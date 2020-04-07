Advanced Weaving with Patterns.

Customise the booklets woven from a web.

@h Weave patterns.
As noted, the two most useful weave patterns are |-weave-as HTML| and
|-weave-as TeX|, and these are both supplied built in to Inweb. When you
weave something with |-weave-as P|, for some pattern name |P|, Inweb first
looks to see if the web in question defines a custom pattern of that name.
For example,
= (text as ConsoleText)
	$ inweb/Tangled/inweb inweb/Examples/goldbach -weave-as Tapestry
=
would look for a directory called:
= (text)
	inweb/Examples/goldbach/Patterns/Tapestry
=
If that is found, Inweb expects it to define |Tapestry|. If not, Inweb next
tries:
= (text)
	inweb/Patterns/Tapestry
=
since |inweb/Patterns| is where the built-in patterns are kept. If it can't
find either, Inweb issues an error.

@ Patterns are a relatively new feature of Inweb, but allow for considerable
customisation of the woven output. In brief, a pattern directory is expected
to contain a configuration file called |pattern.txt|. This consists of a
series of simple one-line commands.

Most custom patterns open with the command:
= (text)
	from Whatever
=
which tells Inweb that this new pattern inherits from an existing one named
|Whatever|. (Do not get these into loops, with A inheriting from B and B
also inheriting from A.) The rule is then that if Inweb needs a file to do
with weaving, it looks first in the new custom pattern, and then, failing
that, in the pattern inherited from. As a result, the custom pattern need
only contain actual differences.

There should then always be a command reading:
= (text)
	format = HTML
=
or whatever other file format is required (for the TeX pattern, for example,
this reads |format = PDF|). A few other settings can also be made with |=|.

(a) |numbered = yes| causes the weaver to apply numbers to section headings:
the first included will be number 1, and so on. Default is |no|.

(b) |abbrevs = no| causes the weaver to suppress all mention of abbreviated
sections ranges, such as |2/tpc|, which aren't useful for documentation (for
example). Default is |yes|.

(c) |tex-command = C| tells the weaver that the TeX typesetting system should
be invoked with the shell command |C|. Default is |tex|.

(d) |pdftex-command = C| tells the weaver that the TeX typesetting system should
be invoked with the shell command |C| when what we want is a PDF, not a DVI
file. Default is |pdftex|.

(e) |open-command = C| tells the weaver to use the shell command |C| if it
wants to open the woven file (i.e., on the user's computer) after it finishes.
Default is |open|, which works nicely for MacOS.

(f) |default-range = R| tells the weaver to assume the range |R|, if the user
tries to weave a multi-section web with this pattern. (For example, the standard
HTML pattern sets |default-range = sections|.)

(g) The equals sign can also be used to override values of the bibliographic data
for the web. These changes are only temporary for the period in which the weave
is going on; they enable us to give custom titles to different weaves from the
same web. For example:
= (text)
	Title = Grammar
	Booklet Title = A formal grammar for Inform 7
	Author = The Inform Project
=
@ The command:
= (text)
	use X
=
tells Inweb that the file X, also stored in the pattern directory, should
be copied into any website being woven. For example, the HTML pattern says
= (text)
	use crumbs.gif
=
to instruct Inweb that an image used by the pages generated needs to be
copied over.

Finally, the command
= (text)
	embed css
=
tells Inweb that in any HTML file produced, the CSS necessary should be
embedded into the HTML, not linked as an external file. This is tidier for
patterns like TeX, where there will only be at most one HTML file produced,
and there's no need for an external CSS file.

@h Cover sheets.
If a weave has a range bigger than a single section -- for example, if it's
a weave of a chapter, or of the complete web -- then it will include a
"cover sheet". In the case of a PDF being made via TeX, this will actually
be an extra page at the front of the PDF; for HTML, of course, it will just
be additional material at the top of the web page.

The template for the cover sheet should be given in a file in the pattern
folder called |cover-sheet.tex|, |cover-sheet.html| or similar. Within it,
double-square brackets can be used to represent values from the bibliographic
data at the top of the web's Contents section. For example:
= (text as Inweb)
	\noindent{{\stitlefont [[Author]]}}
=
In addition:
(a) |[[Cover Sheet]]| expands to the parent pattern's cover sheet -- this is
convenient if all you want to do is to add a note at the bottom of the
standard look.
(b) |[[Booklet Title]]| expands to text such as "Chapter 3", appropriate
to the weave being made.
(c) |[[Capitalized Title]]| is a form of the title in block capital letters.

@h Indexing.
Some weaves are accompanied by indexes. For example, a standard weave into
sections (for the HTML pattern) generates an |index.html| contents page,
linking to the weaves for the individual sections. How is this done?

Inweb looks in the pattern for a template file called either
|chaptered-index.html| or |unchaptered-index.html|, according to whether the
web's sections are in chapters or simply in a single directory of |Sections|.
If it doesn't find this, it looks for a template simply called |index.html|,
using that template in either case.

An index is then made by taking this template file and running it through
the "template interpreter". This is basically a filter: that is, it
works through one line at a time, and most of the time it simply copies
the input to the output. The filtering consists of making the following
replacements. Any text in the form |[[...]]| is substituted with the
value |...|, which can be any of:

(a) A bibliographic variable, set at the top of the |Contents.w| section.

(b) One of the following details about the entire-web PDF (see below):
= (text as Inweb)
	[[Complete Leafname]]  [[Complete Extent]]  [[Complete PDF Size]]
=
(b) One of the following details about the "current chapter" (again, see below):
= (text as Inweb)
	[[Chapter Title]]  [[Chapter Purpose]]  [[Chapter Leafname]]
	[[Chapter Extent]]  [[Chapter PDF Size]]  [[Chapter Errors]]
=
(...) The leafname is that of the typeset PDF; the extent is a page count;
the errors result is a usually blank report.

(c) One of the following details about the "current section" (again, see below):
= (text as Inweb)
	[[Section Title]]  [[Section Purpose]]  [[Section Leafname]]
	[[Section Extent]]  [[Section PDF Size]]  [[Section Errors]]
	[[Section Lines]]  [[Section Paragraphs]]  [[Section Mean]]
	[[Section Source]]
=
(...) Lines and Paragraphs are counts of the number of each; the Source
substitution is the leafname of the original |.w| file. The Mean is the
average number of lines per paragraph: where this is large, the section
is rather raw and literate programming is not being used to the full.

@ But the template interpreter isn't merely "editing the stream", because
it can also handle repetitions. The following commands must occupy entire
lines:

|[[Repeat Chapter]]| and |[[Repeat Section]]| begin blocks of lines which
are repeated for each chapter or section: the material to be repeated
continues to the matching |[[End Repeat]| line. The ``current chapter or
section'' mentioned above is the one selected in the current innermost
loop of that description.

|[[Select ...]]| and |[[End Select]| form a block which behaves like
a repetition, but happens just once, for the named chapter or section.

For example, the following pattern:
= (text as Inweb)
	To take chapter 3 as an example, for instance, we find -
	[[Select 3]]
	[[Repeat Section]]
	    Section [[Section Title]], [[Section Code]], [[Section Lines]] lines.
	[[End Repeat]]
	[[End Select]]
=
weaves a report somewhat like this:
= (text)
	To take chapter 3 as an example, for instance, we find -
	    Section Lexer, 3/lex, 1011 lines.
	    Section Read Source Text, 3/read, 394 lines.
	    Section Lexical Writing Back, 3/lwb, 376 lines.
	    Section Lexical Services, 3/lexs, 606 lines.
	    Section Vocabulary, 3/vocab, 338 lines.
	    Section Built-In Words, 3/words, 1207 lines.
=
@h Navigation and breadcrumbs.
When assembling large numbers of woven websites together, as is needed for
example by the main Inform repository's GitHub pages, we need to navigate
externally as well as internally: that is, the page for one tool will need
a way to link to pages for other tools.

To that end, the special expansion |[[Navigation]]| in a pattern template
will expand by looking for a file which contains a fragment of HTML, usually
consisting only of an un-numbered list of links.

By default, Inweb looks for a file called |nav.html| in two directories: the
one above the destination, and the destination. If both exist, they are both
used. If neither exists, the expansion is empty, but no error is produced.

However, this can be overridden at the command line, with |-navigation N|,
where |N| is the filename for a suitable fragment of navigation HTML.

@ The row of breadcrumbs at the top of a woven website can also be
customised from the command line, in that the prefatory breadcrumbs can
be explicitly chosen. (If they are not chosen, there's just a star, which
links to the relevant GitHub repository home page.) Any number can be
supplied. For example:
= (text as ConsoleText)
	$ inweb/Tangled/inweb ... -breadcrumb 'Groceries:groc.html' -breadcrumb Produce
=
produces the trail
= (text)
	Groceries > Produce > ...
=
with the links being to |groc.html| and |Produce.html| respectively. (The
colon is optional, and needed only if the link is not to the text with |.html|
appended.)
