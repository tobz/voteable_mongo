module Mongoid
  module Voteable
    module Stats
      extend ActiveSupport::Concern

      included do
        index 'voteable.up_votes_count'
        index 'voteable.down_votes_count'
        index 'voteable.votes_count'
        index 'voteable.votes_point'
      
        scope :most_up_voted, order_by(['voteable.up_votes_count', :desc])
        scope :most_down_voted, order_by(['voteable.down_votes_count', :desc])
        scope :most_voted, order_by(['voteable.votes_count', :desc])
        scope :best_voted, order_by(['voteable.votes_point', :desc])
      end
    
      # Get the number of up votes
      def up_votes_count
        voteable.try(:[], 'up_votes_count') || 0
      end
    
      # Get the number of down votes
      def down_votes_count
        voteable.try(:[], 'down_votes_count') || 0
      end
    
      # Get the number of votes
      def votes_count
        voteable.try(:[], 'votes_count') || 0
      end
    
      # Get the votes point
      def votes_point
        voteable.try(:[], 'votes_point') || 0
      end

      def self.remake(log = false)
        remake_stats(log)
        update_parent_stats(log)
      end
      
      def self.remake_stats(log)
        Mongoid::Voteable::VOTE_POINT.each do |class_name, value_point|
          klass = class_name.constantize
          klass_value_point = value_point[class_name]
          puts "Generating stats for #{class_name}" if log
          klass.voteable_related.each{ |doc|
            doc.remake_stats(klass_value_point)
          }
        end
      end
      
      def remake_stats(value_point)
        up_count = up_voter_ids.length
        down_count = down_voter_ids.length

        update_attributes(
          'voteable.up_votes_count' => up_count,
          'voteable.down_votes_count' => down_count,          
          'voteable.votes_count' => up_count + down_count,
          'voteable.votes_point' => value_point[:up]*up_count + value_point[:down]*down_count
        )
      end
    
      def self.update_parent_stats(log)
        VOTE_POINT.each do |class_name, value_point|
          klass = class_name.constantize
          value_point.each do |parent_class_name, parent_value_point|
            relation_metadata = klass.relations[parent_class_name.underscore]
            if relation_metadata
              parent_class = parent_class_name.constantize
              foreign_key = relation_metadata.foreign_key
              puts "Updating stats for #{class_name} > #{parent_class_name}" if log
              klass.voteable_related.each{ |doc|
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
            'voteable.votes_point' => value_point[:up]*up_count + value_point[:down]*down_count
          }
      
          unless value_point[:update_counters] == false
            inc_options.merge!(
              'voteable.votes_count' => up_count + down_count,
              'voteable.up_votes_count' => up_count,
              'voteable.down_votes_count' => down_count
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