# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyExtendedElementsTest < Minitest::Test
  include DrakonRubyTest::Helpers

  def test_select_case_emits_ruby_case_when
    klass = load_flow_class("choice_side")
    ctx = OpenStruct.new(side: :sell)
    out, _err = capture_io { klass.call(ctx) }
    assert_equal "sell_branch\n", out

    ctx2 = OpenStruct.new(side: :buy)
    out2, _err2 = capture_io { klass.call(ctx2) }
    assert_equal "buy_branch\n", out2
  end

  def test_parallel_process_emits_threads
    klass = load_flow_class("parallel_demo")
    ctx = OpenStruct.new
    klass.call(ctx)
    assert_equal 1, ctx.a
    assert_equal 2, ctx.b
  end

  def test_matching_drakon_translates_with_insertions
    base = File.expand_path("../../../tokentech/matching-engine-core/algorithm/Matching.drakon", __dir__)
    skip "algorithm/Matching.drakon не найден по #{base}" unless File.file?(base)

    src = File.read(base, encoding: "UTF-8")
    algo = File.expand_path("../../../tokentech/matching-engine-core/algorithm", __dir__)
    code = DrakonRuby::Translator.new(src).to_ruby(insertion_paths: [algo])
    assert_match(/class Matching\b/, code)
    assert_match(/\.call\(ctx\)/, code)
    assert_operator code.lines.size, :>, 50
  end
end
