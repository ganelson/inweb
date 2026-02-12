# What Inweb Knows about Languages

## Holons are code blocks

Something to notice about the counting-sort example is that Inweb must have
known something about Python in order to tangle it correctly. Consider the code:

	def countingSort(unsorted):
		sorted = []
		if unsorted:
			{{initialise the incidence counts to zero}}

When Inweb replaces `{{initialise the incidence counts to zero}}`, it does
so in a way that keeps track of indentation:

	def countingSort(unsorted):
		sorted = []
		if unsorted:
			max_val = max(unsorted)
			counts = [0] * (max_val + 1)

rather than as, say,

	def countingSort(unsorted):
		sorted = []
		if unsorted:
			max_val = max(unsorted)
	counts = [0] * (max_val + 1)

...which would be disastrous, since indentation is very significant to Python.

An important difference between Inweb and most other systems for literate
programming is that Inweb tries to treat a holon _as if it were a language construct_,
and in particular, as if it were a code block.

For Python, that means respecting indentation. When tangling a web of a
C program, rather than a Python program, Inweb tangles a holon to a _braced_
code block. Thus the code:

	if (N == 1) {{Handle the main case}}

would tangle to:

	if (N == 1) {
		...
	}

where the lines making up `{{Handle the main case}}` appear as `...`. This
means that we can write, say,

	if (N == 1) {{Handle the main case}} else {{Handle the exceptions}}

with some feeling of safety: the `else` won't accidentally attach to some
`if` statement inside `{{Handle the main case}}`.

Named holons being code blocks also means that variables created inside a
named holon have that holon as their scope. For example, the `X` created in:

	{{Handle the main case}} =
	
	    int X = 8911;
	    ...

...is not visible from outside this holon. Accordingly, global definitions
cannot be made inside of a named holon: only at the top level, in a nameless
one. Experience shows that on a program of any size, this rule is invaluable
in making it possible to understand what is going on locally.

As this demonstrates, different languages have different conventions in
how they handle code blocks, and this is one reason why Inweb likes to know
what programming language it is working with.
