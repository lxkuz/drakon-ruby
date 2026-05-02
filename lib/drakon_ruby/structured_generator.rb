# frozen_string_literal: true

require_relative "callout_comments"
require_relative "choice"
require_relative "content"
require_relative "edges"
require_relative "insertion"
require_relative "service_object"

module DrakonRuby
  # Ациклические схемы: код из полей узлов склеивается с if/else/end, case/when и порядком рёбер.
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
        Edges.successors(id, items)
      end
    end

    def initialize(document)
      @doc = document
      @items = document.items
      @nest = 0
      @helper_defs = []
      @helper_counter = 0
    end

    def ruby_source(class_name:, method_name: "call")
      cn = class_name.to_s
      mn = method_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)
      raise Error, "invalid method name #{mn.inspect}" unless mn.match?(/\A[a-z_][a-zA-Z0-9_]*\z/)

      body = emit_block(@doc.start_id.to_s, nil)

      lines = +ServiceObject::FILE_PREFIX
      lines << "class #{cn}\n"
      lines << ServiceObject.class_call_method(mn, INDENT)
      lines << "#{INDENT}def #{mn}(ctx)\n"
      lines << CalloutComments.indented_prefix(@items, INDENT * 2)
      lines << body
      lines << "#{INDENT}end\n"
      unless @helper_defs.empty?
        lines << "\n#{INDENT}private\n\n"
        @helper_defs.each do |chunk|
          lines << chunk
          lines << "\n" unless chunk.end_with?("\n")
        end
      end
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
        when "comment"
          txt = Content.comment_block(node)
          txt.each_line { |ln| out << indent(ln.rstrip) << "\n" } unless txt.to_s.strip.empty?

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
        when "select"
          chain = Choice.case_chain(@items, cur)
          join = Choice.merge_after_cases(@items, chain)
          expr = Choice.discriminator_expr(node)
          out << indent("case #{expr}") << "\n"
          chain.each do |cid|
            cnode = @items[cid]
            terms = Choice.when_clause_terms(cnode)
            out << indent("when #{Choice.format_when_terms(terms)}") << "\n"
            @nest += 1
            out << emit_block(cnode["one"].to_s, join)
            @nest -= 1
          end
          out << indent("else") << "\n"
          @nest += 1
          out << indent('raise ArgumentError, "no matching case branch"') << "\n"
          @nest -= 1
          out << indent("end") << "\n"
          cur = join
        when "case"
          cur = node["one"].to_s
        when "simple_input"
          emit_simple_io(out, node, :input)
          cur = node["one"].to_s
        when "simple_output"
          emit_simple_io(out, node, :output)
          cur = node["one"].to_s
        when "insertion"
          out << indent(Insertion.call_expr_from_node(node)) << "\n"
          cur = node["one"].to_s
        when "pause"
          out << indent("# pause") << "\n"
          cur = node["one"].to_s
        when "parallel"
          emit_parallel(out, node)
          cur = node["one"].to_s
        when "end"
          break
        else
          raise Error, "structured codegen: unsupported type #{type.inspect} at #{cur}"
        end
      end

      out
    end

    def emit_simple_io(out, node, kind)
      @helper_counter += 1
      prefix = kind == :input ? "simple_input" : "simple_output"
      name = "#{prefix}_#{@helper_counter}"
      body_text = Content.block_code(node["content"].to_s)
      comment = body_text.strip.empty? ? "# (#{prefix})" : body_text.lines.map { |ln| "# #{ln.rstrip}".rstrip }.join("\n")
      defn = "#{INDENT}def #{name}(ctx)\n#{INDENT * 2}#{comment}\n#{INDENT}end\n"
      @helper_defs << defn
      out << indent("#{name}(ctx)") << "\n"
    end

    def emit_parallel(out, node)
      primary = Content.block_code(node["content"].to_s)
      secondary = Content.block_code(node["secondary"].to_s)
      if secondary.strip.empty?
        emit_action_lines(out, node)
        return
      end

      @helper_counter += 1
      i = @helper_counter
      out << indent("t_pri_#{i} = Thread.new do") << "\n"
      @nest += 1
      primary.lines.each do |raw|
        line = raw.rstrip
        next if line.strip.empty?

        out << indent(line) << "\n"
      end
      @nest -= 1
      out << indent("end") << "\n"
      out << indent("t_sec_#{i} = Thread.new do") << "\n"
      @nest += 1
      secondary.lines.each do |raw|
        line = raw.rstrip
        next if line.strip.empty?

        out << indent(line) << "\n"
      end
      @nest -= 1
      out << indent("end") << "\n"
      out << indent("t_pri_#{i}.join") << "\n"
      out << indent("t_sec_#{i}.join") << "\n"
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
      Choice.bfs_dist(from_id, @items)
    end

    # +2: отступ тела метода (после class + def).
    def indent(line)
      INDENT * (2 + @nest) + line
    end
  end
end
