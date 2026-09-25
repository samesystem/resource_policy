# ResourcePolicy::Configuration

A protected resource never hands out a raw record. When an attribute's value is itself
guarded by a policy, `protected_resource` returns that policy's own protected resource, so
nested reads run nested rules without every call site having to remember to ask.

For that to work the gem needs to know two things it cannot work out on its own: which values
must carry a policy, and how hard to lean on one that has none. Both are configured here.

Nested protection is **off until you configure it**. A gem consumer which sets nothing keeps
exactly the behaviour it has today.

### Setting it up

In a Rails app, add an initializer:

```ruby
# config/initializers/resource_policy.rb
ResourcePolicy.configure do |config|
  config.protectable = ->(value) { value.is_a?(ActiveRecord::Base) }
  config.nested_protection = Rails.env.local? ? :hard : :soft
  config.reporter = ->(event) { Rails.logger.warn(event.message) }
end
```

### config#protectable

A callable which answers **"is this value something which must carry a policy of its own?"**

It is called with every value a protected resource is about to return:

```ruby
protected_user.first_name       # String   -> not a record -> returned as is
protected_user.current_contract # Contract -> a record     -> must be declared
```

Values which pass the check need either a `.nested` or an `.unprotected` declaration on the
attribute. Everything else — strings, numbers, dates, enums, plain value objects — is handed
back untouched.

The default is `->(_value) { false }`, which means nothing is a record and the guard never
fires. Setting it is what switches nested protection on.

`ActiveRecord::Base` is the usual answer, but it is a dial rather than a constant. Widen it if
you have plain Ruby objects, or view-layer objects, holding sensitive fields:

```ruby
config.protectable = ->(value) { value.is_a?(ActiveRecord::Base) || value.is_a?(GraphqlRails::Decorator) }
```

### config#nested_protection

How hard the gem leans on a nested value it cannot vouch for.

**`:soft` never changes what a caller gets.** It reports and hands the value over, every time,
so you can switch it on in a running app and read the logs without touching behaviour.
**`:hard` enforces.**

| situation | `:soft` | `:hard` |
|---|---|---|
| protectable value with no declaration | warns, returns the value | raises `UnprotectedNestedValueError` |
| nested policy denies the read | warns, returns the value | returns `nil` |

`:hard` is the default on purpose.

A developer who adds an attribute returning a record and forgets to declare it finds out on
their first test run, with a message naming the fix:

```
UserPolicy attribute :absences returned a Absence which has no policy of its own, so its
read rules never run. Declare it with `c.attribute(:absences).nested { SomePolicy.new(_1) }`,
or, if the value needs no policy, with `c.attribute(:absences).unprotected(because: '...')`.
```

### config#reporter

Called on `:soft` with an `UnprotectedNestedValue` (no declaration) or a `DeniedNestedRead`
(the nested policy said no). It exists so you can attach
context the gem knows nothing about:

```ruby
config.reporter = lambda do |event|
  Rails.logger.warn(
    message: event.message,
    policy: event.policy.class.name,
    attribute: event.attribute.name,
    user_id: Current.user&.id
  )
end
```

Both events expose `#policy`, `#attribute` and `#message`; `UnprotectedNestedValue` adds
`#value` and `DeniedNestedRead` adds `#nested_policy`. The default writes the message to
`stderr`.

### Declaring nested attributes

Once configured, each attribute returning a record needs one of two declarations.

`nested` says which policy guards the value. The block runs on the parent policy instance, so
that policy's own dependencies are in scope — which matters when nested policies do not all
take the same arguments:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.attribute(:current_contract)
      .allowed(:read)
      .nested { |contract| ContractPolicy.new(contract, app_context: app_context) }

    c.attribute(:contracts)
      .allowed(:read, if: :read_contracts_allowed?)
      .nested { |contract| ContractPolicy.new(contract, app_context: app_context) }
  end
end
```

`unprotected` says the value needs no policy. The reason is required to be written down, so the
decision is visible in review rather than being a silent default:

```ruby
c.attribute(:custom_fields)
  .allowed(:read)
  .unprotected(because: 'plain value objects with no sensitive fields')
```

### Reading nested values

Nothing changes at the call site. Reads simply run the nested rules too:

```ruby
policy = UserPolicy.new(user, app_context: app_context)
protected_user = policy.protected_resource

protected_user.current_contract           # => ProtectedResource wrapping ContractPolicy
protected_user.current_contract.hours_week # => nil unless ContractPolicy allows reading it
protected_user.contracts.map(&:salary_nr)  # => each item protected by ContractPolicy
```

On `:hard`, a nested value the viewer may not read **at all** is withheld outright rather than
handed over as a proxy answering `nil` to everything. On `:soft` it is handed over and a warning
is logged instead:

```ruby
protected_user.current_contract # => nil on :hard when ContractPolicy denies the read
                                # => ProtectedResource on :soft, plus a logged warning
```

"May not read at all" means the nested policy's `:read` action is denied, or — when it declares
no `:read` action — that none of its attributes are readable.

### Collections

A collection is one decision, not one per item, because the alternative is expensive:

```ruby
protected_user.contracts.includes(:employer) # still a relation when nothing needs wrapping
```

- **undeclared, or `unprotected`** — the collection is handed back as it came, so an
  `ActiveRecord::Relation` stays a relation and callers can keep chaining `.where`, `.includes`
  and `.order`.
- **`nested`** — every item is wrapped, which forces the query and returns an `Array`. On
  `:hard`, items the nested policy withholds are dropped, so the result never contains `nil`s;
  on `:soft` nothing is withheld, so every item survives and each denial is warned about.
- **empty** — there is nothing to vouch for, so it is returned untouched and nothing is reported.

Deciding an undeclared collection costs one `.first` — a `LIMIT 1` on an unloaded relation,
free on one already loaded.

### Rolling it out

Switching `protectable` on in an existing app will surface every record-returning attribute at
once, so introduce it in stages:

1. Set `nested_protection` to `:soft` everywhere and run the test suite to collect the list of
   attributes needing declarations.
2. Declare them, policy by policy, with `nested` or `unprotected`.
3. Move development and test to `:hard`, so new gaps are caught immediately.
4. Soak in production on `:soft` until the warnings stop, then switch it to `:hard` too.

Step 4 matters: `:hard` raises on values which are reaching users today, so anything still
warning in the logs needs a declaration before the switch.
