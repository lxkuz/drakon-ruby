# frozen_string_literal: true

module DrakonRuby
  # Translates Drakon flowchart sources (e.g. .drakon XML) into Ruby.
  # Parser and codegen will grow here as we define the supported subset.
  class Translator
    def initialize(source)
      @source = source
    end

    def to_ruby
      raise NotImplementedError, "parse Drakon → AST → emit Ruby"
    end
  end
end
