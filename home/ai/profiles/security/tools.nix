# Набор ИБ-инструментов одним местом. Его берут два потребителя:
#   - профиль agy-sec (./default.nix) — PATH обёртки;
#   - devShell `security` во flake.nix — для claude, codex и рук:
#       nix develop ~/nixos-conf#security
# sec-scan, promptfoo и sec-pytest приходят из github:BadRabbit00/badrabbit-sec-scan —
# того же флейка, который гоняет CI в проектах: локально и в CI одна версия.
#
# pkgsCuda — nixpkgs с cudaSupport; null — без garak.
{ lib, pkgs, inputs, pkgsCuda ? null }:

let
  schemathesis = pkgs.callPackage ./schemathesis.nix { };
  py = import ./py { inherit lib pkgs inputs pkgsCuda; };

  # Наружу — только команды venv-ов: их python, pip-audit и прочее не должны
  # перекрывать системные бинари.
  snyk-agent-scan = pkgs.writeShellScriptBin "snyk-agent-scan"
    ''exec ${py.agent-scan}/bin/snyk-agent-scan "$@"'';
  # yara/static — офлайн; llm/api/virustotal — по ключам. Загрузку файлов в
  # VirusTotal без явного решения не делаем.
  mcp-scanner = pkgs.writeShellScriptBin "mcp-scanner" ''
    export MCP_SCANNER_VIRUSTOTAL_UPLOAD_FILES="''${MCP_SCANNER_VIRUSTOTAL_UPLOAD_FILES:-false}"
    exec ${py.mcp-scanner}/bin/mcp-scanner "$@"
  '';
  # У пакета нет console-скрипта, точка входа — модуль benchmark.
  agentdojo = pkgs.writeShellScriptBin "agentdojo"
    ''exec ${py.agentdojo}/bin/python -m agentdojo.scripts.benchmark "$@"'';
  garak = pkgs.writeShellScriptBin "garak" ''exec ${py.garak}/bin/garak "$@"'';

  ci = inputs.badrabbit-sec-scan.packages.${pkgs.stdenv.hostPlatform.system};
  inherit (ci) sec-scan promptfoo sec-pytest;
  # Тот же пакет, что flake check проверяет: гость вычисляется один раз на флейк.
  sec-vm = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.sec-vm;

  # pip_api зовёт `python -m pip`; у голого python3 из closure pip-audit pip нет.
  # Свой python через PIPAPI_PYTHON_LOCATION сильнее (аудит venv проекта).
  pyWithPip = pkgs.python3.withPackages (ps: [ ps.pip ]);
  pip-audit = pkgs.writeShellScriptBin "pip-audit" ''
    export PIPAPI_PYTHON_LOCATION="''${PIPAPI_PYTHON_LOCATION:-${pyWithPip}/bin/python3}"
    exec ${pkgs.pip-audit}/bin/pip-audit "$@"
  '';

  tools = with pkgs; [
    sec-scan           # гейт secrets/SAST/SCA/IaC/SBOM, как в CI
    sec-pytest         # pytest для своих тестов в .sec/test
    sec-vm             # изолированный стенд активного аудита (VM без сети)
    # SAST
    semgrep            # semgrep scan; `semgrep mcp` — MCP-сервер профиля agy-sec
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
    pip-audit          # обёртка выше: pip_api с рабочим pip
    cargo-audit        # `cargo-audit audit`: cargo в PATH не нужен
    # npm audit — из devShell проекта: свой nodejs здесь перекрыл бы проектный
    # DAST / API
    zap                # OWASP ZAP, headless: zap -cmd -autorun zap.yaml
    schemathesis       # st run <openapi.json>
    # AI / агенты
    promptfoo          # red teaming LLM-приложения целиком (промпт, тулы, RAG)
    snyk-agent-scan    # MCP/скиллы; анализ уходит на api.snyk.io
    mcp-scanner        # Cisco: MCP офлайн (yara, behavioral)
    agentdojo          # бенчмарк агента против prompt injection
  ] ++ lib.optional (pkgsCuda != null) garak;
in
{
  inherit tools sec-scan sec-vm;
}
