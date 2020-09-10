# FAQ
## Defaults
### Q: I need the child schema to be enriched with the specified defaults is parent key is absent.
```rb
schema do
  field(:top_level).type(:string).required.default('top_level')
  field(:nested).type(:object).required.schema do
    field(:start_date).type(:datetime).required.default(->(a,b,c) { Time.now })
    field(:ends_after).type(:integer).required.default(5)
  end
end
# usage
TestSchema.schema.resolve({}).output # => {:top_level=>"top_level", :nested=>nil, :configurations=>nil}
TestSchema.schema.resolve({nested: {}}).output # => {:top_level=>"top_level", :nested=>{:start_date=>#<DateTime: 2020-08-31T15:36:43+02:00 ((2459093j,49003s,0n),+7200s,2299161j)>, :ends_after=>5}, :configurations=>nil}
# I want resolving on {} to include the :nested structure.
```

### A: Set `.default({})` to your `:nested` field.
> Fields from nested schema are invoked only when the object for the schema exists.


