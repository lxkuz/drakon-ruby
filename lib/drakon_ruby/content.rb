# frozen_string_literal: true

require "cgi"

module DrakonRuby
  # Strips simple HTML from Drakon node text; conditions and code in tests use plain Ruby.
  module Content
    module_function

    def strip_html(str)
      return "" if str.nil? || str.to_s.empty?

      plain = str.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
      CGI.unescapeHTML(plain)
    end

    # У экспорта ДРАКОН условие часто дублируется: HTML в content, короткая формула в link.
    def question_condition(node)
      return "" unless node.is_a?(Hash)

      link = node["link"]
      if link.is_a?(String) && !strip_html(link).empty?
        strip_html(link)
      else
        strip_html(node["content"].to_s)
      end
    end
  end
end
