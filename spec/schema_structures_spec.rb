require 'spec_helper'

describe "Schema structures generation" do
  Paradocs.policy :policy_with_error do
    register_error ArgumentError

    validate do |*|
      raise ArgumentError
    end
  end

  Paradocs.policy :policy_with_silent_error do
    register_silent_error RuntimeError
  end

  let(:schema) do
    Paradocs::Schema.new do
      subschema(:highest_level) { field(:test).present } # no mutations on this level -> subschema ignored

      field(:data).type(:object).present.schema do
        field(:id).type(:integer).present.policy(:policy_with_error)
        field(:name).type(:string).meta(label: "very important staff")
        field(:role).type(:string).declared.options(["admin", "user"]).default("user").mutates_schema! do |*|
          :test_subschema
        end
        field(:extra).type(:array).required.schema do
          field(:extra).declared.default(false).policy(:policy_with_silent_error)
        end

        mutation_by!(:name) { :subschema }

        subschema(:subschema) do
          field(:test_field).present
        end
        subschema(:test_subschema) do
          field(:test1).present
        end
      end
    end
  end


  it "generates nested data for documentation generation" do
    result = schema.structure { |k, meta| meta[:block_works] = true unless meta[:present] }
    expect(result[:_subschemes]).to eq({})
    expect(result[:_errors]).to eq([ArgumentError])
    data_structure = result[:data].delete(:structure)
    expect(result[:data]).to eq({
      type: :object,
      required: true,
      present: true,
      json_path: "$.data",
      nested_name: "data",
    })
    expect(data_structure[:_subschemes]).to eq({
      test_subschema: {
        _errors: [],
        _subschemes: {},
        test1: {required: true, present: true, json_path: "$.data.test1", nested_name: "data.test1"}
      },
      subschema: {
        _errors: [],
        _subschemes: {},
        test_field: {required: true, present: true, json_path: "$.data.test_field", nested_name: "data.test_field"}
      }
    })
    expect(data_structure[:id]).to eq({
      type: :integer,
      required: true,
      present: true,
      policy_with_error: {errors: [ArgumentError]},
      json_path: "$.data.id",
      nested_name: "data.id"
    })
    expect(data_structure[:name]).to eq({
      type: :string,
      label: "very important staff",
      mutates_schema: true,
      block_works: true,
      json_path: "$.data.name",
      nested_name: "data.name"
    })
    expect(data_structure[:role]).to eq({
      type: :string,
      options: ["admin", "user"],
      default: "user",
      mutates_schema: true,
      block_works: true,
      json_path: "$.data.role",
      nested_name: "data.role"
    })
    expect(data_structure[:extra]).to eq({
      type: :array,
      required: true,
      block_works: true,
      json_path: "$.data.extra[]",
      nested_name: "data.extra",
      structure: {
        extra: {
          default: false,
          block_works: true,
          json_path: "$.data.extra[].extra",
          nested_name: "data.extra.extra",
          policy_with_silent_error: {errors: []}
        },
        _subschemes: {}
      }
    })
  end

  it "generates flatten data for documentation generation" do
    expect(schema.flatten_structure { |key, meta| meta[:block_works] = true if key.split(".").size == 1 }).to eq({
      "data" => {
        type: :object,
        required: true,
        present: true,
        block_works: true,
        json_path: "$.data"
      },
      "data.extra" => {
        type: :array,
        required: true,
        json_path: "$.data.extra[]"
      },
      "data.extra.extra" => {
        default: false,
        json_path: "$.data.extra[].extra",
        policy_with_silent_error: {errors: []}
      },
      "data.id" => {
        type: :integer,
        required: true,
        present: true,
        json_path: "$.data.id",
        policy_with_error: {errors: [ArgumentError]}
      },
      "data.name" => {
        type: :string,
        json_path: "$.data.name",
        label: "very important staff",
        mutates_schema: true
      },
      "data.role" => {
        type: :string,
        options: ["admin", "user"],
        default: "user",
        json_path: "$.data.role",
        mutates_schema: true
      },
      _errors: [ArgumentError],
      _subschemes: {
        test_subschema: {
          _errors: [],
          _subschemes: {},
          "data.test1"=>{
            required: true,
            present: true,
            json_path: "$.data.test1"
          }
        },
        subschema: {
          _errors: [],
          _subschemes: {},
          "data.test_field" => {required: true, present: true, json_path: "$.data.test_field"}
        }
      }
    })
  end
end
