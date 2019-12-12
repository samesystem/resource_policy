# ResourcePolicy::AttributesPolicy

## AttributesPolicy.attributes_policy

To add attributes policy config, call `attributes_policy` in your policy class, like this:

```ruby
class UserPolicy
  include ResourcePolicy::AttributesPolicy

  attributes_policy do |c|
    c.attribute(:first_name).allowed(:read)
  end
end
```

### attributes_policy#attribute

Attributes policy allows you to define separate attributes.

Using `attribute#allowed` method you can define conditions for each attribute and for each action type like `read`, `write` and etc:

```ruby
class UserPolicy
  include ResourcePolicy::AttributesPolicy

  attributes_policy do |c|
    c.attribute(:first_name)
      .allowed(:read)
      .allowed(:write, if: %i[admin? writable?])
  end

  private

  def admin?
    ...
  end

  def writable?
    ...
  end
end
```

If no condition is given then action will be always allowed for given attribute.

### attributes_policy#group

Sometimes you might have attribute groups which share same conditions. In this case you can group then using `#group` method:

```ruby
class UserPolicy
  include ResourcePolicy::AttributesPolicy

  group(:user_itself?) do |c|
    c.attribute(:password).allowed(:write)
    c.attribute(:email).allowed(:read, :write)
    c.attribute(:children).allowed(:read, if: :parent?)
  end

  def initialize(user, current_user)
    @user, @current_user = user, current_user
  end

  private

  def user_itself?
    @user == @current_user
  end

  def parent?
    @user.parent?
  end
end
```

In this case:

* `password` will be allowed to `write` only if `user_itself?` returns `true`.
* `email` will be allowed to `read` and `write` only if `user_itself?` returns `true`.
* `childrend` will be allowed to `read` if both `user_itself?` **and** `parent?` returns `true`.
