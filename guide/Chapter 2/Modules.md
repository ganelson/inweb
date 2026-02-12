# Modules

One goal of Inweb is to scale from tiny to enormous webs without too
much effort. A project can begin as a single-file web, grow to the point
where it needs to be broken up into multiple sections and given a contents
page, and grow further until the sections need to be divided up into chapters.

But what then? The Inform compiler has 793 sections, divided into 146 chapters.
No single book should have 146 chapters.

The answer is that Inweb supports a still larger-scale grouping, _module_.
A module is just a web, but one which is not tangled independently: it doesn't
make a stand-alone program, it provides a component for other webs to use.
Inform is therefore broken up into 27 different webs, one of which is `inform7`,
the web itself, and the other 26 of which are its modules. So the average
module has about six chapters, and the average chapter has about six sections.

For a more modest example, suppose we want `smorgasbord` to use a module called
`random-arrays` which might, say, provide random lists of numbers to try
sorting. The contents page might then read:

	Title: Sorting Smorgasbord
	Author: Various Artists
	Notation: MarkdownCode
	Language: Python
	Version Number: 3.0.1

	Import: random-arrays

	Sections
		Counting Sort
		Quick Sort

The line `Import: random-arrays` says that this second web provides a block
of material forming part of the program. This second web is exactly like a
regular web, though it has to be a multi-file one with a contents page, except
that its directory name must end `-module`. In this case, then, Inweb looks
for a directory called `random-arrays-module`.

How does Inweb know where to find `random-arrays-module`? It tries three
locations in turn when looking for a module:

- the inside of the web making the import, that is, its own directory;
- the outside of that web, that is, the directory containing it;
- Inweb's own interior, wherever that is on the user's computer, but
  only if the module asked for was called `foundation` or `literate`.

In this case, then, if `smorgasbord` is inside the directory `programs`,
then Inweb would first try `programs/smorgasbord/random-arrays-module`, and
then, if that failed, `programs/random-arrays-module`.

And the third possibility does not arise. Inweb contains just two modules,
`foundation` and `literate`, and both are written in a dialect of C called InC.
One is a general-purpose library wrapping and considerably extending the C
standard library, and the other contains literate-programming functions which
are essentially the whole Inweb engine. (Inweb itself is really just a
command-line interface to this module.)

Two notes for power users of this feature:

* The import location can be a path, as in `Import: services/words`. This
  is then applied relative to the locations given above.

* Modules can themselves import other modules, and so on: they form a dependency
  tree. But less is more. It doesn't seem to be very helpful to have elaborate
  import pathways.
