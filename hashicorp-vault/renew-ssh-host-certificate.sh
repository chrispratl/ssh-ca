#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to use this script."
    exit 1
fi

# Get the SSH public key
ssh_public_key=$(cat /etc/ssh/ssh_host_ed25519_key.pub)
config_file=config.json

# Check if the configuration file exists
if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file '$config_file' not found!"
    exit 2
fi

server=$( jq -r .server "$config_file" )
roleid=$( jq -r .roleid "$config_file" )
port=$( jq -r .port "$config_file" )
sshEnginePath=$( jq -r .sshEnginePath "$config_file" )
hostRole=$( jq -r .hostRole "$config_file" )
appRole=$( jq -r .appRole "$config_file" )

# Ensure variables are set
if [[ "$server" == "null" || "$appRole" == "null" || "$roleid" == "null" || "$sshEnginePath" == "null" || "$hostRole" == "null" ]]; then
    echo "Error: One or more variables are not set in the configuration file!"
    exit 3
fi

if [[ -z "$port" ]]; then
	port=8200
fi

# Obtain a token from Vault
token=$(
    curl --silent --show-error -XPOST \
        --data "{\"role_id\": \"${roleid}\"}" \
        "https://${server}:${port}/v1/auth/${appRole}/login" 2>&1
)
if [ $? -ne 0 ] ; then
   echo "Error: $token"
   exit 4
fi
token=$(echo $token | jq -r ".auth.client_token")

# Get a new certificate
cert=$(
    curl -s -XPOST \
        --header "X-Vault-Token: $token" \
        --data "{ \
            \"public_key\": \"$ssh_public_key\", \
	    \"valid_principals\": \"$(hostname -f)\", \
            \"cert_type\": \"host\"\
        }" \
        "https://${server}:${port}/v1/${sshEnginePath}/sign/${hostRole}"
)
cert=$(echo $cert | jq -r ".data.signed_key")
# Put the new certificate to the correct position
if [[ -v cert && "$cert" != "null" ]]
then
	echo $cert > /etc/ssh/ssh_host_ed25519_key-cert.pub
else
	echo "Error during cert signing"
	exit 4
fi

