# Usage Examples

This document provides practical examples of using the generic RPM builder for various packages across different UBI versions (8, 9, 10).

## Basic Usage

The builder accepts any package name and supports multiple UBI versions:

```bash
./docker-run.sh [--ubi-version <8|9|10>] <package-name>
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `./docker-build.sh` | Build Docker image for UBI 10 (default) |
| `./docker-build.sh --ubi-version 9` | Build Docker image for UBI 9 |
| `./docker-build.sh --ubi-version 8` | Build Docker image for UBI 8 |
| `./docker-run.sh golang` | Build golang RPM for UBI 10 |
| `./docker-run.sh --ubi-version 9 python3` | Build python3 RPM for UBI 9 |
| `./docker-run.sh --ubi-version 8 nginx` | Build nginx RPM for UBI 8 |

## Examples by Package Type

### 1. Building golang

```bash
# Build the image (one-time)
./docker-build.sh

# Create version-specific patches directory and add patches
mkdir -p ./patches/10/golang
cp my-golang-fixes/*.patch ./patches/10/golang/

# Run the builder for golang
./docker-run.sh golang

# Check the output
ls -lh out/10/RPMS/x86_64/golang*.rpm
```

### 2. Building python3

```bash
# Create version-specific patches directory and add patches
mkdir -p ./patches/10/python3
cp python-backports/*.patch ./patches/10/python3/

# Run the builder
./docker-run.sh python3

# Install the patched Python
sudo rpm -Uvh out/RPMS/x86_64/python3*.rpm
```

### 3. Building nginx

```bash
# Create version-specific patches directory and add patches
mkdir -p ./patches/10/nginx
cp nginx-module-patches/*.patch ./patches/10/nginx/

# Run the builder
./docker-run.sh nginx

# Output will be in out/RPMS/
```

### 4. Building gcc (compiler)

```bash
# Create version-specific patches directory and add patches
mkdir -p ./patches/10/gcc
cp gcc-optimization-patches/*.patch ./patches/10/gcc/

# Run the builder (will take longer)
./docker-run.sh gcc

# Note: GCC builds typically take 30+ minutes
```

### 5. Building httpd (Apache)

```bash
# Create version-specific patches directory and add patches
mkdir -p ./patches/10/httpd
cp apache-security-patches/*.patch ./patches/10/httpd/

# Run the builder
./docker-run.sh httpd
```

### 6. Building kernel (Advanced)

```bash
# Create version-specific patches directory and add patches
mkdir -p ./patches/10/kernel
cp kernel-security-patches/*.patch ./patches/10/kernel/

# Run the builder (may take 1-2 hours)
./docker-run.sh kernel

# Kernel RPMs will be architecture-specific
ls -lh out/10/RPMS/x86_64/kernel*.rpm
```

## Building for Different UBI Versions

### UBI 10 (Default)

```bash
# Build Docker image
./docker-build.sh

# Build golang
./docker-run.sh golang

# Patches are in: patches/10/golang/
```

### UBI 9

```bash
# Build Docker image for UBI 9
./docker-build.sh --ubi-version 9

# Create patches for UBI 9
mkdir -p ./patches/9/golang
cp my-patches/*.patch ./patches/9/golang/

# Build golang for UBI 9
./docker-run.sh --ubi-version 9 golang
```

### UBI 8

```bash
# Build Docker image for UBI 8
./docker-build.sh --ubi-version 8

# Create patches for UBI 8
mkdir -p ./patches/8/golang
cp my-patches/*.patch ./patches/8/golang/

# Build golang for UBI 8
./docker-run.sh --ubi-version 8 golang
```

## Switching Between Packages and Versions

Each package has its own version-specific patches directory, so you can easily switch:

```bash
# Build golang for UBI 10 (uses patches/10/golang/)
./docker-run.sh golang

# Build python3 for UBI 10 (uses patches/10/python3/)
./docker-run.sh python3

# Build golang for UBI 9 (uses patches/9/golang/)
./docker-run.sh --ubi-version 9 golang

# No need to clean up between builds!
```

## Building Same Package for Multiple UBI Versions

```bash
# Build Docker images for all versions
./docker-build.sh                     # UBI 10
./docker-build.sh --ubi-version 9     # UBI 9
./docker-build.sh --ubi-version 8     # UBI 8

# Create patches for each version (may differ due to source differences)
mkdir -p ./patches/10/golang ./patches/9/golang ./patches/8/golang

# Build for each version
./docker-run.sh golang                     # UBI 10
./docker-run.sh --ubi-version 9 golang     # UBI 9
./docker-run.sh --ubi-version 8 golang     # UBI 8
```

## Automation Example

Build multiple packages for multiple UBI versions:

```bash
#!/bin/bash
# build-all.sh

UBI_VERSIONS=("8" "9" "10")
PACKAGES=("golang" "python3" "nginx")

# Build Docker images for all versions
for ver in "${UBI_VERSIONS[@]}"; do
    echo "Building Docker image for UBI $ver..."
    ./docker-build.sh --ubi-version "$ver"
done

# Build packages for each version
for ver in "${UBI_VERSIONS[@]}"; do
    for pkg in "${PACKAGES[@]}"; do
        # Check if patches exist for this version/package
        if [ -d "patches/$ver/$pkg" ] && [ "$(ls -A patches/$ver/$pkg/*.patch 2>/dev/null)" ]; then
            echo "Building $pkg for UBI $ver..."
            ./docker-run.sh --ubi-version "$ver" "$pkg"
            
            # Output is automatically in out/$ver/
            echo "Artifacts are in out/$ver/"
        else
            echo "Skipping $pkg for UBI $ver (no patches found)"
        fi
    done
done
```

## Parallel Builds

Build for different UBI versions in parallel (requires adequate system resources):

```bash
# Build golang for UBI 10 in the background
./docker-run.sh golang &
PID1=$!

# Build golang for UBI 9 in the background
./docker-run.sh --ubi-version 9 golang &
PID2=$!

# Wait for both to complete
wait $PID1
wait $PID2

echo "Both builds complete!"
```

## Manual Docker Usage

If you prefer direct Docker commands:

```bash
# Build the images using version-specific Dockerfiles
docker build -f Dockerfile.ubi10 -t rpm-builder .
docker build -f Dockerfile.ubi9 -t rpm-builder-ubi9 .
docker build -f Dockerfile.ubi8 -t rpm-builder-ubi8 .

# Run for specific package and version (mount version-specific patches and output directories)
# UBI 10
docker run --rm \
    -v "$PWD/out/10:/out" \
    -v "$PWD/patches/10/golang:/patches:ro" \
    rpm-builder golang

# UBI 9
docker run --rm \
    -v "$PWD/out/9:/out" \
    -v "$PWD/patches/9/golang:/patches:ro" \
    rpm-builder-ubi9 golang

# UBI 8
docker run --rm \
    -v "$PWD/out/8:/out" \
    -v "$PWD/patches/8/golang:/patches:ro" \
    rpm-builder-ubi8 golang

# Export source only (no patches needed)
docker run --rm -v "$PWD/out/10:/out" rpm-builder --export-only golang
```

## Troubleshooting Package-Specific Issues

### Package not available

```bash
# Check if package exists in repos for specific UBI version
docker run --rm rpm-builder bash -c "dnf search <package>"
docker run --rm rpm-builder-ubi9 bash -c "dnf search <package>"
docker run --rm rpm-builder-ubi8 bash -c "dnf search <package>"
```

### Build dependencies missing

```bash
# Check what dependencies are needed
docker run --rm rpm-builder bash -c "dnf builddep --assumeno <package>"
```

### Verify patches apply correctly

```bash
# Run a dry-run (modify build-rpm.sh temporarily to exit after patch)
# Or manually test in container:
docker run -it --rm \
    -v "$PWD/patches/10/golang:/patches:ro" \
    rpm-builder bash

# Inside container:
# dnf -y download --source <package>
# rpm -ivh <package>*.src.rpm
# cd /root/rpmbuild/BUILD/<extracted-source>
# patch -p1 --dry-run < /patches/0001-my-patch.patch
```

### Patch doesn't apply to different UBI version

```bash
# Patches for UBI 10 may not work on UBI 9 or 8
# Export source for the target version and create new patches

./docker-export-source.sh --ubi-version 9 golang
cd out/source/golang-*/
# Create patches specific to UBI 9 source
```

## Best Practices

1. **Test patches locally first** before building in container
2. **One package at a time** - clear patches between builds
3. **Version control your patches** - keep them in git
4. **Document patch purpose** - use descriptive commit messages
5. **Clean output directory** between builds to avoid confusion
6. **Use consistent naming** - `0001-description.patch`, `0002-description.patch`
7. **Test on target UBI version** - patches may differ between versions

## Output Structure

After building, your `out/` directory will be organized by UBI version:

```
out/
├── 8/                          # UBI 8 artifacts
│   ├── RPMS/
│   │   └── x86_64/
│   ├── SRPMS/
│   └── source/
├── 9/                          # UBI 9 artifacts
│   ├── RPMS/
│   │   └── x86_64/
│   ├── SRPMS/
│   └── source/
└── 10/                         # UBI 10 artifacts
    ├── RPMS/
    │   ├── x86_64/
    │   │   ├── <package>-<version>.x86_64.rpm
    │   │   └── <package>-devel-<version>.x86_64.rpm
    │   └── noarch/
    │       └── <package>-docs-<version>.noarch.rpm
    ├── SRPMS/
    │   └── <package>-<version>.src.rpm
    └── source/                  # Exported source (when using --export-only)
```

## Common Packages to Build

| Package | Use Case | Typical Build Time |
|---------|----------|-------------------|
| `golang` | Go programming language | 5-10 min |
| `python3` | Python interpreter | 10-15 min |
| `nginx` | Web server | 3-5 min |
| `httpd` | Apache web server | 5-8 min |
| `gcc` | Compiler | 30-60 min |
| `kernel` | Linux kernel | 60-120 min |
| `redis` | In-memory database | 3-5 min |
| `postgresql` | SQL database | 15-20 min |
| `git` | Version control | 5-8 min |
| `vim` | Text editor | 3-5 min |

*Times are approximate and depend on system resources*

## UBI Version Comparison

| Feature | UBI 8 | UBI 9 | UBI 10 |
|---------|-------|-------|--------|
| RHEL Base | 8.x | 9.x | 10.x |
| Default Image | rpm-builder-ubi8 | rpm-builder-ubi9 | rpm-builder |
| Python Default | 3.6 | 3.9 | 3.11+ |
| Golang Default | 1.18 | 1.19 | 1.20+ |

*Package versions vary; check specific repositories for exact versions*
