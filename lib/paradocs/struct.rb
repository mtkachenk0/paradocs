require 'paradocs/dsl'

module Paradocs
  class InvalidStructError < ArgumentError
    attr_reader :errors
    def initialize(struct)
      @errors = struct.errors
      msg = @errors.map do |k, strings|
        "#{k} #{strings.join(', ')}"
      end.join('. ')
      super "#{struct.class} is not a valid struct: #{msg}"
    end
  end

  module Struct
    def self.included(base)
      base.send(:include, Paradocs::DSL)
      base.extend ClassMethods
    end

    def initialize(attrs = {}, environment = {})
      @_results = self.class.schema.resolve(attrs, environment)
      @_graph = self.class.build(@_results.output)
    end

    def valid?
      !_results.errors.any?
    end

    def errors
      _results.errors
    end

    #  returns a shallow copy.
    def to_h
      _results.output.clone
    end

    def ==(other)
      other.respond_to?(:to_h) && other.to_h.eql?(to_h)
    end

    def merge(attrs = {})
      self.class.new(to_h.merge(attrs))
    end

    private

    attr_reader :_graph, :_results

    module ClassMethods
      def new!(attrs = {}, environment = {})
        st = new(attrs, environment)
        raise InvalidStructError, st unless st.valid?

        st
      end

      # this hook is called after schema definition in DSL module
      def paradocs_after_define_schema(schema)
        schema.fields.keys.each do |key|
          key = schema.fields[key].meta_data[:alias] || key
          define_method key do
            _graph[key]
          end
        end
      end

      def build(attrs)
        attrs.each_with_object({}) do |(k, v), obj|
          obj[k] = wrap(k, v)
        end
      end

      def paradocs_build_class_for_child(_key, child_schema)
        klass = Class.new do
          include Struct
        end
        klass.schema = child_schema
        klass
      end

      def wrap(key, value)
        field = schema.fields[key]
        return value unless field

        case value
        when Hash
          # find constructor for field
          cons = field.meta_data[:schema]
          if cons.is_a?(Paradocs::Schema)
            klass = paradocs_build_class_for_child(key, cons)
            klass.paradocs_after_define_schema(cons)
            cons = klass
          end
          cons ? cons.new(value) : value.freeze
        when Array
          value.map { |v| wrap(key, v) }.freeze
        else
          value.freeze
        end
      end
    end
  end
end
