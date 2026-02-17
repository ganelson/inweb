# Special C Features

## Of rats and men

In 1974, Brian Kernighan had finally had enough. Despite all advances in
programming language design since 1953 his colleagues were, infuriatingly, still
using FORTRAN. (And don't hold your breath: in 2026, it still remains in 12th
place on the TIOBE usage index.) In an attempt to bargain, Kernighan wrote a
preprocessor which would superimpose better language features on top of FORTRAN.
He called it "rational FORTRAN", though the rodent-like filename RATFOR is what
we now remember.

This was an idea of its time. An under-appreciated feature of the early Unix era
is that it saw a great flowering of techniques by which programs wrote other
programs, something previously difficult since computers had too little memory,
and sometimes had file systems rigidly distinguishing between program files and
data. Unix did not, so why shouldn't the output of one program be the source
code for another?

Language preprocessors tend to be stopgaps which do not last. Similar new features
to those in RATFOR were ultimately incorporated in the FORTRAN 77 revision. When
Bjarne Stroustrup began what became C++ in 1979, he used a preprocessor to C,
but by 1983 a native C++ compiler had replaced this. The trouble with preprocessors
is that they incur time overheads, and complicate build mechanisms, and report
errors waywardly. And the trouble with language extensions is that programmers
generally prefer the official, standard design, even when it's not very good,
just as chess players hardly ever play "fairy chess" — variants of the game with
exotic pieces, or different rules for captures.

But literate programming also comes out of this period, and when Donald Knuth
worked on the first WEB tool in 1980-84, he combined it with a suite of language
"improvements" so that using WEB wasn't so much coding in Pascal as a sort of
RAT-Pascal. Pascal was poorly standardised, and its design was not ideal for
system-software tools of the kind Knuth wanted to write. But it needed only a
little work: and since Knuth was, after all, using a preprocessor anyway, in
order to tangle code, why not throw in some new Pascal features along the way?

The answer to that "why not" question is: because it will tie the program too
closely to the preprocessor, and make it difficult to port. It is far from
easy to compile Knuth's great programs TeX and Metafont nowadays, because the
original Pascal dialect is obsolete. Even converting a web from WEB to CWEB,
say, porting the Pascal code to C, is a very non-trivial business.

## Supposed improvements

"Improving" languages is a trap for authors of literate programming tools. Inweb
would arguably be a cleaner design if it did not fall into that trap: but in
fact it has. Specifically:

- When tangling a language which is a C variant, Inweb provides a number
  of minor conveniences, such as predeclaring functions automatically and
  reordering structure declarations — in both cases, so that programmers
  don't need to define things in any particular order, or repeat themselves.

- When tangling a particular C variant called "InC", Inweb does even more,
  and recognises a new sort of string literal, for example.

### Declaring a language C-like

Inweb's concept of being "C-like" means they really are very closely related —
Rust, for example, may have a lot of C heritage in it, but would not qualify.
So the property `C-Like` should be set to `true` only for a language which
really is a C variant adopting almost all of C's syntax. Of the languages
supplied with Inweb, only C itself, C++, and InC are `C-Like`.

This setting has two consequences:

1. The `Function Declaration` and `Type Declaration` properties are ignored,
   so that there is no point in setting them. Instead, code hard-wired into
   Inweb performs its own scan for C function and typedef declarations.

2. Four conveniences are provided which affect the way tangling is performed.
   They are off by default, and must be enabled by making `Conventions`.

So, then, Inweb's definition of C includes:

	Conventions {
		...
		standard library #includes are tangled early in the program
		typedefs are tangled early in the program
		typedef structs are tangled early and reordered logically
		function predeclarations are tangled automatically
	}

Because the C definition includes the property `C-Like: true`, these four
features are potentially available, but without those conventions being made
as well, they would not take effect. Any web written in C can then render
them ineffective again, by making one or more of the following conventions:

	Conventions {
		...
		standard library #includes are treated like any other code
		typedefs are treated like any other code
		typedef structs are treated like any other code
		functions are treated like any other code
	}

With those changes made, the language really is regular C, with all its
charms and frustrations. Although the better function/struct scans mentioned
in (1) above still happen, they then affect only weaving.

So, then:

* `standard library #includes are tangled early in the program` pulls forward
  lines like `#include <stdio.h>` (written with angle brackets) for the C standard
  library files (only), so that they're tangled early.
  
* `typedefs are tangled early in the program` similarly pulls forward lines which
  make simple typedefs not involving structures, like `typedef unsigned long long big`.

* `typedef structs are tangled early and reordered logically` is best explained
  by example. Suppose the program contains:
  
      cake birthday_cake;
      ...
      typedef struct cake {
          struct filling f;
      } cake;
      ...
      typedef struct filling {
          int jam;
      } filling;

  This will fail to compile for two reasons: `cake` is unknown at the time
  `cake birthday_cake` is read, because the compiler has not yet reached
  the typedef of `cake`; and `struct filling` needs to be fully declared
  _before_ `struct cake` is declared (since it is incorporated, rather
  than simply pointed to). If `typedef structs are tangled early and reordered logically`,
  both these problems are solved automatically, as Inweb tangles the code
  into the right order to avoid them.

* `function predeclarations are tangled automatically` avoids the need for
  functions to be predeclared before use. For example, suppose:
  
      void first(void) {
          second();
      }
      void second(void) {
          printf("Hello, there.\n");
      }

  This will fail to compile because `second` is unknown when `first` is compiled.
  Often by means of header files, C programmers overcome this with predeclarations:
  
      void second(void); /* predeclaration */
      void first(void) {
          second();
      }
      void second(void) {
          printf("Hello, there.\n");
      }

  This is a nuisance, and if `function predeclarations are tangled automatically`
  then Inweb will automatically tangle predeclarations of all functions.

### InC

InC is a whole other ball of wax. It was contrived as a minimal set of
conveniences for managing the very large ANSI C source code for the Inform
compiler and related tools (including Inweb itself: Inweb is written in InC).
It is not any sort of attempt to create a "better" C across the board. In
that sense InC is not a general-purpose programming language. In particular,
the following limitations currently exist:

- InC can only be used literately, i.e., with Inweb. There is no freestanding
  "InC compiler". InC is tangled down to ANSI C, and the result can then be
  compiled with `clang` or `gcc`.
- InC programs must be multi-file webs, not single-file.
- They must all import the `foundation` module (included with Inweb).
- They must be written in `InwebClassic` notation.

With that said, InC is a stable design which has been used on a variety
of tools by the Inform project for many years now. Anyone is welcome to use it.

-- -- --

Firstly, InC has `C-Like: true` set, and enables all four of the above features
for making C-like languages less fussy about code order.

-- -- --

InC is also the only language included with Inweb which has the property
`Supports Namespaces: true` set. This feature is not strictly speaking tied
to C variants only, but it was inspired by a need for a managed system of
function name prefixes, because very large C code-bases are in dire need of
internal organisation, and C does not have the means. Setting this property
has four effects:

1. Function names are allowed to take the form `Namespace::Name`. For example,
   Inweb has a function called `WebNotation::supports_named_holons`, where
   the namespace is `WebNotation`. The only exception is `main`. External
   functions not declared in the web source, such as the C library's `printf`,
   are of course also left bare.

2. Each section of the literate source can declare that is is part of a namespace.
   (It can't be partly in one, partly in another.) Inweb throws an error if
   it finds a function name whose namespace does not match that of its section.
   Again, `main` is an exception.

3. For weaving and syntax-colouring purposes, `::` is considered part of an
   identifier, as it otherwise would not be. `WebNotation::supports_named_holons`
   would by default be syntax-coloured like `main`, with the colons having the
   same colour as the letters. (Colouring programs can of course override this.)

4. For tangling purposes, the `::` in a name is converted to `__`, so that the
   function as sent to the C compiler is called `WebNotation__supports_named_holons`.
   This needs to be remembered if working with a debugger on the resulting program.

The sections of an InC program, which must be written in `InwebClassic` notation,
open with a titling line. If it takes the form:

	[Namespace::] Actual Title.

...then the namespace given is the one for the section, which all its functions
must live in. For example:

	[WebNotation::] Web Notations.

-- -- --

As noted above, InC webs all have to import the `foundation` modules. One of
its services is a system for extensible strings of Unicode text, called
"text streams" (since text file output is handled by the same mechanism,
unifying files and strings to some extent). InC provides a new sort of literal
for this type:

	text_stream *S = I"alpha beta gamma delta";

This syntax is intended to extend existing C syntax, which already has
several different sorts of string literal identified by an initial letter:

example                     | type
--------------------------- | -----------------------------------------
`"alpha beta gamma delta"`  | `char[]`: null-terminated bytes
`L"alpha beta gamma delta"` | `wchar_t[]`: null-terminated bytes
`U"alpha beta gamma delta"` | `uint32_t[]`: null-terminated bytes
`I"alpha beta gamma delta"` | `text_stream *`: pointer to opaque object

Note that a `text_stream` is not an array. Access to its contents is provided
by the string-manipulation functions in `foundation`.

-- -- --

Finally, InC provides for an arcane notation used only in the Inform compiler
to write "Preform", a set of grammar productions for its language. This is not
the place to document that: see the `words` module in the Inform code base.

But for example the following is legal InC code:

	<declaration> ::=
		declare <dominion> independent	==>	{ R[1], - }

	<dominion> ::=
		canada |
		india |
		malaya

and `<declaration>` can then be used as if it were a function, in C terms:

	if (<declaration>(W)) { ... }

Other programs in InC, such as Inweb and Intest, make no use of any of this.
