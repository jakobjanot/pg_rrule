# pg_ical - PostgreSQL Extension Development Guide

## Project Overview

This is a **PostgreSQL C extension** that adds iCalendar RRULE (recurrence rule) support using libical. The extension provides a custom `rrule` data type and set-returning functions for calculating recurring event occurrences.

**Architecture**: PostgreSQL extension with C implementation → libical library → SQL interface

## Critical Build & Development Workflow

### Docker Workflow (Recommended)
```bash
make -f Makefile.docker docker-dev    # Start PostgreSQL + build environment
make -f Makefile.docker docker-test   # Build extension and run tests
make -f Makefile.docker docker-shell  # Interactive development shell
```

**Docker setup**: See `DOCKER.md` for complete guide. Two Dockerfiles:
- `Dockerfile.dev` - Full development environment with source mounted as volume
- `Dockerfile` - Multi-stage production build for distribution via GitHub Container Registry

### Native Build (Alternative)
```bash
make                    # Compile the extension (requires pg_config + libical)
sudo make install       # Install to PostgreSQL extensions directory
```

**Build system**: Uses PostgreSQL's PGXS build infrastructure (see `Makefile`). The build automatically discovers:
- PostgreSQL paths via `pg_config`
- libical compiler/linker flags via `pkg-config`

### Testing
```bash
# Docker (recommended):
make -f Makefile.docker docker-test

# Native PostgreSQL:
CREATE EXTENSION pg_ical;
\i test.sql             # Run comprehensive test suite
```

**No automated test harness** - testing is manual via `test.sql` which covers validation, occurrence generation, and edge cases (COUNT limits, date ranges).

**CI/CD**: GitHub Actions workflow (`.github/workflows/docker-publish.yml`) builds and publishes Docker images to GitHub Container Registry on every push/tag.

### Dependencies
- **libical 3.0+** (external C library for RFC 5545 parsing)
- **PostgreSQL 9.6+** development headers
- **pkg-config** (for build configuration)

## Code Patterns & Conventions

### Custom Type Implementation (PostgreSQL Pattern)
The `rrule` type follows PostgreSQL's varlena type structure:
```c
typedef struct {
    int32 vl_len_;  // Required varlena header - NEVER modify directly
    char data[FLEXIBLE_ARRAY_MEMBER];  // Variable-length RRULE string
} rrule;
```

**Input/Output Functions**: `rrule_in()` validates via libical before storing, `rrule_out()` returns the raw string. All invalid RRULEs are rejected at insertion time.

### Set-Returning Functions (SRF Pattern)
Functions like `rrule_occurrences()` use PostgreSQL's SRF protocol:
1. **First call** (`SRF_IS_FIRSTCALL()`): Parse RRULE, generate all occurrences into memory, store in `funcctx->user_fctx`
2. **Subsequent calls** (`SRF_PERCALL_SETUP()`): Return one occurrence per call
3. **Cleanup**: Automatic when `SRF_RETURN_DONE()` is called

**Memory Management**: Use `funcctx->multi_call_memory_ctx` for data that persists across SRF calls. Single-call data uses default context.

### Safety Limits
- `rrule_occurrences()`: Max 1,000 occurrences (hardcoded in C)
- `rrule_next_occurrences()`: Max 10,000, validated at runtime

### Time Conversion Pattern
PostgreSQL timestamps ↔ libical times via helper functions:
- `timestamp_to_icaltime()`: Uses PostgreSQL's `timestamp2tm()` API
- `icaltime_to_timestamp()`: Uses PostgreSQL's `tm2timestamp()` API
- **Always use UTC timezone**: `icaltimezone_get_utc_timezone()`

## File Structure & Purpose

- **`src/pg_ical.c`**: All C implementation (type I/O, SRF functions, libical integration)
- **`sql/pg_ical--1.0.0.sql`**: SQL interface definitions (CREATE TYPE, CREATE FUNCTION)
- **`sql/pg_ical.control`**: Extension metadata for PostgreSQL
- **`pg_ical.control`**: Symlink to `sql/pg_ical.control` (required by PGXS - see note below)
- **`Makefile`**: PGXS-based build configuration
- **`Makefile.docker`**: Docker-based development/testing commands
- **`docker/Dockerfile`**: Multi-stage production build for distribution
- **`docker/Dockerfile.dev`**: Development environment with mounted source
- **`docker/docker-compose.yml`**: Dev and production service definitions
- **`tests/test.sql`**: Manual test suite demonstrating all functions
- **`docs/DOCKER.md`**: Complete Docker usage guide
- **`docs/STRUCTURE.md`**: Project organization reference

### PGXS Control File Requirement
PGXS expects the control file to be `$(EXTENSION).control` in the project root. We maintain a symlink:
```bash
ln -sf sql/pg_ical.control pg_ical.control
```
- Created automatically in Docker builds
- Must be created manually for native builds
- Excluded from Git (`.gitignore`)
- Protected from `make clean` via `EXTRA_CLEAN =` in Makefile

## Key Integration Points

### libical Iterator Pattern
```c
icalrecur_iterator *ritr = icalrecur_iterator_new(recur, dtstart);
for (next = icalrecur_iterator_next(ritr); 
     !icaltime_is_null_time(next);
     next = icalrecur_iterator_next(ritr)) {
    // Process occurrence
}
icalrecur_iterator_free(ritr);  // MUST free iterator
```

### PostgreSQL Extension Lifecycle
1. Extension installed via `CREATE EXTENSION pg_ical` (loads from `pg_ical--1.0.0.sql`)
2. Shared library loaded from `$libdir/pg_ical.so` (see `module_pathname` in `.control`)
3. `PG_MODULE_MAGIC` macro validates PostgreSQL version compatibility

## Common Gotchas

- **dtstart parameter**: All occurrence functions require the original event start time (dtstart) - this is NOT stored in the RRULE itself
- **STRICT functions**: All functions are STRICT (return NULL on NULL input, skip execution)
- **IMMUTABLE marking**: Functions marked IMMUTABLE because output depends only on inputs (enables query optimization)
- **RRULE validation**: Happens at type input time, not query time. Invalid RRULEs raise errors during INSERT/UPDATE

## Platform-Specific Notes

**macOS**: Install via `brew install postgresql libical`  
**Linux**: Requires `-dev` packages (e.g., `postgresql-server-dev-all libical-dev`)

---
*For complete RRULE syntax reference, see README.md "RRULE Syntax" section. For usage patterns, see README.md "Usage" examples.*
