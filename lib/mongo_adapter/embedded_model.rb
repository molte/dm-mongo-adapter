module DataMapper
  module Mongo
    module EmbeddedModel
      extend Chainable
      include DataMapper::Model

      # Creates a new Model class with default_storage_name +storage_name+
      #
      # If a block is passed, it will be eval'd in the context of the new Model
      #
      # @param [Proc] block
      #   a block that will be eval'd in the context of the new Model class
      #
      # @return [Model]
      #   the newly created Model class
      #
      # @api semipublic
      def self.new(&block)
        model = Class.new

        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        include DataMapper::Mongo::EmbeddedResource

        def self.name
          to_s
        end
        RUBY

        model.instance_eval(&block) if block
        model
      end

      # Methods copied from DataMapper::Model

      # Return all models that extend the Model module
      #
      #   class Foo
      #     include DataMapper::Resource
      #   end
      #
      #   DataMapper::Model.descendants.first   #=> Foo
      #
      # @return [DescendantSet]
      #   Set containing the descendant models
      #
      # @api semipublic
      def self.descendants
        @descendants ||= DescendantSet.new
      end

      # Return all models that inherit from a Model
      #
      #   class Foo
      #     include DataMapper::Resource
      #   end
      #
      #   class Bar < Foo
      #   end
      #
      #   Foo.descendants.first   #=> Bar
      #
      # @return [Set]
      #   Set containing the descendant classes
      #
      # @api semipublic
      attr_reader :descendants

      # Appends a module for inclusion into the model class after Resource.
      #
      # This is a useful way to extend Resource while still retaining a
      # self.included method.
      #
      # @param [Module] inclusions
      #   the module that is to be appended to the module after Resource
      #
      # @return [Boolean]
      #   true if the inclusions have been successfully appended to the list
      #
      # @api semipublic
      def self.append_inclusions(*inclusions)
        extra_inclusions.concat inclusions

        # Add the inclusion to existing descendants
        descendants.each do |model|
          inclusions.each { |inclusion| model.send :include, inclusion }
        end

        true
      end

      # The current registered extra inclusions
      #
      # @return [Set]
      #
      # @api private
      def self.extra_inclusions
        @extra_inclusions ||= []
      end

      # Extends the model with this module after Resource has been included.
      #
      # This is a useful way to extend Model while still retaining a self.extended method.
      #
      # @param [Module] extensions
      #   List of modules that will extend the model after it is extended by Model
      #
      # @return [Boolean]
      #   whether or not the inclusions have been successfully appended to the list
      #
      # @api semipublic
      def self.append_extensions(*extensions)
        extra_extensions.concat extensions

        # Add the extension to existing descendants
        descendants.each do |model|
          extensions.each { |extension| model.extend(extension) }
        end

        true
      end

      # The current registered extra extensions
      #
      # @return [Set]
      #
      # @api private
      def self.extra_extensions
        @extra_extensions ||= []
      end

      # @api private
      def self.extended(model)
        descendants = self.descendants

        descendants << model

        model.instance_variable_set(:@valid,         false)
        model.instance_variable_set(:@base_model,    model)
        model.instance_variable_set(:@storage_names, {})
        model.instance_variable_set(:@default_order, {})
        model.instance_variable_set(:@descendants,   descendants.class.new(model, descendants))

        extra_extensions.each { |mod| model.extend(mod)         }
        extra_inclusions.each { |mod| model.send(:include, mod) }
      end

      # @api private
      chainable do
        def inherited(model)
          descendants = self.descendants

          descendants << model

          model.instance_variable_set(:@valid,         false)
          model.instance_variable_set(:@base_model,    base_model)
          model.instance_variable_set(:@storage_names, @storage_names.dup)
          model.instance_variable_set(:@default_order, @default_order.dup)
          model.instance_variable_set(:@descendants,   descendants.class.new(model, descendants))

          # TODO: move this into dm-validations
          if respond_to?(:validators)
            validators.contexts.each do |context, validators|
              model.validators.context(context).concat(validators)
            end
          end
        end
      end

      # end of DataMapper::Model methods

      append_extensions DataMapper::Model::Hook
      append_extensions DataMapper::Model::Property
      append_extensions DataMapper::Model::Relationship

      # @overrides DataMapper::Model#assert_valid
      def assert_valid
        return if @valid
        @valid = true

        if properties.empty?
          raise IncompleteModelError, "#{self.name} must have at least one property to be valid"
        end
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

      private

      # @api private
      def const_missing(name)
        if DataMapper::Mongo::Property.const_defined?(name)
          DataMapper::Mongo::Property.const_get(name)
        else
          super(name)
        end
      end

    end # EmbeddedModel
  end # Mongo
end # DataMapper
