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

1.	The Contents section of its web must import Foundation as a module, thus:

	``` None
		Import: foundation
	```

	Import lines appear after the metadata, but before the roster of sections
	and chapters.

2.	The constant `PROGRAM_NAME` must be defined equal to a C string with a
	brief version of the program's name. For example,

	``` None
		@d PROGRAM_NAME "declutter"
	```

3.	The `main` function for the client should, as one of its very first acts,
	call `Foundation::start()`, and should similarly, just before it exits, call
	`Foundation::end()`. Any other module used should be started after Foundation
	starts, and ended before Foundation ends.

@h Truth.
Every large C program starts by defining constants for truth and falsity. So
does Foundation: `TRUE`, `FALSE`, and a third state `NOT_APPLICABLE`.

@h Text streams and formatted output.
Perhaps the most useful feature of Foundation is that it provides for
memory-managed strings of Unicode text. These are unified with text files
which are open for output, in a type called //text_stream//. It's expected
that they may be very large indeed, and appending text to or finding the
length of a text in memory runs in $O(1)$ time.

A typical function writing to one of these might be:

	void Hypothetical::writer(text_stream *OUT, text_stream *authority, int N) {
		WRITE("According to %S, the square of %d is %d.\n", authority, N, N*N);
	}

Here `WRITE` is a variadic macro rather like `printf`, and note the use of
the escape `%S` to write a text stream. It writes formatted output into the
stream `OUT`, and is actually an abbreviation for this:

	void Hypothetical::writer(text_stream *OUT, text_stream *authority, int N) {
		WRITE_TO(OUT, "According to %S, the square of %d is %d.\n", authority, N, N*N);
	}

The function `Hypothetical::writer` can write equally to a text file or to a
string, whichever it's given, and doesn't need to worry about memory management
or text encodings.

The standard output and standard error "files" on Unix-based systems are
referred to as `STDOUT` and `STDERR`, both constants of type `text_stream *`
defined by Foundation. The value `NULL`, used as a text stream, is valid and
prints as the empty string, while ignoring any content written to it.
All of these capitalised macros are defined in //Streams//.

`PRINT("...")` is an abbreviation for `WRITE_TO(STDOUT, "...")`, and
`LOG("...")` similarly writes to the log file. (See //Debugging Log//.)

@ If you're using InC, the slight extension to C made by Inweb, there's a
simple notation for constants of this type:

	text_stream *error_message = I"quadro-triticale stocks depleted";

The `I` prefix is meant to imitate the `L` used in standard C99 for long string
constants. But this is a feature of //inweb// rather than of Foundation.

@ Programs doing a lot of parsing need to create and throw away strings all
of the time, so we shouldn't be too casual about memory management for them.
//Str::new// creates a new empty string; //Str::duplicate// duplicates an
existing one. But these are permanent creations, and not easy to deallocate
(though calling //Str::clear// to empty out their text will free any large
amount of memory they might be using). If you want a string just for a
momentary period, do this:

	TEMPORARY_TEXT(alpha)
	WRITE_TO(alpha, "This is temporary");
	...
	DISCARD_TEXT(alpha)

Between the use of these two macros, `alpha` is a valid `text_stream *`,
and is a string capable of growing to arbitrary size.

@ Foundation provides an elaborate system for providing new string escapes
like `%S`: see //Writers and Loggers//. A similar system manages a debugging
log, to which it's easy to make "dollar escapes" for pretty-printing internal
data structures: for example, if you've made a structure called `recipe`, you
could make `$R` pretty-print one.

@ Foundation also has an extensive library of string-handling routines,
providing the sort of facilities you would expect in a typical scripting
language. See //String Manipulation// and //Pattern Matching//, which can
match text streams against regular expressions, though note that the latter
use an idiosyncratic notation.

There's also //Tries and Avinues// for rapid character sequence parsing.

For slicing, see the //string_position// type, representing positions for the
benefit of functions like //Str::substr//.

@ Individual characters are represented in Foundation using the standard
POSIX type `inchar32_t`, which on all modern systems is a very wide integer,
whether or not signed. It's safe to assume it can hold all normal Unicode
code points. See //Characters// for class functions like //Characters::isdigit//,
which have been carefully written to work equivalently on either Windows or
Unix-based systems.

//C Strings// and //Wide Strings// provide bare-minimum facilities for handling
traditional null-terminated `char` and `inchar32_t` arrays, but don't use these.
Texts are just better.

@h Objects.
To a very limited extent, Foundation enables C programs to have "classes",
"objects" and "methods", and it makes use of that ability itself, too. For
example, suppose we are writing a program to store recipes, and we want
something in C which corresponds to objects of the class `recipe`.

We do this with a special feature of InC called `classdef`:

	classdef recipe {
		struct text_stream *name_of_dish;
		int oven_temperature;
	}

This does several book-keeping things, but in C language terms, it typedefs
`recipe` to mean the above structure.

If we expect to have huge numbers of throwaway instances, we might instead write:

	classdef recipe in 1000s {
		struct text_stream *name_of_dish;
		int oven_temperature;
	}

The memory manager then claims these in blocks of 1000. Use this only if it's
actually needed; note that `DESTROY` cannot be used with objects created
this way.

The macro `CREATE(recipe)` returns a new instance, that is, a `recipe *`
pointer to a newly-allocated block of memory with enough space for the above
structure. Likewise, `DESTROY(R)` would destroy an existing `recipe *` pointer
`R`, after which it is never safe to use the value of `R` again. Unless manually
destroyed, objects last forever; there is no garbage collection. In practice
the Inform tools suite, for which Foundation was written, almost never destroy
objects.

`CREATE` by itself is not a good constructor function because the contents
of the structure are, in principle, undefined. (On some platforms they will
tend to contain zeros throughout: but do not rely on this.) So the better
thing is to wrap `CREATE` in a constructor function:

	recipe *Recipes::new(text_stream *name) {
		recipe *R = CREATE(recipe);
		R->name_of_dish = Str::duplicate(name);
		R->oven_temperature = 200;
		return R;
	}

We also often use the convenient `LOOP_OVER` macro:

	void Recipes::list_all(text_stream *OUT) {
		WRITE("I know about the following recipes:\n");
		recipe *R;
		LOOP_OVER(R, recipe)
			WRITE("- %S\n", R->name_of_dish);
	}

`LOOP_OVER` loops through all created `recipe` instances (which have not been
destroyed).

There are a few other facilities, for which see //Memory//, and also ways to
allocate memory for arrays — see //Memory::calloc// and //Memory::malloc//.

@h Methods.
It's also possible to have method calls on object instances, though the
syntax is not as tidy as it would be in an object-oriented language. To allow
this for `recipe`, we would have to add another line to the structure:

	classdef recipe {
		struct text_stream *name_of_dish;
		int oven_temperature;
		struct method_set *methods;
	}

and another line to the constructor function:

		R->methods = Methods::new_set();

The object `R` is then ready to receive method calls. Each different call needs
an enumerated constant ending `_MTID` to identify it, and an indication of the
type of the function call involved:

``` None
	@ Here is my "cook the recipe" method call:
	
	@e COOK_MTID
	
	=
	VOID_METHOD_TYPE(COOK_MTID, recipe *R, int time_in_oven)
```

It's now possible to call this on any recipe:

	VOID_METHOD_CALL(duck_a_l_orange, COOK_MTID, 45);

What then happens? Nothing at all, unless the recipe instance in question —
here, `duck_a_l_orange` — has been given a receiver function. Let's revisit
the constructor function for recipes:

	recipe *Recipes::new(text_stream *name) {
		recipe *R = CREATE(recipe);
		R->name_of_dish = Str::duplicate(name);
		R->oven_temperature = 200;
		R->methods = Methods::new_set();
		METHOD_ADD(R, COOK_MTID, Recipes::cook);
		return R;
	}

and now add:

	void Recipes::cook(recipe *R, int time_in_oven) {
		...
	}

using the arguments promised in the declaration above. With all this done,
the effect of

	VOID_METHOD_CALL(duck_a_l_orange, COOK_MTID, 45);

is to call:

	Recipes::cook(duck_a_l_orange, 45);

@ In fact it's possible to attach multiple receivers to the same object, in
which case they each run in turn. As a variant on this, methods can also return
their "success". If multiple receivers run, the first to return `TRUE` has
claimed the right to act, and subsequent receivers aren't consulted.

Such methods must be defined with `INT_METHOD_CALL` and are rarely needed. See
//Methods// for more.

@h Collections.
Foundation provides three sorts of "collection": see //Linked Lists and Stacks//,
and also //Dictionaries//. These all collect values which are expected to be
pointers: for example, text streams (of type `text_stream *`) or objects like
the ones created above. For example,

	linked_list *cookbook = NEW_LINKED_LIST(recipe);

initialises a list as ready to use. It's then accessed by macros:

	recipe *lobster_thermidor = Recipes::new(I"lobster thermidor", 200);
	ADD_TO_LINKED_LIST(lobster_thermidor, recipe, cookbook);

Similarly:

	recipe *R;
	LOOP_OVER_LINKED_LIST(R, recipe, cookbook)
		PRINT("I can make %S.\n", R->name_of_dish);

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
the null `pathname` pointer. //Pathnames::up// and //Pathnames::down// go
to parent or subdirectories, respectively. A filename cannot exist without
a pathname; for example,

	pathname *P = Pathnames::down(NULL, I"App")
	P = Pathnames::down(P, I"Config")
	filename *F = Filenames::in(P, I"options.txt");
	PRINT("I have arrived at %f.\n", F);

produces, on platforms where `/` is used as the file system dividing character,

	I have arrived at App/Config/options.txt.

Note the use of the escape `%f` for printing filenames; there's also `%p` for
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
For example, if `F` is a filename, the following reads the file into a
linked list of texts:

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

The //text_file_position// here keeps track of where we are, and in particular,
functions from //Error Messages// can then report errors where they occur:

	Errors::in_text_file("bad syntax here", tfp);

@ The //Preprocessor// provides simple iteration and macro expansion in order
to turn a marked-up script into a plain text file.

@ See //JSON// for convenient ways to encode and decode data to the JSON
interchange format.

@h Miscellaneous other features.
What else? Well:

- //Time// for the time of day and the date of Easter (no, really), and
for timing internal program activity using //Time::start_stopwatch// and
//Time::stop_stopwatch//;

- //Shell// for issuing shell commands via the C library's `system` function,
or its equivalent;

- //HTML// and //Epub Ebooks// for generating web pages and ebooks;

- //Image Dimensions// and //Sound Durations// for handling videos and music;

- //Version Numbers// and //Version Number Ranges// for managing version
numbers of software according to the Semantic Versioning standard.
