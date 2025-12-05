#!/bin/bash

# Check for required CLI argument
if [ -z "$1" ]; then
  echo "Usage: $0 <number_of_instances>"
  exit 1
fi

NUM_INSTANCES="$1"
PIDS=()

# Handle Ctrl+C to kill all child processes
cleanup() {
  echo ""
  echo "Stopping all Godot instances..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  exit 0
}
trap cleanup SIGINT

# Launch Godot instances
for ((i=0; i<NUM_INSTANCES; i++)); do
  CHAR_CODE=$((66 + i))  # Start from ASCII 'B' (66)
  LETTER=$(printf "\\x$(printf %x "$CHAR_CODE")")
  echo "Starting Node$LETTER..."
  godot --path . --headless --node-name "Node$LETTER" &
  PIDS+=($!)

  sleep 0.5
done

# Wait for all background processes
wait

