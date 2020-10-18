#!/usr/bin/env bash
. ./bootstrap.sh

dep define "log2/shell-common:0.1.0"
dep include "log2/shell-common" log
dep include "log2/shell-common:0.1.0" strings

echo $DEP_INCLUDED