require 'post'

class Comment
  include Mongoid::Document
  include Mongoid::Voteable
  
  referenced_in :post
  
  voteable self, :up => +1, :down => -3
  voteable Post, :up => +2, :down => -1 #, :not_update_counters => true
end
