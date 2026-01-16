#!/usr/bin/env bash
# Bootstrap wrapper - enables one-line curl | bash execution
# Usage: curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/bootstrap.sh | bash

set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}[INFO] This script needs sudo privileges. Re-running with sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

# Download the main init script
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo -e "${GREEN}[INFO] Downloading init.sh...${NC}"
curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/init.sh -o "$TEMP_DIR/init.sh"

# Download Falcon Sensor if available (optional)
if curl -fsSL https://raw.githubusercontent.com/markdarwin/ansible/main/falcon-sensor.deb -o "$TEMP_DIR/falcon-sensor.deb" 2>/dev/null; then
    echo -e "${GREEN}[INFO] Downloaded falcon-sensor.deb${NC}"
fi

# Make executable and run
chmod +x "$TEMP_DIR/init.sh"

echo -e "${GREEN}[INFO] Starting initialization...${NC}"
cd "$TEMP_DIR"
./init.sh

echo -e "${GREEN}[SUCCESS] Bootstrap completed!${NC}"