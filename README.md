# Paradocs: Extended [Parametric gem](https://github.com/ismasan/parametric) + Documentation Generation

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

## Getting Started

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

## Learn more
- [Getting Started](https://github.com/mtkachenk0/paradocs/wiki/Getting-Started)
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
