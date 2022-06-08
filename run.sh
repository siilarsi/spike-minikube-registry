#!/usr/bin/env bash
set -euo pipefail

PROG=${0##*/}

function main() {
  is_installed shellcheck 2>/dev/null && shellcheck "$PROG"

  case "${1-}" in
    "setup") setup;;
    "deploy") deploy;;
    "test") _test "${2-:@}";;
    "teardown") teardown;;
    *) help;;
  esac
}

function _test() {
  trap 'echo' EXIT
  (when "running the test suite"
    (it "requires that the used tools are installed"
      is_installed kubectl && is_installed minikube && is_installed jq
      expect_equals $? 0
    )
    (it "requires that kubectl is set to the right context"
      expect_equals "minikube" "$(kubectl config current-context)"
    )
    (it "requires that minikube is running"
      minikube status 1> /dev/null
    )
    (it "requires that the ingress addon is enabled"
      minikube addons list | grep -e 'ingress.*enabled' 1>/dev/null
    )
  )

  (sandbox
    (when "deploying the registry"
      deploy &>/dev/null
      (it "should be possible to reach the base URL"
        expected="200"

        actual=$(get_http_status_of http://registry.test/)

        expect_equals "$expected" "$actual"
      )
      (it "should not contain any repositories"
        expected="0"

        actual=$(get_body_of http://registry.test/v2/_catalog | jq '.repositories | length')

        expect_equals "$expected" "$actual"
      )
    )
  )
}

function deploy() {
  is_installed kubectl || exit 1
  kubectl apply -f templates/
}

function setup() {
  is_installed kubectl || exit 1
  kubectl create namespace spike
}

function teardown() {
  is_installed kubectl || exit 1
  kubectl delete namespace spike
}

function help() {
  cat <<EOM
USAGE
  ./${PROG} [ setup | deploy | test ]

COMMANDS
  setup     setup the k8s registry environment
  deploy    deploys the registry to k8s
  test      run the test suite against the registry

NOTE
Your current kubectl context is "$(kubectl config current-context)"
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

function get_body_of() {
  url=${1?please provide the url a first argument}
  curl -s --resolve registry.test:80:"$(minikube ip)" "$url"
}

function sandbox() {
  trap "teardown &>/dev/null" EXIT
  ( setup || ( teardown && setup ) ) &>/dev/null
}

function when() {
  _scope when "$*"
}

function it() {
  # https://unix.stackexchange.com/a/438405
  CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
  trap 'if [ $? == 0 ]; then echo -en " $CHECK_MARK"; else echo -e " \u2715"; fi' EXIT
  _scope it "$*"
}

function expect_equals() {
  expected=${1?please provide expected as the first argument}
  actual=${2?please provide actual as the second argument}
  (
    trap 'if [ $? != 0 ]; then echo -n " >> expected ${expected} got ${actual}"; fi' EXIT
    test "$expected" = "$actual"
  )
}

OFFSET=( )
function _scope() {
  name="${1:?}"
  shift
  echo -en "\n${OFFSET[*]:-}[${name}] $*"
  OFFSET+=("  ")
}

main "$@"
