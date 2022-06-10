require 'paradocs'

module Paradocs
  module DSL
    # Example
    #   class Foo
    #     include Paradocs::DSL
    #
    #     schema do
    #       field(:title).type(:string).present
    #       field(:age).type(:integer).default(20)
    #     end
    #
    #      attr_reader :params
    #
    #      def initialize(input)
    #        @params = self.class.schema.resolve(input)
    #      end
    #   end
    #
    #   foo = Foo.new(title: "A title", nope: "hello")
    #
    #   foo.params # => {title: "A title", age: 20}
    #

    def self.included(base)
      base.extend(ClassMethods)
      base.schemas = { Paradocs.config.default_schema_name => Paradocs::Schema.new }
    end

    module ClassMethods
      def schema=(sc)
        @schemas[Paradocs.config.default_schema_name] = sc
      end

      def schemas=(sc)
        @schemas = sc
      end

      def inherited(subclass)
        subclass.schemas = @schemas.each_with_object({}) do |(key, sc), hash|
          hash[key] = sc.merge(Paradocs::Schema.new)
        end
      end

      def schema(*args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        key = args.first.is_a?(Symbol) ? args.shift : Paradocs.config.default_schema_name
        current_schema = @schemas.fetch(key) { Paradocs::Schema.new }
        new_schema = if block_given? || options.any?
                       Paradocs::Schema.new(options, &block)
                     elsif args.first.is_a?(Paradocs::Schema)
                       args.first
                     end

        return current_schema unless new_schema

        @schemas[key] = current_schema ? current_schema.merge(new_schema) : new_schema
        paradocs_after_define_schema(@schemas[key])
        @schemas[key]
      end

      def paradocs_after_define_schema(sc)
        # noop hook
      end
    end
  end
end
