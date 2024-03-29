# ResourcePolicy::ActionValidator

The `ResourcePolicy::ActionValidator` is a validator used to check the policy of a resource before performing a certain action. It helps to ensure that a user is only allowed to perform actions on a resource that they have permission to do so.

## Options

The `ResourcePolicy::ActionValidator` accepts two options:

- `:allowed_to` (required) - Specifies the action type that needs to be checked. This can be a symbol, string or proc.
- `:as` (optional) - Specifies the key that will be used to display errors. This is useful if you want to rename the attribute being validated.

## Usage Example

```ruby
require 'resource_policy/action_validator'

class SomeClass
  validates :some_policy, 'resource_policy/action': { allowed_to: :create, as: :some_item }

  def some_policy
    SomePolicy.new
  end
end

some_object = SomeClass.new

if some_object.valid?
  # No validation errors, continue with the process
else
  some_object.errors.messages # => { some_item: ['action "create" is not allowed'] }
end
```

## Usage Example with proc

```ruby
require 'resource_policy/action_validator'

class SomeClass < ActiveRecord::Base
  validates :some_policy, 'resource_policy/action': { allowed_to: -> { custom_allowed_to }, as: :some_item }

  def some_policy
    SomePolicy.new
  end

  def custom_allowed_to
    new_record? ? :create : :update
  end
end

new_object = SomeClass.new
new_object.valid?
new_object.errors.messages # => { some_item: ['action "create" is not allowed'] }

existing_object = SomeClass.find(1)
existing_object.valid?
existing_object.errors.messages # => { some_item: ['action "update" is not allowed'] }
```

In this example, the `SomeClass` has an attribute named `some_policy` which is validated using the `ResourcePolicy::ActionValidator`. The validator calls `custom_allowed_to` method on our model to determine which action to use. If record is new, it will check policy for the `create` action. If the record saved, it will check policy for `update` action. When the action is not allowed, an error message will be added to the `record.errors` object with the key `:some_item`. If the `:as` option is not provided, the key used to display the error will be the name of the attribute being validated.
