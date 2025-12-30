# Ansible Homelab Bootstrap

This repository provides scripts and Ansible playbooks to quickly bootstrap a fresh Linux system with your preferred configuration, packages, and secrets management using 1Password.

## Quick Start: Remote Bootstrap

To run the initialization script on a fresh Linux install (Debian/Ubuntu), you can execute the following commands from your new machine:


Firstly, add the user to sudoers:
```bash
su -
usermod -aG sudo <username>
reboot
```

```bash
cp falcon-sensor.deb ~/
sudo apt install curl
curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/init.sh -o init.sh
chmod +x init.sh
sudo ./init.sh
./ansible.sh
```

- This command downloads and runs the latest `init.sh` directly from the main branch.
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
- Debian/Ubuntu-based system
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
