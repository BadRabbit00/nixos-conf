# Профили Claude Code: несколько независимых «домов» для одного бинаря.
#
# Claude Code читает всё из $CLAUDE_CONFIG_DIR (по умолчанию ~/.claude):
# CLAUDE.md, skills/, agents/, commands/, settings.json с хуками и сам
# .claude.json с MCP-серверами, логином и памятью. Профиль — это такой каталог
# плюс обёртка, которая выставляет переменную. Профили не видят друг друга:
# кодинг с ECC и хуками живёт в ~/.claude, монтаж — в своём каталоге без них.
#
#   ai.profiles.<имя> = {
#     dir          каталог относительно $HOME (по умолчанию .claude-<имя>)
#     wrapper      имя бинаря-обёртки, null = без обёртки (обычный `claude`)
#     instructions путь к CLAUDE.md
#     skills       { имя = derivation; } -> <dir>/skills/<имя>
#     mcp          { имя = { type; command; … }; } -> mcpServers в .claude.json
#     files        { "относительный/путь" = { source | text }; } -> <dir>/…
#     tools        пакеты в PATH обёртки: инструменты, которые скиллы профиля
#                  зовут по имени (ffmpeg, python с либами…); без обёртки — никуда
#     env          переменные окружения обёртки (сессия может переопределить)
#   }
#
# .claude.json агент пишет сам (кэши, счётчики, логин), поэтому MCP не кладутся
# через home.file, а вливаются по ключу mcpServers activation-скриптом; чужие
# серверы, добавленные через `claude mcp add`, остаются.
{ config, lib, pkgs, ... }:

let
  ai = import ./lib.nix { inherit lib pkgs; };
  cfg = config.ai.profiles;
  inherit (lib) types mkOption;

  # Главный конфиг: ~/.claude.json для каталога по умолчанию, иначе внутри
  # $CLAUDE_CONFIG_DIR (так его кладёт сам Claude Code).
  mcpFile = p: if p.dir == ai.roots.claude then ''"$HOME/.claude.json"'' else ''"$HOME/${p.dir}/.claude.json"'';

  profiles = lib.attrValues cfg;
  withMcp = lib.filter (p: p.mcp != { }) profiles;

  sync = pkgs.writeShellApplication {
    name = "ai-profiles-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      ${lib.concatMapStringsSep "\n" (p: ai.mergeJson {
        file = mcpFile p;
        frag = (pkgs.formats.json { }).generate "mcp-${p.name}.json" p.mcp;
        expr = ".mcpServers = ((.mcpServers // {}) + $ours[0])";
      }) withMcp}
      echo "MCP профилей Claude: ${lib.concatMapStringsSep ", " (p: "${p.name} (${toString (builtins.length (lib.attrNames p.mcp))})") withMcp}"
    '';
  };

  wrapper = p: pkgs.writeShellApplication {
    name = p.wrapper;
    runtimeInputs = [ pkgs.claude-code ] ++ p.tools;
    text = ''
      export CLAUDE_CONFIG_DIR="$HOME/${p.dir}"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=\"\${${k}:-${v}}\"") p.env)}
      exec claude "$@"
    '';
  };

  profileFiles = p:
    lib.optionalAttrs (p.instructions != null) { "${p.dir}/CLAUDE.md".source = p.instructions; }
    // lib.mapAttrs' (n: drv: lib.nameValuePair "${p.dir}/skills/${n}" (ai.recursive drv)) p.skills
    // lib.mapAttrs' (rel: v: lib.nameValuePair "${p.dir}/${rel}" v) p.files;
in
{
  options.ai.profiles = mkOption {
    description = "Независимые каталоги конфигурации Claude Code (CLAUDE_CONFIG_DIR) и их обёртки.";
    default = { };
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        name = mkOption { type = types.str; default = name; readOnly = true; };
        dir = mkOption { type = types.str; default = ".claude-${name}"; description = "Каталог относительно $HOME."; };
        wrapper = mkOption { type = types.nullOr types.str; default = "claude-${name}"; description = "Имя обёртки; null — без неё."; };
        instructions = mkOption { type = types.nullOr types.path; default = null; description = "CLAUDE.md профиля."; };
        skills = mkOption { type = types.attrsOf (types.either types.package types.path); default = { }; description = "Скиллы: имя -> каталог со SKILL.md (пакет или путь внутри него)."; };
        mcp = mkOption { type = types.attrsOf types.attrs; default = { }; description = "mcpServers для .claude.json профиля."; };
        files = mkOption { type = types.attrsOf types.attrs; default = { }; description = "Дополнительные home.file относительно dir."; };
        tools = mkOption { type = types.listOf types.package; default = [ ]; description = "Пакеты в PATH обёртки профиля."; };
        env = mkOption { type = types.attrsOf types.str; default = { }; description = "Переменные окружения, которые выставляет обёртка профиля."; };
      };
    }));
  };

  config = lib.mkIf (cfg != { }) {
    assertions = [{
      assertion = lib.allUnique (map (p: p.dir) profiles);
      message = "ai.profiles: два профиля делят один каталог";
    }];

    home.packages = [ sync ] ++ map wrapper (lib.filter (p: p.wrapper != null) profiles);
    home.file = lib.foldl' (acc: p: acc // profileFiles p) { } profiles;

    home.activation.aiProfiles = lib.mkIf (withMcp != [ ])
      (lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/ai-profiles-sync");
  };
}
