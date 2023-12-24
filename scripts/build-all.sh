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

COMPARISON=""
DRY_RUN=""

while getopts 'du:' option
do
    case $option in
        u) COMPARISON=$OPTARG ;;
        d) DRY_RUN=1 ;;
        *) usage ;;
    esac
done

git status
# get list of folders and remove ignore list
if [[ -n "$COMPARISON" ]]; then
    COMPARE1=$(echo "$COMPARISON" | sed s/:.\*$//)
    COMPARE2=$(echo "$COMPARISON" | sed s/^.\*://)
    if [[ "$COMPARE1" == "$COMPARE2" ]]; then
        COMPARE1=""
    fi
    echo "Comparing $COMPARE1 with $COMPARE2"
    # get intersection between folders at root level and list of folders that have changed in merge commit
    folders=$(comm -12 <(find * -maxdepth 0 -type d) <(git --no-pager diff --name-only $COMPARE1 "$COMPARE2" | awk -F "/" '{print $1}' | sort -u))
else
    folders=$(find * -maxdepth 0 -type d)
fi

for i in $ignore_list; do
    folders=$(echo "$folders" | sed "s/$i//g")
done

echo "Updating:"
echo "$folders"
if [[ -n "$DRY_RUN" ]]; then
    exit 0
fi

# Test latest code against examples
for f in $folders; do
    build_example "$f"
done