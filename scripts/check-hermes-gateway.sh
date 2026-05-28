#!/bin/bash
# Check if Hermes gateway is running
# Returns 0 if running, 1 if not

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
STATE_FILE="$HERMES_HOME/gateway_state.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: State file not found at $STATE_FILE"
    exit 1
fi

STATE=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['gateway_state'])" 2>/dev/null)
PID=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['pid'])" 2>/dev/null)

if [ "$STATE" != "running" ]; then
    echo "DOWN: Gateway state is '$STATE' (PID: $PID)"
    exit 1
fi

# Verify PID is actually alive
if ! kill -0 "$PID" 2>/dev/null; then
    echo "DOWN: PID $PID is not alive (state file is stale)"
    exit 1
fi

echo "OK: Gateway running (PID: $PID)"
exit 0
