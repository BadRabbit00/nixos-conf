# Schemathesis — property-based фаззинг API по OpenAPI/GraphQL-схеме.
# https://github.com/schemathesis/schemathesis (MIT)
#
# В nixpkgs его нет. Не хватает трёх зависимостей: harfile и hypothesis-graphql
# (чистый Python, тянем колёса с PyPI) и jsonschema-rs >= 0.60 (в nixpkgs 0.46).
# jsonschema-rs — расширение на Rust; вместо пересборки крейта с новым
# cargoHash берём abi3-колесо manylinux2014 и патчим ELF под стор. Всё запинено
# по sha256, сеть в рантайме не нужна.
{ lib, python3Packages }:

let
  ps = python3Packages;

  wheel = { pname, version, hash, dist ? "py3", python ? "py3", abi ? "none", platform ? "any" }:
    ps.fetchPypi {
      inherit pname version hash dist python abi platform;
      format = "wheel";
    };

  harfile = ps.buildPythonPackage rec {
    pname = "harfile";
    version = "0.6.0";
    format = "wheel";
    src = wheel { inherit pname version; hash = "sha256-DyIJ1uwWSirqfo+ytJ2f713e7lG2Xb/SikFnGFw0uzA="; };
    pythonImportsCheck = [ "harfile" ];
    meta.license = lib.licenses.mit;
  };

  hypothesis-graphql = ps.buildPythonPackage rec {
    pname = "hypothesis_graphql";
    version = "0.13.5";
    format = "wheel";
    src = wheel { inherit pname version; hash = "sha256-e/FrKQ/FuHBTngGBRGzaHyqtw7IzqLR1Mxq8F2T+TkA="; };
    dependencies = [ ps.graphql-core ps.hypothesis ];
    pythonImportsCheck = [ "hypothesis_graphql" ];
    meta.license = lib.licenses.mit;
  };

  jsonschema-rs = ps.buildPythonPackage rec {
    pname = "jsonschema_rs";
    version = "0.60.1";
    format = "wheel";
    src = wheel {
      inherit pname version;
      dist = "cp310"; python = "cp310"; abi = "abi3";
      platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
      hash = "sha256-1DRX+n2vhx9/1RlVw9pyJ+11aHF8beMJlS66XEEuFIg=";
    };
    nativeBuildInputs = [ ps.pkgs.autoPatchelfHook ];
    buildInputs = [ ps.pkgs.stdenv.cc.cc.lib ];
    pythonImportsCheck = [ "jsonschema_rs" ];
    meta = {
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
ps.buildPythonApplication rec {
  pname = "schemathesis";
  version = "4.32.5";
  format = "wheel";
  src = wheel { inherit pname version; hash = "sha256-XsflMuvfmw4COalD3ypWUXSuzaUTth5WTYrSo6yAHyI="; };

  dependencies = with ps; [
    anyio click harfile hypothesis-graphql hypothesis jsonschema-rs pyrate-limiter
    pytest pyyaml requests rich typing-extensions werkzeug
  ];

  pythonImportsCheck = [ "schemathesis" ];

  meta = {
    description = "Property-based testing for API schemas (OpenAPI, GraphQL)";
    homepage = "https://schemathesis.io";
    license = lib.licenses.mit;
    mainProgram = "st";
    platforms = [ "x86_64-linux" ];
  };
}
