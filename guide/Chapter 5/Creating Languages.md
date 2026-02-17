# Creating Languages

In this section, a new language definition will be created from scratch.
Rather than trying out a toy language, we'll aim to work with a real one,
and try to copy with some of the baggage that all real languages come with.
Graydon Hoare's language Rust, first created in 2006, aims to remove
memory-safety issues and undefined behaviours from languages like C or C++:
in this it succeeds admirably, and has gained traction not least from being
partially adopted by some contributions to the Linux kernel. Not everyone
likes its syntactic choices, but it's a language which does make choices.

Probably only Rust can parse Rust fully, but Inweb doesn't actually need to
know very much about it. Setting this up in the most basic way, we'll have a
directory with just two files in. One is a sample Rust program to toy with,
written as a web in `MarkdownCode` format, called `sample.rust.md`:

	# Traces of Corrosion
	
		fn main() {
			// Iterate with n from 1 to 10
			let mut n = 1;
			while n <= 10 {
				 println!("n = {n} of 10");
				 n += 1;
			}
		}

And the other file will be the new language definition, `rust.inweb`:

	Language "Rust" {
		recognise .rust
	}

Kicking the tyres:

	$ inweb inspect sample.rust.md -using rust.inweb
	web "Traces of Corrosion" (Rust program in MarkdownCode notation): 1 paragraph : 11 lines

	$ inweb tangle sample.rust.md
	tangling web "Traces of Corrosion" (MarkdownCode notation) to file 'sample.rust'
	
	$ cat sample.rust
	fn main() {
		// Iterate over all integers from 1 to 10
		let mut n = 1;
		while n <= 10 {
			 println!("n = {n} of 10");
			 n += 1;
		}
	}

As can be seen, a minimal language definition can be minimal indeed. Even
the `recognise` line is optional — a "language" defined just to syntax-colour
text wouldn't need one, since there will never be entire webs written in it.
But it's certainly needed for Rust, because otherwise Inweb would not know
that `sample.rust.md` is written in the Rust language.

A language definition consists, in fact, of any number of the following,
in any order:

- `recognise`, to say what filename extension(s) are typically used by code
written in this language;

- `properties`, to set some syntactic properties of the language;

- `keywords`, to say which identifiers in this language are significant, in
the way that "reserved words" like `while` or `int` are significant in C;

- `colour`, to create a new conceptual colour;

- `colouring` (which can also be written `coloring`), to say how to syntax-colour
programs in this language.

In addition, like most other Inweb definitions, a language can optionally also
contain `Conventions` settings; if present, this must come at the end.

So it's time to give the Rust definition some substance. If we try weaving
with the almost empty definition so far:

	$ inweb weave sample.rust.md -creating
	weaving web "Traces of Corrosion" (MarkdownCode notation) as HTML
		generated: sample.html
		10 files copied to: sample-assets

...then we will see a web page where the Rust code is really quite strangely
syntax-coloured. The literal numbers, `1` and `10`, are coloured differently
from the words like `main`, and differently again from the punctuation marks
like `;`. But it looks wrong to do that for the comment line (the one which
begins with `//`), and for the number in the string (`"n = {n} of 10"`).
The problem is that Inweb doesn't know any better, because it doesn't know
how Rust writes either comments or strings. So:

	Language "Rust" {
		recognise .rust

		properties
			Details: A language for memory-safe coding.
			Line Comment: //
			String Literal: "
			String Literal Escape: \
			Character Literal: '
			Character Literal Escape: \
		end
	}

The `properties` block of a definition makes miscellaneous settings which are
all to do with the meaning of code written in our language. All settings fit
on a single line (each), all settings are optional, and they can be given in
any order. They all take the form `Name: Value`, where any white space before
or after the `Value` is removed. The odd one out here is `Details`: it's just
a short crib which might remind someone looking at what languages are available,
and is used by `inweb inspect -resources`.

Note the setting of `String Literal Escape`. We don't want code like this:

	println!("This is \"not the end of the string\". Only this is.")

to fool Inweb. Setting `String Literal Escape` to `\` tells Inweb that `\`
before a `"` does not end the string; automatically, then, `\\` is treated
as a single literal `\`, so that `"this \\"` is correctly handled as the
text "this \".

So Inweb can now recognise strings and line comments: anything on a line after
`//` will be a comment. (And it automatically knows that a comment can't occur
inside a string, nor vice versa.) That affects weaving, because it immediately
makes syntax-colouring much better: comments and strings are now easily
distinguished by eye. But it does also affect tangling. Consider this code:
	
	This astonishing algorithm actually succeeds in _doubling_ its number.
	
		fn main() {
			let mut n = 1;
			// It is too soon to {{Report progress}}.
			n += 1;
			println!("Time to {{Report progress}}");
			{{Report progress}}
			println!("n = {n}.");
		}
	
	{{Report progress}} =
	
		println!("I have made some progress.");

Note that `{{Report progress}}` occurs twice in places where the author of this
code clearly doesn't want it to expand out: once in a comment, and another time
in a string literal. But because Inweb can now recognise Rust comments and
strings, those two apparent holon expansions are ignored.

Now in fact Rust, like C, also supports (potentially) multiline comments,
placing them between `/*` and `*/` markers, and this can be accommodated with
two further properties in the definition:

			Multiline Comment Open: /*
			Multiline Comment Close: */

Suppose we rewrite out sample program like so:

	fn main() {
		// Iterate over all integers from -4 to 8
		let mut n = -4;
		while n <= 0o10 {
			 println!("n = {n}");
			 n += 1;
		}
	}

Weaving this, we find that `-4` and `0o10` are not syntax-coloured as numbers.
We can put this right like so:

			Hexadecimal Literal Prefix: 0x
			Octal Literal Prefix: 0o
			Binary Literal Prefix: 0b
			Negative Literal Prefix: -

And now valid Rust constants such as `0b11011`, `-126`, `0o47` and `0xDEADBEEF`
will all be syntax-coloured as numbers. Rust also allows floating-point
literals like `3.1415`, `1e4` and `-2.5e-3`, so we may as well throw in:

			Decimal Point Infix: .
			Exponent Infix: e

That's comments, strings, characters and numbers. Turning to identifiers, it's
certainly not ideal that the words `fn`, `let`, and `n` all have the same colour
in the woven output. `n` is a variable name, whereas `fn` and `let` are reserved
words in Rust, with a special structural meaning.

Inweb deals with this with a `keywords` block in the language definition. (Inweb
jargon is to use the term _keyword_ for any identifier with a special meaning.)
Rust in fact has a little hierarchy of words which have special meanings
(strict, reserved, and weak), but since it is basically madness to use any of
them for anything other than those special meanings, we can safely treat all
of them as "reserved words":

		keywords
			_ abstract as async await become box break const continue crate do dyn
			else enum extern false final fn for gen if impl in let loop macro macro_rules
			match mod move mut override priv pub raw ref return safe self Self static struct
			super trait true try type typeof union unsafe unsized use virtual where while
			yield
		end

Note that `keywords` begins a block of words which continues on subsequent lines
until we reach a line reading just `end`. (If `end` is needed as a reserved word,
place it on a line with other reserved words, or else put in in quotes, `"end"`.)

Two of these are actually not like the others: `true` and `false` in Rust are
really numbers rather than magic words, because those are the two Boolean values.
So a niftier approach in our definition is:

		keywords
			_ abstract as async await become box break const continue crate do dyn
			else enum extern final fn for gen if impl in let loop macro macro_rules
			match mod move mut override priv pub raw ref return safe self Self static struct
			super trait try type typeof union unsafe unsized use virtual where while
			yield
		end

		keywords of !constant
			false true
		end

There's a little bit to unpack here. Inweb has a set of conceptual colours for
different semantic ideas in the code it is colouring: these colours all have
names, like `!constant`. (All these names begin `!`.) Keywords can be assigned
in any colour, but the default is `!reserved`.

If the sample code is woven again with these keywords declared... the result,
anticlimactically, is that nothing visible has happened. But that is because
we also need to give a colouring program for Rust as part of our language
definition. This will do the trick:

		colouring
			runs of unquoted {
				runs of !identifier {
					keyword of !reserved => !reserved
					keyword of !constant => !constant
				}
			}
		end

The rules for colouring will be gone into later, but a rough translation of
this would be: if you see an identifier (a run of `!identifier` characters),
and it's a keyword marked as `!reserved`, give it the colour `!reserved`;
and similarly for keywords marked `!constant`. (All other identifiers...
will remain coloured `!identifier`.) And with that in place, Inweb will
colour magic words like `fn` and `mut` in a special way, and will make
`true` and `false` the same colour as `12` or `0x4e11`.

One last tweak, before we leave the syntactic world of Rust: Rust has a
concept of "macro", different from that of "function", and written with
exclamation marks. In our sample code, `main` is a function name, but
`println!` is a macro: the `!` signals that. It would be nice to colour
macros differently. And this would do that:

		colouring
			runs of unquoted {
				runs of !identifier {
					keyword of !reserved => !reserved
					keyword of !constant => !constant
					suffix "!" => !element on both
				}
			}
		end

That new line, `suffix "!" => !element on both`, says that if our identifier
is immediately followed by `!`, then colour both the identifier and the `!`
with the colour `!element`.

But it does seem unfortunate to be calling this `!element` when that's not
what we're thinking of. So Inweb provides a cooler way:

		colour !macro like !element		
		colouring
			runs of unquoted {
				runs of !identifier {
					keyword of !reserved => !reserved
					keyword of !constant => !constant
					suffix "!" => !macro on both
				}
			}
		end

The declaration `colour !macro like !element` creates a new colour, called
`!macro`. The part saying `like !element` means "give this the same appearance
as `!element` would have when making a weave": it's needed because otherwise
Inweb wouldn't know what macros should look like. In the line `colour !NEW like !OLD`,
the colour `!OLD` must already exist, and the colour `!NEW` must not, so we
can't get into paradoxes like

	colour !fish like !fowl
	colour !fowl like !fish

We can have any reasonable number of bonus colours like this ("reasonable" here
means at least 36 per language), and they are all different as far as the
colouring program goes. For example:

	colour !good like !element
	colour !bad like !element

results in two different colours, `!good` and `!bad`, even if they will ultimately
look the same in the woven output.

Here is another trick with suffixes. Rust allows literal numbers to be suffixed
`u32` to indicate that they are unsigned 32-bit numbers:

		colour !macro like !element		
		colouring
			runs of unquoted {
				runs of !identifier {
					keyword of !reserved => !reserved
					keyword of !constant => !constant
					suffix "!" => !macro on both
				}
				runs of !constant {
					suffix "u32" => !constant on both
				}
			}
		end

And with that change, `0x40e3u32` will be syntax-coloured as a constant. Of
course, then we need to make similar changes for the other literal number types
on Rust, of which there are annoyingly many.

How can we test this definition? One convenience is the command `inweb test-language`:

	$ inweb tangle sample.rust.md -using rust.inweb
	tangling web "Traces of Corrosion" (Rust program in MarkdownCode notation) to file 'sample.rust'
	
	$ inweb test-language -called rust -on sample.rust -using rust.inweb
	Test of colouring for language Rust:
	fn main() {
		// Iterate over all integers from 1 to 10
		let mut n = 1;
		while n <= 10 {
			 println!("n = {n} of 10");
			 n += 1;
		}
		println!("1e4 is {}, -2.5e-3 is {}", 1e4, -2.5e-3);
		println!("true is {}, false is {}", true, false);
		println!("4.5_f64 is {}, 0x3ef5u128 is {}", 4.5_f64, 0x3ef5u128);
	}
	
	rrpiiiipppp
	pppp!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	pppprrrprrrpipppnp
	pppprrrrrpippppnnpp
	pppppppppmmmmmmmmpssssssssssssssspp
	pppppppppippppnp
	ppppp
	ppppmmmmmmmmpssssssssssssssssssssssssssppnnnppnnnnnnnpp
	ppppmmmmmmmmpsssssssssssssssssssssssssppnnnnppnnnnnpp
	ppppmmmmmmmmpsssssssssssssssssssssssssssssssssppnnniiiippnnnnnniiiipp
	p

So the command `inweb test-language -called X -on Y` syntax-colours the file `Y`
according to the definition of the language `X`, and prints out a sort of
plain-text crib of the result. The characters in the gibberish at the end
represent colours: `r` is the `!reserved` colour, `i` the `!identifier`
colour, and so on. (`p` is `!plain`.) Note that Inweb has chosen the letter
`m` for our custom colour `macro`, since `m` didn't already mean anything else.

With practice, it's easy enough to read output like this, and it can be
mechanically checked by testing tools like Intest.

By now, `Rust.inweb` contains all five of the possible ingredients of a language
definition: `recognise`, `properties`, `keywords`, `colour` and `colouring`. But as
mentioned above, we can also apply `Conventions`, and it's a good idea
to apply this one:

	Conventions {
		named holons are tangled between <NEWLINE>{<NEWLINE> and }<NEWLINE>
	}

Which makes holons into Rust code blocks. (See //Holons as Code Blocks// for more.)

And so we end up with a workable Rust definition:

	Language "Rust" {
		recognise .rust
	
		properties
			Details: A language for memory-safe coding.
			Line Comment:               	//
			Multiline Comment Open:     	/*
			Multiline Comment Close:    	*/
			String Literal:             	"
			String Literal Escape:      	\
			Character Literal:          	'
			Character Literal Escape:   	\
			Hexadecimal Literal Prefix: 	0x
			Octal Literal Prefix:       	0o
			Binary Literal Prefix:      	0b
			Negative Literal Prefix:    	-
			Decimal Point Infix:        	.
			Exponent Infix:            		e
		end
		
		keywords
			_ abstract as async await become box break const continue crate do dyn
			else enum extern final fn for gen if impl in let loop macro macro_rules
			match mod move mut override priv pub raw ref return safe self Self static struct
			super trait try type typeof union unsafe unsized use virtual where while
			yield
		end
	
		keywords of !constant
			false true
		end
	
		colour !macro like !element		
		colouring
			runs of unquoted {
				runs of !identifier {
					keyword of !reserved => !reserved
					keyword of !constant => !constant
					suffix "!" => !macro on both
				}
				runs of !constant {
					suffix "i8" => !constant on both
					suffix "i16" => !constant on both
					suffix "i32" => !constant on both
					suffix "i64" => !constant on both
					suffix "i128" => !constant on both
					suffix "u8" => !constant on both
					suffix "u16" => !constant on both
					suffix "u32" => !constant on both
					suffix "u64" => !constant on both
					suffix "u128" => !constant on both
					suffix "_f16" => !constant on both
					suffix "_f32" => !constant on both
					suffix "_f64" => !constant on both
					suffix "_f128" => !constant on both
				}
			}
		end

		Conventions {
			named holons are tangled between <NEWLINE>{<NEWLINE> and }<NEWLINE>
		}
	}

Does that fully capture Rust's syntax? Of course not: like all big, serious
languages, Rust has a dismayingly convoluted syntax. But Inweb aims to know only
what it can directly make use of. It's not trying to compile or understand Rust
code. It just wants to avoid obvious tangling errors, and make the woven output
visually helpful: nothing more.

Even the simple aspects captured by our language definition above are, inevitably,
imperfect. For example:

- Rust allows underscores to be used when spacing numbers out, e.g., `1_000_000`
for one million.

- The peculiar `'static` is also a reserved word; we didn't make it a keyword,
because Inweb (by default) does not consider `'` part of an identifier.

- Inweb does not recognise nested multiline comments, following the C convention
that the first `*/` closes a `/*` no matter how many other `/*`s have appeared
since: Rust, as it happens, has the opposite convention.

But when writing a language definition, the question to ask is just: is this
good enough? These demerits aren't so bad. Failing to recognise `1_000_000`
doesn't mean it can't be used in code: it just means the weave won't colour it in,
which is not the end of the world.

And in a way that's the moral here: Inweb language definitions are a pragmatic
business. We should keep fiddling with them until they're good enough, and
then stop worrying.
