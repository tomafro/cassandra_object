module CassandraObject
  module Persistence
    extend ActiveSupport::Concern
    
    module ClassMethods
      def get(key)
        # Can't use constructor for both 'fetch' and 'new'
        # take approach from AR.
        instantiate(key, connection.get(column_family, key))
      end

      def all(keyrange = ''..'', options = {})
        connection.get_key_range(column_family, keyrange, options[:limit] || 100).map {|key| get(key) }
      end
      
      def first(keyrange = ''..'', options = {})
        all(keyrange, options.merge(:limit=>1)).first
      end
      
      def create(attributes)
        returning new(attributes) do |object|
          object.save
        end
      end

      def write(key, attributes)
        returning key || next_key do |key|
          connection.insert(column_family, key, attributes.stringify_keys)
        end
      end

      def instantiate(key, attributes)
        returning allocate do |object|
          object.instance_variable_set("@key", key)
          object.instance_variable_set("@attributes", attributes)
          object.instance_variable_set("@changed_attribute_names", Set.new)
          
        end
      end
    end
    
    module InstanceMethods
      def save
        if was_new_record = new_record?
          run_callbacks :before_create
        end
        run_callbacks :before_save
        @key ||= self.class.write(key, changed_attributes)
        run_callbacks :after_save
        run_callbacks :after_create if was_new_record
        @new_record = false
        true
      end

      def new_record?
        @new_record || false
      end
    end
  end
end