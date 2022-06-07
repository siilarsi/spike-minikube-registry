#!/usr/bin/env bash
set -euxo pipefail

PROG=${0##*/}

function main() {
  assert_installed kubectl
  assert_installed shellcheck

  shellcheck "$PROG"

  kubectl create namespace spike
}

# https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script
function assert_installed() {
  _command=${1?please provide the command to assert}
  if ! command -v "$_command" &> /dev/null; then
    echo "${_command} is required to run ${PROG}"
    exit 1
  fi
}

main "$@"
