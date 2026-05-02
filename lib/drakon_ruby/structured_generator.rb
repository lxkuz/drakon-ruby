# frozen_string_literal: true

require_relative "content"

module DrakonRuby
  # Ациклические схемы: код из полей узлов склеивается с if/else/end и порядком рёбер — без лишней семантики.
  class StructuredGenerator
    INDENT = "  "

    class << self
      def structured?(document)
        acyclic?(document)
      end

      def acyclic?(document)
        marks = {}
        items = document.items
        start = document.start_id.to_s

        dfs = lambda do |id|
          case marks[id]
          when :visiting
            return false
          when :done
            return true
          end
          marks[id] = :visiting
          successors(id, items).each do |s|
            return false unless dfs.call(s)
          end
          marks[id] = :done
          true
        end

        dfs.call(start)
      end

      def successors(id, items)
        n = items[id.to_s] || items[id]
        return [] unless n.is_a?(Hash)

        case n["type"].to_s
        when "action", "branch", "address"
          [n["one"]].compact.map(&:to_s)
        when "question"
          [n["one"], n["two"]].compact.map(&:to_s)
        when "end"
          []
        else
          []
        end
      end
    end

    def initialize(document)
      @doc = document
      @items = document.items
      @nest = 0
    end

    def ruby_source(class_name:, method_name: "start")
      cn = class_name.to_s
      mn = method_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)
      raise Error, "invalid method name #{mn.inspect}" unless mn.match?(/\A[a-z_][a-zA-Z0-9_]*\z/)

      body = emit_block(@doc.start_id.to_s, nil)

      lines = +"# frozen_string_literal: true\n\n"
      lines << "class #{cn}\n"
      lines << "#{INDENT}def #{mn}(ctx)\n"
      lines << body
      lines << "#{INDENT}end\n"
      lines << "#{INDENT}alias_method :run, :#{mn}\n"
      lines << "end\n"
      lines
    end

    private

    def emit_block(entry, stop)
      out = +""
      cur = entry.to_s
      stop = stop&.to_s

      while cur && cur != stop
        node = @items[cur] || raise(Error, "missing node #{cur.inspect}")
        type = node["type"].to_s

        case type
        when "action"
          emit_action_lines(out, node)
          cur = node["one"].to_s
        when "branch", "address"
          cur = node["one"].to_s
        when "question"
          join = merge_for_question(cur)
          cond = Content.question_condition(node)
          out << indent("if (#{cond})") << "\n"
          @nest += 1
          out << emit_block(node["one"].to_s, join)
          @nest -= 1
          out << indent("else") << "\n"
          @nest += 1
          out << emit_block(node["two"].to_s, join)
          @nest -= 1
          out << indent("end") << "\n"
          cur = join
        when "end"
          break
        else
          raise Error, "structured codegen: unsupported type #{type.inspect} at #{cur}"
        end
      end

      out
    end

    def emit_action_lines(out, node)
      code = Content.action_body(node)
      return if code.strip.empty?

      code.lines.each do |raw|
        line = raw.rstrip
        next if line.strip.empty?

        out << indent(line) << "\n"
      end
    end

    def merge_for_question(qid)
      node = @items[qid]
      y = node["one"].to_s
      n = node["two"].to_s
      dy = bfs_dist(y)
      dn = bfs_dist(n)
      common = dy.keys & dn.keys
      raise Error, "structured codegen: cannot find join after question #{qid}" if common.empty?

      common.min_by do |c|
        my = dy[c]
        mn = dn[c]
        [ [my, mn].max, my + mn, c.to_s ]
      end
    end

    def bfs_dist(from_id)
      dist = { from_id => 0 }
      q = [from_id]
      until q.empty?
        id = q.shift
        d = dist[id]
        self.class.successors(id, @items).each do |s|
          next if dist.key?(s)

          dist[s] = d + 1
          q << s
        end
      end
      dist
    end

    # +2: отступ тела метода (после class + def).
    def indent(line)
      INDENT * (2 + @nest) + line
    end
  end
end
