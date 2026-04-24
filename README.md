# kit-board

> GitHub Projects v2 board automation starter kit — part of OpenClaw delivery pipeline.

Превращает пустой GitHub Project v2 в полностью автоматизированный kanban.

## Что умеет (13 возможностей)

1. **Сама ставит исполнителя.** По labelам `role:backend`/`role:frontend`/... задача назначается нужному человеку.
2. **Сама заполняет 6 полей на карточке** (Этап, Зависит от, Порядок, Срочность, Действие, Last moved) — при создании.
3. **Сама разблокирует цепочку.** Закрыл задачу → все её зависимые автоматически в "К работе", исполнители уведомлены.
4. **Подсвечивает застрявшие карточки.** В работе >5 дней — жёлтый, >10 — красный. Blocked >3 дней — красный.
5. **Уведомляет только по делу** (3 типа): "тебе назначена задача", "просят ревью", "твоя задача разблокирована". Без спама.
6. **Каждую пятницу — отчёт скорости команды.** Медианный и p90 cycle time, throughput, top-5 outliers. В pinned issue.
7. **Каждый понедельник — карта зависимостей.** Mermaid-граф всех открытых задач + критический путь + bottlenecks.
8. **Каждый понедельник — аудит доски.** Проверяет целостность: без assignee, без role, рассинхрон полей, aging.
9. **Поддерживает фазы выполнения.** В issue template — "Могу делать сейчас" и "Требует инфры". Никаких монолитных DoD.
10. **Сама определяет тип работы.** По Conventional Commits префиксу (`feat:`, `fix:`, `docs:`, `ops:`) — 8 типов Действия.
11. **Сама считает срочность.** Чем больше задач ждут эту — тем выше. 🔥 / ⚡ / ⏳ / 🟢. Обновляется автоматически.
12. **Сама дорисовывает скрытые зависимости.** По архитектурным паттернам: backend Этапа 1+ → auth, frontend → backend, и т.д.
13. **Ловит блокеры в тексте.** Сканирует body на "ждём", "blocked by", "нужен от" — если найдено без формального `Зависит от` → комментарий-напоминание.

Под капотом: **13 consistency rules** в декларативном `config.yml`, **6 workflows**, **18 auto-actions**. Отключается одной командой.

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
