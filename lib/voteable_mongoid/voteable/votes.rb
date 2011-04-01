module Mongoid
  module Voteable
    
    class Votes
      include Mongoid::Document
      field :u, :type => Array, :default => []
      field :d, :type => Array, :default => []
      field :uc, :type => Integer, :default => 0
      field :dc, :type => Integer, :default => 0
      field :c, :type => Integer, :default => 0
      field :p, :type => Integer, :default => 0
    end

    UP_VOTER_IDS      = 'votes.u'
    DOWN_VOTER_IDS    = 'votes.d'
    UP_VOTES_COUNT    = 'votes.uc'
    DOWN_VOTES_COUNT  = 'votes.dc'
    VOTES_COUNT       = 'votes.c'
    VOTES_POINT       = 'votes.p'
    
    VOTES_DEFAULT_ATTRIBUTES = Votes.new.attributes
    VOTES_DEFAULT_ATTRIBUTES.delete('_id')
    
    def self.migrate_old_votes(log = false)
      VOTEABLE.each do |class_name, value_point|
        klass = class_name.constantize
        klass_value_point = value_point[class_name]
        puts "* Migrating old vote data for #{class_name} ..." if log
        count = 0
        klass.all.each do |doc|
          next if doc['votes']
          count += 1
          up_voter_ids = doc['up_voter_ids'] || []
          down_voter_ids = doc['down_voter_ids'] || []
          up_count = up_voter_ids.size
          down_count = down_voter_ids.size
          klass.collection.update({ :_id => doc.id }, {
            '$set' => {
                :votes => {
                  :u => doc.up_voter_ids,
                  :d => doc.down_voter_ids,
                  :uc => up_count,
                  :dc => down_count,
                  :c => up_count + down_count,
                  :p => klass_value_point[:up]*up_count + klass_value_point[:down]*down_count
                }
            },
            '$unset' => {
              :up_voter_ids => true,
              :down_voter_ids => true,
              :votes_count => true,
              :votes_point => true
            }
          })
        end
        puts "  #{count} objects migrated." if log
      end
    end
    
  end
end
