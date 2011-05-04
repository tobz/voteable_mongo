module Mongo
  module Voteable
    module Integrations
      module MongoMapper
        extend ActiveSupport::Concern

        included do
          key :votes, Hash, :default => DEFAULT_VOTES
          
          class << self
            alias_method :voteable_index, :ensure_index
            alias_method :voteable_collection, :collection
          end
        end

        module ClassMethods
          def voteable_relation(class_name)
            associations.find{ |x, r| r.class_name == class_name }.try(:last)
          end
          
          def voteable_foreign_key(metadata)
            (metadata.options[:in] || "#{metadata.name}_id").to_s
          end
        end
      end
    end
  end
end
