module Mongo
  module Voteable
    module Tasks

      # Set counters and point to 0 for uninitialized voteable objects
      # in order sort and query

      def self.init_stats(log = false)
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          voteable[voteable.keys.first].each do |voting_hash|
            if klass.embedded?
              master_class = klass._parent_klass
              query = { "#{klass._inverse_relation}.#{voting_hash[:voting_field]}" => nil}
              update = { "$set" => {"#{klass._inverse_relation}.$.#{voting_hash[:voting_field]}" => DEFAULT_VOTES } }
            else
              master_class = klass
              query = { voting_hash[:voting_field] => nil}
              update = { '$set' => { voting_hash[:voting_field] => DEFAULT_VOTES } }
            end
            puts "Init stats for #{class_name}" if log
            master_class.collection.update(query, update, {
              :safe => true,
              :multi => true
            })
          end
        end
      end
      
      # Reset votes stats of a given collection or embedded document class.
      # !! It will erase votes if already present!!
      def self.reset_stats(klass, log = false)
        puts "Reset stats for #{klass.name}" if log
        voteables = VOTEABLE.find{|k,v| k == klass.name }.last
        voteables[voteables.keys.first].each do |voting_hash|
          if klass.embedded?
            master_class = klass._parent_klass
            query = { "#{klass._inverse_relation}.#{voting_hash[:voting_field]}" => {"$exists" => true}}
            update = { "$set" => {"#{klass._inverse_relation}.$.#{voting_hash[:voting_field]}" => DEFAULT_VOTES } }
          else
            master_class = klass
            query = {}
            update = { '$set' => { voting_hash[:voting_field] => DEFAULT_VOTES } }
          end
          puts "Init stats for #{klass.name}" if log
          master_class.collection.update(query, update, {
            :safe => true,
            :multi => true
          })
        end
      end

      # Re-generate vote counters and vote points
      def self.remake_stats(log = false)
        master_classes, embedded_classes = {}, {}
        VOTEABLE.each do |class_name, voteable|
          klass = class_name.constantize
          if klass.embedded?
            embedded_classes[klass] = voteable 
          else
            master_classes[klass] = voteable
          end
        end
        remake_stats_for_all_master_classes(master_classes, log)
        remake_stats_for_all_embedded_classes(embedded_classes, log)
        update_parent_for_master_classes(master_classes, log)
        update_parent_for_embedded_classes(embedded_classes, log)
      end
      
      def self.remake_stats_for_all_master_classes(master_classes, log)
        master_classes.each do |klass, voteable|
          klass_voteables = voteable[klass.name]
          klass_voteables.each do |klass_voteable|
            klass.all.each{ |doc|
              remake_stats_for(doc, klass_voteable)
            }
          end
        end
      end
      
      # For embedded classes we need to iterate through all parent records.
      def self.remake_stats_for_all_embedded_classes(embedded_classes, log)
        embedded_classes.each do |klass, voteable|
          master_klass = klass._parent_klass
          klass_voteables = voteable[klass.name]
          klass_voteables.each do |klass_voteable|
            master_klass.all.each do |master_doc|
              master_doc.send(klass._inverse_relation).each do |doc|
                remake_stats_for(doc, klass_voteable)
              end
            end
          end
        end
      end
      
      def self.update_parent_for_master_classes(master_classes, log)
        master_classes.each do |klass, voteable|
          voteable.each do |parent_class_name, parent_voteables|
            parent_voteables.each do |parent_voteable|
              metadata = klass.voteable_relation(parent_class_name)
              if metadata
                parent_class = parent_class_name.constantize
                foreign_key = klass.voteable_foreign_key(metadata)
                puts "Updating stats for #{class_name} > #{parent_class_name}" if log
                klass.all.each{ |doc|
                  update_parent_stats_for(doc, parent_class, parent_voteable, foreign_key)
                }
              end
            end
          end
        end
      end
      
      def self.update_parent_for_embedded_classes(embedded_classes, log)
        embedded_classes.each do |klass, voteable|
          voteable.each do |parent_class_name, parent_voteables|
            parent_voteables.each do |parent_voteable|
              metadata = klass.voteable_relation(parent_class_name)
              if metadata
                parent_class = parent_class_name.constantize
                puts "Updating stats for #{class_name} > #{parent_class_name}" if log
                parent_class.all.each do |master_doc|
                  master_doc.send(klass._inverse_relation).each do |doc|
                    update_parent_stats_for(doc, parent_class, parent_voteable)
                  end
                end
              end
            end
          end
        end
      end
      
      def self.remake_stats_for(doc, voteable)
        up_count = doc.up_voter_ids(voteable[:voting_field]).length
        down_count = doc.down_voter_ids(voteable[:voting_field]).length
        faceless_up_count = doc.faceless_up_votes_count(voteable[:voting_field])
        faceless_down_count = doc.faceless_down_votes_count(voteable[:voting_field])
        total_up_count = up_count + faceless_up_count
        total_down_count = down_count + faceless_down_count
        
        doc.update_attributes(
        voteable[:voting_field] => {
          'up' => doc.up_voter_ids(voteable[:voting_field]),
          'down' => doc.down_voter_ids(voteable[:voting_field]),
          'up_count' => up_count,
          'down_count' => down_count,
          'faceless_up_count' => faceless_up_count,
          'faceless_down_count' => faceless_down_count,
          'total_up_count' => total_up_count,
          'total_down_count' => total_down_count,
          'count' => total_up_count + total_down_count,
          'point' => voteable[:up].to_i*total_up_count + voteable[:down].to_i*total_down_count
        }
        )
      end

      def self.update_parent_stats_for(doc, parent_class, voteable, foreign_key = nil)
        if foreign_key
          parent_id = doc.read_attribute(foreign_key.to_sym)
        else
          parent_name = parent_class.name.downcase
          parent_id = doc.send(parent_name).id
        end
        if parent_id
          up_count = doc.up_voter_ids.length
          down_count = doc.down_voter_ids.length
          faceless_up_count = doc.faceless_up_votes_count
          faceless_down_count = doc.faceless_down_votes_count
          total_up_count = doc.total_up_votes_count
          total_down_count = doc.total_down_votes_count

          return if up_count == 0 && down_count == 0 && faceless_up_count == 0 && faceless_down_count == 0

          inc_options = {
            "#{voteable[:voting_field]}.point" => voteable[:up].to_i*(total_up_count) + voteable[:down].to_i*(total_down_count)
          }

          unless voteable[:update_counters] == false
            inc_options.merge!(
            "#{voteable[:voting_field]}.count" => total_up_count + total_down_count,
            "#{voteable[:voting_field]}.up_count" => up_count,
            "#{voteable[:voting_field]}.down_count" => down_count,
            "#{voteable[:voting_field]}.faceless_up_count" => faceless_up_count,
            "#{voteable[:voting_field]}.faceless_down_count" => faceless_down_count,
            "#{voteable[:voting_field]}.total_up_count" => total_up_count,
            "#{voteable[:voting_field]}.total_down_count" => total_down_count
            )
          end

          parent_ids = parent_id.is_a?(Array) ? parent_id : [ parent_id ]

          parent_class.collection.update(
          { '_id' => { '$in' => parent_ids } },
          { '$inc' =>  inc_options },
          { :safe => true, :multi => true }
          )
        end
      end
    end
  end
end
