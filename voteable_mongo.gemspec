# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'voteable_mongo/version'

Gem::Specification.new do |s|
  s.name        = 'rs_voteable_mongo'
  s.version     = VoteableMongo::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['RocketScience','Alex Nguyen']
  s.email       = ['i@gleb.tv','alex@vinova.sg']
  s.homepage    = 'https://github.com/rs-pro/voteable_mongo'
  s.summary     = %q{Add up / down voting ability to Mongoid documents}
  s.description = %q{Add up / down voting ability to Mongoid documents. Optimized for speed by using only ONE request to MongoDB to validate, update, and retrieve updated data.}
  s.license       = "MIT"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency "mongoid", [">= 3.0", "< 5.0"]
  s.add_development_dependency 'rspec', '~> 2.14.1'
  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
end
