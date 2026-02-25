#!/usr/bin/env bash
# Initialize the environment

# Section 0: Check for sudo privileges
if ! sudo -n true 2>/dev/null; then
	echo -e "[ERROR] This script requires sudo privileges. Run the following commands:
  1. su -
  2. usermod -aG sudo $USER
  3. reboot
Then re-run this script." >&2
	exit 1
fi

set -euo pipefail

# Colour codes for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"


# Section 1: Update package lists (Debian or Fedora)
echo -e "${GREEN}[INFO] Detecting OS and updating package lists...${NC}"
if command -v apt-get >/dev/null 2>&1; then
	OS_FAMILY="debian"
	sudo apt-get update -y
elif command -v dnf >/dev/null 2>&1; then
	OS_FAMILY="fedora"
	sudo dnf makecache -y
elif command -v yum >/dev/null 2>&1; then
	OS_FAMILY="fedora"
	sudo yum makecache -y
else
	echo -e "${RED}[ERROR] This script only supports Debian or Fedora-based systems (apt-get, dnf, or yum required).${NC}" >&2
	exit 1
fi

echo -e "${GREEN}[INFO] Ensuring required base packages are installed...${NC}"
echo -e "${GREEN}[INFO] Ensuring project dependencies are installed...${NC}"

# Section 2: Install necessary base packages
if [[ "$OS_FAMILY" == "debian" ]]; then
	REQUIRED_PACKAGES=(curl sudo gnupg lsb-release)
	PROJECT_PACKAGES=(git python3 python3-pip ansible)
	install_debian_packages() {
		local packages=("${@}")
		for pkg in "${packages[@]}"; do
			if ! dpkg -s "$pkg" >/dev/null 2>&1; then
				echo -e "${GREEN}[INFO] Installing $pkg...${NC}"
				sudo apt-get install -y "$pkg"
			else
				echo -e "${YELLOW}[INFO] $pkg already installed.${NC}"
			fi
		done
	}
	echo -e "${GREEN}[INFO] Ensuring required base packages are installed...${NC}"
	install_debian_packages "${REQUIRED_PACKAGES[@]}"
	echo -e "${GREEN}[INFO] Ensuring project dependencies are installed...${NC}"
	install_debian_packages "${PROJECT_PACKAGES[@]}"
elif [[ "$OS_FAMILY" == "fedora" ]]; then
	REQUIRED_PACKAGES=(curl sudo gnupg2 redhat-lsb-core)
	PROJECT_PACKAGES=(git python3 python3-pip ansible)
	install_fedora_packages() {
		local packages=("${@}")
		for pkg in "${packages[@]}"; do
			if ! rpm -q "$pkg" >/dev/null 2>&1; then
				echo -e "${GREEN}[INFO] Installing $pkg...${NC}"
				sudo dnf install -y "$pkg" || sudo yum install -y "$pkg"
			else
				echo -e "${YELLOW}[INFO] $pkg already installed.${NC}"
			fi
		done
	}
	echo -e "${GREEN}[INFO] Ensuring required base packages are installed...${NC}"
	install_fedora_packages "${REQUIRED_PACKAGES[@]}"
	echo -e "${GREEN}[INFO] Ensuring project dependencies are installed...${NC}"
	install_fedora_packages "${PROJECT_PACKAGES[@]}"
fi

# Install roles from requirements.yml if present
USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/requirements.yml -o /tmp/requirements.yml
if [[ -f "/tmp/requirements.yml" ]]; then
	echo -e "${GREEN}[INFO] Installing Ansible roles from requirements.yml...${NC}"
	ansible-galaxy install -r /tmp/requirements.yml --roles-path "$USER_HOME/.ansible/roles"
else
	echo -e "${YELLOW}[INFO] No requirements.yml file found. Skipping Ansible roles installation.${NC}"
fi


# Install 1Password CLI (op) if not present
if ! command -v op >/dev/null 2>&1; then
	echo -e "${GREEN}[INFO] Installing 1Password CLI...${NC}"
	if [[ "$OS_FAMILY" == "debian" ]]; then
		if ! grep -q "downloads.1password.com/linux/debian" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
			curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main" | sudo tee /etc/apt/sources.list.d/1password.list
			sudo apt-get update -y
		fi
		sudo apt-get install -y 1password-cli
	elif [[ "$OS_FAMILY" == "fedora" ]]; then
		sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
		sudo tee /etc/yum.repos.d/1password.repo > /dev/null <<EOF
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/
enabled=1
gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
		sudo dnf makecache -y || sudo yum makecache -y
		sudo dnf install -y 1password-cli || sudo yum install -y 1password-cli
	fi
else
	echo -e "${YELLOW}[INFO] 1Password CLI already installed.${NC}"
fi

# Section 4: Authenticate 1Password CLI with Service Account
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
	echo -e "${YELLOW}[WARN] OP_SERVICE_ACCOUNT_TOKEN environment variable is not set.${NC}"
	echo -e "Please enter your 1Password service account token:"
	read -rs OP_SERVICE_ACCOUNT_TOKEN
	export OP_SERVICE_ACCOUNT_TOKEN
fi

echo -e "${GREEN}[INFO] Authenticating 1Password CLI with service account...${NC}"
if ! op vault list --format=json >/dev/null 2>&1; then
	echo -e "${RED}[ERROR] Failed to authenticate with 1Password service account. Please check your token.${NC}"
	exit 1
fi
echo -e "${GREEN}[INFO] 1Password CLI authenticated with service account.${NC}"

# Section 5: Fetch secrets from 1Password and configure git
echo -e "${GREEN}[INFO] Fetching secrets from 1Password...${NC}"
GIT_USER=$(op item get --vault "homelab" "homelab-git-user" --field username 2>/dev/null || true)
GIT_EMAIL=$(op item get --vault "homelab" "homelab-git-user" --field email 2>/dev/null || true)

if [[ -n "$GIT_USER" && -n "$GIT_EMAIL" ]]; then
	echo -e "${GREEN}[INFO] Configuring git user/email...${NC}"
	CURRENT_GIT_USER=$(git config --global user.name 2>/dev/null || true)
	CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
	if [[ "$CURRENT_GIT_USER" != "$GIT_USER" ]]; then
		sudo -u "${SUDO_USER:-$USER}" git config --global user.name "$GIT_USER"
		echo -e "${GREEN}[INFO] Set git user.name to $GIT_USER${NC}"
	else
		echo -e "${YELLOW}[INFO] git user.name already set.${NC}"
	fi
	if [[ "$CURRENT_GIT_EMAIL" != "$GIT_EMAIL" ]]; then
		sudo -u "${SUDO_USER:-$USER}" git config --global user.email "$GIT_EMAIL"
		echo -e "${GREEN}[INFO] Set git user.email to $GIT_EMAIL${NC}"
	else
		echo -e "${YELLOW}[INFO] git user.email already set.${NC}"
	fi
else
	echo -e "${RED}[WARN] Could not fetch git credentials from 1Password. Please check vault item 'homelab-git-user'.${NC}"
fi

# Section 6: Add SSH keys from 1Password or configure ssh-agent
echo -e "${GREEN}[INFO] Detecting desktop environment for SSH agent setup...${NC}"
VAULT_NAME="homelab"
SSH_ITEM_NAME="markdarwin"
SSH_KEY_PATH="$USER_HOME/.ssh/id_${SSH_ITEM_NAME}"
SSH_PUB_KEY_PATH="$USER_HOME/.ssh/id_${SSH_ITEM_NAME}.pub"
mkdir -p "$USER_HOME/.ssh"

# Function to check for desktop environment
has_desktop_env() {
	if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] || [[ -n "${DESKTOP_SESSION:-}" ]] || pgrep -x Xorg >/dev/null 2>&1 || pgrep -x Wayland >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

# Function to wait for 1Password SSH agent to be ready
wait_for_1password_ssh_agent() {
	local max_wait=30
	local wait_time=0
	local socket_path="$USER_HOME/.1password/agent.sock"
	
	echo -e "${GREEN}[INFO] Waiting for 1Password SSH agent to be ready...${NC}"
	
	while [[ $wait_time -lt $max_wait ]]; do
		if [[ -S "$socket_path" ]] && SSH_AUTH_SOCK="$socket_path" ssh-add -l >/dev/null 2>&1; then
			echo -e "${GREEN}[INFO] 1Password SSH agent is ready.${NC}"
			return 0
		fi
		sleep 1
		((wait_time++))
		if [[ $((wait_time % 5)) -eq 0 ]]; then
			echo -e "${YELLOW}[INFO] Still waiting for 1Password SSH agent... ($wait_time/${max_wait}s)${NC}"
		fi
	done
	
	return 1
}

USE_1PASSWORD_AGENT=false

if has_desktop_env; then
	echo -e "${GREEN}[INFO] Desktop environment detected. Installing and configuring 1Password Desktop app for SSH agent.${NC}"
	
		if ! command -v 1password >/dev/null 2>&1; then
			echo -e "${GREEN}[INFO] Installing 1Password Desktop app...${NC}"
			if [[ "$OS_FAMILY" == "debian" ]]; then
				if ! grep -q "downloads.1password.com/linux/debian" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
					curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
					echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(lsb_release -cs) stable main" | sudo tee /etc/apt/sources.list.d/1password-app.list
					sudo apt-get update -y
				fi
				sudo apt-get install -y 1password
			elif [[ "$OS_FAMILY" == "fedora" ]]; then
				sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc
				sudo tee /etc/yum.repos.d/1password.repo > /dev/null <<EOF
	[1password]
	name=1Password Stable Channel
	baseurl=https://downloads.1password.com/linux/rpm/stable/
	enabled=1
	gpgcheck=1
	gpgkey=https://downloads.1password.com/linux/keys/1password.asc
	EOF
				sudo dnf makecache -y || sudo yum makecache -y
				sudo dnf install -y 1password || sudo yum install -y 1password
			fi
			echo -e "${YELLOW}[IMPORTANT] Please follow these steps:${NC}"
			echo -e "${YELLOW}  1. Launch 1Password Desktop app${NC}"
			echo -e "${YELLOW}  2. Sign in to your account${NC}"
			echo -e "${YELLOW}  3. Go to Settings > Developer${NC}"
			echo -e "${YELLOW}  4. Enable 'Use the SSH agent'${NC}"
			echo -e "${YELLOW}  5. Enable '1Password CLI'${NC}"
			read -p "Press Enter when you've completed these steps..."
		else
			echo -e "${YELLOW}[INFO] 1Password Desktop app already installed.${NC}"
		fi
	
	# Check if 1Password SSH agent is available and working
	if wait_for_1password_ssh_agent; then
		USE_1PASSWORD_AGENT=true
		# Configure SSH to use 1Password agent
		SSH_CONFIG="$USER_HOME/.ssh/config"
		if ! grep -q "IdentityAgent.*1password/agent.sock" "$SSH_CONFIG" 2>/dev/null; then
			echo -e "${GREEN}[INFO] Configuring SSH to use 1Password agent...${NC}"
			cat >> "$SSH_CONFIG" <<EOF

# 1Password SSH Agent
Host *
    IdentityAgent ~/.1password/agent.sock
EOF
			chmod 600 "$SSH_CONFIG"
		fi
	else
		echo -e "${YELLOW}[WARN] 1Password SSH agent not ready. Falling back to standard ssh-agent.${NC}"
		USE_1PASSWORD_AGENT=false
	fi
	
	# Save public key for reference
	SSH_PUBLIC_KEY=$(op item get --vault "$VAULT_NAME" "$SSH_ITEM_NAME" --field "public key" --reveal 2>/dev/null || true)
	if [[ -n "$SSH_PUBLIC_KEY" ]]; then
		echo "$SSH_PUBLIC_KEY" | sed 's/^"//;s/"$//' | awk 'NF' > "$SSH_PUB_KEY_PATH"
		chmod 644 "$SSH_PUB_KEY_PATH"
		echo -e "${GREEN}[INFO] SSH public key saved to $SSH_PUB_KEY_PATH.${NC}"
	fi
fi

# Fallback to standard ssh-agent if 1Password agent not used
if [[ "$USE_1PASSWORD_AGENT" == "false" ]]; then
	echo -e "${YELLOW}[INFO] Using standard ssh-agent.${NC}"
	
	SSH_PRIVATE_KEY=$(op item get --vault "$VAULT_NAME" "$SSH_ITEM_NAME" --field "private key" --reveal 2>/dev/null || true)
	if [[ -z "$SSH_PRIVATE_KEY" ]]; then
		echo -e "${RED}[ERROR] Could not fetch SSH private key from 1Password. Please check vault item '$SSH_ITEM_NAME'.${NC}"
		exit 1
	fi
	
	# Save private key
	echo "$SSH_PRIVATE_KEY" | sed 's/^"//;s/"$//' | awk 'NF' > "$SSH_KEY_PATH"
	chmod 600 "$SSH_KEY_PATH"
	echo -e "${GREEN}[INFO] SSH private key saved to $SSH_KEY_PATH.${NC}"
	
	# Save public key
	SSH_PUBLIC_KEY=$(op item get --vault "$VAULT_NAME" "$SSH_ITEM_NAME" --field "public key" --reveal 2>/dev/null || true)
	if [[ -n "$SSH_PUBLIC_KEY" ]]; then
		echo "$SSH_PUBLIC_KEY" | sed 's/^"//;s/"$//' | awk 'NF' > "$SSH_PUB_KEY_PATH"
		chmod 644 "$SSH_PUB_KEY_PATH"
		echo -e "${GREEN}[INFO] SSH public key saved to $SSH_PUB_KEY_PATH.${NC}"
	fi
	
	# Start ssh-agent and add key
	eval "$(ssh-agent -s)"
	ssh-add "$SSH_KEY_PATH" 2>/dev/null || true
	echo -e "${GREEN}[INFO] SSH key added to ssh-agent.${NC}"
fi

# Ensure correct ownership
chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$USER_HOME/.ssh"

# Section 7: Test GitHub SSH connection
echo -e "${GREEN}[INFO] Testing GitHub SSH connection...${NC}"
if [[ "$USE_1PASSWORD_AGENT" == "true" ]]; then
	export SSH_AUTH_SOCK="$USER_HOME/.1password/agent.sock"
fi

# Test connection (this will always "fail" but we just want to verify the key works)
set +e
sudo -u "${SUDO_USER:-$USER}" SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"
SSH_TEST_RESULT=$?
set -e

if [[ $SSH_TEST_RESULT -eq 0 ]]; then
	echo -e "${GREEN}[INFO] GitHub SSH authentication successful.${NC}"
else
	echo -e "${YELLOW}[WARN] GitHub SSH test inconclusive, but continuing...${NC}"
fi

# Section 8: Update 1Password agent.toml with SSH key information
if [[ "$USE_1PASSWORD_AGENT" == "true" ]]; then
	AGENT_TOML_PATH="$USER_HOME/.config/1Password/ssh/agent.toml"
	echo -e "${GREEN}[INFO] Updating $AGENT_TOML_PATH with SSH key reference...${NC}"
	
	mkdir -p "$(dirname "$AGENT_TOML_PATH")"
	
	if ! grep -q "item = \"$SSH_ITEM_NAME\"" "$AGENT_TOML_PATH" 2>/dev/null; then
		cat <<EOF >> "$AGENT_TOML_PATH"

[[ssh-keys]]
item = "$SSH_ITEM_NAME"
vault = "$VAULT_NAME"
EOF
		echo -e "${GREEN}[INFO] Added SSH key reference to agent.toml.${NC}"
	else
		echo -e "${GREEN}[INFO] agent.toml already contains reference to $SSH_ITEM_NAME.${NC}"
	fi
	
	chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$AGENT_TOML_PATH"
fi

# Section 9: Create ~/.ansible.sh with secrets from 1Password
ANSIBLE_SH_PATH="$USER_HOME/ansible.sh"
echo -e "${GREEN}[INFO] Creating $ANSIBLE_SH_PATH with secrets from 1Password...${NC}"

VAULT_PASSWORD=$(op item get --vault "$VAULT_NAME" "ansible-vault-password" --field password --reveal 2>/dev/null || true)

VAULT_PASS_PATH="$USER_HOME/.ansible/.vault_pass.txt"
mkdir -p "$(dirname "$VAULT_PASS_PATH")"

echo "$VAULT_PASSWORD" > "$VAULT_PASS_PATH"
chmod 600 "$VAULT_PASS_PATH"
chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$USER_HOME/.ansible"
echo -e "${GREEN}[INFO] Vault password saved to $VAULT_PASS_PATH and permissioned to 600.${NC}"

echo -e "${GREEN}[INFO] Installing ansible galaxy roles...${NC}"
ansible-galaxy role install geerlingguy.dotfiles 2>/dev/null || true

cat > "$ANSIBLE_SH_PATH" <<'EOF'
#!/usr/bin/env bash
# This file is auto-generated by init.sh. Do not edit manually

# Check 1Password is open and unlocked
if op account get >/dev/null 2>&1; then
    echo "1Password is unlocked"
else
    echo "1Password needs to be unlocked. Please unlock 1Password and try again."
    exit 1
fi

# Run ansible-pull with the vault password file
ansible-pull -U git@github.com:markdarwin/ansible.git -K --vault-password-file ~/.ansible/.vault_pass.txt
EOF

chown "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$ANSIBLE_SH_PATH"
chmod 700 "$ANSIBLE_SH_PATH"
echo -e "${GREEN}[INFO] $ANSIBLE_SH_PATH created and made executable.${NC}"


# Section 10: Install CrowdStrike Falcon Sensor (optional)
FALCON_SENSOR_DEB="falcon-sensor.deb"
FALCON_SENSOR_RPM="falcon-sensor.rpm"
FALCON_SENSOR_PATH_DEB="$(dirname "$(readlink -f "$0")")/$FALCON_SENSOR_DEB"
FALCON_SENSOR_PATH_RPM="$(dirname "$(readlink -f "$0")")/$FALCON_SENSOR_RPM"

if [[ "$OS_FAMILY" == "debian" && -f "$FALCON_SENSOR_PATH_DEB" ]]; then
	echo -e "${GREEN}[INFO] Installing CrowdStrike Falcon Sensor from $FALCON_SENSOR_PATH_DEB...${NC}"
	sudo apt-get install -y "$FALCON_SENSOR_PATH_DEB"
	FALCON_INVITE_CODE=$(op item get --vault "homelab" "falcon-sensor-invite-code" --field password --reveal 2>/dev/null || true)
	if [[ -n "$FALCON_INVITE_CODE" ]]; then
		echo -e "${GREEN}[INFO] Registering Falcon Sensor with invite code...${NC}"
		sudo /opt/CrowdStrike/falconctl -s -f --cid="$FALCON_INVITE_CODE"
		echo -e "${GREEN}[INFO] CrowdStrike Falcon Sensor installed and registered successfully.${NC}"
	else
		echo -e "${YELLOW}[WARN] Could not fetch Falcon Sensor invite code. Skipping registration.${NC}"
	fi
elif [[ "$OS_FAMILY" == "fedora" && -f "$FALCON_SENSOR_PATH_RPM" ]]; then
	echo -e "${GREEN}[INFO] Installing CrowdStrike Falcon Sensor from $FALCON_SENSOR_PATH_RPM...${NC}"
	sudo dnf install -y "$FALCON_SENSOR_PATH_RPM" || sudo yum install -y "$FALCON_SENSOR_PATH_RPM"
	FALCON_INVITE_CODE=$(op item get --vault "homelab" "falcon-sensor-invite-code" --field password --reveal 2>/dev/null || true)
	if [[ -n "$FALCON_INVITE_CODE" ]]; then
		echo -e "${GREEN}[INFO] Registering Falcon Sensor with invite code...${NC}"
		sudo /opt/CrowdStrike/falconctl -s -f --cid="$FALCON_INVITE_CODE"
		echo -e "${GREEN}[INFO] CrowdStrike Falcon Sensor installed and registered successfully.${NC}"
	else
		echo -e "${YELLOW}[WARN] Could not fetch Falcon Sensor invite code. Skipping registration.${NC}"
	fi
else
	echo -e "${YELLOW}[INFO] Falcon Sensor package not found for this OS. Skipping installation.${NC}"
fi

echo -e "${GREEN}[SUCCESS] Bootstrap completed successfully!${NC}"
echo -e "${GREEN}You can now run: $ANSIBLE_SH_PATH${NC}"