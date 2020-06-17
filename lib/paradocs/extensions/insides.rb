module Paradocs
  module Extensions
    module Insides
      def structure(ignore_transparent: true, &block)
        flush!
        fields.each_with_object({meta_keys[:errors] => [], meta_keys[:subschemes] => {}}) do |(_, field), obj|
          meta = field.meta_data.dup
          sc = meta.delete(:schema)
          meta[:mutates_schema] = true if meta.delete(:mutates_schema)
          if sc
            meta[:structure] = sc.structure(ignore_transparent: ignore_transparent, &block)
            obj[meta_keys[:errors]] += meta[:structure].delete(meta_keys[:errors])
          else
            obj[meta_keys[:errors]] += field.possible_errors
          end
          obj[field.key] = meta unless ignore_transparent && field.transparent?
          yield(field.key, meta) if block_given?

          next unless field.mutates_schema?
          subschemes.each do |name, subschema|
            obj[meta_keys[:subschemes]][name] = subschema.structure(ignore_transparent: ignore_transparent, &block)
            obj[meta_keys[:errors]] += obj[meta_keys[:subschemes]][name][meta_keys[:errors]]
          end
        end
      end

      def flatten_structure(ignore_transparent: true, root: "", &block)
        flush!
        fields.each_with_object({meta_keys[:errors] => [], meta_keys[:subschemes] => {}}) do |(name, field), obj|
          json_path = root.empty? ? "$.#{name}" : "#{root}.#{name}"
          meta = field.meta_data.merge(json_path: json_path)
          sc = meta.delete(:schema)
          meta[:mutates_schema] = true if meta.delete(:mutates_schema)
          json_path << "[]" if meta[:type] == :array
          humanized_name = json_path.gsub("[]", "")[2..-1]
          obj[humanized_name] = meta unless ignore_transparent && field.transparent?

          if sc
            deep_result = sc.flatten_structure(ignore_transparent: ignore_transparent, root: json_path, &block)
            obj[meta_keys[:errors]] += deep_result.delete(meta_keys[:errors])
            obj[meta_keys[:subschemes]].merge!(deep_result.delete(meta_keys[:subschemes]))
            obj.merge!(deep_result)
          else
            obj[meta_keys[:errors]] += field.possible_errors
          end
          yield(humanized_name, meta) if block_given?
          next unless field.mutates_schema?
          subschemes.each do |name, subschema|
            obj[meta_keys[:subschemes]][name] ||= subschema.flatten_structure(ignore_transparent: ignore_transparent, root: root, &block)
            obj[meta_keys[:errors]] += obj[meta_keys[:subschemes]][name][meta_keys[:errors]]
          end
        end
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

      def meta_keys
        %i(errors subschemes).map! { |key| [key, "#{Paradocs.config.meta_prefix}#{key}".to_sym] }.to_h
      end
    end
  end
end
