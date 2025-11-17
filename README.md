# pg_rrule - PostgreSQL iCalendar RRULE Extension

[![Tests](https://github.com/jakobjanot/pg_rrule/actions/workflows/test.yml/badge.svg)](https://github.com/jakobjanot/pg_rrule/actions/workflows/test.yml)
[![Quality](https://github.com/jakobjanot/pg_rrule/actions/workflows/quality.yml/badge.svg)](https://github.com/jakobjanot/pg_rrule/actions/workflows/quality.yml)

A PostgreSQL extension that provides support for iCalendar recurrence rules (RRULE) using libical.

## Features

- **RRULE data type**: Store recurrence rules directly in your database
- **Occurrence generation**: Calculate recurring events based on RRULE patterns
- **Flexible queries**: Get occurrences within date ranges or get next N occurrences
- **Standard compliance**: Uses libical for RFC 5545 compliant parsing

## Requirements

- PostgreSQL 9.6 or later
- libical 3.0 or later
- pg_config (usually included with PostgreSQL development packages)

## Installation

### From Binaries

Download a release tarball for your OS/architecture from GitHub Releases and copy files to PostgreSQL directories.

Linux example (PostgreSQL 16 on Debian-based distros):
```bash
tar -xzf pg_rrule-<version>-linux-x86_64.tar.gz
cd pg_rrule-<version>
sudo cp pg_rrule.so /usr/lib/postgresql/16/lib/
sudo cp pg_rrule.control /usr/share/postgresql/16/extension/
sudo cp pg_rrule--1.0.0.sql /usr/share/postgresql/16/extension/
```

macOS example:
```bash
tar -xzf pg_rrule-<version>-macos-<arch>.tar.gz
cd pg_rrule-<version>
sudo cp pg_rrule.so $(pg_config --pkglibdir)/
sudo cp pg_rrule.control $(pg_config --sharedir)/extension/
sudo cp pg_rrule--1.0.0.sql $(pg_config --sharedir)/extension/
```

### Use with Docker (official postgres)

Use the official `postgres` image and bind-mount the extension files (example for PostgreSQL 16):
```bash
# Extract binaries for your platform
tar -xzf pg_rrule-<version>-linux-x86_64.tar.gz

docker run --name pg-rrule -d \
    -e POSTGRES_PASSWORD=pass \
    -p 5432:5432 \
    -v "$PWD/pg_rrule-<version>/pg_rrule.so":/usr/lib/postgresql/16/lib/pg_rrule.so:ro \
    -v "$PWD/pg_rrule-<version>/pg_rrule.control":/usr/share/postgresql/16/extension/pg_rrule.control:ro \
    -v "$PWD/pg_rrule-<version>/pg_rrule--1.0.0.sql":/usr/share/postgresql/16/extension/pg_rrule--1.0.0.sql:ro \
    postgres:16

# Create the extension
docker exec -it pg-rrule psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_rrule;"
```
Adjust paths for other PostgreSQL major versions.

### Bake Into a Docker Image

If you prefer embedding the extension in your own image based on the official `postgres` image:

```Dockerfile
# Dockerfile
FROM postgres:16

# Copy prebuilt extension files from a release tarball you extracted locally
# Adjust the version and PostgreSQL major version paths as needed
COPY ./pg_rrule-<version>/pg_rrule.so /usr/lib/postgresql/16/lib/pg_rrule.so
COPY ./pg_rrule-<version>/pg_rrule.control /usr/share/postgresql/16/extension/pg_rrule.control
COPY ./pg_rrule-<version>/pg_rrule--1.0.0.sql /usr/share/postgresql/16/extension/pg_rrule--1.0.0.sql

# Optional: auto-create the extension on first database init
COPY ./init/01_create_pg_rrule.sql /docker-entrypoint-initdb.d/01_create_pg_rrule.sql
```

Where `init/01_create_pg_rrule.sql` contains:

```sql
-- init/01_create_pg_rrule.sql
CREATE EXTENSION IF NOT EXISTS pg_rrule;
```

Build and run:

```bash
docker build -t my-postgres:with-pg-rrule .
docker run --rm -e POSTGRES_PASSWORD=pass -p 5432:5432 my-postgres:with-pg-rrule
```

Notes:
- The paths above match Debian-based `postgres:16` images. For other majors, change `16` accordingly.
- Alpine-based images use different directories; consult that image’s documentation.

### docker-compose Example

Using bind mounts with `docker-compose` to load the extension:

```yaml
# docker-compose.yml
services:
    db:
        image: postgres:16
        environment:
            POSTGRES_PASSWORD: pass
            POSTGRES_DB: app
        ports:
            - "5432:5432"
        volumes:
            # Mount extension files (adjust version and paths)
            - ./pg_rrule-<version>/pg_rrule.so:/usr/lib/postgresql/16/lib/pg_rrule.so:ro
            - ./pg_rrule-<version>/pg_rrule.control:/usr/share/postgresql/16/extension/pg_rrule.control:ro
            - ./pg_rrule-<version>/pg_rrule--1.0.0.sql:/usr/share/postgresql/16/extension/pg_rrule--1.0.0.sql:ro
            # Auto-create extension at init (optional)
            - ./init:/docker-entrypoint-initdb.d:ro
```

Create the `init/01_create_pg_rrule.sql` file with:

```sql
CREATE EXTENSION IF NOT EXISTS pg_rrule;
```

### From Source (Native Installation)

#### Install Dependencies

**macOS (Homebrew):**
```bash
brew install postgresql libical
```

**Ubuntu/Debian:**
```bash
sudo apt-get install postgresql-server-dev-all libical-dev
```

**RHEL/CentOS:**
```bash
sudo yum install postgresql-devel libical-devel
```

#### Build and Install Extension

```bash
# Create required symlink (PGXS requirement - do this once)
ln -sf sql/pg_rrule.control pg_rrule.control

# Build and install
make
sudo make install
```

**Note**: The symlink `pg_rrule.control → sql/pg_rrule.control` is required because PostgreSQL's build system (PGXS) expects the control file in the project root.

### Enable Extension

Connect to your database and run:
```sql
CREATE EXTENSION pg_rrule;
```

## Usage

**For detailed examples and usage patterns, see [docs/EXAMPLES.md](docs/EXAMPLES.md)**

### Creating Tables with RRULE

```sql
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title TEXT,
    dtstart TIMESTAMP WITH TIME ZONE,
    recurrence rrule
);
```

### Inserting RRULE Data

```sql
-- Daily event
INSERT INTO events (title, dtstart, recurrence) 
VALUES ('Daily standup', '2024-01-01 09:00:00+00', 'FREQ=DAILY');

-- Weekly event on Monday and Wednesday
INSERT INTO events (title, dtstart, recurrence) 
VALUES ('Team meeting', '2024-01-01 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO,WE');

-- Monthly event on the 15th
INSERT INTO events (title, dtstart, recurrence) 
VALUES ('Monthly review', '2024-01-15 10:00:00+00', 'FREQ=MONTHLY;BYMONTHDAY=15');

-- Event ending after 10 occurrences
INSERT INTO events (title, dtstart, recurrence) 
VALUES ('Limited event', '2024-01-01 12:00:00+00', 'FREQ=WEEKLY;COUNT=10');

-- Event ending on a specific date
INSERT INTO events (title, dtstart, recurrence) 
VALUES ('Q1 event', '2024-01-01 15:00:00+00', 'FREQ=DAILY;UNTIL=20240331T235959Z');
```

### Querying Occurrences

**Get all occurrences between two dates:**
```sql
SELECT title, rrule_occurrences(
    recurrence,
    '2024-01-01'::timestamptz,
    '2024-01-31'::timestamptz,
    dtstart
) AS occurrence
FROM events
WHERE title = 'Daily standup';
```

**Get next 5 occurrences:**
```sql
SELECT title, rrule_next_occurrences(
    recurrence,
    NOW(),
    5,
    dtstart
) AS occurrence
FROM events;
```

**Get next single occurrence:**
```sql
SELECT title, rrule_next_occurrence(
    recurrence,
    NOW(),
    dtstart
) AS next_occurrence
FROM events;
```

**Validate RRULE before inserting:**
```sql
SELECT rrule_is_valid('FREQ=DAILY;INTERVAL=2');  -- Returns true
SELECT rrule_is_valid('INVALID_RULE');           -- Returns false
```

### Advanced Queries

**Find all events occurring today:**
```sql
SELECT DISTINCT e.title, e.dtstart
FROM events e
CROSS JOIN LATERAL rrule_occurrences(
    e.recurrence,
    CURRENT_DATE::timestamptz,
    (CURRENT_DATE + INTERVAL '1 day')::timestamptz,
    e.dtstart
) AS occ
ORDER BY e.dtstart;
```

**Get upcoming week's schedule:**
```sql
SELECT e.title, occ AS occurrence
FROM events e
CROSS JOIN LATERAL rrule_next_occurrences(
    e.recurrence,
    NOW(),
    20,
    e.dtstart
) AS occ
WHERE occ < NOW() + INTERVAL '7 days'
ORDER BY occ;
```

## RRULE Syntax

The RRULE format follows RFC 5545. Common parameters:

- `FREQ`: DAILY, WEEKLY, MONTHLY, YEARLY
- `INTERVAL`: How often the recurrence repeats
- `COUNT`: Number of occurrences
- `UNTIL`: End date (format: YYYYMMDDTHHMMSSZ)
- `BYDAY`: Days of week (MO, TU, WE, TH, FR, SA, SU)
- `BYMONTHDAY`: Day of month (1-31)
- `BYMONTH`: Month (1-12)

Examples:
- `FREQ=DAILY` - Every day
- `FREQ=WEEKLY;INTERVAL=2` - Every 2 weeks
- `FREQ=MONTHLY;BYDAY=1MO` - First Monday of each month
- `FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25` - December 25th every year

## Functions Reference

### rrule_occurrences(rrule, start_date, end_date, dtstart)
Returns all occurrences between start_date and end_date.

### rrule_next_occurrences(rrule, from_date, count, dtstart)
Returns the next N occurrences after from_date (max 10,000).

### rrule_next_occurrence(rrule, after_date, dtstart)
Returns the next single occurrence after after_date.

### rrule_is_valid(text)
Validates an RRULE string without creating an rrule type.

## Uninstallation

```sql
DROP EXTENSION pg_rrule CASCADE;
```

## Development & CI/CD

This project uses GitHub Actions for automated testing, building, and releases.

- **Automated Tests**: Run on every push and PR
- **Multi-version PostgreSQL**: Tested against PostgreSQL 12-16
- **Releases**: Create a tag `vX.Y.Z` to trigger automated release builds

See [docs/CI_CD.md](docs/CI_CD.md) for complete CI/CD documentation.

### Creating a Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

This automatically:
1. Runs all tests
2. Builds binary and source artifacts
3. Creates GitHub release with downloadable artifacts

## License

MIT License

## Contributing

Contributions are welcome! Please submit issues and pull requests on GitHub.

All pull requests automatically run:
- Compilation tests
- Integration tests
- Code quality checks
- Multi-version PostgreSQL compatibility tests
