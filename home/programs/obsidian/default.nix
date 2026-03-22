{ pkgs, config, ... }:

{
  home.packages = with pkgs; [
    obsidian
  ];

  # Vault structure creation (PARA/Zettelkasten hybrid)
  # We use home.activation to ensure directories and basic config exist.
  home.activation = {
    createObsidianVault = config.lib.dag.entryAfter ["writeBoundary"] ''
      VAULT_DIR="$HOME/vault"
      mkdir -p "$VAULT_DIR"/{00_Inbox,10_Projects,20_Area,30_Library,40_Creative,50_Archive,attachments}
      
      # Create initial .obsidian directory
      mkdir -p "$VAULT_DIR/.obsidian"
      
      # Basic App Settings (Vim Mode, Spellcheck, etc.)
      cat <<EOF > "$VAULT_DIR/.obsidian/app.json"
{
  "vimMode": true,
  "showLineNumber": true,
  "readableLineLength": true,
  "spellcheck": true,
  "alwaysUpdateLinks": true,
  "attachmentFolderPath": "attachments",
  "useMarkdownLinks": true,
  "newFileLocation": "folder",
  "newFileFolderPath": "00_Inbox"
}
EOF

      # Appearance Settings
      cat <<EOF > "$VAULT_DIR/.obsidian/appearance.json"
{
  "accentColor": "#d33637",
  "theme": "obsidian",
  "baseFontSize": 16,
  "textFontFamily": "JetBrainsMono Nerd Font",
  "interfaceFontFamily": "JetBrainsMono Nerd Font",
  "monospaceFontFamily": "JetBrainsMono Nerd Font"
}
EOF

      # Hotkeys (Example: Vim-like)
      cat <<EOF > "$VAULT_DIR/.obsidian/hotkeys.json"
{
  "obsidian-vimrc-plugin:toggle-vim-mode": [
    {
      "modifiers": ["Mod", "Shift"],
      "key": "V"
    }
  ]
}
EOF

      # Initial README for the vault
      if [ ! -f "$VAULT_DIR/README.md" ]; then
        cat <<EOF > "$VAULT_DIR/README.md"
# 🧛‍♂️ Infernal Knowledge Base

This vault is managed as part of the NixOS "Infernal Mecha" configuration.

## 🛠️ Required Plugins (Install via Community Plugins)
- **Dataview**: Dynamic database queries.
- **Templater**: Advanced automation and metadata.
- **Obsidian Git**: Version control (syncs with the \`obsidian\` alias).
- **Excalidraw**: Architectural sketching.
- **Admonition**: Styled callout blocks.
- **Smart Connections**: AI-powered local connections.

## 🚀 Workflow
- Use \`SUPER + Enter\` to launch Kitty and type \`obsidian\` to sync and open.
- **PARA Structure**:
  - \`00_Inbox\`: Quick captures.
  - \`10_Projects\`: Active work.
  - \`20_Area\`: Responsibility zones.
  - \`30_Library\`: Reference material.
  - \`40_Creative\`: Personal expressions.
  - \`50_Archive\`: Completed history.

*Forged in blood and code.*
EOF
      fi
    '';
  };
}
