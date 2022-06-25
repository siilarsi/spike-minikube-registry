#!/usr/bin/env bash
set -euo pipefail

# https://stackoverflow.com/a/246128
JOURNEY_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
# shellcheck source=./framework.sh
source "${JOURNEY_DIR}/framework.sh"
# shellcheck source=./helpers.sh
source "${JOURNEY_DIR}/helpers.sh"
# shellcheck source=./../api.sh
source "${JOURNEY_DIR}/../api.sh"
# shellcheck source=./../deploy.sh
source "${JOURNEY_DIR}/../deploy.sh"

MINIKUBE_REGISTRY="registry.test"
TIMEOUT=15

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
    deploy.all_to sandbox &>/dev/null
    (it "should be ready within $TIMEOUT seconds"
      expected="200"

      actual=$(test.retry_until "http://${MINIKUBE_REGISTRY}/" $TIMEOUT)

      expect_equals "$expected" "$actual"
    )
    (it "should not contain any repositories"
      expected="0"

      actual=$(api.catalog "$MINIKUBE_REGISTRY" \
        | jq '.repositories | length')

      expect_equals "$expected" "$actual"
    )
    (and "transferring an image to it"
      test.build_test_image "foo:bar" 1>/dev/null
      test.push_image_to_local_repo "foo:bar" 1>/dev/null
      test.transfer_image "foo:bar" 1>/dev/null
      (it "should contain one repository"
        expected="1"

        actual=$(api.catalog "$MINIKUBE_REGISTRY" \
          | jq '.repositories | length')

        expect_equals "$expected" "$actual"
      )
      (it "should be an image with one tag"
        expected="1"

        actual=$(api.tags "$MINIKUBE_REGISTRY" "foo" \
          | jq '.tags | length')

        expect_equals "$expected" "$actual"
      )
    )
    (and "deleting all of its pods"
      kubectl -n spike delete pods --all 1>/dev/null
      (it "should start up again within $TIMEOUT seconds"
        expected="200"

        actual=$(test.retry_until "http://${MINIKUBE_REGISTRY}/" $TIMEOUT)

        expect_equals "$expected" "$actual"
      )
      (it "should still contain one repository"
        expected="1"

        actual=$(api.catalog "$MINIKUBE_REGISTRY" \
          | jq '.repositories | length')

        expect_equals "$expected" "$actual"
      )
    )
    (and "building and transferring 10 images of two new repos each"
      old_images=( r1:first r2:first r1:second r2:second r1:third r2:third )
      old_images+=( r1:fourth r2:fourth r1:fifth r2:fifth )
      new_images=( r1:sixth r2:sixth r1:seventh r2:seventh r1:eighth r2:eighth )
      new_images+=( r1:ninth r2:ninth r1:latest r2:latest )
      all_images=( "${old_images[@]}" "${new_images[@]}" )

      for image in "${all_images[@]}"; do
        printf %-15s ": $image"
        test.build_test_image "$image" 1>/dev/null
        test.push_image_to_local_repo "$image" 1>/dev/null
        test.transfer_image "$image" 1>/dev/null
        echo -e -n "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
      done

      (it "should now contain three repositories"
        expected="3"

        actual=$(api.catalog "$MINIKUBE_REGISTRY" \
          | jq '.repositories | length')

        expect_equals "$expected" "$actual"
      )
      (it "should contain 10 tags for the first repo"
        expected="10"

        actual=$(api.tags "$MINIKUBE_REGISTRY" "r1" \
          | jq '.tags | length')

        expect_equals "$expected" "$actual"
      )
      (it "should contain 10 tags for the second repo"
        expected="10"

        actual=$(api.tags "$MINIKUBE_REGISTRY" "r1" \
          | jq '.tags | length')

        expect_equals "$expected" "$actual"
      )
      (and applying the image retention job
        deploy.image_retention_to sandbox 1>/dev/null
      )
    )
  )
)
