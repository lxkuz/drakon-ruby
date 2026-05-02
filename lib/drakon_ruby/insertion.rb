# frozen_string_literal: true

require_relative "content"

module DrakonRuby
  # Вставка другой схемы: имя из content → класс Ruby и поиск файла по каталогам.
  module Insertion
    module_function

    def stem_from_content(content)
      s = Content.block_code(content.to_s).strip
      s = s.sub(/\.drakon\z/i, "")
      s.empty? ? nil : s
    end

    def resolve_path(stem, load_paths)
      return nil if stem.nil? || stem.empty?

      candidates = [stem, stem.gsub("-", "_")]
      candidates |= [File.basename(stem, ".drakon")] if stem.include?(".")
      Array(load_paths).each do |dir|
        next if dir.to_s.empty?

        candidates.each do |base|
          %W[#{base}.drakon #{base}.json].each do |fname|
            path = File.join(dir, fname)
            return path if File.file?(path)
          end
        end
      end
      nil
    end

    def ruby_class_name_from_stem(stem)
      return "DrakonFlow" if stem.nil? || stem.to_s.empty?

      s = stem.to_s.sub(/\.(drakon|json)\z/i, "")
      parts = s.split(/[^a-zA-Z0-9]+/).reject(&:empty?)
      base = parts.map { |p| p[0].upcase + p[1..] }.join
      base = "DrakonFlow" if base.empty?
      base = "Drakon#{base}" if base.match?(/\A\d/)
      base
    end

    def call_expr_from_node(node)
      stem = stem_from_content(node["content"])
      raise Error, "insertion: пустое имя схемы в узле" if stem.nil? || stem.empty?

      cn = ruby_class_name_from_stem(stem)
      "#{cn}.call(ctx)"
    end
  end
end
