# frozen_string_literal: true

require "json"
require_relative "content"

module DrakonRuby
  # Parsed Drakon JSON (e.g. from .drakon) with item graph and start node.
  class Document
    attr_reader :id, :items, :raw, :start_id

    def self.parse(string)
      raw = JSON.parse(string)
      new(raw)
    end

    def initialize(raw)
      @raw = raw
      @id = raw["id"] || raw["name"] || "flow"
      @items = (raw["items"] || {}).transform_keys(&:to_s)
      @start_id = (raw["start"] || raw["$start"])&.to_s
      @start_id ||= infer_start!
      validate!
    end

    def node(id)
      items[id.to_s] || raise(Error, "missing node #{id.inspect}")
    end

    private

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
        when "action", "branch"
          raise Error, "node #{nid} (#{type}) needs \"one\"" unless n.key?("one") && n["one"]
        when "question"
          raise Error, "node #{nid} (question) needs \"one\" and \"two\"" unless n["one"] && n["two"]
          cond = Content.strip_html(n["content"])
          raise Error, "node #{nid} (question) needs non-empty condition after strip" if cond.empty?
        when "end"
          # ok
        else
          raise Error, "unsupported node type #{type.inspect} at #{nid}"
        end
      end
    end
  end
end
