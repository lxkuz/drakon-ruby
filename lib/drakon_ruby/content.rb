# frozen_string_literal: true

require "cgi"

module DrakonRuby
  # Текст узлов ДРАКОН: по умолчанию это уже Ruby-код внутри блока; генератор только склеивает его с if/else и порядком.
  module Content
    module_function

    # Устаревшее «сплющивание» для совместимости тестов; для нового кода см. block_code / action_body.
    def strip_html(str)
      return "" if str.nil? || str.to_s.empty?

      plain = str.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip
      CGI.unescapeHTML(plain)
    end

    # Поле content у action — исполняемый Ruby (возможна HTML-обёртка редактора).
    def action_body(node)
      block_code(node.is_a?(Hash) ? node["content"] : node)
    end

    # Строка блока как код: без разметки — как есть; с тегами — снимаем обёртку, сохраняя переводы строк.
    def block_code(str)
      s = str.to_s
      return "" if s.strip.empty?

      return s.strip unless s.include?("<")

      unwrap_editor_markup(s)
    end

    # У вопроса: выражение для if — link при наличии, иначе content (оба как block_code).
    def question_condition(node)
      return "" unless node.is_a?(Hash)

      link = node["link"]
      if link.is_a?(String)
        c = block_code(link)
        return c unless c.empty?
      end

      block_code(node["content"].to_s)
    end

    def unwrap_editor_markup(s)
      t = CGI.unescapeHTML(s)
      t = t.gsub(%r{</p>\s*<p[^>]*>}i, "\n").gsub(%r{<br\s*/?>}i, "\n")
      t = t.gsub(/<[^>]+>/m, "")
      t.lines.map(&:rstrip).join("\n").strip
    end

    # Комментарий ДРАКОН → строки Ruby-комментариев (без завершающего \n).
    def comment_block(node)
      c = block_code(node.is_a?(Hash) ? node["content"] : node.to_s)
      return "" if c.strip.empty?

      c.lines.map { |ln| "# #{ln.rstrip}".rstrip }.join("\n")
    end
  end
end
