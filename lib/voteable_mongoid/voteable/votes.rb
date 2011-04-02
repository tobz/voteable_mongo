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
    
    def self.migrate_old_votes(log = false)
      VOTEABLE.each do |class_name, voteable|
        klass = class_name.constantize
        klass_voteable = voteable[class_name]
        puts "* Migrating old vote data for #{class_name} ..." if log

        klass.all.each do |doc|
          # Version 0.6.x use very short field names (u, d, uc, dc, c, p) to minimize 
          # votes storage but it's not human friendly
          # Version >= 0.7.0 use readable field names (up, down, up_count, down_count,
          # count, point)
          votes = doc['votes'] || doc['voteable'] || {}

          up_voter_ids = votes['u'] || votes['up'] || 
            votes['up_voter_ids'] || doc['up_voter_ids'] || []

          down_voter_ids = votes['d'] || votes['down'] || 
            votes['down_voter_ids'] || doc['down_voter_ids'] || []
          
          up_count = up_voter_ids.size
          down_count = down_voter_ids.size
          
          klass.collection.update({ :_id => doc.id }, {
            '$set' => {
                'votes' => {
                  'up' => up_voter_ids,
                  'down' => down_voter_ids,
                  'up_count' => up_count,
                  'down_count' => down_count,
                  'count' => up_count + down_count,
                  'point' => klass_voteable[:up]*up_count + klass_voteable[:down]*down_count
                }
            },
            '$unset' => {
              'up_voter_ids' => true,
              'down_voter_ids' => true,
              'votes_count' => true,
              'votes_point' => true,
              'voteable' => true
            }
          }, { :safe => true })
        end
      end
    end
    
  end
end
