#!/usr/bin/env bash
set -euxo pipefail

PROG=${0##*/}

function main() {
  is_installed kubectl || exit 1
  is_installed shellcheck 2>/dev/null && shellcheck "$PROG"

  kubectl create namespace spike
}

# https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script
function is_installed() {
  _command=${1?please provide the command to assert}
  if ! command -v "$_command" &> /dev/null; then
    echo "${_command} is not installed" 1>&2
    return 1
  fi
}

main "$@"
