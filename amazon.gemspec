# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "amazon/version"

Gem::Specification.new do |s|
  s.name        = "amazon"
  s.version     = Amazon::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bill and Ted"]
  s.email       = ["excellent@adventure.com"]
  s.homepage    = ""
  s.summary     = %q{Gets that super awesome csv}
  s.description = %q{Summary AND description?}

  s.rubyforge_project = "amazon"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency("mechanize")
  s.add_dependency("andand")
end
