class Video
  Object.const_set "DynamicDoc", Class.new unless defined? DynamicDoc
  
  include Mongoid::Document
  include Mongo::Voteable
  
  embedded_in :dynamic_doc
  
  voteable self, :up => +1, :down => -1, :index => true, :voting_field => :reviews
  voteable DynamicDoc, :up => +2, :down => -2, :voting_field => :moderations
end