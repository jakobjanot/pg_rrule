# Quick CI/CD Reference

## Common Tasks

### Create a Release

```bash
# Update version if needed
vim sql/pg_rrule.control

# Commit changes
git add .
git commit -m "Prepare release v1.0.0"
git push

# Create and push tag
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will automatically:
# - Run all tests
# - Build artifacts
# - Publish Docker image
# - Create GitHub release
```

### View Build Status

```bash
# Visit GitHub Actions page
open https://github.com/jakobjanot/pg_rrule/actions

# Or use GitHub CLI
gh run list
gh run view <run-id>
gh run watch
```

### Download Release Artifacts

```bash
# Latest release
gh release download

# Specific version
gh release download v1.0.0

# Or via curl
VERSION=1.0.0
curl -LO https://github.com/jakobjanot/pg_rrule/releases/download/v${VERSION}/pg_rrule-${VERSION}-linux-x86_64.tar.gz
```

### Pull Docker Images

```bash
# Latest
docker pull ghcr.io/jakobjanot/pg_rrule:latest

# Specific version
docker pull ghcr.io/jakobjanot/pg_rrule:v1.0.0

# Use in docker-compose
services:
  postgres:
    image: ghcr.io/jakobjanot/pg_rrule:v1.0.0
```

### Run Tests Locally

```bash
# Docker tests
make -f Makefile.docker docker-test

# Native build
make clean && make
sudo make install
psql -d testdb -c "CREATE EXTENSION pg_rrule;"
psql -d testdb -f tests/test.sql
```

### Trigger Manual Workflow

Via GitHub UI:
1. Go to **Actions**
2. Select workflow (e.g., "Tests")
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow**

Via GitHub CLI:
```bash
# Trigger tests
gh workflow run test.yml

# Trigger release (with input)
gh workflow run release.yml -f version=1.0.0

# List workflows
gh workflow list

# View workflow runs
gh run list --workflow=test.yml
```

### Check Release Status

```bash
# List releases
gh release list

# View specific release
gh release view v1.0.0

# Download release assets
gh release download v1.0.0
```

### Re-run Failed Workflow

Via GitHub UI:
1. Go to failed workflow run
2. Click **Re-run failed jobs** or **Re-run all jobs**

Via GitHub CLI:
```bash
# Re-run latest failed run
gh run rerun $(gh run list --workflow=test.yml --limit 1 --json databaseId --jq '.[0].databaseId')

# Re-run specific run
gh run rerun <run-id>
```

### View Workflow Logs

```bash
# View latest run
gh run view

# View specific run
gh run view <run-id>

# View specific job
gh run view <run-id> --job=<job-id>

# Download logs
gh run view <run-id> --log
```

### Clean Up Old Artifacts

GitHub automatically deletes artifacts after 90 days, but you can manually clean up:

```bash
# List artifacts
gh api repos/jakobjanot/pg_rrule/actions/artifacts

# Delete specific artifact
gh api repos/jakobjanot/pg_rrule/actions/artifacts/<artifact-id> -X DELETE
```

### Test Before Pushing

```bash
# Run local tests
make -f Makefile.docker docker-test

# Run example app
cd examples
docker-compose up

# Check formatting
find src -name "*.c" -exec clang-format --dry-run --Werror {} \;

# Auto-fix formatting
find src -name "*.c" -exec clang-format -i {} \;
```

### Debug Failed Build

```bash
# Build locally
make clean
make

# Check for errors
echo $?

# Build in Docker
docker-compose -f docker/docker-compose.yml build dev

# Run shell in build container
docker-compose -f docker/docker-compose.yml run --rm dev bash
```

### Monitor Workflow Costs

GitHub provides free Actions minutes, but you can check usage:

1. Go to **Settings → Billing**
2. View **Actions** usage
3. Check minutes used/remaining

## Workflow Files

- `.github/workflows/docker-publish.yml` - Build and publish Docker images
- `.github/workflows/test.yml` - Run comprehensive test suite
- `.github/workflows/release.yml` - Create releases with artifacts
- `.github/workflows/quality.yml` - Code quality checks

## Environment Variables

Useful in local testing:

```bash
# Simulate GitHub Actions environment
export GITHUB_SHA=$(git rev-parse HEAD)
export GITHUB_REF=refs/heads/main
export GITHUB_REPOSITORY=jakobjanot/pg_rrule
```

## Troubleshooting

### "No space left on device"

GitHub runners have limited disk space. Clean up in workflow:

```yaml
- name: Free disk space
  run: |
    docker system prune -af
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /opt/ghc
```

### "Resource not accessible by integration"

Check workflow permissions in `.github/workflows/*.yml`:

```yaml
permissions:
  contents: write
  packages: write
```

### Tests timeout

Increase timeout in workflow:

```yaml
jobs:
  test:
    timeout-minutes: 30  # Default is 360
```

### Docker rate limits

Authenticate with Docker Hub:

```yaml
- name: Login to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

## Best Practices

1. **Test locally first** before pushing
2. **Use semantic versioning** for releases
3. **Keep workflows fast** - use caching
4. **Monitor costs** - free minutes are limited
5. **Document changes** in commit messages
6. **Use draft releases** for testing
7. **Pin action versions** for stability

## Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [GitHub CLI Docs](https://cli.github.com/manual/)
- [Docker Build Action](https://github.com/docker/build-push-action)
- [Release Action](https://github.com/softprops/action-gh-release)
