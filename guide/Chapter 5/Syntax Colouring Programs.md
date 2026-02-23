# Syntax Colouring Programs

This section is about how to write the `colouring` (or if you prefer `coloring`)
part of a language definition. In //Creating Languages// we saw that a `colouring`
block improved the syntax-colouring for code in the Rust language, but as an
earlier example showed, these blocks can also be used for "languages" which are
really just ways to mark up textual displays or diagrams:

	Language "VowelsExample" {
		colour !vowel like !function
		colouring
			=> !plain
			characters in "AEIOUaeiou" {
				=> !vowel
			}
		end
	}

Thus:

``` VowelsExample
A noir, E blanc, I rouge, U vert, O bleu : voyelles,
Je dirai quelque jour vos naissances latentes :
A, noir corset velu des mouches éclatantes
Qui bombinent autour des puanteurs cruelles,
```

If you're reading this in a woven form which can display coloured text, then
each example of a `colouring` program will be followed by a demonstration,
like that one. Here for example is some Rust code, using the definition
drawn up in //Creating Languages//:

``` Rust
fn main() {
	// Iterate over all integers from 1 to 10
	let mut n = 1;
	while n <= 10 {
		 println!("n = {n} of 10"); /* note use of a macro, not a function */
		 n += 1;
	}
	println!("1e4 is {}, -2.5e-3 is {}", 1e4, -2.5e-3);
	println!("true is {}, false is {}", true, false);
	println!("4.5_f64 is {}, 0x3ef5u128 is {}", 4.5_f64, 0x3ef5u128);
}
```

## Colours

Inweb supports the following "colours". How they correspond to actual colours
or styles visible to the eventual reader is not something that a language
definition can control: that's done with, say, CSS files in weave patterns
(see //Creating Patterns//). So rather than "green" or "blue", Inweb colours
are named semantically, from the following palette of possibilities:

Inweb colour  | Letter | CSS class name      | Suggested use
------------- | ------ | ------------------- | --------------------------------------
`!character`  | `c`    | `character-syntax`  | character literals, e.g., `'c'`
`!comment`    | `!`    | `comment-syntax`    | comments, e.g. `/* thus */`
`!constant`   | `n`    | `constant-syntax`   | literal numbers, e.g., `-130`
`!definition` | `d`    | `definition-syntax` | definitions, e.g., `#define THIS`
`!element`    | `e`    | `element-syntax`    | structure elements, e.g., `.ID_number`
`!extract`    | `x`    | `extract-syntax`    | backticked Markdown code in commentary
`!function`   | `f`    | `function-syntax`   | function names, e.g., `main`
`!type`       | `t`    | `type-syntax`       | type names, e.g., `u32`
`!identifier` | `i`    | `identifier-syntax` | variable names
`!plain`      | `p`    | `plain-syntax`      | punctuation and white space, e.g., `&`
`!reserved`   | `r`    | `reserved-syntax`   | reserved words, e.g., `while`
`!string`     | `s`    | `string-syntax`     | string literals, e.g., `"blue dot"`

The examples in the suggested use column are all from the C language; but
colouring programs give a language definition a lot of freedom in assigning
these colours to different globs of characters.

## If there is no colouring program...

Note that a simple text display, like this one:

	My memory takes me back across the interval of fifty years to a little
	ill-lit room with a sash window open to a starry sky, and instantly
	there returns to me the characteristic smell of that room, the
	penetrating odor of an ill-trimmed lamp, burning cheap paraffin.

will be coloured `!plain` throughout. This effect could be duplicated by:

	Language "Colourless" {
		colouring
			=> !plain
		end
	}

Code for a completely bare language like:

	Language "Bland" {
	}

will get a little fancier treatment, but only a little. The following is
rendered as `Bland`:

``` Bland
let individualScores = [75, 43, 103, 87, 12]
var teamScore = 0
for score in individualScores {
    teamScore += score
}
// sums the individual scores
```

and uses only a few colours: `!constant` on the decimal numbers, `!identifier` on
the things looking like words, and `!plain` on everything else. The result is
better than nothing, but not very much better.

## How Inweb colours code

This works in three stages:

1. Inweb uses the language's comment syntax to work out what part of the code is
commentary, and what part is "live". Only the live part goes forward into stage
two. Live material is coloured `!plain`, and comment material is coloured `!comment`.

2. Inweb tries to read literal constants. Character literals are painted in
`!character`, string literals in `!string`, identifiers in `!identifier`, and
numeric literals as `!constant`. The live material can now have up to five
colours: these four and `!plain`.

3. Inweb runs the `colouring` program for the language (if one is provided):
this has the opportunity to apply some polish. Note that this runs only on
the live material; it cannot affect the commented-out matter identified by stage 1.
When the program finishes, every colour can appear in the live material (including,
if the program really insists, `!comment`).

## Colouring programs

These always begin with a line reading just `colouring`, and end with a line
reading just `end`. The empty colouring program is legal:

    colouring
    end

This makes stage 3 ineffective, and thus is equivalent to not to having a
colouring program at all.

The material in between is called a _block_. Each block runs on a
given stretch of contiguous text, called the _snippet_. For the outermost
block, that's a line of source code. Blocks normally contain one or more
_rules_:

    colouring
        marble => !function
    end

Rules take the form of "if X, then Y", and the `=>` divides the X from the Y.
This one says that if the snippet consists of the word "marble", then colour
it `!function`. Of course this is not very useful, since it would only catch
lines containing only that one word. So we really want to narrow in on smaller
snippets. This, for example, applies its rule to each individual character
in turn:

    colouring
        characters {
            K => !identifier
        }
    end

In the above examples, `K` and `marble` appeared without quotation marks,
but they were only allowed to do that because (a) they were single words,
(b) those words had no other meaning, and (c) they didn't contain any
awkward characters. For any more complicated texts, always use quotation
marks. For example, in

	"=>" => !reserved

the `=>` in quotes is just text, whereas the one outside quotes is being
used to divide a rule.

If you need a literal double quote inside the double-quotes, use `\"`; and
use `\\` for a literal backslash. For example:

    "\\\"" => !reserved

actually matches the text `\"`.

### The six splits

`characters` is an example of a _split_, which splits up the original snippet
of text — say, the line `let K = 2` — into smaller, non-overlapping snippets
— in this case, nine of them: `l`, `e`, `t`, ` `, `K`, ` `, `=`, ` `, and `2`.

Every split is followed by a block of rules, which is applied to each of the
pieces in turn. Inweb works sideways-first: thus, if the block contains rules
R1, R2, ..., then R1 is applied to each piece first, then R2 to each piece,
and so on.

There are several different ways to split, all of them written in the
plural, to emphasize that they work on what are usually multiple things.
Rules, on the other hand, are written in the singular. Splits are not allowed
to be followed by `=>`: they always begin a block.

1.	`characters` splits the snippet into each of its characters.

2.	`characters in T` splits the snippet into each of its characters which
	lie inside the text `T`.

3.	`instances of X` narrows in on each usage of the text `X` inside the snippet.

4.	`runs of !C`, where `!C` describes a colour, splits the snippet
	into non-overlapping contiguous pieces which currently have that colour.
	As a special form, `runs of unquoted` means "runs of characters not painted
	either with `!string` or `!character`".

5.	`matches of /E/`, where `/E/` is a regular expression (see below),
	splits the snippet up into non-overlapping pieces which match it. (If
	there is no match, nothing happens.)

6. 	`brackets in /E/` matches the snippet against the regular expression `E`,
	and then runs the rules on each bracketed subexpression in turn. (If there
	is no match, or there are no bracketed terms in `E`, nothing happens.)

Demonstrations are probably clearer than elaborate descriptions. `characters`
was shown above, and `characters in T` has also been seen before in this chapter:

	colouring
		=> !plain
		characters in "AEIOUaeiou" {
			=> !function
		}
	end

Note that it splits the line up into characters, but ignores all those characters
not found in the text, i.e., all the non-vowels. That doesn't destroy them, because
the next rule could always split the line differently:

	colouring
		=> !plain
		characters in "AEIOUaeiou" {
			=> !function
		}
		characters in "Yy" {
			=> !element
		}
	end

`instances of X` splits into potentially larger snippets. For example,

	colouring
		=> !plain
		instances of "son" {
			=> !function
		}
	end

might produce:

``` LineageExample
Jacob first appears in Genesis chapter 25, the son of Isaac and Rebecca, the
grandson of Abraham, Sarah and Bethuel, the nephew of Ishmael.
```

The first rule makes everything `!plain`, wiping the slate clean from anything
done by Stage 2 (and in particular preventing the `25` from being coloured
as `!constant`). The second rule says that all instances of `son`, including
in the word `grandson`, should be coloured `!function`.

Note that `instances of` never runs in an overlapping way: the snippet `===` would be
considered as having only one instance of `==` (the first two characters),
while `====` would have two.

As an example of `runs of !C`, where `!C` describes a colour, consider:

	colouring
		=> !plain
		characters in "0123456789" {
			=> !function
		}
		runs of !plain {
			"-" => !function
		}
	end

which has this effect:

``` RunningExample
Napoleon Bonaparte (1769-1821) took 167 scientists to Egypt in 1798,
who published their so-called Memoirs over the period 1798-1801.
```

Here the hyphens in number ranges have been coloured, but not the hyphen
in "so-called". That's because the runs in this text (at the time the `runs of`
rule is reached) are:

- `Napoleon Bonaparte (` of `!plain`
- `1769` of `!function`
- `-` of `!plain`
- `1821` of `!function`
- `) took ` of `!plain`
- `167` of `!function`
- ` scientists to Egypt in ` of `!plain`
- `1798` of `!function`
- `,` of `!plain`
- `who published their so-called Memoirs over the period ` of `!plain`
- `1798` of `!function`
- `-` of `!plain`
- `1801` of `!function`
- `.` of `!plain`

Thus the two hyphens occurring in the date ranges occupy entire runs, but
the one in "so-called" does not.

A more computer-science sort of example would be:

	colouring
		runs of !identifier {
			printf => !function
			sscanf => !function
		}
	end

which might produce:

``` StdioExample
if (x == 1) printf("Hello!");
```

The split finds three runs of identifiers: `if`, then `x`, then `printf`. Only
the third is coloured as `!function`, because only the third matches one of the
rules inside the `runs of` block.

The split `matches of /E/` brings in regular expressions for the first time.
For example:

	colouring
		matches of /\.[A-Za-z_][A-Za-z_0-9]*/ {
			=> !function
		}
	end

says that a literal full stop, followed by a letter or underscore, and then
any number (including 0) of letters, digits or underscores, should be painted
as `!function`. As it happens, that's customary notation for labels in some
forms of assembly language:

``` AssemblageExample
	JSR .initialise
	LDR A, #.data
	RTS
.initialise
	TAX
```

Regular expressions are beloved by many programmers for their extreme
conciseness, and are despaired of by others for the same reason. Unpacking
`/\.[A-Za-z_][A-Za-z_0-9]*/` as a human reader, one must first remove the
`/` at start and end `/`. These are delimiters, that is, they say when the
expression starts and finishes, but they are not part of it, in the same way
that the quotation marks around "brass" there are not part of the word brass.
That leaves:

1. `\.` means "match only a literal `.`" — the backslash `\` is needed because
   `.` has a special meaning for regular expressions (it matches any character,
   and we certainly don't want that here); then
2. `[A-Za-z_]` means "match any character between `A` and `Z` inclusive, or
   any character between `a` and `z` inclusive, or an underscore `_`; then
3. `[A-Za-z_0-9]*` is similar, but also allowing the digits `0` to `9`, except
   that it has the magic `*` star at the end: this means "repeated 0 or more times".

So for example `.check_6845_registers` matches: `.` matches (1), then `c` matches (2),
then `heck_6845_registers` matches (3), with the `*` operator counting up to 19.

Lastly, `brackets in /E/`:

	colouring
		=> !plain
		brackets in /.*?([A-Z])\s*=\s*(\d+).*/ {
			=> !function
		}
	end

producing:

``` EquationsExample
	A = 2716
	B=3
	C =715 + B
	D < 14
```

The regexp here, `/.*?([A-Z])\s*=\s*(\d+).*/`, involves further hieroglyphics:

1. `.*?` means any character at all (`.`), repeated 0 or more times (`*`), but
   taking as few repeats as possible consistent with matching everything (`?`).
2. `([A-Z])` is in round brackets `(` and `)`, which means it is a subexpression.
   Anything matched in it is one of the `brackets` we referred to above. What
   does match? Any single upper-case letter between `A` and `Z` inclusive.
3. `\s*` means 0 or more repetitions of `\s`, which means any space or tab.
4. `=` is easy for once: it matches a literal equals sign `=`.
5. `\s*`: see (3).
6. `(\d+)` is our second subexpression. Inside must be 1 more repetitions
   (this is what `+` means: it is like `*` but does not allow 0) of `\d`,
   which means the same thing as `[0-9]`: that is, a decimal digit.
7. `.*` means 0 or more repetitions of any character: which effectively means
   "any text at all", including the empty text.

So for example `C =715 + B` matches because: the empty text matches (1);
`C` matches (2); ` ` matches (3); `=` matches (4); the empty text matches (5);
`715` matches (6); and ` + B` matches (7). Thus we fully match the regexp
against the source text. 

Partly for reasons of speed, the regular expression engine used by Inweb here
is a limited one, compared to some of the behemoths available in many modern
programming languages. It's probably wise to stick to the features used in
these two examples. Note that Inweb does not have `^` (start of text marker)
and `$` (end of text marker), because Inweb always requires the match to be
from the start of the snippet to the end of the snippet. The text `red beachball`
does _not_ match the regular expression `/beach/`. Only `beach` matches `/beach/`.

### The seven ways rules can apply

Rules are the lines with a `=>` in. As noted, they take the form "if X, then
Y". The following are the possibilities for X, the condition.

(1) The easiest thing is to give nothing at all, and then the rule always
applies. As we've seen, this nihilistic program gets rid of colouring entirely:

    colouring
        => !plain
    end

(2) If X is a piece of literal text, the rule applies when the snippet is
exactly that text. For example,

    printf => !function

(3) X can require the whole snippet to be of a particular colour, by writing
`coloured !C` (or `colored !C`). For example:

    colouring
        characters {
            coloured !character => !plain
        }
    end

removes the syntax colouring on character literals.

(4) X can require the snippet to be one of the language's known keywords, as
declared earlier in the ILD by a `keyword` command. The syntax here is
`keyword of !C`, where `!C` is a colour. For example:

    keyword of !element => !element

says: if the snippet is a keyword declared as being of colour `!element`,
then actually colour it that way. (This is much faster than making many
comparison rules in a row, one for each keyword in the language; Inweb has
put all of the registered keywords into a hash table for rapid lookup.)

(5) X can look at a little context before or after the snippet, testing it
with one of the following: `prefix P`, `spaced prefix P`,
`optionally spaced prefix P`. For example, consider this:

	runs of !identifier {
        prefix % => !element
    }

applied to the text `%total += %price`. The two runs of `!identifier` here
are `total` and `price`, but the condition `prefix %` is able to look at
the character occurring in the original line _before_ the snippet, to see
if it is `%` or not. In both cases it is, so the colour is applied... but
only to the words `total` and `price`, not to the percentage signs as well.
Changing the rule to:

        prefix % => !element on both

would colour the percentage signs (i.e., the prefixes) as well.

Another variation of this is to do with whether white space must appear
between the prefix and the snippet. For example,

        spaced prefix £ => !element

_requires_ white space, and means that `£ discount` matches, but that
`£discount` does not. This is not the same thing as

        prefix "£ " => !element

because that would not match `£      discount`. The white space implied by
`spaced` can be any run of 1 or more spaces and tabs.

        optionally spaced prefix £ => !element

makes that "0 or more", and matches `£ discount` or `£discount` equally.

And of course all of these work analogously for `suffix`. Note that these
cannot see the line before or after the current line: only material also
appearing on the same original line.

(6) X can test the snippet against a regular expression, with `matching /E/`.
For example:

    runs of !identifier {
        matching /.*x.*/ => !element
    }

...turns any identifier containing a lower-case `x` into `!element` colour.
Note that `matching /x/` would not have worked, because our regular expression
is required to match the entire snippet, not just somewhere inside.

    characters in "0123456789" {
    	=> !element
    }
    runs of !element {
    	=> !plain
        matching /\d\d\d\d/ => !element
    }

...colours all four-digit numbers `!element`, and all other decimal digits `!plain`.

(7) Whenever a split takes place, Inweb keeps count of how many pieces there are,
and different rules can apply to differently numbered pieces. The notation
is `number N`, where `N` is the number, counting from 1. For example,

	colour !emphasised like !function
	colouring
		=> !plain
		matches of /\S+/ {
			number 3 => !emphasised
		}
	end

applies colour to every third word (where by word we mean "run of non-whitespace
characters", since that's what `\S` means in regexp language). For example:

``` Sonnet
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
```

We can also cycle through a set of possibilities with `number N of M`,
where this time the count runs 1, 2, ..., `M`, 1, 2, ..., `M`, 1, ... and
so on. Thus `number 1 of 3` would work on the 1st, 4th, 7th, ... times;
`number 2 of 3` on the 2nd, 5th, 8th, ...; `number 3 of 3` on the 3rd, 6th,
9th, and so on. This, for example, paints the output from the painting
algorithm in Inweb:

	colouring
		number 1 of 2 => !plain
		number 2 of 2 => {
			characters {
				"!" => !comment
				"c" => !character
				"d" => !definition
				"e" => !element
				"f" => !function
				"i" => !identifier
				"n" => !constant
				"p" => !plain
				"r" => !reserved
				"s" => !string
				"x" => !extract
			}
		}
	end

The result is that lines 1, 3, 5, ... are run through `=> !plain`, while
lines 2, 4, 6, ... are run through a more complicated colouring.

``` PainterOutput
	int x = 55; /* a magic number */
	rrrpipppnnpp!!!!!!!!!!!!!!!!!!!!
	Imaginary::function(x, beta);
	fffffffffffffffffffpippiiiipp
```

Any condition can be reversed by preceding it with `not`. For example,

    not coloured !string => !plain

### The three ways rules can take effect

Now let's look at the conclusion Y of a rule. Here the possibilities are
simpler:

(1) If Y is the name of a colour, the snippet is painted in that colour.
For prefix or suffix rules (see above), it can also be applied to the
prefix or suffix as well: use the notation `=> C on both` or `=> C on suffix`
or `=> C on prefix`.

(2) If Y is an open brace `{`, then it introduces a block of rules which are
applied to the snippet only if this rule has matched. For example,

    keyword !element => {
        optionally spaced prefix . => !element
        optionally spaced prefix -> => !element
    }

means that if the original condition `keyword !element` applies, then two
further rules are applied.

(3) If Y is the word `debug`, then the current snippet and its colouring
are printed out on the command line. Thus:

    colouring
        matches of /\d\S+/ {
            => debug
        }
    end

The rule `=> debug` is unconditional, and will print whenever it's reached.
