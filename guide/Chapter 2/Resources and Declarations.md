# Resources and Declarations

Inweb is highly customisable, and this means there must be ways to supply
it with new conventions about notations, programming languages, and so on.
Those conventions need to be written down in files, and that in turn means
that Inweb must be able to read a variety of files with different meanings,
not just webs.

Since much of the rest of this guide will be about creating new resources,
this seems a good point to set out some ground rules for declaring them.

## Inspecting resources

By convention, files which are meaningful to Inweb commands but which are
_not_ webs are given the filename extension `.inweb`. For example, if you were
to create a custom programming language definition, say for the language
Racket, you might call this `Racket.inweb`. And then:

    $ inweb inspect Racket.inweb
    Language "Racket" at Racket.inweb, line 1

...and then some further output, which need not detain us here. In general,
`inweb inspect` can be pointed at any file which Inweb understands, and will
say what it appears to be.

## Declarations

The general rule is that all Inweb files are a series of one or more _declarations_
of _resources_, like this one:

    Language "Racket" {
        ...
    }

Here the _type_ of the resource is `Language`, and the _name_ of the particular
one created is `Racket`. (Names are optional in some cases: types never are.)
Details about it then appear in the `...` position above. A file can contain
multiple resources:

    Language "Racket" {
        ...
    }

    Notation "Homebrew" {
        ...
    }

Such a file is called a "miscellany", even if all of its declarations have the
same type as each other (unlike in this case).

Resources can even, in some cases, be nested:

    Colony {
        ...

        Language "Racket" {
            ...
        }        
    }

This is not a miscellany because the file contains just one declaration,
a `Colony`. That has a second declaration, a `Language`, inside of it, but
this is a private resource of its own, not visible from the outside.

Outside of these declarations, comments can be included as lines which
begin with `//`. For example, in:

    // Something of a stopgap for now
    Language "APL" { 
        ...
    }

the line `// Something of a stopgap for now` is simply discarded. Otherwise,
nothing can appear outside of declarations except for white space.

The rules on indentation and placing of the braces are strictly enforced here.
This, for example, produces an error:

    Language "APL" {  ...  }

as does:

    Language "APL" {
        ...
        }

and so does:

    Language "APL" {
            ...A...
        ...B...
            ...C...
    }

The material inside the braces should be indented by some amount (counting
tab stops as four spaces), and the indentation used on the first line should
be the minimum indentation used throughout. It's the `...B...` line which
causes the problem in that last example.

## Webs are also resources

If all Inweb files are supposed to be declarations like the ones above, then,
why haven't the webs seen so far followed that shape?

The answer is that if a file is _not_ a declaration (or a miscellany of
multiple declarations), then Inweb decides what it is by looking at the
filename rather than the contents.

* If its filename is `colony.inweb`, it is read as the body of a `Colony`;
* If its filename is `Contents.w` or `Contents.inweb` or ends `.inwebc`, it is
  read as the body of a `Web`;
* And otherwise it is read as the body of a `Page`.

A `Web` declaration is a contents page. So, for example, a contents page
`Contents.inweb` like so:

	Title: Sorting Smorgasbord
	Author: Various Artists
	Notation: MarkdownCode
	Language: Python
	Version Number: 3.0.1

	Sections
		Counting Sort.md
		Quick Sort.md

is read exactly as if it had been declared thus:

	Web {
		Title: Sorting Smorgasbord
		Author: Various Artists
		Notation: MarkdownCode
		Language: Python
		Version Number: 3.0.1
	
		Sections
			Counting Sort.md
			Quick Sort.md
	}

Properly speaking, Inweb always reads filenames case insensitively, so
`Colony.INWEB` would be equivalent to `colony.inweb`. Similarly, trailing spaces
after a filename extension are ignored, so `colony.inweb ` also matches.

The difference between `Web` and `Page` is that the former is used for large
webs, and contains a contents listing (and possibly some book data), whereas
the latter is used for a single-file web, and contains the actual text. But
both create webs. A `Colony` is a whole collection of webs, and we'll come
to that later on.

For example, this tiny single-file web:

    # Pi
    
    π is not part of the core of Python, but is defined in the `math` module:
    
        import math
        print (math.pi)

is read exactly as if it had been declared like this:

    Page {
        # Pi
        
        π is not part of the core of Python, but is defined in the `math` module:
        
            import math
            print (math.pi)
    }

In practice, it would be cumbersome and annoying to have to put webs inside
these declaration braces, and this guide expects that users will never bother
with them except when declaring a `Web` or `Page` inside a `Colony`.

## Complete table of resource types

type          | defines                                         | can contain
------------- | ----------------------------------------------- | ----------------------------------------
`Colony`      | collection of related webs                      | anything but a `Colony` or `Pattern`
`Web`         | contents list and book data for a large web     | anything but a `Colony`, `Web`, `Page` or `Pattern`
`Page`        | text of a single-page web with no contents list | nothing
`Notation`    | notation for writing webs                       | only a `Conventions`
`Language`    | details of a programming language               | only a `Conventions`
`Navigation`  | navigation menu used in woven websites          | nothing
`Pattern`     | generic design used in woven websites           | nothing
`Conventions` | preference settings to be applied to webs       | nothing

In addition, the type `Miscellany` is used internally to represent a ragbag
of declarations all in the same file as each other, but it cannot be declared
explicitly. A `Miscellany` can contain anything except another `Miscellany`.
