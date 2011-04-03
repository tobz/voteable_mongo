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
        #   - :revote: change from vote up to vote down
        #   - :unvote: unvote the vote value (:up or :down)
        def vote(options)
          options.symbolize_keys!
          value = options[:value].to_sym

          votee_id = options[:votee_id]
          voter_id = options[:voter_id]

          votee_id = BSON::ObjectId(votee_id) if votee_id.is_a?(String)
          voter_id = BSON::ObjectId(voter_id) if voter_id.is_a?(String)

          successed = true

          if voteable = VOTEABLE[name][name]
            if options[:revote]
              if value == :up
                positive_voter_ids = 'votes.up'
                negative_voter_ids = 'votes.down'
                positive_votes_count = 'votes.up_count'
                negative_votes_count = 'votes.down_count'
                point_delta = voteable[:up] - voteable[:down]
              else
                positive_voter_ids = 'votes.down'
                negative_voter_ids = 'votes.up'
                positive_votes_count = 'votes.down_count'
                negative_votes_count = 'votes.up_count'
                point_delta = -voteable[:up] + voteable[:down]
              end

              update_result = collection.update({ 
                # Validate voter_id did a vote with value for votee_id
                :_id => votee_id,
                positive_voter_ids => { '$ne' => voter_id },
                negative_voter_ids => voter_id
              }, {
                # then update
                '$pull' => { negative_voter_ids => voter_id },
                '$push' => { positive_voter_ids => voter_id },
                '$inc' => {
                  positive_votes_count => +1,
                  negative_votes_count => -1,
                  'votes.point' => point_delta
                }
              }, {
                :safe => true
              })

            elsif options[:unvote]
              if value == :up
                positive_voter_ids = 'votes.up'
                negative_voter_ids = 'votes.down'
                positive_votes_count = 'votes.up_count'
              else
                positive_voter_ids = 'votes.down'
                negative_voter_ids = 'votes.up'
                positive_votes_count = 'votes.down_count'
              end

              # Check if voter_id did a vote with value for votee_id
              update_result = collection.update({ 
                # Validate voter_id did a vote with value for votee_id
                :_id => votee_id,
                negative_voter_ids => { '$ne' => voter_id },
                positive_voter_ids => voter_id
              }, {
                # then update
                '$pull' => { positive_voter_ids => voter_id },
                '$inc' => {
                  positive_votes_count => -1,
                  'votes.count' => -1,
                  'votes.point' => -voteable[value]
                }
              }, {
                :safe => true
              })

            else # new vote
              if value.to_sym == :up
                positive_voter_ids = 'votes.up'
                positive_votes_count = 'votes.up_count'
              else
                positive_voter_ids = 'votes.down'
                positive_votes_count = 'votes.down_count'
              end

              update_result = collection.update({ 
                # Validate voter_id did not vote for votee_id yet
                :_id => votee_id,
                'votes.up' => { '$ne' => voter_id },
                'votes.down' => { '$ne' => voter_id }
              }, {
                # then update
                '$push' => { positive_voter_ids => voter_id },
                '$inc' => {  
                  'votes.count' => +1,
                  positive_votes_count => +1,
                  'votes.point' => voteable[value] }
              }, {
                :safe => true
              })
            end

            successed = ( update_result['err'] == nil and 
              update_result['updatedExisting'] == true and
              update_result['n'] == 1 )
          end

          # Only update parent class if votee is updated successfully
          if successed
            update_parent_votes(options)
          end

          successed
        end
        
        private
          def update_parent_votes(options)
            value = options[:value].to_sym
            votee ||= options[:votee]
            
            VOTEABLE[name].each do |class_name, voteable|
              # For other class in VOTEABLE options, if is parent of current class
              next unless relation_metadata = relations[class_name.underscore]
              votee ||= find(options[:votee_id])
              # If can find current votee foreign_key value for that class
              next unless foreign_key_value = votee.read_attribute(relation_metadata.foreign_key)

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

              class_name.constantize.collection.update(
                { '_id' => foreign_key_value }, 
                { '$inc' => inc_options }
              )
            end
          end
      end
            
    end
  end
end
