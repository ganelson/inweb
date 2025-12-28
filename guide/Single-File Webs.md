# Single-File Webs

## A simple example

Because LP is designed to help manage the complexity of difficult or large
programs, it looks artificial when applied to "hello world"-sized examples.
Still, here goes.

We will create a single-file web of a Python program to implement one of the
simplest (also most dubious) sorting algorithms: counting sort. This will be
written in the simplest notation Inweb supports, Markdown, and the web is
as follows:

    # Counting Sort
    
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
    
    ```
    Unsorted: [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
    Sorted: [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]
    ```

We store that as the text file `countsort.py.md`. Note that this filename has
two filename extensions: the `.py` part marks this as a web for a program
in the Python programming language, and the `.md` says it is written in Markdown
notation.

This is a web with the title "Counting Sort", since that is written as a heading
at the top line. It contains just three paragraphs, which begin with the words
`This is a...`, `And this code...` and `Here's what...` respectively. Paragraphs
1 and 2 each contain both commentary and also pieces of code from the program,
indicated by being indented one tab stop in the usual Markdown way. (Like
Markdown, Inweb takes a tab stop to be equivalent to four spaces.) Paragraph 3
is pure commentary: note that the so-called fenced extract is not taken as part
of the program.

To reassure ourselves that this file makes sense to Inweb, we could try:

    $ inweb inspect countsort.py.md
    web "Counting Sort" (Python program in MarkdownCode notation): 3 paragraphs : 33 lines

The title "Counting Sort" has been correctly extracted, and there are indeed 3 paras,
so this is looking good.

The notation is described as `MarkdownCode` rather than plain `Markdown` because
Inweb can also read Markdown files which are straightforwardly documents, not
containing a program at all. In fact, if we had called the exact same file
`countsort.md`, not `countsort.py.md`, that's just what would have happened:

    $ inweb inspect countsort.md
    web "Counting Sort" (Markdown notation): 1 paragraph : 33 lines

Here the entire file would be a single paragraph, and all of it is commentary.
Note that Inweb does not now say it is a `Python program`.

It may seem precarious that Inweb reads the same file in quite different ways
depending only on its filename, but these are all just the _default_ ways
Inweb makes these decisions, when it hasn't been told any different.

## Tangling

It's time to tangle the web to an actual program, and run it:

    $ inweb tangle countsort.py.md
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'countsort.py'

    $ python3 countsort.py
    Unsorted: [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
    Sorted: [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]
    
As this demonstrates, the `python3` interpreter is only asked to run the tangled
output file `countsort.py`.

Inweb chose the filename `countsort.py` for the output file because that seemed
the obvious way to express that Markdown formatting had been stripped from `countsort.py.md`.
But this can be overridden with the `-to FILE` switch:

    $ inweb tangle countsort.py.md -to tangled_stuff/mystery.py
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'tangled_stuff/mystery.py'

The special output file `-` can be used to mean "print the result of tangling
rather than saving it in a file": it doesn't create a file literally called `-`.
Using this automatically engages `-silent` mode to suppress the heading, because
we wouldn't want the familiar "tangling web..." text to be mixed into the output.
The main purpose of `-to -` is so that Inweb's tangled output can be decanted
into a Unix pipe. Pipes are a feature of Unix-like operating systems in which
the output printed by one tool becomes the input read by another. So, for example:

	$ inweb tangle countsort.py.md -to - | python3
	Unsorted: [4, 2, 2, 6, 3, 3, 1, 6, 5, 2, 3]
	Sorted: [1, 2, 2, 2, 3, 3, 3, 4, 5, 6, 6]

The pipe character `|` indicates that output from `inweb tangle countsort.py.md -to -`
should be fed continuously into `python3` until it runs out. Since `python3`,
the interpreter for the Python programming language, can read its program from
so-called "standard input", the result is that the program just runs. No file
called `countsort.py` needed to be written at all, which seems tidy.

This can also sometimes be used to inspect the tangled output. For example:

	$ inweb tangle countsort.py.md -to - | more
	$ inweb tangle countsort.py.md -to - | bbedit

Here we pipe to either `more`, a standard Unix tool for displaying files which
are too long to show on screen all at once, or to the MacOS text editor BBEdit.

## Weaving

Weaving next:

    $ inweb weave countsort.py.md
    weaving web "Counting Sort" (Python program in MarkdownCode notation) as HTML
	the weave would require this directory to exist:
	    countsort2-assets
	inweb: fatal error: giving up: either make it by hand, or run again with -creating set

As this reply shows, Inweb is a little cautious about creating directories
automatically: this one looks harmless enough, but for really large weaves,
better safe than sorry. Typing `mkdir countsort2-assets` would make this go away,
but instead why not take Inweb's advice:

     $ inweb weave countsort.py.md -creating
    weaving web "Counting Sort" (Python program in MarkdownCode notation) as HTML
	(created directory 'countsort2-assets')
		generated: countsort2.html
		10 files copied to: countsort2-assets

And now that the directory exists, we don't need to use `-creating` again.

Depending on the format being woven, weaving is more complicated than tangling,
and often generates multiple files, which have to be put somewhere. What the
reply above is trying to communicate is that the actual text has been put into
a single HTML file, `countsort.html`, and that a number of supporting files
(mostly CSS and JavaScript, and loosely called "assets") have been put into a
new directory called `countsort-assets`.

Larger webs, with multiple sections, produce more elaborate websites, and the
reply from `inweb weave` is then longer. Here's the output from weaving a longer
program:

    weaving web "longer" (InC program) as GitHubPages (based on HTML)
        [longer/docs/M-iti.html] [M-wtaw] [M-htwaw] [M-mwiw] [M-awwp] [M-spl] [M-tid] [M-rc] 
        [P-htpw] 
        [1-pc] [1-cnf] [1-ias] [1-iis] [1-ims] [1-ims2] [1-its] [1-its2] [1-iws] 
        [index] 
        18 files copied to: longer/docs/docs-assets
        7 files copied to: longer/docs

The filenames in square brackets are abbreviated for legibility: only the first
filename is written in full, `longer/docs/M-iti.html`, and all subsequent files
are understood to be in the same directory and with the same file extension
unless otherwise indicated. So, `[M-wtaw]` means in fact `longer/docs/M-wtaw.html`,
and so on.
