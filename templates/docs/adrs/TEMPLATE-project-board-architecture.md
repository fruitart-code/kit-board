# ADR-010: Архитектура GitHub Project Board как инструмента координации

> **Дата:** 2026-04-23
> **Статус:** Accepted
> **Участники:** @fruitart-code (решение + реализация)
> **Связанные issues:** — (введение нового модуля)
> **Связанные ADR:** —
> **Связанные документы:** [.github/board/README.md](../../.github/board/README.md) — модуль, [.github/board/config.yml](../../.github/board/config.yml) — source-of-truth конфигурации

---

## 1. Контекст

До введения этой архитектуры проектная доска работала как ручной инструмент:
каждый issue требовал ручной проставки assignee, этапа, приоритета и связанной
документации. На практике это приводило к систематическим провалам:

1. **Участники не видят ожидаемой от них работы.** Задача «Сергей должен написать
   Keycloak realm config до старта Этапа 0» существует в `role-backlog-v1.2.md`
   и TS v1.2, но **не оформлена как issue**. Сергей заходит на доску →
   не видит задач → логично решает, что ему сейчас делать нечего.
2. **Кросс-участниковая последовательность не визуализирована.** Когда задача A
   (razqqm) блокирует задачу B (fruitart-code), оба должны знать об этом.
3. **Временные оценки недостоверны.** В проекте сроки смещаются; полагаться
   на «неделя до дедлайна» как триггер неэффективно. Нужно событийное
   переключение статусов по факту закрытия зависимостей.
4. **Ручное назначение ответственных.** Система многократно наблюдала забытое
   поле `assignee` — человеческий фактор.

Требование: **доска как подключаемый инструмент**, не встроенная в бизнес-логику
часть репозитория. Если в будущем команда перейдёт на Jira/Linear — удаление
одной папки должно закрывать тему без влияния на основной код.

---

## 2. Решение

### 2.1. Изоляция модуля

Вся специфика доски живёт в одной папке:

```
.github/board/
├── README.md                 ← контракт «как отключить»
├── config.yml                ← единый source-of-truth
├── scripts/                  ← idempotent setup/backfill/audit
│   ├── setup-fields.sh
│   ├── backfill.sh
│   └── audit.sh
└── migrations/               ← история изменений
```

GitHub-обязательные пути (нельзя вынести):

- `.github/workflows/issue-automation.yml` — исполнитель логики
- `.github/ISSUE_TEMPLATE/*.yml` — формы с dropdown-ами role/stage

**Контракт отключения:** `rm -rf .github/board .github/workflows/issue-automation.yml`
+ убрать dropdown-блоки из ISSUE_TEMPLATE → модуль убран без последствий
для основного проекта.

### 2.2. Dynamic field ID resolution

**НЕ хардкодим** Project v2 field/option IDs. Скрипты и workflow резолвят
их через GraphQL **по именам** (`"Этап"`, `"Depends on"`, `"Status"`).
Преимущества:

- Self-healing: если поле пересоздано через UI — автоматика продолжает работать
- Идемпотентность `setup-fields.sh`: можно запускать многократно
- Простота ревью: нет магических строк `PVTSSF_lADOD-...` в diff

### 2.3. Role-based auto-assign

Каждый issue имеет ровно один label с префиксом `role:` (6 значений):
`backend`, `frontend`, `auth`, `data-migration`, `ops`, `docs`. Маппинг
`role → assignee` определён в `config.yml`:

| Role              | Assignee              |
|-------------------|-----------------------|
| backend           | @razqqm               |
| frontend          | @kenesovaregina-ops   |
| auth              | @zxczxcas1            |
| data-migration    | @hottraff             |
| ops               | @fruitart-code        |
| docs              | @fruitart-code        |

Workflow `parse-and-assign` извлекает role из issue body (dropdown-ответ
шаблона) → ставит label `role:<X>` → назначает assignee. **Невозможно
создать issue через шаблон без указания role** (required field), значит
невозможно забыть назначить ответственного.

Fallback: если role не указан (issue создан не через шаблон) — assignee
устанавливается в `fallback_assignee` (`@fruitart-code`).

### 2.4. Этапы проекта

Single-select поле `Этап` со значениями `Этап 0..6` + `Вне этапов`.
Привязка через label `этап:<N>`, проставляется workflow по выбору
в template-dropdown. Каждый этап имеет связанный epic-issue (#115..#121).

### 2.5. Dependency tracking (текстовое поле Depends on)

GitHub Projects v2 **не имеет нативного** `depends-on` отношения
(только `sub-issues`, что моделирует containment, а не sequence).
Решение: **текстовое поле `Depends on`** формата `#N, #M`.

Workflow парсит это поле + раздел `### Зависит от` в теле issue и:

1. **При создании** issue:
   - все referenced issues `closed` или список пуст → статус `📋 К работе`
   - есть открытые → статус `🚫 Blocked`

2. **При закрытии** issue `#N` (событие `issues.closed`):
   - найти все items на доске, где в `Depends on` фигурирует `#N`
   - удалить `#N` из их `Depends on`
   - если список стал пуст **и** статус был `🚫 Blocked` → `📋 К работе`
   - прокомментировать issue: `@assignee — зависимость #N закрыта, задача
     разблокирована и готова к работе` (GitHub native notification)

Это реализует **событийное переключение без привязки к датам**:
закрылся блокер — подтянулась следующая задача.

### 2.6. Статусы доски

Шесть существующих статусов сохранены (владелец — `board-automation.yml`,
не трогаем): `📥 Бэклог`, `📋 К работе`, `🔨 В работе`, `👀 На ревью`,
`✅ Одобрено`, `🏁 Готово`.

Добавлен новый: **`🚫 Blocked`** — «задача готова технически, но ждёт
закрытия других». Visible для обоих: блокированного и блокирующего.

Workflow не «опускает» статус из `В работе`/`На ревью`/`Одобрено`/`Готово`
обратно — cascade-unblock касается только `Backlog`/`Blocked`/`К работе`.

### 2.7. Views на доске

| View           | Layout | Filter                                                           | Назначение                         |
|----------------|--------|------------------------------------------------------------------|------------------------------------|
| Таблица        | Table  | none                                                             | Полный обзор                       |
| Доска          | Board  | group by Status                                                  | Kanban-поток                       |
| Команда        | Board  | group by Assignee                                                | Swimlanes по участникам            |
| Roadmap        | Roadmap| group by Этап                                                    | Временная перспектива по этапам    |

**Convention для каждого участника:** свой bookmark с фильтром
`assignee:@me status: К работе,В работе,На ревью`, сортировкой
по `Этап → Order → Priority`.

### 2.8. Notifications (phased)

Workflow содержит placeholder-job `notify-external`, который активируется
при наличии secrets `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID_TASKS`.
Конкретное решение по Telegram-каналу фиксируется отдельно владельцем
проекта, в данном ADR — интеграционная точка.

### 2.9. Audit regime

**Три уровня защиты от "задача объявлена в чате, а на доске её нет":**

#### 2.9.1. PR template enforcement (при каждом PR)

`pull_request_template.md` содержит обязательный блок **Team-sync**. PR,
меняющий `docs/specification/**` / `docs/adrs/**` / `docs/audit/decision-baseline-*`
/ `docs/audit/role-backlog-*` / `docs/audit/preconditions-tracker.md` /
`.github/CODEOWNERS`, должен иметь один из labels:
- **`docs:significant`** + созданные team-sync issues + запись в
  `.github/board/team-sync-tracker.yml`, или
- **`docs:trivial`** (без требований).

#### 2.9.2. Post-merge watcher (автоматически, на event)

Workflow `.github/workflows/docs-change-watcher.yml` срабатывает на
`pull_request.closed` для путей из списка выше. Если PR не имеет ни
`docs:significant` ни `docs:trivial`, и не записан в tracker →
автоматически открывает **tracker-issue `team-sync-overdue: PR #N`**
на @fruitart-code.

#### 2.9.3. Weekly sanity audit (каждый понедельник)

Workflow `.github/workflows/board-sanity.yml` (cron `0 6 * * 1`)
проверяет:

1. Все open issues на доске? (`audit.sh` = gaps_not_on_board)
2. У каждого есть `role:*` и `этап:*` labels?
3. У каждого есть assignee?
4. Есть ли stale `🚫 Blocked` (все deps уже closed)?
5. **Team-sync coverage за последние 14 дней** — сверяет список merged PRs
   (касающихся `significant_paths`) с записями в `team-sync-tracker.yml`.
   Overdue PRs перечисляются в отчёте.

Результат → issue с label `board-audit` на @fruitart-code. Одновременно
открыт только один такой issue (переиспользуется между прогонами).

#### 2.9.4. Field consistency enforcement (real-time)

Инцидент 2026-04-23 показал что **label и Status могут расходиться**
(карточка в `📋 К работе`, но с label `blocked`). Plus workflow
`populate-project-fields` ошибочно downgrade'ил Status при unrelated
events (label change).

Фиксы (Migration 003):

1. **Downgrade protection**: `populate-project-fields` трогает Status
   только если `current = 📥 Бэклог`. Любой другой статус = workflow
   не интерферирует.
2. **Новый job `enforce-consistency`** — срабатывает на
   `issues.labeled/unlabeled/opened/reopened/closed`:
   - `Status = 🚫 Blocked` ↔ label `blocked` (auto-sync)
   - В будущем: расширяется декларативными правилами в `config.yml`

Принцип: **никаких ручных коррекций**. Если вижу расхождение —
добавить правило в workflow, не чинить руками. Любая ручная правка
consistency = баг системы.

#### 2.9.5. Manifest (`team-sync-tracker.yml`)

Single source of truth: "для какого PR созданы team-sync issues, в каком
они статусе". Формат — см. сам файл. Обновляется либо вручную (при merge
significant PR), либо через docs-change-watcher в будущем.

### 2.10. Native GitHub fields — лимит на rename

GitHub Projects v2 создаёт автоматически набор native fields:
`Title`, `Assignees`, `Status`, `Labels`, `Linked pull requests`,
`Milestone`, `Repository`, `Reviewers`, `Parent issue`,
`Sub-issues progress`.

`updateProjectV2Field` возвращает `success` при попытке rename
этих полей, но имя остаётся прежним — GitHub silently игнорирует.

**Следствие:** русифицировать можно только custom fields
(`Этап`, `Порядок`, `Зависит от`, `Срочность`, `Приоритет`,
`Тип задачи`, `Объём`, `Дедлайн`). Система принимает этот лимит —
Status остаётся на английском, workflow резолвит его через
`field_aliases.status = ["Статус", "Status"]` (первое имя = preferred,
второе = actual). Если GitHub когда-нибудь откроет rename — преferred
automatically станет actual.

### 2.11. Не изменяем

- `.github/workflows/board-automation.yml` — владеет переходами
  `В работе → На ревью → Одобрено → Готово`, хорошо работает, трогать опасно.
- Существующие 4 custom fields (`Приоритет`, `Тип задачи`, `Объём`,
  `Дедлайн`) — не удаляются. `Дедлайн` остаётся **информационным**, не
  триггером автоматики.
- Existing status options (`📥 Бэклог`, `📋 К работе`, ...) — ID не меняются.
- CodeQL, CI, uptime-check workflows — вне scope.

---

## 3. Alternatives considered

### A. Sub-issues как зависимости

Отклонено: sub-issues моделируют containment (часть-целое), не sequence.
Issue A не может зависеть от issue B, если они разного уровня иерархии.

### B. Milestones вместо Этап-label

Отклонено: milestones дублируют функцию этапа, но не позволяют
cross-filtering с другими полями. Один issue может относиться к одному
milestone → теряется гибкость multi-label.

### C. Хардкод field IDs в workflow

Отклонено: хрупкость. Ручное пересоздание поля ломает workflow; миграция
между проектами невозможна.

### D. Отдельный репозиторий для `board` модуля

Отклонено: избыточная сложность для 5-person команды. Модуль остаётся
в репо проекта, но изолирован папкой.

### E. Deadline-based триггеры автоматики

Отклонено: противоречит природе проекта — сроки плавают, реальный
прогресс — событийный («закончили → разблокировалось следующее»).

---

## 4. Impact

**Что меняется для участников:**

- Все новые issues создаются **только через шаблоны** (`.github/ISSUE_TEMPLATE/*.yml`)
- Каждый шаблон требует явный выбор `Роль` и `Этап` (required dropdown)
- Depends on — текстовое поле формата `#N, #M` — заполняется в шаблоне (optional)
- После создания issue автоматически: assignee, labels, попадание на доску,
  статус `К работе` / `Blocked`

**Что меняется для меня (AI-агента):**

Добавлены 3 обязательных memory-файла, определяющих regime audit:
- `reference_documentation_sources.md` — список source-of-truth документов
- `feedback_board_audit_routine.md` — регламент еженедельного audit
- `project_board_architecture.md` — ссылка на этот ADR + правила полей

---

## 5. Rollback plan

В случае критической проблемы:

1. Отключить workflow:
   ```bash
   gh workflow disable issue-automation.yml
   ```
2. Если нужен полный откат:
   ```bash
   git revert <commit_sha>    # PR с этим ADR
   rm -rf .github/board
   rm .github/workflows/issue-automation.yml
   ```
3. Ручное снятие `role:*` / `этап:*` labels через UI или `gh label delete`.
4. Project v2 custom fields (`Этап`, `Depends on`, `Order`) — удалить
   через Projects UI → Settings → Fields. `🚫 Blocked` status option
   — там же.

Откат безопасен: основной код проекта не зависит от доски.

---

## 6. Связанные ссылки

- [.github/board/README.md](../../.github/board/README.md) — модуль, entry point
- [.github/board/config.yml](../../.github/board/config.yml) — single source-of-truth
- [.github/workflows/issue-automation.yml](../../.github/workflows/issue-automation.yml) — workflow
- [.github/board/scripts/](../../.github/board/scripts/) — idempotent scripts
- [CONTRIBUTING.md § Dependencies + Auto-assign](../../.github/CONTRIBUTING.md)
- [role-backlog-v1.2.md](../audit/role-backlog-v1.2.md) — откуда извлекаются задачи при audit
- [preconditions-tracker.md](../audit/preconditions-tracker.md) — prod-release блокеры
