# frozen_string_literal: true

require_relative "../test_helper"

class DrakonRubyTranslatorTest < Minitest::Test
  def test_to_ruby_emits_class_and_run
    source = {
      "id" => "smoke",
      "items" => {
        "1" => { "type" => "action", "content" => "ctx.x = 1", "one" => "2" },
        "2" => { "type" => "end" }
      }
    }.to_json
    code = DrakonRuby::Translator.new(source).to_ruby
    assert_match(/class Smoke/, code)
    assert_match(/def run\(ctx\)/, code)
    assert_match(/when "1"/, code)
    assert_match(/state = "2"/, code)
  end

  def test_custom_class_name_override
    source = {
      "id" => "ignored",
      "items" => {
        "1" => { "type" => "action", "content" => "", "one" => "2" },
        "2" => { "type" => "end" }
      }
    }.to_json
    code = DrakonRuby::Translator.new(source).to_ruby(class_name: "MyFlow")
    assert_match(/class MyFlow/, code)
  end
end
