# Профиль «код»: обычный ~/.claude и обычный `claude`. Сюда же целятся warren
# (скиллы, агенты, команды, workflows, правила, хуки), nix-toolkit, ask-models и
# сторонние скиллы из ../../skills; MCP-серверы добавляет ../../mcp.
#
# CLAUDE.md = ядро warren (ai.warren.core, ../../warren) + ./CLAUDE.md (Лилит, железо, Nix-доктрина).
{ config, pkgs, lib, ... }:

let
  parts = [ config.ai.warren.core ./CLAUDE.md ];
  instructions = pkgs.runCommand "claude-code-CLAUDE.md" { } ''
    for f in ${lib.escapeShellArgs parts}; do cat "$f"; printf '\n'; done > "$out"
  '';
in
{
  ai.profiles.code = {
    dir = ".claude";
    wrapper = null;
    inherit instructions;
  };
}
