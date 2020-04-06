Supporting Programming Languages.

How to work with a programming language not yet supported by Inweb.

@h Introduction.
To a very large extent, Inweb works the same way regardless of what language
its webs are using, and that is deliberate. On the other hand, when a web
is woven, it will look much nicer with syntax-colouring, and that clearly
can't be done without at least a surface understanding of what programs in
the language mean.

@
As we've seen, the Contents section of a web has to specify its language.
For example,

	|Language: Perl|

declares that the program expressed by the web is a Perl script. The language
name must be one which Inweb knows, or, more exactly, one for which it can
find a "language definition file". These are stored in the |Languages|
subdirectory of the |inweb| distribution, and if a language is called |L|
then its file is |L.ildf|. You can see the languages currently available
to Inweb by using |-show-languages|. At present, a newly installed Inweb
replies like so:

= (undisplayed text from Figures/languages.txt)

@ So what if you want to write a literate program in a language not on that
list? One option is to give the language as |None|. (Note that this is
different from simply not declaring a language -- if your web doesn't say
what language it is, Inweb assumes C.) |None| is fine for tangling, though
it has the minor annoyance that it tangles to a file with the filename
extension |.txt|, not knowing any better. But you can cure that with
|-tangle-to F| for any filename |F| of your choice. With weaving, though,
|None| makes for drab-looking weaves, because there's very little syntax
colouring.

An even more extreme option is |Plain Text|, which has no syntax colouring
at all. (But this could still be useful if what you want is to produce an
annotated explanation of some complicated configuration file in plain text.)

@ In fact, though, it's easy to make new language definitions, and if you're
spending any serious effort on a web of a program in an unsupported language
then it's probably worth making one. Contributions of these to the Inweb
open source project are welcome, and then this effort might also benefit others.
This section of the manual is about how to do it.

Once you have written a definition, use |-read-language L| at the command
line, where |L| is the file defining it. If you have many custom languages,
|-read-languages D| reads all of the definitions in a directory |D|. Or, if
the language in question is really quite specific to a single web, you can
make a |Dialects| subdirectory of the web and put it in there. (A dialect is,
after all, a local language.)

For testing purposes, running with |-test-language F -test-language-on G|
reads in a file |G| of code, and syntax-colours it according to the rules
for the language defined in the file |F|, then prints a plain-text diagram
of the results. (This can then be tested with Intest test cases, as indeed
Inweb does itself.)

@h Structure of language definitions.
Each language is defined by a single ILDF file. ("Inweb Language Definition
Format".) In this section, we'll call it the ILD.

The ILD is a plain text file, which is read in line by line. Leading and
trailing whitespace on each line is ignored; blank lines are ignored; and
so are comments, which are lines beginning with a |#| character.

The ILD contains three sorts of thing:
(a) Properties, set by lines in the form |Name: "C++"|.
(b) Keywords, set by lines in the form |keyword int|.
(c) A colouring program, introduced by |colouring {| and continuing until the
last block of it is closed with a |}|.

Everything in an ILD is optional, so a minimal ILD is in principle empty. In
practice, though, every ILD should open like so:

= (sample ILDF code)
Name: "C"
Details: "The C programming language"
Extension: ".c"

@h Properties.
Inevitably, there's a miscellaneous shopping list of these, but let's start
with the semi-compulsory ones.

|Name|. This is the one used by webs in their |Language: "X"| lines, and should
match the ILD's own filename: wherever it is stored, the ILD for langauge |X|
should be filenamed |X.ildf|.

|Details| These are used only by |-show-languages|.

|Extension|. The default file extension used when a web in this format is
tangled. Thus, a web for a C program called |something| will normally tangle
to a file called |something.c|.

@ Most programming languages contain comments. In some, like Perl, a comment
begins with a triggering notation (in Perl's case, |#|) occurring outside of
quoted material; and it continues to the end of its line. We'll call that a
"line comment". There are also languages where comments must be the only
non-whitespace items on their lines: in that case, we'll call them "whole
line comments". In others, like Inform 7, a comment begins with one notation
|[| and ends with another |]|, not necessarily on the same line. We'll call
those "multiline comments".

|Line Comment| is the notation for line comments, and |Whole Line Comment| is
the notation for whole line comments.

|Multiline Comment Open| and |Multiline Comment Close|, which should exist
as a pair or not at all, is the notation for multiline comments.

For example, C defines:

= (sample ILDF code)
    Multiline Comment Open: "/*"
    Multiline Comment Close: "*/"
    Line Comment: "//"

@ As noted, comments occur only outside of string or character literals. We
can give notations for these as follows:

|String Literal| must be a single character, and marks both start and end.

|String Literal Escape| is the escape character within a string literal to
express an instance of the |String Literal| character without ending it.

|Character Literal| and |Character Literal Escape| are the same thing for
character literals.

Here, C defines:

= (sample ILDF code)
    String Literal: "\""
    String Literal Escape: "\\"
    Character Literal: "'"
    Character Literal Escape: "\\"

@ Next, numeric literals, like |0xFE45| in C, or |$$10011110| in Inform 6.
It's assumed that every language allows non-negative decimal numbers.

|Binary Literal Prefix|, |Octal Literal Prefix|, and |Hexadecimal Literal Prefix|
are notations for non-decimal numbers, if they exist.

|Negative Literal Prefix| allows negative decimals: this is usually |-| if set.

Here, C has:

= (sample ILDF code)
    Hexadecimal Literal Prefix: "0x"
    Binary Literal Prefix: "0b"
    Negative Literal Prefix: "-"

@ |Shebang| is used only in tangling, and is a probably short text added at
the very beginning of a tangled program. This is useful for scripting languages
in Unix, where the opening line must be a "shebang" indicating their language.
For example, Perl defines:
= (sample ILDF code)
    Shebang: "#!/usr/bin/perl\n\n"
=
Most languages do not have a shebang.

@ In order for C compilers to report C syntax errors on the correct line,
despite rearranging by automatic tools, C conventionally recognises the
preprocessor directive |#line| to tell it that a contiguous extract follows
from the given file. Quite a few languages support notations like this,
which most users never use.

When tangling, Inweb is just such a rearranging tool, and it inserts line
markers automatically for languages which support them: |Line Marker| specifies
that this language does, and gives the notation. For example, C provides:
= (sample ILDF code)
    Line Marker: "#line %d \"%f\"\n"
=
Here |%d| expands to the line number, and |%f| the filename, of origin.

@ When a named paragraph is used in code, and the tangler is "expanding" it
to its contents, it can optionally place some material before and after the
matter added. This material is in |Before Named Paragraph Expansion| and
|After Named Paragraph Expansion|, which are by default empty.

For C and all similar languages, we recommend this:
= (sample ILDF code)
    Before Named Paragraph Expansion: "\n{\n"
    After Named Paragraph Expansion: "}\n"
=
The effect of this is to ensure that code such as:
= (not code)
    if (x == y) @<Do something dramatic@>;
=
tangles to something like this:
= (not code)
    if (x == y)
    {
    ...
    }
=
so that any variables defined inside "Do something dramatic" have limited
scope, and so that multi-line macros are treated as a single statement by |if|,
|while| and so on.

(The new-line before the opening brace is not for aesthetic purposes; we never
care much about the aesthetics of tangled C code, which is not for human eyes.
It's in case of any problems arising with line comments.)

@ When the author of a web makes definitions with |@d| or |@e|, Inweb will
need to tangle those into valid constant definitions in the language concerned.
It can only do so if the language provides a notation for that.

|Start Definition| begins; |Prolong Definition|, if given, shows how to
continue a multiline definition (if they are allowed); and |End Definition|,
if given, places any ending notation. For example, Inform 6 defines:
= (sample ILDF code)
    Start Definition: "Constant %S =\s"
    End Definition: ";\n"
=
where |%S| expands to the name of the term to be defined. Thus, we might tangle
out to:
= (not code)
    Constant TAXICAB = 1729;\n
=
Inweb ignores all definitions unless one of these three properties is given.

@ Inweb needs a notation for conditional compilation in order to handle some
of its advanced features for tangling tagged material: the Inform project
makes use of this to handle code dependent on the operating system in use.
If the language supports it, the notation is in |Start Ifdef| and |End Ifdef|,
and in |Start Ifndef| and |End Ifndef|. For example, Inform 6 has:
= (sample ILDF code)
    Start Ifdef: "#ifdef %S;\n"
    End Ifdef: "#endif; ! %S\n"
    Start Ifndef: "#ifndef %S;\n"
    End Ifndef: "#endif; ! %S\n"
=
which is a subtly different notation from the C one. Again, |%S| expands to
the name of the term we are conditionally compiling on.

@ |Supports Namespaces| must be either |true| or |false|, and is by default
|false|. If set, then the language allows identifier names to include
dividers with the notation |::|; section headings can declare that all of
their code belongs to a single namespace; and any functions detected in that
code must have a name using that namespace.

This is a rudimentary way to provide namespaces to languages not otherwise
having them: InC uses it to extend C.

@ |Suppress Disclaimer| is again |true| or |false|, and by default |false|.
The disclaimer is a comment placed into a tangle declaring that the file
has been auto-generated by Inweb and shouldn't be edited. (The comment
only appears in comment notation has been declared for the language: so
e.g., the Plain Text ILD doesn't need to be told to |Suppress Disclaimer|
since it cannot tangle comments anyway.)

@h Secret Features.
It is not quite true that everything a language can do is defined by the ILD.
Additional features are provided to C-like languages to detect functions
and |typedef|s. At present, these are hard-wired into Inweb, and it will take
further thought to work out how to express them in LDFs.

The property |C-Like|, by default |false|, enables these features.

(In addition, a language whose name is |InC| gets still more features, but
those are not so much a failing of ILDF as because Inweb is itself a sort of
compiler for |InC| -- see elsewhere in this manual.)

@h Keywords.
Syntax colouring is greatly helped by knowing that certain identifier names
are special: for example, |void| is special in C. These are often called
"reserved words", in that they can't be used as variable or function names
in the language in question. For C, then, we include the line:
= (sample ILDF code)
    keyword void
=
Keywords can be declared in a number of categories, which are identified by
colour name: the default is |!reserved|, the colour for reserved words. But
for example:
= (sample ILDF code)
    keyword isdigit of !function
=
makes a keyword of colour |!function|.

@h Syntax colouring program.
That leads nicely into how syntax colouring is done.

ILDs have no control over what colours or typefaces are used: that's all
controllable, but is done by changing the weave pattern. So we can't colour
a word "green": instead we colour it semantically, from the following
palette of possibilities:
= (sample ILDF code)
!character  !comment     !constant  !definition  !element  !extract
!function   !identifier  !plain     !reserved    !string
=
Each character has its own colour. At the start of the process, every
character is |!plain|.

@ At the first stage, Inweb uses the language's comment syntax to work out
what part of the code is commentary, and what part is "live". Only the live
part goes forward into stage two. All comment material is coloured |!comment|.

At the second stage, Inweb uses the syntax for literals. Character literals
are painted in |!character|, string literals in |!string|, identifiers in
|!identifier|, and numeric literals as |!constant|.

At the third stage, Inweb runs the colouring program for the language (if
one is provided): it has the opportunity to apply some polish. Note that this
runs only on the live material; it cannot affect the commented-out matter.

When a colouring program begins running, then, everything is coloured in
one of the following: |!character|, |!string|, |!identifier|, |!constant|,
and |!plain|.

@ A colouring program begins with |colouring {| and ends with |}|. The
empty program is legal but does nothing:
= (sample ILDF code)
    colouring {
    }
=
The material between the braces is called a "block". Each block runs on a
given stretch of contiguous text, called the "snippet". For the outermost
block, that's a line of source code. Blocks normally contain one or more
"rules":
= (sample ILDF code)
    colouring {
        marble => !function
    }
=
Rules take the form of "if X, then Y", and the |=>| divides the X from the Y.
This one says that if the snippet consists of the word "marble", then colour
it |!function|. Of course this is not very useful, since it would only catch
lines containing only that one word. So we really want to narrow in on smaller
snippets. This, for example, applies its rule to each individual character
in turn:
= (sample ILDF code)
    colouring {
        characters {
            K => !identifier
        }
    }
=

@ In the above examples, |K| and |marble| appeared without quotation marks,
but they were only allowed to do that because (a) they were single words,
(b) those words had no other meaning, and (c) they didn't contain any
awkward characters. For any more complicated texts, always use quotation
marks. For example, in
= (sample ILDF code)
	"=>" => !reserved
=
the |=>| in quotes is just text, whereas the one outside quotes is being
used to divide a rule.

If you need a literal double quote inside the double-quotes, use |\"|; and
use |\\| for a literal backslash. For example:
= (sample ILDF code)
    "\\\"" => !reserved
=
actually matches the text |\"|.

@h The six splits.
|characters| is an example of a "split", which splits up the original snippet
of text -- say, the line |let K = 2| -- into smaller, non-overlapping snippets
-- in this case, nine of them: |l|, |e|, |t|, | |, |K|, | |, |=|, | |, and |2|.
Every split is followed by a block of rules, which is applied to each of the
pieces in turn. Inweb works sideways-first: thus, if the block contains rules
R1, R2, ..., then R1 is applied to each piece first, then R2 to each piece,
and so on.

There are several different ways to split, all of them written in the
plural, to emphasize that they work on what are usually multiple things.
Rules, on the other hand, are written in the singular. Splits are not allowed
to be followed by |=>|: they always begin a block.

1. |characters| splits the snippet into each of its characters.

2. |characters in T| splits the snippet into each of its characters which
lie inside the text |T|. For example, here is a not very useful ILD for
plain text in which all vowels are in red:
= (text from Dialects/VowelsExample.ildf as ILDF)
Given the text:
= (not code)
A noir, E blanc, I rouge, U vert, O bleu : voyelles,
Je dirai quelque jour vos naissances latentes :
A, noir corset velu des mouches éclatantes
Qui bombinent autour des puanteurs cruelles,
=
this produces:
= (sample VowelsExample code)
A noir, E blanc, I rouge, U vert, O bleu : voyelles,
Je dirai quelque jour vos naissances latentes :
A, noir corset velu des mouches éclatantes
Qui bombinent autour des puanteurs cruelles,
=

3. The split |instances of X| narrows in on each usage of the text |X| inside
the snippet. For example,
= (text from Dialects/LineageExample.ildf as ILDF)
acts on the text:
= (not code)
Jacob first appears in the Book of Genesis, the son of Isaac and Rebecca, the
grandson of Abraham, Sarah and Bethuel, the nephew of Ishmael.
=
to produce:
= (sample LineageExample code)
Jacob first appears in the Book of Genesis, the son of Isaac and Rebecca, the
grandson of Abraham, Sarah and Bethuel, the nephew of Ishmael.
=
Note that it never runs in an overlapping way: the snippet |===| would be
considered as having only one instance of |==| (the first two characters),
while |====| would have two.

4. The split |runs of C|, where |C| describes a colour, splits the snippet
into non-overlapping contiguous pieces which have that colour. For example:
= (text from Dialects/RunningExample.ildf as ILDF)
acts on:
= (not code)
Napoleon Bonaparte (1769-1821) took 167 scientists to Egypt in 1798,
who published their so-called Memoirs over the period 1798-1801.
=
to produce:
= (sample RunningExample code)
Napoleon Bonaparte (1769-1821) took 167 scientists to Egypt in 1798,
who published their so-called Memoirs over the period 1798-1801.
=
Here the hyphens in number ranges have been coloured, but not the hyphen
in "so-called".

A more computer-science sort of example would be:
= (text from Dialects/StdioExample.ildf as ILDF)
which acts on:
= (not code)
if (x == 1) printf("Hello!");
=
to produce:
= (sample StdioExample code)
if (x == 1) printf("Hello!");
=
The split divides the line up into three runs, and the inner block runs three
times: on |if|, then |x|, then |printf|. Only the third time has any effect.

As a special form, |runs of unquoted| means "runs of characters not painted
either with |!string| or |!character|". This is special because |unquoted| is
not a colour.

5. The split |matches of /E/|, where |/E/| is a regular expression (see below),
splits the snippet up into non-overlapping pieces which match it: possibly
none at all, of course, in which case the block of rules is never used.
This is easier to demonstrate than explain:
= (text from Dialects/AssemblageExample.ildf as ILDF)
which acts on:
= (not code)
		JSR .initialise
		LDR A, #.data
		RTS
	.initialise
		TAX
=
to produce:
= (sample AssemblageExample code)
		JSR .initialise
		LDR A, #.data
		RTS
	.initialise
		TAX
=

6. Lastly, the split |brackets in /E/| matches the snippet against the
regular expression |E|, and then runs the rules on each bracketed
subexpression in turn. (If there is no match, or there are no bracketed
terms in |E|, nothing happens.)
= (text from Dialects/EquationsExample.ildf as ILDF)
acts on:
= (not code)
	A = 2716
	B=3
	C =715 + B
	D < 14
=
to produce:
= (sample EquationsExample code)
	A = 2716
	B=3
	C =715 + B
	D < 14
=
What happens here is that the expression has two bracketed terms, one for
the letter, one for the number; the rule is run first on the letter, then
on the number, and both are turned to |!function|.

@h The seven ways rules can apply.
Rules are the lines with a |=>| in. As noted, they take the form "if X, then
Y". The following are the possibilities for X, the condition.

1. The easiest thing is to give nothing at all, and then the rule always
applies. For example, this somewhat nihilistic program gets rid of colouring
entirely:
= (sample ILDF code)
    colouring {
        => !plain
    }
=

2. If X is a piece of literal text, the rule applies when the snippet is
exactly that text. For example,
= (sample ILDF code)
    printf => !function
=

3. X can require the whole snippet to be of a particular colour, by writing
|coloured C|. For example:
= (sample ILDF code)
    colouring {
        characters {
            coloured !character => !plain
        }
    }
=
removes the syntax colouring on character literals.

4. X can require the snippet to be one of the language's known keywords, as
declared earlier in the ILD by a |keyword| command. The syntax here is
|keyword of C|, where |C| is a colour. For example:
= (sample ILDF code)
    keyword of !element => !element
=
says: if the snippet is a keyword declared as being of colour |!element|,
then actually colour it that way. (This is much faster than making many
comparison rules in a row, one for each keyword in the language; Inweb has
put all of the registered keywords into a hash table for rapid lookup.)

5. X can look at a little context before or after the snippet, testing it
with one of the following: |prefix P|, |spaced prefix P|,
|optionally spaced prefix P|. These qualifiers have to do with whether white
space must appear after |P| and before the snippet. For example,
= (sample ILDF code)
    runs of !identifier {
        prefix optionally spaced -> => !element
    }
=
means that any identifier occurring after a |->| token will be coloured
as |!element|. Similarly for |suffix|.

6. X can test the snippet against a regular expression, with |matching /E/|.
For example:
= (sample ILDF code)
    runs of !identifier {
        matching /.*x.*/ => !element
    }
=
...turns any identifier containing a lower-case |x| into |!element| colour.
Note that |matching /x/| would not have worked, because our regular expression
is required to match the entire snippet, not just somewhere inside.
= (sample ILDF code)
    characters in "0123456789" {
        matching /\d\d\d\d/ => !element
    }
=
...colours all four-digit numbers, but no others.

7. Whenever a split takes place, Inweb keeps count of how many pieces there are,
and different rules can apply to differently numbered pieces. The notation
is |number N|, where |N| is the number, counting from 1. For example,
= (text from Dialects/ThirdExample.ildf as ILDF)
acts on:
= (not code)
With how sad steps, O Moon, thou climb'st the skies! 
How silently, and with how wan a face! 
What, may it be that even in heav'nly place 
That busy archer his sharp arrows tries! 
Sure, if that long-with love-acquainted eyes 
Can judge of love, thou feel'st a lover's case, 
I read it in thy looks; thy languish'd grace 
To me, that feel the like, thy state descries. 
Then, ev'n of fellowship, O Moon, tell me, 
Is constant love deem'd there but want of wit? 
Are beauties there as proud as here they be? 
Do they above love to be lov'd, and yet 
Those lovers scorn whom that love doth possess? 
Do they call virtue there ungratefulness?
=
to produce:
= (sample ThirdExample code)
With how sad steps, O Moon, thou climb'st the skies! 
How silently, and with how wan a face! 
What, may it be that even in heav'nly place 
That busy archer his sharp arrows tries! 
Sure, if that long-with love-acquainted eyes 
Can judge of love, thou feel'st a lover's case, 
I read it in thy looks; thy languish'd grace 
To me, that feel the like, thy state descries. 
Then, ev'n of fellowship, O Moon, tell me, 
Is constant love deem'd there but want of wit? 
Are beauties there as proud as here they be? 
Do they above love to be lov'd, and yet 
Those lovers scorn whom that love doth possess? 
Do they call virtue there ungratefulness?
=
We can also cycle through a set of possibilities with |number N of M|,
where this time the count runs 1, 2, ..., |M|, 1, 2, ..., |M|, 1, ... and
so on. Thus |number 1 of 3| would work on the 1st, 4th, 7th, ... times;
|number 2 of 3| on the 2nd, 5th, 8th, ...; |number 3 of 3| on the 3rd, 6th,
9th, and so on. This, for example, paints the output from the painting
algorithm in Inweb:
= (text from Dialects/PainterOutput.ildf as ILDF)
since alternate lines are plain, for the original text, and then coloured,
to highlight the colours given to the characters in the original. Thus:
= (not code)
	int x = 55; /* a magic number */
	rrrpipppnnpp!!!!!!!!!!!!!!!!!!!!
	Imaginary::function(x, beta);
	fffffffffffffffffffpippiiiipp
=
becomes
= (sample PainterOutput code)
	int x = 55; /* a magic number */
	rrrpipppnnpp!!!!!!!!!!!!!!!!!!!!
	Imaginary::function(x, beta);
	fffffffffffffffffffpippiiiipp
=

@ Any condition can be reversed by preceding it with |not|. For example,
= (sample ILDF code)
    not coloured !string => !plain
=

@h The three ways rules can take effect.
Now let's look at the conclusion Y of a rule. Here the possibilities are
simpler:

1. If Y is the name of a colour, the snippet is painted in that colour.

2. If Y is an open brace |{|, then it introduces a block of rules which are
applied to the snippet only if this rule has matched. For example,
= (sample ILDF code)
    keyword !element => {
        optionally spaced prefix . => !element
        optionally spaced prefix -> => !element
    }
=
means that if the original condition |keyword !element| applies, then two
further rules are applied.

By default, the colour is applied to the snippet. For prefix or suffix
rules (see above), it can also be applied to the prefix or suffix: use
the notation |=> C on both| or |=> C on suffix| or |=> C on prefix|.

3. If Y is the word |debug|, then the current snippet and its colouring
are printed out on the command line. Thus:
= (sample ILDF code)
    colouring {
        matches of /\d\S+/ {
            => debug
        }
    }
=
The rule |=> debug| is unconditional, and will print whenever it's reached.

@h The worm, Ouroboros.
Inweb Language Definition Format is a kind of language in itself, and in
fact Inweb is supplied with an ILD for ILDF itself, which Inweb used to
syntax-colour the examples above. Here it is, as syntax-coloured by itself:
= (text from Languages/ILDF.ildf as ILDF)
