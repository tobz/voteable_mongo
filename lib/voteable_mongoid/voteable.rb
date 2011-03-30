module Mongoid
  module Voteable
    extend ActiveSupport::Concern

    # How many points should be assigned for each up or down vote.
    # This hash should manipulated using Voteable.vote_point method
    VOTE_POINT = {}

    included do
      include Mongoid::Voteable::Stats
      
      def self.voteable_related
        foreign_keys = relations.values.map{ |meta| meta.try(:foreign_key) }.compact
        only(foreign_keys + %w[voteable])
      end

      # Set vote point for each up (down) vote on an object of this class
      # 
      # @param [Hash] options a hash containings:
      # 
      # vote_point self, :up => +1, :down => -3
      # vote_point Post, :up => +2, :down => -1, :update_counters => false
      def self.vote_point(klass = self, options = nil)
        VOTE_POINT[self.name] ||= {}
        VOTE_POINT[self.name][klass.name] ||= options
      end

      # We usually need to show current_user his voting value on voteable object
      # voting value can be nil (not voted yet), :up or :down
      # from voting value, we can decide it should be new vote or revote with :up or :down
      # In this case, validation can be skip to maximize performance

      # Make a vote on an object of this class
      #
      # @param [Hash] options a hash containings:
      #   - :votee_id: the votee document id
      #   - :voter_id: the voter document id
      #   - :value: :up or :down
      #   - :revote: change from vote up to vote down
      #   - :unvote: unvote the vote value (:up or :down)
      def self.vote(options)
        options.symbolize_keys!
        value = options[:value].to_sym
        
        votee_id = options[:votee_id]
        voter_id = options[:voter_id]
        
        votee_id = BSON::ObjectId(votee_id) if votee_id.is_a?(String)
        voter_id = BSON::ObjectId(voter_id) if voter_id.is_a?(String)

        klass = options[:class]
        klass ||= VOTE_POINT.keys.include?(name) ? name : collection.name.classify
        value_point = VOTE_POINT[klass][klass]
        
        if options[:revote]
          if value == :up
            positive_voter_ids = 'voteable.up_voter_ids'
            negative_voter_ids = 'voteable.down_voter_ids'
            positive_votes_count = 'voteable.up_votes_count'
            negative_votes_count = 'voteable.down_votes_count'
            point_delta = value_point[:up] - value_point[:down]
          else
            positive_voter_ids = 'voteable.down_voter_ids'
            negative_voter_ids = 'voteable.up_voter_ids'
            positive_votes_count = 'voteable.down_votes_count'
            negative_votes_count = 'voteable.up_votes_count'
            point_delta = -value_point[:up] + value_point[:down]
          end
          
          update_result = collection.update({ 
            # Validate voter_id did a vote with value for votee_id
            :_id => votee_id,
            positive_voter_ids => { '$ne' => voter_id },
            negative_voter_ids => voter_id
          }, {
            # then update
            '$pull' => { negative_voter_ids => voter_id },
            '$push' => { positive_voter_ids => voter_id },
            '$inc' => {
              positive_votes_count => +1,
              negative_votes_count => -1,
              'voteable.votes_point' => point_delta
            }
          }, {
            :safe => true
          })

        elsif options[:unvote]
          if value == :up
            positive_voter_ids = 'voteable.up_voter_ids'
            negative_voter_ids = 'voteable.down_voter_ids'
            positive_votes_count = 'voteable.up_votes_count'
          else
            positive_voter_ids = 'voteable.down_voter_ids'
            negative_voter_ids = 'voteable.up_voter_ids'
            positive_votes_count = 'voteable.down_votes_count'
          end
          
          # Check if voter_id did a vote with value for votee_id
          update_result = collection.update({ 
            # Validate voter_id did a vote with value for votee_id
            :_id => votee_id,
            negative_voter_ids => { '$ne' => voter_id },
            positive_voter_ids => voter_id
          }, {
            # then update
            '$pull' => { positive_voter_ids => voter_id },
            '$inc' => {
              positive_votes_count => -1,
              'voteable.votes_count' => -1,
              'voteable.votes_point' => -value_point[value]
            }
          }, {
            :safe => true
          })
          
        else # new vote
          if value.to_sym == :up
            positive_voter_ids = 'voteable.up_voter_ids'
            positive_votes_count = 'voteable.up_votes_count'
          else
            positive_voter_ids = 'voteable.down_voter_ids'
            positive_votes_count = 'voteable.down_votes_count'
          end

          update_result = collection.update({ 
            # Validate voter_id did not vote for votee_id yet
            :_id => votee_id,
            'voteable.up_voter_ids' => { '$ne' => voter_id },
            'voteable.down_voter_ids' => { '$ne' => voter_id }
          }, {
            # then update
            '$push' => { positive_voter_ids => voter_id },
            '$inc' => {  
              'voteable.votes_count' => +1,
              positive_votes_count => +1,
              'voteable.votes_point' => value_point[value] }
          }, {
            :safe => true
          })
        end
        
        # Only update parent class if votee is updated successfully
        successed = ( update_result['err'] == nil and 
          update_result['updatedExisting'] == true and
          update_result['n'] == 1 )

        if successed
          VOTE_POINT[klass].each do |class_name, value_point|
            # For other class in VOTE_POINT options, if is parent of current class
            next unless relation_metadata = relations[class_name.underscore]
            next unless votee ||= options[:votee] || voteable_related.where(:id => options[:votee_id]).first
            # If can find current votee foreign_key value for that class
            next unless foreign_key_value = votee.read_attribute(relation_metadata.foreign_key)
          
            inc_options = {}
            
            if options[:revote]
              if value == :up
                inc_options['voteable.votes_point'] = value_point[:up] - value_point[:down]
                unless value_point[:update_counters] == false
                  inc_options['voteable.up_votes_count'] = +1
                  inc_options['voteable.down_votes_count'] = -1
                end
              else
                inc_options['voteable.votes_point'] = -value_point[:up] + value_point[:down]
                unless value_point[:update_counters] == false
                  inc_options['voteable.up_votes_count'] = -1
                  inc_options['voteable.down_votes_count'] = +1
                end
              end
            elsif options[:unvote]
              inc_options['voteable.votes_point'] = -value_point[value]
              unless value_point[:update_counters] == false
                inc_options['voteable.votes_count'] = -1
                if value == :up
                  inc_options['voteable.up_votes_count'] = -1
                else
                  inc_options['voteable.down_votes_count'] = -1
                end
              end
            else # new vote
              inc_options['voteable.votes_point'] = value_point[value]
              unless value_point[:update_counters] == false
                inc_options['voteable.votes_count'] = 1
                if value == :up
                  inc_options['voteable.up_votes_count'] = 1
                else
                  inc_options['voteable.down_votes_count'] = 1
                end
              end
            end
                    
            class_name.constantize.collection.update(
              { :_id => foreign_key_value }, 
              { '$inc' =>  inc_options }
            )
          end
        end
        true
      end
      
    end
  
    # Make a vote on this votee
    #
    # @param [Hash] options a hash containings:
    #   - :voter_id: the voter document id
    #   - :value: vote :up or vote :down
    def vote(options)
      options[:votee_id] ||= _id
      options[:votee] ||= self

      if options[:unvote]
        options[:value] ||= vote_value(options[:voter_id])
      else
        options[:revote] ||= !vote_value(options[:voter_id]).nil?
      end

      self.class.vote(options)
    end

    # Get a voted value on this votee
    #
    # @param [Mongoid Object, BSON::ObjectId] voter is Mongoid object the id of the voter who made the vote
    def vote_value(voter)
      voter_id = voter.is_a?(BSON::ObjectId) ? voter : voter._id
      return :up if up_voter_ids.include?(voter_id)
      return :down if down_voter_ids.include?(voter_id)
    end

    # Array of up voter ids
    def up_voter_ids
      voteable.try(:[], 'up_voter_ids') || []
    end
    
    # Array of down voter ids
    def down_voter_ids
      voteable.try(:[], 'down_voter_ids') || []
    end
    
    def voteable
      read_attribute('voteable')
    end

  end
end
