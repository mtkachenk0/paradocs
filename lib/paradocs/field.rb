require 'paradocs/field_dsl'

module Paradocs
  class Field
    include FieldDSL

    attr_reader :key, :meta_data
    Result = Struct.new(:eligible?, :value)

    def initialize(key)
      @key = key
      @policies = []
      @default_block = nil
      @meta_data = {}
      @policies = []
      @mutation_block = nil
      @expects_mutation = nil
    end

    def meta(hash = nil)
      @meta_data = @meta_data.merge(hash) if hash.is_a?(Hash)
      self
    end

    def possible_errors
      meta_data.map { |_, v| v[:errors] if v.is_a?(Hash) }.flatten.compact
    end

    def default(value)
      meta default: value
      @default_block = (value.respond_to?(:call) ? value : ->(_key, _payload, _context) { value })
      self
    end

    def mutates_schema!(&block)
      @mutation_block ||= block if block_given?
      @expects_mutation = @expects_mutation.nil? && true
      meta mutates_schema: @mutation_block
      @mutation_block
    end

    def mutates_schema?
      !!@mutation_block
    end

    def expects_mutation?
      mutates_schema? && @expects_mutation
    end

    def policy(key, *args)
      pol = lookup(key, args)

      meta pol.meta_data
      policies << pol
      self
    end

    alias type policy
    alias rule policy

    def schema(sc = nil, &block)
      sc = (sc || Schema.new(&block))
      meta schema: sc
      policy sc.schema
    end

    def transparent?
      !!meta_data[:transparent]
    end

    def visit(meta_key = nil, &visitor)
      if sc = meta_data[:schema]
        r = sc.visit(meta_key, &visitor)
        meta_data[:type] == :array ? [r] : r
      else
        meta_key ? meta_data[meta_key] : yield(self)
      end
    end

    def subschema_for_mutation(payload, env)
      subschema_name = @mutation_block.call(payload[key], key, payload, env) if @mutation_block
      @expects_mutation = false
      subschema_name
    end

    def resolve(payload, context)
      eligible = payload.key?(key)
      value = payload[key] # might be nil

      if !eligible && has_default?
        eligible = true
        value = default_block.call(key, payload, context)
        payload[key] = value
      end
      policies.each do |policy|
        # pass schema additional data to the each policy
        policy.environment = context.environment if policy.respond_to?(:environment=)
        if !policy.eligible?(value, key, payload)
          eligible = false
          if has_default?
            eligible = true
            value = default_block.call(key, payload, context)
          end
          break
        else
          value, valid = resolve_one(policy, value, payload, context)

          unless valid
            eligible = true # eligible, but has errors
            break # only one error at a time
          end
        end
      end

      Result.new(eligible, value)
    end

    private

    attr_reader :policies, :default_block

    def resolve_one(policy, value, payload, context)
      value = policy.coerce(value, key, context)
      valid = policy.valid?(value, key, payload)

      context.add_error(policy.message) unless valid
      [value, valid]
    rescue *(policy.try(:errors) || []) => e
      # context.add_error e.message # NOTE: do we need it?
      raise e
    rescue *(policy.try(:silent_errors) || []) => e
      context.add_error e.message
    rescue StandardError => e
      raise e if policy.is_a? Paradocs::Schema # from the inner level, just reraise

      if Paradocs.config.explicit_errors
        error = ConfigurationError.new("<#{e.class}:#{e.message}> should be registered in the policy")
        error.set_backtrace(e.backtrace)
        raise error
      end
      context.add_error policy.message unless Paradocs.config.explicit_errors
      [value, false]
    end

    def has_default?
      !!default_block
    end

    def lookup(key, args)
      obj = key.is_a?(Symbol) ? Paradocs.registry.policies[key] : key

      raise ConfigurationError, "No policies defined for #{key.inspect}" unless obj

      obj.respond_to?(:new) ? obj.new(*args) : obj
    end
  end
end
