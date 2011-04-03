module Mongoid
  module Voteable
    
    class Votes
      include Mongoid::Document
      field :up, :type => Array, :default => []
      field :down, :type => Array, :default => []
      field :up_count, :type => Integer, :default => 0
      field :down_count, :type => Integer, :default => 0
      field :count, :type => Integer, :default => 0
      field :point, :type => Integer, :default => 0
    end
    
    VOTES_DEFAULT_ATTRIBUTES = Votes.new.attributes
    VOTES_DEFAULT_ATTRIBUTES.delete('_id')
  end
end
