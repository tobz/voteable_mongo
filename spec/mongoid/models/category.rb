class Category
  include Mongoid::Document
  include Mongo::Voteable

  field :name  

  has_and_belongs_to_many :posts
  
  voteable self, :index => true
end
