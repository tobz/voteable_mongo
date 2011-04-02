# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "voteable_mongoid/version"

Gem::Specification.new do |s|
  s.name        = "voteable_mongoid"
  s.version     = VoteableMongoid::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Alex Nguyen"]
  s.email       = ["alex@vinova.sg"]
  s.homepage    = "https://github.com/vinova/voteable_mongoid"
  s.summary     = %q{Add Up / Down Voting for Mongoid}
  s.description = %q{Add Up / Down Voting for Mongoid (built for speed by using one Mongodb update-in-place for each collection when provided enough information)}

  s.add_dependency 'mongoid', '~> 2.0.0'
  
  s.add_development_dependency 'rspec'

  s.rubyforge_project = "voteable_mongoid"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
