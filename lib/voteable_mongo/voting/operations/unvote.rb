module Mongo
  module Voting
    module Operations
      module Unvote
        extend ActiveSupport::Concern
        module ClassMethods
          def unvote_query_and_update(options)
            rel = embedded? && _inverse_relation
            if options[:value] == :up
              positive_voter_ids    = ["#{options[:voting_field]}.up", "#{rel}.$.#{options[:voting_field]}.up"]
              positive_votes_count  = ["#{options[:voting_field]}.up_count", "#{rel}.$.#{options[:voting_field]}.up_count"]
            else
              positive_voter_ids    = ["#{options[:voting_field]}.down", "#{rel}.$.#{options[:voting_field]}.down"]
              positive_votes_count  = ["#{options[:voting_field]}.down_count","#{rel}.$.#{options[:voting_field]}.down_count"]
            end
            votes_count           = ["#{options[:voting_field]}.count", "#{rel}.$.#{options[:voting_field]}.count"]
            votes_point           = ["#{options[:voting_field]}.point", "#{rel}.$.#{options[:voting_field]}.point"]

            query = query_for_unvote(options, positive_voter_ids, rel)
            update = update_for_unvote(options, positive_voter_ids, votes_count, votes_point, positive_votes_count)
            return query, update
          end
          
          def query_for_unvote(options, positive_voter_ids, rel)
            if embedded?
              {
                rel => {
                  "$elemMatch" => {
                    "_id" => options[:votee_id],
                    positive_voter_ids.first => options[:voter_id]
                  }
                }
              }
            else
              {
                :_id => options[:votee_id],
                positive_voter_ids.first => options[:voter_id]
              }
            end
          end

          def update_for_unvote(options, positive_voter_ids, votes_count, votes_point, positive_votes_count)
            if embedded?
              {
                # then update
                '$pull' => { positive_voter_ids.last => options[:voter_id] },
                '$inc' => {
                  positive_votes_count.last => -1,
                  votes_count.last => -1,
                  votes_point.last => -options[:voteable][options[:value]]
                }
              }
            else
              {
                # then update
                '$pull' => { positive_voter_ids.first => options[:voter_id] },
                '$inc' => {
                  positive_votes_count.first => -1,
                  votes_count.first => -1,
                  votes_point.first => -options[:voteable][options[:value]]
                }
              }
            end
          end
        end
      end
    end
  end
end