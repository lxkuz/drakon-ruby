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
end
