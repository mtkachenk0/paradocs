module Paradocs
  # Field DSL
  # host instance must implement:
  # #meta(options Hash)
  # #policy(key Symbol) self
  #
  module FieldDSL
    def required
      policy :required
    end

    def present
      required.policy :present
    end

    def declared
      policy :declared
    end

    def options(opts)
      policy :options, opts
    end

    def whitelisted
      policy :whitelisted
    end

    def transparent
      meta transparent: true
    end

    def length(opts)
      policy :length, opts
    end

    def description(text)
      meta description: text
    end

    def example(value)
      meta example: value
    end
  end
end
