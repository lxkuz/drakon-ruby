# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "ostruct"
require "minitest/autorun"
require "minitest/pride"
require "json"
require "drakon_ruby"

module DrakonRubyTest
  module Helpers
    def load_flow_class(fixture)
      path = File.expand_path("fixtures/#{fixture}.drakon", __dir__)
      source = File.read(path, encoding: "UTF-8")
      mod = Module.new
      mod.module_eval(DrakonRuby::Translator.new(source).to_ruby, path, 1)
      name = DrakonRuby::Translator.new(source).ruby_class_name
      mod.const_get(name)
    end

    def run_fixture(fixture, ctx)
      klass = load_flow_class(fixture)
      klass.call(ctx)
    end
  end
end
