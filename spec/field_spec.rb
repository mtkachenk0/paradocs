require 'spec_helper'

describe Paradocs::Field do
  let(:context) { Paradocs::Context.new }

  subject { described_class.new(:a_key) }

  def register_coercion(name, block)
    Paradocs.registry.policy name do
      coerce(&block)
    end
  end

  def resolve(subject, payload)
    subject.resolve(payload, context)
  end

  def has_errors
    expect(context.errors.keys).not_to be_empty
  end

  def no_errors
    expect(context.errors.keys).to be_empty
  end

  def has_error(key, message)
    expect(context.errors[key]).to include(message)
  end

  let(:payload) { { a_key: 'Joe' } }

  describe '#resolve' do
    it 'returns value' do
      resolve(subject, payload).tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'Joe'
      end
    end
  end

  BUILT_IN_COERCIONS = %i[string integer number array object boolean].freeze

  describe '#meta_data' do
    BUILT_IN_COERCIONS.each do |t|
      it "policy #{t} adds #{t} to meta data" do
        subject.policy(t)
        expect(subject.meta_data[:type]).to eq t
      end
    end
  end

  describe '#type' do
    it 'is an alias for #policy' do
      subject.type(:integer)
      resolve(subject, a_key: '10.0').tap do |r|
        expect(r.value).to eq 10
      end
    end
  end

  describe '#policy' do
    it 'coerces integer' do
      subject.policy(:integer)
      resolve(subject, a_key: '10.0').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 10
      end
    end

    it 'coerces number' do
      subject.policy(:number)
      resolve(subject, a_key: '10.0').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 10.0
      end
    end

    it 'coerces string' do
      subject.policy(:string)
      resolve(subject, a_key: 10.0).tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq '10.0'
      end
    end
  end

  describe '#default' do
    it 'is default if missing key' do
      resolve(subject.default('AA'), foobar: 1).tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'AA'
      end
    end

    it 'returns value if key is present' do
      resolve(subject.default('AA'), a_key: nil).tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq nil
      end

      resolve(subject.default('AA'), a_key: 'abc').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'abc'
      end
    end
  end

  describe '#present' do
    it 'is valid if value is present' do
      resolve(subject.present, a_key: 'abc').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'abc'
      end
    end

    it 'is invalid if value is empty' do
      resolve(subject.present, a_key: '').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq ''
      end

      resolve(subject.present, a_key: nil).tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq nil
      end
    end

    it 'is invalid if key is missing' do
      resolve(subject.present, foo: 'abc').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq nil
      end
    end
  end

  describe '#required' do
    it 'is valid if key is present' do
      resolve(subject.required, a_key: 'abc').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'abc'
      end
    end

    it 'is valid if key is present and value empty' do
      resolve(subject.required, a_key: '').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq ''
      end
    end

    it 'is invalid if key is missing' do
      resolve(subject.required, foobar: 'lala').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq nil
      end
    end
  end

  describe '#options' do
    before do
      subject.options(%w[a b c])
    end

    it 'resolves if value within options' do
      resolve(subject, a_key: 'b').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'b'
      end
    end

    it 'resolves if value is array within options' do
      resolve(subject, a_key: %w[b c]).tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq %w[b c]
      end
    end

    it 'does not resolve if missing key' do
      resolve(subject, foobar: %w[b c]).tap do |r|
        expect(r.eligible?).to be false
        no_errors
        expect(r.value).to be_nil
      end
    end

    it 'does resolve if missing key and default set' do
      subject.default('Foobar')
      resolve(subject, foobar: %w[b c]).tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq 'Foobar'
      end
    end

    it 'is invalid if missing key and required' do
      subject = described_class.new(:a_key).required.options(%w[a b c])
      resolve(subject, foobar: %w[b c]).tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to be_nil
      end
    end

    it 'is invalid if value outside options' do
      resolve(subject, a_key: 'x').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq 'x'
      end

      resolve(subject, a_key: %w[x b]).tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq %w[x b]
      end
    end
  end

  describe ':split policy' do
    it 'splits by comma' do
      resolve(subject.policy(:split), a_key: 'tag1,tag2').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq %w[tag1 tag2]
      end
    end
  end

  describe ':declared policy' do
    it 'is eligible if key exists' do
      resolve(subject.policy(:declared).present, a_key: '').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq ''
      end
    end

    it 'is available as method' do
      resolve(subject.declared.present, a_key: '').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq ''
      end
    end

    it 'is not eligible if key does not exist' do
      resolve(subject.policy(:declared).present, foo: '').tap do |r|
        expect(r.eligible?).to be false
        no_errors
        expect(r.value).to eq nil
      end
    end
  end

  describe ':noop policy' do
    it 'does not do anything' do
      resolve(subject.policy(:noop).present, a_key: '').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq ''
      end

      resolve(subject.policy(:noop).present, foo: '').tap do |r|
        expect(r.eligible?).to be true
        has_errors
        expect(r.value).to eq nil
      end
    end
  end

  describe '#schema' do
    it 'runs sub-schema' do
      subject.schema do
        field(:name).policy(:string)
        field(:tags).policy(:split).policy(:array)
      end

      payload = { a_key: [{ name: 'n1', tags: 't1,t2' }, { name: 'n2', tags: ['t3'] }] }

      resolve(subject, payload).tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq([
                                { name: 'n1', tags: %w[t1 t2] },
                                { name: 'n2', tags: ['t3'] }
                              ])
      end
    end
  end

  describe '#policy' do
    let(:custom_klass) do
      Class.new do
        def initialize(title = 'Sr.')
          @title = title
        end

        def eligible?(*_)
          true
        end

        def valid?(*_)
          true
        end

        def coerce(value, _key, _context)
          "#{@title} #{value}"
        end

        def meta_data
          { foo: 'bar' }
        end

        def policy_name
          :custom_policy
        end
      end
    end

    it 'works with policy in registry' do
      register_coercion :foo, ->(v, _k, _c) { "Hello #{v}" }
      subject.policy(:foo)
      resolve(subject, a_key: 'Ismael').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'Hello Ismael'
      end
    end

    it 'raises if policy not found' do
      expect do
        subject.policy(:foobar)
      end.to raise_exception Paradocs::ConfigurationError
    end

    it 'chains policies' do
      Paradocs.registry.policy :general, custom_klass.new('General')
      Paradocs.registry.policy :commander, custom_klass.new('Commander')

      subject
        .policy(:general)
        .policy(:commander)

      resolve(subject, a_key: 'Ismael').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'Commander General Ismael'
      end
    end

    it 'can instantiate policy class and pass arguments' do
      Paradocs.registry.policy :job_title, custom_klass

      subject.policy(:job_title, 'Developer')

      resolve(subject, a_key: 'Ismael').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'Developer Ismael'
      end
    end

    it 'can take a class not in the registry' do
      subject.policy(custom_klass, 'Developer')

      resolve(subject, a_key: 'Ismael').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'Developer Ismael'
      end
    end

    it 'adds policy meta data' do
      subject.policy(custom_klass, 'Developer')
      expect(subject.meta_data[:foo]).to eq 'bar'
    end

    it 'can take an instance not in the registry' do
      subject.policy(custom_klass.new('Developer'), 'ignore this')

      resolve(subject, a_key: 'Ismael').tap do |r|
        expect(r.eligible?).to be true
        no_errors
        expect(r.value).to eq 'Developer Ismael'
      end
    end

    it 'add policy message to #errors if validation fails' do
      register_coercion :error, ->(_v, _k, _c) { raise 'This is an error' }

      subject.policy(:error)

      resolve(subject, a_key: 'b').tap do |r|
        expect(r.eligible?).to be true
        has_error('$', 'is invalid')
        expect(r.value).to eq 'b'
      end
    end
  end
end
