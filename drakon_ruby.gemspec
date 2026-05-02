# frozen_string_literal: true

require_relative "lib/drakon_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "drakon_ruby"
  spec.version = DrakonRuby::VERSION
  spec.summary = "Drakon flowchart to Ruby translator"
  spec.authors = ["drakon-ruby"]
  spec.files = Dir["lib/**/*", "exe/*"]
  spec.require_paths = ["lib"]
  spec.executables = ["drakon2rb"]
  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rake", "~> 13.0"
end
