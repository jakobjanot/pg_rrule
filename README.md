# pg_rrule - PostgreSQL iCalendar RRULE Extension

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

## Quick Start with Docker

The fastest way to try pg_rrule:

```bash
# Run the example application
cd examples
docker-compose up

# Or just pull and run the image
docker run -d \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  ghcr.io/jakobjanot/pg_rrule:latest
```

See [examples/README.md](examples/README.md) for a complete working demo, or [docs/USAGE_IN_DOCKER.md](docs/USAGE_IN_DOCKER.md) for integration guide.

## Installation

### Option 1: Docker (Recommended)

The easiest way to get started is using Docker:

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/jakobjanot/pg_rrule:latest

# Or use docker-compose for development
make -f Makefile.docker docker-dev    # Start dev environment
make -f Makefile.docker docker-test   # Build and test
```

See [docs/DOCKER.md](docs/DOCKER.md) for complete Docker setup and development guide.

### Option 2: Native Installation

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

**Note**: The symlink `pg_rrule.control → sql/pg_rrule.control` is required because PostgreSQL's build system (PGXS) expects the control file in the project root. This symlink is excluded from version control.

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

## License

MIT License

## Contributing

Contributions are welcome! Please submit issues and pull requests on GitHub.
