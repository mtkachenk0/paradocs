module Paradocs
  module Extensions
    class Structure
      %w(errors subschemes).each do |key|
        define_method(key) { "#{Paradocs.config.meta_prefix}#{key}".to_sym }
      end

      attr_reader :schema, :ignore_transparent, :root
      attr_accessor :ignore_transparent
      def initialize(schema, ignore_transparent=true, root="")
        @schema             = schema
        @ignore_transparent = ignore_transparent
        @root               = root
      end

      def flush!
        @nested, @all_nested, @flatten, @all_flatten = [nil] * 4
      end

      def nested(&block)
        @nested ||= schema.fields.each_with_object({errors => [], subschemes => {}}) do |(_, field), result|
          meta, sc = collect_meta(field, root)
          if sc
            meta[:structure] = self.class.new(sc, ignore_transparent, meta[:json_path]).nested(&block)
            result[errors] += meta[:structure].delete(errors)
          else
            result[errors] += field.possible_errors
          end
          result[field.key] = meta unless ignore_transparent && field.transparent?
          yield(field.key, meta) if block_given?

          next unless field.mutates_schema?
          schema.subschemes.each do |name, subschema|
            result[subschemes][name] = self.class.new(subschema, ignore_transparent, root).nested(&block)
            result[errors] += result[subschemes][name][errors]
          end
        end
      end

      def all_nested(&block)
        @all_nested ||= all_flatten(&block).each_with_object({}) do |(name, struct), obj|
          obj[name] = {}
          struct.sort_by { |k, v| k.to_s.count(".") }.each do |key, value|
            target = obj[name]
            key, value = key.to_s, value.clone
            next if key == subschemes
            next target[key] = value if key.start_with?(Paradocs.config.meta_prefix)
            parts = key.split(".")
            if parts.size == 1
              target[key] ||= value
            else
              parts.each.with_index do |subkey, index|
                target[subkey] ||= value
                next if parts.size == index + 1
                target[subkey][:structure] ||= {}
                target = target[subkey][:structure]
              end
            end
          end
        end
      end

      def all_flatten(schema_structure=nil, &block)
        return @all_flatten if @all_flatten
        schema_structure ||= flatten(&block)
        return @all_flatten = {generic: schema_structure} if schema_structure[subschemes].empty?
        @all_flatten = schema_structure[subschemes].each_with_object({}) do |(name, subschema), result|
          next result[name] = schema_structure.merge(subschema) if subschema[subschemes].empty?

          all_flatten(subschema).each do |sub_name, schema|
            result["#{name}_#{sub_name}".to_sym] = schema_structure.merge(schema)
          end
        end
      end

      def flatten(&block)
        @flatten ||= schema.fields.each_with_object({errors => [], subschemes => {}}) do |(_, field), obj|
          meta, sc = collect_meta(field, root)
          humanized_name = meta.delete(:nested_name)
          obj[humanized_name] = meta unless ignore_transparent && field.transparent?

          if sc
            deep_result = self.class.new(sc, ignore_transparent, meta[:json_path]).flatten(&block)
            obj[errors] += deep_result.delete(errors)
            obj[subschemes].merge!(deep_result.delete(subschemes))
            obj.merge!(deep_result)
          else
            obj[errors] += field.possible_errors
          end
          yield(humanized_name, meta) if block_given?
          next unless field.mutates_schema?
          schema.subschemes.each do |name, subschema|
            obj[subschemes][name] ||= self.class.new(subschema, ignore_transparent, root).flatten(&block)
            obj[errors] += obj[subschemes][name][errors]
          end
        end
      end

    private

      def collect_meta(field, root)
        json_path = root.empty? ? "$.#{field.key}" : "#{root}.#{field.key}"
        meta = field.meta_data.merge(json_path: json_path)
        sc = meta.delete(:schema)
        meta[:mutates_schema] = true if meta.delete(:mutates_schema)
        json_path << "[]" if meta[:type] == :array
        meta[:nested_name] = json_path.gsub("[]", "")[2..-1]
        [meta, sc]
      end
    end
  end
end
