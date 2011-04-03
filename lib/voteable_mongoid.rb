require 'mongoid'
require 'voteable_mongoid/voteable/votes'
require 'voteable_mongoid/voteable'
require 'voteable_mongoid/voter'

require 'voteable_mongoid/voteable/tasks'

# Add railtie
if defined?(Rails)
  require 'voteable_mongoid/railtie'
end
