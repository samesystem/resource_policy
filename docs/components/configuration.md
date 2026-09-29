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
  config.protectable_class = ->(klass) { klass <= ActiveRecord::Base }
  config.nested_protection = Rails.env.local? ? :hard : :soft
  config.reporter = ->(event) { Rails.logger.warn(event.message) }
end
```

### config#protectable_class

A callable which answers **"does this kind of value have to carry a policy of its own?"**

It is called with the **class** of every value a protected resource is about to return, never
with the value:

```ruby
protected_user.first_name       # String   -> not a record -> returned as is
protected_user.current_contract # Contract -> a record     -> must be declared
```

Asking about a class rather than a value is what keeps list attributes free. An
`ActiveRecord::Relation` answers `klass` without loading anything, so `protected_user.contracts`
is decided with no query; asking about a value would mean fetching a row behind every list read
on every screen, including the reads which turn out to need no protection at all.

Classes which pass the check need either a `.nested` or an `.unprotected` declaration on the
attribute. Everything else — strings, numbers, dates, enums, plain value objects — is handed
back untouched.

The default is `->(_klass) { false }`, which means nothing is a record and the guard never
fires. Setting it is what switches nested protection on.

`ActiveRecord::Base` is the usual answer, but it is a dial rather than a constant. Widen it if
you have plain Ruby objects, or view-layer objects, holding sensitive fields:

```ruby
config.protectable_class = ->(klass) { klass <= ActiveRecord::Base || klass <= GraphqlRails::Decorator }
```

The trade-off is that the decision cannot depend on the value — "only protect persisted
records" is not expressible. That is deliberate: a per-value rule cannot be answered for a
relation without loading it.

### config#nested_protection

How hard the gem leans on a nested value it cannot vouch for.

**`:soft` changes nothing at all.** It is an observation mode: a value is handed back exactly
as the policy target returned it — the same record, the same relation, still lazy, with every
item in it. The only thing it does is report the values nobody has declared yet.
**`:hard` enforces**, and is the only mode in which a `.nested` declaration does anything.

| situation | `:soft` | `:hard` |
|---|---|---|
| protectable value with no declaration | warns, returns the value | raises `UnprotectedNestedValueError` |
| value with a `.nested` declaration | returns the value untouched | returns the nested policy's protected resource |
| collection with a `.nested` declaration | returns the collection untouched | returns an `Array` of protected resources |
| nested policy denies the object | — the declaration is inert | returns `nil` |
| nested policy denies one of its attributes | — the declaration is inert | returns `nil` |

That split is the point: declarations can be written, reviewed and deployed while the
application behaves exactly as it did, and the flip to `:hard` is the single moment anything
changes. It does mean `:soft` cannot tell you *which* nested values `:hard` would hide —
nothing is wrapped, so nothing is there to notice it. Run your test suite or a staging
environment in `:hard` to get that list: a missing declaration raises, and a denied read shows
up as a failing expectation.

`:hard` is the default on purpose.

A developer who adds an attribute returning a record and forgets to declare it finds out on
their first test run, with a message naming the fix:

```
UserPolicy attribute :absences returned a Absence which has no policy of its own, so its
read rules never run. Declare it with `c.attribute(:absences).nested { SomePolicy.new(_1) }`,
or, if the value needs no policy, with `c.attribute(:absences).unprotected(because: '...')`.
```

### config#reporter

Called on `:soft` with an `UnprotectedNestedValue`: a value whose class is protectable and
whose attribute carries no declaration. It exists so you can attach context the gem knows
nothing about:

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

The event exposes `#policy`, `#attribute`, `#message` and `#value_class` — the class, not the
record, so log events never carry the data they warn about. The default writes the message to
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

### When `nested` is the wrong tool

A protected resource answers the attributes its policy declares and nothing else. That is the
point of it, but it means a nested value is a narrow object, not a stand-in for the record:

```ruby
protected_user.current_contract.hours_week # => the value, it is declared
protected_user.current_contract.shop       # => NoMethodError, no rule declares it
```

So `nested` fits a value which is consumed *through the policy* — a controller rendering off
`protected_resource`, a serialiser built on one. It does not fit a value handed to something
which treats it as the record: a decorator, a presenter, anything reaching for an association
or a helper. Those break the moment `:hard` is switched on, with a `NoMethodError` rather than
a hidden field.

Where a decorator is what exposes the value, the decorator is what has to apply the policy:

```ruby
# not this - the decorator receives a proxy and falls over
c.attribute(:current_contract).allowed(:read).nested { ContractPolicy.new(_1) }

# this - the value leaves as a decorator which applies ContractPolicy itself
def contract
  ContractDecorator.decorate(protected_user.current_contract, app_context:)
end

c.attribute(:current_contract)
  .allowed(:read)
  .unprotected(because: 'exposed only through ContractDecorator, which applies ContractPolicy')
```

The `unprotected` declaration is doing real work there: it records *why* this value needs no
policy of its own, so the next reader can check the claim rather than assume it.

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

protected_user.current_contract.salary_nr # => nil on :hard when ContractPolicy denies salary_nr
                                          # => the value on :soft, plus a logged warning
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
- **`nested`, on `:soft`** — handed back as it came, exactly as above: the declaration is inert.
- **`nested`, on `:hard`** — every item is wrapped, which forces the query and returns an
  `Array`. Items the nested policy withholds are dropped; `nil` entries survive, because only
  the items the viewer may not read are meant to disappear.
- **empty relation** — still decided, because a relation knows its item class whether or not it
  holds rows. A missing declaration is therefore caught on the same code path every time,
  rather than only when the data happens to be there.
- **empty `Array`** — the one case which cannot be decided: an array which holds nothing says
  nothing about what it would have held, so it is handed back untouched and nothing is reported.

**Deciding a collection costs no query at all.** Nothing reads an element: whether an attribute
is declared is a property of the attribute, and the item class of an unloaded relation is a
property of the relation. Only wrapping touches the rows, and that happens on `:hard` alone.

### Rolling it out

Switching `protectable_class` on in an existing app will surface every record-returning
attribute at once, so introduce it in stages:

1. Set `nested_protection` to `:soft` everywhere. Nothing a caller receives changes, so this is
   safe to deploy on its own, and the warnings are the inventory of attributes needing
   declarations.
2. Declare them, policy by policy, with `nested` or `unprotected`. These are safe to deploy
   too: on `:soft` a declaration does nothing.
3. Move test and development to `:hard`. This is where declarations start acting, so it is
   where you find out what they change — a run of the suite lists it.
4. Fix what that surfaces, then flip production to `:hard`.

Step 3 carries the risk, and it is deliberately the step you take on a machine rather than in
production. Everything before it is inert by construction.
