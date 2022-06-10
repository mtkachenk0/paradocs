module Paradocs
  class Results
    attr_reader :output, :errors, :environment

    def initialize(output, errors, environment)
      @output = output
      @errors = errors
      @environment = environment
    end

    def valid?
      !errors.keys.any?
    end
  end
end
