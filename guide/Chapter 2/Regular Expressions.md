# Regular Expressions

Since one or two features of Inweb make use of regular expressions, there
ought to be a section of this guide on the subject, and this is it. But it
can safely be skipped by any reader not yet needing to use them.

Regular expressions are beloved by many programmers for their extreme
conciseness, and are despaired of by others for the same reason. A regular
expression is simply a pattern which matches (or doesn't match) against
some text, possibly extracting some of it. For example, suppose we want
to recognise any of these:

	za3
	zaaa7
	zaaaaaaa2

The pattern here is a `z`, one or more `a`s, and then a digit. The regular
expression `/za+\d/` captures that idea:

1. The `/` and `/` at each end are not part of the regular expression, in the
   same way that the quotation marks around "brass" are not part of the
   word brass.
2. `z` means "match only a literal `z`".
   `a+` means "match one or more `a` characters". The `+` appended to the `a`
   is what accomplishes the "one or more" part.
3. `\d` means "any digit". The use of the backslash here means that the next
   letter has a special meaning; `d` alone would of course match only a `d`.
   And the special meaning of `\d` is "digit".

Suppose next that we want a regular expression to recognise a full stop
followed by an identifier: something like `.check_6845_registers`. 
This might be done with `/\.[A-Za-z_][A-Za-z_0-9]*/`:

1. `\.` means "match only a literal `.`". Perhaps perversely, while `\`
   sometimes applies a special meaning to the next character, this time it
   is taking away a special meaning. Ordinarily, `.` means "match any 
   character at all", and we certainly don't want that here.
2. `[A-Za-z_]` means "match any character between `A` and `Z` inclusive, or
   any character between `a` and `z` inclusive, or an underscore `_`.
3. `[A-Za-z_0-9]*` is similar, but also allowing the digits `0` to `9`, except
   that it has the magic `*` star at the end: this means "repeated 0 or more times".

So for example `.check_6845_registers` matches: `.` matches (1), then `c` matches (2),
then `heck_6845_registers` matches (3), with the `*` operator counting up to 19.

One more example: `/.*?([A-Z])\s*=\s*(\d+).*/`.

1. `.*?` means any character at all (`.`), repeated 0 or more times (`*`), but
   taking as few repeats as possible consistent with matching everything (`?`).
2. `([A-Z])` is in round brackets `(` and `)`, which means it is a subexpression.
   As noted above, regular expressions are used to extract chunks of text as
   well as make a match against them, and the brackets say what to extract. What
   does match here? Any single upper-case letter between `A` and `Z` inclusive.
3. `\s*` means 0 or more repetitions of `\s`, which means any space or tab.
4. `=` is easy for once: it matches a literal equals sign `=`.
5. `\s*`: see (3).
6. `(\d+)` is our second subexpression. Inside must be 1 more repetitions
   (this is what `+` means) of `\d`, which means the same thing as `[0-9]`:
   that is, a decimal digit.
7. `.*` means 0 or more repetitions of any character: which effectively means
   "any text at all", including the empty text.

So for example `C =715 + B` matches because: the empty text matches (1);
`C` matches (2); ` ` matches (3); `=` matches (4); the empty text matches (5);
`715` matches (6); and ` + B` matches (7). Thus we fully match the regexp
against the source text, and we extract two chunks of it: `C` and `715`.

Partly for reasons of speed, the regular expression engine used by Inweb here
is a limited one, compared to some of the behemoths available in many modern
programming languages. The complete list of features is as follows:

-	Subexpressions in round brackets: thus `(broad)(band)` matches the
	text `broadband`, putting `broad` into the first subexpression result
	and `band` into the second

-	Wildcards each match a single character:

	wildcard | meaning                          
	-------- | ---------------------------------
	`.`      | any character at all
	`\d`     | any digit, `0` to `9`
	`\q`     | the double-quotation mark character `"` only
	`\r`     | the newline character only
	`\s`     | any whitespace character, meaning, space, newline or tab
	`\S`     | any character _not_ matching `\s`
	`\t`     | the tab character only

-	Character ranges are like wildcards, but more general: `[aeiou]` means
	"match `a`, `e`, `i`, `o` or `u`".
	
	If a hyphen is used between two characters in the range, then all
	intervening characters are understood to be there. Thus `[e-h]` is
	equivalent to `[efgh]`. So, for example, `\d` (any digit) is equivalent to
	`[0123456789]` or, more concisely, `[0-9]`. If a hyphen occurs at the
	start or end of the range, it just means a hyphen. Thus `[a-z-]`
	matches _either_ a lower-case English letter _or_ `-`.

	If a range begins with `^` then this character is not included, and
	instead the match is against anything which is not one of those given.
	Thus `[^xyz]` matches any single character which is _not_ `x`, `y`, or `z`.
	A `^` character anywhere else in the range means itself in the normal
	way. So `[~^]` matches either `~` or `^`, whereas `[^~]` matches any
	character which isn't `~`.

-	Repetition markers can be placed after a character or subexpression:

	marker | meaning                           | example
	------ | --------------------------------- | -----------------------------------------------------
	`+`    | 1 or more                         | `(abc)+` matches `abc`, `abcabc`, `abcabcabc`, ... 
	`*`    | 0 or more                         | `xy*z`   matches `xz`, `xyz`, `xyyz`, `xyyyz`, ...
	`+?`   | 1 or more, but as few as possible | `(x+?)(.*)` matches `xxx` as `x` then `xx`
	`*?`   | 0 or more, but as few as possible | `(x*?)(.*)` matches `xxx` as the empty text then `xxx`
	`?`    | 0 or 1, and 0 if possible         | `(\d+)(e\d+)?` matches `32`, `1654` and `2e57`

-	The various magic characters above can be stripped of their magical powers
	with a backslash: e.g., `\*` matches `*`, a literal asterisk. `\` is itself
	a magic character, so `\\` is needed to mean a literal backslash.

Two popular regexp features _not_ supported by Inweb are:

-	Positional markers such as `^` (start of text marker) and `$` (end of text
	marker); in the various places that Inweb uses regexes, the context already
	establishes where matching starts or finishes. Similarly, `\a` and `\z`
	cannot be used.

-	Disjunction, that is, giving alternatives with `|`: for example, the
	expression `(fish)|(fowl)` to match either `fish` or `fowl`. This isn't
	allowed for reasons of efficiency: when Inweb does use regexes, it needs
	them to run quickly.
