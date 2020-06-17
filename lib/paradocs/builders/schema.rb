require "paradocs/schema"

module Paradocs
  module Builders
    class Schema
      class Identable
        attr_reader :ident, :name
        def initialize(name, ident="")
          @name = name
          @ident = ident
        end
        def inspect; "#{ident}#{name}"; end
        def to_s; inspect; end
      end

      class Field < Identable
        attr_accessor :presence, :type, :value
        def initialize(key, value, ident)
          @value = value
          @presence = value.nil? || value.try(:empty?) || value.try(:zero?) ? :required : :present
          @type = resolve_type
          @schema = %i(array object).include?(type) ? ".schema do" : ""
          super(key, ident)
        end

        def inspect
          "#{@ident}field(:#{name}).#{presence}.type(:#{type})#{@schema}"
        end

        def nested?
          !@schema.empty?
        end

        private

        def resolve_type
          type = value.class.name.downcase.to_sym
          {
            ->(v) { %i(string integer array).include?(type) } => type,
            ->(v) { type == :hash }                           => :object,
            ->(v) { type == :float }                          => :number,
            ->(v) { !!v == v }                                => :boolean,
            ->(v) { DateTime.parse(v.to_s).to_s == v.to_s }   => :datetime
          }.detect { |rule, _| rule.call(value) }&.last || :string
        rescue => ex
          :string
        end
      end

      attr_reader :obj, :result
      def initialize(obj, spaces_in_tab=2)
        @obj = obj
        @spaces_in_tab = spaces_in_tab
        @deep_level = 0
        @result = []
      end

      def generate
        @result.clear
        result << Identable.new("Paradocs::Schema do")
        go_deeper(obj)
        close_blocks!
        result
      end

      private

      def from_hash(hash)
        hash.each_pair do |key, value|
          field = Field.new(key, value, ident)
          result << field
          go_deeper(value) if field.nested?
        end
      end

      def from_array(array)
        analyzing_array(array) { |hash| from_hash(hash) }
      end

      def go_deeper(obj)
        mtd = obj.is_a?(Array) ? :from_array : :from_hash
        @deep_level += 1
        method(mtd).call(obj)
        @deep_level -= 1
      end

      def ident
        " " * @deep_level * @spaces_in_tab
      end

      def close_blocks!
        memo = result.clone
        memo.each_with_index do |field, index|
          next unless field.try(:nested?)
          blok = result.slice(result.index(field) + 1..-1)
          end_before_field = blok.detect { |f| f.ident <= field.ident }
          field_index = result.index(end_before_field) || result.index(memo[-1]) + 1
          result.insert(field_index, Identable.new("end", field.ident))
        end
      end

      def analyzing_array(array, &block)
        result_was = @result
        @result = []
        array.each { |hash| yield(hash) }
        array_size = array.size

        @result.group_by { |field| [field.name, field.ident] }.each do |field, duplicates|
          adjusted_field = duplicates.first
          adjusted_field.presence = if duplicates.size != array.size
            :declared
          else
            presence = duplicates.map(&:presence).uniq
            presence.size == 1 ? presence.first : presence.sort.last # [present, required] => required
          end

          types = duplicates.map(&:type).uniq
          adjusted_field.type = types.size == 1 ? types.first : :string
          result_was << adjusted_field
        end
        @result = result_was
      end
    end
  end
end
