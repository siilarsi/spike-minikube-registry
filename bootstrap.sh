#!/usr/bin/env bash
set -euxo pipefail
PROG=${0##*/}

function main() {
  shellcheck "$PROG"

  kubectl create namespace spike
}

main "$@"
