#!/usr/bin/env bash
set -euo pipefail

# https://stackoverflow.com/a/246128
JOURNEY_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
# shellcheck source=./framework.sh
source "${JOURNEY_DIR}/framework.sh"
# shellcheck source=./../lib.sh
source "${JOURNEY_DIR}/../lib.sh"
# shellcheck source=./../api.sh
source "${JOURNEY_DIR}/../api.sh"

SOURCE_REGISTRY="localhost:5000"
DESTINATION_REGISTRY="registry.test"

trap 'echo' EXIT
(when "running the test suite"
  (it "requires that kubectl is set to the right context"
    expect_equals "minikube" "$(kubectl config current-context)"
  )
  (it "requires that minikube is running"
    minikube status &> /dev/null
  )
  (it "requires that the ingress addon is enabled"
    minikube addons list | grep -e 'ingress.*enabled' 1>/dev/null
  )
)

(sandbox
  (when "deploying the registry"
    deploy_to sandbox &>/dev/null
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
      push_local "registry" "latest" 1>/dev/null
      transfer_image "$SOURCE_REGISTRY" "$DESTINATION_REGISTRY" "registry" "latest" 1>/dev/null
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
