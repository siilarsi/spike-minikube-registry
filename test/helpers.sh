#!/usr/bin/env bash

LOCAL_REGISTRY="localhost:5000"
MINIKUBE_REGISTRY="registry.test"

function test.setup() {
  namespace=${1?please provide namespace as the first argument}
  kubectl create namespace "$namespace"
  if [ "$(curl -s -w "%{http_code}" http://${LOCAL_REGISTRY})" != 200 ]; then
    docker run -d -p 5000:5000 --restart always --name "registry.${namespace}" registry:2
  fi
}

function test.teardown() {
  namespace=${1?please provide namespace as the first argument}
  kubectl delete namespace "$namespace"
  docker stop "registry.${namespace}"
  docker rm "registry.${namespace}"
}

function test.build_test_image() {
  image=${1?please provide a name to build the image with}
  docker build -t "${image}" -f - . <<EOM
FROM scratch

CMD echo "test image ${image}"
EOM
}

function test.push_image_to_local_repo() {
  image=${1?please provide the name of the image}
  docker tag "$image" "${LOCAL_REGISTRY}/${image}"
  docker push "${LOCAL_REGISTRY}/${image}"
}

# transfer an image from the local to the minikube registry
function test.transfer_image() {
  image=${1?please provide image to transfer as the third argument}
  repo=$(echo "$image" | cut -d':' -f 1)
  tag=$(echo "$image" | cut -d':' -f 2)
  echo "transferring $repo:$tag"
  manifest=$(api.get_manifest "$LOCAL_REGISTRY" "$repo" "${tag-latest}")
  echo "$manifest" | jq -r '.config.digest, .layers[].digest' \
    | while read -r digest; do
      api.get_blob "${LOCAL_REGISTRY}" "${repo}" "${digest}" \
        | api.put_blob_upload "$(api.post_initiate_blob_upload "$MINIKUBE_REGISTRY" "$repo")" "$digest"
    done
  echo "$manifest" | api.put_manifest "${MINIKUBE_REGISTRY}" "${repo}" "${tag-latest}"
  echo "done"
}

# https://stackoverflow.com/questions/42873285/curl-retry-mechanism
function test.retry_until() {
  url=${1?please provide the url a first argument}
  timeout=${2?please provide the timeout as the second argument}
  _curl --retry-all-errors --retry 5 --retry-delay 0 \
    --max-time 2 --retry-max-time "$timeout" -w "%{http_code}" \
    -O /dev/null "$url" | sed -e 's/0*//'
    # the sed command is an ugly hack until I figure how to get the http_code of last response only
}

function _curl() {
  curl -s --resolve "$MINIKUBE_REGISTRY":80:"$(minikube ip)" "$@"
}
