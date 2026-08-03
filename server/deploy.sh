echo "Deploying..."
scp -P 9999 ./server.py nate_g@192.168.1.148:/home/nate_g/Desktop/lyre/

echo "server.py deployed. "

ssh user@remote-server-ip "bash ./restart.sh"
