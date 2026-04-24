# INSTALL — пошаговая инструкция

Полная установка kit-board в target GitHub repo. Рассчитано на **~15 минут** ручной работы.

## Содержание

- [1. Prerequisites](#1-prerequisites)
- [2. Предварительные шаги в GitHub UI](#2-предварительные-шаги-в-github-ui)
- [3. Настройка `.env`](#3-настройка-env)
- [4. Запуск install](#4-запуск-install)
- [5. Проверка установки](#5-проверка-установки)
- [6. Первый test-issue (smoke test)](#6-первый-test-issue-smoke-test)
- [7. Коммит в target repo](#7-коммит-в-target-repo)
- [8. Опциональная настройка Telegram notifications](#8-опциональная-настройка-telegram-notifications)

---

## 1. Prerequisites

### Инструменты на локальной машине

| Инструмент | Минимальная версия | Проверка |
|---|---|---|
| `gh` CLI | 2.40 | `gh --version` |
| Python | 3.10 | `python3 --version` |
| `pyyaml` | любая | `python3 -c "import yaml"` |
| `jq` | 1.6 | `jq --version` |
| Bash | 4 | `bash --version` |
| Git | 2.30 | `git --version` |

Установка pyyaml:
```bash
python3 -m pip install --user pyyaml
```

### GitHub Personal Access Token

Требуются scopes:
- `repo` — create issues, labels
- `project` — manage Projects v2
- `admin:org` — если target принадлежит organization (management collaborators)
- `workflow` — copy workflow files

**Сгенерировать:** https://github.com/settings/tokens/new

**Настроить gh CLI:**
```bash
gh auth login                          # или
gh auth refresh -s project,admin:org,workflow   # добавить scopes к existing
gh auth status                         # проверить
```

### Target repository

- Существует на github.com
- Публичный или приватный (оба работают)
- У вас есть права **Admin** (для создания labels, workflows)
- `main` branch существует

---

## 2. Предварительные шаги в GitHub UI

### 2.1. Создать GitHub Project v2

**API не даёт создать Project v2** — только через UI.

1. Перейдите в target org или user profile → вкладка **Projects**
2. Кнопка **New project** → **Empty project**
3. Name: напр. `Board` или `<Project Name> Board`
4. Visibility: public / private по желанию
5. Create

**Запомните project number** — видно в URL: `https://github.com/orgs/YOUR_ORG/projects/42` → `PROJECT_NUMBER=42`

### 2.2. Добавить участников команды в Project (если team)

1. Project → ⚙ Settings → **Manage access**
2. Добавить каждого члена команды с ролью **Write** (не Admin — иначе сможет сломать shared views)

---

## 3. Настройка `.env`

```bash
cd /path/to/kit-board      # где распакован kit
cp .env.example .env
# Откройте .env в редакторе
```

### Переменные `.env`

| Variable | Пример | Описание |
|---|---|---|
| `PROJECT_OWNER` | `fruitart-code` | Organization или user login, где находится Project v2 |
| `PROJECT_NUMBER` | `5` | Number из URL проекта |
| `PROJECT_TITLE` | `My Project Board` | Отображаемое имя (в миграциях) |
| `TARGET_REPO` | `fruitart-code/my-project` | `owner/name` target репо (куда ставим workflows) |
| `BACKEND_USER` | `alice` | GitHub login backend-разработчика |
| `FRONTEND_USER` | `bob` | GitHub login frontend |
| `AUTH_USER` | `carol` | GitHub login auth/IdP |
| `DATA_USER` | `dave` | GitHub login data-migration |
| `OPS_USER` | `fruitart-code` | GitHub login ops (fallback) |
| `DOCS_USER` | `fruitart-code` | GitHub login docs (обычно = OPS_USER) |
| `TELEGRAM_BOT_TOKEN` | `(empty)` | Опционально — токен бота для notifications |
| `TELEGRAM_CHAT_ID_TASKS` | `(empty)` | Опционально — chat_id для notifications |

**Для малой команды:** если участников меньше 6, просто укажите `fruitart-code` или другой fallback user на все роли без человека — задачи будут assign'иться вам до тех пор, пока вы их не переназначите.

---

## 4. Запуск install

```bash
cd /path/to/kit-board
./install.sh /path/to/target-repo-on-disk
```

Параметр — **локальный путь** к клонированному target репо (не URL).

Скрипт выполнит последовательно:

1. **01-check-prerequisites.sh** — проверит gh, python, pyyaml, jq, bash, git, валидность .env и токена
2. **02-create-labels.sh** — создаст 15+ labels (role:*, этап:*, task, found-work, docs:*, blocked, team-sync-overdue, board-audit, metrics-report, dependency-graph)
3. **03-create-project-fields.sh** — создаст 6 custom fields (Этап, Зависит от, Порядок, 🤖 Срочность, ⏱ Last moved, 📋 Действие) + добавит опцию `🚫 Blocked` в Status
4. **04-install-workflows.sh** — скопирует 6 workflow-файлов в `TARGET_REPO/.github/workflows/`
5. **05-install-templates.sh** — скопирует 4 issue templates в `TARGET_REPO/.github/ISSUE_TEMPLATE/`
6. **06-install-board-module.sh** — скопирует `.github/board/` модуль (config.yml с заполненными placeholders, USER-GUIDE, scripts, migrations/000-initial-from-kit.md)
7. **07-backfill-existing-issues.sh** — опционально (спросит перед запуском), backfill labels/fields для существующих open issues

**Время установки:** 3-5 минут.

Скрипт идемпотентный — можно запускать повторно, уже созданные объекты будут skip'нуты.

---

## 5. Проверка установки

```bash
./verify.sh /path/to/target-repo-on-disk
```

Выведет отчёт:

```
✅ Files installed:
  - 6 workflows in .github/workflows/
  - 4 issue templates in .github/ISSUE_TEMPLATE/
  - .github/board/ module (config.yml, README.md, USER-GUIDE.md, scripts/, migrations/)

✅ GitHub resources:
  - 16 labels created
  - 6 custom fields created
  - 1 status option '🚫 Blocked' added

✅ Config integrity:
  - config.yml placeholders all replaced
  - field_aliases match created fields

⚠️ Warnings:
  - PROJECT_TOKEN secret not set in repo (workflows will use GITHUB_TOKEN — limited perms)
  - TELEGRAM_BOT_TOKEN empty — notify-external job will silently skip

✅ READY TO USE
```

Если есть ❌ — смотрите TROUBLESHOOTING.md.

---

## 6. Первый test-issue (smoke test)

В GitHub UI:

1. Target repo → **Issues** → **New issue** → выбрать шаблон **`Задача`** (task.yml)
2. Заполните:
   - Title: `test(ops): verify kit-board installed`
   - Что нужно сделать: `Проверка установки kit-board`
   - Зачем: `Smoke test после установки`
   - Роль: `ops`
   - Этап: `0 — Infrastructure Bootstrap`
   - Зависит от: (пусто)
3. Submit

**Подождите 30-60 секунд** (workflow асинхронный) и откройте issue:

- Assignee: ваш OPS_USER автоматически
- Labels: `role:ops`, `этап:0`, `task`
- На карточке board: Status `📋 К работе`, `📋 Действие: ⚙️ Настроить` (из `test(ops):` prefix), `🤖 Срочность: ⏳ Обычно`, `Этап 0`
- В issue теле: ничего не добавилось (body сохранён как есть)

Если все поля заполнены — **установка прошла**. Закройте test-issue.

---

## 7. Коммит в target repo

```bash
cd /path/to/target-repo
git status   # покажет новые файлы в .github/
git add .github/
git commit -m "feat(board): install kit-board automation"
```

**Не пушьте сразу** — проверьте `git diff --cached` что всё ок. После — push.

---

## 8. Опциональная настройка Telegram notifications

Если в `.env` заполнены `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID_TASKS` — install script **не добавляет их в secrets автоматически** (требует admin токен с scope `admin:org` или `repo`, который может отсутствовать).

**Сделайте вручную:**

```bash
cd /path/to/target-repo
gh secret set TELEGRAM_BOT_TOKEN --body "YOUR_TOKEN"
gh secret set TELEGRAM_CHAT_ID_TASKS --body "YOUR_CHAT_ID"
gh secret set PROJECT_TOKEN --body "YOUR_PAT_WITH_PROJECT_SCOPE"
```

`PROJECT_TOKEN` — PAT с scope `project`. Нужен для workflow чтобы иметь доступ к Project v2 API.

После этого notify-external workflow начнёт работать — будет отправлять 3 типа событий в Telegram:
- Тебе назначили новую задачу
- Просят ревью PR
- (native comment) Твой блокер разблокирован

---

## Что дальше

- Прочитайте [USER-GUIDE.md](templates/.github/board/USER-GUIDE.md) — оно попадёт в target repo после install, это для команды
- Закрепите (Pin issue) первые отчёты когда они появятся (пятница + понедельник) — см. USER-GUIDE § 8
- Добавьте в target repo README ссылку на USER-GUIDE — пусть команда знает где читать

## Ошибки

Все известные ошибки и решения — [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
