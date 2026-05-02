# frozen_string_literal: true

require_relative "document"
require_relative "generator"
require_relative "structured_generator"
require_relative "silhouette_structured_generator"

module DrakonRuby
  # Parses Drakon JSON; код узлов склеивается в Ruby (структурно для DAG, иначе машина состояний).
  class Translator
    def initialize(source)
      @source = source
    end

    # @param class_name [String, nil] Ruby class name; inferred from document id if omitted
    # @param method_name [String] generated instance method (default + alias #run)
    # @param structured [true, false, :auto] — :auto uses structured codegen when the graph is acyclic
    def to_ruby(class_name: nil, method_name: "start", structured: :auto)
      doc = Document.parse(@source)
      cn = class_name || infer_class_name(doc)
      use_structured = case structured
                       when true then true
                       when false then false
                       else StructuredGenerator.structured?(doc)
                       end
      if use_structured && doc.silhouette?
        SilhouetteStructuredGenerator.new(doc).ruby_source(class_name: cn, method_name: method_name)
      elsif use_structured
        StructuredGenerator.new(doc).ruby_source(class_name: cn, method_name: method_name)
      else
        Generator.new(doc).ruby_source(class_name: cn, method_name: method_name)
      end
    end

    def ruby_class_name
      infer_class_name(Document.parse(@source))
    end

    def silhouette?
      Document.parse(@source).silhouette?
    end

    private

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
