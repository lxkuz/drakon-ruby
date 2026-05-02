# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyFlowScenariosTest < Minitest::Test
  include DrakonRubyTest::Helpers

  def test_linear
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("linear", ctx) }
    assert_equal "a\nb\n", out
    refute ctx.respond_to?(:skipped)
  end

  def test_linear_service_call_style
    klass = load_flow_class("linear")
    out1, _ = capture_io { klass.call(OpenStruct.new) }
    assert_equal "a\nb\n", out1

    out2, _ = capture_io { klass.call }
    assert_equal "a\nb\n", out2
  end

  def test_if_else_true
    ctx = OpenStruct.new(flag: true)
    out, _err = capture_io { run_fixture("if_else", ctx) }
    assert_equal "yes\npicked_a\n", out
    assert_equal 21, ctx.a
    assert_equal 20, ctx.b
  end

  def test_if_else_false
    ctx = OpenStruct.new(flag: false)
    out, _err = capture_io { run_fixture("if_else", ctx) }
    assert_equal "no\npicked_a\n", out
    assert_equal 21, ctx.a
    assert_equal 20, ctx.b
  end

  def test_merge_paths_left
    ctx = OpenStruct.new(left: true)
    out, _err = capture_io { run_fixture("merge_paths", ctx) }
    assert_equal "from_left\nmerged\n", out
  end

  def test_merge_paths_right
    ctx = OpenStruct.new(left: false)
    out, _err = capture_io { run_fixture("merge_paths", ctx) }
    assert_equal "from_right\nmerged\n", out
  end

  def test_loop_counter
    ctx = OpenStruct.new(i: nil)
    out, _err = capture_io { run_fixture("loop_counter", ctx) }
    assert_equal "start\n1\n2\n3\n", out
    assert_equal 3, ctx.i
  end

  def test_branch_entry
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("branch_entry", ctx) }
    assert_equal "after_branch\n", out
  end

  def test_html_condition_strips_tags
    ctx = OpenStruct.new(use_html: true)
    out, _err = capture_io { run_fixture("html_condition", ctx) }
    assert_equal "html_true\n", out

    ctx2 = OpenStruct.new(use_html: false)
    out2, _err2 = capture_io { run_fixture("html_condition", ctx2) }
    assert_equal "html_false\n", out2
  end

  def test_long_chain
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("long_chain", ctx) }
    assert_equal "1\n2\n3\n4\n5\n", out
  end

  def test_nested_questions_all_paths
    cases = [
      [{ outer: false, inner: false }, "outer_no\n"],
      [{ outer: true, inner: true }, "both_yes\n"],
      [{ outer: true, inner: false }, "outer_yes_inner_no\n"]
    ]
    cases.each do |attrs, expected_out|
      ctx = OpenStruct.new(attrs)
      out, _err = capture_io { run_fixture("nested_questions", ctx) }
      assert_equal expected_out, out, "attrs=#{attrs.inspect}"
    end
  end

  def test_explicit_start_skips_unreachable_prefix
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("explicit_start", ctx) }
    assert_equal "from_2\n", out
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
    ctx = OpenStruct.new(ok: true)
    out, _err = capture_io { run_fixture("string_ids", ctx) }
    assert_equal "a\nc\n", out

    ctx2 = OpenStruct.new(ok: false)
    out2, _err2 = capture_io { run_fixture("string_ids", ctx2) }
    assert_equal "a\nd\n", out2
  end

  def test_comment_emits_ruby_comments
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("with_comment", ctx) }
    assert_equal "done\n", out

    path = File.expand_path("../fixtures/with_comment.drakon", __dir__)
    code = DrakonRuby::Translator.new(File.read(path, encoding: "UTF-8")).to_ruby
    assert_match(/# шаг подготовки/, code)
  end

  def test_editor_aliases_insertion_pause
    paths = [File.expand_path("../fixtures", __dir__)]
    path = File.expand_path("../fixtures/aliases.drakon", __dir__)
    source = File.read(path, encoding: "UTF-8")
    code = DrakonRuby::Translator.new(source).to_ruby(insertion_paths: paths)
    mod = Module.new
    mod.module_eval(code, path, 1)
    klass = mod.const_get(:Aliases)
    out, _err = capture_io { klass.call(OpenStruct.new) }
    assert_equal "a\nb\n", out
  end

  def test_empty_action_passthrough
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("empty_action", ctx) }
    assert_equal "after_empty\n", out
  end

  def test_silhouette_two_branches_via_address
    ctx = OpenStruct.new
    out, _err = capture_io { run_fixture("silhouette_two_branches", ctx) }
    assert_equal "branch_a\nbranch_b\n", out

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
