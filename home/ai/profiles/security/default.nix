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
#   schemathesis.nix   пакет (в nixpkgs нет), колёса с PyPI по sha256
{ lib, pkgs, ... }:

let
  ai = import ../../lib.nix { inherit lib pkgs; };
  # Тот же payload, что раскладывает ../../ecc: одинаковый вызов — одна деривация.
  runtime = import ../../ecc/runtime.nix { inherit lib pkgs; };
  payload = import ../../ecc/payload.nix { inherit lib pkgs runtime; };
  schemathesis = pkgs.callPackage ./schemathesis.nix { };

  dir = ".agy-security";
  gemini = "${dir}/.gemini";
  token = ".gemini/antigravity-cli/antigravity-oauth-token";

  tools = with pkgs; [
    # SAST
    semgrep            # semgrep scan; `semgrep mcp` — MCP-сервер ниже
    bandit             # Python AST
    sonar-scanner-cli  # sonar-scanner, нужен свой SonarQube
    # секреты
    gitleaks
    trufflehog
    # зависимости, контейнеры, SBOM
    trivy
    osv-scanner
    syft
    grype
    pip-audit
    cargo-audit
    nodejs             # npm audit; сам проект — из своего devShell
    # DAST / API
    zap                # OWASP ZAP, headless: zap -cmd -autorun zap.yaml
    schemathesis       # st run <openapi.json>
  ];

  # Модель по умолчанию; /model и --model в сессии сильнее. Ключи, которые
  # agy уже записал сам, не перетираем.
  settingsFrag = (pkgs.formats.json { }).generate "agy-sec-settings.json" {
    model = "Gemini 4 Argon (High)";
  };

  # Форма записи — как у agy (protojson), см. ../../mcp/default.nix.
  mcpFrag = (pkgs.formats.json { }).generate "agy-sec-mcp.json" {
    semgrep = {
      "$typeName" = "exa.cascade_plugins_pb.CascadePluginCommandTemplate";
      command = "${pkgs.semgrep}/bin/semgrep";
      args = [ "mcp" "--transport" "stdio" ];
      env.SEMGREP_SEND_METRICS = "off";
    };
  };

  sync = pkgs.writeShellApplication {
    name = "agy-sec-sync";
    runtimeInputs = ai.mergeInputs;
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках
      ${ai.mergeJson { file = ''"$HOME/${gemini}/config/mcp_config.json"''; frag = mcpFrag;
                       expr = ".mcpServers = ((.mcpServers // {}) + $ours[0])"; }}
      ${ai.mergeJson { file = ''"$HOME/${gemini}/antigravity-cli/settings.json"''; frag = settingsFrag;
                       expr = "$ours[0] + ."; }}
      echo "agy-sec: MCP semgrep и модель по умолчанию влиты в ~/${gemini}"
    '';
  };

  wrapper = pkgs.writeShellApplication {
    name = "agy-sec";
    runtimeInputs = [ pkgs.antigravity-cli runtime.run ] ++ tools;
    text = ''
      real="$HOME"
      prof="$real/${dir}"
      export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$real/.config}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$real/.cache}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$real/.local/share}"
      export XDG_STATE_HOME="''${XDG_STATE_HOME:-$real/.local/state}"
      export SEMGREP_SEND_METRICS="''${SEMGREP_SEND_METRICS:-off}"
      # Логин общий с основным agy. Если agy однажды заменит ссылку своим
      # файлом (обновил токен через rename), это уже валидный токен профиля.
      mkdir -p "$prof/$(dirname ${token})"
      [ -e "$prof/${token}" ] || [ -L "$prof/${token}" ] || ln -s "$real/${token}" "$prof/${token}"
      export HOME="$prof"
      exec agy "$@"
    '';
  };
in
{
  home.packages = [ wrapper sync ];

  home.file = {
    "${gemini}/GEMINI.md".source = ./GEMINI.md;
    "${gemini}/config/skills" = ai.recursive "${payload}/claude/skills";
    "${gemini}/config/agents" = ai.recursive "${payload}/agy/agents";
  };

  home.activation.agySecSync =
    lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/agy-sec-sync";
}
