#!/usr/bin/env bash
set -euo pipefail

MINIKUBE_REGISTRY="registry.test"

# https://docs.docker.com/registry/spec/manifest-v2-2/
MEDIA_TYPE_MANIFEST_V2="application/vnd.docker.distribution.manifest.v2+json"

# https://docs.docker.com/registry/spec/api/#get-blob
function api.get_blob() {
  registry=${1?please provide registry as the first argument}
  repo=${2?please provide repository as the second argument}
  digest=${3?please provide digest as the third argument}
  _curl -o - "http://${registry}/v2/${repo}/blobs/${digest}"
}

# https://docs.docker.com/registry/spec/api/#initiate-blob-upload
# directly returns upload location
function api.post_initiate_blob_upload() {
  registry=${1?please provide registry as the first argument}
  repo=${2?please provide repository as the second argument}
  _curl -iX POST "http://${registry}/v2/${repo}/blobs/uploads/" \
    | grep "Location" | cut -d ' ' -f2 | tr -d "\r"
}

# https://docs.docker.com/registry/spec/api/#put-blob-upload
function api.put_blob_upload() {
  location=${1?please provide location as the first argument}
  digest=${2?please provide digest as the second argument}
  _curl -H "content-type: application/octet-stream" \
    --data-binary "@-" -X PUT "${location}&digest=${digest}"
}

# https://docs.docker.com/registry/spec/api/#manifest
function api.get_manifest() {
  registry=${1?please provide registry as the first argument}
  repo=${2?please provide repository as the second argument}
  tag=${3?please provide tag as the third argument}
  _curl -H "Accept: $MEDIA_TYPE_MANIFEST_V2" \
    "http://${registry}/v2/${repo}/manifests/${tag}"
}

# https://docs.docker.com/registry/spec/api/#manifest
function api.put_manifest() {
  registry=${1?please provide registry as the first argument}
  repo=${2?please provide repository as the second argument}
  tag=${3?please provide tag as the third argument}
  _curl -H "content-type: $MEDIA_TYPE_MANIFEST_V2" \
    --data-binary "@-" -X PUT \
    "http://${registry}/v2/${repo}/manifests/${tag}"
}

# https://docs.docker.com/registry/spec/api/#catalog
function api.catalog() {
  registry=${1?please provide registry as the first argument}
  _curl "http://${registry}/v2/_catalog"
}

# https://docs.docker.com/registry/spec/api/#listing-image-tags
function api.tags() {
  registry=${1?please provide registry as the first argument}
  repo=${2?please provide repository as the second argument}
  _curl "http://${registry}/v2/${repo}/tags/list"
}

function _curl() {
  curl -s --resolve "$MINIKUBE_REGISTRY":80:"$(minikube ip)" "$@"
}
