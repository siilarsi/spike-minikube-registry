#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

DESTINATION_REGISTRY="registry.test"
SOURCE_REGISTRY="localhost:5000"

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

function deploy_to() {
  namespace=${1?please provide namespace as the first argument}
  kubectl -n "$namespace" apply -k "${LIB_DIR}/configuration/"
}

function catalog() {
  _curl http://${DESTINATION_REGISTRY}/v2/_catalog
}
