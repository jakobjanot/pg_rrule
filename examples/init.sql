-- Initialize the database with pg_ical extension and sample data

-- Enable the extension
CREATE EXTENSION IF NOT EXISTS pg_ical;

-- Create events table
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    location TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    recurrence rrule,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert sample recurring events
INSERT INTO events (title, description, location, start_time, recurrence) VALUES
    ('Daily Standup', 'Team sync meeting', 'Zoom Room A', '2025-11-05 09:00:00+00', 'FREQ=DAILY'),
    ('Weekly Review', 'Monday team review', 'Conference Room B', '2025-11-11 14:00:00+00', 'FREQ=WEEKLY;BYDAY=MO'),
    ('Bi-weekly Sprint Planning', 'Sprint planning session', 'Main Hall', '2025-11-11 10:00:00+00', 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO'),
    ('Monthly All-Hands', 'Company wide meeting', 'Auditorium', '2025-11-15 15:00:00+00', 'FREQ=MONTHLY;BYMONTHDAY=15'),
    ('Coffee Chat', 'Informal Thursday catch-up', 'Cafeteria', '2025-11-07 14:00:00+00', 'FREQ=WEEKLY;BYDAY=TH'),
    ('Quarterly Review', 'Q4 review meeting', 'Board Room', '2025-11-01 16:00:00+00', 'FREQ=MONTHLY;INTERVAL=3');

-- Create a view for upcoming events
CREATE OR REPLACE VIEW upcoming_events AS
SELECT 
    e.id,
    e.title,
    e.description,
    e.location,
    rrule_next_occurrence(e.recurrence, NOW(), e.start_time) as next_occurrence
FROM events e
WHERE rrule_next_occurrence(e.recurrence, NOW(), e.start_time) IS NOT NULL
ORDER BY next_occurrence;

-- Grant permissions (if needed)
-- GRANT ALL ON events TO caluser;
-- GRANT ALL ON upcoming_events TO caluser;

\echo 'Database initialized with pg_ical extension!'
\echo 'Sample events created. Try: SELECT * FROM upcoming_events;'
