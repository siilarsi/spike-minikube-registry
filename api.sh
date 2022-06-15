#!/usr/bin/env bash
set -euo pipefail

API_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
# shellcheck source=./lib.sh
source "${API_DIR}/lib.sh"

DESTINATION_REGISTRY="registry.test"
SOURCE_REGISTRY="localhost:5000"

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
