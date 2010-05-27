require 'dm-core'
require 'dm-aggregates'
require 'mongo'

dir = Pathname(__FILE__).dirname.expand_path / 'mongo_adapter'

require dir / 'query'
require dir / 'query' / 'java_script'
require dir / 'conditions'

require dir / 'property' / 'object_id'
require dir / 'property' / 'db_ref'
require dir / 'property' / 'array'
require dir / 'property' / 'hash'

require dir / 'support' / 'class'
require dir / 'support' / 'date'
require dir / 'support' / 'date_time'
require dir / 'support' / 'object'

require dir / 'model'
require dir / 'resource'
require dir / 'migrations'
require dir / 'modifier'

require dir / 'aggregates'
require dir / 'adapter'

module DataMapper
  module Mongo
    module QueryExtensions
      def self.included(base)
        # FIXME: figure out a cleaner approach than AMC
        base.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          alias assert_valid_conditions_without_embedment assert_valid_conditions
          alias assert_valid_conditions assert_valid_conditions_with_embedment
        RUBY
      end

      def assert_valid_conditions_with_embedment(conditions)
        if conditions.is_a?(Hash) && model.respond_to?(:embedments) && !model.embedments.blank?
          conditions.each_key do |key|
            key_s = key.to_s

            name  = if key_s.include?('.')
              key_s.split('.')[0].to_sym
            else
              key
            end

            conditions.delete(key) if model.embedments.key?(name)
          end
        end

        assert_valid_conditions_without_embedment(conditions)
      end
    end
  end
end

DataMapper::Query.send(:include, DataMapper::Mongo::QueryExtensions)
