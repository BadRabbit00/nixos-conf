---
name: sec-audit-bandit
description: SAST для Python инструментом bandit — типовые ошибки по AST (eval, pickle, subprocess shell=True, слабые хеши, yaml.load). Пороги severity/confidence, вывод JSON, подавление # nosec. Звать для Python-проектов при словах "bandit", "питон небезопасный", или как шаг sec-audit-passive.
---

# bandit — SAST для Python (пассивно)

bandit (установлен как 1.9.4) в PATH профиля. Строит AST каждого файла и гоняет
плагины. Только Python. Семантику потока данных не делает — дополняет semgrep
([[sec-audit-semgrep]]), не заменяет.

## Что проверяет

Плагины с id `Bxxx`: B1xx разное, B2xx мисконфиг фреймворков (напр. B201
flask debug), B3xx/B4xx чёрные списки вызовов/импортов, B5xx крипта, B6xx
инъекции, B7xx XSS. У каждой находки — **severity** (влияние) и **confidence**
(уверенность), оба LOW/MEDIUM/HIGH.

## Команды

Сигнал-прежде-всего (отсечь LOW-шум), JSON:

```sh
bandit -r . --severity-level medium --confidence-level medium \
  -x ./tests,./.venv,./migrations -f json -o .sec/reports/json/bandit.json
```

Полный проход (все уровни):

```sh
bandit -r . -f json -o .sec/reports/json/bandit.json
```

Флаги: `-r/--recursive` (и только в нём авто-читается `.bandit`),
`-f {csv,html,json,screen,txt,xml,yaml,sarif}` (sarif есть в man, но в твоей
сборке проверь `bandit -f sarif --help`), `-o/--output`,
`-l/-ll/-lll` или `--severity-level {all,low,medium,high}`,
`-i/-ii/-iii` или `--confidence-level {...}`, `-s/--skip` и `-t/--tests`
(id через запятую), `-x/--exclude` (глобы через запятую),
`-c/--configfile` (YAML или `pyproject.toml [tool.bandit]`), `-b/--baseline`
(diff, только JSON-отчёты).

## Как НЕ надо

```sh
bandit .                      # без -r не рекурсивно и не читает .bandit
bandit -r .                   # без порогов и -x: тонешь в LOW (B101 assert в тестах)
bandit -r . --exit-zero       # в гейте никогда не упадёт
```
- bandit не читает `.gitignore` — исключения только через `-x`.
- В INI ключ путей `exclude`, в YAML/TOML — `exclude_dirs` (не путать).

## Чтение вывода

JSON `results[]{filename, line_number, test_id (напр. B602), test_name,
issue_severity, issue_confidence, issue_text, issue_cwe, code, line_range}`,
плюс `metrics` (счётчики) и `errors[]` (непарсибельные файлы — читать).
Код выхода: по умолчанию `1` при находках на уровне порога, `0` если чисто.
Триаж первым: **HIGH confidence + HIGH/MEDIUM severity** (B602 subprocess
`shell=True`, B608 сборка SQL строкой, B303/B324 слабые хеши, B301/B506
небезопасная десериализация / `yaml.load`). Обычные ложные: LOW confidence,
B101 assert в тестах, B404/B603 (subprocess без shell и с константами).

## Подавление

- Инлайн `# nosec` — глушит всё на строке; точечно `# nosec B602,B607` или
  `# nosec assert_used`. `--ignore-nosec` отключает уважение к `# nosec`.
- Конфиг: `.bandit` INI `[bandit]` (`exclude`, `skips`, `tests`, `targets`);
  `bandit.yaml` через `-c` (`exclude_dirs`, `skips`, `tests`); `pyproject.toml`
  `[tool.bandit]`. Семантика: только `tests` → лишь они; только `skips` → все
  кроме них; оба → `tests` минус `skips`.
- Пороги `-ll -ii` (или длинные формы) — главный регулятор шума.

## Отчёты

`.sec/reports/`, в `.gitignore`. Запускать из devShell проекта, если bandit не
в профиле проекта (в agy-sec он есть).

## Доки

- https://bandit.readthedocs.io/en/latest/config.html
- https://bandit.readthedocs.io/en/latest/man/bandit.html
- https://bandit.readthedocs.io/en/latest/plugins/index.html
