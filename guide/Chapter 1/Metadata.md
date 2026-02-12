# Metadata

Recall that `inweb inspect` will tell us what a file seems to be:

	$ inweb inspect countsort.py.md
	web "Counting Sort" (Python program in MarkdownCode notation): 3 paragraphs : 33 lines

When the file is a web, adding the `-metadata` switch will give a more
comprehensive view of the "metadata" for a web:

	$ inweb inspect -metadata countsort.py.md
	web "Counting Sort" (Python program in MarkdownCode notation): 3 paragraphs : 33 lines
	
	Title: Counting Sort
	Author: Anonymous
	Language: Python
	Notation: MarkdownCode

Inweb is all about treating webs as if they were literary texts like books,
and what we see here is like the bibliographic data on a published book, which
might be used in library catalogues.

In this case, of course, there's little to see: the web is simple and doesn't
say much about itself. Inweb inferred the programming language (Python) and
notation (Markdown) from the filename `countsort.py.md`, and found the title
from the heading on the file's opening line:

	# Counting Sort

We could give this program an author by rewriting that first line:

	# Counting Sort by Harold H. Seward

whereupon:

	$ inweb inspect -metadata countsort.py.md
	web "Counting Sort" (Python program in MarkdownCode notation): 3 paragraphs : 33 lines
	
	Title: Counting Sort
	Author: Harold H. Seward
	Language: Python
	Notation: MarkdownCode

It's also possible to specify a version number:

	# Counting Sort by Harold H. Seward (v1954.2)

resulting in:

	Title: Counting Sort
	Author: Harold H. Seward
	Language: Python
	Notation: MarkdownCode
	Version Number: 1954.2

The version number must conform to the semver standard in its format, and
can include prerelease and build numbers. For example, placing `(v1954.2-beta3+1B16)`
in the title line, rather than simply `(v1954.2)`, adds the following metadata:

	Build Number: +1B16
	Prerelease: -beta3
	Semantic Version Number: 1954.2-beta3+1B16
	Version Number: 1954.2

In fact, the previous version also had `Build Number` (blank), `Prerelease` (blank),
and `Semantic Version Number` (same as the ordinary `Version Number`) in existence,
but these weren't displayed because they hadn't been set explicitly. Webs have a
number of concealed-unless-used metadata like these: see `inweb inspect -metadata -fuller`
if you're curious.

There's one last thing we can specify in a simple web like "Counting Sort": its
so-called _purpose_. This should be a quite brief summary of what the program
does, or is for. It should consist of one or two lines in italics, placed
immediately after the title. For example, our file might now begin:

	# Counting Sort by Harold H. Seward (v1954.2)
	
	_An implementation of the 1954 sorting algorithm._

Note that the purpose text is not allowed to contain any other styling markup,
just the italic markers `_` either side, and must be preceded and followed by
a blank line.

That being so, we then find:

	$ inweb inspect -metadata countsort.py.md
	web "Counting Sort" (Python program in MarkdownCode notation): 3 paragraphs : 41 lines
	
	Title: Counting Sort
	Author: Harold H. Seward
	Purpose: An implementation of the 1954 sorting algorithm.
	Language: Python
	Notation: MarkdownCode
	Version Number: 1954.2

This completes the suite of metadata which a single-file Markdown-notation web
can provide.

What good are metadata? One answer is that they help to catalogue and organise
programs, and enable Inweb to identify them. But they can also make it convenient
to print identifying information when the program is run. For example, we could
amend the code testing our sorting program:

	A = [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
	print("Unsorted:", A)
	print("Sorted:", countingSort(A))
	print("So sayeth [[Author]].")

And now, when this is run, we would see:

	Unsorted: [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
	Sorted: [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]
	So sayeth Harold H. Seward.

What happened here is that `[[Author]]` in the double-quoted Python string
`"So sayeth [[Author]]."` was automatically replaced by the value of `Author`
for the program when it was tangled, producing `"So sayeth Harold H. Seward."`.
This happens only for the handful of metadata known to Inweb; any other use
of `[[` and `]]` in strings will be left alone. So, for example, the following
web:

	# Contrivance by Ludwig van der Blonk (v3.14)
	
	_Identifies itself._

	print "[[Author]] brings you [[Title]], in version [[Version Number]]."

tangles to a Python program whose sole act is to print

	Ludwig van der Blonk brings you Contrivance, in version 3.14.
