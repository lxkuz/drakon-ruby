# frozen_string_literal: true

require_relative "callout_comments"
require_relative "choice"
require_relative "content"
require_relative "insertion"
require_relative "silhouette_plan"
require_relative "service_object"

module DrakonRuby
  # Силуэт: каждая ветка (сегмент между address) → отдельный метод Ruby.
  class SilhouetteStructuredGenerator < StructuredGenerator
    def initialize(document)
      super(document)
      @plan = SilhouettePlan.new(document)
      @method_names = {}
    end

    def ruby_source(class_name:, method_name: "call")
      cn = class_name.to_s
      mn = method_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)
      raise Error, "invalid method name #{mn.inspect}" unless mn.match?(/\A[a-z_][a-zA-Z0-9_]*\z/)

      compute_method_names!

      lines = +ServiceObject::FILE_PREFIX
      lines << "class #{cn}\n"
      lines << ServiceObject.class_call_method(mn, INDENT)

      lines << "#{INDENT}def #{mn}(ctx)\n"
      lines << CalloutComments.indented_prefix(@items, INDENT * 2)
      lines << "#{INDENT * 2}#{@method_names[0]}(ctx)\n"
      lines << "#{INDENT}end\n"

      lines << "\n#{INDENT}private\n"

      (0...@plan.segment_count).each do |s|
        lines << "\n"
        lines << "#{INDENT}def #{@method_names[s]}(ctx)\n"
        @nest = 0
        body = emit_segment(@plan.entries[s], s, nil)
        lines << body
        lines << "#{INDENT}end\n"
      end

      unless @helper_defs.empty?
        lines << "\n"
        @helper_defs.each do |chunk|
          lines << chunk
          lines << "\n" unless chunk.end_with?("\n")
        end
      end

      lines << "end\n"
      lines
    end

    private

    def compute_method_names!
      used = {}
      (0...@plan.segment_count).each do |s|
        base = segment_label(s)
        nm = uniquify_method_name(base, used)
        @method_names[s] = nm
      end
    end

    def segment_label(s)
      ids = @plan.nodes_in(s).sort do |a, b|
        da = a.match?(/^\d+$/)
        db = b.match?(/^\d+$/)
        if da && db
          a.to_i <=> b.to_i
        elsif da
          -1
        elsif db
          1
        else
          a <=> b
        end
      end

      branches = ids.select { |id| @items[id]["type"].to_s == "branch" }
      br = branches.find do |id|
        Content.strip_html(@items[id]["content"].to_s).match?(/\S/)
      end
      br ||= branches.first

      if br
        lab = Content.strip_html(@items[br]["content"].to_s)
        return lab.match?(/\S/) ? lab : "segment_#{s}"
      end

      "segment_#{s}"
    end

    def uniquify_method_name(base, used)
      raw = sanitize_method_name(base)
      cand = raw
      i = 2
      while used[cand]
        cand = "#{raw}_#{i}"
        i += 1
      end
      used[cand] = true
      cand
    end

    def sanitize_method_name(str)
      s = str.to_s.strip
      return "segment" if s.empty?

      s = s.gsub(/\s+/, "_")
      s = s.gsub(/[^\p{L}\p{N}_]/u, "_")
      s = s.gsub(/_+/, "_").gsub(/\A_|_\z/, "")
      return "segment" if s.empty?

      s = "m_#{s}" if s.match?(/\A\d/)
      s.downcase
    end

    def emit_segment(entry, seg, stop)
      out = +""
      cur = entry.to_s
      stop = stop&.to_s

      while cur && cur != stop
        verify_in_segment!(cur, seg)

        node = @items[cur] || raise(Error, "missing #{cur}")
        type = node["type"].to_s

        case type
        when "action"
          emit_action_lines(out, node)
          cur = node["one"].to_s
        when "comment"
          txt = Content.comment_block(node)
          txt.each_line { |ln| out << indent(ln.rstrip) << "\n" } unless txt.to_s.strip.empty?

          cur = node["one"].to_s
        when "branch"
          cur = node["one"].to_s
        when "address"
          tid = node["one"].to_s
          target_seg = @plan.segment_of[tid] || raise(Error, "silhouette: address #{cur} → #{tid} без сегмента")
          callee = @method_names[target_seg] || raise(Error, "silhouette: нет метода для сегмента #{target_seg}")
          out << indent("#{callee}(ctx)") << "\n"
          break
        when "question"
          join = merge_after_question(cur, seg)
          if join
            verify_in_segment!(join, seg)
          end

          cond = Content.question_condition(node)
          out << indent("if (#{cond})") << "\n"
          @nest += 1
          out << emit_segment(node["one"].to_s, seg, join)
          @nest -= 1
          out << indent("else") << "\n"
          @nest += 1
          out << emit_segment(node["two"].to_s, seg, join)
          @nest -= 1
          out << indent("end") << "\n"
          cur = join
        when "select"
          chain = Choice.case_chain(@items, cur)
          join = Choice.merge_after_cases(@items, chain)
          verify_in_segment!(join, seg)

          expr = Choice.discriminator_expr(node)
          out << indent("case #{expr}") << "\n"
          chain.each do |cid|
            cnode = @items[cid]
            terms = Choice.when_clause_terms(cnode)
            out << indent("when #{Choice.format_when_terms(terms)}") << "\n"
            @nest += 1
            out << emit_segment(cnode["one"].to_s, seg, join)
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
          out << indent("return") << "\n"
          break
        else
          raise Error, "silhouette codegen: тип #{type.inspect} в узле #{cur}"
        end
      end

      out
    end

    def verify_in_segment!(id, seg)
      got = @plan.segment_of[id.to_s]
      return if got == seg

      raise Error, "silhouette: узел #{id} ожидался в сегменте #{seg}, фактически #{got.inspect}"
    end

    # Точка слияния после question только внутри текущей полосы силуэта; рукава «да/нет» не считаем merge.
    # Если рукава уходят по address в другие полосы — общего узла нет, join = nil.
    def merge_after_question(qid, seg)
      node = @items[qid]
      y = node["one"].to_s
      n = node["two"].to_s

      dy = Choice.bfs_dist(y, @items)
      dn = Choice.bfs_dist(n, @items)
      common = dy.keys & dn.keys
      candidates = common.select do |c|
        cid = c.to_s
        @plan.segment_of[cid] == seg && cid != y && cid != n
      end
      return nil if candidates.empty?

      candidates.min_by do |c|
        my = dy[c]
        mn = dn[c]
        [[my, mn].max, my + mn, c.to_s]
      end
    end
  end
end
