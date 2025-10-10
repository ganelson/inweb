A Brief Guide to Literate.

Notes on using the Literate library.

@h Introduction.
The Literate library builds on //foundation// and provides an extensive suite
of code to handle "literate programs".

A tool can import //literate// only if it also imports //foundation//.

@h Importing the module.
We'll use the term "parent" to mean the tool which is importing //literate//,
that is, which will include its code and be able to use it. As with any
imported module,
(*) The contents page of the parent's web must identify and locate the
module:
= (text as Inweb)
Import: literate
=
(*) The parent must call |LiterateModule::start()| just after it starts up, and
|LiterateModule::end()| just before it shuts down. (But just after, and just
before, the corresponding calls to //foundation//.)

@h Literate programming.
This library was created to serve a family of compilers which all make use of
ideas from "literate programming", and they provide extensive support for
parsing, weaving and tangling webs of LP source code. These are used not only to
build, for example, the Inform compiler, but also within that compiler, to read
literate source.

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

@ There are also some minor conveniences for setting up Github repositories
which contain literate programs. In particular, we use the preprocessor of
//foundation// to construct //Makefiles// and the like: see also //Git Support//,
which helps with |.gitignore| creation, and //Readme Writeme//, a convenient
utility for generating |README.md| files for GitHub repositories.
