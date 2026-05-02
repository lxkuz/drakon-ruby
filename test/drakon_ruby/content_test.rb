# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyContentTest < Minitest::Test
  def test_strip_html_removes_tags
    assert_equal "ctx.ok", DrakonRuby::Content.strip_html("<p>ctx.ok</p>")
  end

  def test_strip_html_normalizes_space
    assert_equal "a b c", DrakonRuby::Content.strip_html("<p>a</p>  <p>b  c</p>")
  end

  def test_strip_empty
    assert_equal "", DrakonRuby::Content.strip_html(nil)
  end

  def test_strip_html_decodes_entities
    assert_equal "a > b", DrakonRuby::Content.strip_html("<p>a &gt; b</p>")
  end

  def test_question_condition_prefers_link
    node = {
      "type" => "question",
      "content" => "<p>ignored</p>",
      "link" => "ctx.ok",
      "one" => "1",
      "two" => "2"
    }
    assert_equal "ctx.ok", DrakonRuby::Content.question_condition(node)
  end

  def test_action_body_plain_is_code
    node = { "content" => "x = 1\ny = 2" }
    assert_equal "x = 1\ny = 2", DrakonRuby::Content.action_body(node)
  end

  def test_action_body_unwraps_paragraphs
    node = { "content" => "<p>a = 1</p><p>b = 2</p>" }
    assert_equal "a = 1\nb = 2", DrakonRuby::Content.action_body(node)
  end

  def test_block_code_keeps_comparison_operators_near_paragraph_close
    assert_equal "ctx.i < 3", DrakonRuby::Content.block_code("<p>ctx.i &lt; 3</p>")
  end

  def test_comment_block
    node = { "content" => "note\nsecond line" }
    assert_equal "# note\n# second line", DrakonRuby::Content.comment_block(node)
  end
end
