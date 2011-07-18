require 'voteable_mongo/embedded_relations'
require 'voteable_mongo/voting/operations/newvote'
require 'voteable_mongo/voting/operations/revote'
require 'voteable_mongo/voting/operations/unvote'
require 'voteable_mongo/voting/operations/update_parents'

module Mongo
  module Voteable
    module Voting
      extend ActiveSupport::Concern
      included do
        include Mongo::Voting::Operations::Newvote
        include Mongo::Voting::Operations::Revote
        include Mongo::Voting::Operations::Unvote
        include Mongo::Voting::Operations::UpdateParents
      end
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
        def set_vote(options)
          validate_and_normalize_vote_options(options)
          return unless VOTEABLE[self.name][self.name]
          setup_voteable(options)
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
          rescue Mongo::OperationFailure => e
            doc = nil
          end
          if doc
            inner_doc = embedded? ? find_inner_doc(doc, options) : doc
            update_parent_votes(VOTEABLE, doc, options) if options[:voteable][:update_parents]
            # Return new vote attributes to instance
            options[:votee].write_attribute(options[:voting_field], inner_doc[options[:voting_field]]) if options[:votee]
            options[:votee] || new(inner_doc)
          else
            false
          end
        end
      
        def setup_voteable(options)
          options[:voting_field] ||= "votes"
          options[:voteable] = VOTEABLE[name][name].find{ |voteable| voteable[:voting_field] == options[:voting_field]}
          return unless options[:voteable]
          options[:voteable][:up] ||= +1
          options[:voteable][:down] ||= -1
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
      end
    end
  end
end
