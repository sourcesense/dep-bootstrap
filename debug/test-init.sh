#!/usr/bin/env bash

# Define those variables outside then "source in" this file
# PACKAGE_UNDER_TEST=
# PACKAGE_UNDER_TEST_DEPENDENCIES=
# FILE_UNDER_TEST=

testPackageRoot="$PACKAGE_UNDER_TEST"
# shellcheck disable=SC1090
. "$HOME"/.basher/lib/include.zsh
basher uninstall temp/temp-0.0.0
basher link "$testPackageRoot" temp/temp-0.0.0
localRepoDir="$HOME"/.dep/repository/temp/temp/0.0.0
rm -rf "$localRepoDir"
mkdir -p "$localRepoDir"
cp -rf "$testPackageRoot/lib" "$localRepoDir"
basher install "$PACKAGE_UNDER_TEST_DEPENDENCIES"
include temp/temp-0.0.0 "lib/$FILE_UNDER_TEST.sh"

# PUT CODE TO TEST HERE
