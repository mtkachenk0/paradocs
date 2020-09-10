# Documentation Generation
## #structure

A `Schema` instance has a `#structure` method that allows instrospecting schema meta data.

```ruby
create_user_schema.structure[:name][:label] # => "User's full name"
create_user_schema.structure[:age][:label] # => "User's age"
create_user_schema.structure[:friends][:label] # => "User friends"
# Recursive schema structures
create_user_schema.structure => {
  _errors: [],
  _subschemes: {},
  name: {
    required: true,
    type: :string,
    label: "User's full name"
  },
  status: {
    options: ["published", "unpublished"],
    default: "published"
  },
  age: {
    type: :integer,
    label: "User's age"
  },
  friends: {
    type: :array,
    label: "User friends",
    structure: {
      _subschemes: {},
      name: {
        type: :string,
        required: true,
        present: true,
        label: "Friend full name"
      },
      email: {label: "Friend's email"}
    }
  }
}
```

Note that many field policies add field meta data.

```ruby
create_user_schema.structure[:name][:type] # => :string
create_user_schema.structure[:name][:required] # => true
create_user_schema.structure[:status][:options] # => ["published", "unpublished"]
create_user_schema.structure[:status][:default] # => "published"
```


# #flatten_structure
 A `Schema` instance also has a `#flatten_structure` method that allows instrospecting schema meta data without deep nesting.
```rb
{
  _errors: [],
  _subschemes: {},
  "name"=>{
    required: true,
    type: :string,
    label: "User's full name",
    json_path: "$.name"
  },
  "status"=>{
    options: ["published", "unpublished"],
    default: "published",
    json_path: "$.status"
  },
  "age"=>{
    type: :integer,
    label: "User's age", :json_path=>"$.age"
  },
  "friends"=>{
    type: :array,
    label: "User friends",
    json_path: "$.friends"
  },
  "friends.name"=>{
    type: :string,
    required: true,
    present: true,
    label: "Friend full name",
    json_path: "$.friends.name"
  },
  "friends.email"=>{
    label: "Friend's email",
    json_path: "$.friends.email"
  }
}
```

## #walk

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

