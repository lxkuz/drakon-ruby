# frozen_string_literal: true

require_relative "content"
require_relative "silhouette_plan"

module DrakonRuby
  # Силуэт: каждая ветка (сегмент между address) → отдельный метод Ruby.
  class SilhouetteStructuredGenerator < StructuredGenerator
    def initialize(document)
      super(document)
      @plan = SilhouettePlan.new(document)
      @method_names = {}
    end

    def ruby_source(class_name:, method_name: "start")
      cn = class_name.to_s
      mn = method_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)
      raise Error, "invalid method name #{mn.inspect}" unless mn.match?(/\A[a-z_][a-zA-Z0-9_]*\z/)

      compute_method_names!

      lines = +"# frozen_string_literal: true\n\n"
      lines << "class #{cn}\n"

      lines << "#{INDENT}def #{mn}(ctx)\n"
      lines << "#{INDENT * 2}#{@method_names[0]}(ctx)\n"
      lines << "#{INDENT}end\n"

      (0...@plan.segment_count).each do |s|
        lines << "\n"
        lines << "#{INDENT}def #{@method_names[s]}(ctx)\n"
        @nest = 0
        body = emit_segment(@plan.entries[s], s, nil)
        lines << body
        lines << "#{INDENT}end\n"
      end

      lines << "\n#{INDENT}alias_method :run, :#{mn}\n"
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

      br = ids.find { |id| @items[id]["type"].to_s == "branch" }
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
          nxt = seg + 1
          callee = @method_names[nxt] || raise(Error, "silhouette: нет метода для сегмента #{nxt}")
          out << indent("#{callee}(ctx)") << "\n"
          break
        when "question"
          join = merge_for_question(cur)
          verify_in_segment!(join, seg)

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
  end
end
