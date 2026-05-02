# frozen_string_literal: true

require "json"
require_relative "content"

module DrakonRuby
  # Parsed Drakon JSON (e.g. from .drakon) with item graph and start node.
  class Document
    attr_reader :id, :items, :raw, :start_id

    def self.parse(string)
      str = string.to_s
      str = str.dup.force_encoding(Encoding::UTF_8) if str.encoding != Encoding::UTF_8
      raw = JSON.parse(str)
      new(raw)
    end

    def initialize(raw)
      @raw = raw
      @id = raw["id"] || raw["name"] || "flow"
      @items = normalize_items((raw["items"] || {}).transform_keys(&:to_s))
      @start_id = (raw["start"] || raw["$start"])&.to_s
      @start_id ||= infer_start!
      validate!
    end

    # Silhouette (силуэт): несколько веток, переходы по иконке «адрес» между ветками; корень JSON или структура графа.
    def silhouette?
      return true if @raw["silhouette"] == true
      return true if @raw["diagramKind"].to_s == "silhouette"
      return true if @raw["style"].to_s == "silhouette"

      types = @items.values.filter_map { |n| n["type"]&.to_s if n.is_a?(Hash) }
      return true if types.count("branch") > 1
      return true if types.include?("address")

      false
    end

    def node(id)
      items[id.to_s] || raise(Error, "missing node #{id.inspect}")
    end

    private

    def normalize_items(items)
      items.transform_values { |n| normalize_node(n) }
    end

    def normalize_node(node)
      return node unless node.is_a?(Hash)

      t = node["type"].to_s
      t = "end" if t == "beginend"
      node.merge("type" => t)
    end

    def infer_start!
      targets = items.flat_map do |_, n|
        next [] unless n.is_a?(Hash)

        [n["one"], n["two"]].compact.map(&:to_s)
      end
      candidates = items.keys.map(&:to_s) - targets
      raise Error, "cannot infer start: #{candidates.inspect}" unless candidates.size == 1

      candidates.first
    end

    def validate!
      raise Error, "items must be a non-empty hash" if items.empty?

      items.each do |nid, n|
        raise Error, "node #{nid} must be a hash" unless n.is_a?(Hash)

        type = n["type"]
        raise Error, "node #{nid} missing type" if type.nil? || type.to_s.empty?

        case type.to_s
        when "action", "branch", "address"
          raise Error, "node #{nid} (#{type}) needs \"one\"" unless n.key?("one") && n["one"]
        when "question"
          raise Error, "node #{nid} (question) needs \"one\" and \"two\"" unless n["one"] && n["two"]
          cond = Content.question_condition(n)
          raise Error, "node #{nid} (question) needs non-empty condition (content or link)" if cond.empty?
        when "end"
          # ok
        else
          raise Error, "unsupported node type #{type.inspect} at #{nid}"
        end
      end
    end
  end
end
