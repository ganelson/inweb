The InC Dialect.

A modest extension of C used by the Inform project.

@h The InC language.
InC is only a little extended from regular C. All of the Inform tools are
written in InC, as is the |foundation| module of utility routines built in
to Inweb. It's probably not sensible to use InC in a web which does not
import |foundation|, and it's certainly not possible to import |foundation|
on a web not written in InC. So the two go together.

@ Though this is really a feature of Inweb rather than InC, and is also
true of regular C webs, functions, definitions and typedef structs need not
be declared before use. In this way, the need for header files can be
avoided altogether.

@ Each section of an InC web can, optionally, begin:
= (text as Inweb)
	[Namespace::] The Title of This Section.
=
rather than, as normal,
= (text as Inweb)
	The Title of This Section.
=
That declares that all functions in this section must be have a name which
begins with |Namespace::|. For example,
= (text as InC)
	int Namespace::initialise(void) {
	    ....
	}
=
Inweb will not allow a function with the wrong namespace (or with none) to
be declared in the section. This rudimentary feature enables the different
sections of the web to behave like packages or modules in languages which
support rather more compartmentalisation than standard C.

The tangler converts these identifiers to regular C identifiers by converting
the |::| to |__|, so in a debugger, the above function would look like
|Namespace__initialise|.

Namespaces can be "nested", in the sense that, for example, we could have:
= (text as Inweb)
	[Errors::Fatal::] Handling fatal errors.
=
@ The |foundation| module contains a suite of utility functions for handling
strings and streams of text. These are unified in a structure called
|text_stream|, so that strings in InC webs are almost all values of type
|text_stream *|. InC provides one convenient feature for this: the notation
= (text as Inweb)
	text_stream *excuse = I"The compiler is not feeling well today.";
=
creates a string literal of this type. (This is analogous to ANSI C's little
used syntax for "long strings", which is |L"like so"|.)

@ The |words| module, a component of the Inform compiler which is not
included in Inweb, defines natural-language grammars in a notation called
Preform. Inweb contains support for writing these directly into code; any
paragraph whose code section makes use of this feature is automatically
tagged |^"Preform"|. This is not the place to document what Preform
notation means, but for example:

= (text)
	<declaration> ::=
		declare <dominion> independent	==>	R[1]

	<dominion> ::=
		canada |
		india |
		malaya
