require File.join(File.dirname(__FILE__), 'category')
require File.join(File.dirname(__FILE__), '/embedded/image')

class Post
  include Mongoid::Document
  include Mongo::Voteable

  field :title
  field :content
  
  # callbacks
  before_vote :before_post_vote
  after_vote :after_post_vote
  
  def before_post_vote; end;
  def after_post_vote; end;
  
  has_and_belongs_to_many :categories
  has_many :comments
  embeds_many :images
  embeds_many :audios
  
  key :title
  
  voteable self, :up => +1, :down => -1, :index => true
  voteable Category, :up => +3, :down => -5, :update_counters => false
end
