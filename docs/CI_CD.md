# CI/CD with GitHub Actions

This project uses GitHub Actions for automated building, testing, and deployment.

## Workflows

### 🏗️ Build and Publish (`docker-publish.yml`)

**Triggers:**
- Push to `main` branch
- Tag push matching `v*.*.*`
- Pull requests to `main`
- Manual trigger

**What it does:**
1. Builds Docker image
2. Runs basic tests
3. Pushes to GitHub Container Registry (`ghcr.io`)
4. Tags images appropriately:
   - `latest` for main branch
   - `vX.Y.Z` for version tags
   - `pr-N` for pull requests

**Usage:**
```bash
# Automatic: Push to main or create a tag
git tag v1.0.0
git push origin v1.0.0

# Manual: Via GitHub UI
# Go to Actions → Build and Publish → Run workflow
```

### 🧪 Tests (`test.yml`)

**Triggers:**
- Push to `main` or `develop`
- Pull requests to `main`
- Manual trigger

**Test Suites:**

1. **Docker Tests** - Build and test in Docker environment
2. **Native Build Tests** - Test compilation on Ubuntu
3. **Multi-Version PostgreSQL** - Test against PostgreSQL 12-16
4. **Example Validation** - Verify example applications work

**Usage:**
```bash
# Automatic: Tests run on every push/PR
# Manual: Via GitHub UI
# Go to Actions → Tests → Run workflow
```

### 📦 Release (`release.yml`)

**Triggers:**
- Tag push matching `v*.*.*`
- Manual trigger with version input

**What it creates:**
1. **Binary artifact** - Pre-compiled `.so` file for Linux x86_64
2. **Source tarball** - Full source code
3. **Docker images** - Tagged with version and `latest`
4. **GitHub Release** - With release notes and checksums

**Usage:**
```bash
# Create a release
git tag v1.0.0
git push origin v1.0.0

# Or manually via GitHub UI with custom version
```

**Artifacts created:**
- `pg_rrule-X.Y.Z-linux-x86_64.tar.gz` - Binary distribution
- `pg_rrule-X.Y.Z-source.tar.gz` - Source code
- `checksums.txt` - SHA256 checksums
- Docker: `ghcr.io/jakobjanot/pg_rrule:X.Y.Z`

### 🔍 Code Quality (`quality.yml`)

**Triggers:**
- Push to `main` or `develop`
- Pull requests to `main`

**Checks:**
1. **C Code Linting** - clang-format, cppcheck
2. **SQL Linting** - Syntax and style checks
3. **YAML Linting** - Validate workflow files
4. **Docker Linting** - Hadolint for Dockerfiles
5. **Documentation** - Check for broken links
6. **Security** - Trivy vulnerability scanning

## GitHub Container Registry

Images are published to GitHub Container Registry at:
```
ghcr.io/jakobjanot/pg_rrule
```

### Available Tags

- `latest` - Latest build from main branch
- `vX.Y.Z` - Specific version releases
- `main` - Latest main branch build
- `pr-N` - Pull request builds (not pushed)

### Pulling Images

```bash
# Latest version
docker pull ghcr.io/jakobjanot/pg_rrule:latest

# Specific version
docker pull ghcr.io/jakobjanot/pg_rrule:v1.0.0
```

### Authentication

Images are public, but to push you need:
```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

## Release Process

### Creating a New Release

1. **Update version** (if needed):
   ```bash
   # Update version in sql/pg_rrule.control if needed
   vim sql/pg_rrule.control
   ```

2. **Commit and tag**:
   ```bash
   git add .
   git commit -m "Release v1.0.0"
   git tag v1.0.0
   git push origin main
   git push origin v1.0.0
   ```

3. **Wait for CI/CD**:
   - Watch GitHub Actions run
   - Verify tests pass
   - Check release is created

4. **Verify release**:
   ```bash
   # Test Docker image
   docker run --rm ghcr.io/jakobjanot/pg_rrule:v1.0.0 postgres --version
   
   # Download and test binary
   wget https://github.com/jakobjanot/pg_rrule/releases/download/v1.0.0/pg_rrule-1.0.0-linux-x86_64.tar.gz
   ```

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH`
- `v1.0.0` - First stable release
- `v1.1.0` - New features (backward compatible)
- `v1.0.1` - Bug fixes
- `v2.0.0` - Breaking changes

## Secrets and Permissions

### Required Permissions

Workflows need these permissions (automatically granted):
- `contents: write` - For creating releases
- `packages: write` - For publishing to GHCR
- `contents: read` - For reading repository

### Required Secrets

No additional secrets needed! GitHub provides `GITHUB_TOKEN` automatically.

## Status Badges

Add to your README.md:

```markdown
[![Build](https://github.com/jakobjanot/pg_rrule/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/jakobjanot/pg_rrule/actions/workflows/docker-publish.yml)
[![Tests](https://github.com/jakobjanot/pg_rrule/actions/workflows/test.yml/badge.svg)](https://github.com/jakobjanot/pg_rrule/actions/workflows/test.yml)
[![Quality](https://github.com/jakobjanot/pg_rrule/actions/workflows/quality.yml/badge.svg)](https://github.com/jakobjanot/pg_rrule/actions/workflows/quality.yml)
```

## Debugging Workflows

### View Logs

1. Go to **Actions** tab
2. Click on workflow run
3. Click on failed job
4. Expand failed step

### Re-run Failed Jobs

1. Go to failed workflow run
2. Click "Re-run failed jobs"

### Test Locally

```bash
# Install act (GitHub Actions local runner)
brew install act  # macOS
# or
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflow locally
act push

# Run specific job
act -j test-docker
```

## Manual Workflow Dispatch

All workflows support manual triggering:

1. Go to **Actions** tab
2. Select workflow
3. Click **Run workflow**
4. Choose branch and fill in inputs (if any)
5. Click **Run workflow**

## Workflow Dependencies

```
Push/Tag → Build & Publish → Tests → Quality
                     ↓
                  Release (on tags)
```

## Environment Variables

Available in all workflows:
- `GITHUB_SHA` - Commit SHA
- `GITHUB_REF` - Branch or tag ref
- `GITHUB_REPOSITORY` - Repository name
- `GITHUB_ACTOR` - User triggering workflow
- `RUNNER_OS` - Operating system (Linux)

## Caching

Workflows use GitHub Actions cache:
- **Docker layers** - Speeds up builds
- **Dependencies** - apt packages cached

## Troubleshooting

### Build Fails

**Problem**: Extension doesn't compile
```bash
# Check locally first
make clean
make
```

**Problem**: Tests fail
```bash
# Run tests locally
make -f Makefile.docker docker-test
```

### Release Fails

**Problem**: Tag already exists
```bash
# Delete tag and retry
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0
```

**Problem**: Docker push fails
- Check GHCR permissions in repo settings
- Verify packages are public

### Quality Checks Fail

**Problem**: Formatting issues
```bash
# Auto-format C code
find src -name "*.c" -exec clang-format -i {} \;
```

**Problem**: YAML linting
```bash
# Install yamllint
pip install yamllint

# Check files
yamllint .github/workflows/
```

## Best Practices

1. **Always test locally** before pushing
2. **Use semantic versioning** for tags
3. **Write descriptive commit messages**
4. **Keep workflows fast** - use caching
5. **Monitor workflow costs** - GitHub provides free minutes
6. **Update dependencies** regularly

## Advanced: Custom Runners

For faster builds, you can use self-hosted runners:

1. Go to **Settings → Actions → Runners**
2. Click **New self-hosted runner**
3. Follow setup instructions
4. Update workflow to use:
   ```yaml
   runs-on: self-hosted
   ```

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Semantic Versioning](https://semver.org/)
- [Docker Build GitHub Action](https://github.com/docker/build-push-action)
