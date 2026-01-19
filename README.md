# Generic RPM Builder with Custom Patches

This project provides a containerized build environment for rebuilding any Red Hat package SRPM with custom patches applied. It supports multiple UBI (Universal Base Image) versions: **UBI 8, 9, and 10**.

## Overview

The builder:
1. Downloads any specified package SRPM from Red Hat repositories
2. Applies your custom patches
3. Rebuilds the RPMs with modifications
4. Outputs the resulting RPM artifacts

**Supports any package**: golang, python3, nginx, httpd, kernel, gcc, and more!

**Supports multiple UBI versions**: 8, 9, 10 (default: 10)

## Project Structure

```
.
├── Dockerfile                  # Default container (UBI 10)
├── Dockerfile.ubi8             # UBI 8 specific container
├── Dockerfile.ubi9             # UBI 9 specific container
├── Dockerfile.ubi10            # UBI 10 specific container
├── build-rpm.sh               # Main build script (runs inside container)
├── docker-build.sh            # Helper script to build the Docker image
├── docker-run.sh              # Helper script to run the builder
├── docker-export-source.sh    # Helper script to export source for analysis
├── patches/                   # Version and package-specific patch directories
│   ├── 8/                    # Patches for UBI 8
│   │   ├── golang/
│   │   └── <package-name>/
│   ├── 9/                    # Patches for UBI 9
│   │   ├── golang/
│   │   └── <package-name>/
│   └── 10/                   # Patches for UBI 10
│       ├── golang/
│       │   └── *.patch
│       └── <package-name>/
│           └── *.patch
├── out/                       # Build artifacts output directory (created at runtime)
│   ├── 8/                    # Artifacts for UBI 8
│   │   ├── RPMS/
│   │   ├── SRPMS/
│   │   └── source/
│   ├── 9/                    # Artifacts for UBI 9
│   │   ├── RPMS/
│   │   ├── SRPMS/
│   │   └── source/
│   └── 10/                   # Artifacts for UBI 10
│       ├── RPMS/             # Built binary RPMs
│       ├── SRPMS/            # Built source RPMs
│       └── source/           # Exported source (when using --export-only)
└── README.md                  # This file
```

## Prerequisites

- Docker installed and running
- Bash shell (macOS, Linux, or WSL on Windows)
- Your custom patch files in git format-patch format

## Quick Start

### Option A: Start with Existing Patches

If you already have patch files:

```bash
# 1. Build the image (only needed once)
./docker-build.sh                        # Builds UBI 10 (default)
./docker-build.sh --ubi-version 9        # Builds UBI 9

# 2. Create version-specific patches directory and add your patches
mkdir -p ./patches/10/golang
cp /path/to/your/fixes/*.patch ./patches/10/golang/

# 3. Build the RPM
./docker-run.sh golang                   # Uses UBI 10 (default)
./docker-run.sh --ubi-version 9 golang   # Uses UBI 9
```

### Option B: Export Source, Create Patches, Then Build

If you need to analyze the source and create patches:

```bash
# 1. Build the image (only needed once)
./docker-build.sh

# 2. Export the source code (also creates patches/<ubi-version>/golang/ directory)
./docker-export-source.sh golang
# Or for a specific UBI version:
./docker-export-source.sh --ubi-version 9 golang

# 3. Analyze and modify the source in out/source/
cd out/source/golang-*/

# 4. Create git commits and generate patches
git init
git add .
git commit -m "Original source"
# Make your changes...
git add .
git commit -m "My fix"
git format-patch -1 HEAD

# 5. Move patches to the version-specific directory and build
mv *.patch ../../../patches/10/golang/
cd ../../..
./docker-run.sh golang
```

**Note:** Patches should be in `git format-patch` format with `-p1` strip level.

## Building for Different UBI Versions

### Build Docker Images

```bash
# Build for UBI 10 (default)
./docker-build.sh

# Build for UBI 9
./docker-build.sh --ubi-version 9

# Build for UBI 8
./docker-build.sh --ubi-version 8

# With custom tag
./docker-build.sh --ubi-version 9 my-custom-builder
```

### Run the Builder

```bash
# Build golang for UBI 10 (default)
./docker-run.sh golang

# Build golang for UBI 9
./docker-run.sh --ubi-version 9 golang

# Build python3 for UBI 8
./docker-run.sh --ubi-version 8 python3
```

## Exporting Source Code for Analysis

To export and analyze source code before creating patches:

```bash
# Export source for UBI 10 (default)
./docker-export-source.sh golang

# Export source for UBI 9
./docker-export-source.sh --ubi-version 9 golang

# Export source for UBI 8
./docker-export-source.sh --ubi-version 8 python3
```

Or using docker-run.sh with --export-only flag:
```bash
./docker-run.sh --export-only golang
./docker-run.sh --ubi-version 9 --export-only golang
```

The source will be exported to `out/<ubi-version>/source/` with:
- Extracted source code
- `_rpm_metadata/SPECS/` - Original spec files
- `_rpm_metadata/SOURCES/` - Original source tarballs and patches

## Manual Usage

If you prefer not to use the helper scripts:

### Build the image:
```bash
# UBI 10 (default)
docker build -t rpm-builder .
# Or explicitly:
docker build -f Dockerfile.ubi10 -t rpm-builder .

# UBI 9
docker build -f Dockerfile.ubi9 -t rpm-builder-ubi9 .

# UBI 8
docker build -f Dockerfile.ubi8 -t rpm-builder-ubi8 .
```

### Run the builder:
```bash
# Build golang for UBI 10 (mount version-specific patches and output directories)
docker run --rm \
    -v "$PWD/out/10:/out" \
    -v "$PWD/patches/10/golang:/patches:ro" \
    rpm-builder golang

# Build golang for UBI 9
docker run --rm \
    -v "$PWD/out/9:/out" \
    -v "$PWD/patches/9/golang:/patches:ro" \
    rpm-builder-ubi9 golang

# Build python3 for UBI 8
docker run --rm \
    -v "$PWD/out/8:/out" \
    -v "$PWD/patches/8/python3:/patches:ro" \
    rpm-builder-ubi8 python3

# Export source only (no patches needed)
docker run --rm -v "$PWD/out/10:/out" rpm-builder --export-only golang
```

## How It Works

### Build Process

1. **SRPM Download**: Downloads the specified package SRPM from enabled repositories
2. **Setup**: Installs the SRPM and extracts the spec file
3. **Patch Injection**:
   - Copies your patches to the RPM SOURCES directory
   - Adds `Patch900+` tags to the spec file
   - Configures `%prep` section to apply patches
4. **Build**: Installs build dependencies and builds the RPMs
5. **Output**: Copies RPMS and SRPMS to `/out` directory

### Patch Numbering

- Your patches are assigned numbers starting at 900 (Patch900, Patch901, etc.)
- This avoids conflicts with existing patches in the package spec file

### Spec File Handling

The builder supports two common spec file styles:
- **%autosetup**: Automatically applies Patch tags
- **%setup with %patch**: Manually applies each patch

## Troubleshooting

### No patches found error

```
ERROR: No patches found in /patches/*.patch
```

**Solution:** Add `.patch` files to the version-specific patches directory:
```bash
mkdir -p ./patches/<ubi-version>/<package-name>
cp /path/to/your/*.patch ./patches/<ubi-version>/<package-name>/
```

### Build fails with patch errors

**Common causes:**
- Patch format incorrect (must be git format-patch compatible)
- Patch strip level mismatch (patches should use `-p1`)
- Patch already applied in upstream package

**Solution:** Review your patches and ensure they're formatted correctly:
```bash
git format-patch -1 <commit-hash>
```

### RPM build dependencies fail

**Cause:** The package spec requires dependencies not available in your repositories.

**Solution:** Ensure your system has access to required RHEL/UBI repositories or modify the Dockerfile to enable additional repos.

### Package not found

```
ERROR: No package <name> available.
```

**Cause:** The specified package doesn't exist in enabled repositories or is spelled incorrectly.

**Solution:**
- Verify the package name: `dnf search <package-name>`
- Check available SRPMs: `dnf list available --source | grep <package>`
- Ensure required repositories are enabled

### Wrong UBI version

**Cause:** Using patches intended for a different UBI version.

**Solution:** Ensure you're using the correct UBI version for your patches:
- Check your patches are in the correct directory: `./patches/<ubi-version>/<package>/`
- Build the correct Docker image: `./docker-build.sh --ubi-version <version>`
- Run with the correct version: `./docker-run.sh --ubi-version <version> <package>`

## Advanced Configuration

### Customizing the Base Image

Each UBI version has its own Dockerfile with version-specific package configurations:

```bash
# Use the version-specific Dockerfile
docker build -f Dockerfile.ubi8 -t rpm-builder-ubi8 .
docker build -f Dockerfile.ubi9 -t rpm-builder-ubi9 .
docker build -f Dockerfile.ubi10 -t rpm-builder .
```

Note: Package availability differs between UBI versions. For example, `rpmdevtools` is not available in UBI 8's default repositories.

### Modifying Build Options

Edit `build-rpm.sh` to customize:
- RPM build flags (line with `rpmbuild -ba`)
- Patch numbering start (currently 900)
- Spec file modifications

### Adding Additional Build Tools

Add packages to the Dockerfile's `RUN dnf install` section:

```dockerfile
RUN dnf -y update && \
    dnf -y install \
      rpm-build rpmdevtools dnf-plugins-core \
      gcc gcc-c++ make git which file findutils \
      diffutils patch tar gzip bzip2 xz \
      python3 \
      your-additional-package && \
    dnf -y clean all
```

## Files Generated

After a successful build, the `out/` directory will contain version-specific subdirectories:

- `out/<ubi-version>/RPMS/x86_64/<package>-*.rpm` - Binary RPM packages
- `out/<ubi-version>/RPMS/noarch/<package>-*.rpm` - Architecture-independent packages (if applicable)
- `out/<ubi-version>/SRPMS/<package>-*.src.rpm` - Source RPM with your patches

Example for golang on UBI 10:
- `out/10/RPMS/x86_64/golang-1.20.10-1.el10.x86_64.rpm`
- `out/10/SRPMS/golang-1.20.10-1.el10.src.rpm`

Example for golang on UBI 9:
- `out/9/RPMS/x86_64/golang-1.19.6-1.el9.x86_64.rpm`
- `out/9/SRPMS/golang-1.19.6-1.el9.src.rpm`

## Clean Up

To remove build artifacts:

```bash
# Remove all build artifacts
rm -rf out/

# Remove artifacts for a specific UBI version
rm -rf out/10/
rm -rf out/9/
rm -rf out/8/
```

To remove Docker images:

```bash
docker rmi rpm-builder
docker rmi rpm-builder-ubi9
docker rmi rpm-builder-ubi8
```

## License

This build tooling is provided as-is. Ensure you comply with Red Hat's licensing for the packages you build and any patches you apply.

## Contributing

To improve this builder:

1. Modify the relevant scripts
2. Test your changes
3. Document any new features in this README

## Support

For issues with:
- **This builder**: Check the troubleshooting section above
- **Package-specific patches**: Consult the relevant package documentation
- **RPM building**: Reference RPM packaging guides
- **Red Hat packages**: Contact Red Hat support

## Common Use Cases

### Building golang with custom patches for UBI 10
```bash
./docker-run.sh golang
```

### Building python3 for UBI 9
```bash
./docker-build.sh --ubi-version 9
./docker-run.sh --ubi-version 9 python3
```

### Building nginx for UBI 8
```bash
./docker-build.sh --ubi-version 8
./docker-run.sh --ubi-version 8 nginx
```

### Building kernel with security patches
```bash
./docker-run.sh kernel
```
*Note: Kernel builds may take significantly longer*
