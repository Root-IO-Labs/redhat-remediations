#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
EXPORT_ONLY=false
PACKAGE_NAME=""
PACKAGE_VERSION=""
SRPM_URL=""
SRPM_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --export-only|--source-only)
            EXPORT_ONLY=true
            shift
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
            PACKAGE_NAME="$1"
            shift
            ;;
    esac
done

# Require package name - no default
if [ -z "$PACKAGE_NAME" ]; then
    echo "ERROR: Package name is required"
    echo ""
    echo "Usage: $0 [--export-only] [--version <ver>] [--url <url>] [--srpm <file>] <package-name>"
    echo ""
    echo "Examples:"
    echo "  $0 golang                                    # Latest version from repos"
    echo "  $0 --version 2.2.5-17.el8_10 expat           # Specific version from repos"
    echo "  $0 --url http://example.com/pkg.src.rpm pkg  # Download from URL"
    echo "  $0 --srpm /srpm/expat-2.2.5.src.rpm expat    # Use local SRPM file (mounted)"
    echo "  $0 --export-only nginx"
    echo ""
    exit 1
fi

if [ "$EXPORT_ONLY" = true ]; then
    if [ -n "$SRPM_FILE" ]; then
        echo "==> Exporting source for package: $PACKAGE_NAME (local SRPM: $SRPM_FILE)"
    elif [ -n "$PACKAGE_VERSION" ]; then
        echo "==> Exporting source for package: $PACKAGE_NAME (version: $PACKAGE_VERSION)"
    else
        echo "==> Exporting source for package: $PACKAGE_NAME (latest)"
    fi
else
    if [ -n "$SRPM_FILE" ]; then
        echo "==> Building RPM for package: $PACKAGE_NAME (local SRPM: $SRPM_FILE)"
    elif [ -n "$PACKAGE_VERSION" ]; then
        echo "==> Building RPM for package: $PACKAGE_NAME (version: $PACKAGE_VERSION)"
    else
        echo "==> Building RPM for package: $PACKAGE_NAME (latest)"
    fi
fi
echo ""

# Setup rpmbuild tree (under /root)
# Use rpmdev-setuptree if available (UBI 9/10), otherwise create manually (UBI 8)
if command -v rpmdev-setuptree &> /dev/null; then
    rpmdev-setuptree
else
    echo "==> rpmdev-setuptree not available, creating rpmbuild tree manually..."
    mkdir -p /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
fi

cd /root

# Get SRPM - from local file, URL, or repos
if [ -n "$SRPM_FILE" ]; then
    # Use local SRPM file (mounted at /srpm/)
    echo "==> Using local SRPM file: $SRPM_FILE"
    if [ ! -f "$SRPM_FILE" ]; then
        echo ""
        echo "ERROR: SRPM file not found: $SRPM_FILE"
        echo "Make sure the file is mounted correctly."
        echo ""
        exit 1
    fi
    SRPM_TO_INSTALL="$SRPM_FILE"
elif [ -n "$SRPM_URL" ]; then
    # Download from provided URL
    echo "==> Downloading SRPM from URL: $SRPM_URL"
    SRPM_FILENAME=$(basename "$SRPM_URL")
    
    # Install curl if not available
    if ! command -v curl &> /dev/null; then
        echo "    Installing curl..."
        dnf -y install curl --quiet
    fi
    
    if ! curl -fSL -o "/root/$SRPM_FILENAME" "$SRPM_URL"; then
        echo ""
        echo "ERROR: Failed to download SRPM from URL"
        echo "URL: $SRPM_URL"
        echo ""
        exit 1
    fi
    SRPM_TO_INSTALL="/root/$SRPM_FILENAME"
else
    # Download from repos
    if [ -n "$PACKAGE_VERSION" ]; then
        # Full NVR format: package-version-release (e.g., expat-2.2.5-17.el8_10)
        DOWNLOAD_SPEC="${PACKAGE_NAME}-${PACKAGE_VERSION}"
        echo "==> Downloading specific version: $DOWNLOAD_SPEC SRPM..."
    else
        DOWNLOAD_SPEC="$PACKAGE_NAME"
        echo "==> Downloading latest $PACKAGE_NAME SRPM from enabled repos..."
    fi

    # Try to download the SRPM
    if ! dnf -y download --source "$DOWNLOAD_SPEC" 2>/dev/null; then
        echo ""
        echo "WARNING: Could not find '$DOWNLOAD_SPEC' in current repos."
        echo ""
        echo "Possible reasons:"
        echo "  1. The version is not available in the enabled repositories"
        echo "  2. The version string format is incorrect"
        echo "  3. The package may be in a vault/archive repository"
        echo ""
        echo "Tips:"
        echo "  - Check available versions: dnf list --showduplicates $PACKAGE_NAME"
        echo "  - Use --srpm to provide a local SRPM file"
        echo "  - Use --url to download from external sources (Koji, CentOS Vault)"
        echo "  - Format should be: <name>-<version>-<release> (e.g., expat-2.5.0-1.el8_10)"
        echo ""
        exit 1
    fi

    # Find the downloaded SRPM (handle both versioned and unversioned cases)
    SRPM_TO_INSTALL=$(ls -1 /root/${PACKAGE_NAME}-*.src.rpm 2>/dev/null | head -n1)
    if [ -z "$SRPM_TO_INSTALL" ]; then
        echo "ERROR: Could not find downloaded SRPM file"
        exit 1
    fi
fi

echo "==> Installing SRPM into rpmbuild tree..."
echo "    Found: $SRPM_TO_INSTALL"
rpm -ivh "$SRPM_TO_INSTALL"

spec="$(ls -1 /root/rpmbuild/SPECS/${PACKAGE_NAME}*.spec | head -n1)"
echo "==> Using spec: $spec"

# If export-only mode, extract source and exit
if [ "$EXPORT_ONLY" = true ]; then
    echo "==> Export-only mode: Extracting source without building..."

    # Extract the source tarball
    cd /root/rpmbuild/SOURCES

    # Find and extract the main source tarball
    for tarball in ${PACKAGE_NAME}-*.tar.* ${PACKAGE_NAME}_*.tar.*; do
        if [ -f "$tarball" ]; then
            echo "    Extracting $tarball..."
            tar -xf "$tarball" -C /root/rpmbuild/BUILD/ 2>/dev/null || true
        fi
    done

    # Copy everything to /out/source
    echo "==> Copying source to /out/source/..."
    mkdir -p /out/source

    # Copy extracted source
    if [ -d "/root/rpmbuild/BUILD" ] && [ "$(ls -A /root/rpmbuild/BUILD 2>/dev/null)" ]; then
        cp -av /root/rpmbuild/BUILD/* /out/source/ 2>/dev/null || true
    fi

    # Copy SPECS and SOURCES for reference
    mkdir -p /out/source/_rpm_metadata
    cp -av /root/rpmbuild/SPECS /out/source/_rpm_metadata/ || true
    cp -av /root/rpmbuild/SOURCES /out/source/_rpm_metadata/ || true

    echo ""
    echo "========================================="
    echo "==> Source exported successfully!"
    echo "========================================="
    echo ""
    echo "Source location: /out/source/"
    echo "Spec file: /out/source/_rpm_metadata/SPECS/"
    echo "Original tarballs: /out/source/_rpm_metadata/SOURCES/"
    echo ""
    echo "WORKFLOW TO CREATE PATCHES:"
    echo "---------------------------"
    echo "1. cd out/<ubi-version>/source/<package-dir>"
    echo "2. git init"
    echo "3. git add ."
    echo "4. git commit -m 'Original source'"
    echo "5. Make your changes to the code"
    echo "6. git add ."
    echo "7. git commit -m 'Description of your changes'"
    echo "8. git format-patch -1 HEAD"
    echo "9. mv *.patch ../../../patches/<ubi-version>/${PACKAGE_NAME}/"
    echo "10. cd ../../.."
    echo "11. ./docker-run.sh --ubi-version <ubi-version> ${PACKAGE_NAME}"
    echo ""
    exit 0
fi

# Ensure we actually have patches
shopt -s nullglob
patches=(/patches/*.patch)
if (( ${#patches[@]} == 0 )); then
  echo "ERROR: No patches found in /patches/*.patch"
  echo "       Put patch files under ./patches/<ubi-version>/<package-name>/ before running."
  exit 2
fi

echo "==> Copying patches into SOURCES..."
cp -v /patches/*.patch /root/rpmbuild/SOURCES/

# Add Patch tags near the top (after existing Patch/Source block is fine)
# Use Patch900+ to avoid collisions.
echo "==> Injecting Patch tags into spec..."
patchno=900
for p in "${patches[@]}"; do
  base="$(basename "$p")"
  # If spec already references it, skip
  if grep -qE "^[Pp]atch[0-9]+:\s*${base}\s*$" "$spec"; then
    echo "    - Spec already has patch tag for $base, skipping Patch tag insert"
  else
    # Insert after the last existing Patch/Source tag block (best-effort)
    # If none found, insert after Name/Version/Release block by appending after first "Release:".
    if grep -qE "^(Source|Patch)[0-9]*:" "$spec"; then
      awk -v add="Patch${patchno}: ${base}" '
        BEGIN{done=0}
        {lines[NR]=$0}
        END{
          last=0
          for(i=1;i<=NR;i++){
            if(lines[i] ~ /^(Source|Patch)[0-9]*:/) last=i
          }
          for(i=1;i<=NR;i++){
            print lines[i]
            if(i==last && done==0){
              print add
              done=1
            }
          }
          if(done==0){ print add }
        }' "$spec" > "${spec}.tmp" && mv "${spec}.tmp" "$spec"
    else
      # Fallback: add after first Release:
      awk -v add="Patch${patchno}: ${base}" '
        {print}
        !done && $0 ~ /^Release:/ {print add; done=1}
        END{ if(!done) print add }' "$spec" > "${spec}.tmp" && mv "${spec}.tmp" "$spec"
    fi
  fi
  ((patchno++))
done

# Apply patches in %prep
# - If spec uses %autosetup, patches are applied automatically
# - If spec uses %autopatch, patches are applied automatically by %autopatch
# - Otherwise, inject %patch900.. lines after %setup in %prep
echo "==> Ensuring patches are applied during %prep..."
if grep -qE '^\s*%autosetup' "$spec"; then
  echo "    Spec uses %autosetup - patches will be applied automatically"
  # Make sure autosetup isn't disabling patch application (-N). If it is, remove -N.
  sed -i -E 's/(^\s*%autosetup[^#\n]*)-N/\1/g' "$spec"
  # Ensure -p1 is present (safe default for git-format patches). If already has -p, leave it.
  if ! grep -qE '^\s*%autosetup.*-p[0-9]+' "$spec"; then
    sed -i -E 's/^\s*(%autosetup)(.*)$/\1 -p1\2/' "$spec"
  fi
elif grep -qE '^\s*%autopatch' "$spec"; then
  echo "    Spec uses %autopatch - patches will be applied automatically"
  # %autopatch applies all Patch* tags, so no manual %patch lines needed
  # Just ensure -p1 is present if not already set
  if ! grep -qE '^\s*%autopatch.*-p[0-9]+' "$spec"; then
    sed -i -E 's/^\s*(%autopatch)(.*)$/\1 -p1\2/' "$spec"
  fi
else
  echo "    Spec uses manual patching - injecting %patch lines..."
  # Insert %patch lines after the first %setup line inside %prep
  # Build the patch application block
  patch_block=""
  for n in $(seq 900 $((900 + ${#patches[@]} - 1))); do
    patch_block+=$'\n'"%patch${n} -p1"
  done

  # Insert after %setup in %prep (best effort: first occurrence)
  python3 - <<PY
import re, pathlib
spec_path = pathlib.Path("$spec")
txt = spec_path.read_text(encoding="utf-8")
m = re.search(r"(?ms)^%prep\\s*(.*?)^%build\\s", txt)
if not m:
    raise SystemExit("ERROR: Could not locate %prep..%build block to inject %patch lines")

prep_block = m.group(0)

# Find first %setup line within %prep
setup_m = re.search(r"(?m)^\\s*%setup\\b.*$", prep_block)
if not setup_m:
    raise SystemExit("ERROR: Spec does not use %autosetup and no %setup found in %prep")

inject = setup_m.group(0) + r'''$patch_block'''

new_prep = prep_block[:setup_m.start()] + inject + prep_block[setup_m.end():]
new_txt = txt[:m.start()] + new_prep + txt[m.end():]
spec_path.write_text(new_txt, encoding="utf-8")
PY
fi

# Note: Not bumping release version - keeping original NVR
# The patched RPM will have the same version as the original

# Check if xmlto is missing (common issue in UBI) - create stub script
if ! dnf list xmlto &> /dev/null; then
    echo ""
    echo "INFO: xmlto not available in repos - creating stub script"
    
    # Remove xmlto from BuildRequires in spec file
    sed -i '/^BuildRequires:.*xmlto/d' "$spec"
    
    # Create a stub xmlto script that creates empty/placeholder output files
    cat > /usr/local/bin/xmlto << 'STUB'
#!/bin/bash
# Stub xmlto - creates empty output when real xmlto is unavailable
# Usage: xmlto <format> <input.xml>
format="$1"
input="$2"
output="${input%.xml}"

case "$format" in
    man)
        # Create a minimal man page
        output="${output}.1"
        echo ".TH \"${output}\" 1" > "$output"
        echo ".SH NAME" >> "$output"
        echo "${output} - documentation unavailable (xmlto not installed)" >> "$output"
        ;;
    html|html-nochunks)
        output="${output}.html"
        echo "<html><body><p>Documentation unavailable - xmlto not installed</p></body></html>" > "$output"
        ;;
    *)
        touch "${output}.${format}" 2>/dev/null || touch "$output"
        ;;
esac
exit 0
STUB
    chmod +x /usr/local/bin/xmlto
    
    echo "    Created stub xmlto script at /usr/local/bin/xmlto"
    
    # Also disable any doc-related bcond if the spec supports it
    BUILD_OPTS="--without doc --without docs --without xmlto"
fi

echo "==> Installing build dependencies..."
# Try to install build deps
if ! dnf -y builddep "$spec" 2>&1; then
    echo ""
    echo "WARNING: Some build dependencies could not be installed."
    echo "Attempting to install available dependencies and skip unavailable ones..."
    
    # Extract BuildRequires from spec and try to install what's available
    grep -E "^BuildRequires:" "$spec" | sed 's/BuildRequires:\s*//' | tr ',' '\n' | while read -r dep; do
        # Clean up the dependency name (remove version constraints)
        dep_name=$(echo "$dep" | sed 's/[<>=].*//' | xargs)
        if [ -n "$dep_name" ]; then
            dnf -y install "$dep_name" 2>/dev/null || echo "    Skipping unavailable: $dep_name"
        fi
    done
fi

echo "==> Building RPMs..."
rpmbuild -ba ${BUILD_OPTS:-} "$spec"

echo "==> Copying artifacts to /out..."
mkdir -p /out
cp -av /root/rpmbuild/RPMS /out/ || true
cp -av /root/rpmbuild/SRPMS /out/ || true

echo "==> Done. Artifacts are in /out (mount a volume to collect them)."
