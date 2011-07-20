module Mongo
  module Voting
    module Operations
      module Unvote
        extend ActiveSupport::Concern
        module ClassMethods
          def unvote_query_and_update(options)
            rel = embedded? && _inverse_relation
            val = options[:value]
            voting_field = options[:voting_field]
            if options[:value] == :up
              positive_voter_ids    = ["#{voting_field}.up", "#{rel}.$.#{voting_field}.up"]
              positive_votes_count  = ["#{voting_field}.up_count", "#{rel}.$.#{voting_field}.up_count"]
              votes_total_count     = ["#{voting_field}.total_up_count", "#{rel}.$.#{voting_field}.total_up_count"]
            else
              positive_voter_ids    = ["#{voting_field}.down", "#{rel}.$.#{voting_field}.down"]
              positive_votes_count  = ["#{voting_field}.down_count","#{rel}.$.#{voting_field}.down_count"]
              votes_total_count     = ["#{voting_field}.total_down_count", "#{rel}.$.#{voting_field}.total_down_count"]
            end
            votes_count             = ["#{voting_field}.count", "#{rel}.$.#{voting_field}.count"]
            votes_point             = ["#{voting_field}.point", "#{rel}.$.#{voting_field}.point"]
            vote_ratio_field        = ["#{voting_field}.ratio","#{rel}.$.#{voting_field}.ratio"]
            votee = options[:votee]
            if val == :up
              vote_ratio_value = (votee.total_up_votes_count(voting_field) - 1).to_f / (votee.votes_count(voting_field))
            else
              vote_ratio_value = (votee.total_up_votes_count(voting_field)).to_f / (votee.votes_count(voting_field))
            end
            query = query_for_unvote(options, positive_voter_ids, rel)
            update = update_for_unvote(options,
                                       positive_voter_ids,
                                       votes_count,
                                       votes_point,
                                       positive_votes_count,
                                       votes_total_count,
                                       vote_ratio_field,
                                       vote_ratio_value)
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

          def update_for_unvote(options,
                                positive_voter_ids,
                                votes_count,
                                votes_point,
                                positive_votes_count,
                                votes_total_count,
                                vote_ratio_field,
                                vote_ratio_value)
            if embedded?
              {
                # then update
                '$pull' =>  { positive_voter_ids.last => options[:voter_id] },
                '$set' =>   { vote_ratio_field.last => vote_ratio_value},
                '$inc' =>   {
                  positive_votes_count.last => -1,
                  votes_count.last => -1,
                  votes_total_count.last => -1,
                  votes_point.last => -options[:voteable][options[:value]]
                }
              }
            else
              {
                # then update
                '$pull' =>  { positive_voter_ids.first => options[:voter_id] },
                '$set' =>   { vote_ratio_field.first => vote_ratio_value},
                '$inc' =>   {
                  positive_votes_count.first => -1,
                  votes_count.first => -1,
                  votes_total_count.first => -1,
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