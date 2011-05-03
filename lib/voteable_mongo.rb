require 'mongoid'
require 'voteable_mongo/voteable'
require 'voteable_mongo/voter'

require 'voteable_mongo/voteable/tasks'

# Add railtie
if defined?(Rails)
  require 'voteable_mongo/railtie'
end
