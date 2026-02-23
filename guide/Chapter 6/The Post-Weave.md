# The Post-Weave

The _post-weave_, very much the après-ski experience of weaving, is a moment
when Inweb can (if a pattern has told it to) perform some follow-on work with
the documents it has just woven. As with the après-ski, by default nothing
happens.

In fact, nothing will ever happen unless the pattern for a weave has a
declaration containing a `commands` block. The only pattern supplied with Inweb which does have
`commands` is `PDFTeX`, whose declaration reads:

	Pattern "PDFTeX" {
		based on: TeX
		initial extension: .tex
		commands
			pdftex -output-directory=WOVENPATH -interaction=scrollmode WOVEN.tex >WOVEN.console
			PROCESS WOVEN.log
			rm WOVEN.log
			rm WOVEN.console
		end
	}

The conundrum here is this. `PDFTeX` wants to produce PDF documents. But Inweb
can only produce TeX source code: for this to be turned into a PDF, it needs
to be run through some external tools — not least some form of TeX. Inweb cannot
contain those tools within itself, so it has to call out to the surrounding
operating system's shell. This is what the commands do.

This feature might not seem worth it for a single file, but bear in mind that
Inweb might be producing 200-odd files at a time, one for each section of a
large web. It's much more convenient to have Inweb manage the process of
turning all those individual TeX files into PDFs, not least because Inweb
will get their fiddly filenames correct.

Each line of the `commands` block is a shell command, _unless_ it has the
form `PROCESS filename`. This gives Inweb the chance to look at the file if
it wants to. That's in practice only ever going to be useful for TeX: what
Inweb does is to scan through the output produced by TeX to see if there
have been overfull hbox errors, count the number of pages, and such. So,
really, it should be used only by the definition above.

Here is the above post-weave system in action:

	$ inweb weave pyramid.c.md -as PDFTeX
	weaving web "Hilbert's Pyramid" (C program in MarkdownCode notation) as PDFTeX (based on TeX)
	(pdftex -output-directory='.'  -interaction=scrollmode 'pyramid.tex'  >'pyramid.console')
	(rm 'pyramid.log')
	(rm 'pyramid.console')
		generated: pyramid.tex

Note that `WOVENPATH` in one command has become `.` (the output directory
happens to be the current working directory here), while each `WOVEN` has
become `pyramid`. Note that `WOVEN` cannot begin with `-`, or contain any
spaces, so the command `rm WOVEN.log` is not quite the invitation to walk
through a graveyard at night that it might seem. Those are the only two
substitutions made by Inweb when it passes these commands to the system
shell.
