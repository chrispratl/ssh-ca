# SSH-CA - Hashicorp Vault Option

I changed my mind and setup Hashicorp Vault. These are my scripts for using Hashicorp Vault as a Server CA.

Note: The Client CA part is still missing, I am currently still doing that via the `cert.sh` script.

## How to setup

* Hashicorp Vault:
    * Setup roles for your servers. For now, I will assume that you already did that. <br>
      A note about my scripts: My security concept is not yet finished, it's just a role ID bound to an IP address. This is probably not enough for most relevant workloads, but note that another security policy will change the token obtaining workflow in the renewal script.
    * Add the following policy for your server role:
    ```
   cat <<EOT > ssh-server-ca-policy.hcl
   path "ssh-server-ca/sign/server-signing" {
        capabilities = ["create", "update"]
    }
   EOT
   vault policy write ssh-server-ca ./ssh-server-ca-policy.hcl
   ```
    * Setup a SSH secret engine, call it `ssh-server-ca`. Import a key or let a new one be created, it doesn't really matter. I did not that much of configuration here, just defined a max TTL of $50$ days (which is not really required anyways).
        * In configuration, setup a private & public key for signing. Note that my scripts are using the `ed25519` protocol, which is not the default. If you want to let Vault setup a keypair for you, use something like the following command: `vault write ssh-server-ca/config/ca key_type=ed25519 generate_signing_key=true`
    * In the `ssh-client-ca`, create a new role called `server-signing`. I did the following configuration here:
        * Allow host certificates (note: Disallow user certificates)
        * Set Max TTL to $10$ days (following the Let's Encrypt concept: Make your certificates short so that renewal has to be automated)
        * I left the rest on default.
* Now, setup the client:
    * Copy the two scripts (`check-ssh-host-certificate-renew.sh` and `renew-ssh-host-certificate.sh`) to the server, into `/opt/secrets` (this path is hard-coded on multiple positions!)
    * Create a new file `/opt/secrets/roleid.txt` which - surprise - contains the role ID
    * Copy the `service` and the `timer` file to `/etc/systemd/system/` on the server
* Setup the renewal: `systemctl daemon-reload && systemctl enable ssh-host-certificate-renew.timer`

## What happens?
* The timer fires every hour. This is fine because in most of the cases, not that much happens.
* If the timer fires, the `check-ssh-host-certificate-renewal.sh` script is executed. This one checks if the host certificate is available and if the expiry date is less than $2$ days in the future, it calls the renew script. If the certificate does not exist or if `ssh-keygen` is unable to read the expiry date, the renew script is also called. <br>
  As already written, note that this command does essentially nothing most of the time. Hence it is okay to call it every hour.
* The renew script now does the following:
    * First, authenticate against Hashicorp vault.
    * Then, using the local SSH `ed25519` server public key, get this one signed.
    * Finally, write the new certificate to the correct file.

Note that the reconfiguration of the `sshd` daemon is still required, as before.
