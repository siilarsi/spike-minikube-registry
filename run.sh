#!/usr/bin/env bash
set -euo pipefail

PROG=${0##*/}
SOURCE_REGISTRY="localhost:5000"
DESTINATION_REGISTRY="registry.test"
# https://stackoverflow.com/a/246128
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

# shellcheck source=./test_utils.sh
source "${SCRIPT_DIR}/test_utils.sh"

function main() {
  is_installed shellcheck 2>/dev/null && shellcheck -x "$PROG"

  case "${1-help}" in
    "setup") setup;;
    "deploy") deploy;;
    "test") _test;;
    "teardown") teardown;;
    "transfer") transfer "${2-registry}" "${3-latest}";;
    "catalog") catalog;;
    *) help;;
  esac
}

function _test() {
  trap 'echo' EXIT
  (when "running the test suite"
    (it "requires that the used tools are installed"
      is_installed kubectl && is_installed minikube \
        && is_installed jq && is_installed docker && is_installed minikube
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
      (it "should be ready within a few seconds"
        expected="200"

        actual=$(get_http_status_of "http://${DESTINATION_REGISTRY}/")

        expect_equals "$expected" "$actual"
      )
      (it "should not contain any repositories"
        expected="0"

        actual=$(_curl "http://${DESTINATION_REGISTRY}/v2/_catalog" \
          | jq '.repositories | length')

        expect_equals "$expected" "$actual"
      )
      (and "transferring an image to it"
        transfer "registry" "latest" 1>/dev/null
        (it "should contain one repository"
         expected="1"

          actual=$(_curl "http://${DESTINATION_REGISTRY}/v2/_catalog" \
            | jq '.repositories | length')

          expect_equals "$expected" "$actual"
        )
      )
      (and "deleting all of its pods"
        kubectl -n spike delete pods --all 1>/dev/null
        (it "should start up again within a few seconds"
          expected="200"

          actual=$(get_http_status_of "http://${DESTINATION_REGISTRY}/")

          expect_equals "$expected" "$actual"
        )
        (it "should still contain one repository"
          expected="1"

          actual=$(_curl "http://${DESTINATION_REGISTRY}/v2/_catalog" \
            | jq '.repositories | length')

          expect_equals "$expected" "$actual"
        )
      )
    )
  )
}

function transfer() {
  repo=${1?please provide repository as the first argument}
  tag=${2?please provide tag as the second argument}
  push_local "$repo" "$tag"
  _transfer "$repo" "$tag"
}

function push_local() {
  repo=${1?please provide repository as the first argument}
  tag=${2?please provide tag as the second argument}
  docker pull "${repo}:${tag}"
  docker tag "${repo}:${tag}" "${SOURCE_REGISTRY}/${repo}:${tag}"
  docker push "${SOURCE_REGISTRY}/${repo}:${tag}"
}

function _transfer() {
  repo=${1?please provide repository as the first argument}
  tag=${2?please provide tag as the second argument}
  echo "transferring $repo:$tag from ${SOURCE_REGISTRY} to ${DESTINATION_REGISTRY}"
  manifest=$(_curl -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "http://${SOURCE_REGISTRY}/v2/${repo}/manifests/${tag}")
    echo "$manifest" | jq -r '.config.digest, .layers[].digest' \
      | while read -r digest; do
        location=$(_curl -iX POST "http://${DESTINATION_REGISTRY}/v2/${repo}/blobs/uploads/" \
          | grep "Location" | cut -d ' ' -f2 | tr -d "\r")
        _curl -o - "http://${SOURCE_REGISTRY}/v2/${repo}/blobs/${digest}" \
          | _curl -H "content-type: application/octet-stream" \
            --data-binary "@-" -X PUT "${location}&digest=${digest}"
      done
  echo "$manifest" \
  | _curl -H "content-type: application/vnd.docker.distribution.manifest.v2+json" \
    --data-binary "@-" -X PUT "http://${DESTINATION_REGISTRY}/v2/${repo}/manifests/${tag}"
  echo "done"
}

function _curl() {
  curl -s --resolve "$DESTINATION_REGISTRY":80:"$(minikube ip)" "$@"
}

# https://stackoverflow.com/questions/42873285/curl-retry-mechanism
function get_http_status_of() {
  url=${1?please provide the url a first argument}
  _curl --retry-all-errors --retry 5 --retry-delay 0 \
    --max-time 2 --retry-max-time 15 -w "%{http_code}" \
    -O /dev/null "$url" | sed -e 's/0*//'
    # the sed command is an ugly hack until I figure how to get the http_code of last response only
}

function deploy() {
  is_installed kubectl || exit 1
  kubectl -n spike apply -k configuration/registry
}

function catalog() {
  _curl http://${DESTINATION_REGISTRY}/v2/_catalog
}

function help() {
  cat <<EOM
USAGE
  ./${PROG} [ test | setup | teardown | deploy | transfer | catalog ]

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
