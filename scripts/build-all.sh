#!/bin/bash

set -eu

here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

usage()
{
    echo "Usage: build-all.sh -u"
    exit 2
}

build_example()
{
    EXAMPLE=$1
    echo "##############################################"
    echo " "
    echo "Building $EXAMPLE"
    echo " "
    echo "##############################################"
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

BUILD_UPDATED=""

while getopts 'u' option
do
    case $option in
        u) BUILD_UPDATED=1 ;;
        *) usage ;;
    esac
done

# get list of folders and remove ignore list
if [[ -n "$BUILD_UPDATED" ]]; then
    # get intersection between folders at root level and list of folders that have changed in merge commit
    folders=$(comm -12 <(find * -maxdepth 0 -type d) <(git diff --name-only -r HEAD^1 HEAD | awk -F "/" '{print $1}' | sort -u))
else
    folders=$(find * -maxdepth 0 -type d)
fi

for i in $ignore_list; do
    folders=$(echo "$folders" | sed "s/$i//g")
done

echo "Updating $folders"

# Test latest code against examples
for f in $folders; do
    build_example "$f"
done