require 'voteable_mongoid/voteable/stats'
require 'voteable_mongoid/voteable'
require 'voteable_mongoid/voter'

# add railtie
if defined?(Rails)
  require 'voteable_mongoid/railtie'
end
