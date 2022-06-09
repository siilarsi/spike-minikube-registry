#!/usr/bin/env bash

SOURCE_REGISTRY="localhost:5000"

function setup() {
  is_installed kubectl && is_installed docker || exit 1
  kubectl create namespace spike
  if [ "$(curl -s -w "%{http_code}" http://${SOURCE_REGISTRY})" != 200 ]; then
    docker run -d -p 5000:5000 --restart always --name registry registry:2
  fi
}

function teardown() {
  is_installed kubectl && is_installed docker || exit 1
  kubectl delete namespace spike
  docker stop registry
  docker rm registry
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
