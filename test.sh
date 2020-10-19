#!/usr/bin/env bash

# shellcheck disable=SC1090
testPackageRoot="$HOME/_PACKAGE_UNDER_TEST_"
#----------------
. "$HOME"/.basher/lib/include.zsh
basher uninstall temp/temp-0.0.0
basher link "$testPackageRoot" temp/temp-0.0.0
localRepoDir="$HOME"/.dep/repository/temp/temp/0.0.0
rm -rf "$localRepoDir"
mkdir -p "$localRepoDir"
cp -rf "$testPackageRoot/lib" "$localRepoDir"
#----------------
basher install _PACKAGE_UNDER_TEST_DEPENDENCIES_
include temp/temp-0.0.0 lib/_FILE_UNDER_TEST_.sh

_CODE_TO_TEST_
