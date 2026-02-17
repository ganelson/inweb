# Summary of Languages

A language declaration must be enclosed thus:

	Language "NAME" {
		...
	}

where the body `...` consists of blank lines, or of any of the following,
given in any order:

*	`recognise .EXTENSION`. A source file with this filename extension will be
	assumed to be written in this language, in the absence of instructions to the
	contrary.

*	`properties`, followed by lines specifying values for given keys, followed
	by a line reading `end`. See below.

*	`colouring`, followed by a colouring program, followed by a line reading `end`.
	Gives instructions for syntax-colouring: specified in //Syntax Colouring Programs//.

*	`keywords`, followed by lines listing keywords, followed by a line reading `end`.
	The keywords can be bare, e.g., `for`, or can be quoted, e.g., `"for"`. (To
	make `end` a keyword, quote it.)

*	`keywords of !COLOUR` is the same, but where the keywords are assigned the
	given colour rather than the default `!reserved` colour. For more on colours,
	see //Syntax Colouring Programs//.

*	`colour !NEWCOLOUR like !EXISTINGCOLOUR` creates a new colour, and tells Inweb
	that it should be rendered in the same appearance as an existing one.

## Conventions used in language declarations

In addition, a language declaration (like any Inweb resource declaration) can
finish up by including a `Conventions` block. Only the following conventions
are really appropriate for a language, though:

	named holons are tangled between BEFORE and AFTER
	standard library #includes are tangled early in the program
	typedefs are tangled early in the program
	typedef structs are tangled early and reordered logically
	function predeclarations are tangled automatically

The last four are relevant only for C and variants of C: see //Special C Features//.
The first, though, can be useful in making the holons for a language behave
like code blocks: see //Holons as Code Blocks// for why we might want this. For
example, Inweb's definition of C contains:

	named holons are tangled between <NEWLINE>{<NEWLINE> and }<NEWLINE>

which means that when a named holon is expanded in tangling, it's encased in
C's open and close block syntax, `{` ... `}`. The newlines are not entirely
cosmetic — we want to ensure that any subsequent `#line` directive will
appear at the start of a line. By default:

	named holons are tangled between <NEWLINE> and <NEWLINE>

Many languages which are not strictly speaking versions of C also brace their
code blocks: so, for example, the definition of Rust in //Creating Languages//
made the same convention.

## The properties block

Everything else having now been fully specified, it remains to give an
exhaustive list of the settings which can be made in the `properties` block.

Properties can be textual (as the great majority are), boolean (in which case
they must be `true` or `false`), or regexp, that is, they hold a regular
expression. Here are examples of each being set:

	properties
		Character Literal:		'
		C-Like: 				false
		Function Declaration:	/def ([A-Za-z_][A-Za-z0-9_]*).*/
	end

Textual properties can either be quoted or not. If quoted, they should be in
double-quotes: `"Thus"`. Within those, `\"` means a double quotation mark,
`\n` means a newline, and `\\` means a backslash. If unquoted, they are
taken just as they are, with no special characters (and thus cannot contain
newlines).

A textual value is read as quoted if it contains at least two characters, and
the first and last are quotation marks: thus `"` is unquoted, and means a
single-character text where the character in question is a double-quotation
mark; but `""` is quoted and means the empty text.

By default, the following properties are all empty or `false` if not set.

-- -- --

`Details`: textual. A one-line note explaining the purpose of this "language",
used only in the output of `inweb inspect -show-resources`. Style note: for
consistency, start with a capital letter, but finish without a full stop. Example:

	Details: The C++ programming language

`Line Comment`: textual. The characters introducing a comment which continues
to the end of the line, but which can appear in any (unquoted, uncommented-out)
position. Affects tangling as well as weaving since Inweb will not expand holon
names when they are commented out. Example:

	Line Comment: //

`Whole Line Comment`: textual. Like `Line Comment`, but allowed only at the
start of a line, where "start" means that these are the first non-whitespace
characters on that line. Example:

	Line Comment: #

`Multiline Comment Open`: textual. The characters introducing a comment which
continues to the next use of `Multiline Comment Close` (so, these should either
both be defined, or neither). This form of comment can begin and end in any
(unquoted, uncommented-out) position and can, but need not, spread across
multiple lines. Affects tangling as well as weaving since Inweb will not
expand holon names when they are commented out. Example:

	Multiline Comment Open: {-
	Multiline Comment Close: -}

`Multiline Comment Open`: textual. See `Multiline Comment Open`.

`String Literal`: textual. The characters opening and also closing a string
literal. Affects tangling as well as weaving since Inweb will not
expand holon names when they appear only in string literals. Example:

	String Literal: "

`String Literal Escape`: textual. If used inside a string literal, means that
any use of `String Literal` immediately following should not be counted as
its end. Example:

	String Literal Escape: \

`Character Literal`: textual. Like `String Literal`, but for character literals.
Example:

	Character Literal: '

`Character Literal Escape`: textual. Like `String Literal Escape`, but for character literals.
Example:

	Character Literal Escape: \

`Binary Literal Prefix`: textual. Introduces a binary number literal, which
then must continue with digits which are each 0 or 1. Affects only syntax-colouring.
Example:

	Binary Literal Prefix: 0b

`Octal Literal Prefix`: textual. Introduces a binary number literal, which
then must continue with digits which are each 0, 1, 2, 3, 4, 5, 6, 7.
Affects only syntax-colouring. Example:

	Binary Literal Prefix: 0o

`Hexadecimal Literal Prefix`: textual. Introduces a binary number literal, which
then must continue with digits which are each 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, a or A,
b or B, c or C, d or D, e or E, f or F. Affects only syntax-colouring. Example:

	Hexadecimal Literal Prefix: 0x

`Negative Literal Prefix`: textual. Introduces a decimal number literal which
is negative. Affects only syntax-colouring. Example (and it's hard to imagine
any other value being set here):

	Negative Literal Prefix: -

`Decimal Point Infix`: textual. Used inside a decimal number literal, acts as
a decimal point. Affects only syntax-colouring. Example (and it's hard to imagine
any other value being set here):

	Decimal Point Infix: .

`Exponent Infix`: textual. Used inside a decimal number literal, acts as
an exponent marker. Affects only syntax-colouring. Example:

	Exponent Infix: e

`Shebang`: textual. Affects only tangling. Place this text at the very top
of any tangled program, followed by a newline. The name goes back to the
old Unix scripting tools, whose input conventionally opened with a comment saying
what program (usually a compiler or interpreter) should run them. Example:

	Shebang: "#!/usr/bin/perl\n\n"

`Line Marker`: textual. Affects only tangling. Placed every time the tangler
draws source material from different files or line numbers than the compiler
might be expecting. `%d` should be placed where the line number is to go, and
`%f` where the filename should be. Example:

	Line Marker: "#line %d \"%f\"\n"

`Indent Named Holon Expansion`: boolean. If `true`, holon expansion should
respect the current indentation level. This needs to be set for Pythonesque
languages: see //Holons as Code Blocks//. Example:

	Indent Named Holon Expansion: true

`Start Definition`: textual. If defining a symbol through an explicit
notation in the web source (for example using `@d` in `InwebClassic`), Inweb
tangles this at the opening of a definition. Example (from C):

	Start Definition: "#define %S "

`Prolong Definition`: textual. If the value of a definition continues across a
second or still further lines, then this text is tangled in between those lines.
Example (from C):

	Prolong Definition: "\\\n    "

`End Definition`: textual. Tangled at the end of the value from a definition
begun with `Start Definition`. Example (from C):

	End Definition: "\n"

`Start Ifdef`: textual. When tangling code which should be compiled only if
a given symbol is defined, Inweb expands this string, in which `%S` is expanded
as the symbol. No other `%` escapes should be used. Example (from Inform 6):

	Start Ifdef: "#ifdef %S;\n"

`Start Ifndef`: textual. Similarly for conditional compilation if a symbol is
not defined. Example (from Inform 6):

	Start Ifdef: "#ifndef %S;\n"

`End Ifdef`: textual. Inweb tangles this at the end of a passage of code
prefaced with `Start Ifdef`: so both should be defined, or neither. Once
again `%S` expands into the symbol name (though this may not be needed, or
might only be used in a comment). Example (from Inform 6):

	End Ifdef: "#endif; ! %S\n"

`End Ifndef`: textual. Similarly to `End Ifdef`, but for passages which began
with `Start Ifndef`.

`C-Like`: boolean. If `true`, this language gains certain Inweb features
reserved for variants of C. See //Special C Features//. Example:

	C-Like: true

`Supports Namespaces`: boolean. This is intended only for C-like languages,
and provides some semblance of a namespace feature for function names
(though not for other identifiers). See //Special C Features//. Example:

	Supports Namespaces: true

`Function Declaration`: regexp. If set, Inweb attempts to parse
(non-comment) lines against this regular expression: if there's a match,
then the first bracketed subexpression is assumed to be the name of a new
function declared on that line, and is made a keyword of colour `!function`.
Multiple expressions can be made alternatives by writing multiple
`Function Declaration` lines. See //Recognising Functions and Types//. Example:

	Function Declaration: /fn (\S+?)\s*\(.*/

`Type Declaration`: regexp. Similar to `Function Declaration`, but for the
colour `!type`. Again, see //Recognising Functions and Types//. Example:

	Type Declaration: /typedef struct (\S+).*/
	Type Declaration: /typedef .* (\S+);\s*/
