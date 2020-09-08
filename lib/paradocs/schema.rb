require "paradocs/context"
require "paradocs/results"
require "paradocs/field"
require "paradocs/extensions/structure"
require "paradocs/extensions/payload_builder"

module Paradocs
  class Schema
    attr_accessor :environment
    attr_reader :subschemes
    def initialize(options={}, &block)
      @options = options
      @fields = {}
      @subschemes = {}
      @definitions = []
      @definitions << block if block_given?
      @default_field_policies = []
      @ignored_field_keys = []
      @expansions = {}
    end

    def schema
      self
    end

    def mutation_by!(key, &block)
      f = @fields.keys.include?(key) ? @fields[key] : field(key).transparent
      f.mutates_schema!(&block)
    end

    def structure(ignore_transparent: true, &block)
      flush!
      Paradocs::Extensions::Structure.new(self, ignore_transparent).structure(&block)
    end

    def flatten_structure(ignore_transparent: true, &block)
      flush!
      Paradocs::Extensions::Structure.new(self, ignore_transparent).flatten_structure(&block)
    end

    def walk(meta_key = nil, &visitor)
      r = visit(meta_key, &visitor)
      Results.new(r, {}, {})
    end

    def visit(meta_key = nil, &visitor)
      fields.each_with_object({}) do |(_, field), m|
        m[field.key] = field.visit(meta_key, &visitor)
      end
    end

    def subschema(*args, &block)
      options = args.last.is_a?(Hash) ? args.last : {}
      name = args.first.is_a?(Symbol) ? args.shift : Paradocs.config.default_schema_name
      current_schema = subschemes.fetch(name) { self.class.new }
      new_schema = if block_given?
        sc = self.class.new(options)
        sc.definitions << block
        sc
      elsif args.first.is_a?(self.class)
        args.first
      else
        self.class.new(options)
      end
      subschemes[name] = current_schema.merge(new_schema)
    end

    def fields
      apply!
      @fields
    end

    def policy(*names, &block)
      @default_field_policies = names
      definitions << block if block_given?

      self
    end

    def ignore(*field_keys, &block)
      @ignored_field_keys += field_keys
      @ignored_field_keys.uniq!

      definitions << block if block_given?

      self
    end

    def clone
      instance = self.class.new(options)
      copy_into instance
    end

    def merge(other_schema)
      instance = self.class.new(options.merge(other_schema.options))

      copy_into(instance)
      other_schema.copy_into(instance)
    end

    def copy_into(instance)
      instance.policy(*default_field_policies) if default_field_policies.any?

      definitions.each do |d|
        instance.definitions << d
      end

      subschemes.each { |name, subsc| instance.subschema(name, subsc) }

      instance.ignore *ignored_field_keys
      instance
    end

    def field(field_or_key)
      f, key = if field_or_key.kind_of?(Field)
        [field_or_key, field_or_key.key]
      else
        [Field.new(field_or_key), field_or_key.to_sym]
      end

      if ignored_field_keys.include?(f.key)
        f
      else
        @fields[key] = apply_default_field_policies_to(f)
      end
    end

    def expand(exp, &block)
      expansions[exp] = block
      self
    end

    def resolve(payload, environment={})
      @environment = environment
      context = Context.new(nil, Top.new, @environment, subschemes)
      output = coerce(payload, nil, context)
      Results.new(output, context.errors, @environment)
    end

    def eligible?(value, key, payload)
      payload.key? key
    end

    def valid?(*_)
      true
    end

    def meta_data
      {}
    end

    def coerce(val, _, context)
      flush!
      if val.is_a?(Array)
        val.map.with_index do |v, idx|
          subcontext = context.sub(idx)
          out = coerce_one(v, subcontext)
          resolve_expansions(v, out, subcontext)
        end
      else
        out = coerce_one(val, context)
        resolve_expansions(val, out, context)
      end
    end

    protected

    attr_reader :definitions, :options

    private

    attr_reader :default_field_policies, :ignored_field_keys, :expansions

    def coerce_one(val, context, flds: fields)
      invoke_subschemes!(val, context, flds: flds)
      flds.each_with_object({}) do |(_, field), m|
        r = field.resolve(val, context.sub(field.key))
        m[field.key] = r.value if r.eligible?
      end
    end

    def invoke_subschemes!(payload, context, flds: fields)
      invoked_any = false
      # recoursive definitions call depending on payload
      flds.clone.each_pair do |_, field|
        next unless field.expects_mutation?
        subschema_name = field.subschema_for_mutation(payload, context.environment)
        subschema = subschemes[subschema_name] || context.subschema(subschema_name)
        next unless subschema # or may be raise error?
        subschema.definitions.each { |block| self.instance_exec(&block) }
        invoked_any = true
      end
      # if definitions are applied new subschemes may appear, apply them until they end
      invoke_subschemes!(payload, context, flds: fields) if invoked_any
    end

    class MatchContext
      def field(key)
        Field.new(key.to_sym)
      end
    end

    def resolve_expansions(payload, into, context)
      expansions.each do |exp, block|
        payload.each do |key, value|
          match = exp.match(key.to_s)
          next unless match
          fld = MatchContext.new.instance_exec(match, &block)
          next unless fld
          into.update(coerce_one({fld.key => value}, context, flds: {fld.key => apply_default_field_policies_to(fld)}))
        end
      end

      into
    end

    def apply_default_field_policies_to(field)
      default_field_policies.reduce(field) {|f, policy_name| f.policy(policy_name) }
    end

    def apply!
      return if @applied
      definitions.each do |d|
        self.instance_exec(options, &d)
      end
      @applied = true
    end

    def flush!
      @fields = {}
      @applied = false
    end
  end
end
