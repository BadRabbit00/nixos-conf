#!/usr/bin/env bash
# Quick setup script for NixOS configuration

set -e

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
if [ ! -z "$hostname" ]; then
    sed -i "s/networking.hostName = \"nixos\"/networking.hostName = \"$hostname\"/" configuration.nix
    sed -i "s/default = nixpkgs.lib.nixosSystem/$hostname = nixpkgs.lib.nixosSystem/" flake.nix
    echo "✅ Hostname set to: $hostname"
fi

echo ""
echo "📝 Step 3: Set username"
read -p "Enter your username (or press Enter to skip): " username
if [ ! -z "$username" ]; then
    sed -i "s/users.users.user/users.users.$username/" configuration.nix
    sed -i "s/home.username = \"user\"/home.username = \"$username\"/" home.nix
    sed -i "s|home.homeDirectory = \"/home/user\"|home.homeDirectory = \"/home/$username\"|" home.nix
    sed -i "s/home-manager.users.user/home-manager.users.$username/" flake.nix
    echo "✅ Username set to: $username"
fi

echo ""
echo "📝 Step 4: Git configuration"
read -p "Enter your git name (or press Enter to skip): " gitname
if [ ! -z "$gitname" ]; then
    sed -i "s/userName = \"Your Name\"/userName = \"$gitname\"/" home.nix
    echo "✅ Git name set"
fi

read -p "Enter your git email (or press Enter to skip): " gitemail
if [ ! -z "$gitemail" ]; then
    sed -i "s/userEmail = \"your.email@example.com\"/userEmail = \"$gitemail\"/" home.nix
    echo "✅ Git email set"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Review the generated configuration files"
echo "2. Run: sudo nixos-rebuild switch --flake .#${hostname:-default}"
echo ""
echo "📚 See README.md for more information"
