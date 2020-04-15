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
own right. Inweb has two: the main part of the program, and //foundation//,
a library of utility functions. See //foundation: A Brief Guide to Foundation//.
