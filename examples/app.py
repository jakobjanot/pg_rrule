#!/usr/bin/env python3
"""
Calendar Application Demo using pg_rrule PostgreSQL Extension

This demonstrates how to use the pg_rrule extension to manage recurring events.
"""

import psycopg2
import os
from datetime import datetime, timedelta

def main():
    # Connect to database
    database_url = os.getenv('DATABASE_URL', 
                            'postgresql://caluser:calpass@localhost:5432/calendar')
    
    print(f"Connecting to database...")
    conn = psycopg2.connect(database_url)
    cur = conn.cursor()
    
    print("\n" + "=" * 70)
    print("🗓️  Calendar Application - pg_rrule Demo")
    print("=" * 70)
    
    # Test 1: Verify extension is loaded
    print("\n✅ Verifying pg_rrule extension...")
    cur.execute("SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_rrule'")
    result = cur.fetchone()
    if result:
        print(f"   Extension '{result[0]}' version {result[1]} is installed")
    else:
        print("   ❌ Extension not found! Please install pg_rrule.")
        return
    
    # Test 2: List all events
    print("\n📋 All Recurring Events:")
    print("-" * 70)
    cur.execute("""
        SELECT id, title, description, location, 
               to_char(start_time, 'YYYY-MM-DD HH24:MI TZ') as start,
               recurrence::text
        FROM events 
        ORDER BY id
    """)
    
    for row in cur.fetchall():
        print(f"  [{row[0]}] {row[1]}")
        print(f"      Description: {row[2]}")
        print(f"      Location: {row[3]}")
        print(f"      Starts: {row[4]}")
        print(f"      Pattern: {row[5]}")
        print()
    
    # Test 3: Next occurrence of each event
    print("\n⏰ Next Occurrence of Each Event:")
    print("-" * 70)
    cur.execute("""
        SELECT 
            title,
            location,
            rrule_next_occurrence(recurrence, NOW(), start_time) as next_time
        FROM events
        ORDER BY next_time
    """)
    
    for row in cur.fetchall():
        if row[2]:
            print(f"  {row[2].strftime('%Y-%m-%d %H:%M')} - {row[0]} @ {row[1]}")
        else:
            print(f"  No future occurrences - {row[0]}")
    
    # Test 4: This week's schedule
    print("\n📅 This Week's Schedule (Next 7 Days):")
    print("-" * 70)
    cur.execute("""
        SELECT 
            e.title,
            e.location,
            occ as event_time
        FROM events e
        CROSS JOIN LATERAL rrule_next_occurrences(
            e.recurrence,
            NOW(),
            50,  -- Get up to 50 occurrences
            e.start_time
        ) as occ
        WHERE occ BETWEEN NOW() AND NOW() + INTERVAL '7 days'
        ORDER BY occ
    """)
    
    results = cur.fetchall()
    if results:
        current_date = None
        for row in results:
            event_date = row[2].date()
            if current_date != event_date:
                current_date = event_date
                print(f"\n  {event_date.strftime('%A, %B %d, %Y')}:")
            print(f"    {row[2].strftime('%H:%M')} - {row[0]} @ {row[1]}")
    else:
        print("  No events scheduled this week")
    
    # Test 5: Count events this month
    print("\n📊 Event Statistics for This Month:")
    print("-" * 70)
    cur.execute("""
        SELECT 
            e.title,
            COUNT(*) as count,
            MIN(occ) as first_occurrence,
            MAX(occ) as last_occurrence
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
        print(f"    First: {row[2].strftime('%Y-%m-%d %H:%M')}")
        print(f"    Last:  {row[3].strftime('%Y-%m-%d %H:%M')}")
        print()
    
    # Test 6: Test RRULE validation
    print("\n🔍 Testing RRULE Validation:")
    print("-" * 70)
    test_rules = [
        ('FREQ=DAILY', 'Daily recurrence'),
        ('FREQ=WEEKLY;BYDAY=MO,WE,FR', 'Weekday recurrence'),
        ('FREQ=MONTHLY;BYMONTHDAY=15', 'Monthly on the 15th'),
        ('INVALID_RULE', 'Invalid rule'),
        ('FREQ=WRONG', 'Wrong frequency'),
    ]
    
    for rule, description in test_rules:
        cur.execute("SELECT rrule_is_valid(%s)", (rule,))
        is_valid = cur.fetchone()[0]
        status = "✅ Valid" if is_valid else "❌ Invalid"
        print(f"  {status}: {rule}")
        print(f"           ({description})")
    
    # Test 7: Get next 5 daily standups
    print("\n📆 Next 5 Daily Standups:")
    print("-" * 70)
    cur.execute("""
        SELECT 
            rrule_next_occurrences(recurrence, NOW(), 5, start_time) as occurrence
        FROM events
        WHERE title = 'Daily Standup'
    """)
    
    for i, row in enumerate(cur.fetchall(), 1):
        print(f"  {i}. {row[0].strftime('%Y-%m-%d %H:%M')}")
    
    print("\n" + "=" * 70)
    print("✅ All demonstrations complete!")
    print("=" * 70)
    print()
    
    # Close connection
    cur.close()
    conn.close()

if __name__ == "__main__":
    try:
        main()
    except psycopg2.Error as e:
        print(f"\n❌ Database error: {e}")
    except Exception as e:
        print(f"\n❌ Error: {e}")
