# CUSTOMIZATION

Как адаптировать kit-board под свой проект (роли, этапы, правила). Без форка — через config.yml и env.

## Содержание

- [1. Меньше/больше ролей](#1-меньшебольше-ролей)
- [2. Другой набор этапов](#2-другой-набор-этапов)
- [3. Свой title prefix mapping](#3-свой-title-prefix-mapping)
- [4. Другие пороги Срочности / Card aging](#4-другие-пороги-срочности--card-aging)
- [5. Отключить отдельный workflow](#5-отключить-отдельный-workflow)
- [6. Добавить свой rule в enforce-consistency](#6-добавить-свой-rule-в-enforce-consistency)
- [7. Переименовать поля на другой язык](#7-переименовать-поля-на-другой-язык)
- [8. Интеграция с другим мессенджером](#8-интеграция-с-другим-мессенджером)

---

## 1. Меньше/больше ролей

Дефолт — 6 ролей. Меняй в `config.yml.roles`:

```yaml
roles:
  my-role:
    label: "role:my-role"
    assignee: "github-user-login"
    description: "..."
```

Плюс изменить:
- `.github/ISSUE_TEMPLATE/task.yml` — dropdown `Role options` (добавить/убрать значения)
- Аналогично в других templates

И запустить `./bootstrap/02-create-labels.sh` — создаст новый label.

**Для solo-dev:** оставь только `ops` и `docs` (обе на тебя). Остальные роли можно просто не использовать (не возникнет проблем — workflow не требует их наличия).

---

## 2. Другой набор этапов

Дефолт — 7 этапов (0..6) + "Вне этапов".

Чтобы изменить — две точки правок:

### 2.1. config.yml

```yaml
stages:
  - id: "0"
    label: "этап:0"
    name: "Этап 0 — Моё название"
    epic_issue: 42    # optional
  # ... добавь/убери сколько надо
```

### 2.2. Опции в Project v2 field `Этап`

Правило `stage_label_matches_field` использует маппинг из config.yml:
```yaml
field_mapping:
  "этап:0": "Этап 0"
  "этап:1": "Этап 1"
```

Если этапов меньше — убери лишние. Если больше — добавь.

**Плюс:** руками в Project UI → Fields → Этап → добавить/убрать options чтобы совпадало.

**Минимум:** 2 стадии (один рабочий + `none`) — ни чем не хуже.

### 2.3. Issue templates

В `task.yml`, `bug_report.yml`, и т.д. — dropdown `Этап` имеет фиксированные options. Синхронизировать.

---

## 3. Свой title prefix mapping

Правило `auto_action_from_title_prefix` использует маппинг Conventional Commits → Действие. Изменить в `config.yml`:

```yaml
- id: auto_action_from_title_prefix
  title_prefix_mapping:
    "💻 Реализовать":
      - "feat"
      - "refactor"
      - "test"
      - "custom"        # добавили свой prefix
```

Изменение не требует перезапуска setup-fields.sh — правило читается workflow при runtime.

**Добавить prefix для проекта** (например `infra:` → ⚙️ Настроить): допиши в секцию `⚙️ Настроить`.

**Убрать prefix** (например не хотим `spike:` → 🔍): просто удали из mapping.

---

## 4. Другие пороги Срочности / Card aging

### Срочность

Правило `auto_urgency_by_blocks` имеет неявные пороги (в workflow коде). Если нужно изменить — редактируй `issue-automation.yml`, секцию `if (rule.id === 'auto_urgency_by_blocks')`:

```js
if (blocksCount >= 2) urgency = '🔥 Горит';
else if (stage === 'Этап 0' && order === 1) urgency = '🔥 Горит';
else if (blocksCount === 1) urgency = '⚡ Срочно';
// ...
```

Например, хотим 🔥 Горит при 3+ блокируемых — измени `>= 2` на `>= 3`.

### Card aging

В `config.yml.card_aging` — явно настраиваемые пороги:

```yaml
card_aging:
  in_progress:
    yellow_days: 5
    red_days: 10
  blocked:
    red_days: 3
  on_review:
    yellow_days: 3
    red_days: 7
```

Для enterprise-project где задачи длинные — повысь до `yellow_days: 14, red_days: 30`. Для fast-paced — понизь.

---

## 5. Отключить отдельный workflow

Каждый workflow — независимый файл. Удалить = отключить.

Например, не нужен **cycle time metrics** (маленькая команда, не измеряем):

```bash
cd target-repo
rm .github/workflows/cycle-time-metrics.yml
git commit -am "chore: disable cycle-time workflow"
```

Остальная автоматика (cascade unblock, consistency, etc.) продолжит работать.

**Опция через disable (не удаление):**

```bash
gh workflow disable cycle-time-metrics.yml
```

— workflow остаётся в репо, но не запускается. Можно `enable` обратно.

---

## 6. Добавить свой rule в enforce-consistency

В `config.yml.consistency_rules` — добавь новое правило:

```yaml
- id: my_custom_rule
  description: "My business logic check"
  action: auto_fix       # или `warn`
  severity: info
  # custom поля для вашей логики
```

И добавь case в `issue-automation.yml`, job `enforce-consistency`:

```js
if (rule.id === 'my_custom_rule') {
  // your logic
  // fv[...] = текущие значения полей
  // actions.push('описание действия')
}
```

Commit + push → следующее срабатывание workflow применит правило.

---

## 7. Переименовать поля на другой язык

Workflow резолвит поля по именам из `field_aliases`:

```yaml
field_aliases:
  status: ["My Custom Status", "Статус", "Status"]
  depends_on: ["Blocks", "Зависит от", "Depends on"]
```

Порядок важен — первое имя = **preferred**, остальные — fallback для backward-compat.

Сам rename через Project UI:
1. Project → Fields → Status → rename → `My Custom Status`
2. Но **native Status нельзя переименовать** (GitHub ограничение). `Title`, `Assignees`, `Labels`, `Linked pull requests` — тоже.

Custom fields (`Этап`, `Порядок`, `Зависит от`, `🤖 Срочность`, `⏱ Last moved`, `📋 Действие`) — переименовываются через API:

```bash
gh api graphql -f query='
mutation {
  updateProjectV2Field(input: {
    fieldId: "FIELD_ID",
    name: "New Name"
  }) { projectV2Field { ... on ProjectV2FieldCommon { name } } }
}'
```

Для single-select полей (Этап, 🤖 Срочность, 📋 Действие) также нужно передать все existing options с их IDs — иначе item field values потеряются. См. reference в [COCR board scripts](https://github.com/COCRealty-Devops/repository-cocrealty/blob/main/.github/board/migrations/006-urgency-field-and-russian-aliases.md).

---

## 8. Интеграция с другим мессенджером

Workflow `notify-external` (в `issue-automation.yml`, job 5) по умолчанию поддерживает только Telegram. Адаптируй под Slack / Discord / Mattermost:

### Slack

Замени в `issue-automation.yml`:

```yaml
run: |
  if [ -z "$SLACK_WEBHOOK" ]; then exit 0; fi
  MSG='{"text":"'"${ACTION}"'"}'
  curl -X POST "$SLACK_WEBHOOK" -H "Content-Type: application/json" -d "$MSG"
```

Переменная `SLACK_WEBHOOK` — Secret в GitHub Actions (https://api.slack.com/messaging/webhooks).

### Discord

```yaml
run: |
  if [ -z "$DISCORD_WEBHOOK" ]; then exit 0; fi
  curl -X POST "$DISCORD_WEBHOOK" -H "Content-Type: application/json" \
    -d "{\"content\": \"$ACTION\"}"
```

### Mattermost

```yaml
run: |
  if [ -z "$MATTERMOST_WEBHOOK" ]; then exit 0; fi
  curl -X POST "$MATTERMOST_WEBHOOK" -H "Content-Type: application/json" \
    -d "{\"text\": \"$ACTION\"}"
```

---

## Подсказки

- **Всегда изменяй через config.yml/env**, а не через hardcode. Так легче обновлять kit когда выйдет новая версия.
- **При больших изменениях**: создай `migration` в `.github/board/migrations/` с описанием "что изменил, почему". Это будет твоя audit trail.
- **Если ломаешь что-то — запусти `uninstall.sh && install.sh`** — он идемпотентный, пересоздаст всё.

Непонятно как что-то сделать — открой issue в kit-board repo.
