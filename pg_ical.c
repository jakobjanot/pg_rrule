#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
#include "utils/timestamp.h"
#include "funcapi.h"
#include "access/htup_details.h"
#include "catalog/pg_type.h"
#include "libical/ical.h"
#include <string.h>
#include <time.h>

PG_MODULE_MAGIC;

/* RRULE type structure */
typedef struct {
    int32 vl_len_;  /* varlena header (do not touch directly!) */
    char data[FLEXIBLE_ARRAY_MEMBER];  /* RRULE string */
} rrule;

/* Helper function to convert PostgreSQL timestamp to icaltimetype */
static struct icaltimetype
timestamp_to_icaltime(TimestampTz ts)
{
    struct pg_tm tm;
    fsec_t fsec;
    struct icaltimetype icaltime;

    if (timestamp2tm(ts, NULL, &tm, &fsec, NULL, NULL) != 0)
        ereport(ERROR,
                (errcode(ERRCODE_DATETIME_VALUE_OUT_OF_RANGE),
                 errmsg("timestamp out of range")));

    icaltime.year = tm.tm_year;
    icaltime.month = tm.tm_mon;
    icaltime.day = tm.tm_mday;
    icaltime.hour = tm.tm_hour;
    icaltime.minute = tm.tm_min;
    icaltime.second = tm.tm_sec;
    icaltime.is_date = 0;
    icaltime.is_daylight = 0;
    icaltime.zone = icaltimezone_get_utc_timezone();

    return icaltime;
}

/* Helper function to convert icaltimetype to PostgreSQL timestamp */
static TimestampTz
icaltime_to_timestamp(struct icaltimetype icaltime)
{
    struct pg_tm tm;
    fsec_t fsec = 0;

    tm.tm_year = icaltime.year;
    tm.tm_mon = icaltime.month;
    tm.tm_mday = icaltime.day;
    tm.tm_hour = icaltime.hour;
    tm.tm_min = icaltime.minute;
    tm.tm_sec = icaltime.second;
    tm.tm_isdst = 0;

    return tm2timestamp(&tm, fsec, NULL, NULL);
}

/* Input function for rrule type */
PG_FUNCTION_INFO_V1(rrule_in);
Datum
rrule_in(PG_FUNCTION_ARGS)
{
    char *str = PG_GETARG_CSTRING(0);
    rrule *result;
    size_t len;
    struct icalrecurrencetype recur;

    /* Validate RRULE string */
    recur = icalrecurrencetype_from_string(str);
    if (recur.freq == ICAL_NO_RECURRENCE)
        ereport(ERROR,
                (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                 errmsg("invalid RRULE string: \"%s\"", str)));

    /* Allocate and copy */
    len = strlen(str);
    result = (rrule *) palloc(VARHDRSZ + len + 1);
    SET_VARSIZE(result, VARHDRSZ + len + 1);
    memcpy(result->data, str, len + 1);

    PG_RETURN_POINTER(result);
}

/* Output function for rrule type */
PG_FUNCTION_INFO_V1(rrule_out);
Datum
rrule_out(PG_FUNCTION_ARGS)
{
    rrule *r = (rrule *) PG_GETARG_POINTER(0);
    char *result;

    result = pstrdup(r->data);
    PG_RETURN_CSTRING(result);
}

/* Validate RRULE string */
PG_FUNCTION_INFO_V1(rrule_is_valid);
Datum
rrule_is_valid(PG_FUNCTION_ARGS)
{
    text *rrule_text = PG_GETARG_TEXT_PP(0);
    char *str;
    struct icalrecurrencetype recur;

    str = text_to_cstring(rrule_text);
    recur = icalrecurrencetype_from_string(str);

    PG_RETURN_BOOL(recur.freq != ICAL_NO_RECURRENCE);
}

/* Get occurrences between two timestamps */
PG_FUNCTION_INFO_V1(rrule_occurrences);
Datum
rrule_occurrences(PG_FUNCTION_ARGS)
{
    FuncCallContext *funcctx;
    struct icaltimetype *times;
    int call_cntr;
    int max_calls;

    if (SRF_IS_FIRSTCALL())
    {
        MemoryContext oldcontext;
        rrule *r = (rrule *) PG_GETARG_POINTER(0);
        TimestampTz start_ts = PG_GETARG_TIMESTAMPTZ(1);
        TimestampTz end_ts = PG_GETARG_TIMESTAMPTZ(2);
        TimestampTz dtstart_ts = PG_GETARG_TIMESTAMPTZ(3);
        
        struct icalrecurrencetype recur;
        struct icaltimetype dtstart, start, end, next;
        icalrecur_iterator *ritr;
        int count = 0;
        int max_occurrences = 1000;  /* Safety limit */

        funcctx = SRF_FIRSTCALL_INIT();
        oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

        /* Parse RRULE */
        recur = icalrecurrencetype_from_string(r->data);
        
        /* Convert timestamps */
        dtstart = timestamp_to_icaltime(dtstart_ts);
        start = timestamp_to_icaltime(start_ts);
        end = timestamp_to_icaltime(end_ts);

        /* Allocate array for results */
        times = (struct icaltimetype *) palloc(max_occurrences * sizeof(struct icaltimetype));

        /* Generate occurrences */
        ritr = icalrecur_iterator_new(recur, dtstart);
        for (next = icalrecur_iterator_next(ritr); 
             !icaltime_is_null_time(next) && count < max_occurrences;
             next = icalrecur_iterator_next(ritr))
        {
            if (icaltime_compare(next, end) > 0)
                break;
            
            if (icaltime_compare(next, start) >= 0)
            {
                times[count++] = next;
            }
        }
        icalrecur_iterator_free(ritr);

        funcctx->user_fctx = times;
        funcctx->max_calls = count;

        MemoryContextSwitchTo(oldcontext);
    }

    funcctx = SRF_PERCALL_SETUP();
    times = (struct icaltimetype *) funcctx->user_fctx;
    call_cntr = funcctx->call_cntr;
    max_calls = funcctx->max_calls;

    if (call_cntr < max_calls)
    {
        TimestampTz result = icaltime_to_timestamp(times[call_cntr]);
        SRF_RETURN_NEXT(funcctx, TimestampTzGetDatum(result));
    }
    else
    {
        SRF_RETURN_DONE(funcctx);
    }
}

/* Get next N occurrences */
PG_FUNCTION_INFO_V1(rrule_next_occurrences);
Datum
rrule_next_occurrences(PG_FUNCTION_ARGS)
{
    FuncCallContext *funcctx;
    struct icaltimetype *times;
    int call_cntr;
    int max_calls;

    if (SRF_IS_FIRSTCALL())
    {
        MemoryContext oldcontext;
        rrule *r = (rrule *) PG_GETARG_POINTER(0);
        TimestampTz from_ts = PG_GETARG_TIMESTAMPTZ(1);
        int32 limit = PG_GETARG_INT32(2);
        TimestampTz dtstart_ts = PG_GETARG_TIMESTAMPTZ(3);
        
        struct icalrecurrencetype recur;
        struct icaltimetype dtstart, from, next;
        icalrecur_iterator *ritr;
        int count = 0;

        funcctx = SRF_FIRSTCALL_INIT();
        oldcontext = MemoryContextSwitchTo(funcctx->multi_call_memory_ctx);

        /* Validate limit */
        if (limit <= 0 || limit > 10000)
            ereport(ERROR,
                    (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
                     errmsg("count must be between 1 and 10000")));

        /* Parse RRULE */
        recur = icalrecurrencetype_from_string(r->data);
        
        /* Convert timestamps */
        dtstart = timestamp_to_icaltime(dtstart_ts);
        from = timestamp_to_icaltime(from_ts);

        /* Allocate array for results */
        times = (struct icaltimetype *) palloc(limit * sizeof(struct icaltimetype));

        /* Generate occurrences */
        ritr = icalrecur_iterator_new(recur, dtstart);
        for (next = icalrecur_iterator_next(ritr); 
             !icaltime_is_null_time(next) && count < limit;
             next = icalrecur_iterator_next(ritr))
        {
            if (icaltime_compare(next, from) > 0)
            {
                times[count++] = next;
            }
        }
        icalrecur_iterator_free(ritr);

        funcctx->user_fctx = times;
        funcctx->max_calls = count;

        MemoryContextSwitchTo(oldcontext);
    }

    funcctx = SRF_PERCALL_SETUP();
    times = (struct icaltimetype *) funcctx->user_fctx;
    call_cntr = funcctx->call_cntr;
    max_calls = funcctx->max_calls;

    if (call_cntr < max_calls)
    {
        TimestampTz result = icaltime_to_timestamp(times[call_cntr]);
        SRF_RETURN_NEXT(funcctx, TimestampTzGetDatum(result));
    }
    else
    {
        SRF_RETURN_DONE(funcctx);
    }
}

/* Get next occurrence after a given date */
PG_FUNCTION_INFO_V1(rrule_next_occurrence);
Datum
rrule_next_occurrence(PG_FUNCTION_ARGS)
{
    rrule *r = (rrule *) PG_GETARG_POINTER(0);
    TimestampTz after_ts = PG_GETARG_TIMESTAMPTZ(1);
    TimestampTz dtstart_ts = PG_GETARG_TIMESTAMPTZ(2);
    
    struct icalrecurrencetype recur;
    struct icaltimetype dtstart, after, next;
    icalrecur_iterator *ritr;
    TimestampTz result;

    /* Parse RRULE */
    recur = icalrecurrencetype_from_string(r->data);
    
    /* Convert timestamps */
    dtstart = timestamp_to_icaltime(dtstart_ts);
    after = timestamp_to_icaltime(after_ts);

    /* Find next occurrence */
    ritr = icalrecur_iterator_new(recur, dtstart);
    for (next = icalrecur_iterator_next(ritr); 
         !icaltime_is_null_time(next);
         next = icalrecur_iterator_next(ritr))
    {
        if (icaltime_compare(next, after) > 0)
        {
            result = icaltime_to_timestamp(next);
            icalrecur_iterator_free(ritr);
            PG_RETURN_TIMESTAMPTZ(result);
        }
    }
    
    icalrecur_iterator_free(ritr);
    PG_RETURN_NULL();
}
