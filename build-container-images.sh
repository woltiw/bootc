#!/usr/bin/env bash

set -euo pipefail

WD="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

DESTINATION_REGISTRY="${DESTINATION_REGISTRY:-registry.wvandoorn.com}"

calver="$(date +"%y.%m.%d-%H%M")"

built_images=()
pushed_images=()
cleanup() {
  echo -e "\nContainer images that were built:"
  for image in "${built_images[@]}"; do
    echo "  - ${image}"
  done
  echo -e "\nContainer images that were pushed:"
  for image in "${pushed_images[@]}"; do
    echo "  - ${image}"
  done

  # podman image rm -f "${built_images[@]}"
}

trap 'cleanup' EXIT

remote_tags() {
  skopeo list-tags "docker://${DESTINATION_REGISTRY}/${DESTINATION_IMAGE}" | jq -r '.Tags[]'
}

local_image_digest() {
  podman image inspect "${1}" | jq -r '.[].Digest'
}

remote_registry_image_digest() {
  skopeo inspect "docker://${1}" | jq -r '.Digest'
}

proces_image() {
  set -euo pipefail
  mkdir -p "${context_dir}"
  build_image_name="localhost/${DESTINATION_IMAGE}:${destination_tags[0]}"
  podman build --pull=always --tag="${build_image_name}" --file="${containerfile}" "${BUILD_ARGS[@]}" "${context_dir}"
  built_images+=("${build_image_name}")
  built_image_digest="$(local_image_digest "${build_image_name}")"
  echo "Built image ${build_image_name} (${built_image_digest})"
  # Check if the resulting image already exists in the registry

  for remote_tag in $(remote_tags); do
    remote_image_digest="$(remote_registry_image_digest "${DESTINATION_REGISTRY}/${DESTINATION_IMAGE}:${remote_tag}")"
    if [[ "${built_image_digest}" == "${remote_image_digest}" ]]; then
      echo "Resulting image already exists. Not pushing another"
      return
    fi
  done

  for tag in "${destination_tags[@]}"; do
    podman tag "${build_image_name}" "${DESTINATION_REGISTRY}/${DESTINATION_IMAGE}:${tag}"
    skopeo copy --all --preserve-digests "containers-storage:${build_image_name}" "docker://${DESTINATION_REGISTRY}/${DESTINATION_IMAGE}:${tag}"
    pushed_images+=("${DESTINATION_REGISTRY}/${DESTINATION_IMAGE}:${tag}")
  done
}

for build_dir in "${WD}"/images/*; do
  set -e
  name="$(basename "${build_dir}")"
  destination_tags=(
    'latest'
  )
  BUILD_ARGS=()
  if [[ -d "${build_dir}/tag" ]]; then
    for tag_dir in "${build_dir}"/tag/*; do
      context_dir="${tag_dir}/context"
      tag="$(basename "${tag_dir}")"

      containerfile="${tag_dir}/Containerfile"
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
    context_dir="${build_dir}/context"
    containerfile="${build_dir}/Containerfile"
    # shellcheck disable=SC1091
    source "${build_dir}/build-logic.sh"
    DESTINATION_IMAGE="bootc/${name}"

    proces_image
  fi
done
