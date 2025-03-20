#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it to use this script."
    exit 1
fi

config_file=config.json


# Check if the configuration file exists
if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file '$config_file' not found!"
    exit 2
fi

min_valid_days=$( jq -r .min_valid_days "$config_file" )

if [[ -z "$min_valid_days" ]]; then
        min_valid_days=8
fi

CERT_FILE="/etc/ssh/ssh_host_ed25519_key-cert.pub"

if [ -f "$CERT_FILE" ]; then
	# Store the expiry date in a variable
	cert_expiry_date=$(ssh-keygen -L -f "$CERT_FILE" | grep "Valid:" | cut -d " " -f 13)

	# Store the expiry date as seconds since the epoch
	cert_expiry_seconds=$(date +%s -d $cert_expiry_date)

	if [ $? -ne 0 ]; then
		# If finding the date failed, do the renew for sure
		/opt/secrets/renew-ssh-host-certificate.sh
	else

		# Store the time "now" as seconds since the epoch
		now=$(date +%s)

		# Compute the number of days between "now" and "cert expiry"
		# Note: No spaces for the division! Otherwise, bash fails.
		let validity=($cert_expiry_seconds - $now)/86400

		if [ $validity -lt $min_valid_days ]; then
			/opt/secrets/renew-ssh-host-certificate.sh
		fi
	fi
else
	/opt/secrets/renew-ssh-host-certificate.sh
fi
