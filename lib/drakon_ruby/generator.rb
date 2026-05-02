# frozen_string_literal: true

require_relative "callout_comments"
require_relative "choice"
require_relative "content"
require_relative "insertion"
require_relative "service_object"

module DrakonRuby
  # Emits a Ruby class with a state-machine method so arbitrary branches and cycles work.
  class Generator
    INDENT = "  "

    def initialize(document)
      @doc = document
      @items = document.items
      @start = document.start_id.to_s
      @helper_defs = []
      @helper_counter = 0
    end

    def ruby_source(class_name:, method_name: "call")
      cn = class_name.to_s
      mn = method_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

      lines = +ServiceObject::FILE_PREFIX
      lines << "class #{cn}\n"
      lines << ServiceObject.class_call_method(mn, INDENT)
      lines << "#{INDENT}def #{mn}(ctx)\n"
      lines << CalloutComments.indented_prefix(@items, INDENT * 2)
      lines << "#{INDENT * 2}state = #{@start.inspect}\n"
      lines << "#{INDENT * 2}loop do\n"
      lines << "#{INDENT * 3}case state\n"
      ordered_ids.each do |nid|
        lines << emit_when(nid, @items[nid])
      end
      lines << "#{INDENT * 3}else\n"
      lines << "#{INDENT * 4}raise \"invalid state: \#{state.inspect}\"\n"
      lines << "#{INDENT * 3}end\n"
      lines << "#{INDENT * 2}end\n"
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

    def ordered_ids
      @items.keys.reject { |id| skippable_state_id?(id) }.sort do |a, b|
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
    end

    def skippable_state_id?(id)
      t = @items[id]["type"].to_s
      return true if t == "callout"

      false
    end

    def emit_when(nid, node)
      type = node["type"].to_s
      body = case type
             when "action" then emit_action(node)
             when "comment" then emit_comment(node)
             when "branch", "address" then emit_silhouette_jump(node)
             when "question" then emit_question(node)
             when "select" then emit_select_dispatch(node, nid)
             when "case" then emit_case_jump(node)
             when "simple_input" then emit_simple_io_sm(node, :input)
             when "simple_output" then emit_simple_io_sm(node, :output)
             when "insertion" then emit_insertion_sm(node)
             when "pause" then emit_pause_sm(node)
             when "parallel" then emit_parallel_sm(node)
             when "end" then emit_end
             else
               raise Error, "unhandled type #{type.inspect} at #{nid}"
             end

      "#{INDENT * 3}when #{nid.inspect} then\n#{body}"
    end

    def emit_case_jump(node)
      dest = node["one"].to_s
      "#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_select_dispatch(node, nid)
      chain = Choice.case_chain(@items, nid)
      expr = Choice.discriminator_expr(node)
      i4 = INDENT * 4
      i5 = INDENT * 5
      buf = +"#{i4}case #{expr}\n"
      chain.each do |cid|
        c = @items[cid]
        terms = Choice.when_clause_terms(c)
        dest = c["one"].to_s
        buf << "#{i4}when #{Choice.format_when_terms(terms)}\n#{i5}state = #{dest.inspect}\n"
      end
      buf << "#{i4}else\n#{i5}raise ArgumentError, \"no matching case branch\"\n#{i4}end\n"
      buf
    end

    def emit_simple_io_sm(node, kind)
      dest = node["one"].to_s
      @helper_counter += 1
      prefix = kind == :input ? "simple_input" : "simple_output"
      name = "#{prefix}_#{@helper_counter}"
      body_text = Content.block_code(node["content"].to_s)
      comment = body_text.strip.empty? ? "# (#{prefix})" : body_text.lines.map { |ln| "# #{ln.rstrip}".rstrip }.join("\n")
      defn = "#{INDENT}def #{name}(ctx)\n#{INDENT * 2}#{comment}\n#{INDENT}end\n"
      @helper_defs << defn
      "#{INDENT * 4}#{name}(ctx)\n#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_insertion_sm(node)
      dest = node["one"].to_s
      expr = Insertion.call_expr_from_node(node)
      "#{INDENT * 4}#{expr}\n#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_pause_sm(node)
      dest = node["one"].to_s
      "#{INDENT * 4}# pause\n#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_parallel_sm(node)
      dest = node["one"].to_s
      primary = Content.block_code(node["content"].to_s)
      secondary = Content.block_code(node["secondary"].to_s)
      if secondary.strip.empty?
        return emit_action(node)
      end

      i = (@helper_counter += 1)
      buf = +"#{INDENT * 4}t_pri_#{i} = Thread.new do\n"
      primary.lines.each do |raw|
        line = raw.rstrip
        next if line.strip.empty?

        buf << "#{INDENT * 5}#{line}\n"
      end
      buf << "#{INDENT * 4}end\n"
      buf << "#{INDENT * 4}t_sec_#{i} = Thread.new do\n"
      secondary.lines.each do |raw|
        line = raw.rstrip
        next if line.strip.empty?

        buf << "#{INDENT * 5}#{line}\n"
      end
      buf << "#{INDENT * 4}end\n"
      buf << "#{INDENT * 4}t_pri_#{i}.join\n"
      buf << "#{INDENT * 4}t_sec_#{i}.join\n"
      buf << "#{INDENT * 4}state = #{dest.inspect}\n"
      buf
    end

    def emit_action(node)
      dest = node["one"].to_s
      code = Content.action_body(node)
      inner = if code.strip.empty?
                ""
              else
                "#{indent_body(code, INDENT * 4)}\n"
              end
      "#{inner}#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_comment(node)
      dest = node["one"].to_s
      txt = Content.comment_block(node)
      inner = if txt.strip.empty?
                ""
              else
                "#{txt.lines.map { |ln| "#{INDENT * 4}#{ln.rstrip}" }.join("\n")}\n"
              end
      "#{inner}#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_silhouette_jump(node)
      dest = node["one"].to_s
      "#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_question(node)
      cond = Content.question_condition(node)
      one = node["one"].to_s
      two = node["two"].to_s
      i4 = INDENT * 4
      i5 = INDENT * 5
      "#{i4}if (#{cond})\n#{i5}state = #{one.inspect}\n#{i4}else\n#{i5}state = #{two.inspect}\n#{i4}end\n"
    end

    def emit_end
      "#{INDENT * 4}break\n"
    end

    def indent_body(code, base)
      code.lines.map(&:rstrip).reject { |l| l.strip.empty? && l == "\n" }.map do |line|
        stripped = line.strip
        next if stripped.empty?

        "#{base}#{stripped}"
      end.compact.join("\n")
    end
  end
end
