#!/bin/bash

set -e

cert=$(
    curl -s \
        "{{ url_for('sign_certificate_v1', name=hostname) }}"
)

echo $cert > /etc/ssh/ssh_host_ed25519_key-cert.pub

systemctl restart ssh
mkdir -p /run/sshd
