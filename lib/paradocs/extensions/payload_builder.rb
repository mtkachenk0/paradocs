module Paradocs
  module Extensions
    class PayloadBuilder
      DEFAULT = :generic
      attr_reader :structure, :result
      attr_accessor :skip_word
      def initialize(schema, skip_word: :skip)
        @structure  = schema.structure
        @skip_word  = skip_word
      end

      def build!(&block)
        structure.all_nested.map { |name, struct| [name, build_simple_structure(struct, &block)] }.to_h
      end

      private

      def build_simple_structure(struct, &block)
        struct.map do |key, value|
          key = key.to_s
          next if key.start_with?(Paradocs.config.meta_prefix) # skip all the meta fields
          ex_value = restore_one(key, value, &block)
          next if ex_value == @skip_word
          [key, ex_value]
        end.compact.to_h
      end

      def restore_one(key, value, &block)
        default = value[:default]
        ex_value = if value[:structure]
          data = build_simple_structure(value[:structure], &block)
          value[:type] == :array ? [data] : data
        elsif default
          default.is_a?(Proc) ? default.call : default
        elsif value[:options] && !value[:options].empty?
          options = value[:options]
          value[:type] == :array ? options : options.sample
        end
        return ex_value unless block_given?
        yield(key, value, ex_value, @skip_word)
      end
    end
  end
end
