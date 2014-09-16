# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is a quick and dirty rule to make Bazel compile itself. It's not
# production ready.

def java_binary_impl(ctx):
  deploy_jar = ctx.outputs["deploy_jar"]
  manifest = ctx.outputs["manifest"]
  build_output = deploy_jar.path + ".build_output"
  main_class = ctx.attr.main_class
  runtime_jars = nset("LINK_ORDER")
  for dep in ctx.targets("deps", "TARGET"):
    runtime_jars += dep.runtime_jars

  jars = runtime_jars.to_collection()
  ctx.file_action(
    output = manifest,
    content = "Main-Class: " + main_class + "\n",
    executable = False)

  # Cleaning build output directory
  cmd = "set -e;rm -rf " + build_output + ";mkdir " + build_output + "\n"
  for jar in jars:
    cmd += "unzip -qn " + jar.path + " -d " + build_output + "\n"
  cmd += ("/usr/bin/jar cmf " + manifest.path + " " +
         deploy_jar.path + " -C " + build_output + " .\n" +
         "touch " + build_output + "\n")

  ctx.action(
    inputs = jars + [manifest],
    outputs = [deploy_jar],
    mnemonic='Deployjar',
    command=cmd,
    use_default_shell_env=True)

  # Write the wrapper.
  executable = ctx.outputs["executable"]
  ctx.file_action(
    output = executable,
    content = '\n'.join([
        "#!/bin/bash",
        ("exec java -jar $(dirname $0)/$(basename %s) %s \"$@\"" %
         (deploy_jar.path, main_class)),
        ""]),
    executable = True)

  return struct(files_to_build = nset(
      "STABLE_ORDER", [deploy_jar, manifest, executable]))


java_binary = rule(java_binary_impl,
    attr = {
       "deps": attr.label_list(
           file_types=NO_FILE, providers = ["runtime_jars"]),
       "main_class": attr.string(),
   },
   outputs={
       "deploy_jar": "lib%{name}.jar",
       "manifest": "%{name}_MANIFEST.MF",
       "executable": "%{name}",
   },
)