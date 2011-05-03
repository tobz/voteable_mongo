# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'voteable_mongo/version'

Gem::Specification.new do |s|
  s.name        = 'voteable_mongo'
  s.version     = VoteableMongo::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Alex Nguyen']
  s.email       = ['alex@vinova.sg']
  s.homepage    = 'https://github.com/vinova/voteable_mongo'
  s.summary     = %q{Add Up / Down Voting for Mongoid and MongoMapper}
  s.description = %q{Up / Down Voting for Mongoid (MongoMapper support coming soon). Built for speed by using only one database request per collection to validate data, update data, and get updated data.}

  s.add_development_dependency 'rspec', '~> 2.5.0'
  s.add_development_dependency 'mongoid', '~> 2.0.0'
  s.add_development_dependency 'mongo_mapper', '~> 0.9.0'
  s.add_development_dependency 'bson_ext', '~> 1.3.0'

  s.rubyforge_project = 'voteable_mongo'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
