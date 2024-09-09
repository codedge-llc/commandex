defmodule Commandex.TypeTest do
  use ExUnit.Case

  doctest Commandex.Type, import: true
  doctest Commandex.Type.Boolean, import: true
  doctest Commandex.Type.Float, import: true
  doctest Commandex.Type.Integer, import: true
  doctest Commandex.Type.String, import: true
end
