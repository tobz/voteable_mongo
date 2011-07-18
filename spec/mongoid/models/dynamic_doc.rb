require File.join(File.dirname(__FILE__), 'user')
require File.join(File.dirname(__FILE__), '/embedded/video')
class DynamicDoc
  include Mongoid::Document
  include Mongo::Voteable

  voteable self, :voting_field => :moderations  
  voteable self, :voting_field => :likes, :up => +2, :down => -2
  voteable User, :voting_field => :points, :up => +5, :down => -5
  
  belongs_to :user
  embeds_many :videos
end