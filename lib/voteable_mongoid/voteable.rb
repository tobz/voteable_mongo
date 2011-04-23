require 'voteable_mongoid/voteable/votes'
require 'voteable_mongoid/voteable/voting'

module Mongoid
  module Voteable
    extend ActiveSupport::Concern

    included do
      include ::Mongoid::Document
      include ::Mongoid::Voteable::Voting
      
      field :votes, :type => Votes

      before_create do
        # Init votes so that counters and point have numeric values (0)
        self.votes = Votes::DEFAULT_ATTRIBUTES
      end
      
      scope :voted_by, lambda { |voter|
        voter_id = voter.is_a?(BSON::ObjectId) ? voter : voter.id
        any_of({ 'votes.up' => voter_id }, { 'votes.down' => voter_id })
      }
      
      scope :up_voted_by, lambda { |voter|
        voter_id = voter.is_a?(BSON::ObjectId) ? voter : voter.id
        where( 'votes.up' => voter_id )
      }
      
      scope :down_voted_by, lambda { |voter|
        voter_id = voter.is_a?(BSON::ObjectId) ? voter : voter.id
        where( 'votes.down' => voter_id )
      }
    end # include
    
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
        if klass != self
          VOTEABLE[name][name][:update_parents] = true
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
    end
    
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
    
  end
end
