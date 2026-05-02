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
end
