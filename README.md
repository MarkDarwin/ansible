# Ansible Homelab Bootstrap

This repository provides scripts and Ansible playbooks to quickly bootstrap a fresh Linux system with your preferred configuration, packages, and secrets management using 1Password.

The expectation is we started with a clean Linux install (Debian/Ubuntu or Fedora) and chose KDE plasma, SSH server and standard system utilities.

## Quick Start: Remote Bootstrap


To run the initialization script on a fresh Linux install (Debian/Ubuntu or Fedora), you can execute the following commands from your new machine:


Firstly, add the user to sudoers (Debian/Ubuntu or Fedora):
```bash
su -
usermod -aG sudo <username>
reboot
```


### For Debian/Ubuntu:
```bash
cp falcon-sensor.deb ~/
sudo apt install curl
curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
sudo ./bootstrap.sh
./ansible.sh
```

### For Fedora:
```bash
cp falcon-sensor.rpm ~/
sudo dnf install -y curl || sudo yum install -y curl
curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
sudo ./bootstrap.sh
./ansible.sh
```

```bash
# cd into the folder containing the certificates for the VPN
for f in *.pem; do
    sudo cp "$f" "/usr/local/share/ca-certificates/${f%.pem}.crt"
done

sudo update-ca-certificates
```

> **Caution:** On the first run of the Ansible playbooks, you may see a failure due to duplicate sources. This is automatically cleaned up on the second run, so simply re-run the playbook to proceed.

- This command downloads and runs the latest `bootstrap.sh` directly from the main branch.
- You will need `curl` installed (usually present by default).
- The script will prompt for your 1Password Service Account Token if not set as an environment variable.


## Running after bootstrap phase
- Open 1Password and authenticate
- Within 1Password, setup SSH agent and integrate with the CLI

## What the Script Does
- Installs required base packages (curl, git, python3, ansible, etc.)
- Installs 1Password CLI and (optionally) Desktop app
- Authenticates with 1Password and fetches secrets
- Configures git user/email
- Sets up SSH keys from 1Password
- Installs Ansible roles and runs playbooks

## Requirements
- Debian/Ubuntu-based system **or** Fedora-based system
- Internet access
- 1Password account with CLI access

## Security
- No secrets are stored in this repository.
- All secrets are fetched securely from 1Password at runtime.
- Never commit decrypted secrets or generated secret files.

## Customization
- Edit `local.yml` and `tasks/` to customize your setup.
- Use your own 1Password vault and item names as needed.

---

**Happy bootstrapping!**
