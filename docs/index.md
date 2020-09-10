# Getting Started
## Introduction
> Paradocs = Extended [Parametric gem](https://github.com/ismasan/parametric) + Documentation Generation

![Ruby](https://github.com/mtkachenk0/paradocs/workflows/Ruby/badge.svg)

Declaratively define data schemas in your Ruby objects, and use them to whitelist, validate or transform inputs to your programs.

Useful for building self-documeting APIs, search or form objects. Or possibly as an alternative to Rails' _strong parameters_ (it has no dependencies on Rails and can be used stand-alone).
## Installation
```sh
$ gem install paradocs
```

Or with Bundler in your Gemfile.
```rb
gem 'paradocs'
```

## Try it out

Define a schema

```ruby
schema = Paradocs::Schema.new do
  field(:title).type(:string).present
  field(:status).options(["draft", "published"]).default("draft")
  field(:tags).type(:array)
end
```

Populate and use. Missing keys return defaults, if provided.

```ruby
form = schema.resolve(title: "A new blog post", tags: ["tech"])

form.output # => {title: "A new blog post", tags: ["tech"], status: "draft"}
form.errors # => {}
```

Undeclared keys are ignored.

```ruby
form = schema.resolve(foobar: "BARFOO", title: "A new blog post", tags: ["tech"])

form.output # => {title: "A new blog post", tags: ["tech"], status: "draft"}
```

Validations are run and errors returned


```ruby
form = schema.resolve({})
form.errors # => {"$.title" => ["is required"]}
```

If options are defined, it validates that value is in options

```ruby
form = schema.resolve({title: "A new blog post", status: "foobar"})
form.errors # => {"$.status" => ["expected one of draft, published but got foobar"]}
```

## Nested schemas

A schema can have nested schemas, for example for defining complex forms.

```ruby
person_schema = Paradocs::Schema.new do
  field(:name).type(:string).required
  field(:age).type(:integer)
  field(:friends).type(:array).schema do
    field(:name).type(:string).required
    field(:email).policy(:email)
  end
end
```

It works as expected

```ruby
results = person_schema.resolve(
  name: "Joe",
  age: "38",
  friends: [
    {name: "Jane", email: "jane@email.com"}
  ]
)

results.output # => {name: "Joe", age: 38, friends: [{name: "Jane", email: "jane@email.com"}]}
```

Validation errors use [JSON path](http://goessner.net/articles/JsonPath/) expressions to describe errors in nested structures

```ruby
results = person_schema.resolve(
  name: "Joe",
  age: "38",
  friends: [
    {email: "jane@email.com"}
  ]
)

results.errors # => {"$.friends[0].name" => "is required"}
```

## Learn more
- [Getting Started](getting_started)
- [Built In Policies](https://github.com/mtkachenk0/paradocs/wiki/Policies#built-in-policies)
	- [Type Policies](https://github.com/mtkachenk0/paradocs/wiki/Policies#type-coercions)
	- [Presence Policies](https://github.com/mtkachenk0/paradocs/wiki/Policies#presence-policies)
  - [Custom Policies](https://github.com/mtkachenk0/paradocs/wiki/Policies#custom-policies)
- [Schema](https://github.com/mtkachenk0/paradocs/wiki/schema)
	- [Expanding fields dynamically](https://github.com/mtkachenk0/paradocs/wiki/schema#expanding-fields-dynamically)
	- [Multiple schema definitions](https://github.com/mtkachenk0/paradocs/wiki/schema#multiple-schema-definitions)
- [Documentation Generation](https://github.com/mtkachenk0/paradocs/wiki/Documentation-Generation)
- [What if my fields are conditional?!](https://github.com/mtkachenk0/paradocs/wiki/subschema)
- [For those who need more: RTFM](https://github.com/mtkachenk0/paradocs/wiki)

