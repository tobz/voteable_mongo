require 'voteable_mongo/voting'

module Mongo
  module Voteable
    extend ActiveSupport::Concern

    DEFAULT_VOTES = {
      'up' => [],
      'down' => [],
      'up_count' => 0,
      'down_count' => 0,
      'count' => 0,
      'point' => 0
    }

    included do
      include ::Mongo::Voteable::Voting

      if defined?(Mongoid) && defined?(field)
        field :votes, :type => Hash, :default => DEFAULT_VOTES

        class << self
          alias_method :ensure_index, :index
        end

        def self.voteable_collection
          collection.master.collection
        end
        
        def self.voteable_foreign_key(metadata)
          metadata.foreign_key.to_s
        end

        def self.voteable_belongs_to_relation?(metadata)
          metadata.relation == ::Mongoid::Relations::Referenced::In
        end

        def self.voteable_belongs_to_many_relation?(metadata)
          metadata.relation == ::Mongoid::Relations::Referenced::ManyToMany
        end

      elsif defined?(MongoMapper)
        key :votes, Hash, :default => DEFAULT_VOTES

        class << self
          alias_method :voteable_collection, :collection
          alias_method :relations, :associations
        end

        def self.voteable_foreign_key(metadata)
          metadata.options[:in].to_s || "#{metadata.name}_id"
        end
        
        def self.voteable_belongs_to_relation?(metadata)
          metadata.is_a?(::MongoMapper::Plugins::Associations::BelongsToAssociation)
        end

        def self.voteable_belongs_to_many_relation?(metadata)
          metadata.is_a?(::MongoMapper::Plugins::Associations::ManyAssociation)
        end
      end
      
      scope :voted_by, lambda { |voter|
        voter_id = voter.is_a?(::BSON::ObjectId) ? voter : voter.id
        where('$or' => [{ 'votes.up' => voter_id }, { 'votes.down' => voter_id }])
      }

      scope :up_voted_by, lambda { |voter|
        voter_id = voter.is_a?(::BSON::ObjectId) ? voter : voter.id
        where('votes.up' => voter_id)
      }

      scope :down_voted_by, lambda { |voter|
        voter_id = voter.is_a?(::BSON::ObjectId) ? voter : voter.id
        where('votes.down' => voter_id)
      }
    end

    # How many points should be assigned for each up or down vote and other options
    # This hash should manipulated using voteable method
    VOTEABLE = {}

    module ClassMethods
      # Set vote point for each up (down) vote on an object of this class
      # 
      # @param [Hash] options a hash containings:
      # 
      # voteable self, :up => +1, :down => -3
      # voteable Post, :up => +2, :down => -1, :update_counters => false # skip counter update
      def voteable(klass = self, options = nil)
        VOTEABLE[name] ||= {}
        VOTEABLE[name][klass.name] ||= options
        if klass == self
          if options[:index] == true
            create_voteable_indexes
          end
        else
          VOTEABLE[name][name][:update_parents] ||= true
        end
      end
      
      # Check if voter_id do a vote on votee_id
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      # 
      # @return [true, false]
      def voted?(options)
        validate_and_normalize_vote_options(options)
        up_voted?(options) || down_voted?(options)
      end
      
      # Check if voter_id do an up vote on votee_id
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      # 
      # @return [true, false]
      def up_voted?(options)
        validate_and_normalize_vote_options(options)
        up_voted_by(options[:voter_id]).where(:_id => options[:votee_id]).count == 1
      end
      
      # Check if voter_id do a down vote on votee_id
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      # 
      # @return [true, false]
      def down_voted?(options)
        validate_and_normalize_vote_options(options)
        down_voted_by(options[:voter_id]).where(:_id => options[:votee_id]).count == 1
      end

      private
        def create_voteable_indexes
          class_eval do
            # Compound index _id and voters.up, _id and voters.down
            # to make up_voted_by, down_voted_by, voted_by scopes and voting faster
            # Should run in background since it introduce new index value and
            # while waiting to build, the system can use _id for voting
            # http://www.mongodb.org/display/DOCS/Indexing+as+a+Background+Operation
            ensure_index [['votes.up', 1], ['_id', 1]], :unique => true
            ensure_index [['votes.down', 1], ['_id', 1]], :unique => true

            # Index counters and point for desc ordering
            ensure_index [['votes.up_count', -1]]
            ensure_index [['votes.down_count', -1]]
            ensure_index [['votes.count', -1]]
            ensure_index [['votes.point', -1]]
          end
        end
    end
    
    module InstanceMethods
      # Make a vote on this votee
      #
      # @param [Hash] options a hash containings:
      #   - :voter_id: the voter document id
      #   - :value: vote :up or vote :down
      #   - :revote: change from vote up to vote down
      #   - :unvote: unvote the vote value (:up or :down)
      def vote(options)
        options[:votee_id] = id
        options[:votee] = self
        options[:voter_id] ||= options[:voter].id

        if options[:unvote]
          options[:value] ||= vote_value(options[:voter_id])
        else
          options[:revote] ||= vote_value(options[:voter_id]).present?
        end

        self.class.vote(options)
      end
    
      # Get a voted value on this votee
      #
      # @param [Mongoid Object, BSON::ObjectId] voter is Mongoid object or the id of the voter who made the vote
      def vote_value(voter)
        voter_id = voter.is_a?(BSON::ObjectId) ? voter : voter.id
        return :up if up_voter_ids.include?(voter_id)
        return :down if down_voter_ids.include?(voter_id)
      end
    
      def voted_by?(voter)
        !!vote_value(voter)
      end

      # Array of up voter ids
      def up_voter_ids
        votes.try(:[], 'up') || []
      end

      # Array of down voter ids
      def down_voter_ids
        votes.try(:[], 'down') || []
      end

      # Array of voter ids
      def voter_ids
        up_voter_ids + down_voter_ids
      end

      # Get the number of up votes
      def up_votes_count
        votes.try(:[], 'up_count') || 0
      end
  
      # Get the number of down votes
      def down_votes_count
        votes.try(:[], 'down_count') || 0
      end
  
      # Get the number of votes
      def votes_count
        votes.try(:[], 'count') || 0
      end
  
      # Get the votes point
      def votes_point
        votes.try(:[], 'point') || 0
      end

      # Get up voters
      def up_voters(klass)
        klass.where(:_id => { '$in' =>  up_voter_ids })
      end

      # Get down voters
      def down_voters(klass)
        klass.where(:_id => { '$in' => down_voter_ids })
      end

      # Get voters
      def voters(klass)
        klass.where(:_id => { '$in' => voter_ids })
      end
    end
  end
end
