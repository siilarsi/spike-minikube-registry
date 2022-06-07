#!/usr/bin/env bash
set -euo pipefail

PROG=${0##*/}

function main() {
  is_installed shellcheck 2>/dev/null && shellcheck "$PROG"
  is_installed kubectl && is_installed minikube || exit 1

  case "${1-}" in
    "setup") setup;;
    "deploy") deploy;;
    "test") _test "${2-:@}";;
    "teardown") teardown;;
    *) help;;
  esac
}

function _test() {
  echo "--- running test suite ---"
  (sandbox
    (when "deploying the registry"
      deploy &>/dev/null
      (it "should be possible to reach the base URL"
        expected="200"

        actual=$(get_http_status_of http://registry.test/)

        expect_equals "$expected" "$actual"
      )
    )
  )
}

function deploy() {
  kubectl apply -f templates/
}

function setup() {
  kubectl create namespace spike
}

function teardown() {
  kubectl delete namespace spike
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

# https://stackoverflow.com/questions/42873285/curl-retry-mechanism
function get_http_status_of() {
  url=${1?please provide the url a first argument}
  curl --retry-all-errors --retry 5 --retry-delay 0 \
    --max-time 2 --retry-max-time 15 -s -w "%{http_code}" \
    --resolve registry.test:80:"$(minikube ip)" \
    -O /dev/null "$url" | sed -e 's/0*//'
    # the sed command is an ugly hack until I figure how to get the http_code of last request only
}


function sandbox() {
  trap "teardown &>/dev/null" EXIT
  setup &>/dev/null
}

function when() {
  _scope when "$*"
}

function it() {
  _scope it "$*"
}

function expect_equals() {
  expected=${1?please provide expected as the first argument}
  actual=${2?please provide actual as the second argument}
  (
    trap 'if [ $? != 0 ]; then echo "--FAILED expected ${expected} got ${actual}"; fi' EXIT
    test "$expected" = "$actual"
  )
}

OFFSET=( )
function _scope() {
  name="${1:?}"
  shift
  echo "${OFFSET[*]:-}[${name}] $*"
  OFFSET+=("  ")
}

main "$@"
