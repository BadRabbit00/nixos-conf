---
name: sec-audit-mcp
description: Аудит цепочки поставок агента — MCP-серверы, скиллы, описания инструментов и промпты на prompt injection и tool poisoning. mcp-scanner (Cisco, офлайн-анализаторы) и snyk-agent-scan (inspect офлайн; scan шлёт данные в Snyk). Звать при словах "MCP", "tool poisoning", "prompt injection в инструментах", "аудит агента".
---

# Аудит MCP / цепочки поставок агента (пассивно)

Два инструмента в PATH профиля. Оба смотрят описания инструментов, промпты и
скиллы MCP-серверов на внедрённые инструкции и отравление.

## mcp-scanner 4.8.7 (Cisco AI Defense)

**Субкоманды** (не анализаторы): `static`, `behavioral`, `config`, `vulnerable-package`.
**Анализаторы** задаёт `--analyzers` ПЕРЕД субкомандой: `yara`, `readiness`,
`prompt_defense`, `schema` — локальные; `api`, `llm`, `virustotal` — ходят в сеть
и требуют ключей.

Пассивно и без утечки = `static` по заранее выгруженному JSON, только локальные
анализаторы:

```sh
mcp-scanner --analyzers yara,readiness,prompt_defense,schema --format summary \
  static --tools tools.json
```

где `tools.json` — выгрузка `tools/list` сервера (`name`, `description`,
`inputSchema`). Форматы: `summary`, `detailed`, `table`, `by_severity`, `raw`.

Как НЕ надо:
```sh
mcp-scanner --analyzers llm,api,virustotal ...    # уводит данные с машины / нужны ключи
mcp-scanner ... config --config-path mcp.json     # config ПОДКЛЮЧАЕТСЯ к живым серверам — не пассивно
```
- `behavioral <path>` берёт путь позиционно и использует LLM-проверку — офлайн
  только если `llm` указывает на локальный endpoint; иначе не пассивно.
- Флага `--source-path` в доках нет — не выдумывай.
- `MCP_SCANNER_VIRUSTOTAL_UPLOAD_FILES` держи `false`/не трогай (дефолт false).

## snyk-agent-scan 0.6.9 (бывший Invariant mcp-scan)

Инвентаризирует MCP-серверы/скиллы/инструменты/промпты и ищет внедрения и tool
poisoning.

**⚠️ `scan` по умолчанию шлёт данные в Snyk** (имена и описания инструментов,
содержимое скиллов; секреты редактируются до отправки), требует токен, офлайн-
режима в 0.6.9 в доках нет. Поэтому для пассивного аудита без утечки —
**только `inspect`**:

```sh
snyk-agent-scan inspect mcp.json          # локальный разбор без анализа-API
```

`scan` (c токеном, с явного разрешения Архитектора и не для конфиденциальных
конфигов):
```sh
snyk-agent-scan scan mcp.json --json --no-skills
```
Флаги `scan`: `--json`, `--skills`/`--no-skills`, `--control-server URL`
(+`--control-server-H`, `--control-identifier`), `--ci`, `--ignore-risks`.
`--dangerously-run-mcp-servers` — не использовать.

Как НЕ надо: гонять `scan` на конфиденциальных MCP-конфигах (описания и скиллы
уходят в Snyk); считать, что `inspect` полностью офлайн — он без анализа-API, но
полная сетевая изоляция в доках не гарантирована.

## Где это уместно

Когда аудируешь сам агентский слой проекта: его MCP-конфиги, определения
инструментов, скиллы. Для нашего профиля сами описания инструментов безопаснее
смотреть `inspect`/`static`. Полноценный red team LLM-приложения — отдельно
(promptfoo, активный аудит).

## Отчёты

`.sec/reports/`, в `.gitignore`.

## Доки

- https://github.com/cisco-ai-defense/mcp-scanner
- https://github.com/snyk/agent-scan
