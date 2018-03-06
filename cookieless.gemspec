# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack/cookieless/version'

Gem::Specification.new do |s|
  s.name             = "cookieless"
  s.version          = Rack::Cookieless::VERSION
  s.authors          = ["Jinzhu", "chrisboy333"]
  s.date             = "2012-01-06"
  s.summary          = "Cookieless is a rack middleware to make your application works with cookie-less devices/browsers without change your application"
  s.description      = "Cookieless is a rack middleware to make your application works with cookie-less devices/browsers without change your application"
  s.email            = "wosmvp@gmail.com"
  s.homepage         = "http://github.com/jinzhu/cookieless"
  s.licenses         = ["MIT"]

  s.files            = `git ls-files -z`.split("\x0")
  s.extra_rdoc_files = ["LICENSE.txt", "README.rdoc"]
  s.executables      = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files       = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths    = ["lib"]

  s.add_runtime_dependency "nokogiri", ">= 0"
  s.add_runtime_dependency "rails", ">= 3.1.0"

  s.add_development_dependency "bundler", "~> 1.5"
  s.add_development_dependency "rake"
  s.add_development_dependency "appraisal"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rspec-mocks"
end
