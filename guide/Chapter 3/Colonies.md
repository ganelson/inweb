# Colonies

A _colony_ is a collection of related webs called _members_, and gets its
name because social spiders, in so far as there are any, merge their webs into
what are called colonies.

Colony is the largest-scale structure supported by Inweb, and colonies can in
principle grow quite large. At time of writing, the main colony for the Inform
compiler has 59 members. But they can be useful with as few as two members,
and sometimes even a single web can benefit from being the only member of its
own diminutive colony.

Creating a colony is very easy. For example, suppose we wanted our `smorgasbord`
example web to start a colony. It would be enough to create a file called
`colony.inweb`, placed alongside `smorgasbord`, with the contents:

	Colony {
		member: "smorgasbord"
	}

But for the sake of a more interesting example, suppose we have written two
programs called `front-office` and `back-office`, which each share a library of
code called `inventory-module` (also a web). These will all live inside a
directory called `retail`. So, we create a file `colony.inweb`, also inside
`retail`, with the following contents:

	Colony {
		member: "front"     at "front-office"
		member: "back"      at "back-office.py.md"
		member: "inventory" at "inventory-module"
	}

So at this point, assuming `retail` is the current working directory:

	$ ls
	back-office.py.md   colony.inweb    front-office    inventory-module

## Member names

Each member has a _name_. These names can be used as a shorthand when typing
commands. For example:

	$ inweb inspect ::back
	web "The Back Office" (Python program in MarkdownCode notation): 13 paragraphs : 248 lines

Here `inweb inspect ::back` achieved the same result as `inweb inspect back-office.py.md`.
And in general, `COLONY::MEMBER` can be used on the Inweb command line to mean
the web which is the member named `MEMBER` of the colony `COLONY`. If we don't
specify `COLONY`, it's taken to be the colony file in the current working directory,
which is why `::back` works from inside `retail`. If we stepped up one level:

	$ cd ..
	$ ls
	retail
	$ inweb inspect retail::back
	web "The Back Office" (Python program in MarkdownCode notation): 13 paragraphs : 248 lines

The `COLONY` part of `COLONY::MEMBER` can either give the filename of the colony
file, or can just give a directory name, in which case Inweb looks for a file
called `colony.inweb` in that directory. (It's because of this convention
that it's generally a good idea to call a colony file `colony.inweb`, and since
it never really makes sense to have two colonies trying to share the same
directory, this is no hardship.)

## Member locations

As lines like this demonstrate, the _name_ of a member can be different from
its _location_:

		member: "front"     at "front-office"

Thus the member `front` is a web located in the directory `front-office`,
which is in the same directory as `colony.inweb`. But in practice, name and
location often coincide, and then `at ...` can be omitted. For example,

		member: "smorgasbord"

is equivalent to writing

		member: "smorgasbord" at "smorgasbord"

The location following `at` is in fact a pathname or filename relative to the
directory holding the colony file, i.e., for us, relative to `retail`. There's
nothing to stop this path leading us outside and some distance away:

		member: "distant" at "../around/the/houses/distant.c.md"

## Placing a colony inside a web directory

Here's another perhaps surprising use of `at`. Simplifying the truth a little,
Inweb itself is a web called `inweb` which contains two subsidiary modules,
`foundation-module` and `literate-module`. Those actually sit inside `inweb`
as subdirectories of it. As well as being a web, `inweb` is a git repository.
We want its colony file to be included in that repository, so it's not
convenient to place this _outside_ `inweb`: if we did, it couldn't be added
to the repository with `git add`. So what we actually do is to place the
colony file inside `inweb`. That gives a directory structure like so:

	inweb
		colony.inweb
		Contents.w
		...
		foundation-module
			Contents.w
			...
		literate-module
			Contents.w
			...

And the colony file is then written like this:

		member: "inweb"      at ""
		member: "foundation" at "foundation-module"
		member: "literate"   at "literate-module"

Note the `at ""` for `inweb` itself: because relative to the location of
`colony.inweb`, you're already there. (This could also have been written `"."`,
meaning "the current directory", but there's no need to.)

## Tangling and weaving an entire colony

Most of Inweb's commands are meant to be applied to webs rather than colonies,
though `inweb weave` and `inweb tangle` can be applied to either. Thus
`inweb weave COLONY` weaves each member of the colony in turn, and similarly
for tangling. If our current working directory contains a `colony.inweb` file,
then we don't even need to indicate what `COLONY` we mean: Inweb will see it
automatically. Thus, in the above `retail` example, we can tangle:

	$ inweb tangle
	(Tangle 1 of 3: front)
	tangling web "The Front Office" (Python program in MarkdownCode notation) to file 'front-office/Tangled/The Front Office.py'
	
	(Tangle 2 of 3: back)
	tangling web "The Back Office" (Python program in MarkdownCode notation) to file 'back-office.py'
	
	(Tangle 3 of 3: inventory)
	tangling web "inventory-module" (Python program in MarkdownCode notation) to file 'inventory-module/Tangled/inventory-module.py'

When we weave, it's clear at once that a skeleton of directories will be needed
in order to hold all the HTML generated:

	$ inweb weave
	the weave would require these 5 directories to exist:
		docs
		docs/docs-assets
		docs/front
		docs/back
		docs/inventory
	inweb: fatal error: giving up: either make them by hand, or run again with -creating set

Note a subtle change here: once Inweb thinks in terms of a colony, it defaults
to weaving output into a directory called `docs`. (This is to follow the convention
used by GitHub when serving web pages associated with a repository.) We can 
change that, of course:

	inweb weave -to my/funny/area
	the weave would require these 7 directories to exist:
		my
		my/funny
		my/funny/area
		my/funny/area/docs-assets
		my/funny/area/front
		my/funny/area/back
		my/funny/area/inventory
	inweb: fatal error: giving up: either make them by hand, or run again with -creating set

But on second thoughts, `docs` wasn't such a bad idea, so:

	$ inweb weave -creating
	(created directory 'docs')
	(created directory 'docs/docs-assets')
	(created directory 'docs/front')
	(created directory 'docs/back')
	(created directory 'docs/inventory')
	(Weave 1 of 3: front)
	weaving web "The Front Office" (Python program in MarkdownCode notation) as GitHubPages (based on HTML)
		[docs/front/invh.html] [sales] [promo] 
		[index] 
		11 files copied to: docs/docs-assets

...and so on.

## External members

So far, all of the members of the `retail` colony have been webs defined in
that colony. But now suppose those webs need to import code from a module
defined in another colony altogether.

This is not as remote an idea as it sounds: all InC programs import code from
the `foundation` module defined in the Inweb colony. The Intest program is in
just that situation, and its colony deals with this by defining:

	Colony {
		default: pattern "GitHubPages" breadcrumbs "Home: //overview//"
	
		member:   "overview"   to "index.html" breadcrumbs ""
		member:   "intest"     at "" to "intest"
		member:   "arch"       at "arch-module" to "arch-module"
		external: "inweb"      at "../inweb"
		external: "foundation" at "../inweb/foundation-module"
	
		...
	}

Note the two `external:` declarations, which are just like `member:` ones,
but tell Inweb that these members are remote from us. (Their file paths lead
outside the Intest repository and assume that Intest and Inweb are sitting
next to each other.) `inweb` and `foundation` are like overseas corresponding
members of some society, who are not expected to attend every meeting.

In particular, `inweb weave` applied to the Intest colony does not weave them,
because it's assumed they have already been woven in their colony. On the
other hand, colony links like `//foundation//` do reach them safely.

## Other resources in colony files

So far, we've placed three different sorts of declaration inside our colony
declaration: `Page` (text of a single-section web), `Web` (contents for a multi-section web),
and `Navigation` (set of sidebar links).

We can also write `Conventions`, like so:
	
	Colony {
		...
		
		Conventions {
			sections are numbered sequentially
		}
	}

This would apply the `sections are numbered sequentially` rule to all the webs
in the colony (unless they individually override that: see //Conventions//).

Then, too, we can place `Language` and `Notation` declarations inside a colony,
and that makes them available to all webs in that colony. For example, we could
tell Inweb about the Rust language, and then any web in the colony could use Rust
if it wanted to. These declarations override any others built in to Inweb, so
we could also redefine the C language (say) with our own redesigned version,
and then members of the colony would use that declaration, not the built-in one.

These declarations might become a little lengthy, and deserve to be stored
elsewhere, rather than in the colony file itself. If so, adding this line:

	Colony {
		...
		using: "my_declarations.inweb"
		...
	}

would tell Inweb to read declarations from the file `my_declarations.inweb`,
and make anything inside (conventions, languages, notations, navigations, and
such) available to the colony's members. There can be any number of `using:`
lines in a colony declaration; it will read each file named. The file paths
are, as usual, relative to the directory holding the colony file.
