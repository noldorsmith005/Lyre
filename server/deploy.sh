#!/bin/bash
set -euo pipefail

echo "Deploying..."

scp -P 9999 ./server.py nate_g@192.168.1.148:/home/nate_g/Desktop/lyre/

ssh -p 9999 nate_g@192.168.1.148 "bash /home/nate_g/Desktop/lyre/restart.sh"

echo "Deployment complete."
