# ResourcePolicy::AttributesValidator

`ResourcePolicy::AttributesValidator` is a validator that validates the attributes of an object to ensure they comply with specified policies. The validator can be used to validate a hash of attributes with the `apply_to` option and the desired access level with the `allowed_to` option.

## Options

The validates method requires two options:

- `:apply_to` (required) - The name of the method that returns the hash that needs to be validated.
- `:allowed_to` (required) - The access level that we need to check. This can be either :read or :write.

## Usage example

```ruby
class SomeClass
  include ActiveModel::Validations
  validates :some_policy, 'resource_policy/attributes': { apply_to: :some_params, allowed_to: :write }

  def some_policy
    SomePolicy.new
  end

  def some_params
    { foo: :foo, bar: :bar }
  end
end

some_object = SomeClass.new
if some_object.valid?
  # No validation errors, continue with the process
else
  some_object.errors.messages # => { foo: ['attribute action "write" is not allowed'], bar: ['attribute action "write" is not allowed'] }
end
```

In this example, the `SomeClass` has an attribute named `some_policy` which is being validated using the `ResourcePolicy::AttributesValidator`. The validator checks if attributes from the `some_params` satisfy access level conditions (such as `:write`). It adds an error for each hash key that does not satisfy policy conditions.

