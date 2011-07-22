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
        # Including major operations of this class.
        # 
        # The extension got then considerably bigger, so they were placed
        # under their own files.
        include Mongo::Voting::Operations::Newvote
        include Mongo::Voting::Operations::Revote
        include Mongo::Voting::Operations::Unvote
        include Mongo::Voting::Operations::UpdateParents
      end
      module ClassMethods
        
        # Instantiate the votee record. 
        # 
        # Only nedded to calculate and store the up/total ratio.
        # This is not ideal because it introduces another hit to the database
        # if no instance is given upfront. 
        # If it's an embedded document two queries are nedded.
        # TODO: Let the developer chooses if ratio should be used.
        # 
        # @return [votee, false]
        def instantiate_votee(options)
          if options[:votee].blank?
            klass = options[:votee_class] || self
            begin
              votee_id = Helpers.try_to_convert_string_to_object_id(options[:votee_id]) 
              options[:votee] = if embedded?
                # Finds the record of the master document and then
                # finds the embedded document through the Mongoid association.
                parent_instance = klass._parent_klass.where("#{klass._inverse_relation}._id" => votee_id).first
                parent_instance.send("#{klass._inverse_relation}").find(votee_id)
              else
                klass.find(votee_id)
              end
            rescue 
              return false
            end
          end
        end
        
        # Make a vote on an object of this class
        #
        # @param [Hash] options a hash containings:
        #   - :votee_id: the votee document id
        #   - :voter_id: the voter document id
        #   - :value: :up or :down
        #   - :revote: if true change vote vote from :up to :down and vise versa
        #   - :unvote: if true undo the voting
        #   - :voting_field: which voting field to use
        #
        # @return [votee, false]
        def set_vote(options)
          instantiate_votee(options)
          return false if options[:votee].blank?
          
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
          # if were setting this up from an API and the resulting document
          # is not nedded, it would be faster to use MongoDB "fire and forget" Update command.
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
            # @inner_doc is the actual document for regular use case.
            # The Mongo driver always returns the master document, so 
            # when using embedded, we must retrieve is attributes
            # from the parent.
            inner_doc = embedded? ? find_inner_doc(doc, options) : doc
            update_parent_votes(VOTEABLE, doc, options) if options[:voteable][:update_parents]
            
            # Return new vote attributes to instance
            options[:votee].write_attribute(options[:voting_field], inner_doc[options[:voting_field]]) if options[:votee]
            options[:votee] || new(inner_doc)
          else
            false
          end
        end
        
        # Helper method to initialize the voteable hash with default values.
        def setup_voteable(options)
          options[:voting_field] ||= "votes"
          options[:voteable] = VOTEABLE[name][name].find{ |voteable| voteable[:voting_field] == options[:voting_field]}
          return unless options[:voteable]
          options[:voteable][:up] ||= +1
          options[:voteable][:down] ||= -1
        end
      
        # Get the embedded instance.
        # 
        # This method does not introduce another hit to the database. 
        # It performs a find using the embedded document's array stored in the master document.
        # @param [Hash] doc is returned from the MongoDB driver
        # @param [Hash] options
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
