---
name: sec-audit-sbom
description: SBOM и сопоставление уязвимостей — syft строит состав компонентов (CycloneDX/SPDX), grype ищет по нему известные CVE. Пассивные команды, офлайн-БД grype и её устаревание, чтение совпадений, подавление .grype.yaml. Звать при словах "SBOM", "syft", "grype", "состав компонентов", или как шаг sec-audit-passive.
---

# SBOM: syft + grype (пассивно)

syft 1.54.0 и grype 0.120.0 в PATH профиля. syft составляет SBOM, grype ищет по
нему уязвимости. Это пара; осмысленно гонять их подряд.

## syft — состав компонентов

Каталогизирует пакеты по экосистемам (apk, dpkg, rpm, Go, Python, npm…) и рендерит
в SBOM. Уязвимости не ищет.

```sh
syft scan dir:. -o cyclonedx-json=.sec/reports/sbom.cdx.json
# несколько форматов разом:
syft scan dir:. -o cyclonedx-json=.sec/reports/sbom.cdx.json -o spdx-json=.sec/reports/sbom.spdx.json
```

Форматы: `syft-json`, `cyclonedx-json`, `cyclonedx-xml`, `spdx-json`,
`spdx-tag-value`, `github-json`, `syft-table`(деф), `template`. Источники:
`dir:`, `file:`, `registry:`, `docker:`, `oci-archive:` и др. Вывод в файл —
`-o <format>=<path>`. `dir:`/`file:` чисто локальны; `registry:` ходит в сеть.

Как НЕ надо: забыть `=path` (SBOM уйдёт в stdout и потеряется); гонять
`registry:`/образ в офлайне.

## grype — уязвимости по SBOM

```sh
grype sbom:.sec/reports/sbom.cdx.json -o json --file .sec/reports/json/grype.json
# или напрямую по дереву:
grype dir:. -o json --file .sec/reports/json/grype.json
```

Схемы источника: `sbom:`, `dir:`, `file:`, `docker:`, `registry:`, `purl:` и др.
Форматы: `json`, `table`, `cyclonedx`, `cyclonedx-json`, `sarif`, `template`.

**Внимание на источник:** `grype ./sbom.json` (без схемы) примет файл как
каталог, а не SBOM — нужна приставка `sbom:`.

### Офлайн-БД и её устаревание

grype качает свою БД. Ключи (env/конфиг): `GRYPE_DB_AUTO_UPDATE`(деф true),
`GRYPE_DB_CACHE_DIR`(~/.cache/grype/db), `GRYPE_DB_VALIDATE_AGE`(деф true),
`GRYPE_DB_MAX_ALLOWED_BUILT_AGE`(деф 120h). Офлайн: заранее `grype db update`,
затем `GRYPE_DB_AUTO_UPDATE=false`. **Грабли:** с выключенным авто-апдейтом и
`validate-age=true` БД старше 120h отвергается; на старой БД аудит молча
пропускает свежие CVE — обновляй по расписанию.

### Чтение вывода

JSON `matches[]`: `vulnerability{id, severity, cvss, fix{versions,state}}`,
`artifact{name, version, type, locations, purl}`, `matchDetails{type, matcher,
searchedBy}` (почему совпало). Игнорённые уходят в `ignoredMatches[]`.
Доверие: `exact-direct-match`/`exact-indirect-match` — высокое; `cpe-match`
склонен к ложным, проверяй руками. Severity: negligible/low/medium/high/critical.

### Подавление

`.grype.yaml` (порядок: `./.grype.yaml` → `~/.grype.yaml` → XDG). Секция
`ignore:` (совпадает, когда ВСЕ критерии сошлись): `vulnerability`(id),
`fix-state`, `package{name,version,type,location}`. Гейт
`fail-on-severity`/`GRYPE_FAIL_ON_SEVERITY` — для пассивного аудита **не ставь**
(пусть просто отчитывается).

## Как это сочетается с trivy

trivy ([[sec-audit-trivy]]) тоже делает SCA и SBOM. syft+grype берут, когда нужен
отдельный переносимый SBOM (CycloneDX/SPDX для комплаенса) и второе мнение по CVE
на его основе. Дубли с trivy/osv нормальны — сведи их на триаже.

## Отчёты

`.sec/reports/`, в `.gitignore`.

## Доки

- https://github.com/anchore/syft , https://oss.anchore.com/docs/reference/syft/cli/
- https://github.com/anchore/grype , https://oss.anchore.com/docs/reference/grype/configuration/
- https://oss.anchore.com/docs/guides/vulnerability/interpreting-results/
