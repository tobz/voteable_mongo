module Mongo
  module Voter
    extend ActiveSupport::Concern

    included do
      scope :up_voted_for, lambda { |votee| where(:_id => { '$in' =>  votee.up_voter_ids }) }
      scope :down_voted_for, lambda { |votee| where(:_id => { '$in' =>  votee.down_voter_ids }) }
      scope :voted_for, lambda { |votee| where(:_id => { '$in' =>  votee.voter_ids }) }
    end

    module InstanceMethods
      # Check to see if this voter voted on the votee or not
      #
      # @param [Hash, Object] options the hash containing the votee, or the votee itself
      # @return [true, false] true if voted, false otherwise
      def voted?(options)
        unless options.is_a?(Hash)
          votee_class = options.class
          votee_id = options.id
        else
          votee = options[:votee]
          if votee
            votee_class = votee.class
            votee_id = votee.id
          else
            votee_class = options[:votee_class]
            votee_id = options[:votee_id]
          end
        end
        if votee_class.embedded?
          Post.collection.find(
          "images" => {
            '$elemMatch' => {
              "_id" => options[:votee_id],
              'votes.up' => :voter_id,
              'votes.down' => :voter_id
            }
          }).count > 0
        else
          votee_class.voted?(:voter_id => id, :votee_id => votee_id)
        end
      end

      # Get the voted value on a votee
      #
      # @param (see #voted?)
      # @return [Symbol, nil] :up or :down or nil if not voted
      def vote_value(options)
        votee = unless options.is_a?(Hash)
          options
        else
          options[:votee] || options[:votee_class].find(options[:votee_id])
        end
        votee.vote_value(_id)
      end
    
      # Cancel the vote on a votee
      #
      # @param [Object] votee the votee to be unvoted
      def unvote(options)
        unless options.is_a?(Hash)
          options = { :votee => options }
        end
        options[:unvote] = true
        options[:revote] = false
        vote(options)
      end

      # Vote on a votee
      #
      # @param (see #voted?)
      # @param [:up, :down] vote_value vote up or vote down, nil to unvote
      def vote(options, value = nil)
        if options.is_a?(Hash)
          votee = options[:votee]
        else
          votee = options
          options = { :votee => votee, :value => value }
        end

        if votee
          options[:votee_id] = votee.id
          votee_class = votee.class
        else
          votee_class = options[:votee_class]
        end
      
        if options[:value].nil?
          options[:unvote] = true
          options[:value] = vote_value(options)
        else
          options[:revote] = options.has_key?(:revote) ? !options[:revote].blank? : voted?(options)
        end
      
        options[:voter] = self
        options[:voter_id] = id

        (votee || votee_class).vote(options)
      end
    end
  end
end
