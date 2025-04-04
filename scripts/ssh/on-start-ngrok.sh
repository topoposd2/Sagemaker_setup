#!/usr/bin/env bash

echo "Setting up SSH with ngrok..."

# Downloading and setting up ngrok
echo "Downloading ngrok..."
curl -sSL https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -o ngrok.zip
unzip -o ngrok.zip
chmod +x ngrok
mv ngrok /usr/local/bin/

# Create ngrok config file
echo "Creating config file /home/ec2-user/SageMaker/.ngrok/config.yml..."
mkdir -p /home/ec2-user/SageMaker/.ngrok
if [[ ! -e /home/ec2-user/SageMaker/.ngrok/config.yml ]]; then
    cat > /home/ec2-user/SageMaker/.ngrok/config.yml <<EOF
authtoken: $NGROK_AUTH_TOKEN
tunnels:
    ssh:
        proto: tcp
        addr: 22
EOF
    chown -R ec2-user:ec2-user /home/ec2-user/SageMaker/.ngrok
fi

# Create start-ngrok-ssh script
echo "Creating /usr/bin/start-ngrok-ssh..."
cat > /usr/bin/start-ngrok-ssh <<'EOF'
#!/usr/bin/env bash

set -e

echo "Starting ngrok..."
/usr/local/bin/ngrok start --all --log=stdout --config /home/ec2-user/SageMaker/.ngrok/config.yml > /home/ec2-user/SageMaker/ngrok.log &
sleep 10

TUNNEL_URL=$(grep -Eo 'url=.+' /home/ec2-user/SageMaker/ngrok.log | cut -d= -f2)
if [[ -z $TUNNEL_URL ]]; then
    echo "Failed to set up SSH with ngrok"
    echo "Ngrok logs:"
    cat /home/ec2-user/SageMaker/ngrok.log
fi

echo "SSH address ${TUNNEL_URL}"

cat > /home/ec2-user/SageMaker/SSH_INSTRUCTIONS <<EOD
SSH enabled through ngrok!
Address: ${TUNNEL_URL}

Use 'ssh -p <port_from_above> ec2-user@<host_from_above>' to SSH here!
EOD
EOF

chmod +x /usr/bin/start-ngrok-ssh
chown ec2-user:ec2-user /usr/bin/start-ngrok-ssh

# Create copy-ssh-keys script
echo "Creating /usr/bin/copy-ssh-keys..."
cat > /usr/bin/copy-ssh-keys <<'EOF'
#!/usr/bin/env bash

set -e

mkdir -p /home/ec2-user/.ssh && chown ec2-user:ec2-user /home/ec2-user/.ssh
mkdir -p /home/ec2-user/SageMaker/ssh && chown -R ec2-user:ec2-user /home/ec2-user/SageMaker/ssh

touch /home/ec2-user/SageMaker/ssh/authorized_keys
chown ec2-user:ec2-user /home/ec2-user/SageMaker/ssh/authorized_keys

cnt=$(cat /home/ec2-user/SageMaker/ssh/authorized_keys | wc -l)
echo "Copying ${cnt} SSH keys..."
cp /home/ec2-user/SageMaker/ssh/authorized_keys /home/ec2-user/.ssh/authorized_keys
EOF

chmod +x /usr/bin/copy-ssh-keys
chown ec2-user:ec2-user /usr/bin/copy-ssh-keys

# Run the copy-ssh-keys and start-ngrok-ssh scripts
copy-ssh-keys
start-ngrok-ssh
