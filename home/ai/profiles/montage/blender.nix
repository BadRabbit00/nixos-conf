# Blender для профиля montage: скиллы по 3D-конвейеру и MCP-сервер.
#
#   EL4CTEO/blender-skills        22 скилла под Blender 5.2: моделинг, UV, PBR,
#                                 запекание, риг, анимация, симуляция, экспорт, QA
#   ifBars/blender-agent-studio   роутер + 12 специалистов (character-workflow,
#                                 modeling, procedural, rendering, simulation…)
#   ahujasid/mcp-for-blender      MCP «blender» (32k★, де-факто стандарт; у Blender
#                                 Foundation своего MCP нет). Две половины:
#                                 сервер mcp-for-blender (stdio, здесь из Nix) и
#                                 аддон внутри Blender, который слушает :9876.
#
# Аддон кладётся в ~/.config/blender/5.2/scripts/addons/blender_mcp.py (то же
# имя, что у штатного установщика, чтобы сервер видел его как установленный)
# и включается стартовым скриптом; сокет-сервер аддон поднимает сам
# (blendermcp_auto_start_server). Blender сам — pkgsCuda.blender из
# home/programs и из tools профиля.
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
  mcpSrc = pkgs.fetchgit {
    url = "https://github.com/ahujasid/mcp-for-blender";
    rev = "5a3618fccb2d982d0dd61e7a1879912c3100073b";
    hash = "sha256-p1jtowSYjIuyy4c6k+NOMRZlpRbkEyjjdmU7bc3kPf4=";
  };

  mcpServer = pkgs.python3Packages.buildPythonApplication {
    pname = "mcp-for-blender";
    version = "2.2.2";
    src = mcpSrc;
    pyproject = true;
    build-system = [ pkgs.python3Packages.setuptools ];
    dependencies = with pkgs.python3Packages; [ mcp httpx ];
    doCheck = false; # тесты ждут живой Blender на :9876
    meta = {
      description = "Blender integration through the Model Context Protocol";
      homepage = "https://github.com/ahujasid/mcp-for-blender";
      license = lib.licenses.mit;
      mainProgram = "mcp-for-blender";
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
      env = { };
    };

    tools = [ mcpServer ]; # ручная диагностика: mcp-for-blender --help
  };

  home.file = {
    "${blenderUser}/scripts/addons/blender_mcp.py".source = "${mcpSrc}/src/blender_mcp/bundled/addon.py";
    "${blenderUser}/scripts/startup/enable_blender_mcp.py".text = ''
      # Включает аддон MCP for Blender при каждом старте; сам файл аддона — из Nix.
      import bpy

      def _enable():
          try:
              bpy.ops.preferences.addon_enable(module="blender_mcp")
          except Exception as exc:  # noqa: BLE001 — Blender без UI или аддон уже включён
              print(f"enable_blender_mcp: {exc}")
          return None

      bpy.app.timers.register(_enable, first_interval=0.5)
    '';
  };
}
