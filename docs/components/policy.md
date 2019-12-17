# ResourcePolicy::Policy

`Policy` includes both `AttributesPolicy` and `ActionsPolicy` modules. Their features are described separately, so read more there if you need more info.

## Policy Configuration

Here is and example how policy looks like:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.policy_target :user

    c.action(:read).allowed(if: :readable?)

    c.attribute(:first_name)
      .allowed(:read, if: :readable?)
      .allowed(:write, if: :writable?)
  end

  def initialize(user, current_user:)
    @user = user
    @current_user = current_user
  end

  private

  def readable?
    true
  end

  def writable?
    true
  end
end
```

### policy#group

Sometimes you might have action groups which share same conditions. In this case you can group then using `#group` method:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.group(:user_itself?) do |g|
      g.action(:change_password).allowed
      g.action(:destroy).allowed(if: :admin?)
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


## Usage of Policy#action

Suppose we have policy like this:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.action(:read).allowed # current_user can always see user
    c.action(:write).allowed(if: :admin?) # only admin current_user can update user
  end

  def initialize(user, current_user:)
    @user = user
    @current_user = current_user
  end

  private

  def admin?
    @current_user.admin?
  end
end
```

then we can check each action like this:

```ruby
policy = UserPolicy.new(user, current_user: current_user)
policy.action(:read).allowed? # => true
policy.action(:write).allowed? # ... depends on `admin?` result
```

## Policy#actions_policy

Another way to check each action is to use `actions_policy` object like this:

```ruby
policy = UserPolicy.new(user, current_user: current_user)
actions_policy = policy.actions_policy
actions_policy.read.allowed? # => true
actions_policy.write.allowed? # ... depends on `admin?` result
```

## Usage of Policy#attribute

Suppose we have policy like this:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.attribute(:email)
      .allowed(:read) # current_user can always view user.email
      .allowed(:write, if: :admin?) # only admin current_user can change email
  end

  def initialize(user, current_user:)
    @user = user
    @current_user = current_user
  end

  private

  def admin?
    @current_user.admin?
  end
end
```

then we can check each attribute like this:

```ruby
policy = UserPolicy.new(user, current_user: current_user)
policy.attribute(:email).allowed_to?(:change) # => false - no such rule
policy.attribute(:email).readable? # => true
policy.action(:email).writable? # ... depends on `admin?` result
```

## Usage of Policy#attributes_policy

Another way to check each action is to use `attributes_policy` object like this:

```ruby
policy = UserPolicy.new(user, current_user: current_user)
attributes_policy = policy.attributes_policy

attributes_policy.email.allowed_to?(:change) # => false - no such rule
attributes_policy.email.readable? # same as `allowed_to?(:read)`
attributes_policy.email.writable? # same as `allowed_to?(:write)`
```

## Usage of Policy#protected_resource

Policy provides `#protected_resource` method which returns wrapped model instance and does not allow to view fields which current_user does not have access to. You must define `policy_target` in order to be able to use `protected_resource` feature

Usage example:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.policy_target(:user) # method name which returns target
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

policy = UserPolicy.new(user, current_user: current_user)
policy.protected_resource.id #=> 1337
policy.protected_resource.email # nil
```
