#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

function deploy.all_to() {
  namespace=${1?please provide namespace as the first argument}
  kubectl -n "$namespace" apply -k "${DEPLOY_DIR}/configuration/"
}
