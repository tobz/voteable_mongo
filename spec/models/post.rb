class Post
  include Mongoid::Document
  include Mongoid::Voteable

  voteable self, :up => +1, :down => -1
  
  references_many :comments  
end
