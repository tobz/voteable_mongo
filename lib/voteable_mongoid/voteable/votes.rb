module Mongoid
  module Voteable
    UP_VOTER_IDS      = 'votes.u'
    DOWN_VOTER_IDS    = 'votes.d'
    UP_VOTES_COUNT    = 'votes.uc'
    DOWN_VOTES_COUNT  = 'votes.dc'
    VOTES_COUNT       = 'votes.c'
    VOTES_POINT       = 'votes.p'
    
    class Votes
      include Mongoid::Document
      
      field :u, :type => Array, :default => []
      field :d, :type => Array, :default => []
      field :uc, :type => Integer, :default => 0
      field :dc, :type => Integer, :default => 0
      field :c, :type => Integer, :default => 0
      field :p, :type => Integer, :default => 0
      
      def identity
        # To remove _id
      end
    end
    
    VOTES_DEFAULT_ATTRIBUTES = Votes.new.attributes
    VOTES_DEFAULT_ATTRIBUTES.delete('_id')
  end
end
