# drakon-ruby

Транслятор из языка **ДРАКОН** (JSON-граф из редактора) в **Ruby**.

**Узлы (канонический тип после разбора):** `action`, `question`, `branch`, `address`, `comment`, `end`.

**Нормализация типов редактора:** `beginend` → `end`; `insertion`, `pause`, `timer`, `shelf`, `process`, `input`, `output` → `action`; `comment`, `commentin`, `commentout` → `comment` (текст → строки `# …`); `loopstart` → `branch`; бинарный `select` или бинарный `case` (есть `one`/`two`, нет `three`) → `question`.

Дополнительные поля переходов `three` … `twelve` и массив/хеш `cases` учитываются при разрешении стартового узла и обходе графа (`Edges`).

Текст внутри блоков (`content`, при необходимости `link` у вопроса) трактуется как **исполняемый Ruby**; генератор **склеивает** фрагменты по рёбрам графа: последовательность действий, `if (условие) … else … end`, без добавления своей логики. Если экспорт оборачивает код в HTML (`<p>…</p>`), обёртка снимается, переводы строк между абзацами сохраняются.

Для **ациклических** схем получается класс в стиле сервис-объекта: **`DoThing.call(ctx)`** или **`DoThing.call(flag: true)`** (без `ctx` задаётся `OpenStruct` из kwargs). Внутри: `def self.call(ctx = nil, **kwargs)`, экземплярный **`call(ctx)`**. Если в графе есть **цикл**, используется машина состояний по id узлов — тот же внешний `.call`.

### Силуэт (silhouette)

Ветка — `type: "branch"`, переход к следующей части — `type: "address"` (поле `one`). Заголовок ветки задаёт **имя метода** Ruby (текст блока → безопасное имя; пустой заголовок → `segment_N`). Каждая «полоса» силуэта до следующего `address` генерируется как **отдельный метод**; точка входа вызывает метод первой ветки, в конце ветки вызывается метод следующей. Узлы `branch`/`address` сами по себе код не добавляют — только границы склейки. Признак силуэта см. `Document#silhouette?`.

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
