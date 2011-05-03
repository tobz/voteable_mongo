require 'post'

class Comment
  include MongoMapper::Document
  include Mongo::Voteable

  key :content, String

  belongs_to :post
  
  voteable self, :up => +1, :down => -3
  voteable Post, :up => +2, :down => -1
end
