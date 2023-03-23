#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC1090
. dep-bootstrap.sh local-SNAPSHOT

dep define "EcoMind/dep-bootstrap:0.5.5"

dep include EcoMind/dep-bootstrap samples/vanilla
