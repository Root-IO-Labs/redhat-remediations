# Default Dockerfile - UBI 10
# For other versions, use:
#   - Dockerfile.ubi8  (UBI 8)
#   - Dockerfile.ubi9  (UBI 9)
#   - Dockerfile.ubi10 (UBI 10)
#
# Or use the helper script:
#   ./docker-build.sh --ubi-version <8|9|10>

# UBI 10 build container that:
# 1) downloads any Red Hat package SRPM from enabled repos
# 2) applies patches you provide
# 3) rebuilds the RPMs
#
# Usage:
#   docker build -t rpm-builder .
#   docker run --rm -v "$PWD/out/10:/out" -v "$PWD/patches/10/<pkg>:/patches:ro" rpm-builder <package-name>
#
# Patches are organized by UBI version and package: ./patches/10/<package-name>/*.patch
# Patches are mounted at runtime, not baked into the image.

FROM registry.access.redhat.com/ubi10/ubi

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Build tooling + helpers to fetch SRPM + build deps
RUN dnf -y update && \
    dnf -y install \
      rpm-build rpmdevtools dnf-plugins-core \
      gcc gcc-c++ make git which file findutils \
      diffutils patch tar gzip bzip2 xz \
      python3 && \
    dnf -y clean all

# Where you'll mount artifacts and patches
VOLUME ["/out"]
VOLUME ["/patches"]

# Copy the build script
COPY build-rpm.sh /usr/local/bin/build-rpm.sh
RUN chmod +x /usr/local/bin/build-rpm.sh

ENTRYPOINT ["/usr/local/bin/build-rpm.sh"]
