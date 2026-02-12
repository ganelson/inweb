# Tags

In very large webs, it can be useful to _tag_ certain paragraphs.

A tag is really just a textual label. Using our Markdown notation, tags can
be applied by hand to paragraphs which have titles like so:

	## Trigonometry ^"mathematical"

The effect of this heading is exactly like

	## Trigonometry

except that the tag `mathematical` is now attached to the paragraph in
question. `inweb inspect -tags` applied to this web will now show:

	web "Bezier" (Python program in MarkdownCode notation): 8 paragraphs : 102 lines

	tag          | paragraphs tagged                                                                 
	------------ | -----------------
	mathematical | 4

This produces a concordance of the tags used in a web. Here there's not much to
see since only one tag is used, and at the paragraph numbered §4 in a weave.
In a slightly larger web you might see something like:

	tag     | paragraphs tagged  
	------- | -----------------------
	Figures | cim:3              
	Tables  | tgs:2, rad:1.3, rad:1.4

Here, `Tables` can be found in §2 of the section abbreviated `tgs`, and §§1.3
and 1.4 of `rad`.

In a really large web, this table can be very large. `-only` can be used to restrict its
scope: `inweb inspect -tags -only 2`, for example, tabulates tags in Chapter 2,
and `inweb inspect -tags -only rad` gives us:

	tag     | paragraphs tagged  
	------- | -----------------
	Tables  | rad:1.3, rad:1.4

If the web contains modules, then by default only its main module is scanned,
but `-fuller` will cause the other modules to be included too.

Nameless paragraphs, sometimes useful to force a paragraph break, can also
be tagged:

	During his 42 years at Renault, Pierre Bézier devised the idea of control
	points to guide curves.

	## ^"mathematical"
	
	In fact, though, his opposite number Paul de Casteljau at the Citroën
	works was responsible for the best algorithm for computing these curves,
	$$ B(t) = \sum_{i=0}^n \beta_i b_{i, n}(t). $$

Multiple tags can be applied to the same paragraph:

	## Trigonometry ^"mathematical" ^"eldritch"

We could now, for example,

	$ inweb weave bezier.py.md -only-tagged-as mathematical
		generated: mathematical.html
		8 files copied to: bezier-assets

This makes a single stand-alone web page containing just those paragraphs
from the web with the given tag. (Even if the web contains many sections, which
would ordinarily weave to many HTML files, the extract here will just be one.)
This can be very useful to view a cross-section of related material from across
a large web.

A warning is printed if no paragraphs in the web matched:

	$ inweb weave bezier.py.md -only-tagged-as geometric
		generated: geometric.html
	    warning: no paragraphs were tagged 'geometric', so weave was empty
		8 files copied to: bezier-assets

Note that this is _not_ an error, and is not issued at all in `-silent` mode.

Tags can also be given a sort of memorandum field. If a tag text includes a
colon `:`, then the tag as such is the part before the (first) colon, and
anything after that is the memo. For example:

	## Trigonometry ^"mathematical: trig formulae"

This tags the paragraph `mathematical`; the text `trig formulae` is not thrown
away, though, and is used as a subheading in any woven page of the
`mathematical`-tagged material in the web.

## Tagging entire sections

If a web has a contents page, then an entire section can be given one or more
tags on the relevant line of the contents page. For example, the `foundation-module`
library used by Inweb includes this chapter in its contents:

	Chapter 1: Setting Up
	"Absolute basics."
		Foundation Module
		POSIX Platforms ^"ifdef-PLATFORM_POSIX"
		Windows Platform ^"ifdef-PLATFORM_WINDOWS"

The effect is that _every_ paragraph in the section `POSIX Platforms` is tagged
with `ifdef-PLATFORM_POSIX`, and similarly for `Windows Platform`.

## Conditional compilation

In C-like languages, tags can be used to tangle code inside of conditional
compilation directives. If a tag takes the form `ifdef-SYMBOL`, then the holon
in the paragraph (assuming there is one) is tangled in between the C directives
`#ifdef SYMBOL` and `#endif`; and similarly for `ifndef-SYMBOL`. So for example:

	## Test code. ^"ifdef-DEBUG"

	## Production code. ^"ifndef-DEBUG"

## Automatic tagging

Inweb silently tags paragraphs itself with certain built-in tags:

tag          | paragraph is tagged if...
------------ | ---------------------------------------------------------
`Outlinks`   | ...it includes a link to a web page outside the web/colony
`Audio`      | ...it includes embedded audio
`Video`      | ...it includes embedded video
`Figures`    | ...it includes an image
`Tables`     | ...it includes a table
`Downloads`  | ...it includes a downloadable file
`HTML`       | ...it includes an excerpt of arbitrary HTML
`Carousels`  | ...it includes a carousel of images
`Structures` | ...it defines a `typedef struct` in a C-like language
`Preform`    | ...it defines Preform grammar in an InC program

Inweb uses its ability to tag `Outlinks` (which is provided only when
commentary is in Markdown notation) to spot all external links from a
website it might be weaving. `inweb inspect -links` will tabulate these:

	inweb inspect -links smorgasbord
	web "Sorting Smorgasbord" (Python program in MarkdownCode notation): 2 sections : 11 paragraphs : 123 lines
	
	from   | external URL                                  
	------ | ----------------------------------------------
	cnsr:1 | https://en.wikipedia.org/wiki/Harold_H._Seward
	qcsr:1 | https://www.google.com     

Such URLs might occur in links like `[google](https://www.google.com)`, or
in image addresses on the wider web, or in Inweb links like `//this one -> https://en.wikipedia.org/wiki/Harold_H._Seward`.
