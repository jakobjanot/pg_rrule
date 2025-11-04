# Using pg_ical Extension in Your Own Docker Projects

This guide shows how to use the pg_ical PostgreSQL extension in your own Docker projects.

## Option 1: Use Pre-built Image from GitHub Container Registry

The easiest way is to use the published Docker image:

### Pull and Run

```bash
# Pull the latest image
docker pull ghcr.io/jakobjanot/pg_ical:latest

# Run PostgreSQL with pg_ical installed
docker run -d \
  --name postgres-ical \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  ghcr.io/jakobjanot/pg_ical:latest

# Connect and test
docker exec -it postgres-ical psql -U postgres -c "CREATE EXTENSION pg_ical; SELECT rrule_is_valid('FREQ=DAILY');"
```

### Use in docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: ghcr.io/jakobjanot/pg_ical:latest
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      # Optional: Auto-run initialization SQL
      - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql

  # Your application
  app:
    build: .
    depends_on:
      - postgres
    environment:
      DATABASE_URL: postgresql://myuser:mypassword@postgres:5432/myapp

volumes:
  postgres-data:
```

Create `init.sql` to automatically set up the extension:

```sql
-- init.sql
CREATE EXTENSION IF NOT EXISTS pg_ical;

-- Create your tables
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    recurrence rrule
);

-- Insert sample data
INSERT INTO events (title, start_time, recurrence) VALUES
    ('Daily Standup', '2025-01-01 09:00:00+00', 'FREQ=DAILY'),
    ('Weekly Review', '2025-01-06 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO');
```

## Option 2: Build From Source in Your Dockerfile

If you want to build from source in your own Dockerfile:

### Method A: Multi-stage Build (Recommended)

```dockerfile
# Dockerfile
FROM postgres:16 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-16 \
    libical-dev \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone and build pg_ical
WORKDIR /tmp/pg_ical
RUN git clone https://github.com/jakobjanot/pg_ical.git . && \
    ln -sf sql/pg_ical.control pg_ical.control && \
    make && \
    make install

# Final stage - clean image
FROM postgres:16

# Copy only the built extension
COPY --from=builder /usr/share/postgresql/16/extension/pg_ical* /usr/share/postgresql/16/extension/
COPY --from=builder /usr/lib/postgresql/16/lib/pg_ical.so /usr/lib/postgresql/16/lib/

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    libical3 \
    && rm -rf /var/lib/apt/lists/*

# Optional: Copy initialization scripts
COPY ./docker-init/ /docker-entrypoint-initdb.d/
```

### Method B: Single-stage Build (Simpler)

```dockerfile
FROM postgres:16

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-16 \
    libical-dev \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*

# Build and install pg_ical
WORKDIR /tmp/pg_ical
RUN git clone https://github.com/jakobjanot/pg_ical.git . && \
    ln -sf sql/pg_ical.control pg_ical.control && \
    make && \
    make install && \
    cd / && rm -rf /tmp/pg_ical

# Clean up build dependencies (optional, saves space)
RUN apt-get remove -y build-essential postgresql-server-dev-16 pkg-config git && \
    apt-get autoremove -y

WORKDIR /
```

### Build and Run

```bash
# Build your image
docker build -t myapp-postgres .

# Run it
docker run -d \
  --name myapp-db \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  myapp-postgres
```

## Option 3: Use as a Volume Mount (Development)

For local development, mount the built extension:

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      # Mount the built extension files
      - ./pg_ical.so:/usr/lib/postgresql/16/lib/pg_ical.so
      - ./sql/pg_ical--1.0.0.sql:/usr/share/postgresql/16/extension/pg_ical--1.0.0.sql
      - ./sql/pg_ical.control:/usr/share/postgresql/16/extension/pg_ical.control
      - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql
```

First, build the extension locally:

```bash
# On your host machine
cd /path/to/pg_ical
make clean && make
```

Then start the container and it will have the extension available.

## Testing the Examples

### Quick Test Script

Create `test-examples.sql`:

```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_ical;

-- Test 1: Validation
\echo '=== Test 1: RRULE Validation ==='
SELECT rrule_is_valid('FREQ=DAILY') as valid_daily,
       rrule_is_valid('INVALID') as invalid_rule;

-- Test 2: Create sample events
\echo '=== Test 2: Creating Sample Events ==='
CREATE TABLE IF NOT EXISTS calendar_events (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    recurrence rrule
);

TRUNCATE calendar_events;

INSERT INTO calendar_events (title, description, start_time, recurrence) VALUES
    ('Daily Standup', 'Team sync', '2025-11-05 09:00:00+00', 'FREQ=DAILY'),
    ('Weekly Review', 'Monday meetings', '2025-11-11 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO'),
    ('Monthly All-Hands', 'Company meeting', '2025-11-15 15:00:00+00', 'FREQ=MONTHLY;BYMONTHDAY=15'),
    ('Coffee Chat', 'Thursday catch-up', '2025-11-07 14:00:00+00', 'FREQ=WEEKLY;BYDAY=TH');

SELECT * FROM calendar_events;

-- Test 3: Next occurrence
\echo '=== Test 3: Next Occurrence of Each Event ==='
SELECT 
    title,
    rrule_next_occurrence(recurrence, NOW(), start_time) as next_time
FROM calendar_events
ORDER BY next_time;

-- Test 4: Next 5 occurrences
\echo '=== Test 4: Next 5 Daily Standups ==='
SELECT 
    title,
    rrule_next_occurrences(recurrence, NOW(), 5, start_time) as occurrence
FROM calendar_events
WHERE title = 'Daily Standup';

-- Test 5: This week's schedule
\echo '=== Test 5: This Week Schedule ==='
SELECT 
    e.title,
    occ::date as event_date,
    occ::time as event_time
FROM calendar_events e
CROSS JOIN LATERAL rrule_next_occurrences(
    e.recurrence,
    NOW(),
    50,
    e.start_time
) as occ
WHERE occ BETWEEN NOW() AND NOW() + INTERVAL '7 days'
ORDER BY occ;

-- Test 6: Events in date range
\echo '=== Test 6: All Events in November 2025 ==='
SELECT 
    e.title,
    COUNT(*) as occurrences_in_november
FROM calendar_events e
CROSS JOIN LATERAL rrule_occurrences(
    e.recurrence,
    '2025-11-01'::timestamptz,
    '2025-11-30'::timestamptz,
    e.start_time
) as occ
GROUP BY e.title
ORDER BY occurrences_in_november DESC;

\echo '=== All Tests Complete ==='
```

### Run the Tests

```bash
# If using docker-compose
docker-compose exec postgres psql -U postgres -f /path/to/test-examples.sql

# If using docker run
docker cp test-examples.sql postgres-ical:/tmp/
docker exec -it postgres-ical psql -U postgres -f /tmp/test-examples.sql

# Or pipe it directly
docker exec -i postgres-ical psql -U postgres < test-examples.sql
```

### Interactive Testing

```bash
# Start an interactive session
docker exec -it postgres-ical psql -U postgres

# Then run SQL interactively
postgres=# CREATE EXTENSION pg_ical;
postgres=# 
postgres=# -- Test next occurrence
postgres=# SELECT rrule_next_occurrence(
postgres=#     'FREQ=DAILY'::rrule,
postgres=#     NOW(),
postgres=#     '2025-11-05 09:00:00+00'::timestamptz
postgres=# );
```

## Complete Example Application

Here's a complete example with Python application:

### Project Structure

```
my-calendar-app/
├── docker-compose.yml
├── Dockerfile
├── init.sql
├── app.py
└── requirements.txt
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: ghcr.io/jakobjanot/pg_ical:latest
    environment:
      POSTGRES_DB: calendar
      POSTGRES_USER: caluser
      POSTGRES_PASSWORD: calpass
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U caluser -d calendar"]
      interval: 5s
      timeout: 5s
      retries: 5

  app:
    build: .
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://caluser:calpass@postgres:5432/calendar
    ports:
      - "8000:8000"
    volumes:
      - ./app.py:/app/app.py

volumes:
  postgres-data:
```

### Dockerfile (for app)

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

CMD ["python", "app.py"]
```

### requirements.txt

```
psycopg2-binary==2.9.9
```

### init.sql

```sql
CREATE EXTENSION IF NOT EXISTS pg_ical;

CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    recurrence rrule,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO events (title, description, start_time, recurrence) VALUES
    ('Daily Standup', 'Team sync meeting', '2025-11-05 09:00:00+00', 'FREQ=DAILY'),
    ('Weekly Review', 'Monday team review', '2025-11-11 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO'),
    ('Monthly All-Hands', 'Company meeting', '2025-11-15 15:00:00+00', 'FREQ=MONTHLY;BYMONTHDAY=15');
```

### app.py

```python
import psycopg2
import os
from datetime import datetime, timedelta

# Connect to database
conn = psycopg2.connect(os.getenv('DATABASE_URL'))
cur = conn.cursor()

print("🗓️  Calendar Application")
print("=" * 50)

# Test 1: List all events
print("\n📋 All Events:")
cur.execute("SELECT id, title, description FROM events ORDER BY id")
for row in cur.fetchall():
    print(f"  {row[0]}. {row[1]} - {row[2]}")

# Test 2: Next occurrence of each event
print("\n⏰ Next Occurrence of Each Event:")
cur.execute("""
    SELECT 
        title,
        rrule_next_occurrence(recurrence, NOW(), start_time) as next_time
    FROM events
    ORDER BY next_time
""")
for row in cur.fetchall():
    print(f"  {row[0]}: {row[1]}")

# Test 3: This week's schedule
print("\n📅 This Week's Schedule:")
cur.execute("""
    SELECT 
        e.title,
        occ::date as event_date,
        occ::time as event_time
    FROM events e
    CROSS JOIN LATERAL rrule_next_occurrences(
        e.recurrence,
        NOW(),
        50,
        e.start_time
    ) as occ
    WHERE occ BETWEEN NOW() AND NOW() + INTERVAL '7 days'
    ORDER BY occ
""")
for row in cur.fetchall():
    print(f"  {row[1]} {row[2]} - {row[0]}")

# Test 4: Count events this month
print("\n📊 Events This Month:")
cur.execute("""
    SELECT 
        e.title,
        COUNT(*) as count
    FROM events e
    CROSS JOIN LATERAL rrule_occurrences(
        e.recurrence,
        date_trunc('month', NOW())::timestamptz,
        (date_trunc('month', NOW()) + INTERVAL '1 month')::timestamptz,
        e.start_time
    ) as occ
    GROUP BY e.title
    ORDER BY count DESC
""")
for row in cur.fetchall():
    print(f"  {row[0]}: {row[1]} occurrences")

print("\n" + "=" * 50)
print("✅ Tests complete!")

cur.close()
conn.close()
```

### Run the Complete Example

```bash
# Start everything
docker-compose up --build

# You should see output like:
# 🗓️  Calendar Application
# ==================================================
# 
# 📋 All Events:
#   1. Daily Standup - Team sync meeting
#   2. Weekly Review - Monday team review
#   3. Monthly All-Hands - Company meeting
# 
# ⏰ Next Occurrence of Each Event:
#   Daily Standup: 2025-11-06 09:00:00+00
#   Coffee Chat: 2025-11-07 14:00:00+00
#   Weekly Review: 2025-11-11 14:00:00+00
# ...
```

## Connecting from Different Languages

### Node.js Example

```javascript
// npm install pg
const { Client } = require('pg');

const client = new Client({
  connectionString: 'postgresql://caluser:calpass@localhost:5432/calendar'
});

await client.connect();

// Get next occurrence
const result = await client.query(`
  SELECT 
    title,
    rrule_next_occurrence(recurrence, NOW(), start_time) as next_time
  FROM events
  ORDER BY next_time
`);

console.log(result.rows);
await client.end();
```

### Go Example

```go
// go get github.com/lib/pq
package main

import (
    "database/sql"
    "fmt"
    _ "github.com/lib/pq"
)

func main() {
    db, _ := sql.Open("postgres", 
        "postgresql://caluser:calpass@localhost:5432/calendar?sslmode=disable")
    defer db.Close()

    rows, _ := db.Query(`
        SELECT 
            title,
            rrule_next_occurrence(recurrence, NOW(), start_time)
        FROM events
        ORDER BY 2
    `)
    defer rows.Close()

    for rows.Next() {
        var title string
        var nextTime sql.NullTime
        rows.Scan(&title, &nextTime)
        fmt.Printf("%s: %v\n", title, nextTime.Time)
    }
}
```

## Troubleshooting

### Extension not found

```bash
# Check if extension files are in the right place
docker exec postgres-ical ls -la /usr/share/postgresql/16/extension/pg_ical*
docker exec postgres-ical ls -la /usr/lib/postgresql/16/lib/pg_ical.so
```

### Permission denied

```bash
# Ensure PostgreSQL has read permissions
docker exec postgres-ical chmod 644 /usr/share/postgresql/16/extension/pg_ical*
docker exec postgres-ical chmod 755 /usr/lib/postgresql/16/lib/pg_ical.so
```

### libical not found

```bash
# Install libical runtime in your Dockerfile
RUN apt-get update && apt-get install -y libical3
```

## Production Considerations

1. **Use specific version tags** instead of `:latest`
   ```yaml
   image: ghcr.io/jakobjanot/pg_ical:v1.0.0
   ```

2. **Persist data with volumes**
   ```yaml
   volumes:
     - postgres-data:/var/lib/postgresql/data
   ```

3. **Use secrets for passwords**
   ```yaml
   environment:
     POSTGRES_PASSWORD_FILE: /run/secrets/db_password
   secrets:
     - db_password
   ```

4. **Add health checks**
   ```yaml
   healthcheck:
     test: ["CMD-SHELL", "pg_isready -U postgres"]
     interval: 10s
     timeout: 5s
     retries: 5
   ```

5. **Resource limits**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 2G
   ```

## Next Steps

- See [EXAMPLES.md](EXAMPLES.md) for more SQL query examples
- Check [DOCKER.md](DOCKER.md) for development workflow
- Read [README.md](../README.md) for extension details
