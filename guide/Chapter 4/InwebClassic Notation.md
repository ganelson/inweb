# InwebClassic Notation

Despite first appearances — when it seems full of mysterious `@` and `=` signs —
`InwebClassic` is quite similar to the `MarkdownCode` notation used in the rest
of this guide. The differences are:

- Paragraph boundaries are explicitly marked with `@` or `@h`.
- Code boundaries are explicitly marked with `=`.
- In C-like languages, definitions and enumerations can be made with `@d` and `@e`.
- Commentary has additional notations for embedding video, carousels, and such.

`InwebClassic` is a little heavier on the eye, then, but reads easily enough
with practice, and does have some advantages. The source code of Inweb is
itself written in `InwebClassic` notation.

## Example

Here is the same program used as an example in //A Little Literate Programming//,
but with its literate features written in `InwebClassic` rather than `MarkdownCode`
notation. The first thing to notice is that there are `@` marker signs scattered
at various line-beginnings throughout, which divide the web into paragraphs: when
using `MarkdownCode`, Inweb deduces paragraph boundaries, but here we write them
explicitly. Similarly, the dividing point between commentary and code is written
explicitly with `=` markers.

The fact that paragraphs begin at `@` markers open up a possibility not found
in `MarkdownCode`: there can be lines at the start of a section in "limbo".
This term, coined by Knuth, refers to any chunk of material found before the
first `@` marker, and therefore not in any paragraph at all:

	Counting Sort.
	
	An implementation of the 1954 sort algorithm.
	
	@ The first para has just begun, and...

This limbo contains a titling line — which, note, needs to end in a full stop — and
then an (optional) description of the purpose of the program. Unlike `MarkdownCode`,
this notation doesn't allow titling lines to be elaborated with author names,
version numbers and such. (`InwebClassic` was really a notation devised for
larger webs which have contents pages, where that can be spelled out fully.)

Here's the actual first paragraph. The `@` followed by at least one character of white
space marks the opening. All the verbiage from "This algorithm" through to "is returned"
is commentary. 
	
	@ This algorithm was found in 1954 by [Harold H. Seward](https://en.wikipedia.org/wiki/Harold_H._Seward),
	who also devised radix sort. They differ from most sorting techniques because they do
	not make comparisons between items in the unsorted array. Indeed, there are no
	comparisons in the following function, only iteration.
	
	This function takes an array of non-negative integers, sorts it, and returns
	the result. The test `if unsorted` means "if the unsorted array is not empty",
	and is needed because Python would otherwise handle this case badly: of course,
	if `unsorted` does equal `[]`, then so should `sorted`, and so the right answer
	is returned.

Once again, the commentary itself uses Markdown notation, so we see the familiar
backticks for code snippets, for example.

Now for some code. The following is a top-level holon, indicated by an equals
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
	
	@ For example, suppose the array is initially `[4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]`.
	Then the maximum value is 6. Python arrays index from 0, so we need an incidence
	counts array of size 7, and we create it as `[0, 0, 0, 0, 0, 0, 0]`.
	
	@<initialise the incidence counts to zero@> =
		max_val = max(unsorted)
		counts = [0] * (max_val + 1)

In that paragraph, then, the commentary section ended and the code segment began
with the line `@<initialise the incidence counts to zero@> =`, making clear that
this is a named holon, not a top-level and nameless one.

The program continues in similar vein:

	@ In the unsorted array we will observe no 0s, one 1, three 2s, and so on. The
	following produces the counts `[0, 1, 3, 3, 1, 1, 2]`.
	
	@<tally how many times each value occurs in the unsorted array@> =
		for value in unsorted:
			counts[value] += 1
	
	@ Unusually for a sorting algorithm, an entirely new sorted array is created,
	using only the incidence counts as a sort of program. We fill `sorted`
	with no `0`s, one `1`, three `2`s, and so on, producing `[1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]`.[1]
	
	[1] The unsorted array is no longer needed, in fact, and so we could easily make this
	algorithm "sort in place" by simply rewriting `unsorted`, rather than making
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

A carousel is a slide-show of (usually but not always) figures; there's a
set of slides with captions, only one of which is visible at a time.

	= (carousel "Royal Albert Hall, London: King Crimson's 50th Anniversary Concert")
	![The Royal Albert Hall at night.](rah.jpg)
	= (carousel "Brighton Beach")
	![Brighton beach by day.](brighton.jpg)
	= (figure brighton.jpg)
	![Roman amphitheatre in a bay.](pula.jpg)
	= (carousel "St Mark's Basilica, Venice")
	![St Mark's Basilica.](venice.jpg)
	= (carousel end)

That carousel contained only figures, but almost any material can go into the
slides, paragraph breaks excepted. For example:

	= (carousel "Stage 1 - Raw tree" above)
	``` BoxArt
		ROOT ---> DOCUMENT
	```
	= (carousel "Stage 2 - Developed tree" above)
	``` BoxArt
		ROOT ---> DOCUMENT
					|
				  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
	```
	= (carousel "Stage 3 - Completed tree" above)
	``` BoxArt
		ROOT ---> DOCUMENT
					|
				  NODE 1  ---  NODE 2  ---  NODE 3  --- ...
					|            |            |
				  text 1       text 2       text 3  ...
	```
	= (carousel end)

This carousel has differently placed captions, too: that's because the
slide lines were typed as:

	= (carousel "Stage 2 - Developed tree" above)

and the like. By default, a caption overlaps slightly with the content; but
it can also be `above` or `below`. A slide can also have no caption at all:

	= (carousel)
	![A faceless figure.](anonymous.jpg)
	= (carousel)
	![A figure with back turned.](furtive.jpg)
	= (carousel end)

## Mildly deprecated syntaxes

For reasons going back to earlier versions of Inweb, the notation also provides
a way to impose images:

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

But note that these figures can all be achieved with (more or less) regular
Markdown just as easily:

	![This is a doohickey.](Wotsit.jpg)

	![This is a rescaled doohickey.](Wotsit.jpg@20x100)

That is, the same conventions used for images in `MarkdownCode` work just
as well here.

Inweb historically provided this syntax:

	>> You sit on the veranda drinking tea and your ducklings swim on the pond,
	and everything smells good... and there are gooseberries. (Anton Chekhov)

for a block quotation; but the more standard Markdown syntax should now be
used, with leading `>` signs on each line:

	> You sit on the veranda drinking tea and your ducklings swim on the pond,
	> and everything smells good... and there are gooseberries. (Anton Chekhov)

Similarly, there are some now-redundant syntaxes for incorporating blocks
of quoted code which are not part of the program. This:

	Consider the following code sample:

	= (text)
	int whatever(int x, char *y) {
	}
	=

is equivalent to an indented Markdown code extract, like so:

	Consider the following code sample:

		int whatever(int x, char *y) {
		}

or equally to a fenced Markdown code extract, like so:

	Consider the following code sample:

	```
	int whatever(int x, char *y) {
	}
	```

The material in the quotation is syntax-coloured following the conventions
of the language used in the program of the current web. Those can be overridden
by specifying a language with a fenced Markdown extract, thus:

	Consider the following code sample:

	``` ConsoleText
    $ inweb tangle countsort.py.md -to unexpected.py
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'unexpected.py'
	```

This is equivalent to the older notation:

	Consider the following code sample:

	= (text as ConsoleText)
    $ inweb tangle countsort.py.md -to unexpected.py
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'unexpected.py'
	=

Text was traditionally inserted from an external file with syntaxes like:

	= (text from FILE)

	= (text from FILE as code)

	= (text from FILE as LANGUAGE)

This should now be done thus:

	![text](FILE)
	
	![text as LANGUAGE](FILE)

Downloads were likewise historically written like so:

	= (download alice.crt "certificate file")

but this is now preferred:

	![download: certificate file](alice.crt)
