require 'spec_helper'

describe Paradocs::Schema do
  before do
    Paradocs.policy :flexible_bool do
      coerce do |v, _k, _c|
        case v
        when '1', 'true', 'TRUE', true
          true
        else
          false
        end
      end
    end
  end

  subject do
    described_class.new do
      field(:title).policy(:string).present.as(:article_title)
      field(:price).policy(:integer).meta(label: 'A price')
      field(:status).policy(:string).options(%w[visible hidden])
      field(:tags).policy(:split).policy(:array)
      field(:description).policy(:string)
      field(:variants).policy(:array).schema do
        field(:name).policy(:string).present
        field(:sku)
        field(:stock).policy(:integer).default(1)
        field(:available_if_no_stock).policy(:boolean).policy(:flexible_bool).default(false)
      end
    end
  end

  describe '#structure' do
    it 'represents data structure and meta data' do
      sc = subject.structure.nested
      expect(sc[:article_title][:present]).to be true
      expect(sc[:article_title][:type]).to eq :string
      expect(sc[:price][:type]).to eq :integer
      expect(sc[:price][:label]).to eq 'A price'
      expect(sc[:variants][:type]).to eq :array
      sc[:variants][:structure].tap do |sc|
        expect(sc[:name][:type]).to eq :string
        expect(sc[:name][:present]).to be true
        expect(sc[:stock][:default]).to eq 1
      end
    end
  end

  def resolve(schema, payload)
    yield schema.resolve(payload)
  end

  def test_schema(schema, payload, result)
    resolve(schema, payload) do |results|
      expect(results.output).to eq result
    end
  end

  it "order input by schema fields' keys order" do
    payload = {
      tags: 'tag',
      status: 'visible',
      extra_field: 'extra',
      price: '100',
      title: 'title',
      variants: [
        {
          stock: '10',
          available_if_no_stock: true,
          extra_field: 'extra',
          name: 'v1',
          sku: 'ABC'
        }
      ]
    }

    output = subject.resolve(payload).output
    expect(output).to eq({
                           article_title: 'title',
                           price: 100,
                           status: 'visible',
                           tags: ['tag'],
                           variants: [
                             {
                               name: 'v1',
                               sku: 'ABC',
                               stock: 10,
                               available_if_no_stock: true
                             }
                           ]
                         })
  end

  it 'works' do
    test_schema(subject, {
                  title: 'iPhone 6 Plus',
                  price: '100.0',
                  status: 'visible',
                  tags: 'tag1, tag2',
                  description: 'A description',
                  variants: [{ name: 'v1', sku: 'ABC', stock: '10', available_if_no_stock: true }]
                },
                {
                  article_title: 'iPhone 6 Plus',
                  price: 100,
                  status: 'visible',
                  tags: %w[tag1 tag2],
                  description: 'A description',
                  variants: [{ name: 'v1', sku: 'ABC', stock: 10, available_if_no_stock: true }]
                })

    test_schema(subject, {
                  title: 'iPhone 6 Plus',
                  variants: [{ name: 'v1', available_if_no_stock: '1' }]
                },
                {
                  article_title: 'iPhone 6 Plus',
                  variants: [{ name: 'v1', stock: 1, available_if_no_stock: true }]
                })

    resolve(subject, {}) do |results|
      expect(results.valid?).to be false
      expect(results.errors['$.title']).not_to be_nil
      expect(results.errors['$.variants']).to be_nil
      expect(results.errors['$.status']).to be_nil
    end

    resolve(subject, { title: 'Foobar', variants: [{ name: 'v1' }, { sku: '345' }] }) do |results|
      expect(results.valid?).to be false
      expect(results.errors['$.variants[1].name']).not_to be_nil
    end
  end

  it 'ignores nil fields if using :declared policy' do
    schema = described_class.new do
      field(:id).type(:integer)
      field(:title).declared.type(:string)
    end

    resolve(schema, { id: 123 }) do |results|
      expect(results.output.keys).to eq [:id]
    end
  end

  describe '#policy' do
    it 'applies policy to all fields' do
      subject.policy(:declared)

      resolve(subject, {}) do |results|
        expect(results.valid?).to be true
        expect(results.errors.keys).to be_empty
      end
    end

    it 'replaces previous policies' do
      subject.policy(:declared)
      subject.policy(:present)

      resolve(subject, { title: 'hello' }) do |results|
        expect(results.valid?).to be false
        expect(results.errors.keys).to match_array(%w[
                                                     $.price
                                                     $.status
                                                     $.tags
                                                     $.description
                                                     $.variants
                                                   ])
      end
    end

    it 'applies :noop policy to all fields' do
      subject.policy(:noop)

      resolve(subject, {}) do |results|
        expect(results.valid?).to be false
        expect(results.errors['$.title']).not_to be_nil
      end
    end
  end

  describe '#merge' do
    context 'no options' do
      let!(:schema1) do
        described_class.new do
          field(:title).policy(:string).present
          field(:price).policy(:integer)
        end
      end

      let!(:schema2) do
        described_class.new do
          field(:price).policy(:string)
          field(:description).policy(:string)
        end
      end

      it 'returns a new schema adding new fields and updating existing ones' do
        new_schema = schema1.merge(schema2)
        expect(new_schema.fields.keys).to match_array(%i[title price description])

        # did not mutate original
        expect(schema1.fields[:price].meta_data[:type]).to eq :integer

        expect(new_schema.fields[:title].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
      end
    end

    context 'with options' do
      let!(:schema1) do
        described_class.new(price_type: :integer, label: 'Foo') do |opts|
          field(:title).policy(:string).present
          field(:price).policy(opts[:price_type]).meta(label: opts[:label])
        end
      end

      let!(:schema2) do
        described_class.new(price_type: :string) do
          field(:description).policy(:string)
        end
      end

      it 'inherits options' do
        new_schema = schema1.merge(schema2)
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:label]).to eq 'Foo'
      end

      it 're-applies blocks with new options' do
        new_schema = schema1.merge(schema2)
        expect(new_schema.fields.keys).to match_array(%i[title price description])

        # did not mutate original
        expect(schema1.fields[:price].meta_data[:type]).to eq :integer

        expect(new_schema.fields[:title].meta_data[:type]).to eq :string
        expect(new_schema.fields[:price].meta_data[:type]).to eq :string
      end
    end
  end

  describe '#clone' do
    let!(:schema1) do
      described_class.new do |_opts|
        field(:id).present
        field(:title).policy(:string).present
        field(:price)
      end
    end

    it 'returns a copy that can be further manipulated' do
      schema2 = schema1.clone.policy(:declared).ignore(:id)
      expect(schema1.fields.keys).to match_array(%i[id title price])
      expect(schema2.fields.keys).to match_array(%i[title price])

      results1 = schema1.resolve(id: 'abc', price: 100)
      expect(results1.errors.keys).to eq ['$.title']

      results2 = schema2.resolve(id: 'abc', price: 100)
      expect(results2.errors.keys).to eq []
    end
  end

  describe '#ignore' do
    it 'ignores fields' do
      s1 = described_class.new.ignore(:title, :status) do
        field(:status)
        field(:title).policy(:string).present
        field(:price).policy(:integer)
      end

      output = s1.resolve(status: 'draft', title: 'foo', price: '100').output
      expect(output).to eq({ price: 100 })
    end

    it 'ignores when merging' do
      s1 = described_class.new do
        field(:status)
        field(:title).policy(:string).present
      end

      s1 = described_class.new.ignore(:title, :status) do
        field(:price).policy(:integer)
      end

      output = s1.resolve(title: 'foo', status: 'draft', price: '100').output
      expect(output).to eq({ price: 100 })
    end

    it 'returns self so it can be chained' do
      s1 = described_class.new do
        field(:status)
        field(:title).policy(:string).present
      end

      expect(s1.ignore(:status)).to eq s1
    end
  end
end
