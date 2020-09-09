require "spec_helper"

describe Paradocs::Extensions::PayloadBuilder do
  let(:schema) do
    Paradocs::Schema.new do
      field(:test).present.type(:string).mutates_schema! { :subschema1 }
      subschema(:subschema1) do
        field(:subtest1).declared.type(:number)
      end
      subschema(:subschema2) do
        field(:subtest2).required.type(:array).schema do
          field(:hello).type(:string).mutates_schema! { |*| :deep_schema }
          subschema(:deep_schema) { field(:deep_field).type(:boolean) }
          subschema(:empty) { }
        end
      end
      # 2 mutation fields and more than 1 subschema pack work good in validation but docs
      # will contain only 1 subschema at once: foo subschemes will never be mixed with test subschemes
      field(:foo).required.type(:object).schema do
        field(:bar).present.type(:string).options(["foo", "bar"]).mutates_schema! do |value, *|
          value == "foo" ? :fooschema : :barschema
        end
        subschema(:fooschema) { }
        subschema(:barschema) do
          field(:barfield).present.type(:boolean)
        end
      end
    end
  end

  it "gives an example payload and takes into account the subschemes" do
    allow_any_instance_of(Array).to receive(:sample) { "bar" }
    payloads = described_class.new(schema).build!
    expect(payloads.keys.sort).to eq([:barschema, :fooschema, :subschema1, :subschema2_deep_schema, :subschema2_empty])
    expect(payloads[:barschema]).to eq({"test" => nil, "foo" => {"bar" => "bar", "barfield" => nil}})
    expect(payloads[:fooschema]).to eq({"test" => nil, "foo" => {"bar" => "bar"}})
    expect(payloads[:subschema1]).to eq({"test" => nil, "foo"  => {"bar" => "bar"}, "subtest1" => nil})
    expect(payloads[:subschema2_deep_schema]).to eq({
      "subtest2" => [{"deep_field" => nil, "hello" => nil}], "test" => nil, "foo" => {"bar" => "bar"}
    })
    expect(payloads[:subschema2_empty]).to eq({
      "test" => nil, "foo" => {"bar" => "bar"}, "subtest2" => [{"hello" => nil}]
    })
  end

  it "yields a usefull block that changes the result" do
    payloads = described_class.new(schema).build! do |key, meta, example, skip_word|
      if key == "bar"
        nil
      elsif meta[:type] == :boolean
        true
      elsif key == "subtest1"
        skip_word # this key value pair will be ommited
      else
        example # return suggested value
      end
    end

    expect(payloads.keys.sort).to eq([:barschema, :fooschema, :subschema1, :subschema2_deep_schema, :subschema2_empty])
    expect(payloads[:barschema]).to eq({"test" => nil, "foo" => {"bar" => nil, "barfield" => true}}) # barfield is change to true and bar is nil
    expect(payloads[:fooschema]).to eq({"test" => nil, "foo" => {"bar" => nil}}) # bar is nil
    expect(payloads[:subschema1]).to eq({"test" => nil, "foo"  => {"bar" => nil}}) # subtest is missing, bar is nil
    expect(payloads[:subschema2_deep_schema]).to eq({
      "subtest2" => [{"deep_field" => true, "hello" => nil}], "test" => nil, "foo" => {"bar" => nil}
    })
    expect(payloads[:subschema2_empty]).to eq({
      "test" => nil, "foo" => {"bar" => nil}, "subtest2" => [{"hello" => nil}]
    })
  end
end
