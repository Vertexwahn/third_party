#
# Copyright (c) 2017-2021, salesforce.com, inc.
# All rights reserved.
# Licensed under the BSD 3-Clause license.
# For full license text, see LICENSE.txt file in the repo root  or https://opensource.org/licenses/BSD-3-Clause
#

#
# Spring Boot Packager
#
# See the macro documentation below for details.

# Spring Boot Executable JAR Layout specification
#   reverse engineered from the Spring Boot maven plugin

# /
# /META-INF/
# /META-INF/MANIFEST.MF                        <-- very specific manifest for Spring Boot (generated by this rule)
# /BOOT-INF
# /BOOT-INF/classes
# /BOOT-INF/classes/git.properties             <-- properties file containing details of the current source tree via Git
# /BOOT-INF/classes/**/*.class                 <-- compiled application classes, must include @SpringBootApplication class
# /BOOT-INF/classes/META-INF/*                 <-- application level META-INF config files (e.g. spring.factories)
# /BOOT-INF/lib
# /BOOT-INF/lib/*.jar                          <-- all upstream transitive dependency jars must be here (except spring-boot-loader)
# /org/springframework/boot/loader
# /org/springframework/boot/loader/**/*.class  <-- the Spring Boot Loader classes must be here

# ***************************************************************
# Dependency Aggregator Rule
#  do not use directly, see the SpringBoot Macro below

def _depaggregator_rule_impl(ctx):
    # magical incantation for getting upstream transitive closure of java deps
    merged = java_common.merge([dep[java_common.provider] for dep in ctx.attr.deps])

    jars = []
    excludes = {}

    for exclusion_info in ctx.attr.deps_exclude:
        for compile_jar in exclusion_info[JavaInfo].full_compile_jars.to_list():
            # print("Spring Boot Excluding: "+compile_jar.owner.name+" as "+compile_jar.path)
            excludes[compile_jar.path] = True

    for dep in merged.transitive_runtime_jars.to_list():
        if excludes.get(dep.path, None) != None:
            # print("exclude by label " + dep.path)
            pass
        else:
            include = True
            for pattern in ctx.attr.deps_exclude_paths:
                if dep.path.find(pattern) > -1:
                    # print("exclude by path " + dep.path)
                    include = False
                    break
            if include:
                # print("Spring Boot Including: "+dep.owner.name+" as "+dep.path)
                jars.append(dep)

    #print("AGGREGATED DEPS")
    #print(jars)

    return [DefaultInfo(files = depset(jars))]

_depaggregator_rule = rule(
    implementation = _depaggregator_rule_impl,
    attrs = {
        "depaggregator_rule": attr.label(),
        "deps": attr.label_list(providers = [java_common.provider]),
        "deps_exclude": attr.label_list(providers = [java_common.provider], allow_empty = True),
        "deps_exclude_paths": attr.string_list(),
    },
)

def _appjar_locator_impl(ctx):
    if java_common.provider in ctx.attr.app_dep:
        output_jars = ctx.attr.app_dep[java_common.provider].runtime_output_jars
        if len(output_jars) != 1:
            fail("springboot rule expected 1 app jar but found %s" % len(output_jars))
    else:
        fail("Unable to locate the app jar")
    return [DefaultInfo(files = depset([output_jars[0]]))]

_appjar_locator_rule = rule(
    implementation = _appjar_locator_impl,
    attrs = {
        "app_dep": attr.label(),
    },
)

# ***************************************************************
# Check Dupe Classes Rule

def _dupeclasses_rule_impl(ctx):
    # setup the output file (contains SUCCESS, NOT_RUN, or the list of errors)
    output = ctx.actions.declare_file(ctx.attr.out)
    outputs = [output]

    if not ctx.attr.dupeclassescheck_enable:
        ctx.actions.write(output, "NOT_RUN", is_executable = False)
        return [DefaultInfo(files = depset(outputs))]

    inputs = []
    input_args = ctx.actions.args()

    # inputs (dupe checker python script, spring boot jar file, ignorelist)
    inputs.append(ctx.attr.script.files.to_list()[0])
    input_args.add(ctx.attr.script.files.to_list()[0].path)
    inputs.append(ctx.attr.springbootjar.files.to_list()[0])
    input_args.add(ctx.attr.springbootjar.files.to_list()[0].path)
    if ctx.attr.dupeclassescheck_ignorelist != None:
        inputs.append(ctx.attr.dupeclassescheck_ignorelist.files.to_list()[0])
        input_args.add(ctx.attr.dupeclassescheck_ignorelist.files.to_list()[0].path)
    else:
        input_args.add("no_ignorelist")

    # add the output file to the args, so python script knows where to write result
    input_args.add(output.path)

    # compute the location of python
    python_interpreter = _compute_python_executable(ctx)

    # run the dupe checker
    ctx.actions.run(
        executable = python_interpreter,
        outputs = outputs,
        inputs = inputs,
        arguments = [input_args],
        progress_message = "Checking for duplicate classes in the Spring Boot jar...",
        mnemonic = "DupeCheck",
    )
    return [DefaultInfo(files = depset(outputs))]

_dupeclasses_rule = rule(
    implementation = _dupeclasses_rule_impl,
    attrs = {
        "dupeclasses_rule": attr.label(),
        "script": attr.label(),
        "springbootjar": attr.label(),
        "dupeclassescheck_ignorelist": attr.label(allow_files=True),
        "dupeclassescheck_enable": attr.bool(),
        "out": attr.string(),
    },
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
)

# ***************************************************************
# JAVAX DETECT Rule

def _javaxdetect_rule_impl(ctx):
    # setup the output file (contains SUCCESS, NOT_RUN, or the list of errors)
    output = ctx.actions.declare_file(ctx.attr.out)
    outputs = [output]

    if not ctx.attr.javaxdetect_enable:
        ctx.actions.write(output, "NOT_RUN", is_executable = False)
        return [DefaultInfo(files = depset(outputs))]

    inputs = []
    input_args = ctx.actions.args()

    # inputs (dupe checker python script, spring boot jar file, ignorelist)
    inputs.append(ctx.attr.script.files.to_list()[0])
    input_args.add(ctx.attr.script.files.to_list()[0].path)
    inputs.append(ctx.attr.springbootjar.files.to_list()[0])
    input_args.add(ctx.attr.springbootjar.files.to_list()[0].path)
    if ctx.attr.javaxdetect_ignorelist != None:
        inputs.append(ctx.attr.javaxdetect_ignorelist.files.to_list()[0])
        input_args.add(ctx.attr.javaxdetect_ignorelist.files.to_list()[0].path)
    else:
        input_args.add("no_ignorelist")

    # add the output file to the args, so python script knows where to write result
    input_args.add(output.path)

    # compute the location of python
    python_interpreter = _compute_python_executable(ctx)

    # run the dupe checker
    ctx.actions.run(
        executable = python_interpreter,
        outputs = outputs,
        inputs = inputs,
        arguments = [input_args],
        progress_message = "Checking for javax classes in the Spring Boot jar (candidates for jakarta migration)...",
        mnemonic = "JavaxDetect",
    )
    return [DefaultInfo(files = depset(outputs))]

_javaxdetect_rule = rule(
    implementation = _javaxdetect_rule_impl,
    attrs = {
        "javaxdetect_rule": attr.label(),
        "script": attr.label(),
        "springbootjar": attr.label(),
        "javaxdetect_ignorelist": attr.label(allow_files=True),
        "javaxdetect_enable": attr.bool(),
        "out": attr.string(),
    },
    toolchains = ["@bazel_tools//tools/python:toolchain_type"],
)

def _compute_python_executable(ctx):
    python_interpreter = None

    # hard requirement on python3 being available
    python_runtime = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"].py3_runtime
    if python_runtime != None:
        if python_runtime.interpreter != None:
            # registered python toolchain, or the Bazel python wrapper script (for system python)
            python_interpreter = python_runtime.interpreter
        elif python_runtime.interpreter_path != None:
            # legacy python only?
            python_interpreter = python_runtime.interpreter_path

    # print(python_interpreter)
    return python_interpreter

# ***************************************************************
# BANNED DEPS RULE

def _banneddeps_rule_impl(ctx):
    output = ctx.actions.declare_file(ctx.attr.out)
    outputs = [output]

    if ctx.attr.deps_banned == None:
        ctx.actions.write(output, "NOT_RUN", is_executable = False)
        return [DefaultInfo(files = depset(outputs))]

    # iterate through the transitive set; this set has already had the deps_exclude
    # rules applied, so this is the filtered list
    found_banned = False
    banned_filenames = ""
    deps = ctx.attr.deps
    for dep in deps:
        for file in dep.files.to_list():
            for currentmatcher in ctx.attr.deps_banned:
                if currentmatcher in file.basename:
                    # found a banned dep
                    banned_filenames = banned_filenames + file.basename + "\n"
                    found_banned = True

    if found_banned:
        ctx.actions.write(output, "FAIL", is_executable = False)
        fail("Found banned jars in the springboot rule [" + ctx.label.name
          + "] dependency list:\n" + banned_filenames
          + "\nSee the deps_banned attribute on this rule for the matched patterns.")
    else:
        ctx.actions.write(output, "SUCCESS", is_executable = False)
    return [DefaultInfo(files = depset(outputs))]

_banneddeps_rule = rule(
    implementation = _banneddeps_rule_impl,
    attrs = {
        "banneddeps_rule": attr.label(),
        "springboot_rule_name": attr.string(),
        "deps_banned": attr.string_list(),
        "deps": attr.label_list(),
        "out": attr.string(),
    }
)



# ***************************************************************
# Outer launcher script for "bazel run"

_bazelrun_script_template = """
#!/bin/bash

set -e

# bring in the resolved variables needed for running the script
# SCRIPT_DIR is the directory in which bazel run executes
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Detect Java Toolchain (optional)
# If the bazelrun_java_toolchain attribute on the springboot rule is set, the springboot
# rule impl below will replace the java_toolchain_attr tag with the relative path
# from exec root to the JVM. We have to do some Bash hijinks to resolve the
# absolute path.
JAVA_TOOLCHAIN_RELATIVE=%java_toolchain_attr%
if [ -z ${JAVA_TOOLCHAIN_RELATIVE+x} ]; then
  # the springboot rule did not set the bazelrun_java_toolchain attribute
  unset JAVA_TOOLCHAIN
else
  # the springboot rule did set the bazelrun_java_toolchain attribute, convert
  # it into an absolute path using exec_root
  exec_root=${SCRIPT_DIR%%bazel-out*}
  JAVA_TOOLCHAIN="${exec_root}${JAVA_TOOLCHAIN_RELATIVE}"
  JAVA_TOOLCHAIN_NAME=%java_toolchain_name_attr%
fi

# the env variables file is found in SCRIPT_DIR
source $SCRIPT_DIR/bazelrun_env.sh

# the inner bazelrun script is found in the runfiles subdir
# this is either default_bazelrun_script.sh or a custom one provided by the user
source %bazelrun_script%
"""

# ***************************************************************
# SpringBoot Rule
#  do not use directly, see the SpringBoot Macro below

def _springboot_rule_impl(ctx):
    outs = depset(transitive = [
        ctx.attr.app_compile_rule.files,
        ctx.attr.genmanifest_rule.files,
        ctx.attr.bazelrun_script.files,
        ctx.attr.genbazelrunenv_rule.files,
        ctx.attr.gengitinfo_rule.files,
        ctx.attr.genjar_rule.files,
    ])

    # resolve the full path of the launcher script that runs "java -jar <springboot.jar>" when calling
    # "bazel run" with the springboot target (bazel run //examples/helloworld) and string sub it
    # into the _bazelrun_script_template text defined above
    outer_bazelrun_script_contents = _bazelrun_script_template \
        .replace("%bazelrun_script%", ctx.attr.bazelrun_script.files.to_list()[0].path)

    # the bazelrun_java_toolchain optional, if set, we use it as the jvm for bazel run
    if ctx.attr.bazelrun_java_toolchain != None:
      # lookup the path to selected java toolchain, and string sub it into the bazel run script
      # text _bazelrun_script_template defined above
      java_runtime = ctx.attr.bazelrun_java_toolchain[java_common.JavaToolchainInfo].java_runtime
      java_bin = [f for f in java_runtime.files.to_list() if f.path.endswith("bin/java")][0]
      outer_bazelrun_script_contents = outer_bazelrun_script_contents \
          .replace("%java_toolchain_attr%", java_bin.path)
      outer_bazelrun_script_contents = outer_bazelrun_script_contents \
          .replace("%java_toolchain_name_attr%", ctx.attr.bazelrun_java_toolchain.label.name)
    else:
      outer_bazelrun_script_contents = outer_bazelrun_script_contents \
          .replace("%java_toolchain_attr%", "")

    outer_bazelrun_script_file = ctx.actions.declare_file("%s" % ctx.label.name)
    ctx.actions.write(outer_bazelrun_script_file, outer_bazelrun_script_contents, is_executable = True)

    # the jar and launcher script we build needs to be part of runfiles so that it ends
    # up in the working directory that "bazel run" uses
    runfiles_list = ctx.attr.genjar_rule.files.to_list()
    runfiles_list.append(ctx.attr.bazelrun_script.files.to_list()[0])

    # and add any data files to runfiles
    if ctx.attr.bazelrun_data != None:
      for data_target in ctx.attr.bazelrun_data:
        runfiles_list.append(data_target.files.to_list()[0])

    return [DefaultInfo(
        files = outs,
        executable = outer_bazelrun_script_file,
        runfiles = ctx.runfiles(files = runfiles_list),
    )]

_springboot_rule = rule(
    implementation = _springboot_rule_impl,
    executable = True,
    attrs = {
        "app_compile_rule": attr.label(),
        "dep_aggregator_rule": attr.label(),
        "genmanifest_rule": attr.label(),
        "genbazelrunenv_rule": attr.label(),
        "gengitinfo_rule": attr.label(),
        "genjar_rule": attr.label(),
        "dupecheck_rule": attr.label(),
        "javaxdetect_rule": attr.label(),
        "banneddeps_rule": attr.label(),
        "apprun_rule": attr.label(),

        "bazelrun_script": attr.label(allow_files=True),
        "bazelrun_data": attr.label_list(allow_files=True),

        "bazelrun_java_toolchain": attr.label(
            mandatory = False,
            default = "@bazel_tools//tools/jdk:current_java_toolchain",
            providers = [java_common.JavaToolchainInfo],
        ),
    },
)

# ***************************************************************
# SpringBoot Macro
#  this is the entrypoint into the springboot rule
def springboot(
        name,
        java_library,
        boot_app_class,
        boot_launcher_class = "org.springframework.boot.loader.JarLauncher",
        deps = None,
        deps_banned = None,
        deps_exclude = None,
        deps_exclude_paths = None,
        deps_index_file = None,
        deps_use_starlark_order = None,
        dupeclassescheck_enable = None,
        dupeclassescheck_ignorelist = None,
        javaxdetect_enable = None,
        javaxdetect_ignorelist = None,
        include_git_properties_file=True,
        bazelrun_java_toolchain = None,
        bazelrun_script = None,
        bazelrun_jvm_flags = None,
        bazelrun_data = None,
        bazelrun_background = False,
        addins = [],
        tags = [],
        testonly = False,
        visibility = None,
        exclude = [], # deprecated
        classpath_index = "@rules_spring//springboot:empty.txt", # deprecated
        use_build_dependency_order = True, # deprecated
        fail_on_duplicate_classes = False, # deprecated
        duplicate_class_allowlist = None, # deprecated
        jvm_flags = "", # deprecated
        data = [], # deprecated
        ):
    """Bazel rule for packaging an executable Spring Boot application.

    Note that the rule README has more detailed usage instructions for each attribute.

    Args:
      name: **Required**. The name of the Spring Boot application. Typically this is set the same as the package name.
        Ex: *helloworld*.
      java_library: **Required**. The built jar, identified by the name of the java_library rule, that contains the
        Spring Boot application.
      boot_app_class: **Required**. The fully qualified name of the class annotated with @SpringBootApplication.
        Ex: *com.sample.SampleMain*
      deps: Optional. An additional set of Java dependencies to add to the executable.
        Normally all dependencies are set on the *java_library*.
      deps_banned: Optional. A list of strings to match against the jar filenams in the transitive graph of
        dependencies for this springboot app. If any of these strings is found within any jar name, the rule will fail.
        This is useful for detecting jars that should never go to production. The list of dependencies is
        obtained after the deps_exclude processing has run.
      deps_exclude: Optional. A list of jar labels that will be omitted from the final packaging step.
        This is a manual option for eliminating a problematic dependency that cannot be eliminated upstream.
        Ex: *["@maven//:commons_cli_commons_cli"]*.
      deps_exclude: Optional. This attribute provides a list of partial paths that will be omitted
        from the final packaging step if the string is contained within the dep filename. This is a more raw method
        than deps_exclude for eliminating a problematic dependency/file that cannot be eliminated upstream.
        Ex: [*jackson-databind-*].
      deps_index_file: Optional. Uses Spring Boot's
        [classpath index feature](https://docs.spring.io/spring-boot/docs/current/reference/html/appendix-executable-jar-format.html#executable-jar-war-index-files-classpath)
        to define classpath order. This feature is not commonly used, as the application must be extracted from the jar
        file for it to work. Ex: *my_classpath_index.idx*
      deps_use_starlark_order: When running the Spring Boot application from the executable jar file, setting this attribute to
        *True* will use the classpath order as expressed by the order of deps in the BUILD file. Otherwise it is random order.
      dupeclassescheck_enable: If *True*, will analyze the list of dependencies looking for any class that appears more than
        once, but with a different hash. This indicates that your dependency tree has conflicting libraries.
      dupeclassescheck_ignorelist: Optional. When using the duplicate class check, this attribute provides a file
        that contains a list of libraries excluded from the analysis. Ex: *dupeclass_libs.txt*
      javaxdetect_enable: If *True*, will analyze the list of dependencies looking for any class from javax.*
        package. This is a candidate for migration to jakarta.
      javaxdetect_ignorelist: Optional. When using the javax detect check, this attribute provides a file
        that contains a list of libraries excluded from the analysis. Ex: *javaxdetect_ignorelist.txt*
      include_git_properties_file: If *True*, will include a git.properties file in the resulting jar.
      bazelrun_java_toolchain: Optional. Label to the Java toolchain to use when launching the application using 'bazel run'
      bazelrun_script: Optional. When launching the application using 'bazel run', a default launcher script is used.
        This attribute can be used to provide a customized launcher script. Ex: *my_custom_script.sh*
      bazelrun_jvm_flags: Optional. When launching the application using 'bazel run', an optional set of JVM flags
        to pass to the JVM at startup. Ex: *-Dcustomprop=gold -DcustomProp2=silver*
      bazelrun_data: Uncommon option to add data files to runfiles. Behaves like the *data* attribute defined for *java_binary*.
      bazelrun_background: Optional. If True, the *bazel run* launcher will not block. The run command will return and process will remain running.
      addins: Uncommon option to add additional files to the root of the springboot jar. For example a license file. Pass an array of files from the package.
      tags: Optional. Bazel standard attribute.
      testonly: Optional. Bazel standard attribute. Defaults to False.
      visibility: Optional. Bazel standard attribute.
      exclude: Deprecated synonym of *deps_exclude*
      classpath_index: Deprecated synonym of *deps_index_file*
      use_build_dependency_order: Deprecated synonym of *deps_use_starlark_order*
      fail_on_duplicate_classes: Deprecated synonym of *dupeclassescheck_enable*
      duplicate_class_allowlist: Deprecated synonym of *dupeclassescheck_ignorelist*
      jvm_flags: Deprecated synonym of *bazelrun_jvm_flags*
      data: Deprecated synonym of *bazelrun_data*
    """
    # NOTE: if you add/change any params, be sure to rerun the stardoc generator (see BUILD file)

    # Create the subrule names
    dep_aggregator_rule = native.package_name() + "_deps"
    appjar_locator_rule = native.package_name() + "_appjar_locator"
    genmanifest_rule = native.package_name() + "_genmanifest"
    genbazelrunenv_rule = native.package_name() + "_genbazelrunenv"
    gengitinfo_rule = native.package_name() + "_gengitinfo"
    genjar_rule = native.package_name() + "_genjar"
    dupecheck_rule = native.package_name() + "_dupecheck"
    javaxdetect_rule = native.package_name() + "_javaxdetect"
    bannedcheck_rule = native.package_name() + "_bannedcheck"
    apprun_rule = native.package_name() + "_apprun"

    # Handle deprecated attribute names; if modern name is not set then take
    # the legacy attribute value (which may be set to a default, or set by the user)
    if deps_exclude == None:
        deps_exclude = exclude
    if deps_index_file == None:
        deps_index_file = classpath_index
    if deps_use_starlark_order == None:
        deps_use_starlark_order = use_build_dependency_order
    if dupeclassescheck_enable == None:
        dupeclassescheck_enable = fail_on_duplicate_classes
    if dupeclassescheck_ignorelist == None:
        dupeclassescheck_ignorelist = duplicate_class_allowlist
    if bazelrun_jvm_flags == None:
        bazelrun_jvm_flags = jvm_flags
    if bazelrun_data == None:
        bazelrun_data = data

    # assemble deps; generally all deps will come transitively through the java_library
    # but a user may choose to add in more deps directly into the springboot jar (rare)
    java_deps = [java_library]
    if deps != None:
        java_deps = [java_library] + deps

    # SUBRULE 1: AGGREGATE UPSTREAM DEPS
    #  Aggregate transitive closure of upstream Java deps
    _depaggregator_rule(
        name = dep_aggregator_rule,
        deps = java_deps,
        deps_exclude = deps_exclude,
        deps_exclude_paths = deps_exclude_paths,
        tags = tags,
        testonly = testonly,
    )

    # SUBRULE 2: GENERATE THE MANIFEST
    #  NICER: derive the Build JDK and Boot Version values by scanning transitive deps
    genmanifest_out = "MANIFEST.MF"
    native.genrule(
        name = genmanifest_rule,
        srcs = [":" + dep_aggregator_rule],
        cmd = "$(location @rules_spring//springboot:write_manifest.sh) " + boot_app_class + " " + boot_launcher_class + " $@ $(JAVABASE) $(SRCS)",
        #      message = "SpringBoot rule is writing the MANIFEST.MF...",
        tools = ["@rules_spring//springboot:write_manifest.sh"],
        outs = [genmanifest_out],
        tags = tags,
        testonly = testonly,
        toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],  # so that JAVABASE is computed
    )

    # SUBRULE 2B: GENERATE THE GIT PROPERTIES
    gengitinfo_out = "git.properties"
    native.genrule(
        name = gengitinfo_rule,
        cmd = "$(location @rules_spring//springboot:write_gitinfo_properties.sh) $@",
        tools = ["@rules_spring//springboot:write_gitinfo_properties.sh"],
        outs = [gengitinfo_out],
        tags = tags,
        testonly = testonly,
        stamp = 1,
    )

    # SUBRULE 2C: CLASSPATH INDEX
    # see https://github.com/salesforce/rules_spring/issues/81
    _appjar_locator_rule(
        name = appjar_locator_rule,
        app_dep = java_library,
        tags = tags,
        testonly = testonly,
    )

    # SUBRULE 3: INVOKE THE BASH SCRIPT THAT DOES THE PACKAGING
    # The resolved input_file_paths array is made available as the $(SRCS) token in the cmd string.
    # Skylark will convert the logical input_file_paths into real file system paths when surfaced in $(SRCS)
    #  cmd format (see springboot_pkg.sh)
    #    param0: directory containing the springboot rule
    #    param1: location of the jar utility (singlejar)
    #    param2: boot application main classname (the @SpringBootApplication class)
    #    param3: spring boot launcher class
    #    param4: jdk path for running java tools e.g. jar; $(JAVABASE)
    #    param5: compiled application jar name
    #    param6: use build file deps order [True|False]
    #    param7: include git.properties file in resulting jar
    #    param8: executable jar output filename to write to
    #    param9: compiled application jar
    #    param10: manifest file
    #    param11: git.properties file
    #    param12: classpath_index file
    #    param13-N: upstream transitive dependency jar(s)
    native.genrule(
        name = genjar_rule,
        srcs = [
            ":" + appjar_locator_rule,
            ":" + genmanifest_rule,
            ":" + gengitinfo_rule,
            deps_index_file,
        ] + addins + [
            "@rules_spring//springboot:addin_end.txt",
            ":" + dep_aggregator_rule,
        ],
        cmd = "$(location @rules_spring//springboot:springboot_pkg.sh) " +
              "$(location @bazel_tools//tools/jdk:singlejar) " + boot_app_class + " " + boot_launcher_class +
              " $(JAVABASE) " + name + " " + str(deps_use_starlark_order) + " " + str(include_git_properties_file) + " $@ $(SRCS)",
        tools = [
            "@rules_spring//springboot:springboot_pkg.sh",
            "@bazel_tools//tools/jdk:singlejar",
        ],
        tags = tags,
        testonly = testonly,
        outs = [_get_springboot_jar_file_name(name)],
        toolchains = ["@bazel_tools//tools/jdk:current_host_java_runtime"],  # so that JAVABASE is computed
        visibility = visibility,
    )

    # SUBRULE 3B: GENERATE THE ENV VARIABLES USED BY THE BAZELRUN LAUNCHER SCRIPT
    genbazelrunenv_out = "bazelrun_env.sh"
    native.genrule(
        name = genbazelrunenv_rule,
        cmd = "$(location @rules_spring//springboot:write_bazelrun_env.sh) " + name + " " + _get_springboot_jar_file_name(name)
            + " " + _get_relative_package_path() + " $@ " + _convert_starlarkbool_to_bashbool(bazelrun_background)
            + " " + bazelrun_jvm_flags,
        #      message = "SpringBoot rule is writing the bazel run launcher env...",
        tools = ["@rules_spring//springboot:write_bazelrun_env.sh"],
        outs = [genbazelrunenv_out],
        tags = tags,
        testonly = testonly,
    )

    # SUBRULE 4a: RUN THE DUPE CHECKER (if enabled)
    # Skip the dupeclasses_rule instantiation entirely if disabled because
    # running this rule requires Python3 installed. If a workspace does not have
    # Python3 available, they can just never enable dupeclassescheck_enable and be ok
    dupecheck_rule_label = None
    if dupeclassescheck_enable:
        _dupeclasses_rule(
            name = dupecheck_rule,
            script = "@rules_spring//springboot:check_dupe_classes",
            springbootjar = genjar_rule,
            dupeclassescheck_enable = dupeclassescheck_enable,
            dupeclassescheck_ignorelist = dupeclassescheck_ignorelist,
            out = "dupecheck_results.txt",
            tags = tags,
            testonly = testonly,
        )
        dupecheck_rule_label = ":" + dupecheck_rule

    # SUBRULE 4b: RUN THE JAVAX DETECTOR (if enabled)
    # Skip the javaxdetect_rule instantiation entirely if disabled because
    # running this rule requires Python3 installed. If a workspace does not have
    # Python3 available, they can just never enable javaxdetect_enable and be ok
    javaxdetect_rule_label = None
    if javaxdetect_enable:
        _javaxdetect_rule(
            name = javaxdetect_rule,
            script = "@rules_spring//springboot:detect_javax_classes",
            springbootjar = genjar_rule,
            javaxdetect_enable = javaxdetect_enable,
            javaxdetect_ignorelist = javaxdetect_ignorelist,
            out = "javaxdetect_results.txt",
            tags = tags,
            testonly = testonly,
        )
        javaxdetect_rule_label = ":" + javaxdetect_rule

    # SUBRULE 4c: RUN THE BANNED DEP CHECKER (if enabled)
    # Skip the bannedcheck_rule instantiation entirely if disabled because
    # running this rule requires Python3 installed. If a workspace does not have
    # Python3 available, they can just never enable dupeclassescheck_enable and be ok
    bannedcheck_rule_label = None
    if deps_banned != None:
        _banneddeps_rule(
            springboot_rule_name = name,
            name = bannedcheck_rule,
            deps = [":" + dep_aggregator_rule],
            deps_banned = deps_banned,
            out = "bannedcheck_results.txt",
            tags = tags,
            testonly = testonly,
        )
        bannedcheck_rule_label = ":" + bannedcheck_rule

    # SUBRULE 5: PROVIDE A WELL KNOWN RUNNABLE RULE TYPE FOR IDE SUPPORT
    # The presence of this rule  makes a Spring Boot entry point class runnable
    # in IntelliJ (it won't run as part of a packaged Spring Boot jar, ie this
    # won't run java -jar springboot.jar, but close enough)
    # Making the springboot rule itself executable is not recognized by IntelliJ
    # (because IntelliJ doesn't know how to handle the springboot rule type or
    # because of a misconfiguration on our end?)
    native.java_binary(
        name = apprun_rule,
        main_class = boot_app_class,
        runtime_deps = java_deps,
        tags = tags,
        testonly = testonly,
    )

    if bazelrun_script == None:
        bazelrun_script = "@rules_spring//springboot:default_bazelrun_script.sh"

    # MASTER RULE: Create the composite rule that will aggregate the outputs of the subrules
    _springboot_rule(
        name = name,
        app_compile_rule = java_library,
        bazelrun_java_toolchain = bazelrun_java_toolchain,
        dep_aggregator_rule = ":" + dep_aggregator_rule,
        genmanifest_rule = ":" + genmanifest_rule,
        genbazelrunenv_rule = ":" + genbazelrunenv_rule,
        gengitinfo_rule = ":" + gengitinfo_rule,
        genjar_rule = ":" + genjar_rule,
        dupecheck_rule = dupecheck_rule_label,
        javaxdetect_rule = javaxdetect_rule_label,
        apprun_rule = ":" + apprun_rule,

        bazelrun_script = bazelrun_script,
        bazelrun_data = bazelrun_data,

        tags = tags,
        testonly = testonly,
        visibility = visibility,
    )

# end springboot macro

def _get_springboot_jar_file_name(name):
    if name.endswith(".jar"):
        fail("the name attribute of the springboot rule should not end with '.jar'")
    return name + ".jar"

def _convert_starlarkbool_to_bashbool(starlarkbool):
    if starlarkbool:
      return "true"
    return "false"

def _get_relative_package_path():
    """Convert the current package name into a relative file system path. Because
    this value is used as a positional argument, if native.package_name() returns
    empty string (e.g. the target is //:foo), we replace it with a token so that
    it won't confuse the parsing of the positional arguments.
    """
    if not native.package_name():
        return "root"
    return native.package_name() + "/"