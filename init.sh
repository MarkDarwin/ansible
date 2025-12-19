#!/usr/bin/env bash
# Initialize the environment

# Section 0: Check for sudo privileges
# This step ensures the script is run with sufficient privileges to install packages.
if ! sudo -n true 2>/dev/null; then
	echo "[ERROR] This script requires sudo privileges. Run the following commands:
  1. su -
  2. usermod -aG sudo mark
  3. reboot
Then re-run this script." >&2
	exit 1
fi

# Section 1: Update package lists
# This step ensures the system package lists are current before installing packages.
set -euo pipefail

# Colour codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

echo "${GREEN}[INFO] Updating package lists...${NC}"
if command -v apt-get >/dev/null 2>&1; then
	sudo apt-get update -y
else
	echo "${RED}[ERROR] This script only supports Debian-based systems (apt-get required).${NC}" >&2
	exit 1
fi


# Section 2: Install necessary base packages
# This step ensures required tools are present for subsequent steps.
REQUIRED_PACKAGES=(curl sudo gnupg lsb-release)


install_packages() {
	local packages=("${@}")
	if ! command -v apt-get >/dev/null 2>&1; then
		echo "${RED}[ERROR] This script only supports Debian-based systems (apt-get required).${NC}" >&2
		exit 1
	fi
	for pkg in "${packages[@]}"; do
		if ! dpkg -s "$pkg" >/dev/null 2>&1; then
			echo "${GREEN}[INFO] Installing $pkg...${NC}"
			sudo apt-get install -y "$pkg"
		else
			echo "${YELLOW}[INFO] $pkg already installed.${NC}"
		fi
	done
}


echo "${GREEN}[INFO] Ensuring required base packages are installed...${NC}"
install_packages "${REQUIRED_PACKAGES[@]}"

# Section 3: Install project dependencies
# This step installs 1Password CLI, git, python3, pip, and ansible if not present.
PROJECT_PACKAGES=(git python3 python3-pip ansible)

echo "${GREEN}[INFO] Ensuring project dependencies are installed...${NC}"
install_packages "${PROJECT_PACKAGES[@]}"

# Install roles from requirements.yml if present
if [[ -f "requirements.yml" ]]; then
	echo "${GREEN}[INFO] Installing Ansible roles from requirements.yml...${NC}"
	ansible-galaxy install -r requirements.yml
else
	echo "${YELLOW}[INFO] No requirements.yml file found. Skipping Ansible roles installation.${NC}"
fi

# Install 1Password CLI (op) if not present
if ! command -v op >/dev/null 2>&1; then
	echo "${GREEN}[INFO] Installing 1Password CLI...${NC}"
	# Add 1Password apt repo if not already present
	if ! grep -q "downloads.1password.com/linux/debian" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
		curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" | sudo tee /etc/apt/sources.list.d/1password.list
		sudo apt-get update -y
	fi
	sudo apt-get install -y 1password-cli
else
	echo "${YELLOW}[INFO] 1Password CLI already installed.${NC}"
fi

# Section 4: Authenticate 1Password CLI with Service Account
# This step authenticates the CLI using the OP_SERVICE_ACCOUNT_TOKEN environment variable.
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
	echo "${YELLOW}[WARN] OP_SERVICE_ACCOUNT_TOKEN environment variable is not set.${NC}"
	echo "Please enter your 1Password service account token:"
	read -s OP_SERVICE_ACCOUNT_TOKEN
	export OP_SERVICE_ACCOUNT_TOKEN
fi
echo "${GREEN}[INFO] Authenticating 1Password CLI with service account...${NC}"
# Test authentication by running a simple op command
if ! op vault list --format=json >/dev/null 2>&1; then
	echo "${RED}[ERROR] Failed to authenticate with 1Password service account. Please check your token.${NC}"
	exit 1
fi
echo "${GREEN}[INFO] 1Password CLI authenticated with service account.${NC}"

# Section 5: Fetch secrets from 1Password and configure git
# This step retrieves secrets and configures git if not already set.
echo "${GREEN}[INFO] Fetching secrets from 1Password...${NC}"
GIT_USER=$(op item get --vault "homelab" "homelab-git-user" --field username 2>/dev/null || true)
GIT_EMAIL=$(op item get --vault "homelab" "homelab-git-user" --field email 2>/dev/null || true)

if [[ -n "$GIT_USER" && -n "$GIT_EMAIL" ]]; then
	echo "${GREEN}[INFO] Configuring git user/email...${NC}"
	CURRENT_GIT_USER=$(git config --global user.name || true)
	CURRENT_GIT_EMAIL=$(git config --global user.email || true)
	if [[ "$CURRENT_GIT_USER" != "$GIT_USER" ]]; then
		git config --global user.name "$GIT_USER"
		echo "${GREEN}[INFO] Set git user.name to $GIT_USER${NC}"
	else
		echo "${YELLOW}[INFO] git user.name already set.${NC}"
	fi
	if [[ "$CURRENT_GIT_EMAIL" != "$GIT_EMAIL" ]]; then
		git config --global user.email "$GIT_EMAIL"
		echo "${GREEN}[INFO] Set git user.email to $GIT_EMAIL${NC}"
	else
		echo "${YELLOW}[INFO] git user.email already set.${NC}"
	fi
else
	echo "${RED}[WARN] Could not fetch git credentials from 1Password. Please check vault item 'homelab-git-user'.${NC}"
fi



# Section 6: Add SSH keys from 1Password or configure ssh-agent
# This step detects if a desktop environment is present and configures SSH accordingly.
echo "${GREEN}[INFO] Detecting desktop environment for SSH agent setup...${NC}"
VAULT_NAME="homelab"
SSH_ITEM_NAME="markdarwin"
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
SSH_KEY_PATH="$USER_HOME/.ssh/id_${SSH_ITEM_NAME}"
SSH_PUB_KEY_PATH="$USER_HOME/.ssh/id_${SSH_ITEM_NAME}.pub"
mkdir -p "$USER_HOME/.ssh"  # Ensure .ssh directory exists

# Function to check for desktop environment
has_desktop_env() {
	if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] || [[ -n "${DESKTOP_SESSION:-}" ]] || pgrep -x Xorg >/dev/null 2>&1 || pgrep -x Wayland >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

if has_desktop_env; then
	echo "${GREEN}[INFO] Desktop environment detected. Installing and configuring 1Password Desktop app for SSH agent.${NC}"
	# Install 1Password Desktop app if not present
	if ! command -v 1password >/dev/null 2>&1; then
		echo "${GREEN}[INFO] Installing 1Password Desktop app...${NC}"
		# Only add keyring and repo if not already present
		if ! grep -q "downloads.1password.com/linux/debian" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
			curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" | sudo tee /etc/apt/sources.list.d/1password-app.list
			sudo apt-get update -y
		fi
		sudo apt-get install -y 1password
	else
		echo "${YELLOW}[INFO] 1Password Desktop app already installed.${NC}"
	fi
	echo "${GREEN}[INFO] Please ensure you are signed in to the 1Password Desktop app and have enabled 'Integrate with SSH agent' in its settings.${NC}"
	# Save public key for convenience
	SSH_PUBLIC_KEY=$(op item get --vault "$VAULT_NAME" "$SSH_ITEM_NAME" --field "public key" --reveal 2>/dev/null)
	if [[ -n "$SSH_PUBLIC_KEY" ]]; then
		echo "$SSH_PUBLIC_KEY" | sed 's/^"//;s/"$//' | awk 'NF' > "$SSH_PUB_KEY_PATH"
		chmod 644 "$SSH_PUB_KEY_PATH"
		echo "${GREEN}[INFO] SSH public key saved to $SSH_PUB_KEY_PATH.${NC}"
	else
		echo "${RED}[WARN] Could not fetch SSH public key from 1Password.${NC}"
	fi
else
	echo "${YELLOW}[INFO] No desktop environment detected. Using built-in ssh-agent.${NC}"
	SSH_PRIVATE_KEY=$(op item get --vault "$VAULT_NAME" "$SSH_ITEM_NAME" --field "private key" --reveal 2>/dev/null)
	if [[ -z "$SSH_PRIVATE_KEY" ]]; then
		echo "${RED}[ERROR] Could not fetch SSH private key from 1Password. Please check vault item '$SSH_ITEM_NAME'.${NC}"
		exit 1
	fi
	# Save private key
	echo "$SSH_PRIVATE_KEY" | sed 's/^"//;s/"$//' | awk 'NF' > "$SSH_KEY_PATH"
	chmod 600 "$SSH_KEY_PATH"
	echo "${GREEN}[INFO] SSH private key saved to $SSH_KEY_PATH.${NC}"
	# Save public key
	SSH_PUBLIC_KEY=$(op item get --vault "$VAULT_NAME" "$SSH_ITEM_NAME" --field "public key" --reveal 2>/dev/null)
	if [[ -n "$SSH_PUBLIC_KEY" ]]; then
		echo "$SSH_PUBLIC_KEY" | sed 's/^"//;s/"$//' | awk 'NF' > "$SSH_PUB_KEY_PATH"
		chmod 644 "$SSH_PUB_KEY_PATH"
		echo "${GREEN}[INFO] SSH public key saved to $SSH_PUB_KEY_PATH.${NC}"
	else
		echo "${RED}[WARN] Could not fetch SSH public key from 1Password.${NC}"
	fi
	# Start ssh-agent and add key
	eval "$(ssh-agent -s)"
	ssh-add "$SSH_KEY_PATH"
	echo "${GREEN}[INFO] SSH key added to built-in ssh-agent.${NC}"
fi




# Section 7: Update 1Password agent.toml with SSH key information
# This step ensures the agent.toml file includes the correct key reference for 1Password SSH agent.
AGENT_TOML_PATH="$USER_HOME/1Password/ssh/agent.toml"
echo "${GREEN}[INFO] Updating $AGENT_TOML_PATH with SSH key reference...${NC}"

mkdir -p "$(dirname "$AGENT_TOML_PATH")"

if grep -q "item = \"$SSH_ITEM_NAME\"" "$AGENT_TOML_PATH" 2>/dev/null; then
	echo "${GREEN}[INFO] agent.toml already contains reference to $SSH_ITEM_NAME.${NC}"
else
	cat <<EOF >> "$AGENT_TOML_PATH"
[[ssh-keys]]
item = "$SSH_ITEM_NAME"
vault = "$VAULT_NAME"
EOF
	echo "${GREEN}[INFO] Added SSH key reference to agent.toml.${NC}"
fi


# Section 8: Create ~/.ansible.sh with secrets from 1Password
# This step fetches Ansible-related secrets from 1Password and writes them to ~/.ansible.sh for use by Ansible.
ANSIBLE_SH_PATH="$USER_HOME/ansible.sh"
echo "${GREEN}[INFO] Creating $ANSIBLE_SH_PATH with secrets from 1Password...${NC}"

# Fetch secrets from 1Password vault (example: ansible-vault password, user credentials)
VAULT_PASSWORD=$(op item get --vault "$VAULT_NAME" "ansible-vault-password" --field password --reveal 2>/dev/null || true)

# Save vault password to ~/.vault_pass.txt
VAULT_PASS_PATH="$USER_HOME/.ansible/.vault_pass.txt"
mkdir -p "$(dirname "$VAULT_PASS_PATH")"

echo "$VAULT_PASSWORD" > "$VAULT_PASS_PATH"
chmod 600 "$VAULT_PASS_PATH"
chown "$SUDO_USER":"$SUDO_USER" "$VAULT_PASS_PATH"
echo "${GREEN}[INFO] Vault password saved to $VAULT_PASS_PATH and permissioned to 600.${NC}"

LOCAL_USER=$(op item get --vault "$VAULT_NAME" "homelab-local-user" --field username 2>/dev/null || true)
LOCAL_PASS=$(op item get --vault "$VAULT_NAME" "homelab-local-user" --field password 2>/dev/null || true)

# Get the hostname so we can set it in the ansible script
HOST_ID="$(hostname -f)"


echo "add github ssh info"
set +e  # Disable exit on error temporarily
# Run the ssh command as the original user to avoid permission issues
sudo -u "${SUDO_USER:-$USER}" ssh -T git@github.com
set -e  # Re-enable exit on error

echo "${GREEN}[INFO] Installing dotfiles ansible galaxy roles...${NC}"
ansible-galaxy role install geerlingguy.dotfiles


cat > "$ANSIBLE_SH_PATH" <<EOF
#!/usr/bin/env bash
# This file is auto-generated by init.sh. Do not edit manually

# Run ansible-pull with the vault password file and host_id as extra var
ansible-pull -U git@github.com:markdarwin/ansible.git -K --vault-password-file ~/.ansible/.vault_pass.txt
EOF

echo "run: ansible-pull -U git@github.com:markdarwin/ansible.git -K --vault-password-file ~/.ansible/.vault_pass.txt"

chown "$SUDO_USER":"$SUDO_USER" "$ANSIBLE_SH_PATH"
chmod 600 "$ANSIBLE_SH_PATH"
chmod +x "$ANSIBLE_SH_PATH"
echo "${GREEN}[INFO] $ANSIBLE_SH_PATH created, permissioned to 600, and made executable.${NC}"

# Section 9: Install CrowdStrike Falcon Sensor
# This step installs the Falcon Sensor from the provided .deb file and registers it using the invite code from 1Password.
FALCON_SENSOR_DEB="falcon-sensor.deb"
FALCON_SENSOR_PATH="$(dirname "$0")/$FALCON_SENSOR_DEB"

if [[ ! -f "$FALCON_SENSOR_PATH" ]]; then
    echo "${RED}[ERROR] Falcon Sensor .deb file not found at $FALCON_SENSOR_PATH.${NC}"
    exit 1
fi

echo "${GREEN}[INFO] Installing CrowdStrike Falcon Sensor from $FALCON_SENSOR_PATH...${NC}"
sudo apt-get install -y "$FALCON_SENSOR_PATH"

echo "${GREEN}[INFO] Fetching Falcon Sensor invite code from 1Password...${NC}"
FALCON_INVITE_CODE=$(op item get --vault "homelab" "falcon-sensor-invite-code" --field password --reveal 2>/dev/null || true)

if [[ -z "$FALCON_INVITE_CODE" ]]; then
    echo "${RED}[ERROR] Could not fetch Falcon Sensor invite code from 1Password. Please check vault item 'falcon-sensor-invite-code'.${NC}"
    exit 1
fi

echo "${GREEN}[INFO] Registering Falcon Sensor with invite code...${NC}"
sudo /opt/CrowdStrike/falconctl -s --cid="$FALCON_INVITE_CODE"

echo "${GREEN}[INFO] CrowdStrike Falcon Sensor installed and registered successfully.${NC}"

