# Quick Reference Guide

## One-Time Setup

```bash
# Build the Docker image for UBI 10 (default)
./docker-build.sh

# Build for UBI 9
./docker-build.sh --ubi-version 9

# Build for UBI 8
./docker-build.sh --ubi-version 8
```

## Two Workflows

### Workflow 1: Export → Analyze → Patch → Build

**Best for:** When you need to examine source code first

```bash
# 1. Export source code (also creates patches/<ubi-version>/<package-name>/ directory)
./docker-export-source.sh <package-name>
# Or for a specific UBI version:
./docker-export-source.sh --ubi-version 9 <package-name>

# 2. Navigate and analyze
cd out/source/<package-dir>/

# 3. Create patches
git init
git add . && git commit -m "Original"
# Make your changes...
git add . && git commit -m "My fix"
git format-patch -1 HEAD

# 4. Move patches to version-specific directory and build
mv *.patch ../../../patches/<ubi-version>/<package-name>/
cd ../../..
./docker-run.sh --ubi-version <ubi-version> <package-name>
```

### Workflow 2: Direct Build with Existing Patches

**Best for:** When you already have patch files

```bash
# 1. Create version-specific patches directory and add patches
mkdir -p ./patches/<ubi-version>/<package-name>
cp /path/to/*.patch ./patches/<ubi-version>/<package-name>/

# 2. Build Docker image for that UBI version (if not already built)
./docker-build.sh --ubi-version <ubi-version>

# 3. Build RPM
./docker-run.sh --ubi-version <ubi-version> <package-name>
```

## Common Commands

**Note:** Package name is REQUIRED for all commands (no default).

| Command | Purpose |
|---------|---------|
| `./docker-build.sh` | Build Docker image for UBI 10 (default) |
| `./docker-build.sh --ubi-version 9` | Build Docker image for UBI 9 |
| `./docker-build.sh --ubi-version 8` | Build Docker image for UBI 8 |
| `./docker-export-source.sh <package>` | Export source for UBI 10 (default) |
| `./docker-export-source.sh --ubi-version 9 <package>` | Export source for UBI 9 |
| `./docker-run.sh <package>` | Build RPM for UBI 10 (default) |
| `./docker-run.sh --ubi-version 9 <package>` | Build RPM for UBI 9 |
| `./docker-run.sh --export-only <package>` | Export source only |

Examples:
| Command | Purpose |
|---------|---------|
| `./docker-export-source.sh golang` | Export golang source (UBI 10) |
| `./docker-export-source.sh --ubi-version 9 python3` | Export python3 source (UBI 9) |
| `./docker-run.sh golang` | Build golang RPM (UBI 10) |
| `./docker-run.sh --ubi-version 8 nginx` | Build nginx RPM (UBI 8) |

## Directory Structure

```
redhat-remediations/
├── docker-build.sh              # Build Docker image
├── docker-export-source.sh      # Export source for analysis
├── docker-run.sh                # Build RPMs or export source
├── build-rpm.sh                 # Internal build script
├── Dockerfile                   # Container definition (supports UBI 8/9/10)
├── patches/                     # Version and package-specific patch directories
│   ├── 8/                       # Patches for UBI 8
│   │   └── <package-name>/
│   ├── 9/                       # Patches for UBI 9
│   │   └── <package-name>/
│   ├── 10/                      # Patches for UBI 10
│   │   └── golang/
│   │       └── *.patch
│   └── README.md
└── out/                         # Generated content (organized by UBI version)
    ├── 8/                       # UBI 8 artifacts
    │   ├── RPMS/
    │   ├── SRPMS/
    │   └── source/
    ├── 9/                       # UBI 9 artifacts
    │   ├── RPMS/
    │   ├── SRPMS/
    │   └── source/
    └── 10/                      # UBI 10 artifacts
        ├── RPMS/                # Built binary RPMs
        ├── SRPMS/               # Built source RPMs
        └── source/              # Exported source code
```

## Quick Examples

### Export and Analyze Source

```bash
./docker-export-source.sh golang
cd out/source/golang-*/
# Analyze the code...
```

### Create a Simple Patch

```bash
cd out/source/golang-*/
git init && git add . && git commit -m "Original"
echo "// My change" >> src/runtime/panic.go
git add . && git commit -m "Add debug comment"
git format-patch -1 HEAD
mv *.patch ../../../patches/10/golang/
```

### Build RPM

```bash
./docker-run.sh golang
ls -lh out/10/RPMS/x86_64/
```

### Build for Different UBI Versions

```bash
# Build golang for UBI 10
./docker-run.sh golang

# Build python3 for UBI 9
./docker-build.sh --ubi-version 9
./docker-run.sh --ubi-version 9 python3

# Build nginx for UBI 8
./docker-build.sh --ubi-version 8
./docker-run.sh --ubi-version 8 nginx
```

### Clean Up

```bash
# Remove all build artifacts
rm -rf out/

# Remove artifacts for a specific UBI version
rm -rf out/10/
rm -rf out/9/

# Remove patches for a specific package and version
rm patches/10/golang/*.patch

# Remove Docker images
docker rmi rpm-builder
docker rmi rpm-builder-ubi9
docker rmi rpm-builder-ubi8
```

## Flags and Options

### docker-export-source.sh
```bash
./docker-export-source.sh [--ubi-version <8|9|10>] <package-name> [image-tag]
```

### docker-run.sh
```bash
./docker-run.sh [--ubi-version <8|9|10>] [--export-only] <package-name> [image-tag]
```

### docker-build.sh
```bash
./docker-build.sh [--ubi-version <8|9|10>] [image-tag]
```

## Supported UBI Versions

| Version | RHEL Base | Image Tag (default) |
|---------|-----------|---------------------|
| 8       | RHEL 8    | rpm-builder-ubi8    |
| 9       | RHEL 9    | rpm-builder-ubi9    |
| 10      | RHEL 10   | rpm-builder         |

## Supported Packages

Any package available in Red Hat repositories:
- golang
- python3
- nginx
- httpd
- gcc
- kernel
- redis
- postgresql
- git
- vim
- And many more...

## Documentation Files

| File | Description |
|------|-------------|
| `README.md` | Complete project documentation |
| `PATCH_WORKFLOW.md` | Detailed workflow for creating patches |
| `USAGE_EXAMPLES.md` | Practical examples for various packages |
| `QUICK_REFERENCE.md` | This file - quick command reference |
| `patches/README.md` | Patch format and guidelines |

## Troubleshooting

### "No patches found"
```bash
# Create version-specific patches directory and add patches
mkdir -p ./patches/<ubi-version>/<package-name>
cp /path/to/*.patch ./patches/<ubi-version>/<package-name>/
```

### "Package not found"
```bash
# Verify package exists
docker run --rm rpm-builder bash -c "dnf search <package>"
```

### Patch won't apply
```bash
# Check patch format
cat patches/10/golang/0001-fix.patch | head -20
# Should be git format-patch format

# Ensure patch is for the correct UBI version
```

### Build fails
```bash
# Check build logs for errors
# Most common: missing dependencies or bad patches
```

## Tips

1. **Always export source first** if you're unsure what to patch
2. **One logical change per patch** - easier to manage
3. **Test patches locally** before building RPMs if possible
4. **Use descriptive commit messages** - they become patch descriptions
5. **Keep patches in version control** - track your modifications
6. **Use correct UBI version** - patches may differ between versions

## Getting Help

- Check `README.md` for comprehensive documentation
- See `PATCH_WORKFLOW.md` for step-by-step workflow
- Look at `USAGE_EXAMPLES.md` for package-specific examples
- Review `patches/README.md` for patch format details

## Quick Start (30 seconds)

```bash
# Setup (once)
./docker-build.sh

# Export source (creates patches/10/golang/ directory)
./docker-export-source.sh golang

# Create patch
cd out/source/golang-*/
git init && git add . && git commit -m "Original"
# Make changes...
git add . && git commit -m "Fix"
git format-patch -1 HEAD
mv *.patch ../../../patches/10/golang/

# Build
cd ../../..
./docker-run.sh golang

# Done!
ls out/10/RPMS/x86_64/
```
