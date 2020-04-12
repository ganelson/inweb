Introduction to Inweb.

What Inweb is, and why it is not CWEB.

@h Introduction.
Inweb is a modern system for literate programming written for the Inform
programming language project.

This means that it is a preprocessor and organiser of source code. It reads in
a "web", an expression of a program which mixes code with heavy quantities of
commentary. Inweb can do two basic things: "weave" the web into a booklet or
website for human readers, or "tangle" it into code ready for a compiler.

Inweb is modern in that it can handle large webs efficiently, with no upper
limit on size; it can weave to modern formats such as PDF files, Epub ebooks
and CSS-styled websites, and it expects that webs will likely be put under
source control at Github or some similar site. These are all technologies
which did not exist when the first wave of LP tools were written, around 1980.

Inweb also aspires to offer as simple a syntax as it can, consistent with
being powerful enough for real-world use. Behind the scenes, though, more
is going on, and Inweb also provides conveniences which remove
the need (in a self-contained project) to write header files, or in general
to predeclare functions or structures.

@h Installation.
Inweb is itself written as a web. The documentation you are currently
reading is part of that web, and if you're reading it as an HTML file or
an ebook then you're looking at the woven form.

While small webs can be written as single files, Inweb is not a small web,
so it occupies a directory called |inweb|. This is what you see if you pull
the project from GitHub, for example.

There is clearly a circularity here. To compile Inweb, you must first run
Inweb to tangle it. But if you already had Inweb, you wouldn't need to compile
it. Here's what to do. From a command-line prompt, set the current working
directory to be the one in which Inweb is stored - that is, not the |inweb|
directory itself, but its parent. Then type one of the following:
= (text as ConsoleText)
	$ make -f inweb/inweb.mk macos

	$ make -f inweb/inweb.mk macos32

	$ make -f inweb/inweb.mk linux

	$ make -f inweb/inweb.mk windows

	$ make -f inweb/inweb.mk unix

	$ make -f inweb/inweb.mk android
=
Unix is for any generic version of Unix, non-Linux, non-MacOS: Solaris, for
example. Android support is currently disabled (though only because its
build settings are currently missing from the inweb distribution). The
older macos32 platform won't build with the MacOS SDK from 10.14 onwards,
and in any case 32-bit executables won't run from 10.15 onwards: so use
the default macos unless you need to build for an old version of MacOS.

You should see some typical make chatter, ending in a reply such as:
= (text as ConsoleText)
	=== Platform set to 64-bit MacOS. Now: make -f inweb/inweb.mk initial ===
=
(All that happened, in fact, was that a platform-specific file of make
settings -- what compilers to use, what options, and so on -- was copied
over to become the file |inweb/platform-settings.mk|. This is a file which
is necessary for Inweb to be fully used, but which is intentionally not
included in the Git repository for Inweb, in order to oblige users to choose
a platform before doing anything else.) Anyway, next do as instructed:
= (text as ConsoleText)
	$ make -f inweb/inweb.mk initial
=
With that done, make should go on to compile the Inweb executable, leaving
you with a working copy of the software. You need never run that
platform-specific command, or make as |initial|, again: you can simply:
= (text as ConsoleText)
	$ make -f inweb/inweb.mk
=
if you want to alter and recompile Inweb.

To test that all is well:
= (text as ConsoleText)
	$ inweb/Tangled/inweb -help
=
That location is where the compiled tool ended up. Users of, for example,
the |bash| shell may want to
= (text as ConsoleText)
	$ alias inweb='inweb/Tangled/inweb'
=
to save a little typing, but in this documentation we always spell it out.

@ When it runs, Inweb needs to know where it is installed in the file
system. There is no completely foolproof, cross-platform way to know this
(on some Unixes, a program cannot determine its own location), so Inweb
decides by the following set of rules:

(a) If the user, at the command line, specified |-at P|, for some path
|P|, then we use that.
(b) Otherwise, if the host operating system can indeed tell us where the
executable is, we use that. This is currently implemented only on MacOS,
Windows and Linux.
(c) Otherwise, if the environment variable |$INWEB_PATH| exists and is
non-empty, we use that.
(d) And if all else fails, we assume that the location is |inweb|, with
respect to the current working directory.

If you're not sure what Inweb has decided and suspect it may be wrong,
running Inweb with the |-verbose| switch will cause it to print its belief
about its location as it starts up.

@h Historical note.
Literate programming is a doctrine invented by Donald Knuth in the early
1980s: the best reference remains Knuth's 1992 book of the same name, though
it is an anthology of much earlier material. The terms web, tangle and weave
all go back to Knuth's work in the late 1970s, well before Tim Berners-Lee
coined the term "world wide web" in 1989.

Literate programming was a rebuttal, or response, to the then-new doctrine of
"structured programming", and to burgeoning work on programming correctness.
Many far-sighted, or alarmist, warnings were being issued around the turn of
the 1980s. "An unreliable programming language generating unreliable programs
constitutes a far greater risk to our environment and to our safety than
unsafe cars, toxic pesticides, or accidents at nuclear power stations" (Tony
Hoare).

Where one response was to attempt mechanical verification that programs were
correct -- a "neat" approach, in the AI jargon of the day -- Knuth instead
opted for a methodology whereby programs had to be carefully explained and
published -- a "scruffy" approach.

@ Knuth notably used LP to write the TeX and Metafont typesetting software,
around 1978-84. His original LP programs "weave" and "tangle" were coded in
a Stanford dialect of Pascal, but in collaboration with Silvio Levy he later
ported them to C as "cweave" and "ctangle". These are collectively called CWEB.
(Inweb, unlike CWEB, is a single program doing both.)

A second wave of LP tools appeared in the 1990s, after the publication of
Knuth's book, and the arrival of Berners-Lee's sort of web: most notably
Norman Ramsey's Noweb (1994) and Ross Williams's Funnelweb (1999). Also,
LP ideas are found in a number of pedagogical tools (especially for teaching
functional programming). It is safe to say, though, that no LP tool has
become standard.

In part this is because LP is not much practiced, but it is also because,
as Christopher Wyk perceptively observed (CACM 33.3, 1990), "no one has yet
volunteered to write a program using another's system for literate
programming".

For over a year, though, the Inform project did try to use CWEB. It proved
inadequate for a number of reasons. It was too closely tied to TeX (as the
only weave format); it was, syntactically, rooted in the computing paradigms
of the 1970s, when nothing was WYSIWYG and the escape character was king; and
it parsed C using a top-down grammar of productions in order to work out an
"ideal" layout of the code which is usually worse than a simple
syntax-colouring text editor could manage, and often much worse. (This grammar
coped particularly poorly with macros, and was very cranky to edit.) More
problematically, CWEB contained hard limits on the size of the source code it
could handle, failing at around 50,000 lines. Since it used tricksy forms of
bitmap storage to save memory, this limit was very hard to raise. On larger
webs, an obscure off-by-one line counting error in ctangle also caused
difficulty.

I struggled on for a while with a fork of CWEB, hoping to modernise it, but
finally concluded that its problems were too deep-seated. Inweb uses none of
its code, but most of its best ideas. Around 2004, Inweb began as a Perl
script; it was reimplemented in C for speed in 2011.

@ Those who have used CWEB or similar tools may wish to note four important
differences:

(a) Many bells and whistles have been removed. Inweb aspires to be as
simple as possible in markup, with as few escape characters as possible.

(b) In Inweb, when writing code for C-like languages, named paragraphs are
expanded inside implicit braces. As a result, they behave like compound
statements, and can be used as loop bodies, or if/else clauses.

(c) Inweb does not follow the disastrous rule of CWEB that every name is
equal to every other name of which it is an initial substring, so
that, say, "Finish" would be considered the same name as "Finish with error".
This was a rule Knuth adopted to save typing. He habitually wrote
elephantine names, the classic being §1000 of the TeX source code, which he
called "If the current page is empty and node p is to be deleted,
goto done1; otherwise use node p to update the state of the
current page; if this node is an insertion, goto contribute;
otherwise if this node is not legal breakpoint, goto contribute
or update_heights; otherwise set pi to the penalty associated
with this breakpoint". We do not recommend this.

(d) Inweb can be used with much larger programs divided into sections
and, if desired, chapters.
