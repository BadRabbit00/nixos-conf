# Semgrep MCP для ИБ-профиля: одна запись для agy-sec, opencode-sec и agy-sdk-sec.
#
# `semgrep mcp` сам включает OTel-трейсинг на сервер Semgrep (git user,
# имя репо, ветка) — для клиентских репо это утечка. Без токена
# semgrep_scan / findings / supply_chain всё равно падают (auto-конфиг при
# выключенных метриках), поэтому выключены: сканы — через CLI с p/…
{ pkgs }:

{
  command = "${pkgs.semgrep}/bin/semgrep";
  args = [ "mcp" "--transport" "stdio" ];
  env = {
    SEMGREP_SEND_METRICS = "off";
    SEMGREP_MCP_DISABLE_TRACING = "true";
    SEMGREP_ENABLE_VERSION_CHECK = "0";
    SEMGREP_SCAN_DISABLED = "true";
    SEMGREP_FINDINGS_DISABLED = "true";
    SEMGREP_SCAN_SUPPLY_CHAIN_DISABLED = "true";
  };
}
