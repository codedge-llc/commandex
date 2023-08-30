# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2023-08-30

### Wardened

- Updated deps.

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
