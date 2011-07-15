class Image
  Object.const_set "Post", Class.new unless defined? Post
  
  include Mongoid::Document
  include Mongo::Voteable
  
  field :url
  embedded_in :post
  
  voteable self, :up => +1, :down => -1, :index => true
  voteable ::Post, :up => +2, :down => -1
end