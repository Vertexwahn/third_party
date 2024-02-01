# How to run with Bazel?

## macOS

```shell
# Assuming you are currently in the flip-1.3 folder
bazel run --config=macos //:flip-cli -- -r $(pwd)/images/reference.exr -t $(pwd)/images/test.exr -d $(pwd)/images/out --hist
```

## Ubuntu 22.04

```shell
# Assuming you are currently in the flip-1.3 folder
bazel run --config=gcc11 //:flip-cli -- -r $(pwd)/images/reference.exr -t $(pwd)/images/test.exr -d $(pwd)/images/out --hist
```


## Windows wiht Visual Studio 2022

```shell
# Assuming you are currently in the flip-1.3 folder
bazel run --config=vs2022 //:flip-cli -- -r $(pwd)/images/reference.exr -t $(pwd)/images/test.exr -d $(pwd)/images/out --hist
```
