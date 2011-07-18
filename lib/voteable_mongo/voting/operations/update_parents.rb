module Mongo
  module Voting
    module Operations
      module UpdateParents
        extend ActiveSupport::Concern
        module ClassMethods
          def update_parent_votes(class_voteable, doc, options)
            if embedded?
              voteable = class_voteable[name][_parent_klass.name]
              if doc['_id']
                _parent_klass.collection.update(
                { '_id' =>  doc['_id'] },
                { '$inc' => parent_inc_options(voteable, options) },
                { :multi => true }
                )
              end
            else
              class_voteable[name].each do |class_name, voteable|
                if metadata = voteable_relation(class_name)
                  if (parent_id = doc[voteable_foreign_key(metadata)]).present?
                    parent_ids = parent_id.is_a?(Array) ? parent_id : [ parent_id ]
                    class_name.constantize.collection.update(
                    { '_id' => { '$in' => parent_ids } },
                    { '$inc' => parent_inc_options(voteable, options) },
                    { :multi => true }
                    )
                  end
                end
              end
            end
          end

          def parent_inc_options(voteable, options)
            voteable = voteable.first
            inc_options = {}
            if options[:revote]
              if options[:value] == :up
                inc_options["#{voteable[:voting_field]}.point"] = voteable[:up] - voteable[:down]
                unless voteable[:update_counters] == false
                  inc_options["#{voteable[:voting_field]}.up_count"] = +1
                  inc_options["#{voteable[:voting_field]}.down_count"] = -1
                end
              else
                inc_options["#{voteable[:voting_field]}.point"] = -voteable[:up] + voteable[:down]
                unless voteable[:update_counters] == false
                  inc_options["#{voteable[:voting_field]}.up_count"] = -1
                  inc_options["#{voteable[:voting_field]}.down_count"] = +1
                end
              end
            elsif options[:unvote]
              inc_options["#{voteable[:voting_field]}.point"] = -voteable[options[:value]]
              unless voteable[:update_counters] == false
                inc_options["#{voteable[:voting_field]}.count"] = -1
                if options[:value] == :up
                  inc_options["#{voteable[:voting_field]}.up_count"] = -1
                else
                  inc_options["#{voteable[:voting_field]}.down_count"] = -1
                end
              end
            else # new vote
              inc_options["#{voteable[:voting_field]}.point"] = voteable[options[:value]]
              unless voteable[:update_counters] == false
                inc_options["#{voteable[:voting_field]}.count"] = +1
                if options[:value] == :up
                  options[:voter_id].present? ? inc_options["#{voteable[:voting_field]}.up_count"] = +1 : inc_options["#{voteable[:voting_field]}.faceless_up_count"] = +1
                else
                  options[:voter_id].present? ? inc_options["#{voteable[:voting_field]}.down_count"] = +1 : inc_options["#{voteable[:voting_field]}.faceless_down_count"] = +1
                end
              end
            end
            inc_options
          end
        end
      end
    end
  end
end
