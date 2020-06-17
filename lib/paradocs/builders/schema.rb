require "paradocs/schema"

module Paradocs
  module Builders
    class Schema
      attr_reader :obj, :result
      def initialize(obj, spaces_in_tab=2)
        @obj = obj
        @spaces_in_tab = spaces_in_tab
        @deep_level = 0
        @result = []
      end

      def generate
        @result.clear
        result << "Paradocs::Schema do"
        go_deeper(obj)
        result << "end"
        result
      end

      private

      def from_hash(hash)
        hash.each_pair do |key, value|
          type = type_of(value)
          field = "#{ident}field(:#{key}).#{presence_of(value)}.type(:#{type})"
          if %i(array object).include? type
            field << ".schema do"
            result << field
            go_deeper(value)
            result << "#{ident}end"
          else
            result << field
            next
          end
        end
      end

      def from_array(array)
        analyzing_array(array) do |hash|
          from_hash(hash)
        end
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

      def presence_of(value)
        return :required if value.nil? || value.try(:empty?) || value.try(:zero?)
        :present
      end

      def type_of(value)
        type = value.class.name.downcase.to_sym
        {
          ->(v) { %i(string integer array).include?(type) } => type,
          ->(v) { type == :hash }                           => :object,
          ->(v) { type == :float }                          => :number,
          ->(v) { !!v == v }                                => :boolean,
          ->(v) { DateTime.parse(v.to_s).to_s == v.to_s }   => :datetime
        }.detect { |rule, _| rule.call(value) }&.last || :string
      rescue
        :string
      end

      def analyzing_array(array, &block)
        result_was = @result
        @result = []
        array.each { |hash| yield(hash) }
        array_size = array.size

        grouped_result = @result.group_by do |name|
          name.match(/(\s*field\(:.+\)\.)(present|required|declared)./).try(:[], 1).to_s
        end
        grouped_result.each_with_index do |(field, duplicates), index|
          next if field.empty?
          field = field.dup
          # define presence of the field
          field << if duplicates.size != array.size
            "declared"
          else
            presence = duplicates.map { |field| field.match(/field\(:.+\).(\w+)\./)[1] }.uniq
            presence.size == 1 ? presence.first : presence.sort.last # [present, required] => required
          end

          types = duplicates.map { |f| f.match(/\.type\(:(\w+)\)/)[1] }.uniq
          field << ".type(:#{types.size == 1 ? types.first : "string"})" # set string if the same fields have different types
          field << ".schema do" if duplicates.any? { |x| x.match? /\.schema do/ }
          result_was << field

          # possible_end = @result[@result.index { |el| el.include?(field) } + 1]
          # result_was << possible_end if possible_end.match? /\send/
        end
        binding.pry
        @result = result_was
      end
    end
  end
end
