# Changelog

## v0.4.1

- Set `false` parameter correctly when given a Map of params. Was previously
  evaluating to `nil`.

## v0.4.0

- Default typespecs and documentation for modules using Commandex.
  Note: this will break any existing modules that have `@type t` already defined.

## v0.3.0

- `param` now supports a `:default` option. (eg. `param :limit, default: 10`)
- Added `new/0` to initialize commands without any parameters.
- `pipeline` can now use a 1-arity anonymous function. (eg. `pipeline &IO.inspect/1`)

## v0.2.0

- Renamed `:error` to `:errors` on Command struct
- Enhanced documentation to show `&run/1` shortcut

## v0.1.0

- Initial release
