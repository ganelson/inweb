# Creating Notations

First, some friendly advice: there may be no need for this. If all that's wanted
is, for example, to change the syntax for named holons, that can be done by
applying `Conventions` to a web written in an existing notation. With that said,
this section offers a tutorial.

## Simple

To get started, here is a notation called `Simple` which does only the absolute
minimum of literate programming: it recognises indented lines as code, and
unindented lines as Markdown commentary. As a test case for that, here's
`countsort.py.simp`:

	This is a Python implementation of the counting sort algorithm. The following
	function takes an array of non-negative integers, sorts it, and returns the result:
	
		def countingSort(unsorted):
			sorted = []
			if unsorted:
				max_val = max(unsorted)
				counts = [0] * (max_val + 1)
				for value in unsorted:
					counts[value] += 1
				for value, count in enumerate(counts):
					sorted.extend([value] * count)
			return sorted
	
	And this code tests the function:
	
		A = [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
		print("Unsorted:", A)
		print("Sorted:", countingSort(A))
	
	Here's what you should see when this runs:
	
	``` console
	Unsorted array: [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
	Sorted array: [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]
	```
	
So now we need to define `Simple`, and tell Inweb to recognise `.simp` files
as using it. The following definition will do:

	Notation "Simple" {
		recognise .simp
		recognise .*.simp
	
		classify
			MATERIAL 	            ==> code if in indented context
			MATERIAL				==> commentary
		end
	}

This can be placed in, say, the file `simple.inweb`.

Everything seems to work nicely:

	$ inweb inspect countsort.py.simp -using simple.inweb
	web "Untitled" (Python program in Simple notation): 3 paragraphs : 31 lines

	$ inweb tangle countsort.py.simp -using simple.inweb -to - | python3
	Unsorted: [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
	Sorted: [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]

Note the `-using simple.inweb` added to the Inweb commands here: these make
declarations in the file `simple.inweb` available to Inweb. There are
alternative ways to do that; for example, if the `countsort.py.simp` web
were part of a colony, then the colony declaration could incorporate the
`Simple` one; or, if the web were large enough for a contents page, that
could do so —

	Title: Sorting Smorgasbord
	Author: Various Artists
	Notation: Simple
	Language: Python
	Version Number: 3.0.1

	Sections
		Counting Sort
		Quick Sort

	Notation "Simple" {
		recognise .simp
		recognise .*.simp
	
		classify
			MATERIAL 	            ==> code if in indented context
			MATERIAL				==> commentary
		end
	}

However it's done, though, Inweb can only use `Simple` if it can see the
declaration somewhere.

Looking back at the declaration, let's take it apart. Firstly, it declares
a named resource of type `Notation` and with the name `Simple`, so it has
the following shape:

	Notation "Simple" {
		...
	}

The contents of the definition begin like so:

		recognise .simp
		recognise .*.simp

This tells Inweb which filename extensions are a clue that a web might be
written with this notation. Note the second line: this says that a double
filename extension, where `*` represents an extension suggesting a programming
language as well, is also allowed. (And this is what enables the filename
`countsort.py.simp` to be recognised.)

Any number of `recognise` lines are allowed, including none. For example,

		recognise .simple
		recognise .*.simple

could be added as alternatives.

The critical part of a notation is the part telling Inweb how to classify
its lines. Inweb reads literate source one line at a time — unlike some
earlier LP tools, it's very much line-based, rather than reading its input
as a stream of characters. Each line is then run through the classifier,
which normally offers one or more possible readings: and Inweb accepts the
first one which works.

The classifier here offers two possible ways to read a line:

		classify
			MATERIAL 	            ==> code if in indented context
			MATERIAL				==> commentary
		end

Each possibility takes the form of a textual pattern to match, then a `==>`
marker, and then the outcome if it does match, possibly with a condition attached.
(White space either side of the `==>` is ignored.)

Here the patterns are both just `MATERIAL`. This is not the literal word
"MATERIAL": it's a wildcard, which matches anything. So in fact both lines
in the classifier will match every possible input. However, the first one
matches only `if in indented context`. This is a _condition_, and means
more than just saying that the line itself is indented: it has to be part
of a run of indented lines, with white space either side. For example, on
the following input:

	You need to get through 30 whole sonnets of Philip Sidney's _Astrophel
	and Stella_ (1591) before you arrive at the good bit:

		With how sad steps, oh Moon, thou climb'st the skies,
		How silently, and with how wan a face.
		What, may it be, that even in heav'nly place
		That busy archer his sharp arrows tries?

Here the four lines of verse would be read `in indented context`, because
they are part of just such an indented block. Reading this:

	Oh grammar rules, oh now your virtues show
		So children still read you with awefull eyes,
	As my young dove may in your precepts wise
		Her grant to me, by her own virtue know.

Inweb would not register any of the lines as `in indented context`, even
though two are indented.

So, then, the result of the above classifier is:

	This is a Python implementation of the counting sort...		commentary
	function takes an array of non-negative integers, so...		commentary
                                                                commentary
		def countingSort(unsorted):                             code
			sorted = []                                         code
			if unsorted:                                        code
				max_val = max(unsorted)                         code
				counts = [0] * (max_val + 1)                    code
				for value in unsorted:                          code
					counts[value] += 1                          code
				for value, count in enumerate(counts):          code
					sorted.extend([value] * count)              code
			return sorted                                       code
                                                                commentary
	And this code tests the function:                           commentary
                                                                commentary
		A = [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]                   code
		print("Unsorted:", A)                                   code
		print("Sorted:", countingSort(A))                       code
	
and so on. That can be verified using `inweb inspect -scan`:

	$ inweb inspect countsort.py.simp -scan -using simple.inweb
	web "Untitled" (Python program in Simple notation): 3 paragraphs : 27 lines
	S1
		C1: commentary
			_______ This⏑is⏑a⏑Python⏑implementation⏑of⏑the⏑counting⏑sort⏑algorithm.⏑The⏑following
			_______ function⏑takes⏑an⏑array⏑of⏑non-negative⏑integers,⏑sorts⏑it,⏑and⏑returns⏑the⏑result:
		C2: holon (used sequentially)
			0000004 def⏑countingSort(unsorted):
			0000005 ⏑⏑⏑⏑sorted⏑=⏑[]
			0000006 ⏑⏑⏑⏑if⏑unsorted:
			0000007 ⏑⏑⏑⏑⏑⏑⏑⏑max_val⏑=⏑max(unsorted)
			0000008 ⏑⏑⏑⏑⏑⏑⏑⏑counts⏑=⏑[0]⏑*⏑(max_val⏑+⏑1)
			0000009 ⏑⏑⏑⏑⏑⏑⏑⏑for⏑value⏑in⏑unsorted:
			0000010 ⏑⏑⏑⏑⏑⏑⏑⏑⏑⏑⏑⏑counts[value]⏑+=⏑1
			0000011 ⏑⏑⏑⏑⏑⏑⏑⏑for⏑value,⏑count⏑in⏑enumerate(counts):
			0000012 ⏑⏑⏑⏑⏑⏑⏑⏑⏑⏑⏑⏑sorted.extend([value]⏑*⏑count)
			0000013 ⏑⏑⏑⏑return⏑sorted
	S2
		C1: commentary
			_______ And⏑this⏑code⏑tests⏑the⏑function:
		C2: holon (used sequentially)
			0000017 A⏑=⏑[4,⏑2,⏑2,⏑6,⏑3,⏑3,⏑1,⏑6,⏑5,⏑2,⏑3]
			0000018 print("Unsorted:",⏑A)
			0000019 print("Sorted:",⏑countingSort(A))
	...

In these scan printouts, `S1`, `S2`, ..., are the paragraphs, which are internally
divided into _chunks_, `C1`, `C2`, and so on. What has happened, then, is that
Inweb has formed the commentary lines together into commentary chunks, and the
code lines into code chunks — which are called holons. When creating a new
notation, it's generally a good idea to write a test web which tries it out,
and to keep on using `inweb inspect -scan` to check that it's being read in
correctly.

## Not quite so simple

Adding a few further features should give a clearer idea of how classification
works. First, let's add subheadings, using Markdown's customary `##` syntax.
This can be done with a new possible match:

		classify
			## MATERIAL             ==> beginparagraph
			MATERIAL 	            ==> code if in indented context
			MATERIAL				==> commentary
		end

So we have a new outcome, `beginparagraph`, which forces a paragraph break
to occur at this point in the source. The `MATERIAL` becomes the subtitle
for the paragraph.

And what about a heading at the top of the file? A really full provision
for that needs quite a run of fresh matches:

		classify
			# "MATERIAL" by SECOND (vTHIRD)     ==> title if on first line of only file
			# MATERIAL by SECOND (vTHIRD)		==> title if on first line of only file
			# MATERIAL (vTHIRD)					==> title if on first line of only file
			# "MATERIAL" by SECOND				==> title if on first line of only file
			# "MATERIAL"						==> title if on first line
			# MATERIAL by SECOND				==> title if on first line of only file
			# MATERIAL							==> title if on first line
			## MATERIAL             			==> beginparagraph
			MATERIAL 	           				==> code if in indented context
			MATERIAL							==> commentary
		end

The outcome in all of those seven, count them, seven matches is `title`. Note
the two new conditions here: `if on first line` means we are on the first line
of the current file (remembering that larger webs have many sections, so that
this may be the title only of one section); `if on first line of only file`
matches only for the top line of a single-file web. It's only in those cases
where we look out for an author name and version number, which (if given)
go into the new wildcards `SECOND` and `THIRD`. For example, matching

	"North by Northwest" by Alfred Hitchcock (v2.1)

would fill `MATERIAL` with "North by Northwest", `SECOND` with "Alfred Hitchcock",
and `THIRD` with "2.1".

Okay, so now for something more powerful: named holons. Combine this classification:

		<OPENHOLON>MATERIAL<CLOSEHOLON> ~~>     ==> namedholon

with a new convention:

		Conventions {
			holon names are written between <[ and ]>
		}

(Conventions can be added at the end of pretty well all Inweb declarations:
see //Resources and Declarations// for the rules on all of that.)

The effect is an eccentric new syntax, one which would read the following web:

	In non-so-simple notation:
		
		def countingSort(unsorted):
			sorted = []
			if unsorted:
				<[initialise the incidence counts to zero]>
				<[tally how many times each value occurs in the unsorted array]>
				<[construct the sorted array with the right number of each value]>
			return sorted
	
	<[initialise the incidence counts to zero]> ~~>
	
		max_val = max(unsorted)
		counts = [0] * (max_val + 1)
	
	<[tally how many times each value occurs in the unsorted array]> ~~>
	
		for value in unsorted:
			counts[value] += 1
	
	<[construct the sorted array with the right number of each value]> ~~>
	
		for value, count in enumerate(counts):
			sorted.extend([value] * count)	
	
	Testing which:
	
		A = [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
		print("Unsorted:", A)
		print("Sorted:", countingSort(A))

And then indeed:

	$ inweb tangle countsort.py.nssimp -to - -using nssimple.inweb | python2
	('Unsorted:', [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3])
	('Sorted:', [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6])

Of course, this notation is only a little different from `MarkdownCode`. We
are writing holons as `<[Name]>` rather than `{{Name}}`, and declaring them
with `<[Name]> ~~>` rather than `{{Name}} =`. All the same, it _is_ different,
and the full variation available to notations is pretty generous. We could
also, say, add:

		Extend <OPENHOLON>MATERIAL<CLOSEHOLON> ~~>  ==> namedholon with continuationoption

and now instead of the `MarkdownCode` syntax for extending a holon, `{{Name of holon}} +=`,
we recognise `Extend <[Name of holon]> ~~>`.

So, then, here there were two new outcomes: `namedholon` and
`namedholon with continuationoption`. (That use of `with` to modify an outcome
with an option is relatively unusual: only a few outcomes have options available.)
Also new were the syntaxes `<OPENHOLON>` and `<CLOSEHOLON>` in the patterns to
match. Rather than matching literally, these match whatever setting is currently
made by the `holon names are written between ... and ...` convention.

## RESIDUE

Suppose we want to make a pilcrow sign ¶ begin a new paragraph, when it's found
in the first column of a line. That seems easy enough:

		¶             			                    ==> beginparagraph

As far as it goes, that works fine; except that the following natural-looking
commentary doesn't work —

	¶ According to part 11(b) of the specification, an identifier name which
	begins with an underscore is reserved, but we are not obliged to reject it.
	Therefore...

The solution is this:

		¶             			                    ==> beginparagraph
		¶ RESIDUE            			            ==> beginparagraph

`RESIDUE`, like `MATERIAL`, `SECOND` and `THIRD`, is another wildcard which
can match any text. If Inweb classifies a line and finds anything in `RESIDUE`,
it turns that material into a new line which immediately follows on, and
then classifies that in turn. For example, Inweb reads this:

	¶ According to part 11(b) of the specification, an identifier name which

and classifies it `beginparagraph`, with `RESIDUE` set to "According to part
11(b) of the specification, an identifier name which". Inweb then classifies
the new line

	According to part 11(b) of the specification, an identifier name which

and classifies it `commentary`. In effect, then, Inweb read the original text
as two lines in succession:

	¶
	According to part 11(b) of the specification, an identifier name which

In fact, still more is possible. Suppose we want this to work:

	¶ ^"specification" ^"ANSI" According to part 11(b), ...

...where we want to "tag" the paragraph with the keywords "specification" and "ANSI".
There can be any number of those tags, so the syntax isn't fixed. The trick now
is to supply a whole new classifier:

	residue of beginparagraph
		RESIDUE <OPENTAG>MATERIAL<CLOSETAG>         ==> paragraphtag
		<OPENTAG>MATERIAL<CLOSETAG>                 ==> paragraphtag
	end

This tells Inweb that if it finds anything in the `RESIDUE` after classifying
a `beginparagraph`, it should then run that material through this classifier.
So the sequence of events is:

- Inweb reads `¶ ^"specification" ^"ANSI" According to part 11(b), ...` as
a `beginparagraph`, with residue "^"specification" ^"ANSI" According to part 11(b), ...".

- Inweb matches `^"specification" ^"ANSI" According to part 11(b), ...` with
the `residue of beginparagraph` classifier, spotting `paragraphtag` with
`MATERIAL` set to "specification".

- Inweb matches `^"ANSI" According to part 11(b), ...` with the `residue of beginparagraph`
classifier, spotting `paragraphtag` with `MATERIAL` set to "ANSI".

- Inweb matches `According to part 11(b), ...` with the `residue of beginparagraph`
classifier, but this time doesn't make a match, and so...

- Inweb reads `According to part 11(b), ...` as a new line, which it then
classifies as `commentary`.

## OPTIONS

The `MarkdownCode` notation allowed for a whole range of qualifying notes to
be added to a holon declaration. For example, in `MarkdownCode`, this was legal:

	{{Grab bag}} (webwide and tangled very early) =

Let's add an equivalent functionality to our example notation. Start with
a new classification line:

		<OPENHOLON>MATERIAL<CLOSEHOLON> (OPTIONS) ~~>   ==> namedholon

As before, this has the outcome `namedholon`. The only difference is that
this time it fills a new wildcard called `OPTIONS`. So how do we deal with that?
The answer is that we give it a whole new classification:

	options of namedholon
		webwide                                     ==> webwideholonoption
		tangled very early                          ==> veryearlyholonoption
		tangled early                               ==> earlyholonoption
		tangled late                                ==> lateholonoption
		tangled very late                           ==> verylateholonoption
		webwide, OPTIONS                            ==> webwideholonoption
		tangled very early, OPTIONS                 ==> veryearlyholonoption
		tangled early, OPTIONS                      ==> earlyholonoption
		tangled late, OPTIONS                       ==> lateholonoption
		tangled very late, OPTIONS                  ==> verylateholonoption
		webwide and OPTIONS                         ==> webwideholonoption
		tangled very early and OPTIONS              ==> veryearlyholonoption
		tangled early and OPTIONS                   ==> earlyholonoption
		tangled late and OPTIONS                    ==> lateholonoption
		tangled very late and OPTIONS               ==> verylateholonoption
		MATERIAL                                    ==> error "unknown holon option(s)"
	end

This tells Inweb how it should deal with any material found in `OPTIONS` after
it has classified a `namedholon`. So for example, in our bizarro syntax,
suppose Inweb is parsing this line:

	<[Do something elegant]> (tangled very early and webwide) ~~>

The regular classification will diagnose this as a `namedholon` with
`MATERIAL` set to the name, "Do something elegant". The `OPTIONS`, though,
will be set to "tangled very early and webwide". Inweb then runs _that_ text
through the `options of namedholon` classifier, and matches it against

		tangled very early and OPTIONS              ==> veryearlyholonoption

This registers the `veryearlyholonoption` option, and reduces the `OPTIONS`
text to "webwide". This is still not empty, so Inweb classifies again, and
this time matches against

		webwide                                     ==> webwideholonoption

And so we end up with `namedholon` supplemented by two options,
`veryearlyholonoption` and `webwideholonoption`.

In practice, only a few outcomes support options, but when they are needed
they do something which otherwise couldn't easily be done.

## A farewell to NotSoSimple

To recap, then, this is the final version of what's now called "NotSoSimple":

	Notation "NotSoSimple" {
		recognise .nssimp
		recognise .*.nssimp
	
		classify
			# "MATERIAL" by SECOND (vTHIRD) 		    ==> title if on first line of only file
			# MATERIAL by SECOND (vTHIRD)				==> title if on first line of only file
			# MATERIAL (vTHIRD)							==> title if on first line of only file
			# "MATERIAL" by SECOND						==> title if on first line of only file
			# "MATERIAL"								==> title if on first line
			# MATERIAL by SECOND						==> title if on first line of only file
			# MATERIAL									==> title if on first line
			## MATERIAL             					==> beginparagraph
			¶             			                    ==> beginparagraph
			¶ RESIDUE            			            ==> beginparagraph
			<OPENHOLON>MATERIAL<CLOSEHOLON> ~~> 		==> namedholon
			<OPENHOLON>MATERIAL<CLOSEHOLON> (OPTIONS) ~~>   ==> namedholon
			Extend <OPENHOLON>MATERIAL<CLOSEHOLON> ~~>  ==> namedholon with continuationoption
			MATERIAL 	                        		==> code if in indented context
			MATERIAL									==> commentary
		end

		residue of beginparagraph
			RESIDUE <OPENTAG>MATERIAL<CLOSETAG>         ==> paragraphtag
			<OPENTAG>MATERIAL<CLOSETAG>                 ==> paragraphtag
		end

		options of namedholon
			webwide                                     ==> webwideholonoption
			tangled very early                          ==> veryearlyholonoption
			tangled early                               ==> earlyholonoption
			tangled late                                ==> lateholonoption
			tangled very late                           ==> verylateholonoption
			webwide, OPTIONS                            ==> webwideholonoption
			tangled very early, OPTIONS                 ==> veryearlyholonoption
			tangled early, OPTIONS                      ==> earlyholonoption
			tangled late, OPTIONS                       ==> lateholonoption
			tangled very late, OPTIONS                  ==> verylateholonoption
			webwide and OPTIONS                         ==> webwideholonoption
			tangled very early and OPTIONS              ==> veryearlyholonoption
			tangled early and OPTIONS                   ==> earlyholonoption
			tangled late and OPTIONS                    ==> lateholonoption
			tangled very late and OPTIONS               ==> verylateholonoption
			MATERIAL                                    ==> error "unknown holon option(s)"
		end
		
		Conventions {
			holon names are written between <[ and ]>
		}
	}

## Processing

An entirely different mechanism, intended to be used only if really necessary,
allows material in the web to be "processed" (read: rewritten).

For example:

	process commentary
		green ==> blue
		blue ==> green
	end

	process code
		green ==> brown
	end

This looks a little like one of the classifiers above, but it's subtly different.
It's hard to see why one would want to do this, but the result is that this web:

	A greengrocer, once in a blue moon, might run this code:
	
		for (int green_bottles = 1; green_bottles <= 10; green_bottles++)
			printf("%d green bottles standing on a wall\n", green_bottles);

would be read in as:

	A bluegrocer, once in a green moon, might run this code:
	
		for (int brown_bottles = 1; brown_bottles <= 10; brown_bottles++)
			printf("%d brown bottles standing on a wall\n", brown_bottles);

Those changes are made after classification, of course, which is how Inweb
knows whether to apply its changes to code or commentary. But it is also
possible to "preprocess" lines before classification, or "postprocess" them
afterwards.

For example:

	preprocess
		@@  ==> §real_at_character§
		@+  ==> <SPACE>
		@&  ==> <NOTHING>		
	end

	postprocess
		§real_at_character§ ==> @
	end

Here the idea is that `@@` is notation for a literal `@` character which would
not trigger any of the lines in the classification; we preprocess that into the
text `§real_at_character§`, rendering it inactive, and then postprocess it back
again after classification. On the other hand, we just replace `@+` with a space
to get rid of it, and `@&` goes altogether.
