---
name: sec-audit-sca
description: Аудит уязвимостей в зависимостях (SCA) нативными аудиторами по экосистемам — osv-scanner (все сразу), pip-audit (Python), cargo-audit (Rust), npm audit (Node). Какие нужны lock-файлы, безопасные пассивные команды, что НЕ трогать (fix мутирует, pip-audit может исполнить код). Звать при словах "зависимости", "CVE в библиотеках", "SCA", "requirements/Cargo.lock/package-lock".
---

# SCA — уязвимости в зависимостях (пассивно)

Все четыре в PATH профиля. SCA смотрит версии зависимостей против баз advisory,
исходный код не анализирует. Для первого прохода по всему репозиторию проще
`sec-scan` ([[sec-audit-sec-scan]]) — он гоняет trivy+osv. Эти — для глубины по
конкретной экосистеме.

**Общее правило: ничего не чиним.** `npm audit fix`, `cargo audit fix`,
`pip-audit --fix` **меняют** дерево зависимостей — в пассивном аудите запрещены.

## osv-scanner 2.5.1 — все экосистемы разом

Одним прогоном: npm, PyPI, Go, Maven/Gradle, Cargo, RubyGems, NuGet, Composer и др.
База OSV (агрегирует GHSA, PYSEC, RUSTSEC…). Источник не меняет.

```sh
osv-scanner scan source -r --format json --output .sec/reports/json/osv.json ./project
osv-scanner scan source -r --format sarif --output .sec/reports/sarif/osv.sarif ./project
```

Коды выхода: `0` пакеты есть, уязвимостей нет; `1` есть уязвимости; `127` общая
ошибка; **`128` не найдено пакетов для сканирования** (нет поддерживаемого
lock-файла). 128 — это НЕ «чисто», это «нечего было смотреть»: дай настоящий
lock-файл или `-r`.

JSON: `results[].packages[]` → `package{name,version,ecosystem}`,
`vulnerabilities[]` (OSV: `id`, `aliases` с CVE, `severity`, фиксы в
`affected[].ranges`), `groups[].max_severity` (дедуп алиасов).
Подавление: `--config osv-scanner.toml`, `[[IgnoredVulns]]` (`id`, `ignoreUntil`,
`reason`). Офлайн: `--offline-vulnerabilities` + заранее `--download-offline-databases`.

## pip-audit 2.10.1 — Python ⚠️

**Опасность:** `pip-audit -r requirements.txt` по умолчанию резолвит и **может
ставить** пакеты в изолированный venv — то есть исполнить код проекта. Доки прямо:
«If you wouldn't `pip install` it, you should not `pip audit` it». Для чужого кода
так нельзя.

Безопасно (без резолва и установки):

```sh
pip-audit -r requirements.txt --no-deps -f json -o .sec/reports/json/pip-audit.json
# если в файле есть хэши — строже:
pip-audit -r requirements.txt --no-deps --disable-pip --require-hashes -f json -o .sec/reports/json/pip-audit.json
```

`--no-deps` требует точных пинов и смотрит только перечисленное (без транзитивных).
Либо аудит уже установленного окружения внутри devShell проекта (установки не
происходит): `pip-audit -l -f json`. Форматы: `columns`(деф), `json`, `cyclonedx-json`,
`markdown`. JSON: `dependencies[]{name,version,vulns[]{id,fix_versions,aliases}}`.
Подавление: `--ignore-vuln ID` (повторяемый). `--desc`/`--aliases` — описания и CVE.

Плохо:
```sh
pip-audit -r requirements.txt          # резолвит и может исполнить код проекта
pip-audit --fix                        # мутирует
```

## cargo-audit 0.22.2 — Rust

База RustSec. Нужен `Cargo.lock`. Без него `cargo audit` сам запускает
`cargo update` (fetch/мутация) — для чужого кода указывай lock явно и запускай
**вне** каталога проекта.

```sh
cargo-audit audit --file path/to/Cargo.lock --json > .sec/reports/json/cargo-audit.json
```

Бинарь зовём `cargo-audit audit` (не `cargo audit` — cargo в PATH профиля нет).
Флаги (проверено `--help`): `-f/--file`, `--json`, `-D/--deny <kind>`,
`--ignore RUSTSEC-YYYY-NNNN`, `-n/--no-fetch`, `--stale`. JSON:
`vulnerabilities.list[]{advisory{id,aliases,cvss},versions.patched,package}`,
`warnings` (unmaintained/unsound/yanked — отдельная категория, не равна уязвимости).
Конфиг `audit.toml` (`[advisories] ignore`, `severity_threshold`).

## npm audit — Node

Нужен `package-lock.json`. **Ходит в реестр** (шлёт описание дерева), офлайна нет.
Гоняй из devShell проекта (нужен проектный node, свой в профиль не кладём).

```sh
npm audit --json --omit=dev > .sec/reports/json/npm-audit.json
```

`--omit=dev` убирает dev-зависимости; `--audit-level <info|low|moderate|high|critical>`
— порог ненулевого кода выхода. JSON: `vulnerabilities{<pkg>{severity,via[],range,
fixAvailable}}`, `metadata.vulnerabilities` — счётчики. `via[]` строкой = транзитивная,
объектом = прямая advisory. Персональной игноры в `npm audit` нет: фикс транзитивной
версии — через `overrides` в package.json.

Плохо:
```sh
npm audit fix            # мутирует package.json и lock, ставит заново
npm audit fix --force    # ещё и ломающие мажоры
```

## Отчёты

`.sec/reports/`, в `.gitignore`.

## Доки

- https://google.github.io/osv-scanner/
- https://github.com/pypa/pip-audit
- https://github.com/rustsec/rustsec/tree/main/cargo-audit
- https://docs.npmjs.com/cli/v11/commands/npm-audit
