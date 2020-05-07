require_relative './base_policy'

module Paradocs
  module Policies
    class Format < Paradocs::BasePolicy
      attr_reader :message

      def initialize(fmt, msg = "invalid format")
        @message = msg
        @fmt = fmt
      end

      def eligible?(value, key, payload)
        payload.key?(key)
      end

      def validate(value, key, payload)
        !payload.key?(key) || !!(value.to_s =~ @fmt)
      end
    end
  end

  # Default validators
  EMAIL_REGEXP = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.freeze

  Paradocs.policy :format, Policies::Format
  Paradocs.policy :email, Policies::Format.new(EMAIL_REGEXP, 'invalid email')

  Paradocs.policy :noop do
    eligible do |value, key, payload|
      true
    end
  end

  Paradocs.policy :declared do
    eligible do |value, key, payload|
      payload.key? key
    end

    meta_data do
      {}
    end
  end

  Paradocs.policy :whitelisted do
    meta_data do
      {whitelisted: true}
    end
  end

  Paradocs.policy :required do
    message do |*|
      "is required"
    end

    validate do |value, key, payload|
      payload.try(:key?, key)
    end

    meta_data do
      {required: true}
    end
  end

  Paradocs.policy :present do
    message do |*|
      "is required and value must be present"
    end

    validate do |value, key, payload|
      case value
      when String
        value.strip != ''
      when Array, Hash
        value.any?
      else
        !value.nil?
      end
    end

    meta_data do
      {present: true}
    end
  end

  {
    gte: [:>=, "greater than or equal to"],
    lte: [:<=, "less than or equal to"],
    gt:  [:>, "strictly greater than"],
    lt:  [:<, "strictly less than"]
  }.each do |policy, (comparison, text)|
    klass = Class.new(Paradocs::BasePolicy) do
      attr_reader :limit
      define_method(:initialize) do |limit|
        @limit = limit.is_a?(Proc) ? limit.call : limit
      end

      define_method(:message) do
        "value must be #{text} #{limit}"
      end

      define_method(:validate) do |value, key, _|
        @key, @value = key, value
        value.send(comparison, limit)
      end

      define_method(:meta_data) do
        meta = super()
        meta[policy][:limit] = limit
        binding.pry unless meta.dig(policy, :limit)
        meta
      end

      define_singleton_method(:policy_name) do
        policy
      end
    end
    Paradocs.policy(policy, klass)
  end

  Paradocs.policy :options do
    message do |options, actual|
      "must be one of #{options.join(', ')}, but got #{actual}"
    end

    eligible do |options, actual, key, payload|
      payload.key?(key)
    end

    validate do |options, actual, key, payload|
      !payload.key?(key) || ok?(options, actual)
    end

    meta_data do |opts|
      {options: opts}
    end

    def ok?(options, actual)
      [actual].flatten.all?{|v| options.include?(v)}
    end
  end
end
