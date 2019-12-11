# ResourcePolicy::Policy

`Policy` includes both `AttributesPolicy` and `ActionsPolicy` modules. Their features are described separately, so read more there if you need more info.

## Basic usage

Here is and example how policy looks like:

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

  private

  def readable?
    true
  end

  def writable?
    true
  end
end
```

## Usage of Policy#action

Suppose we have policy like this:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  actions_policy do |c|
    c.allowed_to(:read) # current_user can always see user
    c.allowed_to(:write, if: :admin?) # only admin current_user can update user
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

  attributes_policy do |c|
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

