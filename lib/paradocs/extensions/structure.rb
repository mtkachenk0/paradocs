module Paradocs
  module Extensions
    class Structure
      %w(errors subschemes).each do |key|
        define_method(key) { "#{Paradocs.config.meta_prefix}#{key}".to_sym }
      end
      attr_reader :schema, :ignore_transparent, :root
      def initialize(schema, ignore_transparent=true, root="")
        @schema = schema
        @ignore_transparent = ignore_transparent
        @root = root
      end

      def structure(&block)
        schema.fields.each_with_object({errors => [], subschemes => {}}) do |(_, field), obj|
          meta, sc = collect_meta(field, root)
          if sc
            meta[:structure] = self.class.new(sc, ignore_transparent, meta[:json_path]).structure(&block)
            obj[errors] += meta[:structure].delete(errors)
          else
            obj[errors] += field.possible_errors
          end
          obj[field.key] = meta unless ignore_transparent && field.transparent?
          yield(field.key, meta) if block_given?

          next unless field.mutates_schema?
          schema.subschemes.each do |name, subschema|
            obj[subschemes][name] = self.class.new(subschema, ignore_transparent, root).structure(&block)
            obj[errors] += obj[subschemes][name][errors]
          end
        end
      end

      def flatten_structure(&block)
        schema.fields.each_with_object({errors => [], subschemes => {}}) do |(_, field), obj|
          meta, sc = collect_meta(field, root)
          humanized_name = meta.delete(:nested_name)
          obj[humanized_name] = meta unless ignore_transparent && field.transparent?

          if sc
            deep_result = self.class.new(sc, ignore_transparent, meta[:json_path]).flatten_structure(&block)
            obj[errors] += deep_result.delete(errors)
            obj[subschemes].merge!(deep_result.delete(subschemes))
            obj.merge!(deep_result)
          else
            obj[errors] += field.possible_errors
          end
          yield(humanized_name, meta) if block_given?
          next unless field.mutates_schema?
          schema.subschemes.each do |name, subschema|
            obj[subschemes][name] ||= self.class.new(subschema, ignore_transparent, root).flatten_structure(&block)
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
