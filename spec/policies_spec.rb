require 'spec_helper'

describe 'default coercions' do
  def test_coercion(key, value, expected)
    coercion = Paradocs.registry.coercions[key]
    expect(coercion.new.coerce(value, nil, nil)).to eq expected
  end

  describe ':datetime' do
    it {
      coercion = Paradocs.registry.coercions[:datetime]
      coercion.new.coerce("2016-11-05T14:23:34Z", nil, nil).tap do |d|
        expect(d).to be_a Date
        expect(d.year).to eq 2016
        expect(d.month).to eq 11
        expect(d.day).to eq 5
        expect(d.hour).to eq 14
        expect(d.minute).to eq 23
        expect(d.second).to eq 34
        expect(d.zone).to eq "+00:00"
      end
    }
  end

  describe ':integer' do
    it {
      test_coercion(:integer, '10', 10)
      test_coercion(:integer, '10.20', 10)
      test_coercion(:integer, 10.20, 10)
      test_coercion(:integer, 10, 10)
    }
  end

  describe ':number' do
    it {
      test_coercion(:number, '10', 10.0)
      test_coercion(:number, '10.20', 10.20)
      test_coercion(:number, 10.20, 10.20)
      test_coercion(:number, 10, 10.0)
    }
  end

  describe ':string' do
    it {
      test_coercion(:string, '10', '10')
      test_coercion(:string, '10.20', '10.20')
      test_coercion(:string, 10.20, '10.2')
      test_coercion(:string, 10, '10')
      test_coercion(:string, true, 'true')
      test_coercion(:string, 'hello', 'hello')
    }
  end

  describe ':boolean' do
    it {
      test_coercion(:boolean, true, true)
      test_coercion(:boolean, '10', true)
      test_coercion(:boolean, '', true)
      test_coercion(:boolean, nil, false)
      test_coercion(:boolean, false, false)
    }
  end

  describe ':split' do
    it {
      test_coercion(:split, 'aaa,bb,cc', ['aaa', 'bb', 'cc'])
      test_coercion(:split, 'aaa ,bb,  cc', ['aaa', 'bb', 'cc'])
      test_coercion(:split, 'aaa', ['aaa'])
      test_coercion(:split, ['aaa', 'bb', 'cc'], ['aaa', 'bb', 'cc'])
    }
  end

  describe ':gt' do
    it "passes the value if it's greater than policy param" do
      expected_policy_behavior(policy: :gt, policy_args: [3], input: {a: 4}, output: {a: 4})
    end

    it "raises error if value is greater to policy param" do
      errors  = {"$.a"=>["value must be strictly greater than 10"]}
      errors2 = {"$.a"=>["value must be strictly greater than 10"]}
      expected_policy_behavior(policy: :gt, policy_args: [10], input: {a: 4}, errors: errors)
      expected_policy_behavior(policy: :gt, policy_args: [10], input: {a: 10}, errors: errors2)
    end
  end

  describe ':gte' do
    it "passes the value if it's greater or equal to policy param" do
      expected_policy_behavior(policy: :gte, policy_args: [3], input: {a: 4}, output: {a: 4})
      expected_policy_behavior(policy: :gte, policy_args: [3], input: {a: 3}, output: {a: 3})
    end

    it "raises error if value is greater than policy param" do
      errors = {"$.a"=>["value must be greater than or equal to 10"]}
      expected_policy_behavior(policy: :gte, policy_args: [10], input: {a: 4}, errors: errors)
    end
  end

  describe ':lt' do
    it "passes the value if it's less to policy param" do
      expected_policy_behavior(policy: :lt, policy_args: [100], input: {a: 4}, output: {a: 4})
    end

    it "raises error if value is strictly less to policy param" do
      errors  = {"$.a"=>["value must be strictly less than 10"]}
      errors2 = {"$.a"=>["value must be strictly less than 10"]}
      expected_policy_behavior(policy: :lt, policy_args: [10], input: {a: 40}, errors: errors)
      expected_policy_behavior(policy: :lt, policy_args: [10], input: {a: 10}, errors: errors2)
    end
  end

  describe ':lte' do
    it "passes the value if it's less or equal to policy param" do
      expected_policy_behavior(policy: :lte, policy_args: [100], input: {a: 4}, output: {a: 4})
      expected_policy_behavior(policy: :lte, policy_args: [100], input: {a: 100}, output: {a: 100})
    end

    it "raises error if value is less or equal than policy param" do
      errors = {"$.a"=>["value must be less than or equal to 1"]}
      expected_policy_behavior(policy: :lte, policy_args: [1], input: {a: 40}, output: {a: 40}, errors: errors)
    end
  end
end
