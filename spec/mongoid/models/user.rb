class User
  include Mongoid::Document
  include Mongo::Voter
  include Mongo::Voteable
  
  # voteable self, :voting_field => :points
  has_many :dynamic_docs
end
