module Mongoid
  module Voteable
    module Tasks

      # Set counters and point to 0 for uninitialized voteable objects 
      # in order sort and query
      def self.init_stats(log = false)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          klass_voteable = voteable[class_name]
          puts "Init stats for #{class_name}" if log
          klass.collection.update({:votes => nil}, {
            '$set' => { :votes => Votes::DEFAULT_ATTRIBUTES }
          }, {
            :safe => true,
            :multi => true
          })
        end
      end
      
      # Re-generate vote counters and vote points
      def self.remake_stats(log = false)
        remake_stats_for_all_voteable_classes(log)
        update_parent_stats(log)
      end

      # Convert votes from from version < 0.7.0 to new data store
      def self.migrate_old_votes(log = false)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          klass_voteable = voteable[class_name]
          puts "* Migrating old vote data for #{class_name} ..." if log
          migrate_old_votes_for(klass, klass_voteable)
        end
      end
          
      def self.migrate_old_votes_for(klass, voteable)
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
                  'point' => voteable[:up]*up_count + voteable[:down]*down_count
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
      
        
      def self.remake_stats_for_all_voteable_classes(log)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          klass_voteable = voteable[class_name]
          puts "Generating stats for #{class_name}" if log
          klass.all.each{ |doc|
            remake_stats_for(doc, klass_voteable)
          }
        end
      end

  
      def self.remake_stats_for(doc, voteable)
        up_count = doc.up_voter_ids.length
        down_count = doc.down_voter_ids.length
    
        doc.update_attributes(
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
                update_parent_stats_for(doc, parent_class, foreign_key, parent_voteable)
              }
            end
          end
        end
      end
  
  
      def self.update_parent_stats_for(doc, parent_class, foreign_key, voteable)
        parent_id = doc.read_attribute(foreign_key.to_sym)
        if parent_id
          up_count = doc.up_voter_ids.length
          down_count = doc.down_voter_ids.length
      
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