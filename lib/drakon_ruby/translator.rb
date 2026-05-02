# frozen_string_literal: true

require_relative "document"
require_relative "generator"

module DrakonRuby
  # Parses Drakon JSON and emits executable Ruby (state machine).
  class Translator
    def initialize(source)
      @source = source
    end

    # @param class_name [String, nil] Ruby class name; inferred from document id if omitted
    def to_ruby(class_name: nil)
      doc = Document.parse(@source)
      cn = class_name || infer_class_name(doc)
      Generator.new(doc).ruby_source(class_name: cn)
    end

    def ruby_class_name
      infer_class_name(Document.parse(@source))
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
