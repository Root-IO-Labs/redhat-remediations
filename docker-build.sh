#!/usr/bin/env bash
set -euo pipefail

# Script to build the RPM builder Docker image
# Usage: ./docker-build.sh [--ubi-version <8|9|10>] [tag]
# Example: ./docker-build.sh
#          ./docker-build.sh --ubi-version 9
#          ./docker-build.sh --ubi-version 8 my-builder-ubi8
#
# Each UBI version has its own Dockerfile:
#   - Dockerfile.ubi8  (UBI 8)
#   - Dockerfile.ubi9  (UBI 9)
#   - Dockerfile.ubi10 (UBI 10, default)
#
# Patches are organized by UBI version and package: ./patches/<ubi-version>/<package-name>/*.patch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
UBI_VERSION="10"
IMAGE_TAG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ubi-version|--ubi)
            UBI_VERSION="$2"
            shift 2
            ;;
        *)
            IMAGE_TAG="$1"
            shift
            ;;
    esac
done

# Validate UBI version
if [[ ! "$UBI_VERSION" =~ ^(8|9|10)$ ]]; then
    echo "ERROR: Invalid UBI version: $UBI_VERSION"
    echo "Supported versions: 8, 9, 10"
    exit 1
fi

# Select the appropriate Dockerfile
DOCKERFILE="Dockerfile.ubi${UBI_VERSION}"

if [ ! -f "$DOCKERFILE" ]; then
    echo "ERROR: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

# Set default image tag based on UBI version
if [ -z "$IMAGE_TAG" ]; then
    if [ "$UBI_VERSION" = "10" ]; then
        IMAGE_TAG="rpm-builder"
    else
        IMAGE_TAG="rpm-builder-ubi${UBI_VERSION}"
    fi
fi

echo "Building Docker image: $IMAGE_TAG (UBI $UBI_VERSION)"
echo "Using Dockerfile: $DOCKERFILE"
echo "========================================="

# Check if patches directory exists
if [ ! -d "./patches" ]; then
    echo "Creating patches directory..."
    mkdir -p ./patches
fi

# Create version-specific patch directories if they don't exist
for ver in 8 9 10; do
    if [ ! -d "./patches/$ver" ]; then
        mkdir -p "./patches/$ver"
    fi
done

# Build the image using version-specific Dockerfile
docker build -f "$DOCKERFILE" -t "$IMAGE_TAG" .

echo ""
echo "========================================="
echo "Build complete!"
echo "Image: $IMAGE_TAG (UBI $UBI_VERSION)"
echo "Dockerfile: $DOCKERFILE"
echo ""
echo "PATCH ORGANIZATION:"
echo "  Patches are organized by UBI version and package name:"
echo "    ./patches/10/golang/*.patch    (UBI 10)"
echo "    ./patches/9/golang/*.patch     (UBI 9)"
echo "    ./patches/8/golang/*.patch     (UBI 8)"
echo ""
echo "TO BUILD AN RPM:"
echo "  1. Create a version-specific patches folder:"
echo "     mkdir -p ./patches/<ubi-version>/<package-name>"
echo ""
echo "  2. Add your patch files:"
echo "     cp /path/to/*.patch ./patches/<ubi-version>/<package-name>/"
echo ""
echo "  3. Run the builder:"
echo "     ./docker-run.sh [--ubi-version <8|9|10>] <package-name>"
echo ""
echo "EXAMPLES:"
echo "  ./docker-run.sh golang                    # Build for UBI 10 (default)"
echo "  ./docker-run.sh --ubi-version 9 golang    # Build for UBI 9"
echo "  ./docker-run.sh --ubi-version 8 python3   # Build for UBI 8"
echo ""
echo "TO EXPORT SOURCE FOR ANALYSIS:"
echo "  ./docker-export-source.sh [--ubi-version <8|9|10>] <package-name>"
