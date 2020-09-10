# Documentation Generation

A `Schema` instance has a `#structure` method that return `Paradocs::Extensions::Structure` instance that allows instrospecting schema meta data.

It's supposed to have the following schema:
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

## Structure#nested
> This method returns schema structure in a nested way including subschemes.
```ruby
schema.structure.nested.to_json # =>
{
  "_errors": ["ArgumentError"],
  "_subschemes": {},
  "data": {
    "type": "object",
    "required": true,
    "present": true,
    "json_path": "$.data",
    "nested_name": "data",
    "structure": {
      "_subschemes": {
        "subschema": {
          "_errors": [],
          "_subschemes": {},
          "test_field": {
            "required": true,
            "present": true,
            "json_path": "$.data.test_field",
            "nested_name": "data.test_field"
          }
        },
        "test_subschema": {
          "_errors": [],
          "_subschemes": {},
          "test1": {
            "required": true,
            "present": true,
            "json_path": "$.data.test1",
            "nested_name": "data.test1"
          }
        }
      },
      "id": {
        "type": "integer",
        "required": true,
        "present": true,
        "policy_with_error": {"errors": ["ArgumentError"]},
        "json_path": "$.data.id",
        "nested_name": "data.id"
      },
      "name": {
        "type": "string",
        "label": "very important staff",
        "json_path": "$.data.name",
        "mutates_schema": true,
        "nested_name": "data.name"
      },
      "role": {
        "type": "string",
        "options": ["admin", "user"],
        "default": "user",
        "json_path": "$.data.role",
        "mutates_schema": true,
        "nested_name": "data.role"
      },
      "extra": {
        "type": "array",
        "required": true,
        "json_path": "$.data.extra[]",
        "nested_name": "data.extra",
        "structure": {
          "_subschemes": {},
          "extra": {
            "default": false,
            "policy_with_silent_error": {"errors": []},
            "json_path": "$.data.extra[].extra",
            "nested_name": "data.extra.extra"
          }
        }
      }
    }
  }
}
```

## Structure#flatten
> This method returns schema structure in a flatten (without deep nesting) way including subschemes.
```rb
schema.structure.flatten.to_json # =>
{
  "_errors": ["ArgumentError"],
  "_subschemes": {
    "subschema": {
      "_errors": [],
      "_subschemes": {},
      "data.test_field": {
        "required": true,
        "present": true,
        "json_path": "$.data.test_field"
      }
    },
    "test_subschema": {
      "_errors": [],
      "_subschemes": {},
      "data.test1": {
        "required": true,
        "present": true,
        "json_path": "$.data.test1"
      }
    }
  },
  "data": {
    "type": "object",
    "required": true,
    "present": true,
    "json_path": "$.data"
  },
  "data.id": {
    "type": "integer",
    "required": true,
    "present": true,
    "policy_with_error": {"errors": ["ArgumentError"]},
    "json_path": "$.data.id"
  },
  "data.name": {
    "type": "string",
    "label": "very important staff",
    "json_path": "$.data.name",
    "mutates_schema": true
  },
  "data.role": {
    "type": "string",
    "options": ["admin", "user"],
    "default": "user",
    "json_path": "$.data.role",
    "mutates_schema": true
  },
  "data.extra": {
    "type": "array",
    "required": true,
    "json_path": "$.data.extra[]"
  },
  "data.extra.extra": {
    "default": false,
    "policy_with_silent_error": {"errors": []},
    "json_path": "$.data.extra[].extra"
  }
}
```


## Structure#all_nested

> This method returns all available combinations of schema (built on subschemas) saving the nesting.

Will return a hash with 2 structures named by the names of declared subschemas:
```rb
all_nested = schema.structure.all_nested
all_nested.keys # => [:subschema, :test_subschema]
all_nested[:subschema] # =>
{
  _errors: [],
  "data" => {
    type:      :object,
    required:  true,
    present:   true,
    json_path: "$.data",
		nested_name: "data",
    structure: {
      "role"       => {type: :string, options: ["admin", "user"], default: "user", json_path: "$.data.role", mutates_schema: true, nested_name: "data.role"},
      "test_field" => {required: true, present: true, json_path: "$.data.test_field", nested_name: "data.test_field"},
      "id"         => {type: :integer, required: true, present: true, policy_with_error: {errors: [ArgumentError]}, json_path: "$.data.id", nested_name: "data.id"},
      "name"       => {type: :string, label: "very important staff", json_path: "$.data.name", mutates_schema: true, nested_name: "data.name"},
      "extra"      => {
        type: :array, required: true, json_path: "$.data.extra[]", nested_name: "data.extra",
        structure: {"extra" => {default: false, policy_with_silent_error: {errors: []}, json_path: "$.data.extra[].extra", nested_name: "data.extra.extra"}}
      }
    }
  }
}
all_nested[:test_subschema] # =>
{
  _errors:     [],
  "data" => {
    type:      :object,
    required:  true,
    present:   true,
    json_path: "$.data",
		nested_name: "data",
    structure: {
      "role"  => {type: :string, options: ["admin", "user"], default: "user", json_path: "$.data.role", mutates_schema: true, nested_name: "data.role"},
      "test1" => {required: true, present: true, json_path: "$.data.test1", nested_name: "data.test1"},
      "id"    => {type: :integer, required: true, present: true, policy_with_error: {errors: [ArgumentError]}, json_path: "$.data.id", nested_name: "data.id"},
      "name"  => {type: :string, label: "very important staff", json_path: "$.data.name", mutates_schema: true, nested_name: "data.name"},
      "extra" => {
        type: :array, required: true, json_path: "$.data.extra[]", nested_name: "data.extra",
        structure: {"extra" => {default: false, policy_with_silent_error: {errors: []}, json_path: "$.data.extra[].extra", nested_name: "data.extra.extra"}}
      }
    }
  }
}
```

## Structure#all_flatten
> This method returns all available combinations of schema (built on subschema) without nesting (the same way as Structure#flatten method does)

Schema is the same as described in `Structure#all_nested`
```rb
schema.structure.all_flatten # =>
{
  subschema: {
    _errors: [],
    "data"             => {type: :object, required: true, present: true, json_path: "$.data", nested_name: "data"},
    "data.id"          => {type: :integer, required: true, present: true, policy_with_error: {errors: [ArgumentError]}, json_path: "$.data.id", nested_name: "data.id"},
    "data.name"        => {type: :string, label: "very important staff", json_path: "$.data.name", mutates_schema: true, nested_name: "data.name"},
    "data.role"        => {type: :string, options: ["admin", "user"], default: "user", json_path: "$.data.role", mutates_schema: true, nested_name: "data.role"},
    "data.extra"       => {type: :array, required: true, json_path: "$.data.extra[]", nested_name: "data.extra"},
    "data.extra.extra" => {default: false, policy_with_silent_error: {errors: []}, json_path: "$.data.extra[].extra", nested_name: "data.extra.extra"},
    "data.test_field"  => {required: true, present: true, json_path: "$.data.test_field", nested_name: "data.test_field"}
  },
  test_subschema: {
    _errors: [],
    "data"             => {type: :object, required: true, present: true, json_path: "$.data", nested_name: "data"},
    "data.id"          => {type: :integer, required: true, present: true, policy_with_error: {errors: [ArgumentError]}, json_path: "$.data.id", nested_name: "data.id"},
    "data.name"        => {type: :string, label: "very important staff", json_path: "$.data.name", mutates_schema: true, nested_name: "data.name"},
    "data.role"        => {type: :string, options: ["admin", "user"], default: "user", json_path: "$.data.role", mutates_schema: true, nested_name: "data.role"},
    "data.extra"       => {type: :array, required: true, json_path: "$.data.extra[]", nested_name: "data.extra"},
    "data.extra.extra" => {default: false, policy_with_silent_error: {errors: []}, json_path: "$.data.extra[].extra", nested_name: "data.extra.extra"},
    "data.test1"       => {required: true, present: true, json_path: "$.data.test1", nested_name: "data.test1"}
  }
}
```

## Passing a block
Given block to the methods above (`#flatten`, `#nested`, `#all_flatten`, `#all_nested`) will be executed for
each field, passing you as arguments `field.key` and `field.meta`. Mutating the second argument `field.meta`
will reflect onto returned `meta`.

## Schema#walk

The `#walk` method can recursively walk a schema definition and extract meta data or field attributes.

```ruby
schema_documentation = create_user_schema.walk do |field|
  {type: field.meta_data[:type], label: field.meta_data[:label]}
end.output

# Returns

{
  name: {type: :string, label: "User's full name"},
  age: {type: :integer, label: "User's age"},
  status: {type: :string, label: nil},
  friends: [
    {
      name: {type: :string, label: "Friend full name"},
      email: {type: nil, label: "Friend email"}
    }
  ]
}
```

When passed a _symbol_, it will collect that key from field meta data.

```ruby
schema_labels = create_user_schema.walk(:label).output

# returns

{
  name: "User's full name",
  age: "User's age",
  status: nil,
  friends: [
    {name: "Friend full name", email: "Friend email"}
  ]
}
```

Potential uses for this are generating documentation (HTML, or [JSON Schema](http://json-schema.org/), [Swagger](http://swagger.io/), or maybe even mock API endpoints with example data.

