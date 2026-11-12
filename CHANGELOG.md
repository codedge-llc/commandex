# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- `param/3` accepts a type, and `new/1` casts the value to that type. A parameter
  without a type works as before. ([#19](https://github.com/codedge-llc/commandex/pull/19))
- Built-in types: `:any`, `:binary`, `:boolean`, `:date`, `:decimal`, `:float`,
  `:integer`, `:map`, `:naive_datetime`, `:naive_datetime_usec`, `:string`, `:time`,
  `:time_usec`, `:utc_datetime`, `:utc_datetime_usec`, `{:array, type}`, and
  `{:map, type}`. The `:decimal` type needs the optional `:decimal` package,
  version 3.0 or later.
- `Commandex.Type` behaviour for custom types. A type can take options from the
  `param` line through the `init/1` and `cast/2` callbacks.
- `:required` option for `param`. A required parameter without a value gets a
  `:required` error.
- `new/1` adds an `:invalid` error for a value that does not cast, and halts a
  command that has an `:invalid` or `:required` error.
- `param` raises an `ArgumentError` at compile time for an unknown type, an unknown
  option, or a default that is not valid for the type.
- `Commandex.halt_on_errors/1` halts a command that has errors.
- Command structs have a `__meta__` field that holds a `Commandex.Metadata` struct
  with the parameter types.

## [0.5.2] - 2025-12-21

### Added

- `halt/2` optionally accepts a `success: true` flag, allowing the command to halt early
  successfully. ([#16](https://github.com/codedge-llc/commandex/pull/16))

## [0.5.1] - 2024-09-09

### Fixed

- `import_deps: [:commandex]` in `.formatter.exs` works again. ([#15](https://github.com/codedge-llc/commandex/pull/15))

## [0.5.0] - 2024-09-08

### Added

- `run/0` function for commands that don't define any parameters.

### Changed

- Raise `ArgumentError` if an invalid `pipeline` is defined.

## [0.4.1] - 2020-06-26

### Fixed

- Set `false` parameter correctly when given a Map of params. Was previously
  evaluating to `nil`.

## [0.4.0] - 2020-05-03

### Added

- Default typespecs and documentation for modules using Commandex.
  Note: this will break any existing modules that have `@type t` already defined.

## [0.3.0] - 2020-01-31

### Added

- `param` now supports a `:default` option. (eg. `param :limit, default: 10`)
- Added `new/0` to initialize commands without any parameters.
- `pipeline` can now use a 1-arity anonymous function. (eg. `pipeline &IO.inspect/1`)

## [0.2.0] - 2020-01-21

### Added

- Enhanced documentation to show `&run/1` shortcut

### Changed

- Renamed `:error` to `:errors` on Command struct

## [0.1.0] - 2020-01-18

- Initial release
