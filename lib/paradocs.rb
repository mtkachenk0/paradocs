require 'paradocs/version'
require 'paradocs/support'
require 'paradocs/registry'
require 'paradocs/field'
require 'paradocs/results'
require 'paradocs/schema'
require 'paradocs/context'
require 'paradocs/base_policy'
require 'ostruct'

module Paradocs
  def self.registry
    @registry ||= Registry.new
  end

  def self.policy(name, plcy = nil, &block)
    registry.policy name, plcy, &block
  end

  def self.config
    @config ||= OpenStruct.new(
      explicit_errors: false,
      whitelisted_keys: [],
      default_schema_name: :schema,
      meta_prefix: '_',
      whitelist_coercion: nil
    )
  end

  def self.configure
    yield config if block_given?
    config
  end
end

require 'paradocs/default_types'
require 'paradocs/policies'
