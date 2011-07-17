require 'voteable_mongo/embedded_relations'
module Mongo
  module Voteable
    module Voting
      extend ActiveSupport::Concern
      # extend Mongo::Voteable::EmbeddedRelations
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
          return unless options[:voteable]
          query, update = if options[:revote]
          revote_query_and_update(options)
        elsif options[:unvote]
          unvote_query_and_update(options)
        else
          new_vote_query_and_update(options)
        end

        # http://www.mongodb.org/display/DOCS/findAndModify+Command
        begin
          doc = voteable_collection.find_and_modify(
          :query => query,
          :update => update,
          :new => true
          )
        rescue Mongo::OperationFailure
          doc = nil
        end
        if doc
          inner_doc = embedded? ? find_inner_doc(doc, options) : doc
          update_parent_votes(doc, options) if options[:voteable][:update_parents]
          # Return new vote attributes to instance
          options[:votee].write_attribute('votes', inner_doc['votes']) if options[:votee]
          options[:votee] || new(inner_doc)
        else
          false
        end
      end

      def find_inner_doc(doc, options)
        doc[_inverse_relation].find{|img| img["_id"] == options[:votee_id] }
      end

      private
      def validate_and_normalize_vote_options(options)
        options.symbolize_keys!
        options[:votee_id] = Helpers.try_to_convert_string_to_object_id(options[:votee_id])
        options[:voter_id] = Helpers.try_to_convert_string_to_object_id(options[:voter_id])
        options[:value] &&= options[:value].to_sym
      end

      def new_vote_query(options)
        if embedded?
          {
            _inverse_relation => {
              '$elemMatch' => {
                "_id" => options[:votee_id],
                'votes.up' => { '$ne' => options[:voter_id] },
                'votes.down' => { '$ne' => options[:voter_id] },
                'votes.ip' => { '$ne' => options[:ip]}
              }
            }
          }
        else
          {
            :_id => options[:votee_id],
            'votes.up' => { '$ne' => options[:voter_id] },
            'votes.down' => { '$ne' => options[:voter_id] },
            'votes.ip' => { '$ne' => options[:ip]}
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
        vote_option_ids = "votes.#{val}"
        vote_option_count = options[:voter_id] ? "votes.#{val}_count" : "votes.faceless_#{val}_count"
        vote_count = "votes.count"
        vote_point = "votes.point"
        ip_option = "votes.ip"
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

      def revote_query_and_update(options)
        rel = embedded? && _inverse_relation
        if options[:value] == :up
          positive_voter_ids =    ['votes.up', "#{rel}.$.votes.up"]
          negative_voter_ids =    ['votes.down', "#{rel}.$.votes.down"]
          positive_votes_count =  ['votes.up_count', "#{rel}.$.votes.up_count"]
          negative_votes_count =  ['votes.down_count',"#{rel}.$.votes.down_count"]
          point_delta = options[:voteable][:up] - options[:voteable][:down]
        else
          positive_voter_ids =    ['votes.down', "#{rel}.$.votes.down"]
          negative_voter_ids =    ['votes.up', "#{rel}.$.votes.up"]
          positive_votes_count =  ['votes.down_count', "#{rel}.$.votes.down_count"]
          negative_votes_count =  ['votes.up_count', "#{rel}.$.votes.up_count"]
          point_delta = -options[:voteable][:up] + options[:voteable][:down]
        end
        query = query_for_revote(options, negative_voter_ids, rel)
        update = update_for_revote(options, negative_voter_ids, positive_voter_ids, positive_votes_count, negative_votes_count, point_delta, rel)

        return query, update
      end

      def update_for_revote(options, negative_voter_ids, positive_voter_ids, positive_votes_count, negative_votes_count, point_delta, rel)
        if embedded?
          {
            # then update
            '$pull' => { negative_voter_ids.last => options[:voter_id] },
            '$push' => { positive_voter_ids.last => options[:voter_id] },
            '$inc' => {
              positive_votes_count.last => +1,
              negative_votes_count.last => -1,
              "#{rel}.$.votes.point" => point_delta
            }
          }
        else
          {
            '$pull' => { negative_voter_ids.first => options[:voter_id] },
            '$push' => { positive_voter_ids.first => options[:voter_id] },
            '$inc' => {
              positive_votes_count.first => +1,
              negative_votes_count.first => -1,
              'votes.point' => point_delta
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

      def unvote_query_and_update(options)
        rel = embedded? && _inverse_relation
        if options[:value] == :up
          positive_voter_ids    = ['votes.up', "#{rel}.$.votes.up"]
          positive_votes_count  = ['votes.up_count', "#{rel}.$.votes.up_count"]
        else
          positive_voter_ids    = ['votes.down', "#{rel}.$.votes.down"]
          positive_votes_count  = ['votes.down_count',"#{rel}.$.votes.down_count"]
        end
        votes_count           = ['votes.count', "#{rel}.$.votes.count"]
        votes_point           = ['votes.point', "#{rel}.$.votes.point"]

        query = query_for_unvote(options, positive_voter_ids, rel)
        update = update_for_unvote(options, positive_voter_ids, votes_count, votes_point, positive_votes_count)
        return query, update
      end

      def update_parent_votes(doc, options)
        if embedded?
          voteable = VOTEABLE[name][_parent_klass.name]
          if doc['_id']
            _parent_klass.collection.update(
            { '_id' =>  doc['_id'] },
            { '$inc' => parent_inc_options(voteable, options) },
            { :multi => true }
            )
          end
        else
          VOTEABLE[name].each do |class_name, voteable|
            if metadata = voteable_relation(class_name)
              if (parent_id = doc[voteable_foreign_key(metadata)]).present?
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
              options[:voter_id].present? ? inc_options['votes.up_count'] = +1 : inc_options['votes.faceless_up_count'] = +1
            else
              options[:voter_id].present? ? inc_options['votes.down_count'] = +1 : inc_options['votes.faceless_down_count'] = +1
            end
          end
        end

        inc_options
      end
    end

  end
end
end
