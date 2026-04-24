# Board Module — GitHub Project Automation

> **Назначение:** всё, что касается конфигурации GitHub Project (доски задач) и
> её автоматизации, живёт в этой папке. Доска — **подключаемый инструмент**,
> не часть бизнес-логики проекта.

**Доска:** 🏗 [COCRealty Board](https://github.com/orgs/COCRealty-Devops/projects/1)

## Быстрые ссылки

- 📋 **[USER-GUIDE.md](USER-GUIDE.md)** — полное руководство пользователя (views, поля, жизненный цикл, FAQ)
- 📐 **[ADR-010 Project Board Architecture](../../docs/adrs/010-project-board-architecture.md)** — архитектурное решение
- 📜 **[migrations/](migrations/)** — история изменений модуля (каждая миграция документирует решённую проблему)
- ⚙️ **[config.yml](config.yml)** — единый source-of-truth (правила, поля, роли, этапы)

## Структура папки

```
.github/board/
├── README.md                 ← этот файл (обзор модуля)
├── USER-GUIDE.md             ← руководство для команды
├── config.yml                ← единый source-of-truth
├── scripts/                  ← idempotent setup/audit/backfill
│   ├── setup-fields.sh       ← создание полей + labels (запускать один раз)
│   ├── backfill.sh           ← миграция существующих issues
│   └── audit.sh              ← ручной audit (обычно не нужен — есть weekly cron)
└── migrations/               ← история изменений модуля
    ├── 000-initial-structure.md
    ├── 001-initial-setup-and-backfill.md
    ├── 002-team-sync-enforcement.md
    ├── 003-status-label-consistency.md
    ├── 004-consistency-rules-engine.md
    ├── 005-populate-readonly-for-initialized.md
    ├── 006-urgency-field-and-russian-aliases.md
    ├── 007-role-assignee-mismatch-audit.md
    ├── 008-card-aging-and-ux-polish.md
    ├── 009-phased-dod-template.md
    ├── 010-action-type-auto-derive.md
    └── 011-pro-metrics-and-cleanup.md
```

## Разделение ответственности

| Путь | Почему здесь | Можно ли вынести |
|---|---|---|
| `.github/workflows/*.yml` (6 файлов) | GitHub требует workflows в `.github/workflows/` | ❌ нет |
| `.github/ISSUE_TEMPLATE/*.yml` (4 файла) | GitHub требует templates в `.github/ISSUE_TEMPLATE/` | ❌ нет |
| `.github/board/config.yml` | Параметры: role→user, stage→id, правила консистентности | ✅ единственный источник правды |
| `.github/board/scripts/` | API-операции, миграции, audit | ✅ |
| `.github/board/USER-GUIDE.md` | Руководство для команды | ✅ |
| `docs/adrs/010-*.md` | Архитектурное решение | ✅ в общей структуре ADR |

Workflow резолвит имена полей через `config.field_aliases` — **никаких
захардкоженных GraphQL IDs**. Это делает модуль self-healing: если поле
пересоздадут через UI, автоматика продолжит работать.

## Контракт «как отключить доску»

Если проект перейдёт на другой инструмент (Jira, Linear):

```bash
# 1. Удалить модуль
rm -rf .github/board/

# 2. Удалить workflows модуля (6 файлов)
rm .github/workflows/issue-automation.yml
rm .github/workflows/board-sanity.yml
rm .github/workflows/docs-change-watcher.yml
rm .github/workflows/cycle-time-metrics.yml
rm .github/workflows/dependency-graph.yml
# (оставить только board-automation.yml — он baseline pre-module)

# 3. Убрать dropdown-поля из issue templates
# (Role, Этап, Зависит от — вручную из .github/ISSUE_TEMPLATE/*.yml)

# 4. Удалить GitHub Project через UI (Projects → Settings → Delete)
```

Всё остальное в репозитории продолжает работать. Основной код проекта,
CI, документация, другие workflows **не зависят** от этого модуля.

## Воркфлоу-файлы (6 штук)

Полное описание — см. [USER-GUIDE.md § 7](USER-GUIDE.md#7-автоматизация--что-работает-без-тебя).

| Workflow | Триггеры | Назначение |
|---|---|---|
| `board-automation.yml` | branch/PR events | Двигает Status по колонкам |
| `issue-automation.yml` | issues.*, PR, schedule, dispatch | 5 jobs: assign, populate, cascade-unblock, enforce-consistency, notify |
| `board-sanity.yml` | Monday 06:00 UTC | Weekly audit → pinned issue |
| `docs-change-watcher.yml` | PR closed в docs/** | Team-sync enforcement |
| `cycle-time-metrics.yml` | Friday 16:00 UTC | Weekly metrics → pinned issue |
| `dependency-graph.yml` | Monday 05:00 UTC | Weekly Mermaid graph → pinned issue |

## Для новых участников

1. Прочитать [USER-GUIDE.md](USER-GUIDE.md) (10 минут)
2. Открыть [доску](https://github.com/orgs/COCRealty-Devops/projects/1) → вкладку «Моя работа»
3. Готово

## Владелец

**@fruitart-code** (A-role на весь модуль по CODEOWNERS).

Все pipeline-sensitive изменения (новое поле, правило, workflow) требуют review @fruitart-code и записи в `migrations/`.

## История

Полная хронология — [migrations/](migrations/). Краткая сводка:

| Дата | Что |
|---|---|
| 2026-04-23 | 000-007 — первая волна: модуль + team-sync + consistency engine + инциденты downgrade/readonly |
| 2026-04-23 | 008 — card aging + selective notifications |
| 2026-04-24 | 009-011 — phased DoD + 📋 Действие + cycle time metrics + dependency graph + cleanup 4 неиспользуемых полей |
