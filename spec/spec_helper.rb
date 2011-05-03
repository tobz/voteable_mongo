require 'rubygems'
require 'bundler'
Bundler.setup


$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

# MODELS = File.join(File.dirname(__FILE__), 'mongoid/models')
MODELS = File.join(File.dirname(__FILE__), 'mongo_mapper/models')
$LOAD_PATH.unshift(MODELS)


require 'mongoid'
require 'mongo_mapper'
require 'voteable_mongo'
require 'rspec'
require 'rspec/autorun'


Mongoid.configure do |config|
  name = 'voteable_mongo_test'
  host = 'localhost'
  config.master = Mongo::Connection.new.db(name)
end

MongoMapper.database = 'voteable_mongo_test'

Dir[ File.join(MODELS, '*.rb') ].sort.each { |file| require File.basename(file) }

User.collection.drop
Post.collection.drop
Comment.collection.drop
Category.collection.drop
