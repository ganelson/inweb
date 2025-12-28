# A Little Literate Programming

## What are holons?

Literate programming is the art of breaking up a complicated program into 
fragments, explaining how they work, and placing them all in context.

The explanatory parts of a web are called _commentary_ and the fragments of code
are called _holons_, a word borrowed from the Hungarian thinker Arthur Koestler
by the Belgian computer scientist Pierre-Arnoul de Marneffe. A holon is "a piece
of the whole", and for us it is a piece of the program being expressed by the web.

As we've seen, when Inweb's Markdown notation is used, commentary and holons
tend to alternate:

	This is commentary text.
	
	And so is this.
	
		thisIsAHolon = true
		print("A holon is part of the whole.")

	Now back to commentary.

In short, the holons, or code fragments, are the runs of lines indented by one tab
stop. The web above has just one holon, and it tangles to:

	thisIsAHolon = true
	print("A holon is part of the whole.")

However, tangling can do more. The real strength of literate programming lies
in the ability to divide the code into holons which have names. Consider this:

	The program divides neatly:
	
		print("Begin.")
		{{Phase one}}
		{{Phase two}}
		print("End.")
	
	{{Phase one}} =
	
		print("This is phase one.")
	
	{{Phase two}} =
	
		print("This is phase two.")

Now there are three holons. The first is nameless, while the second and third
have the names `Phase one` and `Phase two` respectively. Now our web tangles to:

	print("Begin.")
	print("This is phase one.")
	print("This is phase two.")
	print("End.")

## A literate program

Literate programming can only make a case for itself when used to explain
something which does actually call for explanation. So the following is a more
whole-heartedly _literate_ rewriting of the same counting-sort program used
as an example before. This time we divide its critical code into three
phases, each of which becomes a named holon.

	# Counting Sort by Harold H. Seward
	
	_An implementation of the 1954 sort algorithm._
	
	This algorithm was found in 1954 by [Harold H. Seward](https://en.wikipedia.org/wiki/Harold_H._Seward),
	who also devised radix sort. They differ from most sorting techniques because they do
	not make comparisons between items in the unsorted array. Indeed, there are no
	comparisons in the following function, only iteration.
	
	This function takes an array of non-negative integers, sorts it, and returns
	the result. The test `if unsorted` means "if the unsorted array is not empty",
	and is needed because Python would otherwise handle this case badly: of course,
	if `unsorted` does equal `[]`, then so should `sorted`, and so the right answer
	is returned.
	
		def countingSort(unsorted):
			sorted = []
			if unsorted:
				{{initialise the incidence counts to zero}}
				{{tally how many times each value occurs in the unsorted array}}
				{{construct the sorted array with the right number of each value}}
			return sorted
	
	For example, suppose the array is initially `[4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]`.
	Then the maximum value is 6. Python arrays index from 0, so we need an incidence
	counts array of size 7, and we create it as `[0, 0, 0, 0, 0, 0, 0]`.
	
	{{initialise the incidence counts to zero}} =
	
		max_val = max(unsorted)
		counts = [0] * (max_val + 1)
	
	In the unsorted array we will observe no 0s, one 1, three 2s, and so on. The
	following produces the counts `[0, 1, 3, 3, 1, 1, 2]`.
	
	{{tally how many times each value occurs in the unsorted array}} =
	
		for value in unsorted:
			counts[value] += 1
	
	Unusually for a sorting algorithm, an entirely new sorted array is created,
	using only the incidence counts as a sort of program. We fill `sorted`
	with no `0`s, one `1`, three `2`s, and so on, producing `[1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]`.[1]
	
	[1] The unsorted array is no longer needed, in fact, and so we could easily make this
	algorithm "sort in place" by simply rewriting `unsorted`, rather than making
	a new array.
	
	{{construct the sorted array with the right number of each value}} =
	
		for value, count in enumerate(counts):
			sorted.extend([value] * count)	
	
	And this code tests the function:
	
		A = [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
		print("Unsorted:", A)
		print("Sorted:", countingSort(A))
	
	So how did we do? What makes count sort interesting is that it is not doomed
	to run at $O(n\log n)$ or worse speed, where $n$ is the size of the data set:
	counting sort runs at $O(n+k)$, where $k$ is the size of the largest value in
	the data (called `max_val` above). With most data, $k$ is either enormous or
	at least unpredictable, so that speed and memory usage both spike. But for just
	a few applications, where $k$ is known to be within tight bounds, count sort
	is still used today and is exceptionally fast.

If literate programming works at all as an idea, then the above ought to be
easier to understand (and to spot the flaws in) than the original. The woven
form of this, converted for example into a web page, is still easier to read.

Our program is now divided into five holons. Two of these are nameless
holons, the first of which (beginning `def countingSort`) incorporates,
or we will say _uses_, the content of the three named holons. The final
nameless holon (beginning `A =`) does some testing.

## The rules about holon names and usage

There are of course some rules about all this, which Inweb enforces.
Firstly, about the names:

* Holon names are text, and can include all manner of exotic characters or
  emoji, and in whatever casing the author would like.
  So, for example, `{{Measure️ the Bézier curve 📐}}` is a valid holon name.

* They can also contain styling, such as underscores used for emphasis:
  `{{look for the _control point_}}`, say. This can be turned off if it
  causes any confusion (see //Conventions//). Note that `{{look for the control point}}`
  is a different holon name from `{{look for the _control point_}}`, even
  though they differ only in styling. So if you use styling in one mention
  of a holon, you must use matching styling in every mention of it.

* The empty text is not valid, that is, `{{}}` is not legal as a holon name.
  Holon names consisting of white space, like `{{ }}`, _are_ legal, but
  really, get a life.

* Holon names are not allowed to end with the characters `...`: for why,
  see below.

* The same name cannot be used for two different holons in the same file.
  If a web has multiple sections, each in its own file, then it's fine for
  the same holon name — say, `{{Memory has run out}}` — to be used in more
  than one section, but those names are talking about different holons.
  
And there are also common-sense restrictions on how holons are "used", that
is, incorporated into other holons:

* A holon can be used more than once, and can be used either before its
  definition, after its definition, or both.

* Every holon should be used at least once. If it is not, Inweb will issue a
  warning rather than an error, but this warning cannot be muted.

* However, an error will assuredly result from an attempt to use an unknown
  holon. That is, `{{Do something mysterious}}` would throw an error if there
  is no definition of this.

* A holon cannot use itself, directly or indirectly. For example:

      {{alpha}} =

          {{beta}}

      {{beta}} =

          {{alpha}}

  results in an error (whether or not `{{alpha}}` or `{{beta}}` are used elsewhere).

## Naming every holon

Some LP purists may not approve of the way that Inweb normally reads a mix of
nameless and named holons. Shouldn't every holon have a name? That was certainly
the original scheme of Pierre-Arnoul de Marneffe.

Inweb does not adopt this convention by default because large programs containing
a mass of global functions would just become cumbersome if all of those "and
here's another one" holons had to have names. But Inweb does recognise that
some programs will be better presented the old-fashioned way, so it provides
the following feature in order to let authors decide:

* The holon name `{{Main}}` is special. If used at all, it can only be used as
  the first holon in a web. (If the web has multiple sections, that means the
  first holon in the first section which contains any holons.) This first holon
  is then called the "main holon".

* Ordinarily, holon names are case sensitive, and so `{{Read from STDIN}}`
  and `{{read from stdin}}`, for example, are different names. But any casing
  of `{{Main}}` can be used to declare the main holon, so for example `{{main}}`
  or `{{MAIN}}` would also work.

* If there is a main holon, then every holon in the web must be named.

## Continuations

This ability wasn't needed by the example above, but it's also possible to
continue a holon from earlier. Suppose we write the holon:

	{{Print diagnostics}} +=
	
		print("Total memory usage was ", mem_usage)

Note the `+=` here, rather than just `=`. That makes this a continuation of
the holon `{{Print diagnostics}}`, which must already have been defined.
A holon can have any number of continuations; if it does, then the code it
represents is a concatenation of its own lines with the lines in its
continuations, in order of definition. So for example:

	{{Print diagnostics}} =
	
		print("Diagnostics:")

	{{Print diagnostics}} +=
	
		print("Total time taken was ", time_in_cs)

	{{Print diagnostics}} +=
	
		print("Total memory usage was ", mem_usage)

tangles `{{Print diagnostics}}` to:

	print("Diagnostics:")
	print("Total time taken was ", time_in_cs)
	print("Total memory usage was ", mem_usage)

Continuations are best used sparingly, and only when they actually clarify
what is going on, rather than obscuring it.

## Early and late holons

Most programming languages need code to be written in a particular order
to avoid errors, and this is occasionally a nuisance to the literate programmer,
because that isn't the clearest order in which to explain it.

Inweb therefore allows holons to be marked as to be tangled either earlier or
later than usual. For example, the following are all valid header lines:

	{{Include header files}} (tangled very early) =

	{{Initialisation}} (tangled early) =

	{{Do miscellaneous things}} =

	{{Closing down}} (tangled late) =

	{{Check for undeclared symbols}} (tangled very late) =

Inweb will throw an error if code attempts to use an early or late holon. For
example, this cannot work:

	{{Do some business}} =
		print("Starting up")
		{{Initialisation}}

because the `{{Initialisation}}` holon was marked as `tangled early`. So it
can appear only once, and only in the early phase, not as part of another holon.

This is probably a good time to say explicitly what tangling does:

* The following happens in five phases in turn: very early, early, normal,
  late, very late.

* In each phase, each top-level holon belonging to that phase is tangled in turn.

And a holon can be _top-level_ in one of three ways:

* If there is a main holon (see above), that is always top-level. In this case
  there are no nameless holons.

* All nameless holons are top-level. In this case there is no main holon.

* All holons marked as very early, early, late, or very late, are top-level.

Top-level holons are so called because they are exactly the ones which are not
used inside any others. Every part of the program is contained, directly or
indirectly, in at least one top-level holon. To put this in computer-science
terms, our program is a directed multigraph, in which the vertices are the holons,
and an edge is drawn from vertex X to vertex Y whenever holon X uses holon Y.
This graph contains no directed loops, and the top-level holons are exactly the
vertices with no incoming edges.

## Webwide holons

In a web with multiple sections, each section ordinarily has its own private set
of holon names, as explained above. Early LP tools intended for smaller programs
tended instead to have a common set of names used throughout the web, but
experience has shown that for larger webs, this is generally not wise.

But it is occasionally useful to make exceptions for particular holons.
Inweb therefore allows holons to be marked as _webwide_, which means that their
names are visible from every section. (The difference between a webwide and a
regular holon is much like that between a global and a local variable.)

The main holon is automatically webwide if it exists. Otherwise,
holons are only webwide if they are explicitly declared that way. For example,
suppose we declare a holon like this in one section:

	{{Grab bag}} (webwide) =

We could then continue this in any subsequent section of the web, and not just
in its own:

	{{Grab bag}} +=

It's legal for a holon to be both webwide and early/late: for example,

	{{Grab bag}} (webwide and tangled very early) =

Similarly, a webwide holon can be used from outside its own section. We
might, for example, declare this in the opening section of a web:

	{{Disclaimer}} (webwide) =

		print("This part of the program is not fully implemented yet.")

And then we can use `{{Disclaimer}}` anywhere needed.

Webwide holons are, again, best used only when there's a good reason for it.

## Abbreviating holon names

Suppose a holon has a lengthy name which is difficult to type:

	{{Fail with an error message, deallocate memory, and return 1}} =

This may make it annoying to refer to:

		if (text) {{Fail with an error message, deallocate memory, and return 1}}

So Inweb allows such references to be abbreviated:

		if (text) {{Fail...}}

The rule is that the text before `...`, in the case `Fail`, must be a prefix of
the name of _exactly one_ holon defined in the current section; or, if it matches
none in the current section, _exactly one_ holon defined webwide.
