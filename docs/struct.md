# Structs
## Overview
Structs turn schema definitions into objects graphs with attribute readers.

Add optional `Paradocs::Struct` module to define struct-like objects with schema definitions.

```ruby
require 'parametric/struct'

class User
  include Paradocs::Struct

  schema do
    field(:name).type(:string).present
    field(:friends).type(:array).schema do
      field(:name).type(:string).present
      field(:age).type(:integer)
    end
  end
end
```

`User` objects can be instantiated with hash data, which will be coerced and validated as per the schema definition.

```ruby
user = User.new(
  name: 'Joe',
  friends: [
    {name: 'Jane', age: 40},
    {name: 'John', age: 30},
  ]
)

# properties
user.name # => 'Joe'
user.friends.first.name # => 'Jane'
user.friends.last.age # => 30
```

## Errors

Both the top-level and nested instances contain error information:

```ruby
user = User.new(
  name: '', # invalid
  friends: [
    # friend name also invalid
    {name: '', age: 40},
  ]
)

user.valid? # false
user.errors['$.name'] # => "is required and must be present"
user.errors['$.friends[0].name'] # => "is required and must be present"

# also access error in nested instances directly
user.friends.first.valid? # false
user.friends.first.errors['$.name'] # "is required and must be valid"
```

## .new!(hash)

Instantiating structs with `.new!(hash)` will raise a `Paradocs::InvalidStructError` exception if the data is validations fail. It will return the struct instance otherwise.

`Paradocs::InvalidStructError` includes an `#errors` property to inspect the errors raised.

```ruby
begin
  user = User.new!(name: '')
rescue Paradocs::InvalidStructError => e
  e.errors['$.name'] # "is required and must be present"
end
```

## Nested structs

You can also pass separate struct classes in a nested schema definition.

```ruby
class Friend
  include Paradocs::Struct

  schema do
    field(:name).type(:string).present
    field(:age).type(:integer)
  end
end

class User
  include Paradocs::Struct

  schema do
    field(:name).type(:string).present
    # here we use the Friend class
    field(:friends).type(:array).schema Friend
  end
end
```

## Inheritance

Struct subclasses can add to inherited schemas, or override fields defined in the parent.

```ruby
class AdminUser < User
  # inherits User schema, and can add stuff to its own schema
  schema do
    field(:permissions).type(:array)
  end
end
```

## #to_h

`Struct#to_h` returns the ouput hash, with values coerced and any defaults populated.

```ruby
class User
  include Paradocs::Struct
  schema do
    field(:name).type(:string)
    field(:age).type(:integer).default(30)
  end
end

user = User.new(name: "Joe")
user.to_h # {name: "Joe", age: 30}
```

## Struct equality

`Paradocs::Struct` implements `#==()` to compare two structs Hash representation (same as `struct1.to_h.eql?(struct2.to_h)`.

Users can override `#==()` in their own classes to do whatever they need.
