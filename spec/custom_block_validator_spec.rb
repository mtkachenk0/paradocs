require 'spec_helper'

describe 'custom block validator' do
  Paradocs.policy :validate_if do
    eligible do |options, _value, _key, payload|
      options.all? do |key, value|
        payload[key] == value
      end
    end
  end

  it 'works if I just define an :eligible block' do
    schema = Paradocs::Schema.new do
      field(:name).policy(:validate_if, age: 40).present
      field(:age).type(:integer)
    end

    expect(schema.resolve(age: 30).errors.any?).to be false
    expect(schema.resolve(age: 40).errors.any?).to be true #  name is missing
  end

  before do
    expect(Paradocs.registry.policies.values.map(&:policy_name)).to all(be)
  end

  describe 'error handling' do
    Paradocs.policy :strict_validation do
      register_error ArgumentError
      register_silent_error RuntimeError

      validate do |value, _key, _payload|
        raise ArgumentError, 'test' if value > 50
        raise 'value should not exceed 30' if value > 30

        true
      end

      coerce do |value, _key, _context|
        value / 0 if value > 100
        value
      end
    end

    let(:schema) do
      Paradocs::Schema.new do
        field(:age).type(:integer).policy(:strict_validation)
      end
    end

    context 'with disabled explicit errors' do
      it 'works fine if value is valid' do
        expect(schema.resolve(age: 20).errors.any?).to be false
      end

      it 'catches silent errors and uses the error.message as validation failure message' do
        expect(schema.resolve(age: 31).errors).to eq({ '$.age' => ['value should not exceed 30'] })
      end

      it 'raises the very registered error to the highest level' do
        expect { schema.resolve(age: 51) }.to raise_error(ArgumentError).with_message('test')
      end

      it 'catches unregistered error and uses the policy.message as validation failure message' do
        expect(schema.resolve(age: 101).errors).to eq({ '$.age' => ['is invalid'] })
      end
    end

    context 'with enabled explicit errors' do
      before { allow(Paradocs.config).to receive(:explicit_errors) { true } }

      it 'works fine if value is valid' do
        expect(schema.resolve(age: 20).errors.any?).to be false
      end

      it 'catches silent errors and uses the error.message as validation failure message' do
        expect(schema.resolve(age: 31).errors).to eq({ '$.age' => ['value should not exceed 30'] })
      end

      it 'raises the very registered error to the highest level' do
        expect { schema.resolve(age: 51) }.to raise_error(ArgumentError).with_message('test')
      end

      it 'catches unregistered error and raises Configuration error' do
        expect { schema.resolve(age: 101).errors }.to raise_error(Paradocs::ConfigurationError)
          .with_message('<ZeroDivisionError:divided by 0> should be registered in the policy')
      end
    end
  end
end
