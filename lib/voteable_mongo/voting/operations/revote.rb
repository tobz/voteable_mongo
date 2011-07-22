module Mongo
  module Voting
    module Operations
      module Revote
        extend ActiveSupport::Concern
        module ClassMethods
          def revote_query_and_update(options)
            rel = embedded? && _inverse_relation
            val = options[:value]
            voting_field = options[:voting_field]
            
            # Every field name has its variant for master collection
            # and embedded documents. 
            # eg: [votes.up, imags.$.votes.up]
            if options[:value] == :up
              positive_voter_ids          = ["#{voting_field}.up", "#{rel}.$.#{voting_field}.up"]
              negative_voter_ids          = ["#{voting_field}.down", "#{rel}.$.#{voting_field}.down"]
              positive_votes_count        = ["#{voting_field}.up_count", "#{rel}.$.#{voting_field}.up_count"]
              negative_votes_count        = ["#{voting_field}.down_count","#{rel}.$.#{voting_field}.down_count"]
              positive_total_votes_count  = ["#{voting_field}.total_up_count","#{rel}.$.#{voting_field}.total_up_count"]
              negative_total_votes_count  = ["#{voting_field}.total_down_count","#{rel}.$.#{voting_field}.total_down_count"]
              point_delta = options[:voteable][:up] - options[:voteable][:down]
            else
              positive_voter_ids          = ["#{voting_field}.down", "#{rel}.$.#{voting_field}.down"]
              negative_voter_ids          = ["#{voting_field}.up", "#{rel}.$.#{voting_field}.up"]
              positive_votes_count        = ["#{voting_field}.down_count", "#{rel}.$.#{voting_field}.down_count"]
              negative_votes_count        = ["#{voting_field}.up_count", "#{rel}.$.#{voting_field}.up_count"]
              positive_total_votes_count  = ["#{voting_field}.total_down_count", "#{rel}.$.#{voting_field}.total_down_count"]
              negative_total_votes_count  = ["#{voting_field}.total_up_count", "#{rel}.$.#{voting_field}.total_up_count"]
              point_delta = -options[:voteable][:up] + options[:voteable][:down]
            end
            vote_ratio_field = ["#{voting_field}.ratio","#{rel}.$.#{voting_field}.ratio"]
            votee = options[:votee]
            
            # calculating ratio
            if val == :up
              vote_ratio_value = (votee.total_up_votes_count(voting_field) + 1).to_f / (votee.votes_count(voting_field))
            else
              vote_ratio_value = (votee.total_up_votes_count(voting_field) - 1).to_f / (votee.votes_count(voting_field))
            end
            query = query_for_revote(options, negative_voter_ids, rel)
            update = update_for_revote(options, 
                                      negative_voter_ids, 
                                      positive_voter_ids, 
                                      positive_votes_count, 
                                      negative_votes_count, 
                                      positive_total_votes_count,
                                      negative_total_votes_count,
                                      vote_ratio_field,
                                      vote_ratio_value,
                                      point_delta, 
                                      rel)
            return query, update
          end
          
          # Builds update statement for FindAndModify
          # 
          # @param [Array] negative_voter_ids, eg: ["votes.up", "images.$.votes.up"]
          # @param [Array] positive_voter_ids, eg: ["votes.down", "images.$.votes.down"]
          # @param [Array] positive_votes_count, eg: ["votes.up_count", "images.$.votes.up_count"]
          # @param [Array] negative_votes_count, eg: ["votes.down_count", "images.$.votes.down_count"]
          # @param [Array] positive_total_votes_count, eg: ["votes.total_up_count", "images.$.votes.total_up_count"]
          # @param [Array] negative_total_votes_count, eg: ["votes.total_down_count", "images.$.votes.total_down_count"]
          # @param [Array] vote_ratio_field, eg: ["votes.ratio", "images.$.votes.ratio"]
          # @param [Float] vote_ratio_value, eg: 0.4
          # @param [Integer] point_delta is the difference in points for the revote
          # @param [String] rel is the embedding relation name, eg: "images"
          # 
          # @return [Hash] update statement
          # TODO: place arguments inside some hash 
          def update_for_revote(options, 
                                negative_voter_ids, 
                                positive_voter_ids, 
                                positive_votes_count, 
                                negative_votes_count, 
                                positive_total_votes_count, 
                                negative_total_votes_count, 
                                vote_ratio_field, 
                                vote_ratio_value, 
                                point_delta, 
                                rel)
            if embedded?
             {
               # then update
               '$pull' => { negative_voter_ids.last => options[:voter_id] },
               '$push' => { positive_voter_ids.last => options[:voter_id] },
               '$set' =>  { vote_ratio_field.last => vote_ratio_value },
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
               '$set' =>  { vote_ratio_field.first => vote_ratio_value },
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

          # Build query statement of FindAndModify
          # 
          # @param [Hash] options
          # @param [Array] negative_voter_ids, eg: ["votes.up", "images.$.votes.up"]
          # @param [String] rel is the name of the relation for embedded document, eg: "images"
          # 
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