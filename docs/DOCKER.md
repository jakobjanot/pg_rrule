# Docker Setup for pg_ical

This document explains how to use Docker for development, testing, and distribution of the pg_ical extension.

## Quick Start

### Development Workflow

```bash
# Start development environment
make -f Makefile.docker docker-dev

# Build extension and run tests
make -f Makefile.docker docker-test

# Open shell in container for debugging
make -f Makefile.docker docker-shell
```

### Production Image

```bash
# Build production image
make -f Makefile.docker docker-prod

# Run production image
docker run --rm \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  pg_ical:latest
```

## Available Commands

Run `make -f Makefile.docker help` to see all available commands:

- **`docker-build`** - Build development Docker image
- **`docker-dev`** - Start development environment (PostgreSQL + build tools)
- **`docker-test`** - Build extension and run test suite
- **`docker-shell`** - Open interactive shell in dev container
- **`docker-prod`** - Build production Docker image
- **`docker-clean`** - Clean up Docker resources
- **`docker-publish`** - Build and tag for GitHub Container Registry

## Docker Images

### Development Image (`Dockerfile.dev`)
- Based on `postgres:16`
- Includes build tools, libical, and development dependencies
- Source code mounted as volume for live development
- PostgreSQL data persisted in Docker volume

### Production Image (`Dockerfile`)
- Multi-stage build for minimal image size
- Only runtime dependencies included
- Extension pre-built and installed
- Ready for distribution

## Development Workflow

1. **Start the environment:**
   ```bash
   make -f Makefile.docker docker-dev
   # PostgreSQL available at localhost:5432
   # Username: postgres, Password: postgres, Database: testdb
   ```

2. **Edit code** on your host machine (changes reflected in container via volume mount)

3. **Build and test:**
   ```bash
   make -f Makefile.docker docker-test
   ```

4. **Interactive debugging:**
   ```bash
   make -f Makefile.docker docker-shell
   # Inside container:
   cd /workspace
   make clean && make && make install
   psql -U postgres -d testdb
   ```

## GitHub Container Registry Distribution

### Manual Publishing

```bash
# 1. Build and tag image
GITHUB_USERNAME=your-username make -f Makefile.docker docker-publish

# 2. Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u your-username --password-stdin

# 3. Push image
docker push ghcr.io/your-username/pg_ical:latest
```

### Automated GitHub Actions

The `.github/workflows/docker-publish.yml` workflow automatically:
- Builds Docker image on every push to main
- Publishes to GitHub Container Registry (ghcr.io)
- Creates version tags from git tags (e.g., `v1.0.0` → `1.0.0`, `1.0`, `1`, `latest`)
- Runs basic extension tests

**To trigger automated publishing:**
```bash
# Tag a release
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will build and publish automatically
```

### Using Published Images

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/your-username/pg_ical:latest

# Run
docker run --rm \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  ghcr.io/your-username/pg_ical:latest

# Connect and use
psql -h localhost -U postgres -d postgres
CREATE EXTENSION pg_ical;
```

## Docker Compose

The `docker-compose.yml` provides two services:

### Dev Service (default)
```bash
docker-compose up -d
# Source code mounted, PostgreSQL on port 5432
```

### Prod Service (production testing)
```bash
docker-compose --profile production up -d
# Production image, PostgreSQL on port 5433
```

## Troubleshooting

**PostgreSQL won't start:**
```bash
docker-compose logs dev
```

**Extension build fails:**
```bash
make -f Makefile.docker docker-shell
cd /workspace
make clean
make VERBOSE=1  # See detailed build output
```

**Clean slate:**
```bash
make -f Makefile.docker docker-clean
make -f Makefile.docker docker-dev
```

## Integration with CI/CD

The Docker setup integrates with GitHub Actions for:
- Automated testing on pull requests
- Publishing releases to GitHub Container Registry
- Multi-architecture builds (amd64, arm64)

See `.github/workflows/docker-publish.yml` for the complete CI/CD pipeline.
