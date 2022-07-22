#! /bin/bash

# https://github.com/northvolt/volt-os/blob/master/docs/connect.md

EDGE_GATEWAY_IP="fd3b:d3b5:576:1:e0dc:a065:f2d9:0"

# Install wireguard via brew
#brew install wireguard-tools

# Create Keys
wg genkey | tee privatekey | wg pubkey > publickey

WG_PUBLIC_KEY=$(cat publickey)

WG_PRIVATE_KEY=$(cat privatekey)

# Register IPv6 address and public key in AWS DynamoDB

echo Northvolt email:

read -p 'email: ' email_var

NORTHVOLT_EMAIL=email_var

YOUR_FD3B_PROD_IPv6_ADDRESS=$(python3 -c "import secrets; print('fd3b:d3b5:0576:0001:' + ':'.join(secrets.token_hex(2) for i in range(4)))")

YOUR_FD3B_DEV_IPv6_ADDRESS=$(python3 -c "import secrets; print('fd3b:d3b5:0576:0002:' + ':'.join(secrets.token_hex(2) for i in range(4)))")

YOUR_FD3B_FACTORY_IPv6_ADDRESS=$(python3 -c "import secrets; print('fd3b:d3b5:0576:0003:' + ':'.join(secrets.token_hex(2) for i in range(4)))")

cat <<EOF > /tmp/dynamodb-prod-config.json
{
    "Address": {"S": "${YOUR_FD3B_PROD_IPv6_ADDRESS}"},
    "PublicKey": {"S": "${WG_PUBLIC_KEY}"},
    "User": {"S": "${NORTHVOLT_EMAIL}"}
}
EOF

# Login to aws

aws sso login --profile=nv-automation-dev

aws dynamodb put-item --profile nv-automation \
    --table-name wg-server-voltos-prod-users \
    --item file:///tmp/dynamodb-prod-config.json

cat <<EOF > /tmp/dynamodb-dev-config.json
{
    "Address": {"S": "${YOUR_FD3B_DEV_IPv6_ADDRESS}"},
    "PublicKey": {"S": "${WG_PUBLIC_KEY}"},
    "User": {"S": "${NORTHVOLT_EMAIL}"}
}
EOF

aws dynamodb put-item --profile nv-automation-dev \
    --table-name wg-server-voltos-dev-users \
    --item file:///tmp/dynamodb-dev-config.json

cat <<EOF > /tmp/dynamodb-factory-config.json
{
    "Address": {"S": "${YOUR_FD3B_FACTORY_IPv6_ADDRESS}"},
    "PublicKey": {"S": "${WG_PUBLIC_KEY}"},
    "User": {"S": "${NORTHVOLT_EMAIL}"}
}
EOF

aws dynamodb put-item --profile nv-automation \
    --table-name wg-server-factory-voltos-prod-users \
    --item file:///tmp/dynamodb-factory-config.json


# Create WireGuard tunnel configuration files

sudo mkdir -p /usr/local/etc/wireguard

cat <<EOF | sudo tee /etc/wireguard/nv-prod.conf
[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = ${YOUR_FD3B_PROD_IPv6_ADDRESS}/64

[Peer]
PublicKey = xR3ELnMrowd+eVHv5fxpWZnMm587f5cgx350pJFQJjs=
AllowedIPs = fd3b:d3b5:576:1::/64
Endpoint = wg.aut.aws.nvlt.co:51820
PersistentKeepalive = 25
EOF

cat <<EOF | sudo tee /etc/wireguard/nv-dev.conf
[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = ${YOUR_FD3B_DEV_IPv6_ADDRESS}/64

[Peer]
PublicKey = owgUjrhu1S6U3VTs64fqCyhlbnfLT4KfGT6qRYVxvFY=
AllowedIPs = fd3b:d3b5:576:2::/64
Endpoint = wg.aut-dev.aws.nvlt.co:51820
PersistentKeepalive = 25
EOF

cat <<EOF | sudo tee /etc/wireguard/nv-factory.conf
[Interface]
PrivateKey = ${WG_PRIVATE_KEY}
Address = ${YOUR_FD3B_FACTORY_IPv6_ADDRESS}/64

[Peer]
PublicKey = QE/732Jpe8bxQnHV2FFdbdy7IKz4CUA4lRilJ5FsLFw=
AllowedIPs = fd3b:d3b5:576:3::/64
Endpoint = wg-factory.aut.aws.nvlt.co:51820
PersistentKeepalive = 25
EOF

# Select tunnel WireGuard tunnel
read -p 'Type WireGuard tunnel - [dev], [prod], [factory]:' tunnel

# Check the username and password are valid or not
if (( $tunnel == "prod"))
then
    echo -e "\n Starting dev tunnel"
    sudo wg-quick up nv-dev
elif (( $tunnel == "prod"))
then
    echo -e "\n Starting prod tunnel"
    sudo wg-quick up nv-prod
elif (( $tunnel == "factory"))
then
    echo -e "\n Starting factory tunnel"
    sudo wg-quick up nv-factory
else
    echo -e "\n Unsuccessful choice of WireGuardTunnel"
fi


# Inspect tunnel status
sudo wg show
