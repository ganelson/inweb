How to Write a Web.

How to mark up code for literate programming.

@h The title of a section.
In any section file, there will be a few lines at the top which occur before
the first paragraph of code begins. (The first paragraph begins on the first
line which starts with an |@| character.)

The first line should be the title of the section, followed by a full stop.
For example:

	|The Sieve of Eratosthenes.|

A section title must contain only filename-safe characters, and it's probably
wise to make them filename-safe on all platforms: so don't include either
kind of slash, or a colon, and in general go easy on punctuation marks.

Optionally, a section heading can also specify its own range abbreviation,
which must be given in round brackets and followed by a colon:

	|(S/sieve): The Sieve of Eratosthenes.|

If this is not done (and usually it is not), Inweb will construct a range
abbreviation itself: in this case, it comes up with |S/tsoe|.

Subsequent lines of text are then taken as the optional description of the
purpose of the code in this section. (This is used on contents pages.) For
example:

	|A fairly fast way to determine if small numbers are prime, given storage.|

@h Paragraphing.
A standard paragraph is introduced with an |@| command, which must place
that magic character in the first column of the line:

	|@ This is some comment at the start of a new paragraph, which...|

A fancier paragraph with a subheading attached is introduced using the
|@h| or |@heading| command instead. (This is simply a long and short version
of the same command.) The text of the subheading then follows, up to the
first full stop.

	|@heading Reflections on the method.|

Paragraphs can contain three ingredients, all optional, but if given then
given in this order: comment, definitions, and code. The following
example shows all three being used:

	|@h Primality.|
	|We provide this as a function which determines whether a number|
	|is prime:|
	||
	|@d TRUE 1|
	|@d FALSE 0|
	||
	|=|
	|int isprime(int n) {|
	|    if (n <= 1) return FALSE;|
	|    for (int m = 2; m*m <= n; m++)|
	|        if (n % m == 0)|
	|            return FALSE;|
	|    return TRUE;|
	|}|

@ Definitions are made using one of two commands: |@d| or |@define|, or
|@e| or |@enum|. These create new constants in the program, with the values
given: they are the equivalent of a |#define| directive in C. |@define| is
the simpler form. For example,

	|@define USEFUL_PRIME 16339|

sets |USEFUL_PRIME| to 16339. Unlike in the C preprocessor, multi-line
definitions are automatically handled, so for example:

	|@ The following macro defines a function:|
	|@d EAT_FRUIT(variety)|
	|    int consume_by_##variety(variety *frp) {|
	|        return frp->eat_by_date;|
	|    }|
	|=|
	|banana my_banana; /* initialised somewhere else, let's suppose */|
	|EAT_FRUIT(banana) /* expands with the definition above */|
	|void consider_fruit(void) {|
	|    printf("The banana has an eat-by date of %d.", consume_by_banana(&my_banana));|
	|}|

In fact, a definition continues until the next definition, or until the code
part of the paragraph begins, or until the paragraph ends, whichever comes
first.

Enumerations with |@enum| are a convenience to define enumerated constants.
For example,

	|@enum JANUARY_MNTH from 0|
	|@enum FEBRUARY_MNTH|
	|@enum MARCH_MNTH|

and so on, is equivalent to

	|@define JANUARY_MNTH 0|
	|@define FEBRUARY_MNTH 1|
	|@define MARCH_MNTH 2|

What happens is that |@enum| looks at the tail of the name, from the last
underscore to the end: in this case, |_MNTH|. The first time an enumerated
value is asked for with this tail, |from| is used to specify the lowest
number to be used - in the above case, months begin counting from 0. With
each subsequent |_MNTH| request, |@enum| allocates the next unused value.

All symbols defined with |@define| or |@enum| are global, and can be used
from anywhere in the web, including in sections or paragraphs earlier than
the ones in which they are defined. (The tangler automatically arranges code
as necessary to make this work.)

@ Finally, a paragraph can contain code. This is introduced with an equals
sign: in some sense, the value of the paragraph is the code it contains.
In many paragraphs, as in the example above, the divider is just

	|=|

and this means that the rest of the paragraph is part of the program.
Ordinarily, this must appear in column 1, but a special abbreviation is
allowed for paragraphs with no comment and no definitions:

	|@ =|

This is exactly equivalent to:

	|@|
	||
	|=|

We can tell the tangler to place the code early in the tangled program,
rather than at its natural place in the sequence, by annotating

	|= (early code)|

instead of just |=|. (This is occasionally useful where, for example, it's
necessary to create global variables which will be referred to in other
sections of code.) The more extreme |= (very early code)| can be used in C
for complicated header file inclusions, but should be kept to an absolute
minimum, if only for clarity.

We can also tell the tangler to ignore the code completely:

	|= (not code)|

That may seem paradoxical: when is code not code? When it's an extract of
text being displayed for documentation reasons, is the answer. Syntax
colouring is turned off for such code, since it's probably not written
in the same language as the code.

@ One last feature, but it's the most important. Some code extracts are
given names, in angle brackets. If so, then the paragraph is the definition
of that extract. For example:

	|@<Dramatic finale@> =|
	|    printf("I'm ruined! Ruined, I say!\n");|
	|    exit(1);|

Notice that the equals sign is still there: it's just that the chunk of code
is given a name, written inside |@<| and |@>| "brackets". (This notation
goes all the way back to Knuth's original WEB.)

What does the tangler do with this? It doesn't place the code as the next
item in the program. Instead, it expands any mention of |@<Dramatic finale@>|
elsewhere in the section with this block of code. It can be expanded as
many times as necessary, but only within the same section. Another section
would be quite free to define its own |@<Dramatic finale@>|, but it would
not be able to see this one.

Why is this important? One of the points of literate programming is to
subdivide the program on conceptual lines, even within single functions.
For example:

	|@<Perform the sieve@> =|
	|    @<Start with all numbers from 2 upwards in the sieve@>;|
	|    for (int n=2; n*n <= RANGE; n++)|
	|        if (still_in_sieve[n])|
	|            @<Shake out multiples of n@>;|
	|    sieve_performed = TRUE;|

This is easier to understand than writing the function all in one go, and
more practicable than breaking it up into smaller functions.

Named paragraphs behave, in some ways, like macro definitions, and those
have a bad name nowadays - probably fairly. But Inweb makes them much
safer to use than traditional macros, because it tangles them into code
blocks, not just into runs of statements. A variable defined inside a
named paragraph has, as its scope, just that paragraph. And this:

	|        if (still_in_sieve[n])|
	|            @<Shake out multiples of n@>;|

works safely because |@<Shake out multiples of n@>| is, thanks to being a
code block, semantically a single statement.

Finally, note that if there are no commentary or definitions attached to
the paragraph then it's not necessary to type the initial |@|. That is,
this:

	|@|
	||
	|@<Prepare to exit@> =|

...is not necessary, and it's sufficient to type just:

	|@<Prepare to exit@> =|

@h Conditional compilation.
In some languages, especially C, it's very hard to write a program which will
run on multiple operating systems without some use of conditional compilation:
that is, putting some code or definitions inside |#ifdef| clauses or the like.

Inweb can't alter this sad fact of life, but it can make the process tidier.
If a paragraph has the tag |^"ifdef-SYMBOL"|, then any material in it will
be tangled in such a way that it takes effect only if |SYMBOL| is defined.
For example, in a C-language web with the paragraph:

	|@h Windows stuff. ^"ifdef-PLATFORM_WINDOWS"|
	||
	|@d THREADS_AVAILABLE 12|
	|=|
	|void start_threads(int n) {|
	|    ...|
	|}|

...the definition of |THREADS_AVAILABLE| and the function |start_threads|
would be made only inside a |#ifdef PLATFORM_WINDOWS| clause; the same would
happen for any typedefs or |#include|s made.

Similarly, tagging a paragraph |^"ifndef-SYMBOL"| causes it to have effect
only if |SYMBOL| is undefined. A paragraph can have any number of such
conditions applied to it, and if so then all of the conditions must be met.

Note that since tags can be applied to entire sections of a web, at the
Contents listing, it's straightforward to give, say, two versions of a
section file, one with effect on MacOS, one with effect on Windows.

@h Commentary.
The comment part of a paragraph is ignored by the tangler, and appears only
in weaves. For the most part, the text is simply copied over verbatim: but
Inweb quietly tries to improve the appearance of what it copies, and a
few special notations are allowed, to help with this.

@ A doubled hyphen becomes an em-rule; double-quotation marks automatically
smarten (in TeX format, at least).

@ Lines beginning with what look like bracketed list numbers or letters are
set as such, running on into little indented paragraphs. Thus

	|(a) Intellectual property has the shelf life of a banana. (Bill Gates)|
	|(b) He is the very pineapple of politeness! (Richard Brinsley Sheridan)|
	|(c) Harvard takes perfectly good plums as students, and turns them into|
	|prunes. (Frank Lloyd Wright)|

will be typeset thus:

(a) Intellectual property has the shelf life of a banana. (Bill Gates)
(b) He is the very pineapple of politeness! (Richard Brinsley Sheridan)
(c) Harvard takes perfectly good plums as students, and turns them into
prunes. (Frank Lloyd Wright)

A line which begins |(...)| will be treated as a continuation of indented
matter (following on from some break-off such as a source quotation).
A line which begins |(-X)| will be treated as if it were |(X)|, but
indented one tab stop further in, like so:

(c) Harvard blah, blah, blah. (Frank Lloyd Wright)
(-d) Pick a song and sing a yellow nectarine. (Scott Weiland)

@ Text placed between vertical strokes will be set in a fixed-space, code
style font, |thus|.

If a series of lines is indented with tab characters and consists entirely
of courier-type code extracts, it will be set as a running-on series of
code lines.

@ A line written thus:

	|>> The monkey carries the blue scarf.|

is typeset as an extract of text thus:

>> The monkey carries the blue scarf.

(This is a feature used for Inform 7 "code" samples, those being essentially
natural language text.)

@ Pictures must be in PNG, JPG or PDF format and can be included with lines
like:

	|[[Fig_0_1.pdf]]|
	|[[Whatever.jpg width 6cm]]|
	|[[Something.pdf height 2cm]]|

In the latter examples, we constrain the width or the height of the image
to be exactly that given: it is scaled accordingly. (They can't both be
constrained, so you can't change the aspect ratio.)

The weaver expects that any pictures needed will be stored in a subdirectory of
the web called |Figures|: for instance, the weaver would seek |Fig_2_3.pdf| at
pathname |Figures/Fig_2_3.pdf|.

@ Mathematical formulae can be typed in TeX notation between dollar signs,
as usual for TeX formulae. This can of course only really be rendered if
the weave is to TeX, but a few very approximate attempts are made by Inweb
so that the HTML version may also make sense. For example, |$x \leq y$| would
be rendered in HTML as |x <= y|.

