Advanced Weaving with Patterns.

Customise your weave by creating a new pattern.

@h Patterns versus formats.
Every weave produces output in a "format". The formats are built in to Inweb,
and adding new ones would mean contributing code to the project: currently
we have HTML, ePub, Plain Text, PDF, DIV, and TeX.

There is no way to specify the format at the command line. That's because
|-weave-as P| tells Inweb to weave with a given "pattern": a weave pattern
combines a choice of format with other settings to produce a customised
weave. Patterns can also be based on other patterns: one can, in effect, say
"I want something like P but with some differences". For example, the Inweb
manual at GitHub is woven with |-weave-as GitHubPages|, which is a pattern
based heavily on a generic website-producing pattern called |HTML|.

The upshot of all this is that if you want a website, but one which looks and
behaves differently from what |-weave-as HTML| would give, you should create
a new pattern based on it, and work from there. But patterns are not just
for websites.

@ A pattern definition is a directory containing various files, which we'll
get to in due course. Inweb looks for patterns in three places in turn:
(a) The location given by the |patterns| command in the current colony file,
if there is one: see //Making Weaves into Websites//.
(b) The |Patterns| subdirectory of the current web, if there is a current web,
and if it has such a subdirectory.
(c) The set of built-in patterns supplied with Inweb, at |inweb/Patterns|
in the usual distribution.

For example, the command
= (text as ConsoleText)
	$ inweb/Tangled/inweb inweb/Examples/goldbach -weave-as Tapestry
=
didn't set a colony file, so (a) doesn't apply. Inweb first tries 
|inweb/Examples/goldbach/Patterns/Tapestry| and then |inweb/Patterns/Tapestry|.
If it can't find either, Inweb issues an error.

@h Basic settings.
Patterns allow for extensive customisation of the woven output, especially
through the use of plugins (see below). But they can also be extremely minimal.
The one absolute requirement is to include a configuration file called
|pattern.txt|, which consists of a series of simple one-line commands.
In this file, blank lines, leading and trailing white space are all ignored,
as is any file whose first character is |#|.

The first genuine line of the file should always give the pattern's name,
and say what if anything it is based on. For example, this might be:
= (text as Inweb)
	name: Tapestry based on HTML
=
That is the only compulsory content; with that one line in one file, the
Tapestry pattern is ready for use. (But of course it behaves identically
to HTML in every respect, so it's not very useful yet.)

Do not get these into loops, with A based on B and B based on A.

For a pattern not based on an existing one, simply omit the "based on X"
part. Thus, for example,
= (text as Inweb)
	name: HTML
=

@ There are then a handful of other, optional, settings. The following are
all inherited automatically from the pattern we are based on, unless we
set them ourselves.

= (text as Inweb)
	format: F
=
sets the format. At present, this must be |HTML|, |plain| (plain text),
|ePub|, |TeX|, or |TestingInweb|.

= (text as Inweb)
	number sections: yes
	number sections: no
=
causes the weaver to apply numbers to section headings: the first included will
be number 1, and so on. Default is |no|.

= (text as Inweb)
	default range: R
=
tells the weaver to assume the range |R|, if the user tries to weave a
multi-section web with this pattern. (For example, the standard HTML pattern
sets this to |sections|, causing a swarm of individual HTML files to be produced.)

Lastly, there are commands to do with plugins, covered below, which are also
inherited.

@ Bibliographic data can also be set, but this applies only to the current
pattern, and is not inherited from any patterns it is based on.

= (text as Inweb)
	bibliographic data: K = V
=
tells the weaver to override the bibliographic data on any web it weaves, setting
the key |K| to the value |V|. For example:
= (text as Inweb)
	bibliographic data: Booklet Title = A formal grammar for Inform 7
=

@ It can be useful to do some post-processing after each woven file is made.
For an example, see the |PDFTeX| pattern, which simply uses the |TeX| pattern
to make a TeX file, and then runs it through the |pdftex| command-line tool.
This is done by giving the necessary commands in the pattern file:
= (text as Inweb)
	name: PDFTeX based on TeX
	initial extension: .tex
	command: pdftex -output-directory=WOVENPATH -interaction=scrollmode WOVEN.tex
	command: rm WOVEN.tex
	command: rm WOVEN.log
=
Here |WOVEN| expands to the filename of the file which has just been woven,
but stripped of its filename extension.

Note also the "initial extension" setting. The point of this is that if the
user calls Inweb setting |-weave-to Whatever.pdf|, this pattern setting causes
Inweb first to weave |Whatever.tex|; the post-processing commands will then
make |Whatever.pdf| as expected.

As soon as any command in the list fails, Inweb halts with an error. To see
the exact shell commands being issued, run Inweb with |-verbose|.

@h Plugins and assets.
Plugins are named bundles of resources which are sometimes added to a weave,
and sometimes not, depending on its needs; they are placed in the pattern's
folder, and Inweb has access to the plugins not only for the current pattern,
but also for any pattern(s) it is based on. Plugins were designed for HTML,
but there's no reason they shouldn't also be useful for other formats.

A plugin is identified by name alone, case-insensitively, and that name should
be a single alphanumeric word. For example, the HTML pattern file says
= (text as Inweb)
	plugin: Base
=
and this ensures that every file woven by this pattern, or any pattern based
on it, will use |Base|. There can be multiple such commands, for multiple such
plugins, and the ability isn't restricted to HTML alone.

In addition, the HTML format:
(a) includes |MathJax3| if the woven file needs mathematics notation;
(b) includes |Breadcrumbs| if it has a breadcrumb navigation trail;
(c) includes |Carousel| if it has any image carousels;
(d) includes |Popups| if it has any clickable popups (for example, to show
function usage);
(e) includes |Bigfoot| if it includes footnotes.

Two of these draw on other open-source projects:
(a) |MathJax3| is an excellent rendering system for mathematics on the web: see
https://docs.mathjax.org/en/latest/index.html
(b) |Bigfoot| is adapted from a popularly used piece of web coding: see
https://github.com/lemonmade/bigfoot

But if you would like your pattern to use different plugins to handle
mathematics and footnoting, provide lines like these in your pattern file,
but with your preferred plugin names:
= (text as Inweb)
	mathematics plugin: MathJax3
	footnotes plugin: Bigfoot
=
|Bigfoot| may eventually need to be simplified and rewritten: its big feet
presently tread on the |MathJax3| plugin, so right now it's not possible to
have mathematics in a footnote when |Bigfoot| is in use.

@ So what's in a plugin? A plugin is simply a set of "assets", which are
individual files stored in the plugin's directory. A typical asset might be
a CSS file to help making web pages, or a file of TeX macros to help
typeset a PDF.

Plugin inclusion happens like this:
(a) for each file Inweb weaves, it includes only the plugins it needs;
(b) if it needs |X|, Inweb includes every asset -- meaning, every file whose
name does not begin with a |.| -- from the |X| subdirectory of the pattern,
or from the |X| subdirectory of any pattern it is based on;
(c) but it never includes the same-named asset twice.

@ This means it's possible to supply your own version of any plugin you would
like to tinker with. If you want |Carousel| to have rather different CSS effects,
for example, make your own copy of |Carousel| (copying it from the one in
the Inweb distribution at |inweb/Patterns/HTML/Carousel|) and place it in your
own pattern. Files in your version will prevail over files in the built-in one.

As a simple example, suppose you want a pattern just like |GitHubPages| but
which uses monospaced fonts throughout, for commentary as well as code. The
pattern file can just be:
= (text as Inweb)
	name: MonoGitHub based on GitHubPages
=
Then create just one subdirectory of |MonoGitHub|, called |Base|, and create
a single file in that called |Fonts.css|, reading:
= (text)
	.code-font { font-family: monospace; }
	.commentary-font { font-family: monospace; }
=
And that should work nicely. What happens here is that when pages are woven
with |MonoGitHub|, they use this custom |Fonts.css| instead of the one in
the |Base| plugin from |HTML|. (|MonoGitHub| is based on |GitHubPages|, but
that in turn is based on |HTML|.) All the other files of |Base| remain as
they were, and there's no need to provide duplicates here.

@ But wait, there's more. How is an asset actually "included"? The pattern
gets to decide this, based on the file-type of the asset, as expressed by
its filename extension. For example, the TeX pattern says:
= (text)
	assets: .tex embed
=
This admittedly cryptic line tells Inweb that when it includes plugins for
this pattern, any assets ending |.tex| should be "embedded", rather than
copied. There are four things it can do:
(1) |copy|. This is the default, and means that the file is simply copied
into the weave directory, or into the |assets| directory specified in the
colony file, if the user gave one with |-colony|.
(2) |private copy|. The same, but this is never put into the shared |assets|
directory: it's always copied alongside the woven files for the web.
(3) |embed|. The file is not copied. Instead, its entire contents are
pasted into the woven file itself, when the |[[Plugins]]| placeholder in
the template is expanded (see below). Do not use this for binary files.
(4) |collate|. The file is not copied. Instead, its entire contents are
pasted into the woven file itself, when the |[[Plugins]]| placeholder in
the template is expanded (see below); but this is done as a further collation,
not a simple transcription, so any placeholders found in the file will
themselves be expanded. Do not use this for binary files.

@ In addition, the pattern can specify that some text referring to the
asset file should be put into the woven file. For example, an HTML pattern
might say this:
= (text as Inweb)
	assets: .js copy
	assets: .js prefix = <script src="URL"></script>
	assets: .css copy
	assets: .css prefix = <link href="URL" rel="stylesheet" rev="stylesheet" type="text/css">
	assets: .css transform names
=
With that done, any Javascript or CSS files in its plugins will be copied over,
but links to them will be placed into the header of the HTML file being woven.
(The text |URL|, in a prefix or suffix, expands to the relative URL from the
path being woven to the asset file.)

The unique command "transform names", which should be used only for CSS,
enables the colour-scheme renaming business described below.

An alternative scheme would be to embed all CSS and Javascript, thus producing
a stand-alone HTML file. This could be achieved by:
= (text as Inweb)
	assets: .js embed
	assets: .js prefix = <script>
	assets: .js suffix = </script>
	assets: .css embed
	assets: .css prefix = <style type="text/css">
	assets: .css suffix = </style>
	assets: .css transform names
=

@h Embeddings.
Patterns with the HTML format may also want to provide "embeddings". These
are for embedded video/audio or other gadgets, and each different "service" --
|YouTube|, |SoundCloud|, and such -- is represented by an embedding file.
Inweb looks for these in the pattern's |Embedding| subdirectory, if there is
one; then it tries in the pattern we are based on, and so on until it gives
up and throws an error.

The services in the standard Inweb installation, then, are in
|inweb/Patterns/HTML/Embeddings|. It's easy to add new ones; for example,
by creating a similar fragment in |Tapestry/Embedding/WebTubeo.html| you
would provide for embedding videos from |WebTubeo| when using your pattern.

@h Syntax colouring.
No two people ever agree on the ideal colour scheme for syntax-colouring,
so one prime reason to create a custom pattern is to change Inweb's defaults.

Suppose Inweb wants to weave an extract of code written in, say, C. It will
use the programming language definition for C to make a syntax-colouring,
but then use the weave pattern to decide the colour scheme. For example,
it's up to the C language to say which text is a function name: but it's up
to the pattern to say whether functions are red or green.

A pattern based on HTML may provide a subdirectory called |Colouring|. If it
does, then the contents will be CSS files which provide colour schemes for
different programming languages. The scheme |Colours.css| is the fallback,
and is used for any language not providing a colour scheme; otherwise, a
language called, say, |Anaconda| would be coloured by |Anaconda-Colours.css|.
Inweb looks first in the |Colouring| directory of the current pattern, then
tries the pattern it is based on, and so on.

The practical effect is that if you want a pattern to colour Anaconda programs
in your own preferred way -- let's call this hypothetical pattern |SnakeSkin| --
then you need only write two files: |SnakeSkin/pattern.txt|, consisting of
the single line
= (text as Inweb)
	name: SnakeSkin based on HTML
=
(or perhaps based on |GitHubPages|, if you want to host there); and then
a colouring file in |SnakeSkin/Colouring/Anaconda-Colours.css|. You should
make this by copying the default |Colours.css| and tinkering.

@ Note that Inweb supports multiple languages in the same weave, each having
their own colour schemes. To do this, it renames CSS spans on the fly in
order to prevent namespace clashes. But you can forget this, because it's
automatic.

@h Templates.
The final possible ingredient for a pattern is a "template"; this is a file
like a pro-forma letter, into which just the details need to be entered.
Inweb does this in two main circumstances:
(a) For each woven file, for example each HTML page generated in a website,
Inweb looks for |template-body.html| (or |.tex|, or |.txt| -- whatever
file extension is used for files in the current format), and uses that
to top and tail the weaver's output. Not all formats or patterns need that.
(b) If Inweb is weaving a large number of individual files for sections or
chapters, it will try also to make an accompanying contents page, though
it uses the term "index" for this. It does this by looking for the
template |template-index.html| -- this time, it's always HTML: the idea is
that whatever file type you're making, you will want an HTML index page
offering downloads or links to them.

In fact the same process, called "collation", is also used internally to
produce navigation sidebars in HTML, and to inject HTML into headers for
the sake of plugins. But the author of a pattern can't control that, whereas
she can write her own |template-body.html| and/or |template-index.html|.

@ For example, here is a template file for making an HTML page:
= (text as Inweb)
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
	<head>
		<title>[[Booklet Title]]</title>
		[[Plugins]]
	</head>
	<body>
[[Weave Content]]
	</body>
</html>
=
The weaver uses this to generate any HTML page of program taken from the
web being woven. What you see is what you get, except for the placeholders in
double square brackets:
(a) |[[Weave Content]]| expands to the body of the web page -- the headings,
paragraphs and so on.
(b) |[[Plugins]]| expands to any links to CSS or Javascript files needed
by the plugins being used -- see above.
(c) Any bibliographic datum for the web expands to its value: thus |[[Title]]|,
|[[Author]]| and so on. Booklet Title is one of these, but the weaver always
sets it to a sensible title for the current file being woven -- typically the
name of a section or chapter, if that's what the file will contain. Another
sometimes useful case to know is |[[Capitalized Title]]|, which is the title
in BLOCK CAPITAL LETTERS.

@ Other placeholders, not used in the example above, include:
(a) |[[Navigation]]| expands to the navigation sidebar in use when weaving
a colony of webs -- see //Making Weaves into Websites// for more, and for
syntaxes to do with links and URLs.
(b) |[[Breadcrumbs]]| expands to the HTML for the breadcrumb trail.
(c) |[[Docs]]| expands to the URL to the home page of a colony.
(d) |[[Assets]]| expands to the URL of the directory into which plugin
assets such as images are placed.

@ The |template-index.html| file has access to additional placeholders
enabling it to generate contents pages:

(a) One of the following details about the entire-web PDF (see below):
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

@ |[[Repeat Chapter]]| and |[[Repeat Section]]| begin blocks of lines which
are repeated for each chapter or section: the material to be repeated
continues to the matching |[[End Repeat]| line. The "current chapter or
section" mentioned above is the one selected in the current innermost
loop of that description.

|[[Repeat Module]]|, similarly, begins a repeat through the imported
modules of the current web. (The main module, containing the actual material
of the current web, does not count.) Within such a loop,
= (text as Inweb)
	[[Module Title]]  [[Module Purpose]]  [[Module Page]]
=
can all be used to refer to the current module. |[[Module Page]]| expands
to the relative URL of the module's own woven HTML form, provided that
the module is listed as a member of the current colony file.

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

@ Finally, there is very limited support for conditionals with
|[[If CONDITION]]|, an optional |Else|, and a compulsory |Endif|.
Very few conditions are in fact allowed:

|[[If Chapters]]| tests whether the current web is divided into chapters,
the alternative being that all the sections are in a notional chapter just
called |Sections|.

|[[If Modules]]| tests whether the current web imports any modules.

|[[If Chapter Purpose]]|, inside a |[[Repeat Chapter]]|, tests whether the
current chapter has a (non-empty) purpose text. Similarly for |[[If Section Purpose]]|
and |[[If Module Purpose]].

|[[If Module Page]]|, inside a |[[Repeat Module]]|, tests whether the module
appears (under its own name, i.e., not by a different name) as a member in
the colony file, if there is one. In effect, this can be used to test whether
it is safe to make a link to the module's own woven pages using |[[Module Page]]|.
