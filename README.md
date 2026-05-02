# drakon-ruby

Транслятор из языка **ДРАКОН** (JSON-граф из редактора) в **Ruby**.

**Узлы (канонический тип после разбора):** `action`, `question`, `branch`, `address`, `comment`, `end`.

**Нормализация типов редактора:** `beginend` → `end`; `insertion`, `pause`, `timer`, `shelf`, `process`, `input`, `output` → `action`; `comment`, `commentin`, `commentout` → `comment` (текст → строки `# …`); `loopstart` → `branch`; бинарный `select` или бинарный `case` (есть `one`/`two`, нет `three`) → `question`.

Дополнительные поля переходов `three` … `twelve` и массив/хеш `cases` учитываются при разрешении стартового узла и обходе графа (`Edges`).

Текст внутри блоков (`content`, при необходимости `link` у вопроса) трактуется как **исполняемый Ruby**; генератор **склеивает** фрагменты по рёбрам графа: последовательность действий, `if (условие) … else … end`, без добавления своей логики. Если экспорт оборачивает код в HTML (`<p>…</p>`), обёртка снимается, переводы строк между абзацами сохраняются.

Для **ациклических** схем получается класс в стиле сервис-объекта: **`DoThing.call(ctx)`** или **`DoThing.call(flag: true)`** (без `ctx` задаётся `OpenStruct` из kwargs). Внутри: `def self.call(ctx = nil, **kwargs)`, экземплярный **`call(ctx)`**. Если в графе есть **цикл**, используется машина состояний по id узлов — тот же внешний `.call`.

### Силуэт (silhouette)

Ветка — `type: "branch"`, переход к следующей части — `type: "address"` (поле `one`). Заголовок ветки задаёт **имя метода** Ruby (текст блока → безопасное имя; пустой заголовок → `segment_N`). Каждая «полоса» силуэта до следующего `address` становится **отдельным приватным методом** класса-сервиса (`private`); снаружи доступны только **`self.call`** и публичный экземплярный **`call(ctx)`**, который вызывает метод первой ветки, а цепочка веток вызывает следующий приватный метод. Узлы `branch`/`address` сами по себе код не добавляют — только границы склейки. Признак силуэта см. `Document#silhouette?`.

У **question** ветка «да» — `one`, «нет» — `two`; выражение для `if` берётся из непустого **`link`**, иначе из **`content`** (после снятия разметки при необходимости).

## Установка из исходников

```bash
cd drakon-ruby
bundle install
ruby exe/drakon2rb path/to/file.drakon
```

После публикации гема: `gem install drakon_ruby` (и `drakon2rb` окажется в `PATH`).

## Использование

```bash
drakon2rb схема.drakon
```

На выходе — исходный текст Ruby (класс с `.call`). Вход: JSON (как в примерах `test/fixtures/*.drakon`). Опционально в корне JSON: поле `"start": "id"` — с какого узла начинать, если нельзя однозначно вывести старт.

Пример вызова: `Linear.call(ctx)` или `Linear.call(user_id: 1)` (внутри схемы — `ctx.user_id`). Имя экземплярного метода-входа можно сменить опцией транслятора `method_name:`; **класс** `.call` остаётся точкой входа.

### Каталог `examples/`

Готовые схемы для редактора и CLI лежат в **`examples/`**.

**Вложенная диаграмма (insertion)**

- `examples/linear.drakon` — дочерняя схема (печатает `a`, затем `b`).
- `examples/parent_with_insertion.drakon` — родитель: узел вставки с текстом **linear** подтягивает ту же схему по имени файла `linear.drakon` в том же каталоге.

```bash
ruby exe/drakon2rb examples/parent_with_insertion.drakon -o examples/parent_with_insertion.rb
```

Рядом с входным файлом каталог ищется автоматически; при необходимости добавьте `-I /path/to/dir`.

**Docker:** образ собирает **`lib/` при сборке** — после правок в коде выполните `docker compose build drakon2rb`.

- Схема **внутри репозитория** (как раньше): из корня проекта  
  `docker compose run --rm drakon2rb examples/linear.drakon -o examples/linear.rb`
- Схема **где угодно на диске** — скрипт монтирует только каталог вашего файла:

```bash
./scripts/docker-drakon2rb ~/Documents/myflow.drakon -o myflow.rb
```

Путь к `.drakon` может быть абсолютным или относительным **текущего каталога** в терминале. **`-o`** — любой путь на вашей машине (рядом со схемой или в другом каталоге): скрипт монтирует нужные каталоги на хосте в контейнер, и Ruby пишется **на диск хоста**, а не во временный слой образа. Каталоги `-I` скрипт тоже монтирует сам.

**Силуэт (`tes_s.drakon`)**

Три полосы (Init → Process → Done), между полосами узлы **`address`**, цикл «не оплачен» возвращает на полосу Process. Чтобы получить **отдельные приватные методы по полосам**, в корне JSON нужно **`"silhouette": true`** (или `"diagramKind": "silhouette"`). Без этого похожая схема с несколькими `branch` может уйти в обычный структурный код или машину состояний.

```bash
ruby exe/drakon2rb examples/tes_s.drakon -o examples/test_s.rb
```

**Зачем нужен `test/fixtures/string_ids.drakon`**

Это тест транслятора: идентификаторы узлов — произвольные строки (`br`, `a`, `b`…), не только `"1"`, `"2"`. В DrakonHub удобнее числовые id; на логику схемы это не влияет.

**Совместимость с DrakonHub (кратко)**

| Файл в `test/fixtures` | Заметки |
|------------------------|---------|
| **parallel_demo** | В экспорте DrakonHub параллель/процесс — тип **`process`**, поля `content`, `secondary`, `one`. |
| **aliases** | Узел **pause** с пустым текстом выглядит как пустая трапеция; в фикстуре задан подписанный текст «пауза». |
| **silhouette_two_branches** | Нужна привычная оболочка **`1` = End, `2` = Branch**, затем заголовки силуэта; без этого редактор может не открыть файл. |
| **loop_counter** | Цикл «вопрос → действие → снова вопрос» валиден для транслятора; при ошибке импорта в Hub проверьте условие в `<p>` (оператор `<` у края `</p>`). |

## Примеры: схема ДРАКОН (JSON) и сгенерированный Ruby

Файл `.drakon` — это JSON с полем `items`: узлы по id, у каждого `type` и переходы (`one`, `two`, …) на следующий id. Текст в `content` — исполняемый Ruby.

### Линейная цепочка

Условная «картинка» потока (сверху вниз, как в редакторе ДРАКОН):

```
  начало
    │
    ▼
 ┌──────────┐
 │ puts :a  │
 └────┬─────┘
      │
      ▼
 ┌──────────┐
 │ puts :b  │
 └────┬─────┘
      │
      ▼
   конец
```

Фрагмент JSON (`id` схемы задаёт имя класса `Linear`):

```json
{
  "type": "drakon",
  "id": "linear",
  "items": {
    "1": { "type": "action", "content": "puts :a", "one": "2" },
    "2": { "type": "action", "content": "puts :b", "one": "3" },
    "3": { "type": "end" }
  }
}
```

Результат `drakon2rb linear.drakon` (или `Translator#to_ruby`):

```ruby
# frozen_string_literal: true

require "ostruct"

class Linear
  def self.call(ctx = nil, **kwargs)
    ctx ||= OpenStruct.new(**kwargs)
    new.call(ctx)
  end

  def call(ctx)
    puts :a
    puts :b
  end
end
```

Запуск:

```ruby
Linear.call                    # stdout: "a\nb\n"
Linear.call(OpenStruct.new)    # то же
```

### Ветвление и слияние (question → if / else)

```
              ┌── да ──► [ puts :from_left  ] ──┐
  ctx.left?   │                                  ├──► [ puts :merged ] ─► конец
              └── нет ► [ puts :from_right ] ──┘
```

JSON:

```json
{
  "type": "drakon",
  "id": "merge_paths",
  "items": {
    "1": { "type": "question", "content": "ctx.left", "one": "2", "two": "3", "flag1": 1 },
    "2": { "type": "action", "content": "puts :from_left", "one": "4" },
    "3": { "type": "action", "content": "puts :from_right", "one": "4" },
    "4": { "type": "action", "content": "puts :merged", "one": "5" },
    "5": { "type": "end" }
  }
}
```

Сгенерированный Ruby:

```ruby
class MergePaths
  def self.call(ctx = nil, **kwargs)
    ctx ||= OpenStruct.new(**kwargs)
    new.call(ctx)
  end

  def call(ctx)
    if (ctx.left)
      puts :from_left
    else
      puts :from_right
    end
    puts :merged
  end
end
```

### Силуэт: полосы веток как приватные методы

В JSON у корня задаётся `"silhouette": true`. Участки между `branch` и следующим `address` компилируются в **`private def имя_полосы(ctx)`**; пустой заголовок ветки даёт имя вида `segment_1`.

Схема потока (две полосы, одна под другой):

```
  ┌─ branch «Первая ветка» ─────────────────┐
  │  [ puts :branch_a ]                    │
  └───────────────────┬────────────────────┘
                      │
        address «Вторая ветка»
                      │
  ┌─ branch (без текста → segment_…) ─────┐
  │  [ puts :branch_b ]                    │
  └───────────────────┬────────────────────┘
                      ▼
                    конец
```

Файл `test/fixtures/silhouette_two_branches.drakon`:

```json
{
  "type": "drakon",
  "id": "silhouette_two_branches",
  "silhouette": true,
  "items": {
    "1": {
      "type": "branch",
      "branchId": 0,
      "content": "<p>Первая ветка</p>",
      "one": "2"
    },
    "2": { "type": "action", "content": "puts :branch_a", "one": "3" },
    "3": {
      "type": "address",
      "content": "<p>Вторая ветка</p>",
      "one": "4"
    },
    "4": { "type": "branch", "branchId": 1, "content": "", "one": "5" },
    "5": { "type": "action", "content": "puts :branch_b", "one": "6" },
    "6": { "type": "end" }
  }
}
```

Сгенерированный Ruby:

```ruby
# frozen_string_literal: true

require "ostruct"

class SilhouetteTwoBranches
  def self.call(ctx = nil, **kwargs)
    ctx ||= OpenStruct.new(**kwargs)
    new.call(ctx)
  end

  def call(ctx)
    первая_ветка(ctx)
  end

  private

  def первая_ветка(ctx)
    puts :branch_a
    segment_1(ctx)
  end

  def segment_1(ctx)
    puts :branch_b
    return
  end
end
```

`SilhouetteTwoBranches.call` печатает `branch_a`, затем `branch_b` — как если бы полосы шли сверху вниз в силуэте.

### Цикл (машина состояний)

Если в графе есть **цикл**, транслятор строит обход по id узлов (`case state` внутри `loop`). Пример: счётчик и условие выхода (файл `test/fixtures/loop_counter.drakon` в репозитории).

```ruby
def call(ctx)
  state = "1"
  loop do
    case state
    when "1" then
      ctx.i = 0
      puts :start
      state = "2"
    when "2" then
      if (ctx.i < 3)
        state = "3"
      else
        state = "4"
      end
    when "3" then
      ctx.i += 1
      puts ctx.i
      state = "2"
    when "4" then
      break
    else
      raise "invalid state: #{state.inspect}"
    end
  end
end
```

Полный класс с обёрткой `.call` даёт CLI так же, как в линейном примере.

Больше готовых схем: каталог `test/fixtures/*.drakon`.

## Тесты

```bash
cd drakon-ruby
bundle exec rake test
# или
ruby -Ilib:test -e "Dir['test/**/*_test.rb'].each { require _1 }"
```

В `test/fixtures` лежат схемы; `test/drakon_ruby/flow_scenarios_test.rb` и др. читают JSON, генерируют Ruby, `module_eval`, вызывают **`call(ctx)`** и проверяют побочные эффекты (например stdout через `puts` в блоках и `capture_io` в тестах).

## Разработка

- `lib/drakon_ruby/document.rb` — разбор JSON, старт, проверки, силуэт, нормализация типов
- `lib/drakon_ruby/edges.rb` — все исходящие рёбра узла (`one`…`three`…, `cases`)
- `lib/drakon_ruby/content.rb` — тело блока, условие вопроса, комментарии
- `lib/drakon_ruby/structured_generator.rb` / `silhouette_structured_generator.rb` / `generator.rb` — склейка Ruby, силуэт как методы веток, циклы
- `lib/drakon_ruby/translator.rb` — `to_ruby`, имя класса по полю `id`
- `exe/drakon2rb` — CLI

## Лицензия

По согласованию с авторами — отдельный файл лицензии при необходимости.
