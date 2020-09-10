# Built-In Policies
Paradocs ships with a number of built-in policies.

## Type coercions
Type coercions (the `type` method) and validations (the `validate` method) are all _policies_.

### :string

Calls `:to_s` on the value

```ruby
field(:title).type(:string)
```

### :integer

Calls `:to_i` on the value

```ruby
field(:age).type(:integer)
```

### :number

Calls `:to_f` on the value

```ruby
field(:price).type(:number)
```

### :boolean

Returns `true` or `false` (`nil` is converted to `false`).

```ruby
field(:published).type(:boolean)
```

### :datetime

Attempts parsing value with [Datetime.parse](http://ruby-doc.org/stdlib-2.3.1/libdoc/date/rdoc/DateTime.html#method-c-parse). If invalid, the error will be added to the output's `errors` object.

```ruby
field(:expires_on).type(:datetime)
```

## Presence policies.

### :required

Check that the key exists in the input.

```ruby
field(:name).required

# same as
field(:name).policy(:required)
```

Note that `:required` policy does not validate that the value is not empty. Use `:present` for that.

### :present

Check that the key exists and the value is not blank.

```ruby
field(:name).present

# same as
field(:name).policy(:present)
```

If the value is a `String`, it validates that it's not blank. If an `Array`, it checks that it's not empty. Otherwise it checks that the value is not `nil`.

### :declared

Check that a key exists in the input, or stop any further validations otherwise.
This is useful when chained to other validations. For example:

```ruby
field(:name).declared.present
```
The example above will check that the value is not empty, but only if the key exists. If the key doesn't exist no validations will run.

### :default

- `:default` policy is invoked when there are no field presence policies defined or used either `:required` or `:declared` policies.
- `:default` policy is invoked when value is nil or empty
- `:default` policy can be a proc. Proc receives the following arguments: `key, the whole payload, validation context`

```ruby
field(:role).declared.default("admin")
field(:created_at).declared.default( ->(key, payload, context) { DateTime.now })
```

## Useful built-in policies.

### :format

Check value against custom regexp

```ruby
field(:salutation).policy(:format, /^Mr\/s/)
# optional custom error message
field(:salutation).policy(:format, /^Mr\/s\./, "must start with Mr/s.")
```

### :email

```ruby
field(:business_email).policy(:email)
```

### :gt, :gte, :lt, :lte

Compare the value with a number.

```ruby
field(:age).policy(:gt, 35) # strictly greater than 35
field(:age1).policy(:lt, 11.1) # strictly less than 11.1
field(:age2).policy(:lte, 21) # less or equal to 21
field(:age3).policy(:gte, 11) # greater or equal to 11
```

### :options

Pass allowed values for a field

```ruby
field(:status).options(["draft", "published"])

# Same as
field(:status).policy(:options, ["draft", "published"])
```

### :length

Specify value's length constraints. Calls #length under the hood.
 - `min:` - The attribute cannot have less than the specified length.
 - `max`  - The attribute cannot have more than the specified length.
 - `eq`   - The attribute should be exactly equal to the specified length.

```ruby
field(:name).length(min: 5, max: 25)
field(:name).length(eq: 10)
```

### :split

Split comma-separated string values into an array.
Useful for parsing comma-separated query-string parameters.

```ruby
field(:status).policy(:split) # turns "pending,confirmed" into ["pending", "confirmed"]
```

### :meta

The `#meta` field method can be used to add custom meta data to field definitions.
These meta data can be used later when instrospecting schemas (ie. to generate documentation or error notices).

```ruby
create_user_schema = Paradocs::Schema.new do
  field(:name).required.type(:string).meta(label: "User's full name")
  field(:status).options(["published", "unpublished"]).default("published")
  field(:age).type(:integer).meta(label: "User's age")
  field(:friends).type(:array).meta(label: "User friends").schema do
    field(:name).type(:string).present.meta(label: "Friend full name")
    field(:email).policy(:email).meta(label: "Friend's email")
  end
end
```

## Custom policies

You can also register your own custom policy objects. A policy can be not inherited from `Paradocs::BasePolicy`, in this case it must implement the following methods: `#valid?`, `#coerce`, `#message`, `#meta_data`, `#policy_name`

```ruby
class MyPolicy < Paradocs::BasePolicy
  # Validation error message, if invalid
  def message
    'is invalid'
  end

  # Whether or not to validate and coerce this value
  # if false, no other policies will be run on the field
  def eligible?(value, key, payload)
    true
  end

  # Transform the value
  def coerce(value, key, context)
    value
  end

  # Is the value valid?
  def validate(value, key, payload)
    true
  end

  # merge this object into the field's meta data
  def meta_data
    {type: :string}
  end
end
```


You can register your policy with:

```ruby
Paradocs.policy :my_policy, MyPolicy
```
And then refer to it by name when declaring your schema fields

```ruby
field(:title).policy(:my_policy)
```

You can chain custom policies with other policies.

```ruby
field(:title).required.policy(:my_policy)
```

Note that you can also register instances.

```ruby
Paradocs.policy :my_policy, MyPolicy.new
```

For example, a policy that can be configured on a field-by-field basis:

```ruby
class AddJobTitle
  def initialize(job_title)
    @job_title = job_title
  end

  def message
    'is invalid'
  end

  # Noop
  def eligible?(value, key, payload)
    true
  end

  # Add job title to value
  def coerce(value, key, context)
    "#{value}, #{@job_title}"
  end

  # Noop
  def validate(value, key, payload)
    true
  end

  def meta_data
    {}
  end
end

# Register it
Paradocs.policy :job_title, AddJobTitle
```

Now you can reuse the same policy with different configuration

```ruby
manager_schema = Paradocs::Schema.new do
  field(:name).type(:string).policy(:job_title, "manager")
end

cto_schema = Paradocs::Schema.new do
  field(:name).type(:string).policy(:job_title, "CTO")
end

manager_schema.resolve(name: "Joe Bloggs").output # => {name: "Joe Bloggs, manager"}
cto_schema.resolve(name: "Joe Bloggs").output # => {name: "Joe Bloggs, CTO"}
```

## Custom policies, short version

For simple policies that don't need all policy methods, you can:

```ruby
Paradocs.policy :cto_job_title do
  coerce do |value, key, context|
    "#{value}, CTO"
  end
end

# use it
cto_schema = Paradocs::Schema.new do
  field(:name).type(:string).policy(:cto_job_title)
end
```

```ruby
Paradocs.policy :over_21_and_under_25 do
  coerce do |age, key, context|
    age.to_i
  end

  validate do |age, key, context|
    age > 21 && age < 25
  end
end
