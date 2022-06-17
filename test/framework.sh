#!/usr/bin/env bash

FRAMEWORK_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
source "${FRAMEWORK_DIR}/helpers.sh"

function sandbox() {
  trap "test.teardown sandbox &>/dev/null" EXIT
  ( test.setup sandbox || ( test.teardown sandbox && test.setup sandbox ) ) &>/dev/null
}

function when() {
  _scope when "$*"
}

function and() {
  _scope and "$*"
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
