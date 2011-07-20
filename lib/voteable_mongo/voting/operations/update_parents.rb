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
