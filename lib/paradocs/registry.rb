require 'paradocs/base_policy'

module Paradocs
  class ConfigurationError < StandardError; end

  class Registry
    attr_reader :policies

    def initialize
      @policies = {}
    end

    def coercions
      policies
    end

    def policy(name, plcy = nil, &block)
      validate_policy_class(plcy) if plcy

      policies[name] = (plcy || BasePolicy.build(name, :instance_eval, &block))
      self
    end

    private

    def validate_policy_class(plcy)
      plcy_cls = plcy.is_a?(Class) ? plcy : plcy.class
      if plcy_cls < Paradocs::BasePolicy
        valid_overriden = plcy_cls.instance_method(:valid?).source_location != Paradocs::BasePolicy.instance_method(:valid?).source_location
        if valid_overriden
          raise ConfigurationError, "Overriding #valid? in #{plcy_cls} is forbidden. Override #validate instead"
        end
      else
        required_methods = %i[valid? coerce eligible? meta_data policy_name] - plcy_cls.instance_methods
        unless required_methods.empty?
          raise ConfigurationError, "Policy #{plcy_cls} should respond to #{required_methods}"
        end

        return plcy unless Paradocs.config.explicit_errors
        return plcy if plcy_cls.respond_to?(:errors)

        raise ConfigurationError, "Policy #{plcy_cls} should respond to .errors method"
      end
    end
  end
end
