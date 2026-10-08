# MCP-серверы для claude-code, codex и agy: одно объявление — все агенты.
#
#   graphify — память кода. Граф лежит в ./graphify-out/graph.json в корне
#              проекта, значит переживает и смену сессии, и смену агента:
#              что построил один, читает другой.
#   zep      — обычная память. Удалённый сервер Zep, OAuth, ключ в конфиг не
#              кладётся вообще.
#   context7 — живая документация библиотек. Ключ приезжает из sops в рантайме.
#   colab    — удалённая песочница: агент пишет и исполняет ячейки в открытом
#              ноутбуке Colab. Пока только для agy (см. agyFrag ниже).
{ config, lib, pkgs, inputs, isNixOS ? true, ... }:

let
  # В nixpkgs graphify собран голым: сам graphify-mcp есть, а питоновской
  # либы mcp нет — сервер падает с ModuleNotFoundError на первом же запуске.
  # Доливаем ровно один экстра, без остального обвеса.
  graphify = pkgs.graphify.overridePythonAttrs (old: {
    dependencies = old.dependencies ++ old.optional-dependencies.mcp;
  });

  # Ключу context7 в /nix/store не место: стор мировой-читаемый. Поэтому в
  # декларации его нет — обёртка читает расшифрованный sops-ом файл в момент
  # старта сервера. Нет ключа — работаем с рейт-лимитом, а не молча врём.
  context7 = pkgs.writeShellApplication {
    name = "context7-mcp-sops";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      keyfile=${if isNixOS then "/run/secrets/context7_api_key" else lib.escapeShellArg "${config.sops.defaultSymlinkPath}/context7_api_key"}
      if [ -r "$keyfile" ]; then
        CONTEXT7_API_KEY="$(tr -d '\r\n' < "$keyfile")"
        export CONTEXT7_API_KEY
      else
        echo "context7: нет $keyfile — работаю без ключа, с рейт-лимитом" >&2
      fi
      exec ${pkgs.context7-mcp}/bin/context7-mcp "$@"
    '';
  };

  zepUrl = "https://api.getzep.com/mcp";

  # Замкнутый venv в сторе, собранный из uv.lock проекта. Подробности — в файле.
  colab = import ./colab-mcp.nix { inherit lib pkgs inputs; };

  json = (pkgs.formats.json { }).generate;

  # Одни и те же серверы, две разные анатомии конфигов.
  claudeFrag = json "mcp-claude.json" {
    graphify = {
      type = "stdio";
      command = "${graphify}/bin/graphify-mcp";
      args = [ ];
      env = { };
    };
    context7 = {
      type = "stdio";
      command = "${context7}/bin/context7-mcp-sops";
      args = [ ];
      env = { };
    };
    zep = {
      type = "http";
      url = zepUrl;
    };
  };

  codexFrag = json "mcp-codex.json" {
    graphify.command = "${graphify}/bin/graphify-mcp";
    context7.command = "${context7}/bin/context7-mcp-sops";
    zep.url = zepUrl;
  };

  # Antigravity сериализует этот файл через protojson, поэтому форма записи
  # повторяет ту, что пишет он сам ($typeName + command/args/env). Поля timeout
  # из документации Google здесь намеренно нет: наш venv уже собран в сторе и
  # стартует мгновенно, а лишний ключ рискует не пройти разбор protobuf.
  agyFrag = json "mcp-agy.json" {
    colab-mcp = {
      "$typeName" = "exa.cascade_plugins_pb.CascadePluginCommandTemplate";
      command = "${colab}/bin/colab-mcp";
      args = [ ];
      env = { };
    };
  };

  # Оба агента пишут свои конфиги сами: claude складывает туда кэши и счётчики,
  # codex — trust_level проектов. Владеть такими файлами через home.file значит
  # подсунуть агенту симлинк в стор и сломать ему запись. Поэтому не владеем, а
  # вливаем свой кусок и оставляем чужие ключи нетронутыми.
  sync = pkgs.writeShellApplication {
    name = "ai-mcp-sync";
    runtimeInputs = [ pkgs.jq pkgs.remarshal pkgs.coreutils ];
    text = ''
      # shellcheck disable=SC2016  # jq-выражения обязаны быть в одинарных кавычках

      claude="$HOME/.claude.json"
      codex="$HOME/.codex/config.toml"
      agy="$HOME/.gemini/config/mcp_config.json"

      # --- Claude Code -------------------------------------------------------
      # Пользовательские MCP живут именно в ~/.claude.json (проверено: сам
      # `claude mcp add --scope user` пишет туда), а не в settings.json.
      # Проверка -s, а не -f: агенты оставляют файл нулевой длины, а jq на
      # пустом входе падает с "Unexpected end of input".
      [ -s "$claude" ] || printf '{}\n' > "$claude"
      tmp="$(mktemp "$claude.XXXXXX")"
      jq --slurpfile ours ${claudeFrag} \
         '.mcpServers = ((.mcpServers // {}) + $ours[0])' "$claude" > "$tmp"
      mv -f "$tmp" "$claude"

      # --- Codex -------------------------------------------------------------
      # TOML -> JSON -> слияние -> TOML. Круговой прогон теряет комментарии,
      # поэтому свои заметки в config.toml не пиши — переживут только значения.
      mkdir -p "$(dirname "$codex")"
      [ -f "$codex" ] || : > "$codex"
      tmp="$(mktemp "$codex.XXXXXX")"
      remarshal -if toml -of json < "$codex" \
        | jq --slurpfile ours ${codexFrag} \
             '.mcp_servers = ((.mcp_servers // {}) + $ours[0])' \
        | remarshal -if json -of toml > "$tmp"
      mv -f "$tmp" "$codex"

      # --- Antigravity CLI (agy) ---------------------------------------------
      # Путь выдран из самого бинаря (он стрипнут, но строка на месте): agy
      # читает глобальные MCP именно отсюда, а НЕ из ~/.gemini/antigravity-cli/
      # рядом с settings.json и не из ~/.gemini/antigravity/ (то — конфиг IDE).
      mkdir -p "$(dirname "$agy")"
      [ -s "$agy" ] || printf '{}\n' > "$agy"
      tmp="$(mktemp "$agy.XXXXXX")"
      jq --slurpfile ours ${agyFrag} \
         '.mcpServers = ((.mcpServers // {}) + $ours[0])' "$agy" > "$tmp"
      mv -f "$tmp" "$agy"

      echo "MCP разложены: graphify, zep, context7 -> claude + codex; colab -> agy"
    '';
  };
in
{
  home.packages = [
    graphify # сам CLI: без `graphify extract` графа не существует
    colab    # тот же бинарь, что прописан agy — удобно дёрнуть для диагностики
    sync     # перелить руками, не дожидаясь ребилда
  ];

  home.activation.aiMcpServers =
    lib.hm.dag.entryAfter [ "writeBoundary" ] "$DRY_RUN_CMD ${sync}/bin/ai-mcp-sync";
}
