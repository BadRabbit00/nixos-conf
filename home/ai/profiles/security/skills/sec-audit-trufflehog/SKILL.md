---
name: sec-audit-trufflehog
description: Как искать секреты инструментом trufflehog при пассивном аудите, НЕ отправляя найденные ключи провайдерам. Verification включена по умолчанию и шлёт секреты в сеть — всегда --no-verification. Детекторы, команды, чтение JSON. Звать как второе мнение по секретам после gitleaks или при слове "trufflehog".
---

# trufflehog — поиск секретов (второе мнение, строго офлайн)

trufflehog 3.99.2 в PATH профиля. Дополняет gitleaks ([[sec-audit-gitleaks]]):
700+ провайдер-специфичных детекторов вместо чистых регулярок.

## ⚠️ Главное про безопасность

По умолчанию trufflehog **верифицирует** каждый кандидат — делает живой
API-запрос провайдеру (AWS, GitHub и т. д.), чтобы проверить, рабочий ли ключ.
Для чужого/клиентского репозитория это **утечка секретов третьим лицам**.

- `--no-verification` — выключает проверку. **Обязателен** в пассивном аудите.
- `--results=verified` только **фильтрует вывод**, сетевые вызовы при этом
  всё равно идут. Безопасность даёт именно `--no-verification`, не `--results`.

Верификацию включай только с отдельного явного разрешения Архитектора.

## Что проверяет

- Детекторы под конкретных провайдеров (не энтропия). Каждое совпадение
  привязано к провайдеру.
- Источники, нужные здесь: `git file://...` (история) и `filesystem <paths>`.
  Локальный git клонируется во временный каталог (если нет `--trust-local-git-config`).

## Команды (строго без сети к провайдерам)

История, без верификации, JSON:

```sh
trufflehog git file://. --no-verification --json > .sec/reports/json/trufflehog.json
```

Файлы без git:

```sh
trufflehog filesystem path/to/dir --no-verification --json > .sec/reports/json/trufflehog.json
```

Исключить пути (файл с регулярками, по одной на строку):

```sh
trufflehog git file://. --no-verification --json -x .sec/th-exclude.txt
```

Флаги (из исходника main.go): `--no-verification`, `-j/--json`, `--results`
(`verified`/`unknown`/`unverified`/`filtered_unverified`), `--fail` (код выхода
183 при находке), `--include-detectors`/`--exclude-detectors`. У `git`:
`-i/--include-paths`, `-x/--exclude-paths` (оба — **файл** с регулярками),
`--since-commit`, `--branch`, `--max-depth`. У `filesystem`: те же `-i/-x`.

## Как НЕ надо

```sh
trufflehog git file://.                      # без --no-verification: шлёт ключи провайдерам
trufflehog git file://. --results=verified   # НЕ отключает сеть, только прячет вывод
trufflehog filesystem . --directory .        # --directory устарел, путь — позиционным аргументом
trufflehog git file://. --since-commit X     # для полного аудита не сужай историю
```

## Чтение вывода

JSON-поля: `SourceMetadata` (файл/коммит/строка), `SourceType`, `DetectorType`,
`DetectorName`, `DecoderName`, `Verified` (bool), `Raw` (само значение секрета!),
`Redacted`, `ExtraData`. При `--no-verification` `Verified` будет пустым —
находки идут как `unverified`/`unknown`, это нормально.

Встроенной маскировки `Raw` нет, поэтому отчёт чувствителен: триаж веди по
`SourceMetadata`, значение `Raw` никуда не вставляй, в отчёт для Архитектора
не копируй. Живой ключ — ротировать у провайдера.

## Подавление

- Область: `-i/-x` (файлы с регулярками), `--exclude-detectors` для шумных
  детекторов.
- Фингерпринт-игнора в стиле gitleaks у trufflehog нет. Базлайн делают снаружи
  (diff результатов) или `--since-commit` для новых коммитов. Отдельный
  allowlist-флаг для 3.99.x — **не подтверждён** в доках.

## Отчёты

`.sec/reports/`, в `.gitignore`. Обращаться как с секретом (внутри `Raw`).

## Доки

- https://github.com/trufflesecurity/trufflehog (README + main.go)
- https://docs.trufflesecurity.com/
