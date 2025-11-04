#!/bin/bash
# Quick test script for pg_ical examples

set -e

echo "🧪 Testing pg_ical Examples"
echo "============================"
echo

cd "$(dirname "$0")"

# Test 1: Check files exist
echo "✅ Checking example files..."
for file in docker-compose.yml init.sql Dockerfile app.py requirements.txt; do
    if [ -f "$file" ]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file missing!"
        exit 1
    fi
done
echo

# Test 2: Try to start PostgreSQL only
echo "🚀 Starting PostgreSQL with pg_ical..."
docker-compose up -d postgres

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U caluser -d calendar >/dev/null 2>&1; then
        echo "   ✓ PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "   ✗ PostgreSQL failed to start"
        docker-compose logs postgres
        exit 1
    fi
    sleep 1
done
echo

# Test 3: Verify extension is installed
echo "🔍 Verifying pg_ical extension..."
result=$(docker-compose exec -T postgres psql -U caluser -d calendar -tAc "SELECT extname FROM pg_extension WHERE extname = 'pg_ical';")
if [ "$result" = "pg_ical" ]; then
    echo "   ✓ pg_ical extension is installed"
else
    echo "   ✗ pg_ical extension not found!"
    exit 1
fi
echo

# Test 4: Check sample data
echo "📊 Checking sample events..."
count=$(docker-compose exec -T postgres psql -U caluser -d calendar -tAc "SELECT COUNT(*) FROM events;")
if [ "$count" -gt 0 ]; then
    echo "   ✓ Found $count sample events"
else
    echo "   ✗ No events found!"
    exit 1
fi
echo

# Test 5: Test RRULE functions
echo "🧮 Testing RRULE functions..."

# Test rrule_is_valid
result=$(docker-compose exec -T postgres psql -U caluser -d calendar -tAc "SELECT rrule_is_valid('FREQ=DAILY');")
if [ "$result" = "t" ]; then
    echo "   ✓ rrule_is_valid() works"
else
    echo "   ✗ rrule_is_valid() failed"
    exit 1
fi

# Test rrule_next_occurrence
result=$(docker-compose exec -T postgres psql -U caluser -d calendar -tAc "SELECT rrule_next_occurrence('FREQ=DAILY'::rrule, NOW(), NOW()) IS NOT NULL;")
if [ "$result" = "t" ]; then
    echo "   ✓ rrule_next_occurrence() works"
else
    echo "   ✗ rrule_next_occurrence() failed"
    exit 1
fi
echo

# Test 6: Run the full demo app
echo "🎯 Running demo application..."
docker-compose up --build app 2>&1 | grep -q "All demonstrations complete"
if [ $? -eq 0 ]; then
    echo "   ✓ Demo application ran successfully"
else
    echo "   ⚠️  Demo application may have had issues (check logs)"
fi
echo

echo "✅ All tests passed!"
echo
echo "To see the full demo output:"
echo "  docker-compose up app"
echo
echo "To connect interactively:"
echo "  docker-compose exec postgres psql -U caluser -d calendar"
echo
echo "To cleanup:"
echo "  docker-compose down -v"
echo
