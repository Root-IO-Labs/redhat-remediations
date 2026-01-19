# Complete Workflow: From Source Analysis to RPM Build

This guide walks you through the complete process of exporting source code, analyzing it, creating patches, and building patched RPMs. Supports UBI versions 8, 9, and 10.

## Table of Contents

1. [Export Source Code](#1-export-source-code)
2. [Analyze the Source](#2-analyze-the-source)
3. [Create Your Changes](#3-create-your-changes)
4. [Generate Patches](#4-generate-patches)
5. [Build RPMs with Patches](#5-build-rpms-with-patches)
6. [Test and Iterate](#6-test-and-iterate)

---

## 1. Export Source Code

First, export the source code for the package you want to modify:

```bash
# Build the Docker image (one-time setup)
./docker-build.sh                        # UBI 10 (default)
./docker-build.sh --ubi-version 9        # UBI 9
./docker-build.sh --ubi-version 8        # UBI 8

# Export source for analysis
./docker-export-source.sh golang                      # UBI 10 (default)
./docker-export-source.sh --ubi-version 9 golang      # UBI 9
./docker-export-source.sh --ubi-version 8 golang      # UBI 8
```

Or use the alternative command:
```bash
./docker-run.sh --export-only golang
./docker-run.sh --ubi-version 9 --export-only golang
```

This will create version-specific output:
```
out/
└── 10/                         # UBI version
    └── source/
        ├── golang-1.20.10/     # Extracted source code
        └── _rpm_metadata/
            ├── SPECS/          # RPM spec files
            └── SOURCES/        # Original tarballs and patches
```

## 2. Analyze the Source

Navigate to the exported source and examine it:

```bash
cd out/10/source/golang-1.20.10/

# Browse the source code
ls -la

# Find specific files
find . -name "*.go" | grep -i "runtime"

# Search for specific code patterns
grep -r "func main" .

# Read important files
cat README.md
cat VERSION
```

## 3. Create Your Changes

### Step 3.1: Initialize Git Repository

Initialize git to track your changes:

```bash
cd out/10/source/golang-1.20.10/

git init
git add .
git commit -m "Original golang source from SRPM"
```

### Step 3.2: Create a Branch (Optional but Recommended)

```bash
git checkout -b my-security-fix
```

### Step 3.3: Make Your Changes

Edit the files you need to modify:

```bash
# Example: Fix a security issue
vim src/runtime/panic.go

# Example: Add a feature
vim src/net/http/server.go

# Example: Update documentation
vim README.md
```

### Step 3.4: Test Your Changes Locally (if possible)

If you can test locally:

```bash
# For golang
./make.bash
./bin/go version

# For python
./configure && make
./python --version
```

### Step 3.5: Commit Your Changes

Commit each logical change separately:

```bash
# First fix
git add src/runtime/panic.go
git commit -m "Fix panic handling in runtime

This patch fixes CVE-2024-XXXXX by properly handling
panic conditions in the runtime package."

# Second fix
git add src/net/http/server.go
git commit -m "Add timeout handling for HTTP server

Adds configurable timeout support to prevent
resource exhaustion attacks."
```

**Best Practices for Commit Messages:**
- Use clear, descriptive subject lines
- Add detailed explanations in the body
- Reference CVE numbers or issue IDs if applicable
- Explain WHY the change is needed, not just WHAT changed

## 4. Generate Patches

### Step 4.1: Review Your Commits

```bash
# View commit history
git log --oneline

# View detailed changes
git log -p

# View specific commit
git show <commit-hash>
```

### Step 4.2: Generate Patch Files

Generate patches from your commits:

```bash
# Generate patch from the last commit
git format-patch -1 HEAD

# Generate patches from the last 3 commits
git format-patch -3 HEAD

# Generate all patches since original commit
git format-patch HEAD~2

# Generate with specific naming
git format-patch -1 HEAD -o patches/
```

This creates files like:
```
0001-Fix-panic-handling-in-runtime.patch
0002-Add-timeout-handling-for-HTTP-server.patch
```

### Step 4.3: Review Generated Patches

```bash
# View patch content
cat 0001-Fix-panic-handling-in-runtime.patch

# Verify patch can be applied
git apply --check 0001-Fix-panic-handling-in-runtime.patch
```

### Step 4.4: Move Patches to Build Directory

```bash
# From the source directory, move to version-specific patches folder
# For UBI 10:
mv *.patch ../../../patches/10/<package-name>/

# For UBI 9:
mv *.patch ../../../patches/9/<package-name>/

# For UBI 8:
mv *.patch ../../../patches/8/<package-name>/
```

## 5. Build RPMs with Patches

### Step 5.1: Verify Patches Are in Place

```bash
cd /path/to/redhat-remediations
ls -lh patches/10/golang/
```

You should see your patches in the version-specific directory:
```
patches/10/golang/0001-Fix-panic-handling-in-runtime.patch
patches/10/golang/0002-Add-timeout-handling-for-HTTP-server.patch
```

### Step 5.2: Build the RPMs

```bash
# Build for UBI 10 (default)
./docker-run.sh golang

# Build for UBI 9
./docker-run.sh --ubi-version 9 golang

# Build for UBI 8
./docker-run.sh --ubi-version 8 golang
```

The build process will:
1. Download the golang SRPM
2. Extract it
3. Apply your patches (Patch900, Patch901, etc.)
4. Build the RPMs
5. Output to `out/RPMS/` and `out/SRPMS/`

### Step 5.3: Monitor the Build

Watch for:
- **Patch application**: Should see "Applying: Patch900", "Applying: Patch901"
- **Build errors**: Fix any compilation issues
- **Warnings**: Review and address if critical

### Step 5.4: Collect the Built RPMs

```bash
ls -lh out/10/RPMS/x86_64/
ls -lh out/10/SRPMS/
```

## 6. Test and Iterate

### Step 6.1: Install and Test the RPMs

```bash
# Install the built RPM
sudo rpm -Uvh out/10/RPMS/x86_64/golang-*.rpm

# Test the installation
go version
go run hello.go
```

### Step 6.2: If Changes Are Needed

If you need to make additional changes:

```bash
# Go back to source directory
cd out/10/source/golang-1.20.10/

# Make more changes
vim src/runtime/panic.go

# Commit the changes
git add .
git commit -m "Additional fix for edge case"

# Generate new patches (overwrites old ones)
git format-patch HEAD~3  # Generates all 3 patches

# Move to version-specific patches directory
mv *.patch ../../../patches/10/golang/

# Rebuild
cd ../../..
./docker-run.sh golang
```

### Step 6.3: Iterate Until Perfect

Repeat the cycle:
1. Modify source
2. Commit changes
3. Generate patches
4. Build RPMs
5. Test
6. Repeat if needed

---

## Complete Example: Adding a Security Fix to Golang

### Scenario
You need to fix a security vulnerability in golang's runtime package for UBI 10.

### Step-by-Step

```bash
# 1. Export source
./docker-export-source.sh golang

# 2. Navigate to source
cd out/10/source/golang-1.20.10/

# 3. Initialize git
git init
git add .
git commit -m "Original golang 1.20.10 source"

# 4. Create a branch
git checkout -b security-fix-cve-2024-12345

# 5. Make the fix
vim src/runtime/panic.go
# ... make your changes ...

# 6. Test locally (if possible)
cd src
./make.bash
cd ..

# 7. Commit the fix
git add src/runtime/panic.go
git commit -m "Fix CVE-2024-12345 in runtime panic handling

This patch addresses a security vulnerability where panic
conditions could lead to information disclosure.

The fix ensures that panic messages are properly sanitized
before being displayed or logged.

CVE-2024-12345
Severity: High"

# 8. Generate patch
git format-patch -1 HEAD

# 9. Move patch to version-specific patches directory
mv 0001-Fix-CVE-2024-12345-in-runtime-panic-handling.patch ../../../patches/10/golang/

# 10. Build the RPM
cd ../../..
./docker-run.sh golang

# 11. Verify the patch was applied
# Check build logs for "Applying: Patch900"

# 12. Test the built RPM
sudo rpm -Uvh out/10/RPMS/x86_64/golang-*.rpm
go version

# 13. Verify the fix
# Test that the vulnerability is fixed
go run test-cve-2024-12345.go
```

---

## Building for Multiple UBI Versions

If you need the same fix for multiple UBI versions, you may need different patches:

```bash
# Export source for each UBI version
./docker-export-source.sh --ubi-version 10 golang
# Create patches in patches/10/golang/

./docker-export-source.sh --ubi-version 9 golang
# Create patches in patches/9/golang/

./docker-export-source.sh --ubi-version 8 golang
# Create patches in patches/8/golang/

# Build for each version
./docker-run.sh --ubi-version 10 golang
./docker-run.sh --ubi-version 9 golang
./docker-run.sh --ubi-version 8 golang
```

**Note:** Package versions differ between UBI versions, so patches that work on UBI 10 may not apply cleanly to UBI 8 or 9.

---

## Tips and Best Practices

### Patch Creation
- **One logical change per commit**: Easier to review and revert
- **Descriptive commit messages**: Explain WHY, not just WHAT
- **Reference issues/CVEs**: Include ticket numbers or CVE IDs
- **Test before patching**: Verify changes work locally if possible

### Naming Conventions
```bash
# Good patch names
0001-Fix-CVE-2024-12345-memory-leak.patch
0002-Add-timeout-parameter-to-http-client.patch
0003-Update-documentation-for-new-API.patch

# Avoid generic names
0001-fix.patch
0002-changes.patch
```

### Managing Multiple Patches

If you have many patches:

```bash
# In source directory with multiple commits
git log --oneline
# Shows:
# abc123 Add feature C
# def456 Add feature B
# ghi789 Add feature A

# Generate all patches at once
git format-patch <commit-before-your-changes>

# Or specific range
git format-patch ghi789^..abc123
```

### Cleaning Up

```bash
# Remove old patches for a specific package and version before generating new ones
rm patches/10/golang/*.patch

# Clean source directory to start fresh
rm -rf out/10/source/

# Clean build artifacts for UBI 10
rm -rf out/10/RPMS/ out/10/SRPMS/

# Or clean all artifacts
rm -rf out/
```

### Version Control for Patches

Keep your patches in version control:

```bash
# In your redhat-remediations directory
git add patches/10/golang/*.patch
git commit -m "Add security fixes for golang (UBI 10)"
git push
```

---

## Troubleshooting

### Patch Doesn't Apply

```bash
# Check patch format
cat patches/10/golang/0001-my-fix.patch | head -20

# Verify it's a proper git format-patch
# Should start with:
# From <commit-hash>
# From: Your Name <email>
# Date: ...
```

### Build Fails After Applying Patches

```bash
# Review the build log
# Look for errors after "Applying: Patch900"

# Test patch manually
cd out/source/package-dir/
patch -p1 --dry-run < ../../../patches/10/golang/0001-my-fix.patch
```

### Changes Not Reflected in Built RPM

```bash
# Verify patch was actually applied
# Check build logs for "Applying: Patch900"

# Ensure patches are in correct location
ls -la patches/10/golang/

# Rebuild from scratch
rm -rf out/
./docker-run.sh golang
```

### Patch for Wrong UBI Version

```bash
# If you get "Hunk FAILED" errors, the patch may be for a different package version
# Export source for the correct UBI version and create new patches

./docker-export-source.sh --ubi-version 9 golang
# Create patches specific to UBI 9
```

---

## Advanced Workflows

### Multiple Patches from Different Sources

```bash
# Combine patches from different branches
git format-patch security-fixes~3..security-fixes
git format-patch feature-additions~2..feature-additions

# Rename to avoid conflicts
mv 0001-*.patch security-0001-*.patch
mv 0002-*.patch security-0002-*.patch
```

### Rebasing Patches

```bash
# Update patches for new upstream version
git rebase --onto new-version old-version my-changes

# Resolve conflicts and regenerate patches
git format-patch new-version
```

### Interactive Patch Creation

```bash
# Stage specific hunks
git add -p file.go

# Create targeted commits
git commit -m "Fix specific issue"
```

---

## Summary

The complete workflow is:

1. **Export** → `./docker-export-source.sh [--ubi-version <8|9|10>] <package>`
2. **Analyze** → Browse source in `out/source/`
3. **Initialize Git** → `git init && git add . && git commit`
4. **Modify** → Make your changes
5. **Commit** → `git commit` with descriptive messages
6. **Generate** → `git format-patch` to create .patch files
7. **Move** → `mv *.patch ../../../patches/<ubi-version>/<package>/`
8. **Build** → `./docker-run.sh [--ubi-version <8|9|10>] <package>`
9. **Test** → Install and verify the RPMs
10. **Iterate** → Repeat as needed

This workflow gives you full control over the patching process while maintaining traceability and reproducibility across different UBI versions.
