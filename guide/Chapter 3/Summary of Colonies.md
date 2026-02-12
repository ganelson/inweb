# Summary of Colonies

This has been a lengthy tour, but the basic point should be clear enough: except
perhaps for the simplest of one-program websites, every endeavour with Inweb
will likely benefit from being organised into a colony. To sum up:

* A colony has 1 or more members, each declared by `member:`, unless it is
  from a different colony entirely, in which case `external:`.
* Each member has a _name_, and can optionally supply one or more of:
  - a _location_ using `at`,
  - a _website path_ using `to`,
  - a choice of _navigation links_ using `navigation`,
  - a choice of _breadcrumb links_ using `breadcrumbs`, and/or
  - a weaving _pattern_ using `pattern`.
* A line reading `default:` and then some of these clauses sets some default
  values for `navigation`, `breadcrumbs` and/or `pattern` which apply to
  subsequent members until cancelled by a change of `default:`.
* A colony can also contain declarations of:
  - single pages of commentary with `Page "name" { ... }`,
  - contents pages for a whole web with `Web "name" { ... }`,
  - language declarations with `Language "name" { ... }`,
  - notation declarations with `Notation "name" { ... }`, and/or
  - conventions to apply to colony members with `Conventions { ... }`.
* The command `inweb map COLONY` shows a sitemap, and `inweb map -fuller COLONY`
  a more extensive one. `COLONY` need not be specified if the current working
  directory contains the relevant `colony.inweb` file.
* Other Inweb commands can refer to members of a colony as `COLONY::MEMBER` or,
  if again Inweb can see the colony in the cwd, simply `::MEMBER`.
* `inweb weave` and `inweb tangle` can be applied to a colony instead of a web,
  in which case they act on each (internal) member of the colony in turn.
