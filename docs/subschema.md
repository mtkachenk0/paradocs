# Subchemas
> When your schema can change on-the-fly.

## Subschemas and mutations.
Sometimes depending on the data the structure may vary. Most frequently used option is to use `:declared` policy (a.k.a. conditional, but below is another option:

- Mutations are blocks that are assigned to a field and called during the validation (in #resolve), block receives all the related data and should return a subschema name.
- Subschemas are conditional schemas declared inside schemas. They doesn't exist until mutation block is called and decides to invoke a subschema.
```ruby
person_schema = Paradocs::Schema.new do
  field(:role).type(:string).options(["admin", "user"]).mutates_schema! do |value, key, payload, env|
    value == :admin ? :admin_schema : :user_schema
  end

  subschema(:admin_schema) do
    field(:permissions).present.type(:string).options(["superuser"])
    field(:admin_field)
  end
  subschema(:user_schema) do
    field(:permissions).present.type(:string).options(["readonly"])
    field(:user_field)
  end
end

results = person_schema.resolve(name: "John", age: 20, role: :admin, permissions: "superuser")
results.output # => {name: "John", age: 20, role: :admin, permissions: "superuser", admin_field: nil}
results = person_schema.resolve(name: "John", age: 20, role: :admin, permissions: "readonly")
results.errors => {"$.permissions"=>["must be one of superuser, but got readonly"]}
```
