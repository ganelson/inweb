# InwebClassic Notation

## Example

Here is the same program used as an example in //A Little Literate Programming//,
but with its literate features written in `InwebClassic` rather than `MarkdownCode`
notation. The first thing to notice is that there are `@` marker signs scattered
at various line-beginnings throughout, which divide the web into paragraphs: when
using `MarkdownCode`, Inweb deduces paragraph boundaries, but here we write them
explicitly.

To start with, though, another concept not found in `MarkdownCode`: "limbo".
This term, coined by Knuth, refers to any chunk of material found before the
first `@` marker, and therefore not in any paragraph at all:

	Counting Sort.
	
	An implementation of the 1954 sort algorithm.

This contains a titling line — which, note, needs to end in a full stop — and
then an (optional) description of the purpose of the program. Unlike `MarkdownCode`,
this notation doesn't allow titling lines to be elaborated with author names,
version numbers and such. (`InwebClassic` was really a notation devised for
larger webs which have contents pages, where that can be spelled out fully.)

Here's the first paragraph. The `@` followed by at least one character of white
space marks the opening. All the verbiage from "This algorithm" through to "is returned"
is commentary. 
	
	@ This algorithm was found in 1954 by [Harold H. Seward](https://en.wikipedia.org/wiki/Harold_H._Seward),
	who also devised radix sort. They differ from most sorting techniques because they do
	not make comparisons between items in the unsorted array. Indeed, there are no
	comparisons in the following function, only iteration.
	
	This function takes an array of non-negative integers, sorts it, and returns
	the result. The test |if unsorted| means "if the unsorted array is not empty",
	and is needed because Python would otherwise handle this case badly: of course,
	if |unsorted| does equal |[]|, then so should |sorted|, and so the right answer
	is returned.

Note that commentary in this notation doesn't follow Markdown syntax. In fact, it's
much more limited in what markup can do: vertical strokes `|like this|` are used
to denote small code snippets, instead of Markdown's backticks; links, like
the one to Seward's Wikipedia page, are still recognised; so are mathematics
and footnotes, which use the same syntax. But most of Markdown is unavailable.

We now pass to some code. This is a top-level holon, indicated by an equals
sign `=` in the first column of a line:

	=
	def countingSort(unsorted):
		sorted = []
		if unsorted:
			@<initialise...@>
			@<tally how many times each value occurs in the unsorted array@>
			@<construct the sorted array with the right number of each value@>
		return sorted

Note that holon names are written in `@<` and `@>` markers, instead of `{{` and `}}`
as in `MarkdownCode`. In the next paragraph, one of those is defined:
	
	@ For example, suppose the array is initially |[4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]|.
	Then the maximum value is 6. Python arrays index from 0, so we need an incidence
	counts array of size 7, and we create it as |[0, 0, 0, 0, 0, 0, 0]|.
	
	@<initialise the incidence counts to zero@> =
		max_val = max(unsorted)
		counts = [0] * (max_val + 1)

In that paragraph, then, the commentary section ended and the code segment began
with the line `@<initialise the incidence counts to zero@> =`, making clear that
this is a named holon, not a top-level and nameless one.

The program continues in similar vein:

	@ In the unsorted array we will observe no 0s, one 1, three 2s, and so on. The
	following produces the counts |[0, 1, 3, 3, 1, 1, 2]|.
	
	@<tally how many times each value occurs in the unsorted array@> =
		for value in unsorted:
			counts[value] += 1
	
	@ Unusually for a sorting algorithm, an entirely new sorted array is created,
	using only the incidence counts as a sort of program. We fill |sorted|
	with no |0|s, one |1|, three |2|s, and so on, producing |[1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]|.[1]
	
	[1] The unsorted array is no longer needed, in fact, and so we could easily make this
	algorithm "sort in place" by simply rewriting |unsorted|, rather than making
	a new array.
	
	@<construct the sorted array with the right number of each value@> =
		for value, count in enumerate(counts):
			sorted.extend([value] * count)	
	
	@ And this code tests the function:
	
	=
	A = [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
	print("Unsorted:", A)
	print("Sorted:", countingSort(A))
	
	@ During his 42 years at Renault, Pierre Bézier devised the idea of control
	points to guide curves.

	In fact, though, his opposite number Paul de Casteljau at the Citroën
	works was responsible for the best algorithm for computing these curves,
	$$ B(t) = \sum_{i=0}^n \beta_i b_{i, n}(t). $$

## Paragraph structure

Paragraphs consist of three segments, all optional, but which must occur in the
following order: commentary, definitions, code.

A paragraph usually begins in one of these two ways:

	@ A simple marker, which begins a standard paragraph. Any text on the
	line after the marker is commentary, which continues on subsequent lines.

	@h A Heading.
	Note the h, and that a (short) subtitle then follows, up to the full stop.
	Commentary can then begin, though it's better style to start on the
	line following.

A paragraph can be given one or more tags thus:

	@ ^"Tag1" ^"Tag2"
	Commentary begins here.
	
	@h Another Heading. ^"Tag1" ^"Tag2"
	Commentary begins here.

It is also possible to begin a paragraph without commentary or definitions,
going straight into the code segment like so:

	@ =
		...

This is an abbreviation for:

	@
	
	=
		...

There's one last possibility: if the paragraph follows immediately after
some code, or is the opening paragraph, then it can also begin like so:

	@<Named holon@> =
		...

which, once again, makes a paragraph containing only code.

Any definitions must be made after the commentary (and automatically end it). The
simplest definitions are like preprocessor definitions in C:

	@d TERM DEFINITION

The definition can run across multiple lines, though it usually does not.
So, for example,

    @d NUMBER_TEST_RUNS 100
	@d TEST_FUNCTION(name)
		name(NUMBER_TEST_RUNS);

`@define` can be used to spell out `@d`, though the abbreviation is more often used.
A variation on this is:

	@default TERM DEFINITION

which only defines `TERM` if it hasn't already been defined.

Finally, `@e` or `@enumerate` define an enumerated value. The rule here is that
terms in a given "family" are given sequential values automatically. For example:

	@e BLUE_COLOUR from 1
	@e MAGENTA_COLOUR
	@e CRIMSON_COLOUR

defines these three terms with the values 1, 2, 3. The family resemblance is that
they all end `_COLOUR`.

Commentary or definitions then end automatically, and we go into the code segment
of the paragraph, if either the "nameless holon" syntax is used — that is, an
equals sign in column 1:

	=
	...

...or if the "named holon" syntax is used:

	@<Named holon@> =
		...

As in `MarkdownCode`, holons can be continued:

	@<Previously defined holon@> +=
		...

Early code is written like so:

	= (early code)

and similarly for `= (very early code)`, `= (late code)` and `= (very late code)`.

So for example here is a paragraph under a subheading, and which contains all
three possible segments:

	@h Example paragraph.
	This shows all three possible parts.
	
	@d ENDED_SAFELY 0
	
	=
	int main(int argc, char *argv[]) {
		return ENDED_SAFELY;
	}

## Commentary syntax

As noted above, this is (by default) neither Markdown nor TeX — though note
that this can be changed by applying //Conventions//. `InwebClassic` notation
has the convention `commentary uses simplified markup` by default, and that
is indeed simple:

- code excerpts use vertical strokes `|like this|`;
- mathematics is written in dollar signs, as in `$n^2$`;
- and displayed mathematics in double-dollar signs;
- footnotes are written in square brackets, `[1]`, and follow the same
  conventions as in Markdown commentary;
- links are written either `//thus//` or in Markdown syntax, and follow the
  same conventions as in Markdown commentary;
- quotations are introduced `>>`.

As an example of the latter:

	>> You sit on the veranda drinking tea and your ducklings swim on the pond,
	and everything smells good... and there are gooseberries. (Anton Chekhov)

A particular difference is the way that quoted text, or code from a different
program entirely, is written. In Markdown, this would simply be indented.

	= (text)
	This is some plain text being quoted.
	=

Note that it begins and ends with `=` markers, but that these do not end the
commentary section. The request for "text" can be varied:

	= (text as code)

	= (text as LANGUAGE)

Text can also be drawn from an external file, in which case there are no
subsequent lines of textual content, of course, and no end marker:

	= (text from FILE)

	= (text from FILE as code)

	= (text from FILE as LANGUAGE)

And the word `text` can be prefaced with either or both of the keywords
`hyperlinked` and `undisplayed`.

A similar notation can be used to include a variety of gadgets into the
commentary segment of a paragraph. These all use the `=` marker, but with
different bracketed explanations. Some of these are stand-alone, and are
better demonstrated by examples than with specifications. We can put audio
and video players into the woven commentary which will play files included
in a web:

	= (audio SP014.mp3)

	= (video DW014.mp4)

Or we can put in embedded audio or video players calling on external resources:

	= (embedded YouTube video GR3aImy7dWw)

	= (embedded Vimeo video 204519)

	= (embedded SoundCloud audio 42803139)

	= (embedded Vimeo video 204519 at 400 by 300)

	= (embedded SoundCloud audio 42803139 at height 200)

The latter sets just the height (of the displayed waveform, that is —
arguably music has width and not height, but SoundCloud thinks otherwise).

This splices in some HTML code from a file in the web's `HTML` subdirectory,
assuming it has one. (Single-file webs cannot use this feature.)

	= (html fireworks.html)

Similarly, we can have downloads:

	= (download alice.crt "certificate file")

The file to download, in this case `alice.crt`, must be placed in a `Downloads`
subdirectory of the web. The explanatory text — usually just an indication
of what sort of file this is — is optional.


	= (figure MATERIAL "SECOND")
	= (figure MATERIAL)

To embed an image, we write like so:

	= (figure Wotsit.jpg)

	= (figure Whatever.jpg at width 500)

	= (figure Something.jpg at height 2cm)

Dimensions given in cm are scaled at 72 times dimensions given without a
measurement; in practice, rendering to TeX produces roughly the number of
centimeters asked for, and rendering to HTML makes the image width or height
correspond. If you really want to monkey with the aspect ratio,

	= (figure Whatever.jpg at 20 by 100)

A carousel is a slide-show of (usually but not always) figures; there's a
set of slides with captions, only one of which is visible at a time.

	= (carousel "Royal Albert Hall, London: King Crimson's 50th Anniversary Concert")
	= (figure rah.jpg)
	= (carousel "Brighton Beach")
	= (figure brighton.jpg)
	= (carousel "Roman Amphitheatre, Pula")
	= (figure pula.jpg)
	= (carousel "St Mark's Basilica, Venice")
	= (figure venice.jpg)
	= (carousel end)

That carousel contained only figures, but almost any material can go into the
slides, paragraph breaks excepted. For example:

	= (carousel "Stage 1 - Raw tree" above)
	= (text as BoxArt)
		ROOT ---> DOCUMENT
	=
	= (carousel "Stage 2 - Developed tree" above)
	= (text as BoxArt)
		ROOT ---> DOCUMENT
					|
				  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
	=
	= (carousel "Stage 3 - Completed tree" above)
	= (text as BoxArt)
		ROOT ---> DOCUMENT
					|
				  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
					|            |            |
				  text 1       text 2       text 3  ...
	=
	= (carousel end)

This carousel has differently placed captions, too: that's because the
slide lines were typed as:

	= (carousel "Stage 2 - Developed tree" above)

and the like. By default, a caption overlaps slightly with the content; but
it can also be `above` or `below`. A slide can also have no caption at all:

	= (carousel)
	= (figure anonymous.jpg)
	= (carousel)
	= (figure furtive.jpg)
	= (carousel end)
