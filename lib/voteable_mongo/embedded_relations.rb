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
      # #embedded? and .embedded? are methods introduced by Mongoid. I'm are using safe names
      # here because they will be included directly and won't be called through de module.
      # 
      def reload
        if self.class.embedded?
          klass = self.class
          self.attributes = klass._parent_klass.find(eval(klass._parent_name).id) # Post.find(post.id)
                            .send(klass._inverse_relation)                        # .images
                            .find(id).attributes                                  # .find(id).attributes
        else
          super
        end
      end
      # Finds mongoid embedded-in Relation
      module ClassMethods
        
        # Getting the last mongoid relation of type Embedded:In. 
        # You can't embedded a document in multiple documents with Mongoid.
        # Therefore, there can only be one working relation of this type in a document.
        def _relation
          relations.find{|k,v| v.relation==Mongoid::Relations::Embedded::In }.try(:last)
        end
    
        # "post"
        def _parent_name
          _relation.name.to_s
        end
    
        # Accessing Master Collection (where the document is embedded)
        # eg: Post
        def _parent_klass
          _relation.class_name.constantize
        end
    
        # "images"
        # #inverse_setter is an attribute from Mongoid::Relations. 
        # eg: "images="
        def _inverse_relation
          _relation.inverse_setter.delete("=")
        end
      end
    end
  end
end