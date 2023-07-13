#!/bin/bash

set -eux

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

build_example()
{
    EXAMPLE=$1
    pushd "$EXAMPLE"
    swift package update
    swift package edit hummingbird --revision main
    swift test
    swift package unedit hummingbird
    popd
}

pushd "$here"/..

# folders to ignore
ignore_list="scripts ios-image-server"

# get list of folders and remove ignore list
folders=$(find * -maxdepth 0 -type d)

for i in $ignore_list; do
    folders=$(echo "$folders" | sed "s/$i//g")
done

# Test latest code against examples
for f in $folders; do
    build_example "$f"
done