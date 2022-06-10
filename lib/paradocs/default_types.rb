require 'date'

module Paradocs
  # type coercions
  Paradocs.policy :integer do
    coerce do |v, _k, _c|
      v.to_i
    end

    meta_data do
      { type: :integer }
    end
  end

  Paradocs.policy :number do
    coerce do |v, _k, _c|
      v.to_f
    end

    meta_data do
      { type: :number }
    end
  end

  Paradocs.policy :string do
    coerce do |v, _k, _c|
      v.to_s
    end

    meta_data do
      { type: :string }
    end
  end

  Paradocs.policy :boolean do
    coerce do |v, _k, _c|
      !!v
    end

    meta_data do
      { type: :boolean }
    end
  end

  # type validations
  Paradocs.policy :array do
    message do |actual|
      "expects an array, but got #{actual.inspect}"
    end

    validate do |value, key, payload|
      !payload.key?(key) || value.is_a?(Array)
    end

    meta_data do
      { type: :array }
    end
  end

  Paradocs.policy :object do
    message do |actual|
      "expects a hash, but got #{actual.inspect}"
    end

    validate do |value, key, payload|
      !payload.key?(key) ||
        value.respond_to?(:[]) &&
          value.respond_to?(:key?)
    end

    meta_data do
      { type: :object }
    end
  end

  Paradocs.policy :datetime do
    coerce do |v, _k, _c|
      DateTime.parse(v.to_s)
    end

    meta_data do
      { type: :datetime }
    end
  end
end
