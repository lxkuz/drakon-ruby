# frozen_string_literal: true

require_relative "content"

module DrakonRuby
  # Emits a Ruby class with a state-machine method so arbitrary branches and cycles work.
  class Generator
    INDENT = "  "

    def initialize(document)
      @doc = document
      @items = document.items
      @start = document.start_id.to_s
    end

    def ruby_source(class_name:)
      cn = class_name.to_s
      raise Error, "invalid class name #{cn.inspect}" unless cn.match?(/\A[A-Z][a-zA-Z0-9_]*\z/)

      lines = +"# frozen_string_literal: true\n\n"
      lines << "class #{cn}\n"
      lines << "#{INDENT}def run(ctx)\n"
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
             when "branch" then emit_silhouette_jump(node, "Branch")
             when "address" then emit_silhouette_jump(node, "Address")
             when "question" then emit_question(node)
             when "end" then emit_end
             else
               raise Error, "unhandled type #{type.inspect} at #{nid}"
             end

      "#{INDENT * 3}when #{nid.inspect} then\n#{body}"
    end

    def emit_action(node)
      dest = node["one"].to_s
      code = node["content"].to_s
      inner = if code.strip.empty?
                ""
              else
                "#{indent_body(code, INDENT * 4)}\n"
              end
      "#{inner}#{INDENT * 4}state = #{dest.inspect}\n"
    end

    def emit_silhouette_jump(node, kind)
      dest = node["one"].to_s
      label = Content.strip_html(node["content"].to_s)
      comment = if label.empty?
                  ""
                else
                  "#{INDENT * 4}# #{kind}: #{label}\n"
                end
      "#{comment}#{INDENT * 4}state = #{dest.inspect}\n"
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
