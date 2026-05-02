# frozen_string_literal: true

module DrakonRuby
  # Strips simple HTML from Drakon node text; conditions and code in tests use plain Ruby.
  module Content
    module_function

    def strip_html(str)
      return "" if str.nil? || str.to_s.empty?

      str.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
    end
  end
end
