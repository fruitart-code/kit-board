# AGENT-PROMPT

> Готовый промпт для AI-агента (Claude Code, Cursor, Copilot Workspace, etc.)
> чтобы развернуть kit-board в target repo автоматически.

## Как использовать

Скопируй блок ниже → вставь в чат с агентом → он сделает всё сам. Агенту потребуется твоё подтверждение на несколько шагов (secrets, PROJECT_NUMBER).

---

## 🤖 Prompt

Вот задача для тебя:

> У меня есть starter kit `kit-board` (https://github.com/fruitart-code/kit-board) — это автоматизация GitHub Projects v2 board. Я хочу установить её в **текущий репозиторий**.
>
> Последовательность:
>
> 1. **Клонируй kit в временную папку**:
>    ```bash
>    git clone https://github.com/fruitart-code/kit-board.git /tmp/kit-board
>    ```
>
> 2. **Прочитай следующие файлы** (в указанном порядке, не делая сразу действий):
>    - `/tmp/kit-board/README.md`
>    - `/tmp/kit-board/INSTALL.md` — здесь полная инструкция
>    - `/tmp/kit-board/TROUBLESHOOTING.md` — на случай ошибок
>    - `/tmp/kit-board/templates/.github/board/USER-GUIDE.md` — что получу в итоге
>
> 3. **Подготовь `.env`**:
>    - Скопируй `/tmp/kit-board/.env.example` → `/tmp/kit-board/.env`
>    - Узнай у меня (спроси явно каждое значение):
>      - GitHub owner (organization или user login)
>      - Repo name
>      - Project v2 number (если проект не создан — попроси создать через UI и дать номер из URL)
>      - Имена участников команды (GitHub logins) для 6 ролей:
>        backend, frontend, auth, data-migration, ops, docs
>      - Telegram BOT_TOKEN + CHAT_ID (опционально — можно пропустить)
>    - Заполни `.env` полученными значениями
>
> 4. **Убедись что prerequisites установлены** (gh CLI ≥ 2.40, python 3.10+, pyyaml, bash). Если нет — скажи мне что установить.
>
> 5. **Проверь токен**:
>    ```bash
>    gh auth status
>    gh api user
>    ```
>    Если токен не имеет scope `project` — перегенерируй через `gh auth refresh -s project,admin:org`.
>
> 6. **Запусти install**:
>    ```bash
>    cd /tmp/kit-board
>    ./install.sh $(pwd -P)/../../path/to/current-target-repo
>    ```
>    _(путь = текущий target repo)_
>
>    Install script выполнит последовательно bootstrap-шаги:
>    - `01-check-prerequisites.sh` — проверка окружения
>    - `02-create-labels.sh` — 15+ labels
>    - `03-create-project-fields.sh` — 6 custom fields + Blocked status option
>    - `04-install-workflows.sh` — копирует 6 workflow-файлов в target/.github/workflows/
>    - `05-install-templates.sh` — копирует 4 issue templates
>    - `06-install-board-module.sh` — копирует `.github/board/` модуль
>    - `07-backfill-existing-issues.sh` — опционально, если в target repo есть open issues
>
> 7. **Проверь установку**:
>    ```bash
>    ./verify.sh $(pwd -P)/../../path/to/current-target-repo
>    ```
>    Скрипт проверяет: файлы на месте, labels созданы, fields созданы, workflow файлы валидны.
>
> 8. **Сделай первый live-test**:
>    - Создай тестовый issue в target repo через шаблон `task.yml`
>    - Проверь что в течение 60 секунд:
>      - Assignee проставился автоматически (по role)
>      - Issue на доске
>      - Поля `Этап`, `🤖 Срочность`, `📋 Действие` заполнены
>      - Статус = `📋 К работе` или `🚫 Blocked`
>    - Закрой тестовый issue после проверки
>
> 9. **Закоммить изменения** в target repo:
>    ```bash
>    cd /path/to/target-repo
>    git add .github/
>    git commit -m "feat(board): install kit-board automation"
>    ```
>    _Не пушь пока не подтвержу._
>
> 10. **Отчитайся**:
>     - Сколько labels создано
>     - Сколько fields создано
>     - Сколько workflows установлено
>     - Результат verify.sh
>     - Результат live-test
>     - Если есть warnings из TROUBLESHOOTING.md — что из них применимо
>
> **Stop-gates** (подтверждение от меня обязательно):
> - Перед запуском `install.sh`
> - Перед `git commit` в target repo
> - Перед `git push`
> - Перед удалением чего-либо в `uninstall` сценарии
>
> Если возникнет **ошибка** — читай `/tmp/kit-board/TROUBLESHOOTING.md` и сообщай мне **проблему + предлагаемое решение**, не пытайся исправить автоматически.
>
> Начинай с шага 1.

---

## Вариации промпта

### Если у тебя уже есть kit-board склонирован

> У меня локально уже есть `kit-board` по пути `/path/to/kit-board`. Используй существующий clone, пропусти шаг 1.

### Если проект Project v2 ещё не создан

> Перед шагом 3 помоги создать GitHub Project v2 через UI:
> 1. Перейди https://github.com/orgs/{ORG}/projects → New project → Empty project
> 2. Дай мне число из URL (например `...projects/5` → number = 5)
> Дальше по шагам.

### Если target repo уже имеет issues

> После шага 7 — **не запускай 07-backfill автоматически**. Сначала спроси меня, есть ли issues которые я хочу backfill, или начинаем с чистого листа.

### Если Telegram notifications нужны

> В `.env` заполни TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID_TASKS. Install script добавит их как GitHub Actions secrets в target repo. Проверить — в Settings → Secrets and variables → Actions.

---

## Что агент должен знать заранее

- **Операции requiring Ledger / hardware signing:** если пользователь использует hardware-based git commit signing (Ledger/YubiKey), commit в шаге 9 потребует физического touch. Попроси пользователя разбудить устройство и повторит.
- **Proxy environment:** если `gh api` возвращает 502 через proxy — попробуй повтор, не падай сразу.
- **Idempotency:** install.sh можно запускать много раз — он skip'ает уже существующие поля/labels.

---

## Чего агент НЕ должен делать

- Не удалять существующие `.github/workflows/*` — только добавлять новые.
- Не пушить без явного подтверждения.
- Не создавать Project v2 через API (требует ручного шага в UI из-за ограничения GitHub API).
- Не изменять config.yml после install без явного запроса (там уже persist state).

---

## Ссылки

- Main repo: https://github.com/fruitart-code/kit-board
- Issue tracker: https://github.com/fruitart-code/kit-board/issues
- Reference implementation: https://github.com/COCRealty-Devops/repository-cocrealty (это откуда kit извлечён)
