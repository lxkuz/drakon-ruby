# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyDiagramInventoryTest < Minitest::Test
  include DrakonRubyTest::Helpers

  ALGO = File.expand_path("../../../tokentech/matching-engine-core/algorithm", __dir__)

  # Сырые типы из экспорта matching-engine (до normalize).
  RAW_EXPORT_TYPES = %w[
    action branch callout case comment end insertion process question select simpleinput
  ].freeze

  def test_matching_engine_algorithm_exports_only_known_raw_types
    skip "нет каталога algorithm" unless File.directory?(ALGO)

    Dir.glob(File.join(ALGO, "*.drakon")).each do |path|
      raw = DrakonRuby::DiagramInventory.raw_types(File.read(path, encoding: "UTF-8"))
      raw.each do |t|
        assert RAW_EXPORT_TYPES.include?(t),
               "неучтённый тип #{t.inspect} в #{File.basename(path)} — добавьте normalize/генератор в Document"
      end

      canon = DrakonRuby::DiagramInventory.canonical_types(File.read(path, encoding: "UTF-8"))
      canon.each do |t|
        refute_equal "process", t, "process должен нормализоваться в parallel: #{path}"
      end
    end
  end

  def test_callout_emitted_as_leading_comments
    klass = load_flow_class("with_callouts")
    out, _err = capture_io { klass.call(OpenStruct.new) }
    assert_equal "x\n", out
    code = DrakonRuby::Translator.new(File.read(File.expand_path("../fixtures/with_callouts.drakon", __dir__), encoding: "UTF-8")).to_ruby
    assert_match(/# Note A/, code)
    assert_match(/puts :x/, code)
  end
end
