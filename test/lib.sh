#!/usr/bin/env bash

SOURCE_REGISTRY="localhost:5000"

function test.setup() {
  namespace=${1?please provide namespace as the first argument}
  kubectl create namespace "$namespace"
  if [ "$(curl -s -w "%{http_code}" http://${SOURCE_REGISTRY})" != 200 ]; then
    docker run -d -p 5000:5000 --restart always --name "registry.${namespace}" registry:2
  fi
}

function test.teardown() {
  namespace=${1?please provide namespace as the first argument}
  kubectl delete namespace "$namespace"
  docker stop "registry.${namespace}"
  docker rm "registry.${namespace}"
}
