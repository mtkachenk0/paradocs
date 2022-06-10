require 'spec_helper'
require 'paradocs/whitelist'
require 'paradocs/dsl'

describe 'classes including Whitelist module' do
  class TestWhitelist
    include Paradocs::DSL
    include Paradocs::Whitelist

    schema(:request) do
      field(:data).present.type(:array).schema do
        field(:id).present.type(:string).whitelisted
        field(:name).present.type(:string)
        field(:empty_array).type(:array).schema do
          field(:id).whitelisted
        end
        field(:subschema_1).whitelisted.mutates_schema! { |name, *| name.to_sym }
        field(:empty_hash).type(:array).schema do
          field(:id).whitelisted
        end
        field(:extra).schema do
          field(:id).present.type(:string).whitelisted
          field(:name).present.type(:string)
          field(:empty_string).present.type(:string)
        end

        subschema(:subfield_1) do
          field(:subfield_1).present.type(:boolean).whitelisted
          field(:subschema_2).mutates_schema! { |name, *| name.to_sym }

          subschema(:subfield_2) do
            field(:subfield_2).present.type(:boolean).whitelisted
          end
        end
      end
    end
  end

  describe '.filter!' do
    let(:schema) { TestWhitelist.schema(:request) }
    let(:input) do
      {
        'unexpected' => 'test',
        from_config: 'whitelisted',
        data: [
          'id' => 5,
          name: nil,
          unexpected: nil,
          empty_array: [],
          subschema_1: 'subfield_1',
          subfield_1: true,
          subschema_2: 'subfield_2',
          subfield_2: true,
          empty_hash: {},
          'extra' => {
            id: 6,
            name: 'name',
            unexpected: 'unexpected',
            empty_string: ''
          }
        ]
      }
    end

    before { Paradocs.config.whitelisted_keys = [:from_config] }

    it "should filter not whitelisted attributes with different key's type" do
      whitelisted = TestWhitelist.new.filter!(input, schema)

      expect(whitelisted).to eq(
        {
          unexpected: '[FILTERED]',
          from_config: 'whitelisted',
          data: [
            {
              id: 5,
              name: '[EMPTY]',
              unexpected: '[EMPTY]',
              empty_array: [],
              subschema_1: 'subfield_1',
              subfield_1: true,
              subschema_2: '[FILTERED]',
              subfield_2: true,
              empty_hash: {},
              extra: {
                id: 6,
                name: '[FILTERED]',
                unexpected: '[FILTERED]',
                empty_string: '[EMPTY]'
              }
            }
          ]
        }
      )
    end

    context 'when Paradocs.config.whitelist_coercion block is set' do
      before { Paradocs.config.whitelist_coercion = proc { |value, meta| meta[:type] != :string ? 'FILTER' : value.to_s } }

      it 'executes block for each value' do
        whitelisted = TestWhitelist.new.filter!(input, schema)
        expect(whitelisted).to eq(
          {
            unexpected: '[FILTERED]',
            from_config: 'FILTER',
            data: [
              {
                id: '5',
                name: '[EMPTY]',
                unexpected: '[EMPTY]',
                empty_array: [],
                subschema_1: 'FILTER',
                subfield_1: 'FILTER',
                subschema_2: '[FILTERED]',
                subfield_2: 'FILTER',
                empty_hash: {},
                extra: {
                  id: '6',
                  name: '[FILTERED]',
                  unexpected: '[FILTERED]',
                  empty_string: '[EMPTY]'
                }
              }
            ]
          }
        )
      end
    end
  end
end
