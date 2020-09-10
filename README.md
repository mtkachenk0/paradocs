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
Please read the [documentation](https://paradocs.readthedocs.io/en/latest)
