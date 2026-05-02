# frozen_string_literal: true

require_relative "document"
require_relative "insertion"

module DrakonRuby
  # Рекурсивная сборка вставляемых схем: классы зависимостей выше главного класса.
  class InsertionBundle
    def initialize(main_source, insertion_paths, class_name:, method_name:, structured:)
      @main_source = main_source
      @paths = Array(insertion_paths).compact
      @class_name = class_name
      @method_name = method_name
      @structured = structured
    end

    def prepend_to(main_ruby)
      return main_ruby if @paths.empty?

      order = collect_stems
      parts = order.map { |stem| compile_stem(stem) }
      parts.push(main_ruby)
      parts.join("\n\n")
    end

    private

    def collect_stems
      order = []
      seen = {}
      visiting = {}

      dfs = lambda do |stem|
        return if seen[stem]
        if visiting[stem]
          raise Error, "insertion: циклическая вставка схемы #{stem.inspect}"
        end

        visiting[stem] = true
        path = Insertion.resolve_path(stem, @paths)
        unless path
          visiting[stem] = false
          return
        end

        inner = File.read(path, encoding: "UTF-8")
        Document.parse(inner).items.each do |_, n|
          next unless n["type"].to_s == "insertion"

          sub = Insertion.stem_from_content(n["content"])
          dfs.call(sub) if sub && !sub.empty?
        end

        visiting[stem] = false
        seen[stem] = true
        order << stem
      end

      Document.parse(@main_source).items.each do |_, n|
        next unless n["type"].to_s == "insertion"

        stem = Insertion.stem_from_content(n["content"])
        dfs.call(stem) if stem && !stem.empty?
      end

      order
    end

    def compile_stem(stem)
      require_relative "translator"
      path = Insertion.resolve_path(stem, @paths)
      raise Error, "insertion: файл не найден для схемы #{stem.inspect} в #{@paths.inspect}" unless path

      src = File.read(path, encoding: "UTF-8")
      tr = Translator.new(src)
      tr.to_ruby(
        class_name: tr.ruby_class_name,
        method_name: @method_name,
        structured: @structured,
        insertion_paths: @paths,
        expand_insertions: false
      )
    end
  end
end
