---
name: sec-audit-trivy
description: Универсальный сканер trivy для пассивного аудита — уязвимости в зависимостях, мисконфиги IaC (Dockerfile, k8s, Terraform, Helm), секреты, лицензии, SBOM. Какие сканеры включены по умолчанию, вывод JSON/SARIF/CycloneDX, подавление .trivyignore. Звать при словах "trivy", "уязвимости зависимостей", "IaC", "Dockerfile/k8s/terraform", или как шаг sec-audit-passive.
---

# trivy — универсальный сканер (пассивно)

trivy 0.74.0 в PATH профиля. `trivy fs <path>` гоняет четыре сканера, выбор —
`--scanners` (через запятую). По первому проходу это ядро `sec-scan`
([[sec-audit-sec-scan]]); этот скилл — чтобы гонять trivy прицельно.

## Что проверяет (`trivy fs`)

| Сканер | `--scanners` | По умолчанию в fs | Что | Нужно |
|---|---|---|---|---|
| Уязвимости | `vuln` | **вкл** | CVE в зависимостях | поддерживаемый lock/manifest; БД качается при первом запуске |
| Секреты | `secret` | **вкл** | хардкод-ключи (регулярки) | ничего |
| Мисконфиг | `misconfig` | **выкл** | IaC-мисконфиги | сырые IaC-файлы; проверки встроены (офлайн) |
| Лицензии | `license` | **выкл** | лицензии пакетов | метаданные зависимостей |

Дефолт fs = `vuln,secret`. `misconfig` и `license` включай явно.
Lock-файлы для vuln (fs): `requirements.txt`/`poetry.lock`/`Pipfile.lock`/`uv.lock`,
`package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`, `go.mod`, `Cargo.lock`,
`pom.xml`/`gradle.lockfile`, `composer.lock`, `Gemfile.lock` и др. **Нет lock-файла —
нет результатов по зависимостям.** Мисконфиг-типы: Dockerfile, Kubernetes,
Terraform, CloudFormation, Azure ARM, Helm (docker-compose в доках 0.74 как тип
мисконфига **не подтверждён**).

## Команды

```sh
# полный пассивный проход: деп + IaC + секреты, JSON
trivy fs --scanners vuln,misconfig,secret --format json --output .sec/reports/json/trivy.json .
# JSON -> SARIF без повторного скана
trivy convert --format sarif --output .sec/reports/sarif/trivy.sarif .sec/reports/json/trivy.json
# только IaC
trivy config ./infra
# SBOM (CycloneDX); с уязвимостями — добавить --scanners vuln
trivy fs --format cyclonedx --output .sec/reports/sbom.cdx.json .
# скан готового SBOM
trivy sbom .sec/reports/sbom.cdx.json
# гейт по severity (для CI фиксируй явно)
trivy fs --severity HIGH,CRITICAL --scanners vuln,misconfig,secret --exit-code 1 .
```

Форматы: `table`(деф), `json`, `sarif`, `github`, `template`, `cyclonedx`,
`spdx`, `spdx-json`. `--format cyclonedx` **отключает** секьюрити-скан, если не
добавить `--scanners vuln`. Шум: `--ignorefile .sec/.trivyignore`,
`--skip-dirs "vendor,node_modules"`, `--skip-files`, `--ignore-unfixed`.
Офлайн: `--skip-db-update --skip-java-db-update --skip-check-update` (БД заранее
`--download-db-only`), `--offline-scan`, `--db-repository` (свой mirror).

## Как НЕ надо

```sh
trivy fs .                                  # misconfig выключен — IaC не проверится
trivy fs --format cyclonedx .               # ждать уязвимостей: скан выключен без --scanners vuln
trivy fs --skip-db-update .                 # без ранее скачанной БД — пустой результат
```
- Мисконфигу нужны **сырые** IaC-файлы, не rendered-состояние.
- Для гейта фиксируй `--severity HIGH,CRITICAL`, не тони в LOW/UNKNOWN.

## Чтение вывода

JSON: `Results[]{Target, Class, Type, Vulnerabilities[], Misconfigurations[],
Secrets[], Licenses[]}`.
- Vuln: `VulnerabilityID, PkgName, InstalledVersion, FixedVersion, Severity,
  Status`. **Нет `FixedVersion` = фикса нет** (кандидат под `--ignore-unfixed`).
- Misconfig: AVD-id (напр. `AVD-DS-0002`), `Severity`, `Resolution`, `CauseMetadata`.
- Secret: rule id, `Category`, `Severity`, `Match`, строка.

**Reachability trivy НЕ делает.** CVE означает «уязвимая версия присутствует», не
«уязвимый путь вызывается». Severity = из CVSS, не эксплуатируемость в этом репо.
Достижимость оценивай руками.

## Подавление

- `.trivyignore` (или `--ignorefile`): по одному id на строку (CVE, AVD, secret-rule),
  `#` комментарии, опционально `CVE-xxxx exp:2026-01-01`.
- `.trivyignore.yaml` (экспериментально, через `--ignorefile`): секции
  `vulnerabilities`/`misconfigurations`/`secrets`/`licenses`, по записи `id`
  (+ опц. `paths`, `purls`, `expired_at`, `statement`).
- Инлайн для IaC: `#trivy:ignore:AVD-GCP-0051` строкой перед ресурсом (Terraform,
  CFN, Helm, Dockerfile).
- `trivy.yaml` (`-c/--config`): ключи под `report:` (`format`, `output`,
  `severity`, `exit-code`), `scan.scanners`, `vulnerability.ignore-unfixed`.

## Отчёты

`.sec/reports/`, в `.gitignore`.

## Доки

- https://trivy.dev/latest/docs/target/filesystem/
- https://trivy.dev/latest/docs/configuration/filtering/
- https://trivy.dev/latest/docs/scanner/misconfiguration/
- https://trivy.dev/latest/docs/advanced/air-gap/
