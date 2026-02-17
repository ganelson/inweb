# Summary of Notations

A notation declaration must be enclosed thus:

	Notation "NAME" {
		...
	}

where the body `...` consists of blank lines, or of any of the following,
given in any order:

*	`name "NAME"`. Now deprecated: an alternative way to supply the name.

*	`recognise .EXTENSION`. A source file with this filename extension will
	be assumed to follow this notation, in the absence of instructions to the
	contrary.

*	`recognise .*.EXTENSION`. Ditto, but here an extension (`*`) representing
	a programming language can also be given.

*	`classify`, followed by match lines, followed by `end`. If a declaration
	contains multiple `classify` blocks, they are concatenated. This determines
	how a line of literate source is classified: whether it's a heading, is code,
	or is commentary, and so on.

*	`options of OUTCOME`, followed by match lines, followed by `end`. This
	tells Inweb how to deal with text left in the `OPTIONS` wildcard after
	a line has been classified as `OUTCOME`.

*	`residue of OUTCOME`, followed by match lines, followed by `end`. This
	tells Inweb how to deal with text left in the `RESIDUE` wildcard after
	a line has been classified as `OUTCOME`. Any text unmatched, or left
	over, will be construed as an additional line of source.

*	`process code`, followed by processing lines, followed by `end`. This
	rewrites code (only) after all classification is complete.

*	`process commentary`, followed by processing lines, followed by `end`. This
	rewrites commentary (only) after all classification is complete.

*	`preprocess`, followed by processing lines, followed by `end`. This
	rewrites all source text immediately before classification begins.

*	`postprocess`, followed by processing lines, followed by `end`. This
	rewrites all source text immediately after classification is made,
	applying to everything, regardless of what the outcome was.

## Classification line syntax

Within a classifier, each (non-white-space) line must take one of the following
shapes:

- _pattern_ `==>` _outcome_
- _pattern_ `==>` _outcome_ `if` _condition_
- _pattern_ `==>` _outcome_ `if not` _condition_

The _outcome_ can be any of:

- _main-outcome_
- _main-outcome_ `with` _option_
- _main-outcome_ `in new paragraph`
- _main-outcome_ `with` _option_ `in new paragraph`

The `in new paragraph` note tells Inweb that a new paragraph should be forced
immediately prior to this line, so that the line forms the first thing in it.
(Such a paragraph will have no subtitle attached, of course.) Note that the
main outcome `beginparagraph` should not be given the `in new paragraph` note:
that achieves a paragraph break by more regular means.

Note that comments are not allowed in a classifier: too much risk of misunderstanding.

### Patterns

The _pattern_ part is read as literal text, by default: in other words, it has
to match exactly. However, certain "wildcards" are allowed which break this rule:

- The wildcards `MATERIAL`, `SECOND`, `THIRD` and `FOURTH` can absorb any non-empty
text. The text put into them is then used for different purposes depending on the
outcome.

- Wildcards can be qualified by being immediately followed with `(NONWHITESPACE)`.
Thus `MATERIAL(NONWHITESPACE)` would not match any text containing spaces or tabs.
At the other extreme, `MATERIAL(WHITESPACE)` would only match a run of spaces and tabs.
`MATERIAL(DIGITS)` requires it to contain only decimal digits.

- The special wildcards `RESIDUE` and `OPTIONS` behave exactly like the other four,
except that content in them is put through further classification after a successful
match. See //Creating Notations// for more.

### Conditions

The valid conditions are:

condition                    | holds provided
---------------------------- | --------------
`on first line`              | at the top of any file in the literate source
`on first line of only file` | at the top of a single-file web (and never in a multi-file web)
`following title`            | in lines following `title`
`in extract context`         | previous line was code, or a text extract, or a named holon declaration, or a nameless holon marker
`in holon context`           | `in extract context` where the extract is a holon
`in textextract context`     | `in extract context` where the extract is not a holon
`in definition context`      | previous line was `definition` or `defaultdefinition` or `definitioncontinued`
`in indented context`        | line occurs in a separated block of indented lines

The valid outcomes are a longer trawl, so they'll be grouped loosely by function.

### Headings

`title` should normally be used only at the top of a file. For a single-file web,
it can indicate the title (and sometimes also authorship and version) of the
program; for a multi-file web, it should only give the title of the section held
in the file in question. The following can be put into textual wildcards:

- `MATERIAL` (compulsory). The text of the title itself.
- `SECOND` (optional). The author's name.
- `THIRD` (optional). The version text.
- `FOURTH` (optional). The "namespace" for a section, for the benefit of the
  special InC programming language.

The option `withpurposeoption` says that if the title contains a colon, then
it should be read as "Title: Purpose": that is, the colon and the tail will be
removed, and the tail turned into the "purpose" for the program or section.

-- -- --

`purpose` should be used for brief explanatory material under a title which
describes what the program is for. `MATERIAL` holds the explanation.

-- -- --

`beginparagraph` is used to trigger a paragraph break, that is, the end of an
old paragraph (if any) and the start of a new one. If `MATERIAL` contains text,
this is used for the title of the paragraph; if not, it has no title.

Any leftover text in `RESIDUE` is run through the `residue of beginparagraph`
classifier, if there is one. This can make two possible matches:

- `paragraphtag`, with the tag name in `MATERIAL`.
- `paragraphtitling`, with the paragraph title in `MATERIAL`.

If no match is made, the `RESIDUE` becomes the next line of literate source.

It's possible to change the "importance" of the paragraph title — assuming
there is one — by giving `beginparagraph` one of the options:

- `superheadingoption` makes it more important than regular titled paras.
- `subheading1option`, `subheading2option`, `subheading3option`, `subheading4option`,
  or `subheading5option` make it less important than regular titled paras, with
  level 5 being the lowest of the low.

### Commentary and gadgets

`commentary` means that a line is commentary, and the content should be put
into `MATERIAL`.

-- -- --

`quotation` means a displayed (inset) quotation, whose text should be put
into `MATERIAL`.

-- -- --

`textextract` should be used for a line which indicates that _subsequent_ lines
are part of a displayed piece of text or code (but which are _not_ part of the
program being tangled, and are not functional). `MATERIAL` can optionally be set
to the name of a programming language, in which case the material is
syntax-coloured for that language: if not, it is treated as plain text. If
`SECOND` is set, it is the name of a file from which the material is taken — in
which case, there are no subsequent lines needed, and no end-marker.

Otherwise, though, there should then be a run of `extract` lines, where the
content of each is held in `MATERIAL`, and then an `endextract` line.

`textascodeextract` is a variation on `textextract`. This time `MATERIAL`
cannot be set, so there is no way to specify a programming language, and
therefore the material is presented generically — but as code, not text.

`textextractto` is subtly different, in that it does something on tangles
as well as on weaves. The distinction is that it writes its content out to
an external file whose filename is in `MATERIAL`.

`endextract` should be used for the terminal line marking the end (but
not containing any of the content) of a `textextract`, `textascodeextract`,
or `textextractto` extract.

Either or both of these options can also be applied to `textextract`,
`textascodeextract`, or `textextractto`:

- `hyperlinkedoption` causes URLs in the extract to be woven as live links;
- `undisplayedoption` causes the extract to be woven without the inset box or
  similar framing on the page — the effect is a much barer look.

-- -- --

`figure` marks where an image is to be inserted into the weave. `MATERIAL`
is the filename of the image; `SECOND`, which is optional, can hold dimensions
to scale it to, such as "width 500", "height 2cm", or "200 by 400".

-- -- --

`audio` places an audio player in the commentary, with the audio file's name
placed in `MATERIAL`.

`video` places a video player in the commentary, with the video file's name
placed in `MATERIAL`.

`embeddedvideo` places a video player which embeds sound or film from an
external streaming service into a weave. `MATERIAL` must be the service,
which should be one of "YouTube", "Vimeo", or "SoundCloud". `SECOND` identifies
the content to stream from there, e.g., "GR3aImy7dWw" for a typical YouTube
video. Optional resolution measurements can also be tacked on.
See //InwebClassic Notation// for more.

-- -- --

A carousel of slides can be realised as follows:

`carouselslide` begins each slide. `MATERIAL` can optionally contain a caption.
The content of the slide is then what occupies subsequent lines, up to either
the next `carouselslide` or the `carouselend`. Two options can be added:

- `captionaboveoption` places the caption above the slide content, rather than
  slightly over it, and similarly
- `captionbelowoption` places it below.

`carouselend` ends the final slide, and thus completes the carousel.

-- -- --

`download` is for a line embedding a download link. `MATERIAL` should be the
filename, `SECOND` (which is optional) the kind of file — say, "PDF".

-- -- --

`html` is for a line marking where an external file of HTML is to be spliced
into the weave. `MATERIAL` must hold the filename.

### Holons

`namelessholon` means that the line begins a stretch of code (a holon) which
has no name. The `MarkdownCode` notation never generates this outcome, because
nameless holons there are indicated only by being indented blocks. But other
notations do. For example, Knuth used the marker `@p` to mean "go into Pascal
mode", i.e., begin some code now, since he was using the Pascal language. This
can be achieved thus:

	@p RESIDUE      ==> namelessholon

(Note the residue: Knuth had no qualms about writing code on the same line as
the `@p` marker.)

-- -- --

`namedholon` means that a holon with a name is being declared on this line.
The `MATERIAL` text should be its name, and that name should be non-empty.
For example:

	<OPENHOLON>MATERIAL<CLOSEHOLON> =           ==> namedholon

-- -- --

`fileholon` is for material to be tangled to a subsidiary file, where
`MATERIAL` holds the filename. For example:

	Write this to "<MATERIAL>":                 ==> fileholon

These are not really holons as such, since they do not form part of the program
being tangled: instead they may be making a configuration file, say, or some
other sidekick resource which needs to be in the source code even though it's
not technically the program itself.

-- -- --

Five possible options can be applied to `namelessholon` or `namedholon` (though
not `fileholon`, where they would make no sense:

-	`webwideholonoption` makes a holon webwide. As this affects the visibility
	of its name, this is really only meaningful for `namedholon`.
-	`veryearlyholonoption` says that code in the holon should be tangled very
	early in the program.
-	`earlyholonoption` says it should be tangled early.
-	`lateholonoption` says it should be tangled late.
-	`verylateholonoption` says it should be tangled very late.

-- -- --

The body of a holon is a collection of code lines. These can be classified
in either of two ways:

`code` is for what is definitely a line in a holon. `MATERIAL` must contain
the actual source code fragment.

`extract` is for a line in a general "excerpt" of displayed material (see
below). Again, the content should be put in `MATERIAL`. If Inweb can see
from context that the line occurs in a holon, it will be recognised as `code`
automatically. For example, in this piece of `InwebClassic` notation:

	@ For example:						        classified as beginparagraph then commentary
	                                            classified as commentary
	=	                                        classified as namelessholon
		@<Here is a holon@>;				    classified as extract
                            				    classified as extract
	@<Here is a holon@> =						classified as namedholon
	    int k = 0;              				classified as extract
	    char *p = "static text";				classified as extract

all of the `extract` lines automatically become `code` because they occur
inside of holons. Because of that, there's no need for the `InwebClassic`
notation to distinguish between code and other extract matter: it can classify
all such lines as `extract`, and let Inweb sort out the consequences.

### Definitions

`definition`. Classifies a line as the definition of a symbol (or macro).
`MATERIAL` should contain the thing to be defined: say, "MAX_TESTS", or
"TEST_CASE(name)". `SECOND` should contain its defined value: say, "100".
If `SECOND` is blank, Inweb will use some bland value appropriate to the
programming language, such as "0".

The option `defaultoption` makes this mean "if the `MATERIAL` symbol has
no definition already, then define it as this".

`definitioncontinued`. If a definition's value contines onto subsequent
lines of the source, this should be used for those lines (note: _not_ `code`
or `extract`).

-- -- --

`enumeration`. Adds a new symbol (not macro) to an enumerated set. The
symbol should be in `MATERIAL`. If this is the first symbol, beginning a
new enumeration, then `SECOND` should be the value to begin enumerating from,
which should be a non-negative literal decimal number, such as "5".

-- -- --

`makedefinitionshere`. This was added to Inweb to emulate CWEB's `@h` marker,
and isn't used in Inweb's modern notations. It tells Inweb that, when tangling,
the definitions (and enumerations) should be made at this point in the program.
In the absence of this guidance, Inweb places definitions automatically, and
this doesn't seem to be troublesome in practice.

### Oddities

`formatidentifier` was introduced to emulate WEB's (and CWEB's) `@f` marker,
which changes the syntax-colouring rules applied to a keyword. `MATERIAL`
should be the keyword to alter, and `SECOND` the keyword we want the first
one to look similar to. In effect, `@f` means "treat this like that".

-- -- --

`includefile` was introduced to emulate CWEB's `@i` marker: it's like `#include`
in C, and means "place this external file of literate source here". This is
somewhat contrary to the spirit of Inweb.

## Processing line syntax

Within a processing block, each (non-white-space) line must take the shape:

- _match_ `==>` _replacement_

Note that the replacements are not made in sequence, and that only one replacement
is made at any given position. Thus:

	process
		f ==> g
		g ==> f
	end

processes "logoff" into "lofogg".

All text is literal except that:

- `<NOTHING>` means "the empty text", so replacing with this deletes something;
- `<SPACE>` means a space;
- `<TAB>` means a tab;
- `<LEFTANGLE>` means a literal `<`;
- `<RIGHTANGLE>` means a literal `>`;

Note that `<NEWLINE>`, unlike with text appearing in //Conventions//, is _not_
supported here.
