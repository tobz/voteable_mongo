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
      
      field :u, :type => Array
      field :d, :type => Array
      field :uc, :type => Integer, :default => 0
      field :dc, :type => Integer, :default => 0
      field :c, :type => Integer, :default => 0
      field :p, :type => Integer, :default => 0
    end
  end
end
