---
name: sec-audit-gitleaks
description: Как искать секреты в коде и git-истории инструментом gitleaks при пассивном аудите. Что он находит, безопасные команды (git/dir), чтение JSON/SARIF, подавление ложных срабатываний. Звать при словах "секреты", "gitleaks", "утёкшие ключи", "токены в коде", или как шаг sec-audit-passive.
---

# gitleaks — поиск секретов (пассивно, офлайн)

gitleaks 8.30.1 уже в PATH профиля. Он **никуда не ходит по сети** — только
сопоставляет регулярки и энтропию. Это самый безопасный секрет-сканер для
чужого репозитория: найденный ключ не уходит провайдеру (в отличие от
verification у trufflehog, см. [[sec-audit-trufflehog]]).

## Что проверяет

- Регулярками + опциональной энтропией Шеннона по каждому правилу: API-ключи,
  приватные RSA/ED25519-ключи, пароли в URL, токены облаков, сертификаты.
- Две поверхности сканирования:
  - `gitleaks git <path>` — вся **история** (под капотом `git log -p`);
  - `gitleaks dir <path>` — рабочее дерево/файлы **без git** (алиасы `files`, `directory`).
- `detect` — устаревшая команда (deprecated с v8.19.0), не используй её.

## Команды (безопасные для пассивного аудита)

Полная история, отчёт в SARIF, секреты маскируются:

```sh
gitleaks git . --redact --no-banner \
  --report-format sarif --report-path .sec/reports/sarif/gitleaks.sarif \
  --exit-code 2
```

Дерево без git (например, распакованный архив):

```sh
gitleaks dir . --redact --no-banner \
  --report-format json --report-path .sec/reports/json/gitleaks.json
```

Свой конфиг и принятые находки из `.sec/`:

```sh
gitleaks git . --redact --config .sec/gitleaks.toml \
  --gitleaks-ignore-path .sec/.gitleaksignore \
  --report-format sarif --report-path .sec/reports/sarif/gitleaks.sarif
```

Ключевые флаги: `-f/--report-format` (json, csv, junit, sarif, template),
`-r/--report-path`, `--redact[=0..100]` (без значения = 100%),
`-c/--config`, `-i/--gitleaks-ignore-path` (файл или папка с `.gitleaksignore`),
`-b/--baseline-path`, `--exit-code` (по умолчанию 1 при находке),
`--log-opts` (только у `git`, проброс в `git log`, напр. `--log-opts="--all"`).

## Как НЕ надо

```sh
gitleaks detect --source .          # устаревшая команда
gitleaks git .                      # без --redact: секреты попадут в stdout и отчёт
gitleaks dir .                      # когда нужна история — dir её не видит, бери git
git add .sec/reports/               # отчёт содержит совпадения и строки, не коммить
```

- `--no-git` и `--source` на новых командах **не существуют** — это были опции
  `detect`. Файловое сканирование теперь отдельная команда `dir`.

## Чтение вывода

JSON-поля находки: `RuleID`, `Description`, `File`, `StartLine`/`EndLine`,
`Commit`, `Author`, `Date`, `Match`, `Secret` (пусто/маскировано при `--redact`),
`Entropy`, `Fingerprint`, `Tags`. **Fingerprint** = `commit:file:rule-id:line` —
стабильный идентификатор для подавления. SARIF: `runs[].results[]` с `ruleId`,
`message`, `locations[].physicalLocation` — кормит GitHub code scanning.

Триаж без раскрытия секрета: работай по маскированному отчёту и fingerprint,
файл/коммит смотри локально, никуда значение не вставляй. Живой ключ — **ротировать
у провайдера**: удалить строку/коммит мало, секрет остаётся в истории и клонах.

## Подавление ложных срабатываний

- `.sec/.gitleaksignore` — по одному fingerprint на строку (фича помечена как
  экспериментальная).
- Инлайн-комментарий `gitleaks:allow` на строке; `--ignore-gitleaks-allow`
  отключает это поведение.
- `.sec/gitleaks.toml`: `[extend]` (`useDefault` или `path`, взаимоисключающие;
  `disabledRules`), свои `[[rules]]`, аллоулисты `[[rules.allowlists]]` и
  глобальные `[[allowlists]]` (формы множественного числа — для 8.21.0+/8.25.0+,
  в 8.30.1 именно они).
- `--baseline-path` — разово принять большой существующий набор, не правя
  по одному fingerprint.

## Отчёты

Клади в `.sec/reports/` (добавь её в `.gitignore` проекта). Отчёт чувствителен,
обращайся с ним как с секретом.

## Доки

- https://github.com/gitleaks/gitleaks
