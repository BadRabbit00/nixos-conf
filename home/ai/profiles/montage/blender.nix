# Blender для профиля montage: скиллы по 3D-конвейеру и MCP-сервер.
#
#   EL4CTEO/blender-skills        22 скилла под Blender 5.2: моделинг, UV, PBR,
#                                 запекание, риг, анимация, симуляция, экспорт, QA
#   ifBars/blender-agent-studio   роутер + 12 специалистов (character-workflow,
#                                 modeling, procedural, rendering, simulation…)
#   Blender Lab blender_mcp       официальный MCP «blender» (см. ниже): сервер из
#                                 Nix, extension в ~/.config/blender/5.2
#
# Blender сам — pkgsCuda.blender из home/programs и из tools профиля.
{ lib, pkgs, pkgsCuda, ... }:

let
  ai = import ../../lib.nix { inherit lib pkgs; };
  banner = ./banner.md;
  version = "0-unstable-2026-10-23";
  set = pname: src: skills: extra: ai.mkSkillSet { inherit pname version src skills banner extra; };
  under = dir: names: lib.genAttrs names (n: "${dir}/${n}");

  blenderSkillsSrc = pkgs.fetchgit {
    url = "https://github.com/EL4CTEO/blender-skills";
    rev = "71d031dab8bc6729504d11a78cbe91945401045f";
    hash = "sha256-njc2MKcgUiqNgztOVpArq3KvCJ0ilLJnTpFl2XUzT/M=";
  };
  agentStudioSrc = pkgs.fetchgit {
    url = "https://github.com/ifBars/blender-agent-studio";
    rev = "b9b714012858a73831f5e79df2bc1c80658e5dad";
    hash = "sha256-xyrtCbbIlj6l6kMSFopFOg3QSzRgHYiU2WBlTWscG6I=";
  };
  # Официальный MCP от Blender Lab (projects.blender.org/lab/blender_mcp),
  # коммит тот же, что пинит плагин Hermes Agent (v1.0.3). Две половины:
  #   mcp/    сервер blender-mcp (stdio), здесь собран как python-приложение;
  #           26 МБ RST-справки по API и мануалу едут внутрь пакета;
  #   addon/  extension «mcp» (blender_version_min 5.1), слушает localhost:9876,
  #           автостарт включён по умолчанию, но требует разрешённого online
  #           access в настройках Blender — стартовый скрипт включает и то, и то.
  mcpSrc = pkgs.fetchgit {
    url = "https://projects.blender.org/lab/blender_mcp.git";
    rev = "2cea8d566dde07fbac28a61d698909d69724e853";
    hash = "sha256-pYeByO4Oi5eyynsJhGVd1vBWXHvhGn+Y5LGit6Kazlw=";
  };

  mcpServer = pkgs.python3Packages.buildPythonApplication {
    pname = "blender-mcp";
    version = "1.0.3";
    src = mcpSrc;
    sourceRoot = "${mcpSrc.name}/mcp";
    pyproject = true;
    build-system = [ pkgs.python3Packages.setuptools ];
    dependencies = with pkgs.python3Packages; [ docutils pyyaml mcp ] ++ mcp.optional-dependencies.cli;
    doCheck = false; # интеграционные тесты ждут живой Blender на :9876
    meta = {
      description = "Blender Lab MCP server: natural-language interface to the Python API and docs";
      homepage = "https://www.blender.org/lab/mcp-server/";
      license = lib.licenses.gpl3Plus;
      mainProgram = "blender-mcp";
    };
  };

  blenderMajorMinor = lib.versions.majorMinor pkgsCuda.blender.version; # "5.2"
  blenderUser = ".config/blender/${blenderMajorMinor}";
in
{
  ai.profiles.montage = {
    skills =
      set "blender-skills" blenderSkillsSrc (under "skills" [
        "blender-core" "blender-scene-setup" "blender-workflow-recipes" "blender-hardsurface-modeling"
        "blender-sculpting" "blender-retopology-uv" "blender-pbr-materials" "blender-texture-baking"
        "blender-geometry-nodes" "blender-lighting-lookdev" "blender-rendering" "blender-time-of-day"
        "blender-weather-fx" "blender-character-rigging" "blender-facial-shapekeys" "blender-animation"
        "blender-simulation" "blender-game-optimization" "blender-export-pipelines" "blender-asset-qa"
        "blender-pipeline-automation" "blender-addon-development" ]) ""
      # Роутер — корневой SKILL.md; свои plugins/site/tools ему не нужны.
      // set "blender-agent-studio" agentStudioSrc ({ blender-agent-studio = "."; } // under "plugins/blender-agent-studio/skills" [
        "blender-art-direction-intake" "blender-modeling-workflow" "blender-character-workflow"
        "blender-procedural-workflow" "blender-rendering-workflow" "blender-simulation-workflow"
        "blender-animation-workflow" "blender-signage-workflow" "blender-asset-validation"
        "blender-iterative-refinement" "blender-mcp-integration" "blender-agent-benchmark" ])
        ''rm -rf "$out/blender-agent-studio"/{plugins,site,tools,scripts,node_modules}'';

    mcp.blender = {
      type = "stdio";
      command = lib.getExe mcpServer;
      args = [ ];
      # *_for_cli-инструменты запускают сам Blender в фоне.
      env.BLENDER_PATH = lib.getExe pkgsCuda.blender;
    };

    tools = [ mcpServer ]; # ручная диагностика: blender-mcp --help
  };

  home.file = {
    # Extension целиком (каталог = id из blender_manifest.toml); репозиторий
    # user_default Blender сканирует сам, остаётся только включить.
    "${blenderUser}/extensions/user_default/mcp" = {
      source = "${mcpSrc}/addon/blender_mcp_addon";
      recursive = true;
    };
    "${blenderUser}/scripts/startup/enable_blender_mcp.py".text = ''
      # Разрешает online access (без него extension MCP отказывается стартовать)
      # и включает extension при каждом запуске; сам код аддона — из Nix.
      import bpy

      def _enable():
          try:
              bpy.context.preferences.system.use_online_access = True
              bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mcp")
          except Exception as exc:  # noqa: BLE001 — фоновый режим или уже включён
              print(f"enable_blender_mcp: {exc}")
          return None

      bpy.app.timers.register(_enable, first_interval=0.5)
    '';
  };
}
