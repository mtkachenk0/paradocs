## Expanding fields dynamically

Sometimes you don't know the exact field names but you want to allow arbitrary fields depending on a given pattern.

```ruby
# with this payload:
# {
#   title: "A title",
#   :"custom_attr_Color" => "red",
#   :"custom_attr_Material" => "leather"
# }

schema = Paradocs::Schema.new do
  field(:title).type(:string).present
  # here we allow any field starting with /^custom_attr/
  # this yields a MatchData object to the block
  # where you can define a Field and validations on the fly
  # https://ruby-doc.org/core-2.2.0/MatchData.html
  expand(/^custom_attr_(.+)/) do |match|
    field(match[1]).type(:string).present
  end
end

results = schema.resolve({
  title: "A title",
  :"custom_attr_Color" => "red",
  :"custom_attr_Material" => "leather",
  :"custom_attr_Weight" => "",
})

results.ouput[:Color] # => "red"
results.ouput[:Material] # => "leather"
results.errors["$.Weight"] # => ["is required and value must be present"]
```

NOTES: dynamically expanded field names are not included in `Schema#structure` metadata, and they are only processes if fields with the given expressions are present in the payload. This means that validations applied to those fields only run if keys are present in the first place.


## Cloning schemas

The `#clone` method returns a new instance of a schema with all field definitions copied over.

```ruby
new_schema = original_schema.clone
```

New copies can be further manipulated without affecting the original.

```ruby
# See below for #policy and #ignore
new_schema = original_schema.clone.policy(:declared).ignore(:id) do |sc|
  field(:another_field).present
end
```

## Merging schemas

The `#merge` method will merge field definitions in two schemas and produce a new schema instance.

```ruby
basic_user_schema = Paradocs::Schema.new do
  field(:name).type(:string).required
  field(:age).type(:integer)
end

friends_schema = Paradocs::Schema.new do
  field(:friends).type(:array).schema do
    field(:name).required
    field(:email).policy(:email)
  end
end

user_with_friends_schema = basic_user_schema.merge(friends_schema)

results = user_with_friends_schema.resolve(input)
```

Fields defined in the merged schema will override fields with the same name in the original schema.

```ruby
required_name_schema = Paradocs::Schema.new do
  field(:name).required
  field(:age)
end

optional_name_schema = Paradocs::Schema.new do
  field(:name)
end

# This schema now has :name and :age fields.
# :name has been redefined to not be required.
new_schema = required_name_schema.merge(optional_name_schema)
```



### Reusing nested schemas

You can optionally use an existing schema instance as a nested schema:

```ruby
friends_schema = Paradocs::Schema.new do
  field(:friends).type(:array).schema do
    field(:name).type(:string).required
    field(:email).policy(:email)
  end
end

person_schema = Paradocs::Schema.new do
  field(:name).type(:string).required
  field(:age).type(:integer)
  # Nest friends_schema
  field(:friends).type(:array).schema(friends_schema)
end
```

### Schema-wide policies

Sometimes it's useful to apply the same policy to all fields in a schema.

For example, fields that are _required_ when creating a record might be optional when updating the same record (ie. _PATCH_ operations in APIs).

```ruby
class UpdateUserForm < CreateUserForm
  schema.policy(:declared)
end
```

This will prefix the `:declared` policy to all fields inherited from the parent class.
This means that only fields whose keys are present in the input will be validated.

Schemas with default policies can still define or re-define fields.

```ruby
class UpdateUserForm < CreateUserForm
  schema.policy(:declared) do
    # Validation will only run if key exists
    field(:age).type(:integer).present
  end
end
```

### Ignoring fields defined in the parent class

Sometimes you'll want a child class to inherit most fields from the parent, but ignoring some.

```ruby
class CreateUserForm
  include Paradocs::DSL

  schema do
    field(:uuid).present
    field(:status).required.options(["inactive", "active"])
    field(:name)
  end
end
```

The child class can use `ignore(*fields)` to ignore fields defined in the parent.

```ruby
class UpdateUserForm < CreateUserForm
  schema.ignore(:uuid, :status) do
    # optionally add new fields here
  end
end
```

### Schema options

Another way of modifying inherited schemas is by passing options.

```ruby
class CreateUserForm
  include Paradocs::DSL

  schema(default_policy: :noop) do |opts|
    field(:name).policy(opts[:default_policy]).type(:string).required
    field(:email).policy(opts[:default_policy).policy(:email).required
    field(:age).type(:integer)
  end

  # etc
end
```

The `:noop` policy does nothing. The sub-class can pass its own _default_policy_.

```ruby
class UpdateUserForm < CreateUserForm
  # this will only run validations keys existing in the input
  schema(default_policy: :declared)
end
```

## A pattern: changing schema policy on the fly.

You can use a combination of `#clone` and `#policy` to change schema-wide field policies on the fly.

For example, you might have a form object that supports creating a new user and defining mandatory fields.

```ruby
class CreateUserForm
  include Paradocs::DSL

  schema do
    field(:name).present
    field(:age).present
  end

  attr_reader :errors, :params

  def initialize(payload: {})
    results = self.class.schema.resolve(payload)
    @errors = results.errors
    @params = results.output
  end

  def run!
    User.create(params)
  end
end
```

Now you might want to use the same form object to _update_ and existing user supporting partial updates.
In this case, however, attributes should only be validated if the attributes exist in the payload. We need to apply the `:declared` policy to all schema fields, only if a user exists.

We can do this by producing a clone of the class-level schema and applying any necessary policies on the fly.

```ruby
class CreateUserForm
  include Paradocs::DSL

  schema do
    field(:name).present
    field(:age).present
  end

  attr_reader :errors, :params

  def initialize(payload: {}, user: nil)
    @payload = payload
    @user = user

    # pick a policy based on user
    policy = user ? :declared : :noop
    # clone original schema and apply policy
    schema = self.class.schema.clone.policy(policy)

    # resolve params
    results = schema.resolve(params)
    @errors = results.errors
    @params = results.output
  end

  def run!
    if @user
      @user.update_attributes(params)
    else
      User.create(params)
    end
  end
end
```

## Multiple schema definitions

Form objects can optionally define more than one schema by giving them names:

```ruby
class UpdateUserForm
  include Paradocs::DSL

  # a schema named :query
  # for example for query parameters
  schema(:query) do
    field(:user_id).type(:integer).present
  end

  # a schema for PUT body parameters
  schema(:payload) do
    field(:name).present
    field(:age).present
  end
end
```

Named schemas are inherited and can be extended and given options in the same way as the nameless version.

Named schemas can be retrieved by name, ie. `UpdateUserForm.schema(:query)`.

If no name given, `.schema` uses `:schema` as default schema name.

