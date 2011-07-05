# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "forever/version"

Gem::Specification.new do |s|
  s.name        = "forever"
  s.version     = Forever::VERSION
  s.authors     = ["DAddYE"]
  s.email       = ["d.dagostino@lipsiasoft.com"]
  s.homepage    = "https://github.com/daddye/forever"
  s.summary     = %q{Small daemon framework for ruby}
  s.description = %q{Small daemon framework for ruby, with logging, error handler and more...}

  s.rubyforge_project = "forever"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency 'mail', '~>2.3.0'
end
