#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/Library/Logs/AF-LLM/startup.log"

if [[ ! -f "$LOG" ]]; then
  echo "Startup log not found at $LOG"
  exit 1
fi

echo "===== Startup Log Summary ====="
echo "Log: $LOG"
echo "Total lines: $(wc -l < "$LOG")"
echo "Health checks (approx): $(grep -i -c 'health' "$LOG")"
echo "Server start events: $(grep -i -E 'Starting AF-LLM|Server restarted|Server started|Restarted' -c "$LOG")"
echo "Errors/Warnings: $(grep -i -E 'error|failed|backend|warn' "$LOG" | wc -l)"
echo
echo "Last 50 lines:"
tail -n 50 "$LOG"
echo "===== End ====="
