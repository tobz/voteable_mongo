require File.join(File.dirname(__FILE__), 'category')

class Post
  include Mongoid::Document
  include Mongo::Voteable

  field :title
  field :content
  
  has_and_belongs_to_many :categories
  has_many :comments
  
  field :_id, type: String, default: -> { title }
  
  voteable self, :up => +1, :down => -1, :index => true
  voteable Category, :up => +3, :down => -5, :update_counters => false
end
