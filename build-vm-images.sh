#!/usr/bin/env bash

set -euo pipefail

WD="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

DESTINATION_REGISTRY="${DESTINATION_REGISTRY:-registry.wvandoorn.com}"

proces_image() {
  set -euo pipefail
  output_dir="${WD}/output/${name}"
  mkdir -p "${output_dir}"
  container_image_name="${DESTINATION_REGISTRY}/${DESTINATION_IMAGE}:${destination_tags[0]}"

  sudo podman pull "${container_image_name}"
  sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "${WD}/config.toml:/config.toml:ro" \
    -v "${output_dir}:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --use-librepo=True \
    "${container_image_name}"

}

for build_dir in "${WD}"/images/*; do
  set -e
  name="$(basename "${build_dir}")"
  destination_tags=(
    'latest'
  )
  if [[ -d "${build_dir}/tag" ]]; then
    for tag_dir in "${build_dir}"/tag/*; do
      tag="$(basename "${tag_dir}")"

      # shellcheck disable=SC1091
      source "${build_dir}/build-logic.sh"
      # shellcheck disable=SC1091
      source "${tag_dir}/build-logic.sh"
      DESTINATION_IMAGE="bootc/${name}"

      destination_tags=(
        "${tag}"
      )
      proces_image
    done
  else

    # shellcheck disable=SC1091
    source "${build_dir}/build-logic.sh"
    DESTINATION_IMAGE="bootc/${name}"
    proces_image
  fi
done
