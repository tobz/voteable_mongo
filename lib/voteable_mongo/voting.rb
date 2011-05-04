module Mongo
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
        # 
        # @return [votee, false]
        def vote(options)
          validate_and_normalize_vote_options(options)
          options[:voteable] = VOTEABLE[name][name]
          
          if options[:voteable]
             query, update = if options[:revote]
              revote_query_and_update(options)
            elsif options[:unvote]
              unvote_query_and_update(options)
            else
              new_vote_query_and_update(options)
            end

            # If votee exits or need to update parent
            # use Collection#find_and_modify to retrieve updated votes data and parent_ids
            doc = voteable_collection.find_and_modify(
              :query => query,
              :update => update,
              :new => true
            )

            if doc
              update_parent_votes(doc, options) if options[:voteable][:update_parents]
              # Update new votes data
              options[:votee].write_attribute('votes', doc['votes']) if options[:votee]
              options[:votee] || new(doc)
            else
              false
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
                'votes.point' => options[:voteable][options[:value]]
              }
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
              # Can skip $ne validation since creating a new vote
              # already warranty that a voter can vote one only
              # positive_voter_ids => { '$ne' => options[:voter_id] },
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
              # Can skip $ne validation since creating a new vote 
              # already warranty that a voter can vote one only
              # negative_voter_ids => { '$ne' => options[:voter_id] },
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
            VOTEABLE[name].each do |class_name, voteable|
              if metadata = voteable_relation(class_name)
                if parent_id = doc[voteable_foreign_key(metadata)]
                  parent_ids = parent_id.is_a?(Array) ? parent_id : [ parent_id ]
                  class_name.constantize.collection.update( 
                    { '_id' => { '$in' => parent_ids } },
                    { '$inc' => parent_inc_options(voteable, options) },
                    { :multi => true }
                  )
                end
              end
            end
          end

          
          def parent_inc_options(voteable, options)
            inc_options = {}

            if options[:revote]
              if options[:value] == :up
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
              inc_options['votes.point'] = -voteable[options[:value]]
              unless voteable[:update_counters] == false
                inc_options['votes.count'] = -1
                if options[:value] == :up
                  inc_options['votes.up_count'] = -1
                else
                  inc_options['votes.down_count'] = -1
                end
              end

            else # new vote
              inc_options['votes.point'] = voteable[options[:value]]
              unless voteable[:update_counters] == false
                inc_options['votes.count'] = +1
                if options[:value] == :up
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
