module Mongo
  module Voting
    module Operations
      module UpdateParents
        extend ActiveSupport::Concern
        module ClassMethods
          # Updates parent votes
          # 
          # @param [Hash] class_voteable 
          # @param [Hash] doc is the document returned by the mongo driver
          # @param [Hash] options
          # 
          # Master collections can have multiple relations and should update all parents.
          # Embedded documents in Mongoid can only have one parent and multiple updates aren't necessary
          # Before an update can be made, an instance of the parent's document is retrieved.
          # This is only needed for the up/total ratio calculation, but it has a cost of an aditional query.
          # 
          # TODO: Ratio calculation should be optional
          def update_parent_votes(class_voteable, doc, options)
            if embedded?
              voteable = class_voteable[name][_parent_klass.name]
              if doc['_id']
                votee = _parent_klass.find(doc['_id'])
                parent_inc_options, parent_set_options = parent_options(voteable, options, votee)
                _parent_klass.collection.update(
                { '_id' =>  doc['_id'] },
                { '$inc' => parent_inc_options, '$set' => parent_set_options },
                { :multi => true }
                )
              end
            else
              class_voteable[name].each do |class_name, voteable|
                if metadata = voteable_relation(class_name)
                  if (parent_id = doc[voteable_foreign_key(metadata)]).present?
                    parent_ids = parent_id.is_a?(Array) ? parent_id : [ parent_id ]
                    # because of the ratio calculation we need to iterate through
                    # all parent documents.
                    parent_ids.each do |parent_id|
                      votee = class_name.constantize.find(parent_id)
                      parent_inc_options, parent_set_options = parent_options(voteable, options, votee)
                      class_name.constantize.collection.update(
                      { '_id' => parent_id },
                      { '$set' => parent_set_options, '$inc' => parent_inc_options },
                      { :multi => true }
                      )
                    end
                  end
                end
              end
            end
          end
          
          # Builds options for the update
          # 
          # @param [Hash] voteable are the voteable options for the parent document
          # @param [Hash] options
          # @param [Object] votee is an instance of the parent document
          # 
          # TODO: urgent need of refactoring
          def parent_options(voteable, options, votee)
            voteable = voteable.first
            val = options[:value]
            voting_field = voteable[:voting_field]
            inc_options = {}
            set_options = {}
            if options[:revote]
              if options[:value] == :up
                inc_options["#{voting_field}.point"] = voteable[:up] - voteable[:down]
                unless voteable[:update_counters] == false
                  inc_options["#{voting_field}.up_count"] = +1
                  inc_options["#{voting_field}.down_count"] = -1
                  inc_options["#{voting_field}.total_up_count"] = +1
                  inc_options["#{voting_field}.total_down_count"] = -1
                  set_options["#{voting_field}.ratio"] = (votee.total_up_votes_count(voting_field) + 1).to_f / (votee.votes_count(voting_field))
                end
              else
                inc_options["#{voting_field}.point"] = -voteable[:up] + voteable[:down]
                unless voteable[:update_counters] == false
                  inc_options["#{voting_field}.up_count"] = -1
                  inc_options["#{voting_field}.down_count"] = +1
                  inc_options["#{voting_field}.total_up_count"] = -1
                  inc_options["#{voting_field}.total_down_count"] = +1
                  set_options["#{voting_field}.ratio"] = (votee.total_up_votes_count(voting_field) - 1).to_f / (votee.votes_count(voting_field))
                end
              end
            elsif options[:unvote]
              inc_options["#{voting_field}.point"] = -voteable[options[:value]]
              unless voteable[:update_counters] == false
                inc_options["#{voting_field}.count"] = -1
                if options[:value] == :up
                  inc_options["#{voting_field}.up_count"] = -1
                  inc_options["#{voting_field}.total_up_count"] = -1
                  set_options["#{voting_field}.ratio"] = (votee.total_up_votes_count(voting_field) - 1).to_f / (votee.votes_count(voting_field))
                else
                  inc_options["#{voting_field}.down_count"] = -1
                  inc_options["#{voting_field}.total_down_count"] = -1
                  set_options["#{voting_field}.ratio"] = (votee.total_up_votes_count(voting_field) + 1).to_f / (votee.votes_count(voting_field))
                end
              end
            else # new vote
              inc_options["#{voting_field}.point"] = voteable[options[:value]]
              unless voteable[:update_counters] == false
                inc_options["#{voting_field}.count"] = +1
                if options[:value] == :up
                  options[:voter_id].present? ? inc_options["#{voting_field}.up_count"] = +1 : inc_options["#{voting_field}.faceless_up_count"] = +1
                  inc_options["#{voting_field}.total_up_count"] = +1
                  set_options["#{voting_field}.ratio"] = (votee.total_up_votes_count(voting_field) + 1).to_f / (votee.votes_count(voting_field) + 1)
                else
                  options[:voter_id].present? ? inc_options["#{voting_field}.down_count"] = +1 : inc_options["#{voting_field}.faceless_down_count"] = +1
                  inc_options["#{voting_field}.total_down_count"] = +1
                  set_options["#{voting_field}.ratio"] = (votee.total_up_votes_count(voting_field)).to_f / (votee.votes_count(voting_field) + 1)
                end
              end
            end
            return inc_options, set_options
          end
        end
      end
    end
  end
end
