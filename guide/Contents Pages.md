# Contents Pages

The examples so far have been of single-file webs, but it's impractical for
even a medium-sized program to be stuffed into a single section of code,
and all but impossible for a large one.

## Getting started

It's easy to make a multi-file web. Suppose the `Counting Sort` example used
earlier needed to become part of a larger program, trying out different sort
algorithms.

We begin by creating a new directory, which we'll call `smorgasbord`:
though not a requirement, giving a web its own private directory is tidy.
The web will have two _sections_, each in its own file: `Counting Sort.md` and
`Quick Sort.md`, which demonstrate different ways to sort data. The third and
final file making up the web is the _contents page_, which we will give the
filename `Contents.inweb`. It reads:

	Title: Sorting Smorgasbord
	Author: Various Artists
	Notation: MarkdownCode
	Language: Python
	Version Number: 3.0.1

	Sections
		Counting Sort
		Quick Sort

As can be seen, this starts with some basic metadata about the web. We saw
earlier that a single-file web has to imply its metadata by using its
title and filename: that's because it has no better way. A multi-file web
uses its contents page to spell out the details explicitly.

Inweb commands refer to a single-file web by giving its filename: hence
commands like `inweb inspect countsort.pl.md`, where `countsort.pl.md`
was the single file of a small web. When referring to a multi-file web,
we can _either_ give its contents page:

	$ inweb inspect smorgasbord/Contents.inweb

_or_, equivalently and more conveniently, just give the directory name:

	$ inweb inspect smorgasbord

Either way, the reply is:

	web "Sorting Smorgasbord" (Python program in MarkdownCode notation): 2 sections : 10 paragraphs : 139 lines
	
	Contents:
	abbrev | section       | lines
	------ | ------------- | -----
	cnsr   | Counting Sort | 77   
	qcsr   | Quick Sort    | 62

New output has appeared here: a contents rundown. The `abbrev` column is because
Inweb sometimes needs a way to refer to sections briefly but unambiguously: it
chooses abbreviations such that no two sections can ever have the same.

## Weaving and tangling

Weaving and tangling work much as they do for single-file webs, except that
the output is written, by default, to different places:

* `inweb tangle countsort.pl.md` tangles to `countsort.pl`.
* `inweb tangle smorgasbord` tangles to `smorgasbord/Tangled/Sorting Smorgasbord.pl`,
  creating the subdirectory `Tangled` of `smorgasbord` if it doesn't already exist.
* `inweb weave countsort.pl.md` weaves to `countsort.html` with a slew of CSS
  files in the directory `countsort-assets`.
* `inweb weave smorgasbord` weaves a website into `smorgasbord/Woven`, whose CSS
  and similar files are in `smorgasbord/Woven/assets`, and those subdirectories
  are created if they do not already exist.

So, for example:

	$ inweb weave smorgasbord  
	weaving web "Sorting Smorgasbord" (Python program in MarkdownCode notation) as HTML
    [smorgasbord/Woven/cnsr.html] [qcsr] 
    [index] 
    10 files copied to: smorgasbord/Woven/assets

Note the reappearance of the two abbreviations mentioned above: each section has
become an HTML file called `cnsr.html` or `qcsr.html`, rather than the more
cumbersome `Counting Sort.html`. In addition, the contents have become `index.html`,
the home page for the mini-website.

Inweb is just a little more cautious about creating directories on behalf of the
user if the command-line switch `-to` is used, but it's not sure what that refers
to. For example:

	$ inweb weave smorgasbord -to my_website
	weaving web "Sorting Smorgasbord" (Python program in MarkdownCode notation) as HTML
	inweb: fatal error: this is neither an existing file nor directory: my_website

	$ mkdir my_website
	
	$ inweb weave smorgasbord -to my_website
	weaving web "Sorting Smorgasbord" (Python program in MarkdownCode notation) as HTML
		[my_website/cnsr.html] [qcsr] 
		[index] 
		10 files copied to: my_website/assets

## Contents entries

Every section of a web has to have its own individual entry in the contents
listing for a web, and every section has to be stored in its own individual file.

An entry in the contents listing of a web gives Inweb enough information to
know both the title of the section, and the location of the file. When Inweb
reads an entry like this:

		Counting Sort

it takes the title to be `Counting Sort`. As to the location, Inweb looks
for `smorgasbord/Counting Sort`; it doesn't find that file, so it tries
`smorgasbord/Counting Sort.md` instead; and that does exist, so all is well.
(Inweb would also have tried the filename extensions `.w` or `.i6t`, though
the latter is now deprecated.) If that had failed too, Inweb would next
have looked to see if the web had a `Sections` subdirectory, because some
medium-sized webs like to store their section files in a subdirectory called
`Sections`. So in fact it tries quite a few possibilities:

	Counting Sort
	Counting Sort.md
	Counting Sort.w
	Counting Sort.i6t
	Sections/Counting Sort
	Sections/Counting Sort.md
	Sections/Counting Sort.w
	Sections/Counting Sort.i6t

and takes the first match, that is, the first which exists as a file.

Section names must not contain the characters `.`, `\`, `"`, or `/`. So, in
particular, if Inweb reads the contents entry

		../external/miscellaneous/Mixed Bag.md

then it knows that the title of the section must just be `Mixed Bag`. The
location of the file is always taken to be _relative to_ the directory holding
the contents file. So, here, it would be `external/miscellaneous/Mixed Bag.md`,
assuming that `smorgasbord` is in our current working directory: the `..` part
of the file path stepped up a directory, getting out of `smorgasbord` altogether.

It is usually a good idea for a section called, say, "Counting Sort", to have
a filename consisting of its title plus an extension, as in `Counting Sort.md`.
But there are times when this might be tricky. For example, we might want to
avoid awkward Unicode characters in the filename of a section called "Runes 𐲦‎𐲧‎𐲨‎𐲩 and 𐲌𐲏",
if we don't trust our computer's file system to handle Old Hungarian properly.
For those, we could write:

		"Runes 𐲦‎𐲧‎𐲨‎𐲩 and 𐲌𐲏" at "Runes 1.md"

thus specifying the section title and location independently. Since section titles
cannot contain a `"` character, no ambiguity can arise.

Large webs will have enough sections to make it sensible to group them
together in what are called _chapters_. For example, this is from a contents
page for a program called Inblorb:

	Chapter 1: Blurbs
	"A little infrastructure, but basically, parsing of our instructions."
		Basics
		Main
		Blorb Errors
		Blurb Parser
	
	Chapter 2: Blorbs
	"Our primary purpose is to write a blorb file, and all else is a side-show."
		Blorb Writer
	
	Chapter 3: Other Material
	"Although non-blorb release material is a side-show, it's a divertingly varied one."
		Releaser
		Solution Deviser
		Links and Auxiliary Files
		Placeholders
		Templates
		Website Maker
		Base64

Whereas our previous simple contents page had just one subheading, `Sections`:

	Sections
		Counting Sort
		Quick Sort

...this larger example has three, `Chapter 1: Blurbs`, `Chapter 2: Blorbs`,
and `Chapter 3: Other Material`. In each case the chapter is followed by a line
of text in quotation marks `"`, briefly outlining the contents: this is optional,
though. The rules for looking up the section files are the same as before,
except that instead of looking in `Sections`, Inweb will look in `Chapter 1`,
`Chapter 2` or `Chapter 3`, as appropriate. For example, `Solution Deviser`
turns out to refer to the file at `inblorb/Chapter 3/Solution Deviser.w`.

The list of legal chapter-like headings is quite restrictive:

	Preliminaries
	Manual
	Chapter <positive whole number>: <title>
	Appendix <letter A to L>: <title>

And that's all. Note that if chapters are used at all, then the subheading
`Sections` can't be used: a web is either chaptered or it is not. Inspecting
Inblorb, we now see:

	abbrev | chapter   | section                   | lines
	------ | --------- | ------------------------- | -----
	1/bsc  | Chapter 1 | Basics                    | 55   
	1/mn   | Chapter 1 | Main                      | 295  
	1/be   | Chapter 1 | Blorb Errors              | 115  
	1/bp   | Chapter 1 | Blurb Parser              | 405  
	2/bw   | Chapter 2 | Blorb Writer              | 591  
	3/rls  | Chapter 3 | Releaser                  | 616  
	3/sd   | Chapter 3 | Solution Deviser          | 421  
	3/laaf | Chapter 3 | Links and Auxiliary Files | 165  
	3/plc  | Chapter 3 | Placeholders              | 212  
	3/tmp  | Chapter 3 | Templates                 | 123  
	3/wm   | Chapter 3 | Website Maker             | 1031 
	3/bs6  | Chapter 3 | Base64                    | 80 

Note that the abbreviations now have a numerical part: `3/sd` abbreviates
`Solution Deviser` from `Chapter 3`. The chapter itself has an abbreviation,
which is just `3`. For `Preliminaries` or `Manual`, the prefix would be `P`
or `M`, and for `Appendix A` to `Appendix L` (the most allowed), it would be
`A` to `L`. As noted above, these abbreviations are used when weaving a website:
but since the `/` can't be used in a filename, it's replaced by a `-`. So the
HTML file generated for `Solution Deviser` is `3-sd.html`.

The special abbreviation `0` can be used to refer to the entire web, should
this ever be necessary. There is never a Chapter 0.

## Modules

One goal of Inweb is to scale from tiny to enormous webs without too
much effort. A project can begin as a single-file web, grow to the point
where it needs to be broken up into multiple sections and given a contents
page, and grow further until the sections need to be divided up into chapters.

But what then? The Inform compiler has 793 sections, divided into 146 chapters.
No single book should have 146 chapters.

The answer is that Inweb supports a still larger-scale grouping, _module_.
A module is just a web, but one which is not tangled independently: it doesn't
make a stand-alone program, it provides a component for other webs to use.
Inform is therefore broken up into 27 different webs, one of which is `inform7`,
the web itself, and the other 26 of which are its modules. So the average
module has about six chapters, and the average chapter has about six sections.

For a more modest example, suppose we want `smorgasbord` to use a module called
`random-arrays` which might, say, provide random lists of numbers to try
sorting. The contents page might then read:

	Title: Sorting Smorgasbord
	Author: Various Artists
	Notation: MarkdownCode
	Language: Python
	Version Number: 3.0.1

	Import: random-arrays

	Sections
		Counting Sort
		Quick Sort

The line `Import: random-arrays` says that this second web provides a block
of material forming part of the program. This second web is exactly like a
regular web, though it has to be a multi-file one with a contents page, except
that its directory name must end `-module`. In this case, then, Inweb looks
for a directory called `random-arrays-module`.

How does Inweb know where to find `random-arrays-module`? It tries three
locations in turn when looking for a module:

- the inside of the web making the import, that is, its own directory;
- the outside of that web, that is, the directory containing it;
- Inweb's own interior, wherever that is on the user's computer, but
  only if the module asked for was called `foundation` or `literate`.

In this case, then, if `smorgasbord` is inside the directory `programs`,
then Inweb would first try `programs/smorgasbord/random-arrays-module`, and
then, if that failed, `programs/random-arrays-module`.

And the third possibility does not arise. Inweb contains just two modules,
`foundation` and `literate`, and both are written in a dialect of C called InC.
One is a general-purpose library wrapping and considerably extending the C
standard library, and the other contains literate-programming functions which
are essentially the whole Inweb engine. (Inweb itself is really just a
command-line interface to this module.)

Two notes for power users of this feature:

* The import location can be a path, as in `Import: services/words`. This
  is then applied relative to the locations given above.

* Modules can themselves import other modules, and so on: they form a dependency
  tree. But less is more. It doesn't seem to be very helpful to have elaborate
  import pathways.
