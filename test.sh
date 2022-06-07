#!/usr/bin/env bash
set -euxo pipefail

PROG=${0##*/}

function main() {
  is_installed shellcheck 2>/dev/null && shellcheck "$PROG"
  is_installed kubectl && is_installed minikube || exit 1

  case "${1-}" in
    "setup") kubectl create namespace spike;;
    "deploy") kubectl apply -f templates/;;
    "test") test "${2-:@}";;
    *) help;;
  esac
}

function test() {
  curl -s -w "%{http_code}" --resolve registry.test:80:"$(minikube ip)" http://registry.test/
}

function help() {
  cat <<EOM
USAGE
  ./${PROG} [ setup ]

COMMANDS
  setup     setup the test environment
  deploy    deploy the registry
  test      run the test suite against the registry
EOM
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
