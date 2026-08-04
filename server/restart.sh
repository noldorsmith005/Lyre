#!/bin/bash


PROCESS_NAME="lyre-server"
SCRIPT_PATH="/home/nate_g/Desktop/lyre/server.py"

LOG_FILE="/home/nate_g/Desktop/lyre/log.txt"
PID_FILE="/home/nate_g/Desktop/lyre/pidfile.pid"

PYTHON_EXEC="/home/nate_g/miniconda3/envs/lyre/bin/python3"

echo "Restarting server..."

start-stop-daemon --stop --oknodo --pidfile "$PID_FILE"

sleep 1

start-stop-daemon --start --background \
    --pidfile "$PID_FILE" --make-pidfile \
    --exec "$PYTHON_EXEC" \
    --no-close \
    -- "$SCRIPT_PATH" > "$LOG_FILE" 2>&1

echo "Server restarted."


