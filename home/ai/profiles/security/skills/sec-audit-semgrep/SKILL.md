---
name: sec-audit-semgrep
description: SAST инструментом semgrep — семантический поиск уязвимостей по правилам (инъекции, SSRF, XSS, небезопасная крипта) во многих языках. Наборы правил, вывод JSON/SARIF, подавление, тонкости метрик и кода выхода. Звать при словах "semgrep", "SAST", "статический анализ", или как шаг sec-audit-passive.
---

# semgrep — семантический SAST (пассивно)

semgrep 1.179.0 в PATH профиля. Своих встроенных проверок нет — всё приходит
из `--config` (наборы правил `p/...` из реестра или локальные YAML).

## Что проверяет

Многоязычный анализ по паттернам и потоку данных (taint): инъекции, SSRF, XSS,
небезопасная десериализация, слабая крипта. Наборы:
- **p/default** — курируемый кросс-язычный набор по умолчанию, самое широкое покрытие.
- **p/owasp-top-ten** — правила под категории OWASP Top 10.
- **p/secrets** — хардкод-секреты; но большая часть правил (~218 из 270) — Pro и
  требует логина, без него работает только свободное подмножество.

## Команды

```sh
semgrep scan --config p/default --config p/owasp-top-ten --metrics off \
  --json --json-output=.sec/reports/json/semgrep.json .
semgrep scan --config p/default --metrics off \
  --sarif --sarif-output=.sec/reports/sarif/semgrep.sarif .
```

Свои правила из `.sec/`, офлайн, без телеметрии:

```sh
semgrep scan --config .sec/semgrep --metrics off --sarif --sarif-output=.sec/reports/sarif/semgrep.sarif .
```

Флаги: `-c/--config` (файл, каталог YAML, URL или id реестра; **повторяемый**),
`--json`/`--json-output=FILE`, `--sarif`/`--sarif-output=FILE`,
`--severity=INFO|WARNING|ERROR` (повторяемый), `--exclude=GLOB`/`--include=GLOB`,
`--baseline-commit=HASH` (diff-скан относительно коммита), `--max-target-bytes`,
`--no-git-ignore`.

## ⚠️ Метрики и код выхода (важно)

- `--config auto` **тянет правила из реестра и шлёт телеметрию** (под дефолтным
  `--metrics=auto`), плюс требует сеть. Для пассивного/офлайн-аудита не годится.
  Любой `p/...` тоже тянется из реестра и шлёт метрики — поэтому всегда
  `--metrics off`, а для полного офлайна — локальный каталог правил в `--config`.
- **Код выхода `1` при находках бывает только с `--error`.** По умолчанию скан с
  находками всё равно выходит `0`. Гейт на коде выхода (как в sec-scan) должен
  ставить `--error` или читать JSON. Прочие коды: `2` фатальная ошибка,
  `4` плохой паттерн, `7` нет конфига.

## Как НЕ надо

```sh
semgrep scan --config auto .            # офлайн не работает + шлёт телеметрию
semgrep ci                              # режим для их платформы, не для разового аудита
```
- Не ждать полного покрытия от `p/secrets` без логина (большинство правил Pro).
- Не держать `p/...` неприпиненными для воспроизводимого аудита — вендорь копию
  правил локально в `.sec/semgrep`, если нужна стабильная база.
- Свой `.semgrepignore` **заменяет** встроенный шаблон (который скипает `.git`,
  `node_modules/`, `vendor/`, `build/`, `dist/`, тесты) — иначе случайно начнёшь
  сканировать вендор.

## Чтение вывода

JSON: `results[]{check_id, path, start/end, extra.message, extra.severity
(INFO/WARNING/ERROR), extra.metadata (owasp/cwe/confidence), extra.lines}`, плюс
`errors[]` (пропущенные файлы/правила — читать!) и `paths.scanned`.
Триаж: `metadata.confidence: HIGH` + taint-правило до реального sink = скорее
true positive. Паттерн-правила на тестах/моках или где «грязное» значение —
константа = обычные ложные.

## Подавление

- Инлайн: комментарий с `nosemgrep` на строке находки или строкой выше;
  по правилу — `# nosemgrep: rule-id` (id с неймспейсом). Включено по умолчанию.
- `.semgrepignore` в корне (gitignore-синтаксис); помни, что он заменяет
  встроенный шаблон.
- Тюнинг = выбор правил: комбинируй `--config`, фильтруй `--severity`,
  ограничивай `--include`/`--exclude`.

## MCP

В профиле включён MCP-сервер `semgrep` (только `semgrep_scan_with_custom_rule`,
AST и схема правил — остальные выключены без токена). Через MCP удобно проверить
гипотезу своим YAML-правилом; полные сканы — через CLI выше.

## Отчёты

`.sec/reports/`, в `.gitignore`.

## Доки

- https://docs.semgrep.dev/cli-reference
- https://docs.semgrep.dev/ignoring-files-folders-code
- https://docs.semgrep.dev/metrics
