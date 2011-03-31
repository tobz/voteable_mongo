module Mongoid
  module Voteable
    module Stats
      extend ActiveSupport::Concern

      # Get the number of up votes
      def up_votes_count
        votes.try(:[], 'uc') || 0
      end
    
      # Get the number of down votes
      def down_votes_count
        votes.try(:[], 'dc') || 0
      end
    
      # Get the number of votes
      def votes_count
        votes.try(:[], 'c') || 0
      end
    
      # Get the votes point
      def votes_point
        votes.try(:[], 'p') || 0
      end

      # Re-generate vote counters and vote points
      def self.remake(log = false)
        remake_stats(log)
        update_parent_stats(log)
      end
      
      def self.remake_stats(log)
        VOTEABLE.each do |class_name, value_point|
          klass = class_name.constantize
          klass_value_point = value_point[class_name]
          puts "Generating stats for #{class_name}" if log
          klass.all.each{ |doc|
            doc.remake_stats(klass_value_point)
          }
        end
      end
      
      def remake_stats(value_point)
        up_count = up_voter_ids.length
        down_count = down_voter_ids.length
        
        update_attributes(
          UP_VOTES_COUNT => up_count,
          DOWN_VOTES_COUNT => down_count,          
          VOTES_COUNT => up_count + down_count,
          VOTES_POINT => value_point[:up]*up_count + value_point[:down]*down_count
        )
      end
    
      def self.update_parent_stats(log)
        VOTEABLE.each do |class_name, value_point|
          klass = class_name.constantize
          value_point.each do |parent_class_name, parent_value_point|
            relation_metadata = klass.relations[parent_class_name.underscore]
            if relation_metadata
              parent_class = parent_class_name.constantize
              foreign_key = relation_metadata.foreign_key
              puts "Updating stats for #{class_name} > #{parent_class_name}" if log
              klass.all.each{ |doc|
                doc.update_parent_stats(parent_class, foreign_key, parent_value_point)
              }
            end
          end
        end
      end
      
      def update_parent_stats(parent_class, foreign_key, value_point)
        parent_id = read_attribute(foreign_key.to_sym)
        if parent_id
          up_count = up_voter_ids.length
          down_count = down_voter_ids.length
        
          return if up_count == 0 && down_count == 0

          inc_options = {
            VOTES_POINT => value_point[:up]*up_count + value_point[:down]*down_count
          }
          
          unless value_point[:update_counters] == false
            inc_options.merge!(
              VOTES_COUNT => up_count + down_count,
              UP_VOTES_COUNT => up_count,
              DOWN_VOTES_COUNT => down_count
            )
          end
        
          parent_class.collection.update(
            { :_id => parent_id }, 
            { '$inc' =>  inc_options }
          )
        end
      end
      
    end
  end
end