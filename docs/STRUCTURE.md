# Project Structure

This document describes the organization of the pg_ical PostgreSQL extension.

## Directory Layout

```
pg_ical/
├── src/                    # C source code
│   └── pg_ical.c          # Main extension implementation
├── sql/                    # SQL interface definitions
│   ├── pg_ical--1.0.0.sql # Extension SQL functions and types
│   └── pg_ical.control    # Extension metadata
├── tests/                  # Test files
│   └── test.sql           # Comprehensive test suite
├── docker/                 # Docker configuration
│   ├── Dockerfile         # Production build (multi-stage)
│   ├── Dockerfile.dev     # Development environment
│   └── docker-compose.yml # Service definitions
├── docs/                   # Documentation
│   ├── DOCKER.md          # Docker usage guide
│   └── STRUCTURE.md       # This file
├── .github/
│   ├── copilot-instructions.md  # AI coding agent guide
│   └── workflows/
│       └── docker-publish.yml   # CI/CD pipeline
├── Makefile               # Native build configuration (PGXS)
├── Makefile.docker        # Docker convenience commands
├── README.md              # User documentation
└── pg_ical.control        # Symlink to sql/pg_ical.control (build requirement)
```

## File Purposes

### Source Code (`src/`)
- **pg_ical.c**: Complete C implementation of the extension
  - RRULE type I/O functions
  - Set-returning functions for occurrence calculation
  - libical integration
  - PostgreSQL timestamp conversion utilities

### SQL Interface (`sql/`)
- **pg_ical--1.0.0.sql**: SQL DDL for creating extension functions and types
- **pg_ical.control**: PostgreSQL extension metadata (version, dependencies)

### Tests (`tests/`)
- **test.sql**: Comprehensive manual test suite covering:
  - RRULE validation
  - Occurrence generation (daily, weekly, monthly)
  - Edge cases (COUNT limits, UNTIL dates)

### Docker (`docker/`)
- **Dockerfile**: Production build with multi-stage compilation
- **Dockerfile.dev**: Development environment with source mounted as volume
- **docker-compose.yml**: Service definitions for dev and prod containers

### Documentation (`docs/`)
- **DOCKER.md**: Complete guide to Docker-based development workflow
- **STRUCTURE.md**: This file - project organization reference

### Build System
- **Makefile**: PGXS-based native build configuration
  - Discovers PostgreSQL paths via `pg_config`
  - Links libical via `pkg-config`
  - Source path: `OBJS = src/pg_ical.o`
  - SQL path: `DATA = sql/pg_ical--1.0.0.sql`
- **Makefile.docker**: Convenience wrapper for Docker commands
- **pg_ical.control**: Symlink to `sql/pg_ical.control`
  - Required by PGXS (expects `$(EXTENSION).control` in root)
  - Created with: `ln -sf sql/pg_ical.control pg_ical.control`
  - Excluded from version control (`.gitignore`)

## Build Requirements

### PGXS Control File Symlink
PostgreSQL's PGXS build system expects the control file to be named `$(EXTENSION).control` in the project root directory. Since we organize SQL files in the `sql/` subdirectory, we maintain a symlink:

```bash
ln -sf sql/pg_ical.control pg_ical.control
```

This symlink is:
- Created automatically during Docker builds
- Required for native builds (must be created manually)
- Excluded from Git via `.gitignore`
- Not cleaned by `make clean` (protected by `EXTRA_CLEAN =` in Makefile)

### Path Configuration in Makefile
```makefile
OBJS = src/pg_ical.o          # C source location
DATA = sql/pg_ical--1.0.0.sql # SQL script location
```

## Development Workflow

### Docker (Recommended)
```bash
make -f Makefile.docker docker-dev    # Start dev environment
make -f Makefile.docker docker-test   # Build and test
make -f Makefile.docker docker-shell  # Interactive shell
```

### Native Build
```bash
ln -sf sql/pg_ical.control pg_ical.control  # Create symlink (first time only)
make                                         # Compile
sudo make install                            # Install to PostgreSQL
psql -d mydb < tests/test.sql               # Run tests
```

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/docker-publish.yml`):
1. Builds Docker image from `docker/Dockerfile`
2. Publishes to GitHub Container Registry
3. Triggers on push and tags

## Migration Notes

This structure was reorganized from a flat root directory to improve maintainability:
- All C code moved to `src/`
- SQL definitions moved to `sql/`
- Docker files moved to `docker/`
- Tests moved to `tests/`
- Control file symlink added to satisfy PGXS requirements
