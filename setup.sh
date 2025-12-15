#!/usr/bin/env bash

# Setup Script for NixOS Configuration
# This script updates the username and hostname across the configuration files.

set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting configuration setup...${NC}"

# Default values
DEFAULT_USER="BadRabbit"
DEFAULT_HOST="badrabbitpc"

# Prompt for new values
read -p "Enter your desired username: " NEW_USER
read -p "Enter your desired hostname: " NEW_HOST

if [ -z "$NEW_USER" ] || [ -z "$NEW_HOST" ]; then
    echo "Username and hostname cannot be empty."
    exit 1
fi

echo -e "${GREEN}Updating configuration files...${NC}"

# Replace Username
# We use grep to find files containing the old username and sed to replace it
grep -rl "$DEFAULT_USER" . --exclude-dir=.git --exclude=setup.sh | xargs sed -i "s/$DEFAULT_USER/$NEW_USER/g"

# Replace Hostname
grep -rl "$DEFAULT_HOST" . --exclude-dir=.git --exclude=setup.sh | xargs sed -i "s/$DEFAULT_HOST/$NEW_HOST/g"

echo -e "${GREEN}Configuration updated successfully!${NC}"
echo "New Username: $NEW_USER"
echo "New Hostname: $NEW_HOST"
echo ""
echo "Next steps:"
echo "1. Generate your hardware configuration:"
echo "   nixos-generate-config --show-hardware-config > hosts/desktop/hardware-configuration.nix"
echo "2. Review the changes using 'git diff'"
echo "3. Install the system:"
echo "   sudo nixos-install --flake .#$NEW_HOST"
