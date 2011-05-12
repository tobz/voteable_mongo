module Mongo
  module Voteable
    module Helpers

      def self.try_to_convert_string_to_object_id(x)
        x.is_a?(String) && BSON::ObjectId.legal?(x) ? BSON::ObjectId(x) : x
      end

      def self.get_mongo_id(x)
        x.respond_to?(:id) ? x.id : x
      end

    end
  end
end
