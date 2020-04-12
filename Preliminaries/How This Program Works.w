How This Program Works.

An overview of how Inweb works, with links to all of its important functions.

@h How to read this web.
Inweb is a program for weaving and tangling literate programs, or "webs",
and it is a web itself. Webs are easy to read, which is really the point
of them, but they take getting used to, and it may be easiest to begin by
skimming the two (deliberately minimal) examples here, //goldbach// and
//twinprimes//.

Inweb is a command-line program written in a modest extension of C. See
//The InC Dialect// for full details, but essentially: it's C without
function predeclarations or header files, and where functions are organised
into namespaces, having names like |Parser::begin()| rather than just |begin()|.

Programs like Inweb are divided into "modules", each of which is a web in its
own right. Inweb has two: the main part of the program, and a library of
utility functions called Foundation.

@h Basics of using Foundation.
Foundation provides Unicode text, lists, memory management, file handling,
regular expression matching, dictionaries of key-value pairs, and so on.
See //foundation// to read it as a web, but you shouldn't need to.

To a limited extent, Foundation enables C programs like Inweb to have "objects"
and "methods". For example, Inweb has a concept of "weave plugins", and these
are identified (by reference) using values of type |weave_plugin *|. The
relevant section of the Inweb source defines the type //weave_plugin// and
gives a constructor function for making new ones, //WeavePlugins::new//.
This is then returned as a |weave_plugin *| pointer which has an infinite
lifespan: though Foundation can also delete objects, Inweb never asks it to.

Foundation itself contains many useful types, and the most ubiquitous is
//text_stream//. This unifies text files and memory-managed strings of Unicode
text. A typical function writing to this might be:
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

The standard output and standard error "files" are written |STDOUT| and |STDERR|
as streams; |PRINT("...")| is an abbreviation for |WRITE_TO(STDOUT, "...")|.
All of these capitalised macros are defined in //Streams//.
