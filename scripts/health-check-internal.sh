#!/bin/bash
# Wozark Health Check (internal) — run from VPS via SSH
# Checks ALL services including internal-only ones
# Exit code: 0 = all healthy, 1 = something down
#
# Usage from dev machine:
#   ssh root@168.231.70.56 'bash -s' < scripts/health-check-internal.sh

FAILURES=0

check_http() {
    local name=$1
    local url=$2
    local timeout=${3:-5}

    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$url" 2>/dev/null)
    if [ "$status" = "200" ]; then
        echo "  OK   $name"
    else
        echo "  FAIL $name (HTTP $status)"
        FAILURES=$((FAILURES + 1))
    fi
}

check_tcp() {
    local name=$1
    local host=$2
    local port=$3

    if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "  OK   $name"
    else
        echo "  FAIL $name (connection refused)"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "=== Wozark Health Check (internal/VPS) ==="
echo "$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# All services via CapRover internal network
check_http "Ruth  (sensor)"    "http://srv-captain--wbot-ruth-prod:8080/health"
check_http "Wendy (brain)"     "http://srv-captain--wendy:3000/health"
check_http "Jonah (analyst)"   "http://srv-captain--jonah:8000/health" 10
check_http "Marty (dashboard)" "https://marty.wozark.com"

# Database
check_tcp  "PostgreSQL"        "srv-captain--wbot-db" "5432"

echo ""
if [ $FAILURES -eq 0 ]; then
    echo "All services healthy"
    exit 0
else
    echo "$FAILURES service(s) down"
    exit 1
fi
