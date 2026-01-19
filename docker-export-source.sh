#!/usr/bin/env bash
set -euo pipefail

# Script to export package source code for analysis and patch creation
# Usage: ./docker-export-source.sh [options] <package-name> [image-tag]
#
# Options:
#   --ubi-version <8|9|10>   UBI version (default: 10)
#   --version <pkg-version>  Download specific package version from repos
#   --srpm <file>            Use local SRPM file (offline source)
#   --url <srpm-url>         Download SRPM from URL
#
# Examples:
#   ./docker-export-source.sh golang                                  # Export latest for UBI 10
#   ./docker-export-source.sh --ubi-version 9 golang                  # Export latest for UBI 9
#   ./docker-export-source.sh --version 2.5.0-1.el8_10 expat          # Specific version
#   ./docker-export-source.sh --srpm ~/srpms/expat-2.2.5.src.rpm exp  # Use local SRPM
#   ./docker-export-source.sh --url https://koji.../pkg.src.rpm pkg   # Download from URL
#
# After exporting, patches should be placed in: ./patches/<ubi-version>/<package-name>/
# Output is placed in: ./out/<ubi-version>/source/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
PACKAGE_NAME=""
PACKAGE_VERSION=""
SRPM_URL=""
SRPM_FILE=""
IMAGE_TAG=""
UBI_VERSION="10"

while [[ $# -gt 0 ]]; do
    case $1 in
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
    echo "  --srpm <file>            Use local SRPM file (offline source)"
    echo "  --url <srpm-url>         Download SRPM from URL"
    echo ""
    echo "Examples:"
    echo "  $0 golang                                              # Export latest for UBI 10"
    echo "  $0 --ubi-version 9 golang                              # Export latest for UBI 9"
    echo "  $0 --version 2.5.0-1.el8_10 expat                      # Export specific version"
    echo "  $0 --srpm ~/srpms/expat-2.2.5-17.el8_10.src.rpm expat  # Use local SRPM"
    echo "  $0 --url https://example.com/pkg.src.rpm pkg           # Download from URL"
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

echo "Exporting source for package: $PACKAGE_NAME$VERSION_INFO (UBI $UBI_VERSION)"
echo "========================================="
echo "Image: $IMAGE_TAG"
echo "UBI Version: $UBI_VERSION"
echo "Package: $PACKAGE_NAME"
[ -n "$PACKAGE_VERSION" ] && echo "Version: $PACKAGE_VERSION"
[ -n "$SRPM_FILE" ] && echo "Local SRPM: $SRPM_FILE"
[ -n "$SRPM_URL" ] && echo "SRPM URL: $SRPM_URL"
echo "Output directory: $OUT_DIR/source/"
echo "Patches directory: $PATCHES_DIR"
echo ""

# Clean previous source export if exists
if [ -d "$OUT_DIR/source" ]; then
    echo "Cleaning previous source export..."
    # Use docker to remove root-owned files from previous exports
    docker run --rm -v "$OUT_DIR:/out" "$IMAGE_TAG" rm -rf /out/source 2>/dev/null || rm -rf "$OUT_DIR/source"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUT_DIR"

# Create version-specific patches directory if it doesn't exist
if [ ! -d "$PATCHES_DIR" ]; then
    echo "Creating patches directory for $PACKAGE_NAME (UBI $UBI_VERSION)..."
    mkdir -p "$PATCHES_DIR"
fi

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
echo "========================================="
echo "Source export complete!"
echo ""
echo "Source code location: $OUT_DIR/source/"
echo ""

# Find the extracted source directory
SOURCE_DIRS=$(find "$OUT_DIR/source" -maxdepth 1 -type d ! -name source ! -name _rpm_metadata 2>/dev/null || true)

if [ -n "$SOURCE_DIRS" ]; then
    echo "Extracted source directories:"
    echo "$SOURCE_DIRS" | while read -r dir; do
        echo "  - $(basename "$dir")"
    done
    echo ""
fi

echo "NEXT STEPS TO CREATE PATCHES:"
echo "------------------------------"
echo ""
echo "1. Navigate to the source directory:"
echo "   cd $OUT_DIR/source/<package-directory>"
echo ""
echo "2. Initialize git repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Original source'"
echo ""
echo "3. Make your changes to the code"
echo ""
echo "4. Commit your changes:"
echo "   git add ."
echo "   git commit -m 'Description of your fix/feature'"
echo ""
echo "5. Generate patch file:"
echo "   git format-patch -1 HEAD"
echo ""
echo "6. Move patch to the version-specific patches directory:"
echo "   mv *.patch $PATCHES_DIR/"
echo ""
echo "7. Build RPM with your patches:"
echo "   cd $SCRIPT_DIR"
echo "   ./docker-run.sh --ubi-version $UBI_VERSION $PACKAGE_NAME"
echo ""
echo "TIP: You can create multiple commits and generate multiple patches:"
echo "     git format-patch -<n> HEAD  # generates last n commits as patches"
echo ""
