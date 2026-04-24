# Acceptance Checklist

Чек-лист что kit-board правильно установлен и работает. Пройдите сверху вниз после запуска `./install.sh`.

## Before Handoff

### Files installed in target repo

- [ ] `.github/workflows/board-automation.yml` существует
- [ ] `.github/workflows/issue-automation.yml` существует
- [ ] `.github/workflows/board-sanity.yml` существует
- [ ] `.github/workflows/docs-change-watcher.yml` существует
- [ ] `.github/workflows/cycle-time-metrics.yml` существует
- [ ] `.github/workflows/dependency-graph.yml` существует
- [ ] `.github/ISSUE_TEMPLATE/task.yml` существует
- [ ] `.github/ISSUE_TEMPLATE/bug_report.yml` существует
- [ ] `.github/ISSUE_TEMPLATE/feature_request.yml` существует
- [ ] `.github/ISSUE_TEMPLATE/found_work.yml` существует
- [ ] `.github/board/config.yml` существует (все `{{placeholders}}` заменены)
- [ ] `.github/board/README.md` существует
- [ ] `.github/board/USER-GUIDE.md` существует
- [ ] `.github/board/scripts/{setup-fields,backfill,audit}.sh` исполняемые (`chmod +x`)
- [ ] `.github/board/migrations/000-initial-from-kit.md` существует

### GitHub resources созданы

- [ ] **Labels** (минимум 15, можно больше):
  - `role:backend`, `role:frontend`, `role:auth`, `role:data-migration`, `role:ops`, `role:docs`
  - `этап:0` ... `этап:6`, `этап:none`
  - `task`, `found-work`
  - `blocked`, `docs:significant`, `docs:trivial`
  - `team-sync-overdue`, `board-audit`, `metrics-report`, `dependency-graph`
- [ ] **Project v2 custom fields** (6):
  - `Этап` (single-select, 8 опций)
  - `Зависит от` (text)
  - `Порядок` (number)
  - `🤖 Срочность` (single-select, 4 опции)
  - `⏱ Last moved` (date)
  - `📋 Действие` (single-select, 8 опций)
- [ ] **Status option** `🚫 Blocked` добавлена между Бэклог и К работе

### Config integrity

- [ ] `config.yml` — все placeholders `{{FOO}}` заменены на реальные значения
- [ ] `project.owner` совпадает с owner Project v2
- [ ] `project.number` совпадает с номером Project v2
- [ ] `roles.*.assignee` — валидные GitHub logins
- [ ] `field_aliases` присутствует (без него workflows не найдут поля)

### Secrets в target repo

- [ ] `PROJECT_TOKEN` — добавлен, имеет scope `project` (для workflow доступа к Project v2 API)
- [ ] _(опционально)_ `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID_TASKS` — если хотим уведомления

### Verify script

```bash
./verify.sh /path/to/target-repo
```

- [ ] Output: `✅ READY TO USE`
- [ ] Нет строк с ❌
- [ ] Warnings (если есть) понятны и обработаны

---

## Smoke test — первый issue

1. В target repo → Issues → New issue → шаблон **Задача** (task.yml)
2. Заполнить:
   - Title: `test(ops): kit-board smoke test`
   - Что нужно сделать: `Проверка работы автоматики`
   - Зачем: `Smoke test после установки`
   - Роль: `ops`
   - Этап: `0 — Infrastructure Bootstrap`
3. Submit

**Через 30-60 секунд проверить:**

- [ ] Issue получил labels `role:ops`, `этап:0`, `task`
- [ ] Assignee = ваш OPS_USER
- [ ] Issue появился на доске (Project v2)
- [ ] На карточке: `Status = 📋 К работе`, `Этап = Этап 0`
- [ ] `📋 Действие = ⚙️ Настроить` (derived из prefix `test(`/`ops(`)
- [ ] `🤖 Срочность = ⏳ Обычно` (никого не блокирует)
- [ ] `⏱ Last moved = сегодня`

Если всё выше ✅ — **smoke test прошёл**. Закройте test-issue.

Если ❌ — смотрите [TROUBLESHOOTING.md § Issue автоматика](TROUBLESHOOTING.md#issue-автоматика).

---

## Cascade unblock test (опционально, углублённый)

1. Создайте issue A через template (Role: ops, Этап: 0)
2. Создайте issue B через template (Role: ops, Этап: 0, Зависит от: `#A`)
3. Проверить на доске: B в колонке `🚫 Blocked`
4. Закрыть issue A
5. **Через 30-60 секунд** проверить: B в колонке `📋 К работе`
6. В issue B должен быть комментарий `@assignee — зависимость #A закрыта, задача разблокирована`

Если всё ✅ — cascade работает.

---

## What's Included

- [ ] Auto-assign по role-label
- [ ] Auto-populate 6 полей при создании issue
- [ ] Cascade unblock при закрытии зависимости
- [ ] Card aging tracker (weekly)
- [ ] Cycle time metrics (weekly, pinned)
- [ ] Dependency graph Mermaid (weekly, pinned)
- [ ] Sanity audit (weekly, pinned если gaps)
- [ ] Selective Telegram notifications (только 3 event types)
- [ ] 12 consistency rules в декларативном config.yml
- [ ] 4 issue templates с phased DoD support

## What's NOT Included (known limitations)

- [ ] Multi-repo / multi-project setup (один kit = один repo + один project)
- [ ] Slack/Discord integrations (только Telegram via workflow)
- [ ] Story points / velocity tracking (cargo-culted — не делаем для small teams)
- [ ] Sub-task hierarchy (GitHub's task-list достаточно)
- [ ] Native Jira/Linear import (команда создаёт issues заново через templates)

## Demo Scenarios

### 1. Новый участник получает задачу
1. Открывает доску → вкладку `Моя работа`
2. Видит Order 1 сверху
3. Открывает issue → читает body (с phased DoD если есть)
4. Создаёт ветку `git checkout -b feature/issue-42-foo` → статус автоматически → `🔨 В работе`

### 2. Зависимость разблокирована
1. Developer закрывает PR с `Closes #42`
2. Issue #42 → `🏁 Готово`
3. Через 30 сек: все issues, которые зависели от `#42` → `📋 К работе` автоматически
4. Assignees получают native GitHub notification

### 3. Weekly report
1. Понедельник 05:00 UTC → dependency graph обновляется
2. Понедельник 06:00 UTC → sanity audit
3. Пятница 16:00 UTC → cycle time metrics
4. Все три — pinned issues, команда видит изменения

---

## Final Sign-off

- [ ] Команда получила ссылку на target-repo `.github/board/USER-GUIDE.md`
- [ ] Как минимум один член команды создал live issue и получил auto-populated карточку
- [ ] Weekly reports включатся следующие понедельник/пятницу автоматически
- [ ] У ДИТ/Admin есть заготовленный план на случай миграции команды на другой инструмент (uninstall.sh)
