class Category
  include MongoMapper::Document
  include Mongo::Voteable

  key :name, String

  key :post_ids, Array
  many :posts, :in => :post_ids
  
  voteable self, :index => true
end
