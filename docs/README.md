# ResourcePolicy

[![Build Status](https://travis-ci.org/samesystem/resource_policy.svg?branch=master)](https://travis-ci.org/samesystem/resource_policy)
[![codecov](https://codecov.io/gh/samesystem/resource_policy/branch/master/graph/badge.svg)](https://codecov.io/gh/samesystem/resource_policy)
[![Documentation](https://readthedocs.org/projects/ansicolortags/badge/?version=latest)](https://samesystem.github.io/resource_policy)

Gem which allows to protect your resources and their methods with policy rules.

## Installation

Add this line to your Ruby on Rails application's Gemfile:

```ruby
gem 'resource_policy', require 'resource_policy/rails'
```

Or add this for any other ruby app:

```ruby
gem 'resource_policy'
```

And then execute:

```sh
    $ bundle
```

Or install it yourself as:

```sh
    $ gem install resource_policy
```

## Documentation

All details about gem usage can be found here: https://samesystem.github.io/resource_policy

## Usage

Policy should be a single point of truth where you can check what kind of actions current user (or anything else) can do to some resource. Later you will see example of `UserPolicy`.

### Actions policy

Action policy defines what kind of actions can be done on resource. In the folulowing example `UserPolicy` defines what kind of actions `current_user` can do with other `user`.

#### Define action policy

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.action(:show).allowed # current_user can always see user
    c.action(:update).allowed(if: :admin?) # only admin current_user can update user
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

#### Using action policy

```ruby
policy = UserPolicy.new(user, current_user: current_user)
policy.action(:show).allowed? # => true
policy.action(:update).allowed? # ... depends on `admin?` result
```

### Attributes policy

Similar as with actions policy, you can define each field which should be visible or writable by other user

#### Define attributes policy

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

#### Using attributes policy

```ruby
policy = UserPolicy.new(user, current_user: current_user)
policy.attribute(:email).readable? # => true
policy.attribute(:email).writable? # ... depends on `admin?` result
```

#### Using protector

You can use `Policy` to hide some fields. Here is how:

```ruby
class UserPolicy
  include ResourcePolicy::Policy

  policy do |c|
    c.attribute(:id).allowed(:read)
    c.attribute(:email).allowed(:read, if: :admin?)
  end

  ...
end
```

Now you can protect `user` like this:

```ruby
current_user.admin? #=> false

user = User.find(1337)
user.id #=> 1337
user.email #=> "john.doe@example.com"

policy = UserPolicy.new(user, current_user)
protected_user = policy.protected_resource
protected_user.id #=> 1337
protected_user.email # nil
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/samesystem/resource_policy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ResourcePolicy project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/samesystem/resource_policy/blob/master/CODE_OF_CONDUCT.md).
