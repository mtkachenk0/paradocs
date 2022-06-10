module Paradocs
  module Extensions
    class Structure
      DEFAULT = :generic
      %w[errors subschemes].each do |key|
        define_method(key) { "#{Paradocs.config.meta_prefix}#{key}".to_sym }
      end

      attr_reader :schema, :ignore_transparent, :root
      attr_accessor :ignore_transparent
      def initialize(schema, ignore_transparent = true, root = '')
        @schema             = schema
        @ignore_transparent = ignore_transparent
        @root               = root
      end

      def nested(&block)
        schema.fields.each_with_object({ errors => [], subschemes => {} }) do |(_, field), result|
          meta, sc = collect_meta(field, root)
          if sc
            meta[:structure] = self.class.new(sc, ignore_transparent, meta[:json_path]).nested(&block)
            result[errors] += meta[:structure].delete(errors)
          else
            result[errors] += field.possible_errors
          end

          field_key = field.meta_data[:alias] || field.key
          result[field_key] = meta unless ignore_transparent && field.transparent?
          yield(field_key, meta) if block_given?

          next unless field.mutates_schema?

          schema.subschemes.each do |name, subschema|
            result[subschemes][name] = self.class.new(subschema, ignore_transparent, root).nested(&block)
            result[errors] += result[subschemes][name][errors]
          end
        end
      end

      def all_nested(&block)
        all_flatten(&block).each_with_object({}) do |(name, struct), obj|
          obj[name] = {}
          # sort the flatten struct to have iterated 1lvl keys before 2lvl and so on...
          struct.sort_by { |k, _v| k.to_s.count('.') }.each do |key, value|
            target = obj[name]
            key = key.to_s
            value = value.clone # clone the values, because we do mutation below
            value.merge!(nested_name: key) if value.respond_to?(:merge) # it can be array (_errors)
            next target[key.to_sym] = value if key.start_with?(Paradocs.config.meta_prefix) # copy meta fields

            parts = key.split('.')
            next target[key] ||= value if parts.size == 1 # copy 1lvl key

            parts.each.with_index do |subkey, index|
              target[subkey] ||= value
              next if parts.size == index + 1

              target[subkey][:structure] ||= {}
              target = target[subkey][:structure] # target goes deeper for each part
            end
          end
        end
      end

      def all_flatten(schema_structure = nil, &block)
        schema_structure ||= flatten(&block)
        if schema_structure[subschemes].empty?
          schema_structure.delete(subschemes) # don't include redundant key
          return { DEFAULT => schema_structure }
        end
        schema_structure[subschemes].each_with_object({}) do |(name, subschema), result|
          if subschema[subschemes].empty?
            result[name] = schema_structure.merge(subschema)
            result[name][errors] += schema_structure[errors]
            result[name][errors].uniq!
            result[name].delete(subschemes)
            next result[name]
          end

          all_flatten(subschema).each do |sub_name, schema|
            result["#{name}_#{sub_name}".to_sym] = schema_structure.merge(schema)
          end
        end
      end

      def flatten(&block)
        schema.fields.each_with_object({ errors => [], subschemes => {} }) do |(_, field), obj|
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
        field_key = field.meta_data[:alias] || field.key
        json_path = root.empty? ? "$.#{field_key}" : "#{root}.#{field_key}"
        meta = field.meta_data.merge(json_path: json_path)
        sc = meta.delete(:schema)
        meta[:mutates_schema] = true if meta.delete(:mutates_schema)
        json_path << '[]' if meta[:type] == :array
        meta[:nested_name] = json_path.gsub('[]', '')[2..-1]
        [meta, sc]
      end
    end
  end
end
