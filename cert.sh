#!/bin/bash

# chdir to the right working directory
# cd /root/ssh-ca

# Get hostname of the server
server=$1

# Check if the server hostname is given - otherwise, exit
if [[ $server == "" ]]
then
    echo Please specify a host.
    exit 1
fi

# Check if the serial file exists and create it otherwise
if [ ! -f serial ]; then
    echo "1" > serial
fi

# Get the serial number
serial=$(cat serial)

# change directory to the server
cd $server

# Find infile
for infile in id_ecdsa id_rsa id_ed25519 ssh_host_rsa_key ssh_host_ecdsa_key ssh_host_ed25519_key
do
    if [[ -f $infile.pub ]]
    then
        break
    fi
done
if [[ ! -f $infile.pub ]]
then
    echo No public key file found. The script does not work now.
    exit 1
fi
if [[ $infile == ssh_host* ]]
then
    command="ssh-keygen -h"
else
    command=ssh-keygen
fi

# Check if principals are given
if [[ -f principals ]]
then
    principals=$(cat principals)
else
    principals=$server
fi

# Create the certificate
$command \
    -s ../ca \
    -I $server \
    -V +35d \
    -z $serial \
    -n $principals \
    $infile.pub

mv $infile-cert.pub current-cert.pub

# Update serial number
cd ..
serial=$(($serial+1))
echo $serial > serial
