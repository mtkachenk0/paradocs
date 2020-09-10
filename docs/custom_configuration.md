# Configuration
```rb
Paradocs.configure do |config|
  config.explicit_errors = false       # set to true if you want all errors from the policies to be explicitly registered in the policy
  config.whitelisted_keys = []         # enrich it with global white-listed keys if you use WhiteList feature
  config.default_schema_name = :schema # this name will be set for unnamed schemas
  config.meta_prefix = "_"             # used in #structure and #flatten_structure methods. All the metadata will be prefixed with this prefix.
  config.whitelist_coercion = nil      # set up a Proc here, that receives |value, field.meta| for each whitelisted field in order to enrich the whitelisting logic.
end
```
