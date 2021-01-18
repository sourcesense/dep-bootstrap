#!/usr/bin/env bash

export _DEP_VERBOSENESS_LEVEL=2

. ../bootstrap.sh

# PUT CODE TO TEST HERE

dep define "log2/shell-common:0.2.0"
# dep define "log2/shell-common:0.2.1"

dep include log2/shell-common files

# trim " ciccio   "