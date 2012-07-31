require 'rubygems'
require 'bundler'
Bundler.setup

require 'mongoid'
models_folder = File.join(File.dirname(__FILE__), 'mongoid/models')
Mongoid.configure do |config|
  name = 'voteable_mongo_test'
  host = 'localhost'
  config.connect_to(name)
end

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))


require 'voteable_mongo'
require 'rspec'
require 'rspec/autorun'

Dir[ File.join(models_folder, '*.rb') ].each { |file|
  require file
  file_name = File.basename(file).sub('.rb', '')
  klass = file_name.classify.constantize
  begin
    klass.collection.drop
  rescue Exception => e
    print e.message
  end
}
