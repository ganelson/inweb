# About Languages

## Languages as means of writing programs

Literate programming tools have to strike a balance about how much they want
to know about the programming language being used in a web. If they get too
close, the result can be a tool wedded to a single language, just as the
original `WEB` really cannot be used with anything other than a long-dead
dialect of Pascal. But if they take a principled stand that they know
nothing about the language, then they end up feature-poor, and produce
weaves which are a little bland.

Inweb aims to allow quite a wide variety of programming languages, but needs
the user to brief it on any language it does not already know. Running:

	$ inweb inspect -resources

lists all Inweb's built-in resources, and at time of writing only 24 of them
are languages: since quite a few are obscure (for reasons to do with the needs
of the Inform project, which Inweb spun out of), an Inweb user is quite likely
to need to add new languages sooner or later.

Fortunately, language declarations can be surprisingly short and easy, so this
is not a huge task.

## Languages as ways to syntax-colour text

The author of a large web may want to display snippets of console output,
pseudocode, pieces of programs in other languages, examples of usage, and so
on. These aren't part of the web's program as such, and all vanish away in
a tangle. But in the woven form of the web, they need to look right.

But how is Inweb to do that? Inweb uses a combination of syntax-colouring and
(in HTML output) CSS styling to make a chunk of C look different from a chunk
of console output, for example. But in order to do that, in needs to be told
what each chunk is. For example (in `MarkdownCode` notation):

	This is a basic tangling command:

	``` ConsoleText
    $ inweb tangle countsort.py.md
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'countsort.py'
	```

Here the displayed material, inside a Markdown "fence" provided by the backticks,
is declared as being `ConsoleText`.

This is in fact a "language", as far as Inweb is concerned. (It's one of the ones
supplied with Inweb.) Inweb doesn't distinguish between languages you might want
to program in, and schemes for colouring up text being displayed in a weave. As
a pretty extreme example:

	Language "VowelsExample" {
		colour !vowel like !function
		colouring
			=> !plain
			characters in "AEIOUaeiou" {
				=> !vowel
			}
		end
	}

This language is evidently just a colouring scheme (it takes plain text and
highlights the English vowels in it), not something to write programs in.

All of this is to say that an Inweb language is a combination of a few notes
about its syntax or quirks, together with instructions on how to syntax-colour
its code, but both parts are optional.
