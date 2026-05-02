# frozen_string_literal: true

require_relative "document"
require_relative "generator"
require_relative "structured_generator"
require_relative "silhouette_structured_generator"
require_relative "insertion_bundle"

module DrakonRuby
  # Parses Drakon JSON; код узлов склеивается в Ruby (структурно для DAG, иначе машина состояний).
  class Translator
    def initialize(source)
      @source = source
    end

    # @param class_name [String, nil] Ruby class name; inferred from document id if omitted
    # @param method_name [String] generated instance method (default call)
    # @param structured [true, false, :auto] — :auto uses structured codegen when the graph is acyclic
    # @param insertion_paths [Array<String>] каталоги для поиска вставляемых .drakon по имени из insertion
    # @param main_source_path [String, nil] если задан, в начало путей добавляется каталог этого файла (как у CLI)
    # @param expand_insertions [Boolean] собрать зависимые классы выше основного (рекурсивно)
    def to_ruby(class_name: nil, method_name: "call", structured: :auto, insertion_paths: [], expand_insertions: true,
                main_source_path: nil)
      doc = Document.parse(@source)
      cn = class_name || infer_class_name(doc)
      use_structured = case structured
                       when true then true
                       when false then false
                       else StructuredGenerator.structured?(doc)
                       end
      raw = doc.raw
      explicit_silhouette = raw["silhouette"] == true || raw["diagramKind"].to_s == "silhouette"
      # Методы по полосам — только при явном флаге в JSON (иначе Matching.drakon с циклами уходит сюда и рвёт стек).
      inner = if structured == false
                Generator.new(doc).ruby_source(class_name: cn, method_name: method_name)
              elsif explicit_silhouette
                SilhouetteStructuredGenerator.new(doc).ruby_source(class_name: cn, method_name: method_name)
              elsif use_structured
                StructuredGenerator.new(doc).ruby_source(class_name: cn, method_name: method_name)
              else
                Generator.new(doc).ruby_source(class_name: cn, method_name: method_name)
              end
      paths = merge_insertion_paths(insertion_paths, main_source_path)
      if expand_insertions && paths.any?
        inner = InsertionBundle.new(
          @source,
          paths,
          class_name: cn,
          method_name: method_name,
          structured: structured
        ).prepend_to(inner)
      end
      inner
    end

    def ruby_class_name
      infer_class_name(Document.parse(@source))
    end

    def silhouette?
      Document.parse(@source).silhouette?
    end

    private

    def merge_insertion_paths(insertion_paths, main_source_path)
      paths = Array(insertion_paths).compact
      if main_source_path && !main_source_path.to_s.strip.empty?
        d = File.dirname(File.expand_path(main_source_path))
        paths = [d] + paths
      end
      paths.uniq
    end

    def infer_class_name(doc)
      s = doc.id.to_s.sub(/\.(drakon|json)\z/i, "")
      parts = s.split(/[^a-zA-Z0-9]+/).reject(&:empty?)
      base = parts.map { |p| p[0].upcase + p[1..] }.join
      base = "DrakonFlow" if base.empty?
      base = "Drakon#{base}" if base.match?(/\A\d/)
      base
    end
  end
end
