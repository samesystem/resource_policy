# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0]

<<<<<<< HEAD
* Updated: Ruby version updated to 4.0
=======
* Updated: Ruby to 3.2+
>>>>>>> update/ruby-to-4.0.6
* Added: short-hand method for getting allowed actions
* Added: support for proc type validator options
* Added: nested read protection. `protected_resource` now returns a protected resource for
  values guarded by a policy of their own, so nested reads run nested rules. Attributes
  returning a record declare either `.nested { SomePolicy.new(_1) }` or
  `.unprotected(because: '...')`. Configured via `ResourcePolicy.configure` with
  `config.protectable`, `config.nested_protection` (`:soft` reports and changes nothing for
  callers, `:hard` enforces) and `config.reporter`. Off until `config.protectable` is set, so
  existing consumers keep their current behaviour.
* Added/Changed/Deprecated/Removed/Fixed/Security: YOUR CHANGE HERE

## [1.1.0]

* Added AttributesValidator

## [1.0.0]

* Added Ruby on Rails validator
* Fixed: attribute policy no longer depends on action policy conditions

## [0.2.0]

* Changed: resource protection is now done using policy instance method instead of class method
