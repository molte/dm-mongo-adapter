module DataMapper
  module Mongo
    module Model
      def self.extended(model)
        model.extend Embedment
      end

      # Defines a Property on the Resource
      #
      # Overrides the property method in dm-core so as to automatically map
      # Array and Hash types to EmbeddedArray and EmbeddedHash respectively.
      #
      # @param [Symbol] name
      #   the name for which to call this property
      # @param [Type] type
      #   the type to define this property ass
      # @param [Hash(Symbol => String)] options
      #   a hash of available options
      #
      # @return [Property]
      #   the created Property
      #
      # @api public
      def property(name, type, options = {})
        case type
        when Array
          super(name, DataMapper::Mongo::Property::Array, options)
        when Hash
          super(name, DataMapper::Mongo::Property::Hash, options)
        else
          super(name, type, options)
        end
      end

      # Loads an instance of this Model, taking into account IdentityMap
      # lookup, inheritance columns(s) and Property typecasting. Also loads
      # the embedments on the Resource.
      #
      # @param [Enumerable<Object>] records
      #   An Array of Resource or Hashes to load a Resource with
      # @param [DataMapper::Query] query
      #   The query used to load the Resource
      #
      # @return [Resource]
      #   The loaded Resource instance
      #
      # @overrides DataMapper::Model#load
      #
      # @api semipublic
      def load(records, query)
        resources = super

        # Load embedded resources
        resources.each_with_index do |resource, index|
          resource.model.embedments.each do |name, relationship|
            unless (targets = records[index][name.to_s]).blank?
              relationship.set(resource, targets, true)
            end
          end
        end

        resources
      end

      private

      # @api private
      def const_missing(name)
        if DataMapper::Mongo::Property.const_defined?(name)
          DataMapper::Mongo::Property.const_get(name)
        else
          super(name)
        end
      end
    end # Model
  end # Mongo
end # DataMapper
