module Mongoid
  module Voteable
    module Stats
      extend ActiveSupport::Concern

      # Get the number of up votes
      def up_votes_count
        votes.try(:[], 'up_count') || 0
      end
    
      # Get the number of down votes
      def down_votes_count
        votes.try(:[], 'down_count') || 0
      end
    
      # Get the number of votes
      def votes_count
        votes.try(:[], 'count') || 0
      end
    
      # Get the votes point
      def votes_point
        votes.try(:[], 'point') || 0
      end
      
      def self.init(log = false)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          klass_voteable = voteable[class_name]
          puts "Init stats for #{class_name}" if log
          klass.collection.update({:votes => nil}, {
            '$set' => { :votes => VOTES_DEFAULT_ATTRIBUTES }
          }, {
            :safe => true,
            :multi => true
          })
        end
      end
      
      # Re-generate vote counters and vote points
      def self.remake(log = false)
        remake_stats(log)
        update_parent_stats(log)
      end
      
      def self.remake_stats(log)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          klass_voteable = voteable[class_name]
          puts "Generating stats for #{class_name}" if log
          klass.all.each{ |doc|
            doc.remake_stats(klass_voteable)
          }
        end
      end
      
      def remake_stats(voteable)
        up_count = up_voter_ids.length
        down_count = down_voter_ids.length
        
        update_attributes(
          'votes.up_count' => up_count,
          'votes.down_count' => down_count,
          'votes.count' => up_count + down_count,
          'votes.point' => voteable[:up]*up_count + voteable[:down]*down_count
        )
      end
    
      def self.update_parent_stats(log)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          voteable.each do |parent_class_name, parent_voteable|
            relation_metadata = klass.relations[parent_class_name.underscore]
            if relation_metadata
              parent_class = parent_class_name.constantize
              foreign_key = relation_metadata.foreign_key
              puts "Updating stats for #{class_name} > #{parent_class_name}" if log
              klass.all.each{ |doc|
                doc.update_parent_stats(parent_class, foreign_key, parent_voteable)
              }
            end
          end
        end
      end
      
      def update_parent_stats(parent_class, foreign_key, voteable)
        parent_id = read_attribute(foreign_key.to_sym)
        if parent_id
          up_count = up_voter_ids.length
          down_count = down_voter_ids.length
        
          return if up_count == 0 && down_count == 0

          inc_options = {
            'votes.point' => voteable[:up]*up_count + voteable[:down]*down_count
          }
          
          unless voteable[:update_counters] == false
            inc_options.merge!(
              'votes.count' => up_count + down_count,
              'votes.up_count' => up_count,
              'votes.down_count' => down_count
            )
          end
        
          parent_class.collection.update(
            { '_id' => parent_id }, 
            { '$inc' =>  inc_options },
            { :safe => true }
          )
        end
      end
      
    end
  end
end