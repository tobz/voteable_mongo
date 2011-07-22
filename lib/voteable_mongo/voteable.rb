require 'voteable_mongo/voting'
require 'voteable_mongo/integrations/mongoid'
require 'voteable_mongo/integrations/mongo_mapper'
require 'voteable_mongo/embedded_relations'

module Mongo
  module Voteable
    extend ActiveSupport::Concern
    # up: ids of up voters 
    # down: ids of down voters
    # faceless_up_count: number of anonymous up votes 
    # faceless_down_count: number of anonymous down votes
    # up_count: number of voters up votes
    # down_count: number of voters down votes
    # total_up_count: faceless + voters (up votes)
    # total_down_count: faceless + voters (down votes)
    # count: total number of votes
    # point: points attributed to the votes
    # ratio: up/total. It is being cached for querying purposes
    # ip: IPs used in anonymous votes
    DEFAULT_VOTES = {
      'up' => [],
      'down' => [],
      'faceless_up_count' => 0,
      'faceless_down_count' => 0,
      'up_count' => 0,
      'down_count' => 0,
      'total_up_count' => 0,
      'total_down_count' => 0,
      'count' => 0,
      'point' => 0,
      'ratio' => 0,
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
      # TODO: If there's more than one voting field in the document, all of them
      # will trigger the same callbacks. One should be able to test it, but
      # it should be better to work around here.
      define_model_callbacks :vote
      
      # 
      # No support for embedded documents
      # TODO: find a way to return this information for embedded documents.
      # Maybe keeping the votes within the voters class.
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
      # :voting_field will always default to "votes" so we don't break the public API
      # 
      # TODO: split this into setup and performing methods.
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
      
      # Defines the oting_field in the included class
      # with the given name.
      # 
      # @param [String] voting_field is the field under which 
      # the votes will be placed.
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
      #   - :ip: ip used by anonymous voters for controlling purposes
      #   - :voting_field: field storing the votes (default = "votes")
      def set_vote(options)
        # we can run before and after callbacks around this method
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
      # # @param voting_field(String) default = "votes
      def vote_value(voter, voting_field = "votes")
        voter_id = Helpers.get_mongo_id(voter)
        return :up if up_voter_ids(voting_field).include?(voter_id)
        return :down if down_voter_ids(voting_field).include?(voter_id)
      end
      
      # Has the voter voted for record of votee?
      # @param voting_field(String) default = "votes
      # @return [true, false]
      def voted_by?(voter, voting_field = "votes")
        !!vote_value(voter, voting_field)
      end

      # Array of up voter ids
      # @param voting_field(String) default = "votes"
      def up_voter_ids(voting_field = "votes")
        eval(voting_field).try(:[], 'up') || []
      end

      # Array of down voter ids
      # @param voting_field(String) default = "votes"
      def down_voter_ids(voting_field = "votes")
        eval(voting_field).try(:[], 'down') || []
      end

      # Array of voter ids
      # @param voting_field(String) default = "votes"
      def voter_ids(voting_field = "votes")
        up_voter_ids(voting_field) + down_voter_ids(voting_field)
      end
      
      # Get the total number of up votes (registered and anonymous)
      # @param voting_field(String) default = "votes"
      def total_up_votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'total_up_count') || 0
      end
      
      # Get the total number of down votes (registered and anonymous)
      # @param voting_field(String) default = "votes"
      def total_down_votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'total_down_count') || 0
      end
      
      # Get the positive votes ratio in relation to the total votes count
      # eg: 1 :up, 9 :down = 10% (ratio = 0.1) 
      # @param voting_field(String) default = "votes"
      # @return Float
      def votes_ratio(voting_field = "votes")
        eval(voting_field).try(:[], 'ratio') || 0
      end

      # Get the number of up votes
      # @param voting_field(String) default = "votes"
      def up_votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'up_count') || 0
      end
      
      # Get the number of anonymous up votes
      # @param voting_field(String) default = "votes"
      def faceless_up_votes_count(voting_field = "votes")
        eval(voting_field).try(:[], 'faceless_up_count') || 0
      end
      
      # Get the number of anonymous down votes
      # @param voting_field(String) default = "votes"
      def faceless_down_votes_count(voting_field = "votes")
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
