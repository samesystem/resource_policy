# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0]

* Updated: Ruby to 3.2+
* Added: short-hand method for getting allowed actions
* Added: support for proc type validator options
* Added: nested read protection. `protected_resource` now returns a protected resource for
  values guarded by a policy of their own, so nested reads run nested rules. Attributes
  returning a record declare either `.nested { SomePolicy.new(_1) }` or
  `.unprotected(because: '...')`. Configured via `ResourcePolicy.configure` with
  `config.protectable_class` (asked about a class, never a value, so a list attribute is
  decided without loading a row), `config.nested_protection` (`:soft` reports and changes
  nothing for callers, `:hard` enforces) and `config.reporter`. Off until
  `config.protectable_class` is set, so existing consumers keep their current behaviour. On
  `:soft` nothing is ever withheld: an undeclared value, a nested object the viewer may not
  read and an attribute of one the viewer may not read are all reported and handed over, so
  adding a declaration cannot start hiding data until `:hard` is switched on.
* Added/Changed/Deprecated/Removed/Fixed/Security: YOUR CHANGE HERE

## [1.1.0]

* Added AttributesValidator

## [1.0.0]

* Added Ruby on Rails validator
* Fixed: attribute policy no longer depends on action policy conditions

## [0.2.0]

* Changed: resource protection is now done using policy instance method instead of class method
