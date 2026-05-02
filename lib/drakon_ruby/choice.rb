# frozen_string_literal: true

require_relative "content"
require_relative "edges"

module DrakonRuby
  # Цепочка select → case → case → … из экспорта ДРАКОН (matching-engine и др.).
  module Choice
    module_function

    # Упорядоченный список id узлов типа case, начиная с select["one"].
    def case_chain(items, select_id)
      sel = items[select_id.to_s] || raise(Error, "choice: нет select #{select_id}")
      raise Error, "choice: ожидался select, получено #{sel["type"]}" unless sel["type"].to_s == "select"

      chain = []
      cur = sel["one"].to_s
      until cur.empty?
        n = items[cur]
        break unless n && n["type"].to_s == "case"

        chain << cur
        nxt = n["two"].to_s
        break if nxt.empty?

        cur = nxt
      end
      raise Error, "choice: у select #{select_id} нет цепочки case" if chain.empty?

      chain
    end

    # Общая точка слияния всех рукавов case (как merge после question).
    def merge_after_cases(items, case_node_ids)
      targets = case_node_ids.map { |cid| items[cid.to_s]["one"].to_s }
      merge_many(items, targets)
    end

    def merge_many(items, start_ids)
      dists = start_ids.map { |s| bfs_dist(s, items) }
      keys = dists.map(&:keys)
      common = keys.reduce(:&)
      raise Error, "choice: не найден общий join для #{start_ids.inspect}" if common.nil? || common.empty?

      common.min_by do |c|
        mx = dists.map { |d| d[c] }.max
        [mx, dists.sum { |d| d[c] }, c.to_s]
      end
    end

    def bfs_dist(from_id, items)
      dist = { from_id.to_s => 0 }
      q = [from_id.to_s]
      until q.empty?
        id = q.shift
        d = dist[id]
        Edges.successors(id, items).each do |s|
          s = s.to_s
          next if dist.key?(s)

          dist[s] = d + 1
          q << s
        end
      end
      dist
    end

    # Выражение для case expr; при подписи-заголовке («Side») — ctx.side и т.п.
    def discriminator_expr(select_node)
      raw = Content.block_code(select_node["content"]).strip
      return raw if ruby_discriminator?(raw)

      slug = label_to_ctx_slug(raw)
      "ctx.#{slug}"
    end

    def ruby_discriminator?(s)
      return false if s.empty?

      return true if s.include?("ctx.") || s.match?(/\w\s*[,\[\]\)]/) # call, comma
      return true if s.include?(".") && s.match?(/[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_]/)
      return true if s.start_with?("@")
      return true if s.match?(/\A[a-z_][a-z0-9_]*\z/) && !short_title?(s)

      false
    end

    def short_title?(s)
      s.match?(/\A[A-Za-z][a-z]*\z/) && s.length <= 12 && s[0] == s[0].upcase
    end

    def label_to_ctx_slug(label)
      s = Content.strip_html(label.to_s)
      s = s.gsub(/[^\p{L}\p{N}]+/u, "_").downcase
      s = s.gsub(/_+/, "_").gsub(/\A_|_\z/, "")
      return "switch" if s.empty?

      s
    end

    # Строки для when: строка и символ по подписи блока case.
    def when_clause_terms(case_node)
      label = Content.strip_html(case_node["content"].to_s).strip
      return ['""'] if label.empty?

      terms = [label.inspect]
      sym = label.gsub(/[^\p{L}\p{N}_]/u, "_").downcase
      sym = sym.gsub(/_+/, "_").gsub(/\A_|_\z/, "")
      if sym.match?(/\A[a-z_][a-z0-9_]*\z/)
        terms << ":#{sym}" unless terms.include?(":#{sym}")
      end
      terms.uniq
    end

    def format_when_terms(terms)
      terms.join(", ")
    end
  end
end
