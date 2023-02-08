# ResourcePolicy::ActionsPolicy

## policy#action

Actions policy allows you to define config for each action.

Using `action` and `allowed` methods chain you can define conditions for each action:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.action(:show).allowed
    c.action(:update).allowed(if: %i[admin? admin?])
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

* `show` action is always allowed;
* `update` action is allowed only if both `admin?` and `writable?` methods returns `true`.


### policy#group

Sometimes you might have action groups which share same conditions. In this case you can group then using `#group` method:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.group(:user_itself?) do |g|
      g.allowed_to(:change_password)
      g.allowed_to(:destroy, if: :admin?)
    end
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
