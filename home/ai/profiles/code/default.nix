# Профиль «код»: обычный ~/.claude и обычный `claude`. Сюда же целятся ECC
# (скиллы, агенты, команды, правила, хуки), nix-toolkit, ask-models и
# сторонние скиллы из ../../skills; MCP-серверы добавляет ../../mcp.
#
# CLAUDE.md собирается из частей по флейвору ECC (../../ecc, ai.ecc.flavour):
#   br      ядро форка (badrabbit/core/CLAUDE.md) + ./CLAUDE.md (Лилит, железо, Nix-доктрина);
#   legacy  ./CLAUDE.md + ./ecc-legacy.md (ECC-петля и @~/.claude/ecc-guide.md).
{ config, pkgs, lib, ... }:

let
  core = config.ai.ecc.core;
  parts = if core != null then [ core ./CLAUDE.md ] else [ ./CLAUDE.md ./ecc-legacy.md ];
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
