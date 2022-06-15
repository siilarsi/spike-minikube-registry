#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

DESTINATION_REGISTRY="registry.test"
SOURCE_REGISTRY="localhost:5000"

function _curl() {
  curl -s --resolve "$DESTINATION_REGISTRY":80:"$(minikube ip)" "$@"
}

function push_local() {
  repo=${1?please provide repository as the first argument}
  tag=${2?please provide tag as the second argument}
  docker pull "${repo}:${tag}"
  docker tag "${repo}:${tag}" "${SOURCE_REGISTRY}/${repo}:${tag}"
  docker push "${SOURCE_REGISTRY}/${repo}:${tag}"
}

# https://stackoverflow.com/questions/42873285/curl-retry-mechanism
function get_http_status_of() {
  url=${1?please provide the url a first argument}
  _curl --retry-all-errors --retry 5 --retry-delay 0 \
    --max-time 2 --retry-max-time 15 -w "%{http_code}" \
    -O /dev/null "$url" | sed -e 's/0*//'
    # the sed command is an ugly hack until I figure how to get the http_code of last response only
}

function deploy_to() {
  namespace=${1?please provide namespace as the first argument}
  kubectl -n "$namespace" apply -k "${LIB_DIR}/configuration/"
}

function catalog() {
  _curl http://${DESTINATION_REGISTRY}/v2/_catalog
}
