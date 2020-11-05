# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'paradocs/version'

Gem::Specification.new do |spec|
  spec.name          = "paradocs"
  spec.version       = Paradocs::VERSION
  spec.authors       = ["Maxim Tkachenko", "Ismael Celis"]
  spec.email         = ["tkachenko.maxim.w@gmail.com", "ismaelct@gmail.com"]
  spec.description   = %q{Flexible DRY validations with API docs generation done right TLDR; parametrics on steroids.}
  spec.summary       = %q{A huge add-on for original gem mostly focused on retrieving the more metadata from declared schemas as possible.}
  spec.homepage      = "https://paradocs.readthedocs.io/en/latest"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", '~> 12.3'
  spec.add_development_dependency "rspec", '3.4.0'
  spec.add_development_dependency "pry", "~> 0"
end
