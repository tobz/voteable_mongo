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
                    "#{options[:voting_field]}.up" => { '$ne' => options[:voter_id] },
                    "#{options[:voting_field]}.down" => { '$ne' => options[:voter_id] },
                    "#{options[:voting_field]}.ip" => { '$ne' => options[:ip]}
                  }
                }
              }
            else
              {
                :_id => options[:votee_id],
                "#{options[:voting_field]}.up" => { '$ne' => options[:voter_id] },
                "#{options[:voting_field]}.down" => { '$ne' => options[:voter_id] },
                "#{options[:voting_field]}.ip" => { '$ne' => options[:ip]}
              }
            end
          end
          def new_vote_update(options, vote_option_count,vote_count,vote_point, push_option)
            update = {
              '$inc' => {
                vote_count => +1,
                vote_option_count => +1,
                vote_point => options[:voteable][options[:value]]
              }
            }.merge!(push_option)
          end

          def new_vote_query_and_update(options)
            val = options[:value] # :up or :down
            vote_option_ids = "#{options[:voting_field]}.#{val}"
            vote_option_count = options[:voter_id] ? "#{options[:voting_field]}.#{val}_count" : "#{options[:voting_field]}.faceless_#{val}_count"
            vote_count = "#{options[:voting_field]}.count"
            vote_point = "#{options[:voting_field]}.point"
            ip_option = "#{options[:voting_field]}.ip"
            if embedded?
              rel = "#{_inverse_relation}.$." # prepend relation for embedded collections
              vote_option_ids.prepend rel
              vote_option_count.prepend rel
              vote_count.prepend rel
              vote_point.prepend rel
              ip_option.prepend rel
            end
            ip_option = options[:ip].present? ? { ip_option => options[:ip] } : {}
            user_option = options[:voter_id].present? ? { vote_option_ids => options[:voter_id] } : {}
            combined_push = ip_option.merge(user_option)
            push_option = combined_push.empty? ? {} : { '$push' => combined_push }
            query = new_vote_query(options)
            update = new_vote_update(options, vote_option_count,vote_count,vote_point, push_option)
            return query, update
          end
        end
      end
    end
  end
end