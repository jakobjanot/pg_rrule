-- Test script for pg_ical extension
-- Run with: psql -d your_database -f test.sql

-- Create extension
CREATE EXTENSION IF NOT EXISTS pg_ical;

-- Create test table
DROP TABLE IF EXISTS events CASCADE;
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    dtstart TIMESTAMP WITH TIME ZONE NOT NULL,
    recurrence rrule
);

-- Insert test data
INSERT INTO events (title, dtstart, recurrence) VALUES
    ('Daily standup', '2025-01-01 09:00:00+00', 'FREQ=DAILY'),
    ('Weekly team meeting', '2025-01-01 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO,WE,FR'),
    ('Monthly review', '2025-01-15 10:00:00+00', 'FREQ=MONTHLY;BYMONTHDAY=15'),
    ('Bi-weekly sprint', '2025-01-01 10:00:00+00', 'FREQ=WEEKLY;INTERVAL=2'),
    ('Limited event', '2025-01-01 12:00:00+00', 'FREQ=DAILY;COUNT=5');

-- Test 1: Validate RRULE strings
SELECT 'Test 1: RRULE validation' AS test;
SELECT rrule_is_valid('FREQ=DAILY') AS valid_daily,
       rrule_is_valid('FREQ=WEEKLY;BYDAY=MO,WE') AS valid_weekly,
       rrule_is_valid('INVALID') AS invalid_rule;

-- Test 2: Get occurrences in January 2025
SELECT 'Test 2: Daily standup occurrences in first week of Jan 2025' AS test;
SELECT title, rrule_occurrences(
    recurrence,
    '2025-01-01'::timestamptz,
    '2025-01-07'::timestamptz,
    dtstart
) AS occurrence
FROM events
WHERE title = 'Daily standup'
LIMIT 10;

-- Test 3: Get next 3 occurrences of weekly meeting
SELECT 'Test 3: Next 3 weekly team meetings' AS test;
SELECT title, rrule_next_occurrences(
    recurrence,
    '2025-01-01'::timestamptz,
    3,
    dtstart
) AS occurrence
FROM events
WHERE title = 'Weekly team meeting';

-- Test 4: Get next occurrence for each event
SELECT 'Test 4: Next occurrence for each event' AS test;
SELECT title, rrule_next_occurrence(
    recurrence,
    '2025-01-01'::timestamptz,
    dtstart
) AS next_occurrence
FROM events;

-- Test 5: All events with limited count
SELECT 'Test 5: All occurrences of limited event (should be 5)' AS test;
SELECT title, rrule_occurrences(
    recurrence,
    '2025-01-01'::timestamptz,
    '2025-12-31'::timestamptz,
    dtstart
) AS occurrence
FROM events
WHERE title = 'Limited event';

-- Test 6: Monthly events
SELECT 'Test 6: Monthly review for 6 months' AS test;
SELECT title, rrule_next_occurrences(
    recurrence,
    '2025-01-01'::timestamptz,
    6,
    dtstart
) AS occurrence
FROM events
WHERE title = 'Monthly review';

-- Cleanup (commented out by default)
-- DROP TABLE events;
-- DROP EXTENSION pg_ical;
