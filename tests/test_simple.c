#include <libical/ical.h>
#include <stdio.h>

int main() {
    struct icalrecurrencetype recur;
    struct icaltimetype dtstart, next;
    icalrecur_iterator *ritr;
    
    recur = icalrecurrencetype_from_string("FREQ=DAILY");
    printf("Parsed RRULE, freq=%d\n", recur.freq);
    
    dtstart.year = 2025;
    dtstart.month = 11;
    dtstart.day = 1;
    dtstart.hour = 9;
    dtstart.minute = 0;
    dtstart.second = 0;
    dtstart.is_date = 0;
    dtstart.is_daylight = 0;
    dtstart.zone = icaltimezone_get_utc_timezone();
    
    printf("Creating iterator...\n");
    ritr = icalrecur_iterator_new(recur, dtstart);
    printf("Getting next occurrence...\n");
    next = icalrecur_iterator_next(ritr);
    printf("Year: %d\n", next.year);
    icalrecur_iterator_free(ritr);
    
    return 0;
}
