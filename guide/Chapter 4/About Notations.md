# About Notations

## Introduction

A _notation_ is a form of markup for a web which tells Inweb how to decide
which parts are commentary, which parts are program, and so on. In the chapters
of this guide so far, a notation called `MarkdownCode` has always been used:
a lightweight sort of notation closely based on Markdown.

However, a good LP tool should allow for multiple notations, both because tastes
vary and because some notations work better with particular languages than others.
Inweb goes further and allows users to create their own notations, and this is
a real help for an under-appreciated use case: showcasing classic programs which
do contain commentary, but were never written as literate programs by their authors.

## How Inweb decides on the notation for a web

Clearly Inweb cannot read a web without knowing its notation, and this is not
always obvious. Here is how it decides:

-	A web large enough to have a contents page can explicitly declare its notation,
	as in this example:

		Title: Sorting Smorgasbord
		Author: Various Artists
		Notation: MarkdownCode
		Language: Python
		Version Number: 3.0.1
	
		Sections
			Counting Sort
			Quick Sort

	Here the line `Notation: MarkdownCode` decides the matter. Note that every
	notation has its own name; that needs to be a resource visible from the web.
	(Note also that contents pages have the same syntax regardless of notation.)

-	If a web has a contents page, but does not say what the notation is, then:

	-	if the section filenames have the extension `.md`, it will be `MarkdownCode`;
	-	if `.w`, then `InwebClassic`.

-	A single-file web, which doesn't have a contents page, can use a filename
	extension to indicate its notation:
	
	-	the extension `.md` indicates `MarkdownCode`;
	-	the extension `.w` indicates `InwebClassic`;
	-	the extension `.cweb` indicates `CWEB`;
	-	the extension `.web` indicates `WEB`;
	-	and any newly-constructed notation can say what extensions it recognises.

## The notations supplied with Inweb

`MarkdownCode` is the simplest notation Inweb supports. It's intended to be
easy to pick up, and also to have the convenience that a web using this
notation renders well in a Markdown viewer — for example, if such a source
code file is viewed at GitHub.

`InwebClassic` is a more traditional LP notation, in that paragraph and code
boundaries are explicitly marked. This increases the amount of markup needed,
but some people find this clearer. It also provides for automated definitions
and enumerations when coding in C-like languages, and for that reason is used
by the Inform project. But since the commentary uses the same Markdown syntax as
`MarkdownCode`, the two notations are not as different as they may appear at
first sight.

`CWEB` is a partial compatibility mode with Knuth's CWEB tool. It is able to
tangle, and to weave to HTML, at least some of his programs of the last
forty years, more or less adequately. Here, commentary uses TeX, not
conventional Markdown.

`WEB` is an even more partial compatibility mode for Knuth's early WEB tool.
It can only usefully weave, not tangle, and even then, quite imperfectly.
WEB is used today only for the ${\rm\TeX}$ and Metafont source code, and there
is little point in tangling these, since they are written in a long-obsolete
form of Pascal. Again, commentary uses TeX.

As we shall see, though, it's easy to create entirely new notations.
