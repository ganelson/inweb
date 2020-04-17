How This Program Works.

An overview of how Inweb works, with links to all of its important functions.

@h Prerequisites.
This page is to help readers to get their bearings in the source code for
Inweb, which is a literate program or "web". Before diving in:
(a) It helps to have some experience of reading webs. The short examples
//goldbach// and //twinprimes// are enough to give the idea.
(b) Inweb is written in C, in fact ANSI C99, but this is disguised by the
fact that it uses some extension syntaxes provided by //inweb// itself.
Turn to //The InC Dialect// for full details, but essentially: it's plain
old C without predeclarations or header files, and where functions have names
like |Tags::add_by_name| rather than just |add_by_name|.
(c) Inweb makes use of a "module" of utility functions called //foundation//.
This is a web in its own right. There's no need to read it, but you may want
to take a quick look at //foundation: A Brief Guide to Foundation// or the
example //eastertide//.

@h Working out what to do, and what to do it to.
Inweb is a C program, so it begins at //main//, in //Program Control//. PC
works out where Inweb is installed, then calls //Configuration//, which
//reads the command line options -> Configuration::read//.

The user's choices are stored in an //inweb_instructions// object, and Inweb
is put into one of four modes: |TANGLE_MODE|, |WEAVE_MODE|, |ANALYSE_MODE|, or
|TRANSLATE_MODE|.[1] Inweb never changes mode: once set, it remains
for the rest of the run. Inweb also acts on only one main web in any run,
unless in |TRANSLATE_MODE|, in which case none.

Once it has worked through the command line, //Configuration// also calls
//Colonies::load// to read the colony file, if one was given (see
//Making Weaves into Websites//), and uses this to preset some settings:
see //Configuration::member_and_colony//.

All errors in configuration are sent to //Errors::fatal//, from whose bourne
no traveller returns.

[1] Tangling and weaving are fundamental to all LP tools. Analysis means, say,
reading a web and listing functions in it. Translation is for side-activities
like //making makefiles -> Makefiles// or //gitignores -> Git Support//.
Strictly speaking there is also |NO_MODE| for runs where the user simply
asked for |-help| at the command line.

@ //Program Control// then resumes, calling //Main::follow_instructions// to
act on the //inweb_instructions// object. If the user did specify a web to
work on, PC then goes through three stages to understand it.

First, PC calls //Reader::load_web// to read the metadata of the web -- that is,
its title and author, how it breaks down into chapters and sections, and what
modules it imports. The real work is done by the Foundation library function
//WebMetadata::get//, which returns a //web_md// object, providing details
such as its declared author and title (see //Bibliographic Data for Webs//),
and also references to a //chapter_md// for each chapter, and a //section_md//
for each section. There is always at least one //chapter_md//, each of which
has at least one //section_md//.[1] The "range text" for each chapter and
section is set here, which affects leafnames used in woven websites.[2] The
optional |build.txt| file for a web is read by //BuildFiles::read//, and the
semantic version number determined at //BuildFiles::deduce_semver//.

Where a web imports a module, as for instance the //eastertide// example does,
//WebMetadata::get// creates a //module// object for each import. In any event,
it also creates a module called |"(main)"| to represent the main, non-imported,
part of the overall program. Each module object also refers to the //chapter_md//
and //section_md// objects.[3]

The result of //Reader::load_web// is an object called a //web//, which expands
on the metadata considerably. If |W| is a web, |W->md| produces its //web_md//
metadata, but |W| also has numerous other fields.

[1] For single-file webs like //twinprimes//, with no contents pages, Inweb
makes what it calls an "implied" chapter and section heading.

[2] Range texts are used at the command line, and in |-catalogue| output, for
example; and also to determine leafnames of pages in a website being woven.
A range is really just an abbreviation. For example, |M| is the range for the
Manual chapter, |2/tp| for the section "The Parser" in Chapter 2.

[3] The difference is that the //web_md// lists every chapter and section,
imported or not, whereas the //module// lists only those falling under its
own aegis.

@ After loading, the second stage is to call //Reader::read_web//. Whereas
loading was rapid and involved looking only at the contents page, reading
takes longer and means extracting every line of commentary or code. Just
as the loader wrapped the //web_md// in a larger //web// object, so too
the reader wraps each //chapter_md// in a //chapter//, and each //section_md//
in a //section//.

Inweb syntax is heavily line-based, and every line of every section file (except
the Contents page) becomes a //source_line//. In the end, then, Inweb has built
a four-level hierarchy on top of the more basic three-level hierarchy produced
by //foundation//:
= (hyperlinked text as BoxArt)
INWEB        //web//     ---->  //chapter//     ---->  //section//     ---->   //source_line//
              |                |                  |
FOUNDATION   //web_md//  ---->  //chapter_md//  ---->  //section_md//
             //module//
=

@ The third stage is to call //Parser::parse_web//. This is where we check that
the web is syntactically valid line-by-line, reporting errors if any using
by calling //Main::error_in_web//. Each line is assigned a "category": for
example, the category |DEFINITIONS_LCAT| is given to lines holding definitions
made with |@d| or |@e|. See //Line Categories// for the complete roster.[1]

The parser also recognises headings and footnotes, but most importantly, it
introduces an additional concept: the //paragraph//. Each nunbered passage
corresponds to one //paragraph// object; it may actually contain several
paragraphs of prose in the everyday English sense, but has just one heading,
usually a number like "2.3.1". Those numbers are assigned hierarchically,[2]
which is not a trivial algorithm: see //Numbering::number_web//.

It is the parser which finds all of the "paragraph macros", the term used
in the source code for named stretches of code in |@<...@>| notation. A
//para_macro// object is created for each one, and every section has its own
collection, stored in a |linked_list|.[3] Similarly, the parser finds all of
the footnote texts, and works out their proper numbering; each becomes a
//footnote// object.[4]

At the end of the third stage, then, everything's ready to go, and in memory
we now have something like this:
= (hyperlinked text as BoxArt)
INWEB        //web//     ---->  //chapter//     ---->  //section//     ---->  //paragraph//  ----> //source_line//
              |                |                  |               //para_macro//
FOUNDATION   //web_md//  ---->  //chapter_md//  ---->  //section_md//
             //module//
=

[1] There are more than 20, but many are no longer needed in "version 2" of
the Inweb syntax, which is the only one anyone should still use. Continuing
to support version 1 makes //The Parser// much fiddlier, and at some point we
will probably drop this quixotic goal.

[2] Unlike in CWEB and other past literate programming tools, in which
paragraphs -- sometimes called "sections" by those programs, a different use
of the word to ours -- are numbered simply 1, 2, 3, ..., through the entire
program. Doing this would entail some webs in the Inform project running up
to nearly 8000.

[3] In real-world use, to use a |dictionary| instead would involve more
overhead than gain: there are never very many paragraph macros per section.

[4] Though the parser is not able to check that the footnotes are all used;
that's done at weaving time instead.

@h Programming languages.
The contents page of a web usually mentions one or more programming languages.
A line at the top like
= (text as Inweb)
	Language: C
=
results in the text "C" being stored in the bibliographic datum |"Language"|,
and if contents lines for chapters or sections specify other languages,[1]
the loader stores those in the relevant //chapter_md// or //section_md//
objects. But to the loader, these are all just names.

The reader then loads in definitions of these programming languages by
calling //Languages::find_by_name//, and the parser does the same when it
finds extract lines like
= (text as Inweb)
	= (text as ACME)
=
to say that a passage of text must be syntax-coloured like the ACME language.

//Languages::find_by_name// is thus called at any time when Inweb finds need
of a language; it looks for a language definition file (see documentation
at //Supporting Programming Languages//), parses it one line at a time using
//Languages::read_definition_line//, and returns a //programming_language//
object. These correspond to their names: you cannot have two different PL
objects with languages both called "Python", say.

The practical effect is that a web can involve many languages, even though
the main use case is to have just one throughout. //web//, //chapter//,
//section// and even individual //source_line// objects all contain pointers
to a //programming_language//.

[1] A little-used feature of Inweb, which should arguably be taken out as
unnecessary now that colonies allow for multiple webs to coexist happily.

@h Weaving mode.
Let's get back to //Program Control//, which has now set everything up and is
about to take action. What it does depends on which of the four modes Inweb
is in; we'll start with |WEAVE_MODE|.

Weaves are highly comfigurable, so they depend on several factors:
(a) Which format is used, as represented by a //weave_format// object. For
example, HTML, ePub and PDF are all formats.
(b) Which pattern is used, as represented by a //weave_pattern// object. A
pattern is a choice of format together with some naming conventions and
auxiliary files. For example, GitHubPages is a pattern which imposes HTML
format but also throws in, for example, the GitHub logo icon.
(c) Whether a filter to particular tags is used, as represented by a
//theme_tag//.[1]
(d) What subset of the web the user wants to weave -- by default the whole
thing, but sometimes just one chapter, or just one section, and sometimes
a special setting for "do all chapters one at a time" or "do all sections
one at a time", a procedure called //The Swarm//.

[1] For example, Inweb automatically applies the |"Functions"| tag to any
paragraph defining one (see //Types and Functions//), and using |-weave-tag|
at the command line filters the weave down to just these. Sing to the tune
of Suzanne Vega's "Freeze Tag".

@ //Program Control// begins by attempting to load the weave pattern, with
//Patterns::find//; the syntax of weave pattern files can be found in
//Patterns::scan_pattern_line//.

It then either calls //Swarm::weave_subset// -- meaning, a subset of the
web, going into a single output file -- or //Swarm::weave//, which it turn
splits the web into subsets and sends each of those to //Swarm::weave_subset//;
and it ensures that //Patterns::copy_payloads_into_weave// is called at the
end of the process. "Payloads" are files copied into the weave: for example,
an icon or a CSS file used in the website being constructed is a "payload".

//Swarm::weave// also causes an "index" to be made, though "index" here is
Inweb jargon for something which is more likely a contents page listing the
sections and linking to them.[1]

Either way, each single weaving operation arrives at //Swarm::weave_subset//,
which consolidates all the settings needed into a //weave_order// object:
it says, in effect, "weave content X into file Y using pattern Z".[2]

[1] No index is made if the user asked for only a single section or chapter
to be woven; only if there was a swarm.

[2] So when Inweb is used to construct the website you are, perhaps, reading
this text on, around 80 //weave_order// objects will be made, one for each
call to //Swarm::weave_subset//, which in turn is one for each section of the
source-code web of Inweb itself.

@ And so we descend into //The Weaver//, where the function //Weaver::weave//
is given the //weave_order// and told to get on with it.[1]

The method is actually very simple, and is just a depth-first traverse of the
above tree structure for the web, weaving the lines one at a time and keeping
track of the "state" as we go -- the state being, for example, are we currently
in some code, or currently in commentary. For convenience, these running
details are stored in a //weaver_state// object, but it's thrown away as soon
as the weaver finishes.

The actual output produced depends throughout on the format, and for individual
lines it also depends on the programming language they are written in. So the
weaver does its work by making method calls to the //programming_language//
or //weave_format// in question: in effect, these are APIs. See the sections
//Language Methods// and //Format Methods// for itemised lists, but for
example, to weave a line of C into HTML format, the weaver first calls
//LanguageMethods::syntax_colour//, which in turn calls the method
|SYNTAX_COLOUR_WEA_MTID| to the //programming_language// object for C;
and then calls //Formats::source_code//, which in turn calls |SOURCE_CODE_FOR_MTID|
on the //weave_format// object representing HTML.

[1] "Weaver, weave" really ought to be a folk song, but if so, I can't find
it on Spotify.

@ Syntax-colouring is worth further mention, since it demonstrates how
language support works. In principle, any //programming_language// object
can do whatever it likes in response to |SYNTAX_COLOUR_WEA_MTID|. But if Inweb
assigns no particular code to this, what instead happens is that the generic
handler function in //ACME Support// takes on the task.[1] This runs the
colouring program in the language's definition file, by calling an algorithm
called //The Painter//. Colouring programs are, in effect, a mini-language
of their own, which is compiled by //Programming Languages// and then run
in a low-level interpreter by //The Painter//.

[1] "ACME" is used here in the sense of "generic".

@ As for the formats, see //TeX Format// for how TeX output is done, and see
//Running Through TeX// for issuing shell commands to turn that into PDFs.[1]

See //HTML Formats// for HTML and ebook weaving, but see also a suite of
useful functions in //Colonies// which coordinate URLs across websites so
that one web's weave can safely link to another's. In particular, cross-references
written in |//this notation//| are "resolved" by //Colonies::resolve_reference_in_weave//,
and the function //Colonies::reference_URL// turns them into relative URLs
from any given file. Within the main web being woven, //Colonies::paragraph_URL//
can make a link to any paragraph of your choice.[2]

The HTML format also has the ability to request a //weave_plugin//, which is
a bundle of JavaScriot and CSS to implement some unusual feature. Inweb uses
two already, one for footnotes, one for mathematics. Plugins are only woven
into web pages actually using them, to save loading unnecessary JavaScript
in the browser. See //Weave Plugins//.

[1] When Inweb was begun, this seemed the main use case, the most important
thing, the big deal -- all Knuthian points of view. It now seems clear that
TeX/PDF is much less important than HTML/ePub.

[2] Inweb anchors at paragraphs; it does not anchor at individual lines.
This is intentional, as it's intended to take the reader to just enough
context and explanation to understand what is being linked to.

@ Finally on weaving, special mention should go to //The Indexer//, a
subsystem of code which works through a template (often, but not necessarily,
of HTML code), and substitutes special material in at given points. This
is used in two ways:
(a) A simple version tops and tails a weave, providing, for example, the
HTML header for an HTML page, and closing off its |<body>|. For historical
reasons, these are referred to as "cover sheets". See //Indexer::cover_sheet_maker//.
(b) A more elaborate version with a much richer set of features can make
arbitrary constructions, and is used for "index pages" (i.e., contents
pages) in //The Swarm//, and also for recursively dropping in navigation
matter to the sidebar of a web page. See //Indexer::run_engine//. This
is where template/navigation syntax such as |[[Link ...]]| is handled.

@h Tangling mode.
Alternatively, we're in |TANGLE_MODE|, which is more straightforward.
//Program Control// simply works out what we want to tangle, selecting the
appropriate //tangle_target// object, and calls //Tangler::tangle//.
Most webs have just one "tangle target", meaning that the whole web makes
a single program -- in that case, the choice is obvious. However, the
contents section can mark certain chapters or sections as being independent
targets.[1]

//Tangler::tangle// works hierarchically, calling down to //Tangler::tangle_paragraph//
and finally //Tangler::tangle_line// on individual lines of code. Throughout
the process, the Tangler makes method calls to the current programming
language; see //Language Methods//. As with syntax-colouring, the default
arrangement is that these methods are handled by the generic "ACME" language,
following instructions from the language definition file.

Languages declaring themselves "C-like" have access to special tangling
facilities, all implemented with non-ACME method calls: see //C-Like Languages//.
In particular, for coping with how |#ifdef| affects |#include| see
//CLike::additional_early_matter//; for predeclaration of functions and
structs and |typedef|s, see //CLike::additional_predeclarations//.

The language calling itself "InC" gets even more: see //InC Support//, and
in particular //text_literal// for text constants like |I"banana"|
and //preform_nonterminal// for Preform grammar notation like
|<sentence-ending>|.

[1] The original intention of this feature was that a program might want
to have, as "appendices", certain configuration files or other extraneous
matter needing explanation. The author was motivated here by the example of
"TeX", which was presented as a literate program, but was difficult fully
to understand without also reading its format files quite carefully. However,
it now seems better practice to make such a sidekick file its own web, and
use a colony file to make everything tidy on a woven website. So maybe this
feature can go.

@h Analysis mode.
Alternatively, we're in |ANALYSE_MODE|. There's not much to this: //Program Control//
simply calls //Analyser::catalogue_the_sections//, or else makes use of the same
functions as |TRANSLATE_MODE| would -- but in the context of having read in a
web. If it makes a |.gitignore| file, for example, it does so for that specific
web, whereas if the same feature is used in |TRANSLATE_MODE|, it does so in
the abstract and for no particular web.

@h Translation mode.
Or, finally, we're in |TRANSLATE_MODE|. We can:
(a) make a makefile by calling //Makefiles::write//;
(b) make a |.gitignore| file by calling //Git::write_gitignore//;
(c) advance the build number in a build file, by calling out to the
Foundation code at //BuildFiles::advance//;
(d) run a syntax-colouring test to help debug a programming language definition --
see //Program Control// itself for details.

And that is essentially it. Inweb winds up by returning exit code 1 if there
were errors, or 0 if not, like a good Unix citizen.

@h Adding to Inweb.
Here's some miscellaneous advice for those tempted to do so:

1. To add a new command-line switch, declare at //Configuration::read// and
add a field to //inweb_instructions// which holds the setting; don't act on it
then and there, only in //Program Control// later. But we don't want these
settings to proliferate: ask first if adding a feature to, say, //Colonies//
or //weave_pattern// files would meet the same need.

2. To add new programming languages, try if possible to do everything you
need with a new definition file alone: see //Supporting Programming Languages//.
Failing that, see if making definition files more powerful would do it (for
example, by making the ACME support more general-purpose). Failing even that,
follow the model of //C-Like Languages//: that is, add logic to
//Languages::read_definition// which adds method receiver functions
to a language with a given name, or, preferably, some given declaration in
the language definition file. On no account insert any language bias into
//The Weaver// or //The Tangler//.

3. To add new formats, make a new section in //Chapter 5// following the
model of, say, //Plain Text Format// and then adding methods gradually.
But don't forget to call your new format's creator function from
//Formats::create_weave_formats//. Also, don't create a new format if what
you really want is a new pattern: for example, "an HTML website but done
differently" should be a pattern based on HTML; but Markdown would be a
genuinely new format. (And in any case, if you do create a new format, you
must also create a new pattern in order to use it.)

4. If you are creating a new class of object, don't forget to declare it
in //Basics//.
