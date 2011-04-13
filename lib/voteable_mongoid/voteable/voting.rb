module Mongoid
  module Voteable
    module Voting
      extend ActiveSupport::Concern
      
      module ClassMethods
        # Make a vote on an object of this class
        #
        # @param [Hash] options a hash containings:
        #   - :votee_id: the votee document id
        #   - :voter_id: the voter document id
        #   - :value: :up or :down
        #   - :revote: if true change vote vote from :up to :down and vise versa
        #   - :unvote: if true undo the voting
        #   - :return_votes: if true always return updated votes data
        # 
        # @return [votes, false, nil]
        def vote(options)
          validate_and_normalize_vote_options(options)
          options[:voteable] = VOTEABLE[name][name]
          
          update_parents = options[:voteable][:update_parents]

          if options[:voteable]
             query, update = if options[:revote]
              revote_query_and_update(options)
            elsif options[:unvote]
              unvote_query_and_update(options)
            else
              new_vote_query_and_update(options)
            end

            if update_parents || options[:votee] || options[:return_votes]
              # If votee exits or need to update parent
              # use Collection#find_and_modify to retrieve updated votes data and parent_ids
              begin
                doc = collection.master.collection.find_and_modify(
                  :query => query,
                  :update => update,
                  :new => true
                )
                # Update new votes data
                votes = doc['votes']
                options[:votee].write_attribute('votes', votes) if options[:votee]
                update_parent_votes(doc, options) if update_parents
                return votes
              rescue
                # Don't update parents if operation fail or no matching object found
                return false
              end
            else
              # Just update and don't care the result
              collection.update(query, update)
            end
          end
        end

        
        private
          def validate_and_normalize_vote_options(options)
            options.symbolize_keys!
            options[:votee_id] = BSON::ObjectId(options[:votee_id]) if options[:votee_id].is_a?(String)
            options[:voter_id] = BSON::ObjectId(options[:voter_id]) if options[:voter_id].is_a?(String)
            options[:value] &&= options[:value].to_sym
          end
        
          def new_vote_query_and_update(options)
            if options[:value] == :up
              positive_voter_ids = 'votes.up'
              positive_votes_count = 'votes.up_count'
            else
              positive_voter_ids = 'votes.down'
              positive_votes_count = 'votes.down_count'
            end

            return {
              # Validate voter_id did not vote for votee_id yet
              :_id => options[:votee_id],
              'votes.up' => { '$ne' => options[:voter_id] },
              'votes.down' => { '$ne' => options[:voter_id] }
            }, {
              # then update
              '$push' => { positive_voter_ids => options[:voter_id] },
              '$inc' => {  
                'votes.count' => +1,
                positive_votes_count => +1,
                'votes.point' => options[:voteable][options[:value]] }
            }
          end

          
          def revote_query_and_update(options)
            if options[:value] == :up
              positive_voter_ids = 'votes.up'
              negative_voter_ids = 'votes.down'
              positive_votes_count = 'votes.up_count'
              negative_votes_count = 'votes.down_count'
              point_delta = options[:voteable][:up] - options[:voteable][:down]
            else
              positive_voter_ids = 'votes.down'
              negative_voter_ids = 'votes.up'
              positive_votes_count = 'votes.down_count'
              negative_votes_count = 'votes.up_count'
              point_delta = -options[:voteable][:up] + options[:voteable][:down]
            end

            return {
              # Validate voter_id did a vote with value for votee_id
              :_id => options[:votee_id],
              positive_voter_ids => { '$ne' => options[:voter_id] },
              negative_voter_ids => options[:voter_id]
            }, {
              # then update
              '$pull' => { negative_voter_ids => options[:voter_id] },
              '$push' => { positive_voter_ids => options[:voter_id] },
              '$inc' => {
                positive_votes_count => +1,
                negative_votes_count => -1,
                'votes.point' => point_delta
              }
            }
          end
          

          def unvote_query_and_update(options)
            if options[:value] == :up
              positive_voter_ids = 'votes.up'
              negative_voter_ids = 'votes.down'
              positive_votes_count = 'votes.up_count'
            else
              positive_voter_ids = 'votes.down'
              negative_voter_ids = 'votes.up'
              positive_votes_count = 'votes.down_count'
            end

            return {
              :_id => options[:votee_id],
              # Validate if voter_id did a vote with value for votee_id
              negative_voter_ids => { '$ne' => options[:voter_id] },
              positive_voter_ids => options[:voter_id]
            }, {
              # then update
              '$pull' => { positive_voter_ids => options[:voter_id] },
              '$inc' => {
                positive_votes_count => -1,
                'votes.count' => -1,
                'votes.point' => -options[:voteable][options[:value]]
              }
            }
          end
          

          def update_parent_votes(doc, options)
            value = options[:value]
            votee ||= options[:votee]
            
            VOTEABLE[name].each do |class_name, voteable|
              # For other class in VOTEABLE options, if is parent of current class
              next unless relation_metadata = relations[class_name.underscore]
              # If can find current votee foreign_key value for that class
              next unless foreign_key_value = doc[relation_metadata.foreign_key.to_s]

              class_name.constantize.collection.update(
                { '_id' => foreign_key_value }, 
                { '$inc' => parent_inc_options(value, voteable, options) }
              )
            end
          end

          
          def parent_inc_options(value, voteable, options)
            inc_options = {}

            if options[:revote]
              if value == :up
                inc_options['votes.point'] = voteable[:up] - voteable[:down]
                unless voteable[:update_counters] == false
                  inc_options['votes.up_count'] = +1
                  inc_options['votes.down_count'] = -1
                end
              else
                inc_options['votes.point'] = -voteable[:up] + voteable[:down]
                unless voteable[:update_counters] == false
                  inc_options['votes.up_count'] = -1
                  inc_options['votes.down_count'] = +1
                end
              end

            elsif options[:unvote]
              inc_options['votes.point'] = -voteable[value]
              unless voteable[:update_counters] == false
                inc_options['votes.count'] = -1
                if value == :up
                  inc_options['votes.up_count'] = -1
                else
                  inc_options['votes.down_count'] = -1
                end
              end

            else # new vote
              inc_options['votes.point'] = voteable[value]
              unless voteable[:update_counters] == false
                inc_options['votes.count'] = +1
                if value == :up
                  inc_options['votes.up_count'] = +1
                else
                  inc_options['votes.down_count'] = +1
                end
              end
            end

            inc_options
          end
      end
            
    end
  end
end
