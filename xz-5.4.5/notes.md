# Notes

- Download https://github.com/tukaani-project/xz/releases/download/v5.4.5/xz-5.4.5.tar.gz

- I extract the files to a folder named xz-5.4.5

- Execute

```shell
patch -p1 < /home/username/bazel-central-registry/modules/xz/5.4.5/patches/patch.diff
```

- Test:

```shell
bazel test //:all_tests
```
