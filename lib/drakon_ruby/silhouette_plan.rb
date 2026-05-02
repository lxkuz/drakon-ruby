# frozen_string_literal: true

module DrakonRuby
  # Разбиение графа на «ветки силуэта»: счётчик сегмента увеличивается при переходе через узел type address.
  class SilhouettePlan
    attr_reader :segment_of, :entries, :segment_count

    def initialize(document)
      @items = document.items
      @start = document.start_id.to_s
      @segment_of = {}
      @entries = {}
      visit(@start, 0)
      max_seg = @segment_of.values.max || 0
      @segment_count = max_seg + 1
    end

    def nodes_in(segment_index)
      @segment_of.select { |_, s| s == segment_index }.keys
    end

    private

    def visit(id, seg)
      id = id.to_s
      return if id.empty?

      old = @segment_of[id]
      if old
        raise Error, "silhouette: узел #{id} принадлежит и сегменту #{old}, и #{seg}" unless old == seg

        return
      end

      @segment_of[id] = seg
      @entries[seg] ||= id

      n = @items[id] || raise(Error, "silhouette: нет узла #{id}")

      case n["type"].to_s
      when "address"
        visit(n["one"].to_s, seg + 1)
      when "question"
        visit(n["one"].to_s, seg)
        visit(n["two"].to_s, seg)
      when "action", "branch", "comment"
        visit(n["one"].to_s, seg)
      when "end"
        # конец ветки
      else
        raise Error, "silhouette plan: тип #{n["type"].inspect} не поддержан в узле #{id}"
      end
    end
  end
end
