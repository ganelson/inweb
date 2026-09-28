# Patterns for Weaving PDFs

By default, Inweb weaves websites, but it can also weave webs to "print"
documents, or at any rate PDFs which can be printed out, emailed, downloaded,
and so forth.

Paper is a subtly different medium than the web, mostly because it doesn't
stretch or shrink as needed. Some programs will be hard to squash into the
margins of US Legal or A4 paper, for example. Web authors need to live within
this reality. It's entirely possible to make good-looking and practical PDFs out
of Inweb webs: but some compromises may be needed. If you are reading this guide
in a PDF, you can form your own opinion, because it will have been woven by Inweb.

## First choose your TeX

Inweb comes with a slew of built-in patterns for weaving to PDF, but this
apparent variety is a little misleading. All are based on different versions
of the TeX typesetting system. Inweb allows any combination of the three main
"engines" used by TeX experts, and the two main environments built on top:

|           | tex     | pdftex     | xetex      |
| --------- | ------- | ---------- | ---------- |
| Plain TeX | `TeX`   | `PDFTeX`   | `XeTeX`    |
| LaTeX     | `LaTeX` | `PDFLaTeX` | `XeLaTeX`  |

On the environments:

- Plain TeX is the original, 1984-vintage TeX, and indeed has roots in the
1970s. Though highly extensible, and the subject of a classic book, it is
not in practice used any longer in its original raw form.

- The LaTeX macro package, originally written as a more user-friendly layer on
top of plain TeX, rapidly supplanted it as the main system used by scientists
and mathematicians to write papers and books. It has gradually become more
sophisticated, and is accompanied (in the standard TeXLive distribution) by a
substantial suite of add-on "packages". All serious typographic work done with
TeX today is done with some form of LaTeX.

On the engines:

- The original tex engine is sturdy but obsolete. Inweb produces only a TeX
source file: this will then need to be run through the `tex` command-line tool
to produce a so-called DVI file, an obsolete format from the early 1980s,
which will then need to be converted with further tools to make a PDF.
Hyperlinks, syntax colouring, images, sounds, and so forth, are unavailable,
and the range of characters is very confined.

- The pdftex engine is the workhorse of modern TeX hackers: it is robust, fast,
and much better-featured. Inweb is able to use it to incorporate hyperlinks,
syntax colouring, and images. However, the range of fonts it offers is relatively
narrow.

- The xetex engine cannot do all that pdftex can do, but it can handle
right-to-left scripts, a breathtaking range of Unicode, and non-TeX fonts.
Inweb users are not advised to use xetex unless these extra abilities are
essential.

- The TeX community is currently developing forms of these engines which
incorporate Lua scripting. These are exciting times, but Inweb doesn't support
such engines yet. (In practice, they may work anyway, or may need only a
very little modification.)

To sum up, then: for almost all Inweb users wanting to create PDFs, the best
choice will be the `PDFLaTeX` pattern, or a pattern based on it.

Strictly speaking, Inweb does come with two alternatives to TeX, but neither
is likely to be useful except for testing purposes. Weaving `-as Plain` produces
a plain text file, but it lives up to its name. Weaving `-as TestingInweb`
produces a textual serialisation of Inweb's intermediate weave tree. This is
used for continuous integration testing of Inweb, but nobody else should use it.

## Installing a private pattern

The PDF version of the guide you are reading is woven with a pattern called
`GuidePDF`: this takes care of problems with some Unicode characters, gives
it a title page and table of contents, and changes its page layout and fonts.

None of that took very much work, but some familiarity with LaTeX's range of
packages and how they can be tweaked is helpful. The most approachable book
here is Stefan Kottwitz, _LaTeX Beginner's Guide_ (third edition 2026).

This is the file tree for the `guide` web with its new `GuidePDF` pattern added:

	guide
		Chapter 1
		Chapter 2
		...
		Inweb
			...
			Patterns
				GuidePDF
					Base
						character-fixes.latexpkg
						page.tex
						titling.tex
						type.tex
					GuidePDF.inweb

The pattern itself is of course just the `GuidePDF` directory and its contents.
This pattern is visible only to the `guide` web, being tucked away inside it.
With that in place:

``` ConsoleText
    $ inweb weave inweb/guide -as guidepdf
    weaving web "The Inweb Guide" (Markdown notation) as GuidePDF (based on PDFLaTeX)
	...
		[inweb/docs/guide/Complete.latex: 133pp 1412K]
```

What happens in the `...` part is that Inweb automatically runs the pdflatex
tool on the LaTeX source code it has produced in the weave: this tool then
produces a PDF, and Inweb checks the console output to make sure all went well.
The `GuidePDF.inweb` file is in fact mostly taken up with shell-scripting to
accomplish that onward conversion:

	Pattern "GuidePDF" {
		based on: PDFLaTeX
		commands
			if pdflatex -output-directory=WOVENPATH -interaction=scrollmode WOVEN.latex
				>WOVEN.console; then echo "no pdflatex errors"; else cat WOVEN.console; fi
			if pdflatex -output-directory=WOVENPATH -interaction=scrollmode WOVEN.latex
				>WOVEN.console; then echo "no pdflatex errors"; else cat WOVEN.console; fi
			PROCESS WOVEN.log
		end
	}

See //The Post-Weave// for more, but it's not really relevant here. Strictly
speaking there are just three lines of commands here, not five, as in this
listing: two rather long lines have been folded for legibility. The repetition
above might seem surprising: these commands run the output of Inweb (`WOVEN.latex`)
through the pdflatex tool _twice_, not once. That's quite a normal thing when
using LaTeX: it enables the contents page numbers and other cross-references
to come out correctly, and also gives LaTeX a second chance to redesign tables
and break them better across pages in light of its experience the first time.
The pdflatex tool is sufficiently fast that the time lost through this two-pass
typesetting is unimportant.

## Giving the Guide a title page and table of contents

By default, the `PDFLaTeX` pattern begins its PDF of a web with the heading
for Chapter 1, in effect jumping straight into the text: no title page, no
contents. We will change that by supplying a `titling.tex` file in our new
pattern `GuidePDF`. And here it is:

	\centerline{\reducedinchhighfont INWEB}
	\bigskip
	
	\inwebimagewidth{inweb/guide/Figures/weave.jpg}{8}
	
	\bigskip
	\centerline{\sectiontitletext{Guide to Inweb v[[Version Number]]}}
	
	\thispagestyle{empty}
	\vskip 0.5in
	\bodytextspacing
	\markboth{Contents}{Contents}
	
	[[Repeat Chapter]]
	\inwebcontentsc{[[Chapter Title]]}{[[Chapter Link]]}
	
	[[Repeat Section]]
	\inwebcontentss{[[Section Title]]}{[[Section Link]]}
	
	[[End Repeat]]
	
	[[End Repeat]]
	
	\vfill\eject

This file is _collated_ into the weave, so that those items in double-square
brackets expand as needed (see //Collation//). The result is like so:

	\centerline{\reducedinchhighfont INWEB}
	\bigskip
	
	\inwebimagewidth{inweb/guide/Figures/weave.jpg}{8}
	
	\bigskip
	\centerline{\sectiontitletext{Guide to Inweb v9.0}}
	
	\thispagestyle{empty}
	\vskip 0.5in
	\bodytextspacing
	\markboth{Contents}{Contents}

	\inwebcontentsc{Chapter 1: Smaller Webs}{ch1}
	
	\inwebcontentss{Getting Started}{se1/gs}
	
	\inwebcontentss{Single-File Webs}{se1/sw}
	
	...
	
	\inwebcontentsc{Chapter 2: Larger Webs}{ch2}
	
	\inwebcontentss{Contents Pages}{se2/cp}
	
	...
	
	\vfill\eject

Just a few notes about the macros used here:

- The contents macros `\inwebcontentsc` and `\inwebcontentss` are defined for
  us in the `PDFLaTeX` pattern, even though they aren't used by it, so we
  inherit those definitions. They produce suitable hyperlinked lines in the
  table of contents.

- This line also uses an inherited macro, which places an image of a given
  width in centimeters:

      \inwebimagewidth{inweb/guide/Figures/weave.jpg}{8}

  This involves an explicit path to an image used on the title page: which
  will only work if that's the correct path, so it implicitly assumes we are
  running Inweb from the right current working directory. As this pattern is
  purely for our own use, it doesn't seem worth being clever — we can accept
  that restriction.

- The line `\markboth{Contents}{Contents}` sets the current left and right
  running heads to "Contents". This is good if the contents listing runs on
  to a second or third page (as indeed it does, for the Guide).

## Giving the Guide a bespoke page design

Next, we will also supply our own version of `page.tex` — made by taking the
one from the standard `LaTeX` pattern, and changing it as needed:

	% `page.tex`
	%
	% The page design we will use: paper size, margins, headers and footers.
	% See also `fonts.tex`.
	%
	\documentclass[a4paper,10pt]{book}
	%
	\usepackage[a4paper, inner=2cm, outer=2cm, top=2cm, bottom=3cm,
	bindingoffset=0cm]{geometry}
	%
	\usepackage{fancyhdr}
	\fancyhf{}
	\fancyhead[R]{\rightmark}
	\fancyfoot{\hfill\thepage}
	\pagestyle{fancy}
	%
	\usepackage[T1]{fontenc}
	\usepackage{newpxtext}
	\usepackage{newpxmath}
	%
	\usepackage[onehalfspacing]{setspace}

This incorporates four changes, in fact:

- There are wider left and right margin settings in the options supplied to
  the `geometry` package, which manages the page shape.

- The header and footer are simpler than the defaults. The defaults are:

      \fancyhead[LE]{\thepage\quad\leftmark}
      \fancyhead[RO]{\rightmark\quad\thepage}
      \fancyfoot[LE,RO]{}

  which place the page numbers at the top, not the bottom, and which make
  the left and right pages mirrors of each other, with the running head always
  on the outside. This change isn't really either better or worse, but at least
  demonstrates how to make a change.

- Where the default would be `\usepackage{lmodern}` — giving us the Latin Modern
  family of fonts, essentially a modernised and expanded version of TeX's
  traditional Computer Modern Roman font — we have instead used the `newpxtext`
  and `newpxmath` packages, which give the guide a Palatino-like font, and its
  corresponding mathematics font.

- The `setspace` package has been used to change the "leading" (the distance
  between adjacent baselines of type) to 1.5 times normal (`onehalfspacing` means
  one-and-a-half, not half), which loosens the text lines from their rather tight
  defaults. That's good for the Guide, because it's a long prose document rather
  than being a program.

We also modify the standard `type.tex` file. This contains measurements of
the type variations used in our document: for example, how much smaller the
endnotes should be as compared with the body text. The only change made by
the Guide is to replace:

	\def\chaptertitletext#1{\textsf{\Huge #1}}
	\def\sectiontitletext#1{\textsf{\huge #1}}

with:

	\def\chaptertitletext#1{\Huge #1}
	\def\sectiontitletext#1{\huge #1}

In other words, the main chapter and section headings remain the same size,
but are no longer sans serif (this being what the LaTeX macro `\textsf` does).
In Palatino, serifs look better, or so the author thinks.

## Dealing with Unicode characters

Despite a naïve sort of élan, and a soupçon of accented letters, this Guide is
mostly English prose with letters found on any typewriter. Still, there are a
few fruity Unicode characters, outside of the normal ISO Latin-1 range needed
by most west European languages.

We need to deal with that issue, because otherwise the weave will throw errors.
Some TeX tools react to missing characters with mere warnings, or even silently
accept them but leave gaps in the output: but pdflatex does report those gaps,
and Inweb auto-detects the reports it gives.

We will deal with this issue by providing a file we'll call `character-fixes.latexpkg`.
Files with the `.latexpkg` file extension are collated into the LaTeX output
at a suitable point to use further packages which might be needed, i.e., after
the document class has been declared, but before the document has been opened.

The first thing is to give LaTeX better ability to read a UTF-8 encoded source
file, which is what Inweb has generated for it:

	\usepackage[utf8]{inputenc}

That means LaTeX can at least read the exotic characters, but they will not be
able to be printed in the PDF, because the Palatino font doesn't have them.
For example, we needed the letter π, and an angle sign 📐, and a sort of
space marker ⏑: none of those exist in Palatino.

Since there are relatively few of these cases, we will supply workarounds
for each one, using the LaTeX package `newunicodechar`. For example:

	\usepackage{newunicodechar}
	\newunicodechar{📐}{\ensuremath{\angle}}
	\newunicodechar{π}{\ensuremath{\pi}}
	\newunicodechar{⏑}{\leavevmode\hbox{\tt\char`\ }}

(The actual file contains about 40 of those workarounds.) The idea is that
every time LaTeX reads the character 📐, it should behave as if `\ensuremath{\angle}`
had been there instead. What this does is to enter math mode (if we were not
already in it), and then run the `\angle` macro, which typesets an angle sign.
Similarly, text like

	The Babylonians calculated π as $25/8$, which is out by about 1%.

is read as if it were

	The Babylonians calculated $\pi$ as $25/8$, which is out by about 1%.

And so on. It can require some ingenuity to find good LaTeX imitations of
the glyphs required: but see //https://texdoc.org/serve/symbols/0//, Scott
Pakin's formidable _The Comprehensive LaTeX Symbol List_. (Its index is quite
a sight.)

This sort of workaround wouldn't make sense for more hybrid texts,
where it would be better to use other LaTeX fonts and packages: but that goes
beyond the scope here. The ultimate recourse would be to use `XeLaTeX` and
suitable fonts, which can do practically anything with text.
