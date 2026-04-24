# kit-board

> GitHub Projects v2 board automation starter kit — part of OpenClaw delivery pipeline.

Превращает пустой GitHub Project v2 в полностью автоматизированный kanban с:

- **Auto-assign** по role-label → assignee маппингу
- **Dependency tracking** с cascade unblock при закрытии зависимостей
- **Auto-computed** 🤖 Срочность (по количеству блокируемых задач) и 📋 Действие (из Conventional Commits префикса)
- **Card aging** — красные/жёлтые флаги для застрявших задач
- **Weekly reports** в pinned issues: cycle time metrics, dependency graph, sanity audit
- **Phased DoD** в issue templates (разделение офлайн-scope и infra-dependent)
- **Selective notifications** (3 event types только, no spam)

**12 consistency rules** в decorative `config.yml`, **6 workflows**, **18 auto-actions** без участия человека.

## Quick Start

```bash
git clone https://github.com/fruitart-code/kit-board.git
cd kit-board
cp .env.example .env
# Заполни .env (см. INSTALL.md для подробностей)
./install.sh /path/to/your-target-repo
./verify.sh /path/to/your-target-repo
```

После install — коммит изменений в target repo. Первый issue созданный через шаблон — сразу с auto-populated полями.

## Для AI-агента

Если у вас есть AI-agent (Claude Code, Cursor, etc.) — дайте ему [`AGENT-PROMPT.md`](AGENT-PROMPT.md). Агент развернёт kit самостоятельно в 5-10 минут.

## Документация

| Документ | Когда читать |
|---|---|
| **[INSTALL.md](INSTALL.md)** | Подробная инструкция установки (manual шаги, .env, troubleshooting common issues) |
| **[AGENT-PROMPT.md](AGENT-PROMPT.md)** | Готовый промпт для AI-агента, который развернёт kit за вас |
| **[ACCEPTANCE_CHECKLIST.md](ACCEPTANCE_CHECKLIST.md)** | Чек-лист что kit работает после установки |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | 15+ сценариев что делать если что-то не работает |
| **[CUSTOMIZATION.md](CUSTOMIZATION.md)** | Как адаптировать под свою команду (роли, этапы, правила) |
| **[templates/.github/board/USER-GUIDE.md](templates/.github/board/USER-GUIDE.md)** | Руководство пользователя (это файл пользователи target-репо будут читать) |

## Что внутри

```
kit-board/
├── install.sh                  ← bootstrap — одна команда
├── verify.sh                   ← проверка установки
├── uninstall.sh                ← rollback
├── .env.example                ← переменные для настройки
├── bootstrap/                  ← 7 step-by-step скриптов
└── templates/                  ← копируется в target repo
    ├── .github/
    │   ├── workflows/          ← 6 workflow-файлов
    │   ├── ISSUE_TEMPLATE/     ← 4 templates
    │   └── board/
    │       ├── config.yml      ← с {{placeholders}} — заполнит install
    │       ├── README.md
    │       ├── USER-GUIDE.md
    │       ├── scripts/
    │       └── migrations/
    └── docs/adrs/
        └── TEMPLATE-project-board-architecture.md
```

## Требования (prerequisites)

- **`gh` CLI** (≥ 2.40)
- **Python 3.10+** с `pyyaml`
- **Bash 4+**
- **GitHub Personal Access Token** с правами: `repo`, `project`, `admin:org` (последнее — если проект принадлежит org)
- **GitHub Project v2** уже создан в target org/user

Полный чек-лист prerequisites — [INSTALL.md § 1](INSTALL.md#1-prerequisites).

## Совместимость

- GitHub.com (на GHES не тестировалось)
- GitHub Projects v2 API (GraphQL)
- Single-repo проекты (один репо ↔ один project)

Для multi-repo / multi-project — требуется адаптация config.yml.

## Отличия от других kit-*

| Aspect | kit-* (типичный) | kit-board |
|---|---|---|
| Цель | Сам код/приложение | Инфраструктура **вокруг** кода |
| Что ставится | Докер + src + tests | Workflow-файлы + project v2 config |
| Requires | Docker | gh CLI + Project v2 созданный |
| Идемпотентно | По большей части | Полностью (install.sh можно запускать много раз) |

## Контракт «как удалить»

Один скрипт:

```bash
./uninstall.sh /path/to/your-target-repo
```

Удаляет:
- `.github/board/` целиком
- `.github/workflows/{issue-automation,board-automation,board-sanity,docs-change-watcher,cycle-time-metrics,dependency-graph}.yml`
- Labels `role:*`, `этап:*`, `blocked`, `docs:significant`, `docs:trivial`, и т.д.
- Project fields (optional, с подтверждением — потеря данных!)

## License

MIT © @fruitart-code, 2026

## Feedback

Открой issue в этом репо если нашёл баг или хочешь feature.
