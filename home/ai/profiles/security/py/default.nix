# Питоновые сканеры AI-безопасности, которых нет в nixpkgs. Приём тот же, что у
# ../../../mcp/colab-mcp.nix: у каждого инструмента свой pyproject.toml + uv.lock,
# uv2nix собирает из лока замкнутый venv в сторе, колёса приезжают по хешам из
# лока. В рантайме ни uv, ни сети для установки.
#
# Отдельный venv на инструмент: snyk-agent-scan пинит mcp==1.30 и rich==14.2,
# cisco-ai-mcp-scanner хочет mcp>=2 — в одном окружении они не сходятся.
#
# Обновить: поменять пин в py/<имя>/pyproject.toml, затем в его каталоге
#   UV_PYTHON_DOWNLOADS=never nix shell nixpkgs#uv nixpkgs#python313 -c uv lock --python python3.13
# (для garak — python314 / python3.14, см. ниже).
#
# pkgsCuda — nixpkgs с cudaSupport (как в home/generic-linux.nix); null — без garak
# (CI: garak там не нужен, LLM-часть проверяет promptfoo).
{ lib, pkgs, inputs, pkgsCuda ? null }:

let
  inherit (inputs) pyproject-nix uv2nix pyproject-build-systems;
  hacks = pkgs.callPackage pyproject-nix.build.hacks { };

  # Пакеты только в sdist, которые не объявляют setuptools как build-system
  # (старый setup.py). Список — из локов: колёс у них на PyPI нет вовсе.
  legacySetuptools = [ "ecoji" "langdetect" ];
  buildFixes = final: prev: lib.genAttrs (lib.filter (n: prev ? ${n}) legacySetuptools) (n:
    prev.${n}.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
    }));

  # torch из nixpkgs вместо колеса PyPI: CUDA-сборка приходит готовой из
  # cache.nixos-cuda.org (sm_120 в ней есть), CPU — из cache.nixos.org. Его
  # pip-зависимости nvidia-*/cuda-*/triton из venv выкидываем: рантайм CUDA уже
  # внутри nixpkgs-торча, а колёса на гигабайты никому не нужны.
  nixpkgsTorch = torch: _final: prev: {
    torch = hacks.nixpkgsPrebuilt {
      from = torch;
      prev = prev.torch // {
        passthru = prev.torch.passthru // {
          dependencies = lib.filterAttrs
            (n: _: !(lib.hasPrefix "nvidia-" n || lib.hasPrefix "cuda-" n || n == "triton"))
            prev.torch.passthru.dependencies;
        };
      };
    };
  };

  # dir — каталог с pyproject.toml/uv.lock; dist — дистрибутив, чьи скрипты нужны.
  # 3.13 по умолчанию: у yara-python и tree-sitter-* под 3.14 колёс нет.
  mkEnv = { name, dir, dist, python ? pkgs.python313, extra ? (_: _: { }) }:
    let
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = dir; };
      overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
      pythonSet =
        (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope
          (lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
            buildFixes
            extra
          ]);
    in
    pythonSet.mkVirtualEnv "${name}-env" { ${dist} = [ ]; };

  # garak на python3 из того же набора пакетов, что и его torch: иначе
  # nixpkgsPrebuilt откажется (разные интерпретаторы — разный ABI).
  mkGarak = name: ps: mkEnv {
    inherit name;
    dir = ./garak;
    dist = "garak";
    python = ps.python3;
    extra = nixpkgsTorch ps.python3Packages.torch;
  };
in
{
  # Snyk Agent Scan (бывший Invariant mcp-scan): MCP-конфиги, скиллы, tool poisoning.
  agent-scan = mkEnv { name = "snyk-agent-scan"; dir = ./agent-scan; dist = "snyk-agent-scan"; };
  # Cisco AI Defense mcp-scanner: YARA-правила офлайн, LLM/API-анализаторы опционально.
  mcp-scanner = mkEnv { name = "cisco-mcp-scanner"; dir = ./mcp-scanner; dist = "cisco-ai-mcp-scanner"; };
  # AgentDojo (ETH Zurich): бенчмарк устойчивости агента к prompt injection.
  agentdojo = mkEnv { name = "agentdojo"; dir = ./agentdojo; dist = "agentdojo"; };
} // lib.optionalAttrs (pkgsCuda != null) {
  # garak (NVIDIA): 230+ проб уязвимостей модели. Только локально, на RTX:
  # цели — llama-server (OpenAI API), HF-модели, API. В CI его место — promptfoo.
  garak = mkGarak "garak" pkgsCuda;
}
