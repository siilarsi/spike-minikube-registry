#!/usr/bin/env bash
set -euxo pipefail

function main() {
  kubectl create namespace spike
}

main "$@"
