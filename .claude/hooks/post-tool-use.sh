#!/bin/bash
# Post-Tool-Use Hook
# Runs after every tool use (Bash, file write, etc.)
# Appends a timestamp to memory so Claude knows what happened when

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Tool used: $CLAUDE_TOOL_NAME" \
  >> ./memory/session_activity.log
