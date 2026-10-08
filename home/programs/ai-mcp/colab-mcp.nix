# Colab MCP — мост от локального агента к Colab-сессии в браузере.
#
# Официальная инструкция Google предлагает `uvx git+https://…/colab-mcp`, то
# есть тянуть неверсионированный HEAD с гита при КАЖДОМ старте сервера и
# резолвить зависимости в рантайме мимо Nix. Так мы не играем.
#
# Здесь исходник пинуется по rev+hash, а девять его зависимостей собираются из
# репозиторного uv.lock через uv2nix: колёса приезжают fixed-output-деривациями
# по хешам ИЗ САМОГО ЛОКА. В рантайме нет ни uv, ни сети — сервер стартует из
# готового venv в /nix/store.
#
# Почему не честный python3Packages.buildPythonApplication: в nixpkgs нет ни
# jupyter-kernel-client, ни requests-oauth2client, а fastmcp там 3.4.7 при пине
# ==2.14.5 — разошёлся мажор. Это три своих питон-пакета плюс патч пина, и всё
# разваливается на следующем апдейте nixpkgs. uv.lock — источник правды автора.
{ lib, pkgs, inputs }:

let
  inherit (inputs) pyproject-nix uv2nix pyproject-build-systems;

  # pyproject.toml требует >=3.13, .python-version в репозитории — ровно 3.13.
  python = pkgs.python313;

  src = pkgs.fetchFromGitHub {
    owner = "googlecolab";
    repo = "colab-mcp";
    rev = "b9ab3899e0f1fa493390b1fd6d54aa2e464ecdf1";
    hash = "sha256-a2ObK9IGWd9z2oe6b8iU3LEZIhXuOH6P54P1Fidphbw=";
  };

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };

  # Предпочитаем колёса: sdist тянет за собой сборку C-расширений (pydantic-core,
  # websockets), а это минуты компиляции ради байт-в-байт того же результата.
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
      ]);
in
# Замкнутый venv в сторе: bin/colab-mcp плюс всё дерево зависимостей.
pythonSet.mkVirtualEnv "colab-mcp-env" workspace.deps.default
