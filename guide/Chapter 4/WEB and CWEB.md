# WEB and CWEB

These are somewhat experimental features provided with a view to being able
to read existing webs in two 1980s LP systems, for historical interest: there's
no intention here to support these formats for the creation of new webs.
The implementation is in any case incomplete, as noted below.

## CWEB

`CWEB` is the adaptation of `WEB` (see below) to C rather than Pascal, and is
a system still used by Knuth for smaller programs, such as those written in
the course of his work on _The Art of Computer Programming_.

Inweb has only limited `CWEB` support, but can weave and even tangle some modest
C programs. For example, Knuth wrote a web called `backpdi.w` which computes
every integer which is equal to the sum of the $m$-th powers of its digits.
Renaming this `backpdi.c.cweb`, we obtain:

	$ inweb inspect back-pdi.c.cweb
	web "Untitled" (C program in CWEB notation): 22 paragraphs : 367 lines

CWEB has no concept of metadata such as titling: hence, "Untitled". The rest
looks correct, though, and:

	$ inweb weave back-pdi.c.cweb
	weaving web "Untitled" (C program in CWEB notation) as HTML
    	generated: back-pdi.html
    	11 files copied to: docs/docs-assets

	$ inweb tangle back-pdi.c.cweb -using CWEB.inweb
	tangling web "Untitled" (C program in CWEB notation) to file 'back-pdi.c'

This code is written in an antique dialect of C, so:

	$ clang -std=c89 back-pdi.c -o back-pdi
	$ ./back-pdi 3
	1: 7400->0407
	2: 7310->0371
	3: 7300->0370
	4: 5310->0153
	5: 1000->0001
	6: 0000->0000
	Altogether 6 solutions for m=3 (110 nodes, 4662 mems).

And indeed $4^3 + 0^3 + 7^3 = 64 + 0 + 343 = 407$, so score one for Professor Knuth:
the solutions are 407, 371, 370, 153, 1 and 0.

Support for `CWEB` remains limited, nevertheless. The following are not implemented:

- the `@x`, `@y`, `@z` syntax used only in change files (Knuth's reinvention of
  `diff`);
- the `@l` syntax for handling ISO Latin-1 (not very well);
- the syntax `@'x'` to mean the character code for `x`;
- the syntax `@f IDENTIFIER TeX`, i.e., the `TeX` special case of `@f`, which
  would be tiresome to explain.

Moreover, holon names are not allowed to run over multiple lines, as they are
in CWEB; and a few other such issues mean that not all valid CWEB webs can be
read in, as yet. More work may or may not be done on this.

## WEB

`WEB` was the original literate programming tool, created by Donald Knuth in
order to manage the source code for his typographic programs TeX and Metafont.
Properly speaking there were two tools, `WEAVE` and `TANGLE`, but collectively
they are called `WEB`. These were tied to a form of Pascal no longer used,
and are difficult to emulate without essentially porting them wholesale.

Inweb has even more limited support for reading `WEB` files. Currently, it can
parse `WEAVE` and `TANGLE` successfully:

	$ inweb weave weave.pas.web
	weaving web "Untitled" (Pascal program in WEB notation) as HTML
		generated: weave.html
		10 files copied to: weave-assets

Note that a WEB file must be filenamed `NAME.pas.web` in order for Inweb to
pick up its notation. As yet, `tex.pas.web` does not parse: it contains some
direly convoluted syntax. More work may or may not be done on this.
