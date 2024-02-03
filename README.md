# Readme

> bazelizing, bazelization, to bazelize, bazelized: The act of converting some existing software artifact to be easily consumed by the Bazel build tool

This repo contains third-party libraries that were bazelized.
If appreciated those bazelizations can be provided to the upstream dependencies.

## Notes

### How to use with your Bazel build?

You can put the contents of this repository in folder named `third_party` inside your workspace/repo.
Add to your `.bazelignore` the folder `third_party`, since this folder contains many `WORKSPACE` and 
`MODULE.bazel` files.
In your `MODULE.bazel` you can use `local_path_override` to reference on of the listed dependencies here.

Example:

```shell
bazel_dep(name = "openexr", version = "3.2.1")

local_path_override(
    module_name = "openexr",
    path = "../third_party/openexr",
)
```

To see this in action have look at [Vertexwahn/FlatlandRT](https://github.com/Vertexwahn/FlatlandRT)

### Further ideas

Deleting all `MODULE.bazel` files and shifting their contents to one "centralized" `MODULE.bazel` file should enable you to use third-party dependencies simply by:

```shell
...(
    ...
    deps = ["//third_party/abseil-cpp/absl/algorithm:container"],
    ...    
)
```

This approach needs of course some more rework. 
For example, in abseil-cpp you have to change the dependency to `@googletest//:some_target` to something like `//third_party/googletest:some_target`.
Maybe [Copybara](https://github.com/google/copybara) can automate all needed transformations.
This repo stick to the polyrepo approach where each library is consider as its own Bazel module.
Neverthless, it would be interesesting to work in a monorepo with one `MODULE.bazel` file (or no module file since modules are then not needed anymore).

## References

- [Is putting all project dependencies inside project’s repository good practice?](https://medium.com/@Vertexwahn/is-putting-all-project-dependencies-inside-projects-repository-good-practice-2b275f4fc3ce)
