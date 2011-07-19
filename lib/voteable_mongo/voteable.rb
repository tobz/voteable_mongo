require 'voteable_mongo/voting'
require 'voteable_mongo/integrations/mongoid'
require 'voteable_mongo/integrations/mongo_mapper'
require 'voteable_mongo/embedded_relations'

module Mongo
  module Voteable
    extend ActiveSupport::Concern
    DEFAULT_VOTES = {
      'up' => [],
      'down' => [],
      'faceless_up_count' => 0,
      'faceless_down_count' => 0,
      'up_count' => 0,
      'down_count' => 0,
      'count' => 0,
      'point' => 0,
      'ip' => []
    }

    included do
      include Mongo::Voteable::Voting
      include Mongo::Voteable::EmbeddedRelations

      if defined?(Mongoid)
        include Mongo::Voteable::Integrations::Mongoid
      elsif defined?(MongoMapper)
        include Mongo::Voteable::Integrations::MongoMapper
      end
      
      # Define callbacks for voting if defined in voteable model
      # This is useful because the gem interacts with the database
      # through the ruby-mongo driver directly, skipping ActiveModel::Callbacks
      # 
      # Example:
      #   before_vote :do_something_before
      #   after_vote :do_something_after
      # 
      # define_model_callbacks :vote
      
      # 
      # 
      # No support for embedded documents
      # 
      # 
      scope :voted_by, lambda { |voter, voting_field = "votes"|
        voter_id = Helpers.get_mongo_id(voter)
        where('$or' => [{ "#{voting_field}.up" => voter_id }, { "#{voting_field}.down" => voter_id }])
      }

      scope :up_voted_by, lambda { |voter, voting_field = "votes"|
        voter_id = Helpers.get_mongo_id(voter)
        where("#{voting_field}.up" => voter_id)
      }

      scope :down_voted_by, lambda { |voter, voting_field = "votes"|
        voter_id = Helpers.get_mongo_id(voter)
        where("#{voting_field}.down" => voter_id)
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
      # voteable self, :voting_field => :moderations
      # 
      def voteable(klass = self, options = nil)
        VOTEABLE[name] ||= {}
        options[:voting_field] = options[:voting_field].present? ? options[:voting_field].to_s : "votes"
        define_voting_field(options[:voting_field]) if klass==self
        VOTEABLE[name][klass.name] ||= []
        VOTEABLE[name][klass.name] << options
        
        if klass == self
          if options[:index] == true
            create_voteable_indexes(options[:voting_field])
          end
        else
          VOTEABLE[name][name].each do |voteable|
            voteable.merge!(:update_parents => true)
          end
        end
      end
      
      def define_voting_field(voting_field)
        class_eval do
          field voting_field, :type => Hash, :default => DEFAULT_VOTES
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
        up_voted_by(options[:voter_id], options[:voting_field]).where(:_id => options[:votee_id]).count == 1
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
        down_voted_by(options[:voter_id], options[:voting_field]).where(:_id => options[:votee_id]).count == 1
      end

      def create_voteable_indexes(voting_field = "votes")
        # Compound index _id and voters.up, _id and voters.down
        # to make up_voted_by, down_voted_by, voted_by scopes and voting faster
        # Should run in background since it introduce new index value and
        # while waiting to build, the system can use _id for voting
        # http://www.mongodb.org/display/DOCS/Indexing+as+a+Background+Operation
        voteable_index [["#{voting_field}.up", 1], ['_id', 1]], :unique => true
        voteable_index [["#{voting_field}.down", 1], ['_id', 1]], :unique => true

        # Index counters and point for desc ordering
        voteable_index [["#{voting_field}.up_count", -1]]
        voteable_index [["#{voting_field}.down_count", -1]]
        voteable_index [["#{voting_field}.count", -1]]
        voteable_index [["#{voting_field}.point", -1]]
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
      # 
      def set_vote(options)
        _run_vote_callbacks do
          options[:votee_id] = id
          options[:votee] = self
          options[:voter_id] ||= options[:voter].try(:id)
          options[:voting_field] ||= "votes"

          if options[:unvote]
            options[:value] ||= vote_value(options[:voter_id], options[:voting_field])
          else
            options[:revote] ||= options[:voter_id] && vote_value(options[:voter_id], options[:voting_field]).present?
          end

          self.class.set_vote(options)
        end
      end
      
      # Get a voted value on this votee
      #
      # @param voter is object or the id of the voter who made the vote
      def vote_value(voter, voting_field = "votes")
        voter_id = Helpers.get_mongo_id(voter)
        return :up if up_voter_ids(voting_field).include?(voter_id)
        return :down if down_voter_ids(voting_field).include?(voter_id)
      end
    
      def voted_by?(voter, voting_field = "votes")
        !!vote_value(voter, voting_field)
      end

      # Array of up voter ids
      def up_voter_ids(voting_field = "votes")
        eval(voting_field).try(:[], 'up') || []
      end

      # Array of down voter ids
      def down_voter_ids(voting_field = "votes")
        eval(voting_field).try(:[], 'down') || []
      end

      # Array of voter ids
      def voter_ids(voting_field = "votes")
        up_voter_ids(voting_field) + down_voter_ids(voting_field)
      end
      
      # Get the total number of up votes (registered and anonymous)
      def total_up_count(voting_field = "votes")
        up_votes_count(voting_field) + faceless_up_count(voting_field)
      end
      
      # Get the total number of down votes (registered and anonymous)
      def total_down_count(voting_field = "votes")
        down_votes_count(voting_field) + faceless_down_count(voting_field)
      end
      
      def votes_ratio(voting_field = "votes")
        votes_count(voting_field) > 0 ? (total_up_count(voting_field).to_f/votes_count(voting_field)) : 0
      end

      # Get the number of up votes
      def up_votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'up_count') || 0
      end
      
      def faceless_up_count(voting_field = "votes")
        eval(voting_field).try(:[], 'faceless_up_count') || 0
      end
      
      def faceless_down_count(voting_field = "votes")
        eval(voting_field).try(:[], 'faceless_down_count') || 0
      end
  
      # Get the number of down votes
      def down_votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'down_count') || 0
      end
  
      # Get the number of votes
      def votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'count') || 0
      end
  
      # Get the votes point
      def votes_point(voting_field = "votes")
        eval(voting_field).try(:[], 'point') || 0
      end

      # Get up voters
      def up_voters(klass, voting_field = "votes")
        klass.where(:_id => { '$in' =>  up_voter_ids(voting_field) })
      end

      # Get down voters
      def down_voters(klass, voting_field = "votes")
        klass.where(:_id => { '$in' => down_voter_ids(voting_field) })
      end

      # Get voters
      def voters(klass, voting_field = "votes")
        klass.where(:_id => { '$in' => voter_ids(voting_field) })
      end
    end
  end
end
