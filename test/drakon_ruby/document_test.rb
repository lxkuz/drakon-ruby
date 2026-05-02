# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyDocumentTest < Minitest::Test
  def test_infers_start_when_unique
    json = {
      "id" => "t",
      "items" => {
        "1" => { "type" => "action", "content" => "1", "one" => "2" },
        "2" => { "type" => "end" }
      }
    }.to_json
    d = DrakonRuby::Document.parse(json)
    assert_equal "1", d.start_id
  end

  def test_respects_explicit_start
    json = {
      "id" => "t",
      "start" => "2",
      "items" => {
        "1" => { "type" => "action", "content" => "1", "one" => "2" },
        "2" => { "type" => "end" }
      }
    }.to_json
    d = DrakonRuby::Document.parse(json)
    assert_equal "2", d.start_id
  end

  def test_rejects_unknown_node_type
    json = {
      "id" => "t",
      "items" => {
        "1" => { "type" => "weird", "one" => "2" },
        "2" => { "type" => "end" }
      }
    }.to_json
    err = assert_raises(DrakonRuby::Error) { DrakonRuby::Document.parse(json) }
    assert_match(/unsupported node type/i, err.message)
  end
end
