A Brief Guide to Foundation.

Notes on getting started with the Foundation library.

@h Introduction.
The Foundation module supplies some of the conveniences of more modern
programming languages to ANSI C. It offers the usual stuff of standard
libraries everywhere: memory management, collection classes, filename and file
system access, regular-expression matching and so on, and it does so while
abstracting away differences between operating systems (Windows, Linux,
Unix, MacOS, Android and so on).

Almost all functionality is optional and can be ignored if not wanted. With a
few provisos, the code is thread-safe, sturdy and well tested, since it forms
the support code for the Inform programming language's compiler and outlying
tools, including Inweb itself. If you need to write a command-line utility in
ANSI C with no dependencies on other tools or libraries to speak of, you could
do worse. But you certainly don't need it to use //inweb//, even if you're
writing in C.

For a brief example of a command-line utility using some of the commoner
features of Foundation in a simple way, see //eastertide//. Further exercises
can be found in //foundation-test//.

@ To use //foundation//, a program must at minimum do three things.

1. The Contents section of its web must import Foundation as a module, thus:
= (text as Inweb)
	Import: foundation
=
Import lines appear after the metadata, but before the roster of sections
and chapters.

2. The constant |PROGRAM_NAME| must be defined equal to a C string with a
brief version of the program's name. For example,
= (text as Inweb)
	@d PROGRAM_NAME "declutter"
=

3. The |main| function for the client should, as one of its very first acts,
call |Foundation::start()|, and should similarly, just before it exits, call
|Foundation::end()|. Any other module used should be started after Foundation
starts, and ended before Foundation ends.

@h Truth.
Every large C program starts by defining constants for truth and falsity. So
does Foundation: |TRUE|, |FALSE|, and a third state |NOT_APPLICABLE|.

@h Text streams and formatted output.
Perhaps the most useful feature of Foundation is that it provides for
memory-managed strings of Unicode text. These are unified with text files
which are open for output, in a type called //text_stream//. It's expected
that they may be very large indeed, and appending text to or finding the
length of a text in memory runs in $O(1)$ time.

A typical function writing to one of these might be:
= (text as InC)
	void Hypothetical::writer(text_stream *OUT, text_stream *authority, int N) {
		WRITE("According to %S, the square of %d is %d.\n", authority, N, N*N);
	}
=
Here |WRITE| is a variadic macro rather like |printf|, and note the use of
the escape |%S| to write a text stream. It writes formatted output into the
stream |OUT|, and is actually an abbreviation for this:
= (text as InC)
	void Hypothetical::writer(text_stream *OUT, text_stream *authority, int N) {
		WRITE_TO(OUT, "According to %S, the square of %d is %d.\n", authority, N, N*N);
	}
=
The function |Hypothetical::writer| can write equally to a text file or to a
string, whichever it's given, and doesn't need to worry about memory management
or text encodings.

The standard output and standard error "files" on Unix-based systems are
referred to as |STDOUT| and |STDERR|, both constants of type |text_stream *|
defined by Foundation. The value |NULL|, used as a text stream, is valid and
prints as the empty string, while ignoring any content written to it.
All of these capitalised macros are defined in //Streams//.

|PRINT("...")| is an abbreviation for |WRITE_TO(STDOUT, "...")|, and
|LOG("...")| similarly writes to the log file. (See //Debugging Log//.)

@ If you're using //inweb: The InC Dialect//, the slight extension to C made
by Inweb, there's a simple notation for constants of this type:
= (text as InC)
	text_stream *error_message = I"quadro-triticale stocks depleted";
=
The |I| prefix is meant to imitate the |L| used in standard C99 for long string
constants. But this is a feature of //inweb// rather than of Foundation.

@ Programs doing a lot of parsing need to create and throw away strings all
of the time, so we shouldn't be too casual about memory management for them.
//Str::new// creates a new empty string; //Str::duplicate// duplicates an
existing one. But these are permanent creations, and not easy to deallocate
(though calling //Str::clear// to empty out their text will free any large
amount of memory they might be using). If you want a string just for a
momentary period, do this:
= (text as InC)
	TEMPORARY_TEXT(alpha)
	WRITE_TO(alpha, "This is temporary");
	...
	DISCARD_TEXT(alpha)
=
Between the use of these two macros, |alpha| is a valid |text_stream *|,
and is a string capable of growing to arbitrary size.

@ Foundation provides an elaborate system for providing new string escapes
like |%S|: see //Writers and Loggers//. A similar system manages a debugging
log, to which it's easy to make "dollar escapes" for pretty-printing internal
data structures: for example, if you've made a structure called |recipe|, you
could make |$R| pretty-print one.

@ Foundation also has an extensive library of string-handling routines,
providing the sort of facilities you would expect in a typical scripting
language. See //String Manipulation// and //Pattern Matching//, which can
match text streams against regular expressions, though note that the latter
use an idiosyncratic notation.

There's also //Tries and Avinues// for rapid character sequence parsing.

For slicing, see the //string_position// type, representing positions for the
benefit of functions like //Str::substr//.

@ Individual characters are represented in Foundation using the standard
POSIX type |inchar32_t|, which on all modern systems is a very wide integer,
whether or not signed. It's safe to assume it can hold all normal Unicode
code points. See //Characters// for class functions like //Characters::isdigit//,
which have been carefully written to work equivalently on either Windows or
Unix-based systems.

//C Strings// and //Wide Strings// provide bare-minimum facilities for handling
traditional null-terminated |char| and |inchar32_t| arrays, but don't use these.
Texts are just better.

@h Objects.
To a very limited extent, Foundation enables C programs to have "classes",
"objects" and "methods", and it makes use of that ability itself, too. (See
//Foundation Classes// for the list of classes made by //foundation//.) For
example, suppose we are writing a program to store recipes, and we want
something in C which corresponds to objects of the class |recipe|. We need to
do three things:

1. Declare an enumerated constant ending |_CLASS| to represent this type in the
memory manager, and then make a matching use of a macro to define some associated
functions, which we never see or think about. For example:
= (text as Inweb)
	@ Here are my classes...
	
	@e recipe_CLASS
	
	=
	DECLARE_CLASS(recipe)
=
The mention of "individually" is because this is for data structures where
we expect to have relatively few instances. If we expect to have huge numbers
of throwaway instances, we would instead write:
= (text as Inweb)
	@ Here are my classes...
	
	@e salt_grain_CLASS
	
	=
	DECLARE_CLASS_ALLOCATED_IN_ARRAYS(salt_grain, 1000)
=
The memory manager then claims these in blocks of 1000. Use this only if it's
actually needed; note that |DESTROY| cannot be used with objects created
this way.

2. We have to declare the actual structure, and |typedef| the name to it. For
example:
= (text as InC)
	typedef struct recipe {
		struct text_stream *name_of_dish;
		int oven_temperature;
		CLASS_DEFINITION
	} recipe;
=
Here |CLASS_DEFINITION| is a macro defined in //Memory// which expands to the
necessary field(s) to keep track of this. We won't use those fields, or ever
think about them.

3. In fact we've now finished. The macro |CREATE(recipe)| returns a new
instance, and |DESTROY(R)| would destroy an existing one, |R|. Unless manually
destroyed, objects last forever; there is no garbage collection. In practice
the Inform tools suite, for which Foundation was written, almost never destroy
objects.

Customarily, though, we wrap the use of |CREATE| in a constructor function:
= (text as InC)
	recipe *Recipes::new(text_stream *name) {
		recipe *R = CREATE(recipe);
		R->name_of_dish = Str::duplicate(name);
		R->oven_temperature = 200;
		return R;
	}
=

We also often use the convenient |LOOP_OVER| macro:
= (text as InC)
	void Recipes::list_all(text_stream *OUT) {
		WRITE("I know about the following recipes:\n");
		recipe *R;
		LOOP_OVER(R, recipe)
			WRITE("- %S\n", R->name_of_dish);
	}
=
|LOOP_OVER| loops through all created |recipe| instances (which have not been
destroyed).

There are a few other facilities, for which see //Memory//, and also ways to
allocate memory for arrays -- see //Memory::calloc// and //Memory::malloc//.

@h Methods.
It's also possible to have method calls on object instances, though the
syntax is not as tidy as it would be in an object-oriented language. To allow
this for |recipe|, we would have to add another line to the structure:
= (text as InC)
	typedef struct recipe {
		struct text_stream *name_of_dish;
		int oven_temperature;
		struct method_set *methods;
		CLASS_DEFINITION
	} recipe;
=
and another line to the constructor function:
= (text as InC)
		R->methods = Methods::new_set();
=
The object |R| is then ready to receive method calls. Each different call needs
an enumerated constant ending |_MTID| to identify it, and an indication of the
type of the function call involved:
= (text as Inweb)
	@ Here is my "cook the recipe" method call:
	
	@e COOK_MTID
	
	=
	VOID_METHOD_TYPE(COOK_MTID, recipe *R, int time_in_oven)
=
It's now possible to call this on any recipe:
= (text as InC)
	VOID_METHOD_CALL(duck_a_l_orange, COOK_MTID, 45);
=
What then happens? Nothing at all, unless the recipe instance in question --
here, |duck_a_l_orange| -- has been given a receiver function. Let's revisit
the constructor function for recipes:
= (text as InC)
	recipe *Recipes::new(text_stream *name) {
		recipe *R = CREATE(recipe);
		R->name_of_dish = Str::duplicate(name);
		R->oven_temperature = 200;
		R->methods = Methods::new_set();
		METHOD_ADD(R, COOK_MTID, Recipes::cook);
		return R;
	}
=
and now add:
= (text as InC)
	void Recipes::cook(recipe *R, int time_in_oven) {
		...
	}
=
using the arguments promised in the declaration above. With all this done,
the effect of
= (text as InC)
	VOID_METHOD_CALL(duck_a_l_orange, COOK_MTID, 45);
=
is to call:
= (text as InC)
	Recipes::cook(duck_a_l_orange, 45);
=

@ In fact it's possible to attach multiple receivers to the same object, in
which case they each run in turn. As a variant on this, methods can also return
their "success". If multiple receivers run, the first to return |TRUE| has
claimed the right to act, and subsequent receivers aren't consulted.

Such methods must be defined with |INT_METHOD_CALL| and are rarely needed. See
//Methods// for more.

@h Collections.
Foundation provides three sorts of "collection": see //Linked Lists and Stacks//,
and also //Dictionaries//. These all collect values which are expected to be
pointers: for example, text streams (of type |text_stream *|) or objects like
the ones created above. For example,
= (text as InC)
	linked_list *cookbook = NEW_LINKED_LIST(recipe);
=
initialises a list as ready to use. It's then accessed by macros:
= (text as InC)
	recipe *lobster_thermidor = Recipes::new(I"lobster thermidor", 200);
	ADD_TO_LINKED_LIST(lobster_thermidor, recipe, cookbook);
=
Similarly:
= (text as InC)
	recipe *R;
	LOOP_OVER_LINKED_LIST(R, recipe, cookbook)
		PRINT("I can make %S.\n", R->name_of_dish);
=
That's about all you can do with linked lists: they are not nearly so well
worked-through as texts.

A dictionary is an associative hash which relates key names (which are text
streams) to values (which are usually, but not always, also text streams).
They behave very like hashes in Perl and, as the name suggests, use hashing
to make access rapid. See //Dictionaries//.

@ Foundation also provides for //heterogeneous_tree//, which is a structure
able to hold a rooted tree in which nodes can be a variety of different
objects, rather than having to be uniform. Functions are provided to
build and verify such trees.

@h Files and paths.
Filenames and pathnames are, perhaps controversially, represented by two
different types: //filename// and //pathname//. The latter should perhaps
have been called "directoryname", but that ship has sailed.

Foundation does not have a unified type for URLs, as most modern libraries do.
But there are some advantages to that, in that the type-checker forces us to
be clear which we intend at any given time. Anyway, that vessel is also now
well out to sea.

These both hold names, not actual files: they are places where files or
directories might be.

Both tend to refer relative to the current working directory, represented by
the null |pathname| pointer. //Pathnames::up// and //Pathnames::down// go
to parent or subdirectories, respectively. A filename cannot exist without
a pathname; for example,
= (text as InC)
	pathname *P = Pathnames::down(NULL, I"App")
	P = Pathnames::down(P, I"Config")
	filename *F = Filenames::in(P, I"options.txt");
	PRINT("I have arrived at %f.\n", F);
=
produces, on platforms where |/| is used as the file system dividing character,
= (text)
	I have arrived at App/Config/options.txt.
=
Note the use of the escape |%f| for printing filenames; there's also |%p| for
pathnames.

See //Filenames// and //Pathnames// for more.

@ If you need to iterate over the contents of a directory in the file system,
see //Directories//. But to create a directory, call //Pathnames::create_in_file_system//.
For synchronisation, try //Pathnames::rsync//, but don't expect too much.

See //Pathnames// for how to access the user's home directory, the current
working directory, and the installation directory for a program.

@ //Binary Files// does the tedious work of writing binary data while allowing
for endian-ness; and it can also compute md5 hashes of binary files, which is
useful for testing the correctness of our tools.

@ //Text Files// allows us to read text files. Its most useful function is
//TextFiles::read//, which opens a file, can print an error if it doesn't
exist, and if it does, then feeds the lines one at a time to an iterator.
For example, if |F| is a filename, the following reads the file into a
linked list of texts:
= (text as InC)
	linked_list *Hypothetical::list_from_file(filename *F) {
		linked_list *L = NEW_LINKED_LIST(text_stream);
		TextFiles::read(F, FALSE, "can't open colony file",
			TRUE, Hypothetical::helper, NULL, (void *) L);
		return L;
	}

	void Hypothetical::helper(text_stream *line, text_file_position *tfp, void *v_L) {
		linked_list *L = (linked_list *) v_L;
		ADD_TO_LINKED_LIST(text, line, L);
	}
=
The //text_file_position// here keeps track of where we are, and in particular,
functions from //Error Messages// can then report errors where they occur:
= (text as InC)
	Errors::in_text_file("bad syntax here", tfp);
=

@ The //Preprocessor// provides simple iteration and macro expansion in order
to turn a marked-up script into a plain text file. Extensive use is made of
this in order to construct //Makefiles// and the like: see also //Git Support//,
which helps with |.gitignore| creation, and //Readme Writeme//, a convenient
utility for generating |README.md| files for GitHub repositories.

@ See //JSON// for convenient ways to encode and decode data to the JSON
interchange format.

@h Literate programming.
The foundation library was created to serve a family of compilers which all
make use of ideas from "literate programming", and they provide extensive
support for parsing, weaving and tangling webs of LP source code. These are
used not only to build, for example, the Inform compiler, but also within
that compiler, to read literate source.

This isn't the place to explain what a literate program is: if you're reading
this, you're looking at one. But the terminology and data structures we use
might be worth a brief overview:

A "web" is a literate-programming expression of either a stand-alone program,
or a library of code which can be "imported" by other webs. Each web is
represented in the filing system either by its own private directory of
resources, which is good for larger programs or libraries, or more simply
by a single file, which is less fuss for simpler programs. Each web is
represented in memory by an |ls_web| structure.

A web is basically some metadata together with some literate code divided
into chapters, each represented by an |ls_chapter|. A chapter is further
divided into sections, each an |ls_section|. Small single-file webs don't
appear to have these, but in fact they do: there's an implicit chapter
containing an implicit section, which contains the program. Middle-sized
webs divided into section files in the filing system similarly have an implicit
chapter to hold those sections. So all webs of every size have an |ls_web|
holding |ls_chapter| holding |ls_section| hierarchy.

Because one web can import another one (see above), it may contain chapters
drawn from multiple sources. These are called its "modules", and represented by
|ls_module| structures. A simple web which imports nothing has just one "main
module", holding its entire source. But if a web representing tool X imports
library L, then there will be two modules for X: the main module and also the
module of code imported from L. Since an imported module might then import other
modules in turn, the modules of a web form a small dependency graph, of which
the main module is the root.

@ Each section then contains a single "unit" of literate source, held in an |ls_unit|.
This consists of |ls_paragraph| objects, which in turn are divided into |ls_chunk|
objects, which in turn contain |ls_line| objects. This paragraph you're reading
is a single |ls_paragraph|, containing a single |ls_chunk|, with 11 |ls_line|s (one
blank). More complex paragraphs might have a chunk of commentary text, then some
definitions (each of which is another chunk), then a block of code (another chunk
again). 

Fragments of source code which are part of the program to be compiled are called
"holons". So only some chunks are holons, and details of the code they hold are
held in |ls_holon| objects. (Note that a definition of a symbol is not a holon.)

Parsing a unit mostly involves "classifying" its lines according to the current
notation being used for LP. We support multiple notations, with the current
parsing rules being expressed as an |ls_notation| object. Classification of a
line produces |ls_class| objects as intermediate results, and if it goes badly
then it can also produce errors, each stored as an |ls_error|.

@ To sum up, then, webs are stored in the following nine structures:

= (text)
	ls_web
		with tree of at least 1 ls_module
		and list of 1 or more ls_chapter
			each with list of 1 or more ls_section
				each with exactly 1 ls_unit
					each with list of 0 or more ls_paragraph
						each with list of 1 or more ls_chunk 
							where one chunk in the list may have 1 ls_holon
							and every chunk has a list of 1 or more ls_line
					and a list of 0 or more ls_error
=

Note that a web must have at least one chapter, each chapter must have at
least one section, each paragraph must have at least one chunk, and each
chunk must have at least one line. The empty program would be stored as:

= (text)
	ls_web
		1 ls_module
		1 ls_chapter
			1 ls_section
				1 ls_unit
					with 0 ls_paragraph objects
=

@ The fundamental things we can do with a web, then, are:

(a) Parsing. Literate source has highly customisable markup syntax: see
//Web Notations//.

(b) Tangling. See //The Tangler// for how this is done. Note that tangling
can be performed entirely in memory, so that tools such as Inform can read
literate source and tangle it internally, avoiding the need for secondary
LP tools or intermediate files stored on disc.

(c) Weaving. See //The Swarm// for an overview of how complex weaves are
divided into a "swarm" of simple ones, each of which generates a "weave tree"
of rendering instructions. See //Format Methods// and its subsidiaries,
such as //HTML Formats//, for the actual process of rendering weave output
from the tree.

@ Literate programs are, at the end of the day, still programs, and are
written in programming languages. We need to understand those languages
at least a little in order to syntax-colour them when weaving, and also
in order to provide convenient tangling features when tangling. See
//Programming Languages// for how we define their syntactic and other quirks.

Languages declaring themselves "C-like" have access to special tangling
facilities, all implemented with non-ACME method calls: see //C-Like Languages//.
In particular, for coping with how |#ifdef| affects |#include| see
//CLike::additional_early_matter//; for predeclaration of functions and
structs and |typedef|s, see //CLike::additional_predeclarations//.

A special language calling itself "InC" gets even more: see //InC Support//, and
in particular //text_literal// for text constants like |I"banana"|
and //preform_nonterminal// for Preform grammar notation like
|<sentence-ending>|. "InC" is basically a more convenient form of C, and
is the language in which the foundation library is written.

@h Miscellaneous other features.
What else? Well:
(a) //Time// for the time of day and the date of Easter (no, really), and
for timing internal program activity using //Time::start_stopwatch// and
//Time::stop_stopwatch//;
(b) //Shell// for issuing shell commands via the C library's |system| function,
or its equivalent;
(c) //HTML// and //Epub Ebooks// for generating web pages and ebooks;
(d) //Image Dimensions// and //Sound Durations// for handling videos and music;
(e) //Version Numbers// and //Version Number Ranges// for managing version
numbers of software according to the Semantic Versioning standard.
