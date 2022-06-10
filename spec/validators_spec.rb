require 'spec_helper'

describe 'default validators' do
  def test_validator(payload, key, name, eligible, valid, *args)
    validator = Paradocs.registry.policies[name]
    validator = validator.new(*args) if validator.respond_to?(:new)
    expect(validator.eligible?(payload[key], key, payload)).to eq eligible
    expect(validator.valid?(payload[key], key, payload)).to eq valid
  end

  describe ':format' do
    it {
      test_validator({ key: 'Foobar' }, :key, :format, true, true, /^Foo/)
      test_validator({ key: 'Foobar' }, :key, :format, true, false, /^Bar/)
      test_validator({ foo: 'Foobar' }, :key, :format, false, true, /^Foo/)
    }
  end

  describe ':email' do
    it {
      test_validator({ key: 'foo@bar.com' }, :key, :email, true, true)
      test_validator({ key: 'foo@' }, :key, :email, true, false)
      test_validator({ foo: 'foo@bar.com' }, :key, :email, false, true)
    }
  end

  describe ':required' do
    it {
      test_validator({ key: 'foo' }, :key, :required, true, true)
      test_validator({ key: '' }, :key, :required, true, true)
      test_validator({ key: nil }, :key, :required, true, true)
      test_validator({ foo: 'foo' }, :key, :required, true, false)
    }
  end

  describe ':present' do
    it {
      test_validator({ key: 'foo' }, :key, :present, true, true)
      test_validator({ key: '' }, :key, :present, true, false)
      test_validator({ key: nil }, :key, :present, true, false)
      test_validator({ foo: 'foo' }, :key, :present, true, false)
    }
  end

  describe ':declared' do
    it {
      test_validator({ key: 'foo' }, :key, :declared, true, true)
      test_validator({ key: '' }, :key, :declared, true, true)
      test_validator({ key: nil }, :key, :declared, true, true)
      test_validator({ foo: 'foo' }, :key, :declared, false, true)
    }
  end

  describe ':options' do
    it {
      test_validator({ key: 'b' }, :key, :options, true, true, %w[a b c])
      test_validator({ key: 'd' }, :key, :options, true, false, %w[a b c])
      test_validator({ key: %w[c b] }, :key, :options, true, true, %w[a b c])
      test_validator({ key: %w[c b d] }, :key, :options, true, false, %w[a b c])
      test_validator({ foo: 'b' }, :key, :options, false, true, %w[a b c])
    }
  end

  describe ':array' do
    it {
      test_validator({ key: %w[a b] }, :key, :array, true, true)
      test_validator({ key: [] }, :key, :array, true, true)
      test_validator({ key: nil }, :key, :array, true, false)
      test_validator({ key: 'hello' }, :key, :array, true, false)
      test_validator({ key: 123 }, :key, :array, true, false)
      test_validator({ foo: [] }, :key, :array, true, true)
    }
  end

  describe ':object' do
    it {
      test_validator({ key: { 'a' => 'b' } }, :key, :object, true, true)
      test_validator({ key: {} }, :key, :object, true, true)
      test_validator({ key: %w[a b] }, :key, :object, true, false)
      test_validator({ key: nil }, :key, :object, true, false)
      test_validator({ key: 123 }, :key, :object, true, false)
      test_validator({ foo: {} }, :key, :object, true, true)
    }
  end
end
