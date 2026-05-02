# frozen_string_literal: true

require_relative "content"

module DrakonRuby
  # Подписи callout на полотне → строки комментариев в начале потока (не в графе рёбер).
  module CalloutComments
    module_function

    # Текст для вставки в начало тела метода (без отступа).
    def prefix_source(items)
      buf = +""
      callout_nodes(items).each do |_nid, n|
        txt = Content.block_code(n["content"].to_s)
        next if txt.strip.empty?

        txt.each_line { |ln| buf << "# #{ln.rstrip}\n" }
      end
      buf
    end

    # Префикс с отступом для тела `def call(ctx)`.
    def indented_prefix(items, pad)
      pfx = prefix_source(items)
      return "" if pfx.empty?

      pfx.lines.map { |ln| "#{pad}#{ln}" }.join
    end

    def callout_nodes(items)
      items.select { |_, n| n.is_a?(Hash) && n["type"].to_s == "callout" }.sort_by { |id, _| sort_key(id) }
    end

    def sort_key(id)
      id.to_s.match?(/^\d+$/) ? id.to_i : id.to_s
    end
  end
end
