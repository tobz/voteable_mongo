module Mongo
  module Voteable
    module EmbeddedRelations
      extend ActiveSupport::Concern
      # Provides reloading funcionality for embedded documents.
      #  
      # Embedded Documents are not true mongo collections, what 
      # prevents them from reloading. This method evaluates whether
      # this instance is embedded and reloads it through its parent.
      # 
      # Example:
      #   Image embedded in Post
      #   self.attributes = Post.find(post.id).images.find(id)
      #
      def reload
        if self.class.embedded?
          klass = self.class
          self.attributes = klass.parent_klass.find(eval(klass.parent_name).id) # Post.find(post.id)
                            .send(klass.inverse_relation)                       # .images
                            .find(id).attributes                                # .find(id).attributes
        else
          super
        end
      end
      # Finds mongoid embedded-in Relation
      module ClassMethods
        def relation
          relations.find{|k,v| v.relation==Mongoid::Relations::Embedded::In }.try(:last)
        end
    
        # "post"
        def parent_name
          relation.name.to_s
        end
    
        # Post
        def parent_klass
          relation.class_name.constantize
        end
    
        # "images"
        def inverse_relation
          relation.inverse_setter.delete("=")
        end
      end
    end
  end
end