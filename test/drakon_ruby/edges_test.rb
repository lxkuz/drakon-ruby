# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyEdgesTest < Minitest::Test
  def test_outgoing_refs_numeric_keys
    n = { "one" => "2", "two" => "3", "three" => "4" }
    assert_equal %w[2 3 4], DrakonRuby::Edges.outgoing_refs(n).sort
  end

  def test_outgoing_refs_cases_array
    n = {
      "cases" => [
        { "when" => "a", "to" => "10" },
        { "when" => "b", "one" => "11" }
      ]
    }
    refs = DrakonRuby::Edges.outgoing_refs(n)
    assert_includes refs, "10"
    assert_includes refs, "11"
  end
end
