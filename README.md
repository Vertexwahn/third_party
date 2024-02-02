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


## References

- [Is putting all project dependencies inside project’s repository good practice?](https://medium.com/@Vertexwahn/is-putting-all-project-dependencies-inside-projects-repository-good-practice-2b275f4fc3ce)
