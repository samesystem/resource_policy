# ResourcePolicy::ActionsPolicy

## ActionsPolicy.actions_policy

To add actions policy config, call `actions_policy` in your policy class, like this:

```ruby
class UserPolicy
  include ResourcePolicy::ActionsPolicy

  actions_policy do |c|
    c.allowed_to(:read)
  end
end
```

### actions_policy#allowed_to

Actions policy allows you to define config for each action.

Using `allowed_to` method you can define conditions for each action:

```ruby
class UserPolicy
  include ResourcePolicy::ActionsPolicy

  actions_policy do |c|
    c.allowed_to(:read)
    c.allowed_to(:write, if: %i[admin? writable?])
  end

  def initialize(user, current_user)
    @user, @current_user = user, current_user
  end

  private

  def user_itself?
    @user == @current_user
  end

  def admin?
    @current_user.admin?
  end
end
```

If no condition is given then action will be always allowed.

This config means:

* `read` action is always allowed;
* `write` action is allowed only if both `admin?` and `writable?` methods returns `true`.


### actions_policy#group

Sometimes you might have action groups which share same conditions. In this case you can group then using `#group` method:

```ruby
class UserPolicy
  include ResourcePolicy::ActionsPolicy

  group(:user_itself?) do |c|
    c.allowed_to(:change_password)
    c.allowed_to(:destroy, if: :admin?)
  end

  private

  def admin?
    ...
  end
end
```

In this case:

* `change_password` will be allowed if `user_itself?` returns `true`;
* `destroy` will be allowed if both `user_itself?` and ``admin?` returns `true`.
