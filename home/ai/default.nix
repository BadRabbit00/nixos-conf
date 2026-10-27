# Агенты для кодинга: claude-code, codex, antigravity (agy) и всё, что они
# подбирают из домашнего каталога. Один корень, одна раскладка:
#
#   mcp/         MCP-серверы, вливаются в мутабельные конфиги агентов
#   skills/      сторонние SKILL.md, запинены по rev/hash, скрипты через Nix-обёртки
#   ecc/         Everything Claude Code: скиллы, агенты, команды, правила, хуки
#   nix-toolkit/ свои Nix-агенты, команды и справочники
#   ask-models/  обёртки ask-*/write-* для чужих моделей и их команды
#   profiles.nix профили Claude Code (CLAUDE_CONFIG_DIR): каталог, обёртка, CLAUDE.md, скиллы, MCP
#   profiles/    code (обычный ~/.claude, Лилит + ECC) и montage (~/.claude-montage, claude-montage)
#                security — agy-sec: Antigravity с отдельным $HOME (~/.agy-security), ИБ-сканеры + ECC
#   gemini/      файлы gemini-cli (~/.config/gemini)
#   lib.nix      общий инвентарь: корни агентов, fan-out файлов, слияние JSON/TOML
#
# Claude Code держит user-конфиг в $HOME/.claude (не XDG), codex — в $CODEX_HOME
# (~/.codex), agy — в ~/.gemini/config; пути собраны в lib.nix и больше нигде.
{ pkgs, ... }:

{
  imports = [
    ./profiles.nix
    ./profiles/code/default.nix
    ./profiles/montage/default.nix
    ./profiles/security/default.nix
    ./mcp/default.nix
    ./skills/default.nix
    ./ecc/default.nix
    ./nix-toolkit/default.nix
    ./ask-models/default.nix
  ];

  home.packages = with pkgs; [
    claude-code
    codex           # OpenAI Codex CLI
    antigravity-cli # agy, Gemini
    opencode        # провайдер-агностичный агент; ИБ-профиль на локальной модели — opencode-sec
  ];

  # gemini-cli. Секреты (CONTEXT7_API_KEY, GITHUB_TOKEN) приходят из sops-nix,
  # в этих файлах их нет и быть не должно.
  xdg.configFile."gemini/settings.json".source = ./gemini/settings.json;
  xdg.configFile."gemini/trustedFolders.json".source = ./gemini/trustedFolders.json;
  xdg.configFile."gemini/state.json".source = ./gemini/state.json;
  xdg.configFile."gemini/GEMINI.md".source = ./gemini/GEMINI.md;
}
