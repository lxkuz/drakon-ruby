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

  def test_silhouette_flag_and_address
    json = {
      "id" => "s",
      "silhouette" => true,
      "items" => {
        "1" => { "type" => "address", "content" => "next", "one" => "2" },
        "2" => { "type" => "end" }
      }
    }.to_json
    d = DrakonRuby::Document.parse(json)
    assert d.silhouette?
  end

  def test_silhouette_inferred_from_multiple_branches
    json = {
      "id" => "s",
      "items" => {
        "1" => { "type" => "branch", "branchId" => 0, "content" => "", "one" => "2" },
        "2" => { "type" => "address", "content" => "", "one" => "3" },
        "3" => { "type" => "branch", "branchId" => 1, "content" => "", "one" => "4" },
        "4" => { "type" => "end" }
      }
    }.to_json
    assert DrakonRuby::Document.parse(json).silhouette?
  end

  def test_aliases_normalize_to_canonical_types
    json = {
      "id" => "t",
      "items" => {
        "1" => { "type" => "insertion", "content" => "x", "one" => "2" },
        "2" => { "type" => "commentin", "content" => "c", "one" => "3" },
        "3" => { "type" => "end" }
      }
    }.to_json
    d = DrakonRuby::Document.parse(json)
    assert_equal "insertion", d.node("1")["type"]
    assert_equal "comment", d.node("2")["type"]
  end

  def test_beginend_normalized_to_end
    json = {
      "id" => "t",
      "items" => {
        "1" => { "type" => "action", "content" => "ctx.ok = true", "one" => "2" },
        "2" => { "type" => "beginend" }
      }
    }.to_json
    d = DrakonRuby::Document.parse(json)
    assert_equal "end", d.node("2")["type"]
  end
end
