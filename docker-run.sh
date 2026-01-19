#!/usr/bin/env bash
set -euo pipefail

# Script to run the RPM builder container
# Usage: ./docker-run.sh [options] <package-name> [image-tag]
#
# Options:
#   --ubi-version <8|9|10>   UBI version (default: 10)
#   --version <pkg-version>  Download specific package version from repos
#   --srpm <file>            Use local SRPM file (offline source)
#   --url <srpm-url>         Download SRPM from URL
#   --export-only            Export source without building
#
# Examples:
#   ./docker-run.sh golang                                      # Build latest for UBI 10
#   ./docker-run.sh --ubi-version 9 golang                      # Build latest for UBI 9
#   ./docker-run.sh --version 2.5.0-1.el8_10 expat              # Specific version from repos
#   ./docker-run.sh --srpm ~/srpms/expat-2.2.5.src.rpm expat    # Use local SRPM file
#   ./docker-run.sh --url https://koji.../pkg.src.rpm pkg       # Download from URL
#   ./docker-run.sh --export-only golang                        # Export source only
#
# Patches are loaded from: ./patches/<ubi-version>/<package-name>/*.patch
# Output artifacts are placed in: ./out/<ubi-version>/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
EXPORT_ONLY=false
PACKAGE_NAME=""
PACKAGE_VERSION=""
SRPM_URL=""
SRPM_FILE=""
IMAGE_TAG=""
UBI_VERSION="10"

while [[ $# -gt 0 ]]; do
    case $1 in
        --export-only|--source-only)
            EXPORT_ONLY=true
            shift
            ;;
        --ubi-version|--ubi)
            UBI_VERSION="$2"
            shift 2
            ;;
        --version|-v)
            PACKAGE_VERSION="$2"
            shift 2
            ;;
        --url|-u)
            SRPM_URL="$2"
            shift 2
            ;;
        --srpm|-s)
            SRPM_FILE="$2"
            shift 2
            ;;
        *)
            if [ -z "$PACKAGE_NAME" ]; then
                PACKAGE_NAME="$1"
            elif [ -z "$IMAGE_TAG" ]; then
                IMAGE_TAG="$1"
            fi
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

# Require package name - no default
if [ -z "$PACKAGE_NAME" ]; then
    echo "ERROR: Package name is required"
    echo ""
    echo "Usage: $0 [options] <package-name> [image-tag]"
    echo ""
    echo "Options:"
    echo "  --ubi-version <8|9|10>   UBI version (default: 10)"
    echo "  --version <pkg-version>  Specific package version (NVR format)"
    echo "  --url <srpm-url>         Download SRPM from URL instead of repos"
    echo "  --srpm <file>            Use local SRPM file"
    echo "  --export-only            Export source without building"
    echo ""
    echo "Examples:"
    echo "  $0 golang                                              # Build latest for UBI 10"
    echo "  $0 --ubi-version 9 golang                              # Build latest for UBI 9"
    echo "  $0 --version 2.5.0-1.el8_10 expat                      # Build specific version"
    echo "  $0 --srpm ~/srpms/expat-2.2.5-17.el8_10.src.rpm expat  # Use local SRPM"
    echo "  $0 --url https://example.com/pkg.src.rpm pkg           # Download from URL"
    echo "  $0 --export-only golang                                # Export source only"
    echo ""
    echo "Patches are loaded from: ./patches/<ubi-version>/<package-name>/*.patch"
    echo "Output artifacts are placed in: ./out/<ubi-version>/"
    echo ""
    exit 1
fi

# Validate local SRPM file if provided
if [ -n "$SRPM_FILE" ]; then
    if [ ! -f "$SRPM_FILE" ]; then
        echo "ERROR: SRPM file not found: $SRPM_FILE"
        exit 1
    fi
    # Convert to absolute path
    SRPM_FILE="$(cd "$(dirname "$SRPM_FILE")" && pwd)/$(basename "$SRPM_FILE")"
fi

# Set default image tag based on UBI version
if [ -z "$IMAGE_TAG" ]; then
    if [ "$UBI_VERSION" = "10" ]; then
        IMAGE_TAG="rpm-builder"
    else
        IMAGE_TAG="rpm-builder-ubi${UBI_VERSION}"
    fi
fi

# Version-specific output directory
OUT_DIR="$SCRIPT_DIR/out/$UBI_VERSION"

# Version-specific patches directory
PATCHES_DIR="$SCRIPT_DIR/patches/$UBI_VERSION/$PACKAGE_NAME"

# Build version info string for display
VERSION_INFO=""
if [ -n "$PACKAGE_VERSION" ]; then
    VERSION_INFO=" (version: $PACKAGE_VERSION)"
elif [ -n "$SRPM_FILE" ]; then
    VERSION_INFO=" (local SRPM)"
elif [ -n "$SRPM_URL" ]; then
    VERSION_INFO=" (from URL)"
fi

if [ "$EXPORT_ONLY" = true ]; then
    echo "Exporting source for package: $PACKAGE_NAME$VERSION_INFO (UBI $UBI_VERSION)"
    echo "========================================="
    echo "Image: $IMAGE_TAG"
    echo "UBI Version: $UBI_VERSION"
    echo "Package: $PACKAGE_NAME"
    [ -n "$PACKAGE_VERSION" ] && echo "Version: $PACKAGE_VERSION"
    [ -n "$SRPM_FILE" ] && echo "Local SRPM: $SRPM_FILE"
    [ -n "$SRPM_URL" ] && echo "SRPM URL: $SRPM_URL"
    echo "Output directory: $OUT_DIR/source/"
    echo ""

    # Clean previous source export if exists
    if [ -d "$OUT_DIR/source" ]; then
        echo "Cleaning previous source export..."
        # Use docker to remove root-owned files from previous exports
        docker run --rm -v "$OUT_DIR:/out" "$IMAGE_TAG" rm -rf /out/source 2>/dev/null || rm -rf "$OUT_DIR/source"
    fi

    # Create output directory if it doesn't exist
    mkdir -p "$OUT_DIR"

    # Build docker run command with optional version/url/srpm
    DOCKER_CMD=(docker run --rm -v "$OUT_DIR:/out")
    # Mount local SRPM file if provided
    if [ -n "$SRPM_FILE" ]; then
        SRPM_BASENAME=$(basename "$SRPM_FILE")
        DOCKER_CMD+=(-v "$SRPM_FILE:/srpm/$SRPM_BASENAME:ro")
    fi
    DOCKER_CMD+=("$IMAGE_TAG" --export-only)
    if [ -n "$PACKAGE_VERSION" ]; then
        DOCKER_CMD+=(--version "$PACKAGE_VERSION")
    fi
    if [ -n "$SRPM_FILE" ]; then
        DOCKER_CMD+=(--srpm "/srpm/$SRPM_BASENAME")
    fi
    if [ -n "$SRPM_URL" ]; then
        DOCKER_CMD+=(--url "$SRPM_URL")
    fi
    DOCKER_CMD+=("$PACKAGE_NAME")

    # Run the container in export-only mode
    echo "Downloading and extracting source for $PACKAGE_NAME$VERSION_INFO..."
    echo "This may take a few minutes..."
    echo ""

    "${DOCKER_CMD[@]}"

    echo ""
    echo "See: $OUT_DIR/source/ for the exported source code"
    echo ""
    echo "When creating patches, place them in: ./patches/$UBI_VERSION/$PACKAGE_NAME/"
else
    echo "Running RPM builder for package: $PACKAGE_NAME$VERSION_INFO (UBI $UBI_VERSION)"
    echo "========================================="
    echo "Image: $IMAGE_TAG"
    echo "UBI Version: $UBI_VERSION"
    echo "Package: $PACKAGE_NAME"
    [ -n "$PACKAGE_VERSION" ] && echo "Version: $PACKAGE_VERSION"
    [ -n "$SRPM_FILE" ] && echo "Local SRPM: $SRPM_FILE"
    [ -n "$SRPM_URL" ] && echo "SRPM URL: $SRPM_URL"
    echo "Patches directory: $PATCHES_DIR"
    echo "Output directory: $OUT_DIR"
    echo ""

    # Check if version-specific patches directory exists
    if [ ! -d "$PATCHES_DIR" ]; then
        echo "ERROR: Patches directory not found: $PATCHES_DIR"
        echo ""
        echo "Please create the directory and add your patch files:"
        echo "  mkdir -p $PATCHES_DIR"
        echo "  cp /path/to/your/*.patch $PATCHES_DIR/"
        echo ""
        exit 1
    fi

    # Check if patches exist in the version-specific directory
    patch_count=$(find "$PATCHES_DIR" -maxdepth 1 -name "*.patch" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$patch_count" -eq 0 ]; then
        echo "ERROR: No .patch files found in $PATCHES_DIR"
        echo "Please add your patch files to this directory before running."
        exit 1
    fi

    echo "Found $patch_count patch file(s) in $PATCHES_DIR"
    echo ""

    # Create output directory if it doesn't exist
    mkdir -p "$OUT_DIR"

    # Build docker run command with optional version/url/srpm
    DOCKER_CMD=(docker run --rm -v "$OUT_DIR:/out" -v "$PATCHES_DIR:/patches:ro")
    # Mount local SRPM file if provided
    if [ -n "$SRPM_FILE" ]; then
        SRPM_BASENAME=$(basename "$SRPM_FILE")
        DOCKER_CMD+=(-v "$SRPM_FILE:/srpm/$SRPM_BASENAME:ro")
    fi
    DOCKER_CMD+=("$IMAGE_TAG")
    if [ -n "$PACKAGE_VERSION" ]; then
        DOCKER_CMD+=(--version "$PACKAGE_VERSION")
    fi
    if [ -n "$SRPM_FILE" ]; then
        DOCKER_CMD+=(--srpm "/srpm/$SRPM_BASENAME")
    fi
    if [ -n "$SRPM_URL" ]; then
        DOCKER_CMD+=(--url "$SRPM_URL")
    fi
    DOCKER_CMD+=("$PACKAGE_NAME")

    # Run the container with version-specific patches mounted
    echo "Starting RPM build process for $PACKAGE_NAME$VERSION_INFO..."
    echo "This may take several minutes..."
    echo ""

    "${DOCKER_CMD[@]}"

    echo ""
    echo "========================================="
    echo "Build complete!"
    echo ""
    echo "RPM artifacts for $PACKAGE_NAME$VERSION_INFO (UBI $UBI_VERSION) are in: $OUT_DIR/"
    echo ""
    echo "RPMS: $OUT_DIR/RPMS/"
    echo "SRPMS: $OUT_DIR/SRPMS/"
    echo ""
    ls -lh "$OUT_DIR/" 2>/dev/null || true
fi
