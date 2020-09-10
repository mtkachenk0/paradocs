# Payload Builder

> Schema instance provides #example_payloads method that returns example of all possible structures.

NOTE: PayloadBuilder sets nil values by default. If options are given - builder will take on of them, if default is set - builder will use it.
> PayloadBuilder#build! method takes a block as argument that may help you adding your custom rules.

#### Example schema
```ruby
schema = Paradocs::Schema.new do
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
```

## Generate payloads

```rb
Paradocs::Extensions::PayloadBuilder.new(schema).build! # =>
# or
schema.example_payloads.to_json # =>
{
  "subschema": {
    "data": {
      "name": null,
      "role": "user",
      "extra": [{"extra": null}],
      "test_field": null,
      "id": null
    }
  },
  "test_subschema": {
    "data": {
      "name": null,
      "role": "user",
      "extra": [{"extra": null}],
      "test1": null,
      "id": null
    }
  }
}
```

## Customize payload generation logic
PayloadBuilder#build! allows passing a block that will receive the following arguments:

- key: Field name
- meta: Field meta data (that includes (if provided) field types, presence data, policies and other meta data
- example_value: Provided by generator example value.
- skip_word: Return this argument back if you want this item to be ommitted.

```rb
block = Proc.new do |key, meta, example, skip_word|
  if key.to_s == "name"
    "John Smith"
  elsif meta[:type] == :integer
    13
  elsif key.to_s.match? /test/
    skip_word
  else
    example
  end
end
schema.example_payloads(&block) # =>
# or
Paradocs::Extensions::PayloadBuilder.new(schema).build!(&block) # =>
{
  "subschema": {
    "data": {
      "name": "John Smith", # value is changed
      "role": "user", # random choice from field(:user).options
      "extra": [{"extra": null}], # null are defaults
      "id": 13 # value is changed
      # NOTE: fields matching with /test/ are ommitted: test_field, test1
    }
  },
  "test_subschema": {
    "data": {
      "name": "John Smith",
      "role": "user",
      "extra": [{"extra": null}],
      "id": 13
    }
  }
}

```
