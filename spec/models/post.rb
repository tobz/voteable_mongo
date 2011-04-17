class Post
  include Mongoid::Document
  include Mongoid::Voteable

  field :title
  field :content
  
  has_and_belongs_to_many :categories
  has_many :comments

  voteable self, :up => +1, :down => -1
  voteable Category, :up => +3, :down => -5, :update_counters => false
end
