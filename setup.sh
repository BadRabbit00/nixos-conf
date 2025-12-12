#!/usr/bin/env bash
# Quick setup script for NixOS configuration

set -e

# Function to escape special characters for sed
escape_sed() {
    echo "$1" | sed 's/[&/\]/\\&/g'
}

echo "🚀 NixOS Configuration Setup"
echo "=============================="
echo ""

# Check if running on NixOS
if [ ! -f /etc/NIXOS ]; then
    echo "⚠️  Warning: This doesn't appear to be a NixOS system!"
    echo "This configuration is designed for NixOS."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📝 Step 1: Generate hardware configuration"
read -p "Generate hardware-configuration.nix? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
    echo "✅ hardware-configuration.nix generated"
fi

echo ""
echo "📝 Step 2: Set hostname"
read -p "Enter your hostname (or press Enter to skip): " hostname
if [[ -n "$hostname" ]]; then
    hostname_escaped=$(escape_sed "$hostname")
    sed -i "s/networking.hostName = \"nixos\"/networking.hostName = \"$hostname_escaped\"/" configuration.nix
    sed -i "s/nixosConfigurations.default/nixosConfigurations.$hostname_escaped/" flake.nix
    sed -i "s/flake .\#default/flake .#$hostname_escaped/" home.nix
    echo "✅ Hostname set to: $hostname"
fi

echo ""
echo "📝 Step 3: Set username"
read -p "Enter your username (or press Enter to skip): " username
if [[ -n "$username" ]]; then
    username_escaped=$(escape_sed "$username")
    sed -i "s/users.users.user/users.users.$username_escaped/" configuration.nix
    sed -i "s/home.username = \"user\"/home.username = \"$username_escaped\"/" home.nix
    sed -i "s|home.homeDirectory = \"/home/user\"|home.homeDirectory = \"/home/$username_escaped\"|" home.nix
    sed -i "s/home-manager.users.user/home-manager.users.$username_escaped/" flake.nix
    echo "✅ Username set to: $username"
fi

echo ""
echo "📝 Step 4: Git configuration"
read -p "Enter your git name (or press Enter to skip): " gitname
if [[ -n "$gitname" ]]; then
    gitname_escaped=$(escape_sed "$gitname")
    sed -i "s/userName = \"Your Name\"/userName = \"$gitname_escaped\"/" home.nix
    echo "✅ Git name set"
fi

read -p "Enter your git email (or press Enter to skip): " gitemail
if [[ -n "$gitemail" ]]; then
    gitemail_escaped=$(escape_sed "$gitemail")
    sed -i "s/userEmail = \"your.email@example.com\"/userEmail = \"$gitemail_escaped\"/" home.nix
    echo "✅ Git email set"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated configuration files"
if [[ -n "$hostname" ]]; then
    echo "2. Run: sudo nixos-rebuild switch --flake .#$hostname"
else
    echo "2. Run: sudo nixos-rebuild switch --flake .#default"
fi
echo ""
echo "📚 See README.md for more information"
