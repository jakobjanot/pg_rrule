-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_ical" to load this file. \quit

-- RRULE data type
CREATE TYPE rrule;

-- Input/Output functions for rrule type
CREATE FUNCTION rrule_in(cstring)
RETURNS rrule
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION rrule_out(rrule)
RETURNS cstring
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

CREATE TYPE rrule (
    INPUT = rrule_in,
    OUTPUT = rrule_out,
    INTERNALLENGTH = VARIABLE,
    STORAGE = extended
);

-- Function to get occurrences between two timestamps
CREATE FUNCTION rrule_occurrences(
    rrule,
    timestamp with time zone,  -- start date
    timestamp with time zone,  -- end date
    timestamp with time zone   -- dtstart (when the recurrence starts)
)
RETURNS SETOF timestamp with time zone
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

-- Function to get the next N occurrences
CREATE FUNCTION rrule_next_occurrences(
    rrule,
    timestamp with time zone,  -- from date
    integer,                   -- count
    timestamp with time zone   -- dtstart
)
RETURNS SETOF timestamp with time zone
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

-- Function to validate RRULE string
CREATE FUNCTION rrule_is_valid(text)
RETURNS boolean
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;

-- Function to get next occurrence after a given date
CREATE FUNCTION rrule_next_occurrence(
    rrule,
    timestamp with time zone,  -- after this date
    timestamp with time zone   -- dtstart
)
RETURNS timestamp with time zone
AS 'MODULE_PATHNAME'
LANGUAGE C IMMUTABLE STRICT;
