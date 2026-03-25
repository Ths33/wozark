#!/bin/bash
# Wozark Health Check — run via cron or manually
# Checks all externally-reachable services + database
# Exit code: 0 = all healthy, 1 = something down
#
# NOTE: Ruth and Jonah are internal-only (no public domain/port).
# To check them, SSH into the VPS and run health-check-internal.sh,
# or verify indirectly via Wendy's /health (which reports trading status).

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

echo "=== Wozark Health Check (external) ==="
echo "$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# Public services
check_http "Wendy (brain)"     "https://wendy.wozark.com/health"
check_http "Marty (dashboard)" "https://marty.wozark.com"

# Database (exposed port)
check_tcp  "PostgreSQL"        "45.93.138.190" "15432"

# Internal-only — not reachable from outside CapRover network
echo ""
echo "--- Not checkable externally ---"
echo "  SKIP Ruth  (internal only — srv-captain--wbot-ruth-prod:8080)"
echo "  SKIP Jonah (internal only — srv-captain--jonah:8000, not yet deployed)"

echo ""
if [ $FAILURES -eq 0 ]; then
    echo "All reachable services healthy"
    exit 0
else
    echo "$FAILURES service(s) down"
    exit 1
fi
