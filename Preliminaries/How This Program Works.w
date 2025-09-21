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
works out which subcommand it will be executing. It runs only one subcommand
in each execution, and halts after doing essentially nothing if no subcommand
was given (for example, if help information was requested but nothing else).

All errors in configuration are sent to //Errors::fatal//, from whose bourne
no traveller returns.

@ //Program Control// then resumes, calling the relevant subcommand to take
action. Most of the subcommands then call back to //Configuration// in order to
make sense of their main "operands", that is, the settings which say what web to
act upon: this ensures that they share conventions as far as possible.

In most cases, though, a web must be read into memory. This is done in full --
that is, reading not only metadata such as its title, author, and section
breakdown, but also the completely parsed text of the source. All this work is
delegated to the foundation library, so if you're interested in how it's done,
and in how webs are stored in memory, see there. The result is a single
//ls_web// object, containing a list of //ls_chapter// objects for each chapter,
each of which in turn is a list of //ls_section// objects for each section.
There is always at least one //ls_chapter//, each of which has at least one
//ls_section//.[1] The "range text" for each chapter and section is set along
the way, which affects leafnames used in woven websites.[2]

Where a web imports a module, as for instance the //eastertide// example does,
//WebStructure::from_declaration// creates a //ls_module// object for each
import. In any event, it also creates a module called |"(main)"| to represent
the main, non-imported, part of the overall program. Each module object also
refers to the //ls_chapter// and //ls_section// objects.[3]

So, then, the subcommand does its thing -- which invariably means simply
calling a convenient function somewhere in //foundation// and then returns
to //Program Control//. And that is essentially it. Inweb winds up by returning
exit code 1 if there were errors, or 0 if not, like a good Unix citizen.


[1] For single-file webs like //twinprimes//, with no contents pages, Inweb
makes what it calls an "implied" chapter and section heading.

[2] Range texts are used at the command line, and in |inweb inspect| output, for
example; and also to determine leafnames of pages in a website being woven.
A range is really just an abbreviation. For example, |M| is the range for the
Manual chapter, |2/tp| for the section "The Parser" in Chapter 2, and |3| means
all of chapter 3.

[3] The difference is that the //ls_web// lists every chapter and section,
imported or not, whereas the //ls_module// lists only those falling under its
own aegis.

@h Adding to Inweb.
Here's some miscellaneous advice for those who would like to add to Inweb:

1. To add a new command-line switch, declare this in the relevant subcommand
section, and follow the general plan used there. But we don't want these
settings to proliferate: ask first if adding a feature to, say, //Colonies//
or //weave_pattern// files would meet the same need. And on the other hand,
if the switch really makes the subcommand do something quite different,
consider making a new subcommand instead.

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
