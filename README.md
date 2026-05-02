# drakon-ruby

Транслятор из языка **ДРАКОН** (JSON-граф из редактора) в **Ruby**. Поддерживаются узлы: `action`, `question`, `branch`, `address`, `end` (и нормализация `beginend` → `end`).

Текст внутри блоков (`content`, при необходимости `link` у вопроса) трактуется как **исполняемый Ruby**; генератор **склеивает** фрагменты по рёбрам графа: последовательность действий, `if (условие) … else … end`, без добавления своей логики. Если экспорт оборачивает код в HTML (`<p>…</p>`), обёртка снимается, переводы строк между абзацами сохраняются.

Для **ациклических** схем получается обычный читаемый Ruby (`def start(ctx)` и `alias run`). Если в графе есть **цикл**, используется машина состояний по id узлов.

### Силуэт (silhouette)

Ветка — `type: "branch"`, переход к следующей части — `type: "address"` (поле `one`). Эти узлы **не вставляют** свой текст в целевой код: только задают порядок склейки. Признак силуэта в JSON (`silhouette`, несколько `branch`, наличие `address`) см. `Document#silhouette?`.

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

На выходе — исходный текст Ruby (класс). Вход: JSON (как в примерах `test/fixtures/*.drakon`). Опционально в корне JSON: поле `"start": "id"` — с какого узла начинать, если нельзя однозначно вывести старт.

## Тесты

```bash
cd drakon-ruby
bundle exec rake test
# или
ruby -Ilib:test -e "Dir['test/**/*_test.rb'].each { require _1 }"
```

В `test/fixtures` лежат схемы; `test/drakon_ruby/flow_scenarios_test.rb` и др. читают JSON, генерируют Ruby, `module_eval` и проверяют `ctx` после `run(ctx)`.

## Разработка

- `lib/drakon_ruby/document.rb` — разбор JSON, старт, проверки, силуэт, нормализация типов
- `lib/drakon_ruby/generator.rb` — генерация `case state` / `loop`
- `lib/drakon_ruby/translator.rb` — `to_ruby`, имя класса по полю `id`
- `exe/drakon2rb` — CLI

## Лицензия

По согласованию с авторами — отдельный файл лицензии при необходимости.
