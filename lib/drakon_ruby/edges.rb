# frozen_string_literal: true

module DrakonRuby
  # Исходящие рёбра узла графа ДРАКОН (все поддерживаемые поля переходов).
  module Edges
    module_function

    OUT_KEYS = %w[
      one two three four five six seven eight nine ten eleven twelve
    ].freeze

    # Все id узлов, в которые есть переход из этого узла.
    def outgoing_refs(node)
      return [] unless node.is_a?(Hash)

      refs = []
      OUT_KEYS.each do |k|
        v = node[k]
        refs << v.to_s if v && !v.to_s.empty?
      end

      case node["cases"]
      when Hash
        node["cases"].each_value do |v|
          refs << v.to_s if v && !v.to_s.empty?
        end
      when Array
        node["cases"].each do |c|
          next unless c.is_a?(Hash)

          %w[to one target].each do |key|
            next unless c[key]

            refs << c[key].to_s unless c[key].to_s.empty?
          end
        end
      end

      refs.uniq
    end

    def successors(node_id, items)
      n = items[node_id.to_s] || items[node_id]
      outgoing_refs(n)
    end
  end
end
