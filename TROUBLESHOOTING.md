# TROUBLESHOOTING

Частые проблемы при установке и использовании kit-board. Решения — в порядке вероятности.

## Содержание

- [Prerequisites / gh CLI](#prerequisites--gh-cli)
- [Install script errors](#install-script-errors)
- [Project v2 / Fields](#project-v2--fields)
- [Labels](#labels)
- [Workflows не работают](#workflows-не-работают)
- [Issue автоматика](#issue-автоматика)
- [Cascade unblock не срабатывает](#cascade-unblock-не-срабатывает)
- [Срочность / Действие не вычисляются](#срочность--действие-не-вычисляются)
- [Telegram notifications](#telegram-notifications)
- [Откат (uninstall)](#откат-uninstall)

---

## Prerequisites / gh CLI

### `gh: command not found`

```bash
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh      # или через github.com/cli/cli/releases

# Windows
winget install --id GitHub.cli
```

### `gh auth status` → not authenticated

```bash
gh auth login
# Choose: GitHub.com → HTTPS → Login with web browser
```

### `your authorization token does not have enough scopes`

```bash
gh auth refresh -s project,admin:org,workflow,write:packages
gh auth status
```

Проверить scope токена:
```bash
gh api user -H "X-OAuth-Scopes"
```

Если не помогает — пересоздать PAT на https://github.com/settings/tokens/new с галочками: `repo`, `project`, `admin:org`, `workflow`.

### `python3: command not found` / `No module named 'yaml'`

```bash
python3 -m pip install --user pyyaml
# или в venv
python3 -m venv .venv && source .venv/bin/activate && pip install pyyaml
```

### `jq: command not found`

```bash
# macOS
brew install jq
# Ubuntu
sudo apt install jq
```

---

## Install script errors

### `ERROR: TARGET_REPO variable not set`

Убедись что `.env` заполнен и `TARGET_REPO=owner/name`. Install script использует для создания labels и проверки API.

### `Invalid PROJECT_NUMBER`

Проверь что `PROJECT_NUMBER` — это **число** (не URL целиком). В URL `https://github.com/orgs/XXX/projects/5` — это `5`.

### `Project not found`

Причины:
1. Неправильный `PROJECT_OWNER` в `.env` (не совпадает с организацией где создан project)
2. Токен не имеет scope `project`
3. Project приватный, а токен не добавлен как collaborator

Проверка:
```bash
gh api graphql -f query='
query {
  organization(login: "'"$PROJECT_OWNER"'") {
    projectV2(number: '"$PROJECT_NUMBER"') { title }
  }
}'
```
Если выдаёт null — project действительно не найден. Если `not authorized` — scope.

### `Field '📋 Действие' already exists with different options`

Скрипт попытался создать поле, но оно уже существует с другим набором значений. Варианты:
1. Удалить поле через UI и запустить снова: `gh project → Settings → Fields → delete → ./install.sh`
2. Отредактировать поле вручную, чтобы options соответствовали config.yml

---

## Project v2 / Fields

### Дубликаты полей (e.g. два поля `Depends on`)

Причина: install запускался несколько раз на версиях до хотфикса #153. Решение:
```bash
# Найти дубликат
gh api graphql -f query='query { organization(login: "OWNER") { projectV2(number: N) { fields(first: 50) { nodes { ... on ProjectV2FieldCommon { id name } } } } } }' | jq

# Удалить через API:
gh api graphql -f query='mutation { deleteProjectV2Field(input: {fieldId: "FIELD_ID"}) { projectV2Field { ... on ProjectV2FieldCommon { name } } } }'
```

### `Status` поле — не могу переименовать на русский

Это GitHub native field. **Rename невозможен.** Workflow работает через `field_aliases` — он резолвит и `Status`, и `Статус`. Оставьте как есть.

### Option `🚫 Blocked` не добавилась

```bash
# Проверка
gh api graphql -f query='
query {
  organization(login: "OWNER") {
    projectV2(number: N) {
      fields(first: 50) { nodes { ... on ProjectV2SingleSelectField { name options { name } } } }
    }
  }
}' | jq '.data.organization.projectV2.fields.nodes[] | select(.name == "Status")'
```

Если нет `🚫 Blocked` — запустить:
```bash
./bootstrap/03-create-project-fields.sh
```
(идемпотентно, добавит только missing options).

---

## Labels

### Дубликаты labels со схожими именами (e.g. `docs` и `docs:trivial`)

Это разные labels, оба нужны:
- `docs` — тип задачи (категория)
- `docs:significant` / `docs:trivial` — флаги для docs-change-watcher

Не удалять.

### Label не ставится автоматически

Проверьте что issue создан через шаблон (`.github/ISSUE_TEMPLATE/task.yml` и т.п.). Issues созданные через `gh issue create` без `--label` не получают labels.

Workflow `parse-and-assign` парсит тело issue — там должны быть секции `### Роль` и `### Этап` с ответами из dropdowns.

---

## Workflows не работают

### Workflow не появился в Actions tab

Проверьте:
```bash
ls .github/workflows/
```

Должно быть:
- `board-automation.yml`
- `issue-automation.yml`
- `board-sanity.yml`
- `docs-change-watcher.yml`
- `cycle-time-metrics.yml`
- `dependency-graph.yml`

Если файлы есть, но не в Actions — сделайте `git commit + git push`. Workflows активируются только после push в default branch.

### `The requested URL returned error: 403`

Workflow не может писать в проект. Нужен PROJECT_TOKEN secret с scope `project`.

```bash
cd /path/to/target-repo
gh secret set PROJECT_TOKEN --body "YOUR_PAT_WITH_project_SCOPE"
```

### `Error: Not Found` при updateProjectV2ItemFieldValue

Issue не на проекте. Проверьте что **Auto-add to project** workflow включён в Project Settings → Workflows.

---

## Issue автоматика

### Issue создан — assignee не проставился

Проверьте:
1. Issue создан **через template** (task.yml / bug_report.yml / etc.), не через blank issue
2. В body issue есть секция `### Роль` с распознаваемым значением (backend/frontend/auth/data-migration/ops/docs)
3. `role_label_matches_assignee` правило в config работает:
   ```bash
   # Глянуть логи workflow run
   gh run list --workflow=issue-automation.yml --limit 5
   gh run view <RUN_ID> --log
   ```

Если label `role:X` есть, но assignee пустой — правило `auto_fix_if_no_assignee` сработает **только если assignees пусто**. Если кто-то руками проставил — не перезапишется. Это by design.

### Status не меняется при создании ветки

Branch name должен матчить pattern `{type}/issue-{N}-{description}`:
- `feature/issue-42-foo` ✅
- `fix/issue-42-bug` ✅
- `42-foo` ❌
- `new-branch` ❌

См. `.github/workflows/board-automation.yml` jobs.branch-created для regex.

### Issue на доске, но поля `Этап`, `🤖 Срочность`, `📋 Действие` пустые

Workflow populate-project-fields работает асинхронно. Подождите 30-60 секунд. Если всё ещё пусто — триггернуть вручную:

```bash
gh workflow run issue-automation.yml --ref main -f issue_number=42
```

---

## Cascade unblock не срабатывает

Issue закрылся, но зависимые не разблокировались.

Проверки:
1. В закрытом issue было референс в `Зависит от` других: да/нет?
   ```bash
   # Проверить Project field "Зависит от" closed issue — можно через log
   gh api graphql -f query='query { repository(owner:"OWNER",name:"REPO") { issue(number:CLOSED_N) { projectItems(first:5) { nodes { fieldValues(first:10) { nodes { ... on ProjectV2ItemFieldTextValue { text field { ... on ProjectV2FieldCommon { name } } } } } } } } } }'
   ```
2. Workflow запустился? `gh run list --workflow=issue-automation.yml --limit 5`
3. В логе есть строка `Cascade unblock: N issue(s) moved to К работе`?

Если workflow не запустился — PROJECT_TOKEN неверный (см. выше).

Если workflow запустился, но no cascade — возможно dependent issues имеют **статус не Blocked** (например в В работе). Правило только переводит Blocked → К работе.

---

## Срочность / Действие не вычисляются

### `🤖 Срочность` всегда `⏳ Обычно`

Правило `auto_urgency_by_blocks` считает blocks_count — сколько **других** open issues имеют в своём `Зависит от` ссылку на текущий.

Если issue никого не блокирует → `⏳ Обычно` → **правильно**.

Если issue блокирует других, но blocks_count = 0 → проверьте формат `Зависит от` в зависимых issues. Должно быть `#42` (с решёткой), не `42`.

### `📋 Действие` пустое

Title не содержит Conventional Commits prefix в распознаваемом формате. Поддерживаемые:
- `feat:`, `feat(X):`
- `fix:`, `fix(X):`
- `docs:`, `docs(X):`
- `ops:`, `ops(X):`, `chore:`, `chore(X):`, `auth:`, `data:`, `task(X):`
- `team-sync:`
- `proposal:`, `research:`, `spike:`
- `review:`
- `coord:`, `coord(X):`

Если title типа `Prod-release blocker: integration ...` — нет prefix → поле пустое. Либо переименуйте title, либо поставьте `📋 Действие` вручную в Project UI. Weekly board-sanity audit flagует такие issues.

---

## Telegram notifications

### Сообщения не приходят

Проверки:
1. `TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_ID_TASKS` добавлены как GitHub Actions secrets:
   ```bash
   gh secret list
   ```
2. Бот добавлен в чат и имеет право писать.
3. `chat_id` правильный. Чтобы узнать:
   - Добавь бота в чат, напиши ему что-то
   - `curl "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[].message.chat.id'`

### Приходит спам (каждое действие)

Workflow слушает только 3 event types по дизайну. Если больше — проверь что не стоит лишний `on:` в `issue-automation.yml`:
```yaml
on:
  issues:
    types: [..., assigned]    # правильно для notify
  pull_request:
    types: [review_requested] # правильно для notify
```

---

## Откат (uninstall)

Полный откат:

```bash
cd /path/to/kit-board
./uninstall.sh /path/to/target-repo
```

Скрипт:
- Удаляет `.github/board/` целиком
- Удаляет 6 workflow-файлов (только наших)
- Удаляет labels role:*, этап:*, blocked, docs:significant, docs:trivial, team-sync-overdue, board-audit, metrics-report, dependency-graph, task, found-work
- **Спрашивает подтверждение** перед удалением Project fields (потеря данных!)
- Не удаляет Project v2 сам — это делается через UI

После `uninstall` — `git status` покажет deleted файлы. Commit вручную:
```bash
cd target-repo
git add -A && git commit -m "chore(board): uninstall kit-board"
```

### Частичный откат — только workflows

```bash
cd target-repo
rm .github/workflows/{issue-automation,board-automation,board-sanity,docs-change-watcher,cycle-time-metrics,dependency-graph}.yml
git commit -am "chore: remove board workflows"
```

Board module (`.github/board/`) останется как документация.

---

## Если ничего не помогло

1. Открой issue в https://github.com/fruitart-code/kit-board/issues
2. Приложи:
   - Версию gh CLI (`gh --version`)
   - OS (`uname -a`)
   - Фрагмент из `verify.sh` output
   - Фрагмент из логов workflow runs
3. Ссылка на reference implementation — [`COCRealty-Devops/repository-cocrealty`](https://github.com/COCRealty-Devops/repository-cocrealty) — откуда kit извлечён.
