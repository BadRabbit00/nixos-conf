---
name: sec-audit-sec-scan
description: Как гонять общий гейт sec-scan — один прогон gitleaks+semgrep+bandit+trivy+osv+syft с отчётами SARIF/JSON и кодом выхода. Это первый проход пассивного аудита и то же, что крутится в CI. Звать при словах "sec-scan", "быстрый прогон", "гейт", "пройдёт ли CI".
---

# sec-scan — общий гейт (первый проход)

`sec-scan` в общем PATH. Один вызов запускает связку сканеров и ставит код
выхода — удобно начать пассивный аудит и проверить, пройдёт ли CI. Это тот же
инструмент, что в CI-воркфлоу (github.com/BadRabbit00/badrabbit-sec-scan).

## Что внутри

gitleaks (секреты, вся история) · semgrep + bandit (SAST) · trivy vuln+misconfig
(зависимости и IaC) · osv-scanner (второе мнение по зависимостям) · syft (SBOM).
Подробности каждого — в [[sec-audit-gitleaks]], [[sec-audit-semgrep]],
[[sec-audit-bandit]], [[sec-audit-trivy]], [[sec-audit-sca]], [[sec-audit-sbom]].

## Команды

```sh
sec-scan .                                  # порог high, отчёты в .sec/reports
sec-scan --fail-on critical .               # мягче: падать только на CRITICAL
sec-scan --skip sbom,iac .                  # пропустить проверки
sec-scan --no-history .                     # gitleaks только по дереву, без git-истории
sec-scan -o .sec/reports .                  # явная папка отчётов
```

Порог: `--fail-on critical|high|medium|none` (деф high; секреты валят всегда,
кроме `none`). Пропуск: `--skip secrets,sast,deps,iac,sbom`.
Коды выхода: `0` чисто, `1` находки на уровне порога и выше, `2` сканер упал.

## Проектные настройки `.sec/`

sec-scan сам подхватывает из `.sec/` цели: `semgrep/*.yaml` (свои правила),
`gitleaks.toml`, `.gitleaksignore`, `.trivyignore`. Свой набор правил semgrep —
`SEC_SCAN_SEMGREP_CONFIG="p/default ./rules"`.

## Отчёты

`.sec/reports/summary.md` (таблица находок и вердикт), `sarif/*.sarif` (для
GitHub code scanning), `json/*.json`, `sbom.cdx.json`. Папку добавь в `.gitignore`
проекта.

## Как это ложится в аудит

`sec-scan` — быстрый первый проход: он охватывает секреты, SAST, SCA, IaC, SBOM
за один вызов. Дальше по находкам углубляйся прицельными инструментами (их скиллы
выше) и ручным ревью горячих мест. План целиком — [[sec-audit-passive]].

## Доки

- https://github.com/BadRabbit00/badrabbit-sec-scan
