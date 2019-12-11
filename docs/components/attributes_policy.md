# ResourcePolicy::AttributesPolicy

## Usage of AttributesPolicy.protect

AttributePolicy provides `.protect` method which wraps model instance and does not allow to view fields which current_user does not have access to.

Usage example:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  attributes_policy do |c|
    c.attribute(:id).allowed(:read) # visible to all
    c.attribute(:salary).allowed(:read, if: :admin?) # only visible to admin
  end

  def initialize(user, current_user:)
    @user = user
    @current_user = current_user
  end

  def admin?
    @current_user.admin?
  end
end
```

Now you can protect `user` like this:

```ruby
current_user.admin? #=> false

user = User.find(1337)
user.id #=> 1337
user.email #=> "john.doe@example.com"

protected_user = UserPolicy.attributes_policy.protect(user, current_user: current_user)
protected_user.id #=> 1337
protected_user.email # nil
```
