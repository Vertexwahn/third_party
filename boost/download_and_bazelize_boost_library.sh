#!/usr/bin/env bash

#
#   SPDX-FileCopyrightText: 2024 Julian Amann <dev@vertexwahn.de>
#   SPDX-License-Identifier: Apache-2.0
#

set -euxo pipefail

download_boost_library()
{
    boost_library_name=$1
    boost_library_version=$2
    curl https://github.com/boostorg/${boost_library_name}/archive/refs/tags/boost-${boost_library_version}.tar.gz -O -L
    tar -xf boost-${boost_library_version}.tar.gz
    rm boost-${boost_library_version}.tar.gz
}

bazelize_boost_library()
{
    boost_library_name=$1
    boost_library_version=$2
    cd ${boost_library_name}-boost-${boost_library_version}
    curl https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/refs/heads/main/modules/boost.${boost_library_name}/${boost_library_version}.bcr.1/overlay/BUILD.bazel -O -L
    curl https://raw.githubusercontent.com/bazelbuild/bazel-central-registry/refs/heads/main/modules/boost.${boost_library_name}/${boost_library_version}.bcr.1/MODULE.bazel -O -L
}

download_and_bazelize_boost_library()
{
    download_boost_library $1 $2
    bazelize_boost_library $1 $2
}

#download_and_bazelize_boost_library "config" "1.83.0"
download_boost_library "config" "1.87.0"
