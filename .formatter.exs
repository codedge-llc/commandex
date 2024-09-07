locals_without_parens = [
  param: 1,
  param: 2,
  param: 3,
  data: 1,
  pipeline: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
