# drakon-ruby

Транслятор из языка **ДРАКОН** (JSON-граф из редактора: узлы `action`, `question`, `branch`, `end`) в **Ruby**.

Схема компилируется в класс с методом `run(ctx)`: внутри — машина состояний по id узлов, чтобы корректно обрабатывать ветвления и циклы.

В полях **`content`** для тестов и генерации допустим **валидный Ruby**: тело действия подставляется как есть; для `question` текст очищается от простых HTML-тегов и используется как условие в `if` (ветка «да» → `one`, «нет» → `two`).

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

- `lib/drakon_ruby/document.rb` — разбор JSON, старт, проверки
- `lib/drakon_ruby/generator.rb` — генерация `case state` / `loop`
- `lib/drakon_ruby/translator.rb` — `to_ruby`, имя класса по полю `id`
- `exe/drakon2rb` — CLI

## Лицензия

По согласованию с авторами — отдельный файл лицензии при необходимости.
