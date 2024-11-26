# SSH-CA - Hashicorp Vault Integration

How to setup Hashicorp Vault to sign host certificates automatically. These are the scripts for using Hashicorp Vault as a Server Certificate Authority (CA).

Note: The Client CA part is still missing, this can be done via the `cert.sh` script.

## Setup
### Hashicorp Vault
 * Roles for your servers.<br/>
      A note about my scripts: My security concept is not yet finished, it's just a role ID bound to an IP address. This is probably not enough for most relevant workloads, but note that another security policy will change the token obtaining workflow in the renewal script.
    ```shell
   vault auth enable approle
   vault write auth/approle/role/renew-ssh-certs \
    token_type=batch \
    bind_secret_id=false \
    secret_id_bound_cidrs="<myIPranges/24>" \
    token_max_ttl=10m policies="ssh-ca-policy"
   vault read auth/approle/role/renew-ssh-certs/role-id
    ```
    * Add the following policy for your server role:
    ```shell
   cat <<EOT > ssh-server-ca-policy.hcl
   path "ssh-server-ca/sign/server-signing" {
        capabilities = ["create", "update"]
    }
   EOT
   vault policy write ssh-ca-policy ./ssh-server-ca-policy.hcl
   ```
 * Setup a SSH secret engine, set the path to `ssh-server-ca`.
  `vault secrets enable -path=ssh-server-ca ssh`
   <br/>Configure the CA keys:
     * To generate a new key pair:<br/>`vault write ssh-server-ca/config/ca key_type=ed25519 generate_signing_key=true`
     * To use an existing key pair:<br/>`vault write ssh-server-ca/config/ca private_key="$(cat ca.key)" public_key="$(cat ca.pub)"`
 * In the `ssh-server-ca`, create a new role called `server-signing` with the following configuration:
     * Allow host certificates
     * Set Max TTL to $10$ days (Following the Let's Encrypt model, short-lived certificates encourage automation for renewals)
 ```shell
vault write ssh-server-ca/roles/server-signing \
 key_type=ca     ttl=240h     allow_host_certificates=true \
 allowed_domains="<my.domains>"     allow_subdomains=true
 ```
### Client
 * Copy the two scripts (`check-ssh-host-certificate-renew.sh` and `renew-ssh-host-certificate.sh`) and the configuration file (`config.json`) to the servers. The path has to be `/opt/secrets` (this is hard-coded on multiple positions!)
 * Set the variables in the configuration file
 * Copy the `.service` and the `.timer` files to `/etc/systemd/system/` on the server
* Setup the renewal: `systemctl daemon-reload && systemctl enable ssh-host-certificate-renew.timer`

## How it works
* Timer-Triggered Script Execution: The timer fires hourly.
* The `check-ssh-host-certificate-renewal.sh` script is executed. This script calls the renewal script if:
   * The certificate does not exist
   * The expiry date is too close
   * ssh-keygen fails to read the expiry date
* The `renew-ssh-host-certificate-sh` script performs the following actions:
    * Authenticates with Hashicorp Vault
    * Signs the local SSH `ed25519` server public key
    * Write the new certificate to the correct file.

Note that the initial configuration of the `sshd` daemon is still required, as in `cert-sh`.
