# pg_rrule Examples

This directory contains working examples demonstrating how to use the pg_rrule PostgreSQL extension in Docker-based applications.

## Quick Start

The simplest way to test pg_rrule:

```bash
cd examples

# Start PostgreSQL with pg_rrule and run demo app
docker-compose up

# You should see output demonstrating all pg_rrule functions
```

## What's Included

### Files

- **`docker-compose.yml`** - Complete setup with PostgreSQL + pg_rrule and Python demo app
- **`init.sql`** - Automatic database initialization with sample events
- **`app.py`** - Python demo application showing all pg_rrule functions
- **`Dockerfile`** - Python application container
- **`requirements.txt`** - Python dependencies

### Sample Data

The example creates these recurring events:

1. **Daily Standup** - Every day at 9:00 AM
2. **Weekly Review** - Every Monday at 2:00 PM
3. **Bi-weekly Sprint Planning** - Every other Monday at 10:00 AM
4. **Monthly All-Hands** - 15th of each month at 3:00 PM
5. **Coffee Chat** - Every Thursday at 2:00 PM
6. **Quarterly Review** - Every 3 months on the 1st at 4:00 PM

## Running the Examples

### Option 1: Full Stack (Recommended)

Run both PostgreSQL and the demo app:

```bash
docker-compose up
```

This will:
1. Start PostgreSQL with pg_rrule extension
2. Create database and load sample events
3. Run the Python demo showing all features
4. Display comprehensive output demonstrating each function

### Option 2: PostgreSQL Only

Just run the database:

```bash
docker-compose up postgres
```

Then connect manually:

```bash
# Connect with psql
docker-compose exec postgres psql -U caluser -d calendar

# Run queries
calendar=# SELECT * FROM upcoming_events;
calendar=# \i /docker-entrypoint-initdb.d/01-init.sql
```

### Option 3: Interactive Testing

Start PostgreSQL and connect interactively:

```bash
# Start database
docker-compose up -d postgres

# Wait for it to be ready
docker-compose exec postgres pg_isready -U caluser -d calendar

# Connect with psql
docker-compose exec postgres psql -U caluser -d calendar

# Now you can run any SQL queries from docs/EXAMPLES.md
```

## Example Queries to Try

Once PostgreSQL is running, try these queries:

```sql
-- See all events
SELECT * FROM events;

-- Next occurrence of each event
SELECT * FROM upcoming_events;

-- This week's schedule
SELECT 
    e.title,
    occ as event_time
FROM events e
CROSS JOIN LATERAL rrule_next_occurrences(
    e.recurrence,
    NOW(),
    50,
    e.start_time
) as occ
WHERE occ BETWEEN NOW() AND NOW() + INTERVAL '7 days'
ORDER BY occ;

-- Count events this month
SELECT 
    e.title,
    COUNT(*) as occurrences
FROM events e
CROSS JOIN LATERAL rrule_occurrences(
    e.recurrence,
    date_trunc('month', NOW())::timestamptz,
    (date_trunc('month', NOW()) + INTERVAL '1 month')::timestamptz,
    e.start_time
) as occ
GROUP BY e.title;

-- Next 5 daily standups
SELECT 
    rrule_next_occurrences(recurrence, NOW(), 5, start_time) as meeting_time
FROM events
WHERE title = 'Daily Standup';
```

## Using in Your Own Application

### Copy the docker-compose.yml

```yaml
services:
  postgres:
    image: ghcr.io/jakobjanot/pg_rrule:latest
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
    ports:
      - "5432:5432"
    volumes:
      - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql
```

### Adapt init.sql for your schema

Customize the events table and sample data for your use case.

### Connect from your app

Use the DATABASE_URL pattern:
```
postgresql://myuser:mypassword@postgres:5432/myapp
```

## Cleanup

```bash
# Stop containers
docker-compose down

# Remove volumes (deletes data)
docker-compose down -v
```

## Troubleshooting

**Port 5432 already in use:**
```bash
# Change port in docker-compose.yml
ports:
  - "5433:5432"  # Use 5433 on host
```

**App can't connect to database:**
```bash
# Check if PostgreSQL is ready
docker-compose exec postgres pg_isready -U caluser -d calendar

# View logs
docker-compose logs postgres
```

**Extension not found:**
```bash
# Verify extension is installed
docker-compose exec postgres psql -U caluser -d calendar -c "SELECT * FROM pg_extension WHERE extname = 'pg_rrule';"
```

## Next Steps

- See [../docs/EXAMPLES.md](../docs/EXAMPLES.md) for more SQL examples
- See [../docs/USAGE_IN_DOCKER.md](../docs/USAGE_IN_DOCKER.md) for integration guide
- Check [../README.md](../README.md) for extension documentation
