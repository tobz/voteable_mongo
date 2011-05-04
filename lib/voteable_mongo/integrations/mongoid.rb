module Mongo
  module Voteable
    module Integrations
      module Mongoid
        extend ActiveSupport::Concern

        included do
          field :votes, :type => Hash, :default => DEFAULT_VOTES

          class << self
            alias_method :voteable_index, :index
          end
        end
        
        module ClassMethods
          def voteable_relation(class_name)
            relations.find{ |x, r| r.class_name == class_name }.try(:last)
          end

          def voteable_collection
            collection.master.collection
          end

          def voteable_foreign_key(metadata)
            metadata.foreign_key.to_s
          end
        end
      end
    end
  end
end
