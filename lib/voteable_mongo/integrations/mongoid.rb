module Mongo
  module Voteable
    module Integrations
      module Mongoid
        extend ActiveSupport::Concern

        included do
          # The field votes won't be defined here on account 
          # of the customizeable field

          class << self
            alias_method :voteable_index, :index
          end
        end
        
        module ClassMethods
          def voteable_relation(class_name)
            relations.find{ |x, r| r.class_name == class_name }.try(:last)
          end
          
          # Falling back to Ruby driver's collection.
          # For embedded documents, it should point to the master collection.
          def voteable_collection
            if self.embedded?
              _parent_klass.collection.master.collection
            else
              collection.master.collection
            end
          end

          def voteable_foreign_key(metadata)
            metadata.foreign_key.to_s
          end
        end
      end
    end
  end
end
