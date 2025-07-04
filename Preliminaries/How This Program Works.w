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
like |LiterateSource::tag_paragraph| rather than just |add_by_name|.
(c) Inweb makes use of a "module" of utility functions called //foundation//.
Indeed, as will become quickly apparent, almost its entire functionality is
carried out by foundation: Inweb itself is little more than a command-line
interface to control what is done. See //foundation: A Brief Guide to Foundation//.

@h Working out what to do, and what to do it to.
Inweb is a C program, so it begins at //main//, in //Program Control//. PC
works out where Inweb is installed, then calls //Configuration//, which
//reads the command line options -> Configuration::read//.

The user's choices are stored in an //inweb_instructions// object, and Inweb
is put into one of four modes: |TANGLE_MODE|, |WEAVE_MODE|, |ANALYSE_MODE|, or
|TRANSLATE_MODE|.[1] Inweb never changes mode: once set, it remains
for the rest of the run. Inweb also acts on only one main web in any run,
unless in |TRANSLATE_MODE|, in which case none.

Once it has worked through the command line, //Configuration// reads in the
colony file, if one was given (see //Making Weaves into Websites//), and uses
this to preset some settings: see //Configuration::member_and_colony//.

All errors in configuration are sent to //Errors::fatal//, from whose bourne
no traveller returns.

[1] Tangling and weaving are fundamental to all LP tools. Analysis means, say,
reading a web and listing functions in it. Translation is for side-activities
like making makefiles. Strictly speaking there is also |NO_MODE| for runs where
the user simply asked for |-help| at the command line.

@ //Program Control// then resumes, calling //Main::follow_instructions// to
act on the //inweb_instructions// object. If the user did specify a web to
work on, PC then goes through three stages to understand it.

First, PC calls //Main::load_web// to read the web fully into memory -- not
only metadata such as its title, author, and section breakdown, but also the
completely parsed text of the source. (It's possible to read webs only partially
as metadata alone for speed, but we don't do that.) All this work is delegated to
the foundation library, so if you're interested in how it's done, and in how
webs are stored in memory, see there. The result, put briefly, is a single
//ls_web// object, containing a list of //ls_chapter// objects for each chapter,
each of which in turn is a list of //ls_section// objects for each section.
There is always at least one //ls_chapter//, each of which
has at least one //ls_section//.[1] The "range text" for each chapter and
section is set along the way, which affects leafnames used in woven websites.[2]

Where a web imports a module, as for instance the //eastertide// example does,
//WebStructure::get// creates a //ls_module// object for each import. In any event,
it also creates a module called |"(main)"| to represent the main, non-imported,
part of the overall program. Each module object also refers to the //ls_chapter//
and //ls_section// objects.[3]

[1] For single-file webs like //twinprimes//, with no contents pages, Inweb
makes what it calls an "implied" chapter and section heading.

[2] Range texts are used at the command line, and in |-catalogue| output, for
example; and also to determine leafnames of pages in a website being woven.
A range is really just an abbreviation. For example, |M| is the range for the
Manual chapter, |2/tp| for the section "The Parser" in Chapter 2.

[3] The difference is that the //ls_web// lists every chapter and section,
imported or not, whereas the //ls_module// lists only those falling under its
own aegis.

@h Taking action.
Let's get back to //Program Control//, which has now set everything up and is
about to take action. What it does depends on which of the four modes Inweb
is in: |WEAVE_MODE|, |TANGLE_MODE|,  |ANALYSE_MODE| or |TRANSLATE_MODE|.
The latter amounts to very little, and is simply a catchall name for generating
convenient addenda to webs of source code: makefiles, gitignore files and such.

And that is essentially it. Inweb winds up by returning exit code 1 if there
were errors, or 0 if not, like a good Unix citizen.

@h Adding to Inweb.
Here's some miscellaneous advice for those who would like to add to Inweb:

1. To add a new command-line switch, declare at //Configuration::read// and
add a field to //inweb_instructions// which holds the setting; don't act on it
then and there, only in //Program Control// later. But we don't want these
settings to proliferate: ask first if adding a feature to, say, //Colonies//
or //weave_pattern// files would meet the same need.

2. To add new programming languages, try if possible to do everything you
need with a new definition file alone: see //Supporting Programming Languages//.
Failing that, foundation will need to be added to. see if making definition
files more powerful would do it (for example, by making the ACME support more
general-purpose). Failing even that, follow the model of //C-Like Languages//:
that is, add logic to //Languages::read_definition// which adds receiver functions
to a language with a given name, or, preferably, some given declaration in the
language definition file. On no account insert any language bias into
//The Weaver// or //The Tangler//.

3. To add new forms of weave output, try if possible to make a new pattern:
see //Advanced Weaving with Patterns//. But this won't always be good enough.
For example, "an HTML website but done differently" should be a pattern based
on HTML.
