# pg_rrule Function Examples

This guide provides practical examples of using pg_rrule functions to work with recurring events.

## Quick Start

First, enable the extension in your database:

```sql
CREATE EXTENSION pg_rrule;
```

## The RRULE Type

The `rrule` type stores iCalendar recurrence rules. When you insert an RRULE string, it's automatically validated:

```sql
-- Valid RRULE - this works
SELECT 'FREQ=DAILY'::rrule;

-- Invalid RRULE - this raises an error
SELECT 'INVALID_RULE'::rrule;
-- ERROR: invalid RRULE string
```

## Core Functions Overview

pg_rrule provides 4 main functions:

1. **`rrule_is_valid(text)`** - Validate an RRULE string
2. **`rrule_next_occurrence(rrule, after, dtstart)`** - Get the next single occurrence
3. **`rrule_next_occurrences(rrule, from, count, dtstart)`** - Get next N occurrences
4. **`rrule_occurrences(rrule, start, end, dtstart)`** - Get occurrences in a date range

## Function Examples

### 1. Validating RRULE Strings

Use `rrule_is_valid()` to check if an RRULE is valid before inserting:

```sql
-- Check various RRULE patterns
SELECT rrule_is_valid('FREQ=DAILY');                    -- true
SELECT rrule_is_valid('FREQ=WEEKLY;BYDAY=MO,WE,FR');   -- true
SELECT rrule_is_valid('FREQ=MONTHLY;BYMONTHDAY=15');   -- true
SELECT rrule_is_valid('FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25'); -- true
SELECT rrule_is_valid('INVALID_RULE');                 -- false
SELECT rrule_is_valid('FREQ=WRONG');                   -- false
```

**Use case**: Validate user input before storing in database:

```sql
-- Only insert if valid
INSERT INTO events (title, dtstart, recurrence)
SELECT 'Meeting', NOW(), 'FREQ=WEEKLY;BYDAY=MO'::rrule
WHERE rrule_is_valid('FREQ=WEEKLY;BYDAY=MO');
```

### 2. Getting the Next Single Occurrence

`rrule_next_occurrence(rrule, after_date, dtstart)` returns the next occurrence after a given date.

**Parameters**:
- `rrule` - The recurrence rule
- `after_date` - Find occurrences after this timestamp
- `dtstart` - The original event start time (required by RRULE spec)

```sql
-- Daily meeting starting Jan 1, 2025 at 9 AM
SELECT rrule_next_occurrence(
    'FREQ=DAILY'::rrule,
    '2025-01-05 12:00:00+00'::timestamptz,  -- After this date
    '2025-01-01 09:00:00+00'::timestamptz   -- Event start time
);
-- Returns: 2025-01-06 09:00:00+00 (next day at 9 AM)

-- Weekly meeting every Monday
SELECT rrule_next_occurrence(
    'FREQ=WEEKLY;BYDAY=MO'::rrule,
    NOW(),
    '2025-01-06 14:00:00+00'::timestamptz  -- First Monday at 2 PM
);
-- Returns: next Monday at 14:00:00
```

**Practical example** - "When is my next team meeting?":

```sql
CREATE TABLE meetings (
    id SERIAL PRIMARY KEY,
    name TEXT,
    first_occurrence TIMESTAMPTZ,
    pattern rrule
);

INSERT INTO meetings VALUES
    (1, 'Daily Standup', '2025-01-01 09:00:00+00', 'FREQ=DAILY'),
    (2, 'Weekly Review', '2025-01-06 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO');

-- Find next occurrence of each meeting
SELECT 
    name,
    rrule_next_occurrence(pattern, NOW(), first_occurrence) as next_meeting
FROM meetings;

--        name        |      next_meeting       
-- -------------------+-------------------------
--  Daily Standup     | 2025-11-05 09:00:00+00
--  Weekly Review     | 2025-11-11 14:00:00+00
```

### 3. Getting Multiple Upcoming Occurrences

`rrule_next_occurrences(rrule, from_date, count, dtstart)` returns the next N occurrences.

**Parameters**:
- `rrule` - The recurrence rule
- `from_date` - Start searching from this timestamp
- `count` - Number of occurrences to return (max 10,000)
- `dtstart` - The original event start time

```sql
-- Get next 5 daily meetings
SELECT rrule_next_occurrences(
    'FREQ=DAILY'::rrule,
    '2025-01-01'::timestamptz,
    5,
    '2025-01-01 09:00:00+00'::timestamptz
);

-- Returns:
--  2025-01-02 09:00:00+00
--  2025-01-03 09:00:00+00
--  2025-01-04 09:00:00+00
--  2025-01-05 09:00:00+00
--  2025-01-06 09:00:00+00

-- Get next 3 weekly meetings (Mon/Wed/Fri)
SELECT rrule_next_occurrences(
    'FREQ=WEEKLY;BYDAY=MO,WE,FR'::rrule,
    '2025-01-01'::timestamptz,
    3,
    '2025-01-01 10:00:00+00'::timestamptz
);

-- Returns:
--  2025-01-03 10:00:00+00  (Friday)
--  2025-01-06 10:00:00+00  (Monday)
--  2025-01-08 10:00:00+00  (Wednesday)
```

**Practical example** - "Show me this week's schedule":

```sql
-- Get all meeting instances for the next 7 days
SELECT 
    m.name,
    occ as scheduled_time
FROM meetings m
CROSS JOIN LATERAL rrule_next_occurrences(
    m.pattern,
    NOW(),
    50,  -- Get up to 50 occurrences
    m.first_occurrence
) as occ
WHERE occ < NOW() + INTERVAL '7 days'
ORDER BY occ;

--       name        |     scheduled_time      
-- ------------------+-------------------------
--  Daily Standup    | 2025-11-05 09:00:00+00
--  Daily Standup    | 2025-11-06 09:00:00+00
--  Daily Standup    | 2025-11-07 09:00:00+00
--  Daily Standup    | 2025-11-08 09:00:00+00
--  Daily Standup    | 2025-11-09 09:00:00+00
--  Daily Standup    | 2025-11-10 09:00:00+00
--  Weekly Review    | 2025-11-11 14:00:00+00
--  Daily Standup    | 2025-11-11 09:00:00+00
```

### 4. Getting Occurrences in a Date Range

`rrule_occurrences(rrule, start_date, end_date, dtstart)` returns all occurrences between two dates.

**Parameters**:
- `rrule` - The recurrence rule
- `start_date` - Beginning of range
- `end_date` - End of range
- `dtstart` - The original event start time

```sql
-- All daily meetings in January 2025
SELECT rrule_occurrences(
    'FREQ=DAILY'::rrule,
    '2025-01-01'::timestamptz,
    '2025-01-31'::timestamptz,
    '2025-01-01 09:00:00+00'::timestamptz
);
-- Returns: 31 occurrences (Jan 1 - Jan 31)

-- Weekly meetings in Q1 2025
SELECT rrule_occurrences(
    'FREQ=WEEKLY;BYDAY=MO'::rrule,
    '2025-01-01'::timestamptz,
    '2025-03-31'::timestamptz,
    '2025-01-06 14:00:00+00'::timestamptz  -- First Monday
);
-- Returns: All Mondays in Q1 (~13 occurrences)

-- Monthly meetings for the whole year
SELECT rrule_occurrences(
    'FREQ=MONTHLY;BYMONTHDAY=15'::rrule,
    '2025-01-01'::timestamptz,
    '2025-12-31'::timestamptz,
    '2025-01-15 10:00:00+00'::timestamptz
);
-- Returns: 12 occurrences (15th of each month)
```

**Practical example** - "How many meetings did we have last month?":

```sql
-- Count meetings per type in October 2025
SELECT 
    m.name,
    COUNT(*) as meeting_count
FROM meetings m
CROSS JOIN LATERAL rrule_occurrences(
    m.pattern,
    '2025-10-01'::timestamptz,
    '2025-10-31'::timestamptz,
    m.first_occurrence
) as occ
GROUP BY m.name;

--       name        | meeting_count
-- ------------------+---------------
--  Daily Standup    |            31
--  Weekly Review    |             4
```

## Complete Real-World Example

Here's a complete example of a calendar application:

```sql
-- Create events table
CREATE TABLE calendar_events (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    recurrence rrule,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert various events
INSERT INTO calendar_events (title, description, location, start_time, recurrence) VALUES
    ('Daily Standup', 'Team sync', 'Zoom Room A', '2025-01-01 09:00:00+00', 'FREQ=DAILY'),
    ('Sprint Planning', 'Bi-weekly planning', 'Conference Room', '2025-01-01 10:00:00+00', 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO'),
    ('Monthly All-Hands', 'Company meeting', 'Main Hall', '2025-01-15 15:00:00+00', 'FREQ=MONTHLY;BYMONTHDAY=15'),
    ('Coffee Chat', 'Informal catch-up', 'Cafeteria', '2025-01-02 14:00:00+00', 'FREQ=WEEKLY;BYDAY=TH'),
    ('Limited Workshop', 'Training session', 'Training Room', '2025-01-10 13:00:00+00', 'FREQ=DAILY;COUNT=5');

-- Query 1: What's happening today?
SELECT 
    e.title,
    e.location,
    occ as event_time
FROM calendar_events e
CROSS JOIN LATERAL rrule_occurrences(
    e.recurrence,
    CURRENT_DATE::timestamptz,
    (CURRENT_DATE + INTERVAL '1 day')::timestamptz,
    e.start_time
) as occ
ORDER BY occ;

-- Query 2: My schedule for next week
SELECT 
    e.title,
    e.description,
    occ::date as event_date,
    occ::time as event_time
FROM calendar_events e
CROSS JOIN LATERAL rrule_next_occurrences(
    e.recurrence,
    NOW(),
    100,  -- Get plenty of occurrences
    e.start_time
) as occ
WHERE occ BETWEEN NOW() AND NOW() + INTERVAL '7 days'
ORDER BY occ;

-- Query 3: Next occurrence of each event
SELECT 
    e.title,
    rrule_next_occurrence(e.recurrence, NOW(), e.start_time) as next_time,
    e.location
FROM calendar_events e
ORDER BY next_time;

-- Query 4: How many events this month?
SELECT 
    e.title,
    COUNT(*) as occurrences_this_month
FROM calendar_events e
CROSS JOIN LATERAL rrule_occurrences(
    e.recurrence,
    date_trunc('month', NOW())::timestamptz,
    (date_trunc('month', NOW()) + INTERVAL '1 month')::timestamptz,
    e.start_time
) as occ
GROUP BY e.title
ORDER BY occurrences_this_month DESC;

-- Query 5: Find conflicts (events at the same time)
WITH all_occurrences AS (
    SELECT 
        e.id,
        e.title,
        occ as event_time
    FROM calendar_events e
    CROSS JOIN LATERAL rrule_next_occurrences(
        e.recurrence,
        NOW(),
        30,
        e.start_time
    ) as occ
)
SELECT 
    a.title as event1,
    b.title as event2,
    a.event_time as conflict_time
FROM all_occurrences a
JOIN all_occurrences b ON a.event_time = b.event_time AND a.id < b.id
ORDER BY a.event_time;
```

## Common RRULE Patterns

Here are common recurrence patterns you can use:

```sql
-- Every day
'FREQ=DAILY'

-- Every weekday (Mon-Fri)
'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'

-- Every Monday and Wednesday
'FREQ=WEEKLY;BYDAY=MO,WE'

-- Every 2 weeks
'FREQ=WEEKLY;INTERVAL=2'

-- First Monday of every month
'FREQ=MONTHLY;BYDAY=1MO'

-- Last Friday of every month
'FREQ=MONTHLY;BYDAY=-1FR'

-- 15th of every month
'FREQ=MONTHLY;BYMONTHDAY=15'

-- Every 3 months (quarterly)
'FREQ=MONTHLY;INTERVAL=3'

-- Yearly on December 25
'FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25'

-- Daily for 10 occurrences only
'FREQ=DAILY;COUNT=10'

-- Daily until March 31, 2025
'FREQ=DAILY;UNTIL=20250331T235959Z'

-- Every weekday until specific date
'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;UNTIL=20251231T235959Z'
```

## Important Notes

### The `dtstart` Parameter

All occurrence functions require a `dtstart` (start datetime) parameter. This is important because:

1. **RRULE alone doesn't specify when events start** - it only defines the pattern
2. **The time component matters** - if dtstart is 9:00 AM, all occurrences will be at 9:00 AM
3. **It's the reference point** - RRULE calculations use dtstart as the baseline

```sql
-- Same RRULE, different dtstart = different results
SELECT rrule_next_occurrence(
    'FREQ=DAILY'::rrule,
    '2025-01-05'::timestamptz,
    '2025-01-01 09:00:00+00'::timestamptz  -- 9 AM start
);
-- Returns: 2025-01-06 09:00:00+00

SELECT rrule_next_occurrence(
    'FREQ=DAILY'::rrule,
    '2025-01-05'::timestamptz,
    '2025-01-01 14:30:00+00'::timestamptz  -- 2:30 PM start
);
-- Returns: 2025-01-06 14:30:00+00
```

### Safety Limits

- `rrule_occurrences()`: Maximum 1,000 occurrences (hardcoded)
- `rrule_next_occurrences()`: Maximum 10,000 occurrences (validated)

For infinite recurrences without COUNT/UNTIL, always use date ranges or count limits to avoid performance issues.

### Timezones

All timestamps are stored as `TIMESTAMPTZ` (timestamp with time zone). The extension uses UTC internally for calculations and preserves your input timezone.

## Troubleshooting

**Error: "invalid RRULE string"**
- Check your RRULE syntax against RFC 5545
- Use `rrule_is_valid()` to test before inserting

**No results returned**
- Verify your date range includes the event start time
- Check that `dtstart` is before your query range
- Ensure COUNT/UNTIL limits haven't been reached

**Performance issues**
- Use date ranges instead of requesting thousands of occurrences
- Add appropriate indexes on timestamp columns
- Consider materializing common queries into a view

## See Also

- [README.md](../README.md) - Installation and setup
- [DOCKER.md](DOCKER.md) - Docker development guide
- [RFC 5545](https://tools.ietf.org/html/rfc5545) - iCalendar specification
