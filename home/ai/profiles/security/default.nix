# Профиль «ИБ» для Antigravity CLI: обёртка `agy-sec`, Argon по умолчанию,
# в PATH сканеры (SAST, секреты, SCA/SBOM, DAST), из скиллов только ECC.
#
# У agy нет переменной вроде CLAUDE_CONFIG_DIR: все пути (~/.gemini/config,
# ~/.gemini/antigravity-cli, ~/.gemini/GEMINI.md) он строит от $HOME. Поэтому
# профиль — отдельный $HOME в ~/.agy-security, куда agy кладёт свои скиллы,
# агенты, MCP, историю и кэши. Основной agy с дизайн-скиллами и colab-mcp
# этого каталога не видит, и наоборот. Общий у них только логин: обёртка
# ссылается на OAuth-токен основного профиля, второй /login не нужен.
# XDG_* обёртка оставляет на настоящем доме: git, gh, кэши trivy/semgrep
# продолжают читать ~/.config и ~/.cache.
#
#   GEMINI.md          правила профиля и шпаргалка по инструментам
#   tools.nix          набор инструментов (общий с devShell `security` во flake.nix)
#   (sec-scan, promptfoo, sec-pytest — из github:BadRabbit00/badrabbit-sec-scan)
#   schemathesis.nix   пакет (в nixpkgs нет), колёса с PyPI по sha256
#   py/                Agent Scan, Cisco mcp-scanner, AgentDojo, garak: venv из uv.lock (uv2nix)
#   skills/            свои sec-audit-* скиллы для agy (план аудита и гайды по инструментам)
{ lib, pkgs, inputs, pkgsCuda, ... }:

let
  ai = import ../../lib.nix { inherit lib pkgs; };
  # Тот же payload, что раскладывает ../../ecc: одинаковый вызов — одна деривация.
  runtime = import ../../ecc/runtime.nix { inherit lib pkgs; };
  payload = import ../../ecc/payload.nix { inherit lib pkgs runtime; };
  secTools = import ./tools.nix { inherit lib pkgs inputs pkgsCuda; };
  inherit (secTools) tools;
  perms = import ./permissions.nix;
  # у agy только префиксы: флаги и пути он не различает
  allowCommands = lib.attrNames perms.commands ++ lib.attrNames perms.read;
  semgrepMcp = import ./semgrep-mcp.nix { inherit pkgs; };

  dir = ".agy-security";
  gemini = "${dir}/.gemini";
  token = ".gemini/antigravity-cli/antigravity-oauth-token";

  # Свои sec-audit-* скиллы рядом с ECC. ECC-каталог смонтирован recursive, так
  # что соседние каталоги-скиллы не конфликтуют. Имена читаются из ./skills.
  secSkills = ai.dirNames ./skills;
  secSkillFiles = lib.listToAttrs (map
    (n: lib.nameValuePair "${gemini}/config/skills/${n}" (ai.recursive (./skills + "/${n}")))
    secSkills);

  # Модель при первом запуске (seed). Потом ключ — выбор пользователя:
  # /model и --model сильнее, ребилд его не перетирает.
  # permissions.allow — наоборот, закреплён Nix'ом и перетирает ручные правки:
  # это allow-list для headless-прогонов (`agy-sec --print`), где подтвердить
  # команду некому и всё вне списка soft-deny'ится. Сам список — в
  # ./permissions.nix, общий с opencode-sec и agy-sdk-sec.
  settingsFrag = (pkgs.formats.json { }).generate "agy-sec-settings.json" {
    model = "Gemini 4 Argon (High)";
    permissions.allow = map (c: "command(${c})") allowCommands;
  };

  # Форма записи — как у agy (protojson), см. ../../mcp/default.nix.
  mcpFrag = (pkgs.formats.json { }).generate "agy-sec-mcp.json" {
    semgrep = { "$typeName" = "exa.cascade_plugins_pb.CascadePluginCommandTemplate"; } // semgrepMcp;
  };


  sync = pkgs.writeShellApplication {
    name = "agy-sec-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      ${ai.mergeJson { file = ''"$HOME/${gemini}/config/mcp_config.json"''; frag = mcpFrag;
                       expr = ".mcpServers = ((.mcpServers // {}) + $ours[0])"; }}
      ${ai.mergeJson { file = ''"$HOME/${gemini}/antigravity-cli/settings.json"''; frag = settingsFrag;
                       expr = "($ours[0] + .) | .permissions = $ours[0].permissions"; }}
      echo "agy-sec: MCP semgrep, модель по умолчанию и permissions.allow влиты в ~/${gemini}"
    '';
  };

  wrapper = pkgs.writeShellApplication {
    name = "agy-sec";
    runtimeInputs = [ pkgs.antigravity-cli runtime.run ] ++ tools;
    text = ''
      # Настоящий дом запоминаем: agy-sec, запущенный изнутри agy-sec, не должен
      # уйти в ~/.agy-security/.agy-security.
      real="''${AGY_SEC_REAL_HOME:-$HOME}"
      export AGY_SEC_REAL_HOME="$real"
      prof="$real/${dir}"
      export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$real/.config}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$real/.cache}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$real/.local/share}"
      export XDG_STATE_HOME="''${XDG_STATE_HOME:-$real/.local/state}"
      export SEMGREP_SEND_METRICS="''${SEMGREP_SEND_METRICS:-off}"
      ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}='${lib.replaceStrings [ "'" ] [ "'\\''" ] v}'\n") perms.env)}
      # Логин общий с основным agy. Если agy однажды заменит ссылку своим
      # файлом (обновил токен через rename), это уже валидный токен профиля.
      # Без -f: настоящий токен не перетираем; || true — гонка двух первых запусков.
      mkdir -p "$prof/$(dirname ${token})"
      chmod 700 "$prof" # в логах бесед — вывод сканеров
      [ -e "$prof/${token}" ] || [ -L "$prof/${token}" ] || ln -s "$real/${token}" "$prof/${token}" || true
      export HOME="$prof"
      exec agy "$@"
    '';
  };
in
{
  # Тот же профиль на локальной модели: opencode-sec, agy-sdk-sec, llama-sec.
  imports = [ ./local ];

  # sec-scan — в общий PATH: им пользуются и claude, и codex, и руки.
  # Остальные инструменты — в agy-sec или `nix develop ~/nixos-conf#security`.
  home.packages = [ wrapper sync secTools.sec-scan ];

  home.file = {
    "${gemini}/GEMINI.md".source = ./GEMINI.md;
    "${gemini}/config/skills" = ai.recursive "${payload}/claude/skills";
    "${gemini}/config/agents" = ai.recursive "${payload}/agy/agents";
  } // secSkillFiles;

  home.activation.agySecSync =
    lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/agy-sec-sync";
}
