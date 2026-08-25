FROM ubuntu:24.04@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea

ARG KERNEL_RELEASE=6.8.0-136-generic
ARG KERNEL_HEADERS_VERSION=6.8.0-136.136

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        kmod \
        "linux-headers-${KERNEL_RELEASE}=${KERNEL_HEADERS_VERSION}" \
    && test -d "/lib/modules/${KERNEL_RELEASE}/build" \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
