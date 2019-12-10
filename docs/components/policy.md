# ResourcePolicy::Policy

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  actions_policy do |c|
    c.allowed_to(:read, if: :readable?)
  end

  attributes_policy do |c|
    c.attribute(:first_name)
      .allowed(:read, if: :readable?)
      .allowed(:write, if: :writable?)
  end

  def initialize(user, current_user:)
    @user = user
    @current_user = current_user
  end

  def readable?
    true
  end
end
```
