# About Patterns

Every weave is makes use of a _pattern_. The same web can look very different
when woven with two different patterns; and a pattern can, in principle, be
used with many different webs.

Like languages and notations, patterns are resources identified by their names. 
The default pattern is called `HTML`:

	$ inweb weave pyramid.c.w
	weaving web "Hilbert's Pyramid" (C program in MarkdownCode notation) as HTML

Note the `as HTML` at the end of that line. Whereas:

	$ inweb weave pyramid.c.w -as GitHubPages
	weaving web "Hilbert's Pyramid" (C program in MarkdownCode notation) as GitHubPages

That's to say, running the `inweb weave` command with the switch `-as NAME`
tells Inweb to use the pattern called `NAME`.

Creating a whole new pattern is not as major an undertaking as it may first
seem. Patterns can also be _based on_ other patterns: for example, `GitHubPages`
is based on `HTML`. It changes a few things, it adds a few things, but it
doesn't need to sort out the many little details of making a web page.
Anyone wanting to weave to web pages, but to pages which look different from
Inweb's usual output, is almost certainly best advised to make a new pattern
based on `HTML` (a generic sort of page-builder), and go from there.

## Where patterns are declared

As mentioned above, a pattern is an Inweb resource, so it must have a declaration.
But unlike (say) languages, this can't be declared inside of another declaration:
it has to be in its own file, which contains nothing else. That's because a
pattern is seldom just the declaration: it almost always comes with a suite
of other files — holding HTML, Javascript code, CSS styles, TeX macros,
images, or whatever else might be needed. So in practice

- a pattern called `NAME` should occupy a directory also called `NAME`, in which
- the actual declaration is in a text file called `NAME.inweb`.

As with other Inweb resources, patterns can only be used if Inweb can see them.
Inweb has a handful of patterns built in, such as `HTML` and `GitHubPages`.
Otherwise:

- `-using DIRECTORY` will tell Inweb it can use the pattern in that directory; or
- if a web is a multi-file web stored in a directory, and that directory has a
  subdirectory called `Patterns`, then Inweb will be able to see all patterns
  in that directory when weaving the web; or
- if a colony declaration includes `patterns: DIRECTORY`, then Inweb will be
  able to see all patterns in that directory when weaving any web from the colony.
