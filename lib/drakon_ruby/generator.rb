# frozen_string_literal: true

require_relative "content"
require_relative "service_object"

module DrakonRuby
  # Emits a Ruby class with a state-machine method so arbitrary branches and cycles work.
  class Generator
    INDENT = "  "

    def initialize(document)
      @doc = document
      @items = document.items
      @start = document.start_id.to_s
    end

    def ruby_source(class_name:, method_name: "call")
      cn = class_name.to_s
      mn = method_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

      lines = +ServiceObject::FILE_PREFIX
      lines << "class #{cn}\n"
      lines << ServiceObject.class_call_method(mn, INDENT)
      lines << "#{INDENT}def #{mn}(ctx)\n"
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
      lines << "end\n"
      lines
    end

    private

    def ordered_ids
      @items.keys.sort do |a, b|
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

    def emit_when(nid, node)
      type = node["type"].to_s
      body = case type
             when "action" then emit_action(node)
             when "comment" then emit_comment(node)
             when "branch", "address" then emit_silhouette_jump(node)
             when "question" then emit_question(node)
             when "end" then emit_end
             else
               raise Error, "unhandled type #{type.inspect} at #{nid}"
             end

      "#{INDENT * 3}when #{nid.inspect} then\n#{body}"
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
