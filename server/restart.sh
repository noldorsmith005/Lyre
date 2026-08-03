#!/bin/bash

PROCESS_NAME="flare-server"
SCRIPT_PATH="/path/to/your/server.py"
PYTHON_EXEC="/usr/bin/python3"
LOG_FILE="/var/log/my_python_server.log"
PID_FILE="/var/run/my_python_server.pid"

# Killing daemon
echo "Restarting server..."
start-stop-daemon --stop --oknodo --pidfile "$PID_FILE" --name "$PROCESS_NAME"

# Starting daemon
start-stop-daemon --start --background \
  --pidfile "$PID_FILE" --make-pidfile \
  --name "$PROCESS_NAME" \
  --no-close \
  --startas "$PYTHON_EXEC" -- "$SCRIPT_PATH" >> "$LOG_FILE" 2>&1

echo "Server restarted"
