module Mongo
  module Voting
    module Operations
      module Revote
        extend ActiveSupport::Concern
        module ClassMethods
          def revote_query_and_update(options)
            rel = embedded? && _inverse_relation
            if options[:value] == :up
              positive_voter_ids =          ["#{options[:voting_field]}.up", "#{rel}.$.#{options[:voting_field]}.up"]
              negative_voter_ids =          ["#{options[:voting_field]}.down", "#{rel}.$.#{options[:voting_field]}.down"]
              positive_votes_count =        ["#{options[:voting_field]}.up_count", "#{rel}.$.#{options[:voting_field]}.up_count"]
              negative_votes_count =        ["#{options[:voting_field]}.down_count","#{rel}.$.#{options[:voting_field]}.down_count"]
              positive_total_votes_count =  ["#{options[:voting_field]}.total_up_count","#{rel}.$.#{options[:voting_field]}.total_up_count"]
              negative_total_votes_count =  ["#{options[:voting_field]}.total_down_count","#{rel}.$.#{options[:voting_field]}.total_down_count"]
              point_delta = options[:voteable][:up] - options[:voteable][:down]
            else
              positive_voter_ids =          ["#{options[:voting_field]}.down", "#{rel}.$.#{options[:voting_field]}.down"]
              negative_voter_ids =          ["#{options[:voting_field]}.up", "#{rel}.$.#{options[:voting_field]}.up"]
              positive_votes_count =        ["#{options[:voting_field]}.down_count", "#{rel}.$.#{options[:voting_field]}.down_count"]
              negative_votes_count =        ["#{options[:voting_field]}.up_count", "#{rel}.$.#{options[:voting_field]}.up_count"]
              positive_total_votes_count =  ["#{options[:voting_field]}.total_down_count", "#{rel}.$.#{options[:voting_field]}.total_down_count"]
              negative_total_votes_count =  ["#{options[:voting_field]}.total_up_count", "#{rel}.$.#{options[:voting_field]}.total_up_count"]
              point_delta = -options[:voteable][:up] + options[:voteable][:down]
            end
            query = query_for_revote(options, negative_voter_ids, rel)
            update = update_for_revote(options, 
                                      negative_voter_ids, 
                                      positive_voter_ids, 
                                      positive_votes_count, 
                                      negative_votes_count, 
                                      positive_total_votes_count,
                                      negative_total_votes_count,
                                      point_delta, 
                                      rel)
            return query, update
          end
          def update_for_revote(options, negative_voter_ids, positive_voter_ids, positive_votes_count, negative_votes_count, positive_total_votes_count, negative_total_votes_count, point_delta, rel)
            if embedded?
             {
               # then update
               '$pull' => { negative_voter_ids.last => options[:voter_id] },
               '$push' => { positive_voter_ids.last => options[:voter_id] },
               '$inc' => {
                 positive_votes_count.last => +1,
                 negative_votes_count.last => -1,
                 positive_total_votes_count.last => +1,
                 negative_total_votes_count.last => -1,
                 "#{rel}.$.#{options[:voting_field]}.point" => point_delta
               }
             }
            else
             {
               '$pull' => { negative_voter_ids.first => options[:voter_id] },
               '$push' => { positive_voter_ids.first => options[:voter_id] },
               '$inc' => {
                 positive_votes_count.first => +1,
                 negative_votes_count.first => -1,
                 positive_total_votes_count.first => +1,
                 negative_total_votes_count.first => -1,
                 "#{options[:voting_field]}.point" => point_delta
               }
             }
            end
          end

          def query_for_revote(options, negative_voter_ids, rel)
            if embedded?
             {
               rel => {
                 "$elemMatch" => {
                   "_id" => options[:votee_id],
                   negative_voter_ids.first => options[:voter_id]
                 }
               }
             }
            else
             {
               :_id => options[:votee_id],
               negative_voter_ids.first => options[:voter_id]
             }
            end
          end
        end
      end
    end
  end
end