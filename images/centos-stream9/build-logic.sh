#!/usr/bin/env bash

BASE_IMAGE=quay.io/centos-bootc/centos-bootc
BASE_TAG=stream9

BUILD_ARGS+=(
  --build-arg="BASE_IMAGE=${BASE_IMAGE}"
  --build-arg="BASE_TAG=${BASE_TAG}"
)
