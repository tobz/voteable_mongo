module Mongo
  module Voting
    module Operations
      module Newvote
        extend ActiveSupport::Concern
        module ClassMethods
          def new_vote_query(options)
            if embedded?
              {
                _inverse_relation => {
                  '$elemMatch' => {
                    "_id" => options[:votee_id],
                    "#{options[:voting_field]}.up" =>   { '$ne' => options[:voter_id] },
                    "#{options[:voting_field]}.down" => { '$ne' => options[:voter_id] },
                    "#{options[:voting_field]}.ip" =>   { '$ne' => options[:ip]}
                  }
                }
              }
            else
              {
                :_id => options[:votee_id],
                "#{options[:voting_field]}.up" =>   { '$ne' => options[:voter_id] },
                "#{options[:voting_field]}.down" => { '$ne' => options[:voter_id] },
                "#{options[:voting_field]}.ip" =>   { '$ne' => options[:ip]}
              }
            end
          end
          def new_vote_update(options, 
                              vote_option_count,
                              vote_count,
                              vote_point,
                              push_option,
                              vote_total_count,
                              vote_ratio_field,
                              vote_ratio_value)
            update = {
              '$inc' => {
                vote_count => +1,
                vote_option_count => +1,
                vote_total_count => +1,
                vote_point => options[:voteable][options[:value]]
              },
              '$set' => { vote_ratio_field => vote_ratio_value },
            }.merge!(push_option)
          end

          def new_vote_query_and_update(options)
            
            val = options[:value] # :up or :down
            voting_field          = options[:voting_field]
            vote_option_ids       = "#{options[:voting_field]}.#{val}"
            vote_option_count     = options[:voter_id] ? "#{options[:voting_field]}.#{val}_count" : "#{options[:voting_field]}.faceless_#{val}_count"
            vote_total_count      = "#{options[:voting_field]}.total_#{val}_count"
            vote_count            = "#{options[:voting_field]}.count"
            vote_point            = "#{options[:voting_field]}.point"
            ip_option             = "#{options[:voting_field]}.ip"
            vote_ratio_field      = "#{options[:voting_field]}.ratio"
            votee = options[:votee]
            if val == :up
              vote_ratio_value = (votee.total_up_votes_count(voting_field) + 1).to_f / (votee.votes_count(voting_field) + 1)
            else
              vote_ratio_value = (votee.total_up_votes_count(voting_field)).to_f / (votee.votes_count(voting_field) + 1)
            end
            if embedded?
              rel = "#{_inverse_relation}.$." # prepend relation for embedded collections
              vote_option_ids.prepend rel
              vote_option_count.prepend rel
              vote_total_count.prepend rel
              vote_count.prepend rel
              vote_point.prepend rel
              ip_option.prepend rel
              vote_ratio_field.prepend rel
            end
            ip_option = options[:ip].present? ? { ip_option => options[:ip] } : {}
            user_option = options[:voter_id].present? ? { vote_option_ids => options[:voter_id] } : {}
            combined_push = ip_option.merge(user_option)
            push_option = combined_push.empty? ? {} : { '$push' => combined_push }
            query = new_vote_query(options)
            update = new_vote_update(options, 
                                     vote_option_count,
                                     vote_count,
                                     vote_point,
                                     push_option,
                                     vote_total_count,
                                     vote_ratio_field,
                                     vote_ratio_value)
            return query, update
          end
        end
      end
    end
  end
end