module Mongo
  module Voteable
    module Integrations
      module Mongoid
        extend ActiveSupport::Concern

        included do
          field :votes, :type => Hash
          
          before_create do
            # Init votes so that counters and point have numeric values (0)
            self.votes = DEFAULT_VOTES
          end

          scope :voted_by, lambda { |voter|
            voter_id = voter.is_a?(::BSON::ObjectId) ? voter : voter.id
            any_of({ 'votes.up' => voter_id }, { 'votes.down' => voter_id })
          }

          scope :up_voted_by, lambda { |voter|
            voter_id = voter.is_a?(::BSON::ObjectId) ? voter : voter.id
            where( 'votes.up' => voter_id )
          }

          scope :down_voted_by, lambda { |voter|
            voter_id = voter.is_a?(::BSON::ObjectId) ? voter : voter.id
            where( 'votes.down' => voter_id )
          }
        end
        
        module ClassMethods
          def create_voteable_indexes
            class_eval do
              # Compound index _id and voters.up, _id and voters.down
              # to make up_voted_by, down_voted_by, voted_by scopes and voting faster
              # Should run in background since it introduce new index value and
              # while waiting to build, the system can use _id for voting
              # http://www.mongodb.org/display/DOCS/Indexing+as+a+Background+Operation
              index [['votes.up', 1], ['_id', 1]], :unique => true
              index [['votes.down', 1], ['_id', 1]], :unique => true

              # Index counters and point for desc ordering
              index [['votes.up_count', -1]]
              index [['votes.down_count', -1]]
              index [['votes.count', -1]]
              index [['votes.point', -1]]
            end
          end
        end
      end
    end
  end
end
