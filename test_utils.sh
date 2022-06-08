#!/usr/bin/env bash

function setup() {
  is_installed kubectl || exit 1
  kubectl create namespace spike
}

function teardown() {
  is_installed kubectl || exit 1
  kubectl delete namespace spike
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
