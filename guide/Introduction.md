# Introduction

## Installation

Inweb is a free and open-source tool for literate programming. Besides the basic tasks
of tangling and weaving, it plays nicely with GitHub, offers highly customisable
notation, and provides convenient organisation tools. Above all, it scales easily
from simple one-page programs in a single file up to extensive families of large and
inter-related programs and libraries.

Since the 1980s, many small LP tools have been written, but few have been more than
proofs of concept. Inweb is far from perfect, but it is by contrast production
software, and has been used daily since 2008 to manage the 300,000-line code base
of the Inform 7 programming language, on Linux, MacOS, Windows, and numerous other
operating systems. This has forced it to engage with many practical issues.

For all that, Inweb is a simple tool at heart, which scales down as well as up.
This manual aims to be a concise but complete guide to using it, and you need read
very little before getting started.

Installation instructions are elsewhere, at [the project's GitHub page](https://github.com/ganelson/inweb).
The software is provided as a command-line tool, and if your installation has
been successful, you should be able to type Inweb to use it:

    $ inweb
    inweb: a tool for literate programming. See 'inweb help' for more.

In this manual, the shell prompt is shown as `$`, so the command typed there was
`inweb`, while the subsequent lines were printed by the program in reply.

## Subcommands and help

Inweb has migrated to the modern style of command-line interface popularised by
other multi-function tools such as `git` and `docker`: it is a tool-box rather
than a screwdriver, and has a number of different "commands", all related to
dealing with webs in some way, but performing essentially different functions.
All commands are written in the form `inweb COMMAND`, followed by any options
or parameters needed by the command in question.

`inweb help` is just such a command. It does nothing except to print out a
brief reminder of how to use Inweb at the command line. For every other
command, for example `inweb tangle`, further help is also available:

    $ inweb help tangle
    inweb tangle

    Usage: inweb tangle [WEB]

    Tangling is one of the two fundamental operations of literate programming
    (for the other, see 'inweb help weave'). It strips out the markup in a web,

... and so on: about a screenful is printed.

## Switches

A command-line switch is an embellishment to a command which slightly changes
what it does. It's written with an initial `-`.

Switches should only appear after the command word, and different commands
support different switches. For example, the `inweb tangle` command has the
optional switch `-to FILE`, which changes where the tangled program is written to.
Without the switch:

    $ inweb tangle countsort.py.md
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'countsort.py'

And with it:

    $ inweb tangle countsort.py.md -to unexpected.py
    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'unexpected.py'

This overrode the default filename `countsort.py`, which would otherwise have been
used, and it's typical of how switches change only the details of what is done.
There is no switch which makes `inweb tangle` do anything other than perform a
tangle.

A handful of Inweb switches can be used with _any_ command, but most are arcane
and can be ignored. (See `inweb help` for a complete list.) Two which are sometimes
useful, though, control the amount of console output produced by Inweb.

For the most part, replies like:

    tangling web "Counting Sort" (Python program in MarkdownCode notation) to file 'countsort.py'

are a helpful reassurance. But users who prefer the customary Unix silence can add `-silent`:

    $ inweb tangle countsort.py.md -silent

in which case nothing at all will be printed unless some error occurs. There is
also an opposite extreme, `-verbose`, which gives a running narrative of what
Inweb believes it is doing.

Note that `-silent` does not hush commands whose whole purpose is to print something:
for example, `inweb help` and `inweb inspect`. There is no meaningful way to
provide `inweb help` silently.

## Lexicon

Like any other domain of computer science, LP has its own terms of art, and a
few basic terms are worth defining here. Mostly people agree about these
definitions, but be warned that some LP tools use different words for what
Inweb calls a "section" and a "paragraph". (Confusingly, some use "section"
or "module" for what we call "paragraph".)

* _Literate programming_ is writing computer programs as essays which explain
the workings and motivation of the code being exhibited.

* A _literate program_ is also called a _web_, and for conciseness this manual
will usually use the shorter term. The word was coined around 1980, and does
not refer to the World Wide Web, which did not then exist.

* Webs vary in size from tens of lines to hundreds of thousands. Larger webs are
organised like books, and are divided into _chapters_ and _sections_ with a
_contents page_, in which case they will be stored in many source files. But
smaller essays have no need for any of that, and Inweb handles them more simply.
They are called _single-file webs_, because they are stored as a single source file each.

* Each section is divided internally into _paragraphs_. Each paragraph can contain
one snippet of code from the program (sometimes called a _holon_), along with some
discussion of it, but some paragraphs consist solely of discussion, and some
simply present code without explanation. Some paragraphs open with a _subheading_,
usually when there is a change of subject.

* _Notation_ is used to _mark up_ a web, showing which parts are explanation,
which parts are program, where the paragraph boundaries are, and so on. Inweb
supports multiple notations, and lets you create your own. The _notation_ for a
web is not the same thing as its _language_, which means the programming
language used by the code in it.

* _Tangling_ is the process of extracting the code from a web, so that it can
be compiled or interpreted. _Tangled output_ is not intended for humans to read,
and is ephemeral.

* _Weaving_ is the process of presenting the explanation and code in a web for
human eyes. Of course, the original files holding the web already do this, but
_woven output_ is intended to be prettier, and to look like a publication:
a document or a website.

* A _colony_ is a collection of inter-related webs, which are tangled independently
into different programs (perhaps in a variety of languages) but woven together
into a joint presentation. A small colony might contain only two or three webs:
for example, a program for some utility function, a configuration file for same,
and a manual. At time of writing, the Inform project colony has 66 webs.

* A _module_ is a web which presents a substantial suite of code but which does
not tangle to a complete program. It might be a major component of a large program,
or it might be a library of code intended to be used by multiple programs. For
example, Inweb is itself a web, consisting of its command line interface plus
two large modules, `foundation` and `literate`.
