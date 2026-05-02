# frozen_string_literal: true

require "json"
require_relative "document"

module DrakonRuby
  # Учёт типов узлов в JSON (до и после normalize — через Document).
  module DiagramInventory
    module_function

    # Уникальные типы из сырого JSON (как в экспорте редактора).
    def raw_types(json_string)
      raw = JSON.parse(json_string.to_s)
      (raw["items"] || {}).each_value.filter_map { |n| n["type"]&.to_s if n.is_a?(Hash) }.uniq.sort
    end

    # Типы после Document.normalize_node.
    def canonical_types(json_string)
      Document.parse(json_string).items.each_value.filter_map { |n| n["type"]&.to_s if n.is_a?(Hash) }.uniq.sort
    end
  end
end
