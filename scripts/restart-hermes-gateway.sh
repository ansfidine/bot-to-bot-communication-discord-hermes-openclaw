#!/bin/bash
# Restart Hermes gateway via launchd
# Force restart even if throttled

echo "Restarting Hermes gateway..."
launchctl kickstart -kp gui/$(id -u)/ai.hermes.gateway

# Wait and verify
sleep 10

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
STATE_FILE="$HERMES_HOME/gateway_state.json"
STATE=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['gateway_state'])" 2>/dev/null)
PID=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['pid'])" 2>/dev/null)

if [ "$STATE" = "running" ]; then
    echo "SUCCESS: Gateway restarted (PID: $PID)"
    exit 0
else
    echo "FAILED: Gateway state is '$STATE' (PID: $PID)"
    exit 1
fi
