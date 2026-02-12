# README Files

Almost all repositories at Github have a file called `README.md`, in Markdown
format, which describes what the program is, how to install it, and so on.

Inweb provides a convenient way to keep such files up to date. Suppose we
take our example web `smorgasbord`, and create a _script_ `smorgasbord.rmscript`
inside it, reading:

	# Sorting Smorgasbord
	
	This is version {metadata: Semantic Version Number}, dated {metadata: Build Date}.

As part of the build process for the program, we can include this command:

	$ inweb make-readme smorgasbord
	smorgasbord/smorgasbord.rmscript -> smorgasbord/README.md

And this will create the `README.md` with contents such as:

	# Sorting Smorgasbord
	
	This is version 1-early-beta+1A02, dated 21 December 2025.

Optional switches allow both the script and destination file to be changed:
`inweb make-readme WEB -script S -to RM` creates a file `RM` from the script `S`
in the context of the web `WEB`, and similarly for a colony instead of a web.

If `-script` is not specified, Inweb first tries `smorgasbord.rmscript`
and then `scripts/smorgasbord.rmscript` in the web (or colony) directory,
which for this example is `smorgasbord`: if neither file exists, Inweb throws
an error. If `-to` is not specified, Inweb assumes `README.md` in the web (or
colony) directory. If `-to` is set to `-`, Inweb writes to standard output
instead of to a file:

	$ inweb make-readme smorgasbord -to -
	# Sorting Smorgasbord
	
	This is version 1-early-beta+1A02, dated 21 December 2025.

Mostly, whatever is in the script copies directly through into the output, but
three characters have special rules:

- Braces `{` and `}` must be used in neatly paired ways: and their
  contents have to be meaningful to Inweb, or an error is thrown.
- Literal braces can be obtained with `\{` and `\}`,
- Literal tabs and newlines can be written `\t` and `\n`, and of course
- Literal backslashes can be obtained with `\\`.

A usage of braces is called an _expansion_, and:

- `{web}` expands to the colony member name for the web named
  in the command (or, if a colony is named, for the _first_ web in that colony).

- `{list-of-webs}` expands to a comma-separated list of colony member names for
  the colony named in the command; or, if a web is named, to the colony it
  belongs to; or, if it does not belong to a colony, then just to a list with
  one member, the name of the web. In effect, `{list-of-webs}` expands to
  everything Inweb can see.

- `{metadata: DATUM}` expands to the metadata of that name for the web named
  in the command (or, if a colony is named, for the _first_ web in that colony).
  To see the possible choices of `DATUM`, see //Metadata//.

- `{metadata: DATUM of: WEB}` expands to the metadata of that name for the web
  given. This only makes sense for a colony, and `WEB` can then be the name of
  a colony member.

- `{set name: VARIABLE to: TEXT}` creates a new _variable_ with the given
  context, and `{VARIABLE}` thereafter expands to its value. Variable names
  are always in full capitals, and contain no spaces. For example:
  
      {set name: URL to: https://www.inform7.com}
      See [the project home page]({URL}) for more.
  
  would expand to:
  
      See [the project home page](https://www.inform7.com) for more.

- `{repeat with VARIABLE in LIST}` followed in due course by `{end-repeat}`
  causes material to be generated over and over. For example,
  
      {repeat with SEA in Black, Caspian}
      Welcome to the {SEA} Sea.
      {end-repeat}

  expands to

      Welcome to the Black Sea.
      Welcome to the Caspian Sea.

  and

      Seas available:{repeat with SEA in Sargasso, Libyan} {SEA} Sea;{end-repeat}

  expands to

      Seas available: Sargasso Sea; Libyan Sea;

- `{define: NAME}` or `{define: NAME ARGUMENTS}` followed in due course by `{end-define}`
  creates a new expansion. For example,
  
      {define: describe content: STUFF}
      Also available here is {STUFF}.
      {end-define}
      {describe content: inbuild}
      {describe content: infix}

  expands to
  
      Also available here is inbuild.
      Also available here is infix.

  Here the `NAME` is `describe` and the `ARGUMENTS` part is `content: STUFF`.
  There can be any number of arguments; if the argument name is preceded by `?`
  then it is optional.

So for example, this produces a table of all the webs in the current colony:

	Title | Current version | Build date
	----- | --------------- | ----------
	{repeat with: W in: {list-of-webs}}
	{metadata: Title of: {W}} | {metadata: Semantic Version Number of: {W}} | {metadata: Build Date of: {W}}
	{end-repeat}

And this would be a script for a generic read-me file which could be used to
make individual `README.md` files for multiple colony members:

	# {metadata: Title} version {metadata: Semantic Version Number}
	
	This is version {metadata: Semantic Version Number}, dated {metadata: Build Date}.
	It can be tangled with `inweb tangle ::{web}`.

## Conveniences for Inform

Two other expansions are available which are almost certainly useful only for
the Inform project. `{version ...}` and `{date ...}` produce a version number
and date for a piece of software in a repository which is not necessarily a
colony member, because it is not necessarily a web. Specifically:

- `{version web:W}` does the same as `{metadata: Version Number on: W}`, for
  completeness.

- `{version program:P}` looks in the directory `P` (relative to the current
  colony) for a file called `README.txt` or `README.md`, then scans it.
  It looks for the patterns `CheapGlk Library: N` or `- Version N`, where
  `N` is the version number.

- `{version extension:E}` looks at the Inform extension file (it has to be
  a single file) `E`, reckoned relative to the colony, and extracts a
  version number from its header.

- `{version template:T}` does similarly for an Inform template (note: not
  an Inweb one) `T`.

- `{version inform6:C}` does similarly for a source tree of the Inform 6
  compiler, located at path `C` with respect to the current colony.

And `{date ...}` is similar, but less likely to find anything, because
these do not all record dates as well as version numbers.
