# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyFlowScenariosTest < Minitest::Test
  include DrakonRubyTest::Helpers

  def test_linear
    ctx = OpenStruct.new(trace: [])
    run_fixture("linear", ctx)
    assert_equal %i[a b], ctx.trace
    refute ctx.respond_to?(:skipped)
  end

  def test_linear_service_call_style
    klass = load_flow_class("linear")
    ctx = OpenStruct.new(trace: [])
    klass.call(ctx)
    assert_equal %i[a b], ctx.trace

    trace = []
    klass.call(nil, trace: trace)
    assert_equal %i[a b], trace
  end

  def test_if_else_true
    ctx = OpenStruct.new(trace: [], flag: true)
    run_fixture("if_else", ctx)
    assert_equal %i[yes picked_a], ctx.trace
    assert_equal 21, ctx.a
    assert_equal 20, ctx.b
  end

  def test_if_else_false
    ctx = OpenStruct.new(trace: [], flag: false)
    run_fixture("if_else", ctx)
    assert_equal %i[no picked_a], ctx.trace
    assert_equal 21, ctx.a
    assert_equal 20, ctx.b
  end

  def test_merge_paths_left
    ctx = OpenStruct.new(trace: [], left: true)
    run_fixture("merge_paths", ctx)
    assert_equal %i[from_left merged], ctx.trace
  end

  def test_merge_paths_right
    ctx = OpenStruct.new(trace: [], left: false)
    run_fixture("merge_paths", ctx)
    assert_equal %i[from_right merged], ctx.trace
  end

  def test_loop_counter
    ctx = OpenStruct.new(trace: [], i: nil)
    run_fixture("loop_counter", ctx)
    assert_equal [:start, 1, 2, 3], ctx.trace
    assert_equal 3, ctx.i
  end

  def test_branch_entry
    ctx = OpenStruct.new(trace: [])
    run_fixture("branch_entry", ctx)
    assert_equal %i[after_branch], ctx.trace
  end

  def test_html_condition_strips_tags
    ctx = OpenStruct.new(trace: [], use_html: true)
    run_fixture("html_condition", ctx)
    assert_equal %i[html_true], ctx.trace

    ctx2 = OpenStruct.new(trace: [], use_html: false)
    run_fixture("html_condition", ctx2)
    assert_equal %i[html_false], ctx2.trace
  end

  def test_long_chain
    ctx = OpenStruct.new(trace: [])
    run_fixture("long_chain", ctx)
    assert_equal [1, 2, 3, 4, 5], ctx.trace
  end

  def test_nested_questions_all_paths
    cases = [
      [{ outer: false, inner: false }, [:outer_no]],
      [{ outer: true, inner: true }, [:both_yes]],
      [{ outer: true, inner: false }, [:outer_yes_inner_no]]
    ]
    cases.each do |attrs, expected|
      ctx = OpenStruct.new({ trace: [] }.merge(attrs))
      run_fixture("nested_questions", ctx)
      assert_equal expected, ctx.trace, "attrs=#{attrs.inspect}"
    end
  end

  def test_explicit_start_skips_unreachable_prefix
    ctx = OpenStruct.new(trace: [])
    run_fixture("explicit_start", ctx)
    assert_equal [:from_2], ctx.trace
    refute ctx.skipped, "prefix node must not run when start is set"
  end

  def test_generated_code_is_idempotent
    path = File.expand_path("../fixtures/linear.drakon", __dir__)
    source = File.read(path)
    a = DrakonRuby::Translator.new(source).to_ruby
    b = DrakonRuby::Translator.new(source).to_ruby
    assert_equal a, b
  end

  def test_ruby_class_name_matches_generated_class
    path = File.expand_path("../fixtures/loop_counter.drakon", __dir__)
    source = File.read(path)
    t = DrakonRuby::Translator.new(source)
    mod = Module.new
    mod.module_eval(t.to_ruby, path, 1)
    assert mod.const_defined?(t.ruby_class_name, false)
  end

  def test_string_node_ids
    ctx = OpenStruct.new(trace: [], ok: true)
    run_fixture("string_ids", ctx)
    assert_equal %i[a c], ctx.trace

    ctx2 = OpenStruct.new(trace: [], ok: false)
    run_fixture("string_ids", ctx2)
    assert_equal %i[a d], ctx2.trace
  end

  def test_comment_emits_ruby_comments
    ctx = OpenStruct.new(trace: [])
    run_fixture("with_comment", ctx)
    assert_equal [:done], ctx.trace

    path = File.expand_path("../fixtures/with_comment.drakon", __dir__)
    code = DrakonRuby::Translator.new(File.read(path, encoding: "UTF-8")).to_ruby
    assert_match(/# шаг подготовки/, code)
  end

  def test_editor_aliases_insertion_pause
    ctx = OpenStruct.new(trace: [])
    run_fixture("aliases", ctx)
    assert_equal [:from_insertion], ctx.trace
  end

  def test_empty_action_passthrough
    ctx = OpenStruct.new(trace: [])
    run_fixture("empty_action", ctx)
    assert_equal %i[after_empty], ctx.trace
  end

  def test_silhouette_two_branches_via_address
    ctx = OpenStruct.new(trace: [])
    run_fixture("silhouette_two_branches", ctx)
    assert_equal %i[branch_a branch_b], ctx.trace

    path = File.expand_path("../fixtures/silhouette_two_branches.drakon", __dir__)
    source = File.read(path, encoding: "UTF-8")
    assert DrakonRuby::Translator.new(source).silhouette?
    assert DrakonRuby::Document.parse(source).silhouette?

    code = DrakonRuby::Translator.new(source).to_ruby
    refute_match(/# Address:/, code)
    refute_match(/# Branch:/, code)
    assert_operator code.scan(/^  def /).size, :>=, 3, "силуэт: start + отдельные методы веток"
    assert_match(/segment_1\(ctx\)/, code)
  end
end
