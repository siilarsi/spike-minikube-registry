#!/usr/bin/env bash
set -euo pipefail

PROG=${0##*/}
# https://stackoverflow.com/a/246128
RUN_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
# shellcheck source=./deploy.sh
source "${RUN_DIR}/deploy.sh"
# shellcheck source=./api.sh
source "${RUN_DIR}/api.sh"
# shellcheck source=./test/helpers.sh
source "${RUN_DIR}/test/helpers.sh"

MINIKUBE_REGISTRY="registry.test"

function main() {
  is_installed shellcheck 2>/dev/null && shellcheck -x "$PROG"
  is_installed kubectl && is_installed minikube \
    && is_installed curl && is_installed docker \
    && is_installed jq || exit 1

  case "${1-help}" in
    "setup") test.setup custom-run;;
    "deploy") deploy.all_to custom-run;;
    "test") (cd "${RUN_DIR}/test/" && ./journey.sh);;
    "teardown") test.teardown custom-run;;
    "transfer")
      image="${2-foo:latest}"
      test.build_test_image "$image"
      test.push_image_to_local_repo "$image"
      test.transfer_image "$image"
      ;;
    "catalog") api.catalog "$MINIKUBE_REGISTRY";;
    *) help;;
  esac
}

function help() {
  cat <<EOM
USAGE
  ./${PROG} [ test | setup | teardown | deploy | transfer | api ]

COMMANDS
  test      run the test suite against the registry
            can be run independently

  setup     setup the test environment => $(kubectl config current-context)
  teardown  cleanup the test environment

  deploy    deploy the registry => $(kubectl config current-context)
  transfer  transfer an image to the deployed registry
  catalog   view the catalog of the deployed registry
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
