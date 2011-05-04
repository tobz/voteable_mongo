require File.join(File.dirname(__FILE__), 'category')

class Post
  include MongoMapper::Document
  include Mongo::Voteable

  key :title, String
  key :content, String
  
  key :category_ids, Array
  many :categories, :in => :category_ids

  many :comments

  voteable self, :up => +1, :down => -1, :index => true
  voteable Category, :up => +3, :down => -5, :update_counters => false
end
