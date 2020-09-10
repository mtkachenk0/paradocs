# Form objects DSL

## DSL
You can use schemas and fields on their own, or include the `DSL` module in your own classes to define form objects.

```ruby
require "parametric/dsl"

class CreateUserForm
  include Paradocs::DSL

  schema(:test) do
    field(:name).type(:string).required
    field(:email).policy(:email).required
    field(:age).type(:integer)
    subschema_by(:age) { |age| age > 18 ? :allow : :deny }
  end

  subschema_for(:test, name: :allow) { field(:role).options(["sign_in"]) }
  subschema_for(:test, name: :deny) { field(:role).options([]) }

  attr_reader :params, :errors

  def initialize(input_data)
    results = self.class.schema.resolve(input_data)
    @params = results.output
    @errors = results.errors
  end

  def run!
    if !valid?
      raise InvalidFormError.new(errors)
    end

    run
  end

  def valid?
    !errors.any?
  end

  private

  def run
    User.create!(params)
  end
end
```

Form schemas can also be defined by passing another form or schema instance. This can be useful when building form classes in runtime.

```ruby
UserSchema = Paradocs::Schema.new do
  field(:name).type(:string).present
  field(:age).type(:integer)
end

class CreateUserForm
  include Paradocs::DSL
  # copy from UserSchema
  schema UserSchema
end
```

## Form object inheritance

Sub classes of classes using the DSL will inherit schemas defined on the parent class.

```ruby
class UpdateUserForm < CreateUserForm
  # All field definitions in the parent are conserved.
  # New fields can be defined
  # or existing fields overriden
  schema do
    # make this field optional
    field(:name).declared.present
  end

  def initialize(user, input_data)
    super input_data
    @user = user
  end

  private
  def run
    @user.update params
  end
end
```

