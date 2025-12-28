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

## Mapping a colony

A command which makes sense only for colonies is `inweb map`, which prints out
a sitemap of the website produced when all the webs in the colony have been woven.
Here's what we get:

	$ inweb map
	colony declared in the file: colony.inweb
	weave output to the directory: docs
	
	member    | type | source location  
	--------- | ---- | -----------------
	front     | book | front-office     
	inventory | book | inventory-module 
	back      | page | back-office.py.md

Members are divided into "books", webs with multiple sections, and "pages",
single-file webs with no contents page.

Note that the source location column here shows the location with respect
to your current working directory, so if the CWD is not where the colony file
is, it won't be the same as the `at` fields in the declaration.

Then we get some statistics:

	member    | notation     | language | chapters | sections
	--------- | ------------ | -------- | -------- | --------
	front     | MarkdownCode | Python   | 1        | 2       
	*back     | MarkdownCode | Python   | 1        | 1       
	inventory | MarkdownCode | Python   | 1        | 2       
	--------- | ------------ | -------- | -------- | --------
	total: 3  | --           | --       | 3        | 5       

Note that this doesn't total up lines or paragraphs. That's because to do
so would mean reading in the complete text of all the members of a colony, and
for a large colony of substantial programs, this takes several seconds. But
Inweb will dutifully do so if asked for `inweb map -fuller`. For example,
here's the fuller stats for the colony of the program Intest:

	member     | notation     | language | modules | chapters | sections   | paragraphs   | lines         
	---------- | ------------ | -------- | ------- | -------- | ---------- | ------------ | --------------
	*overview  | InwebClassic | None     | --      | 1        | 1          | 0            | 16            
	intest     | InwebClassic | InC      | 2       | 6 (+ 11) | 21 (+ 55)  | 376 (+ 1053) | 8097 (+ 29997)
	arch       | InwebClassic | InC      | --      | 3        | 5          | 62           | 1164          
	inweb      | InwebClassic | InC      | 2       | 3 (+ 15) | 18 (+ 100) | 192 (+ 2037) | 4642 (+ 51738)
	foundation | InwebClassic | InC      | --      | 8        | 50         | 991          | 28833         
	---------- | ------------ | -------- | ------- | -------- | ---------- | ------------ | --------------
	total: 5   | --           | --       | --      | 21       | 95         | 1621         | 42752         

The additions in brackets are to allow for the fact that, by using modules,
some webs are sharing code. Numbers outside brackets are the unique contribution
made by the web in question, and numbers in brackets are those imported. So, for
example, `intest` itself has only six chapters of 21 sections of code, but it's
importing 11 more chapters of 55 sections from the 2 modules it imports.

Returning to our `retail` example, we then get the site map itself:

	path         | leaf             | link-name | nav | crumbs | pattern
	------------ | ---------------- | --------- | --- | ------ | -------
	back/        | back-office.html | back      | --  |        | HTML   
	docs-assets/ | --               | --        | --  | --     | --     
	front/       | index.html       | front     | --  |        | HTML   
	inventory/   | index.html       | inventory | --  |        | HTML   

This is meant to give a picture of the website which would emerge if each
member of the colony were woven in an HTML format. The "path" and "leaf"
combined give URLs within this website: so, if all this content were uploaded
to a server providing `arachnidretail.com`, then the front office program's
home page would be:

	arachnidretail.com/front/index.html

And assets like images and CSS files would go into `docs-assets`. This last
table is, again, only a top-level view: `inweb map -fuller` gives a more
completist view, showing where all the individual sections of code go.

The "nav", "crumbs" and "pattern" columns have to do with how the web in
question is rendered: more on this below.

## Cross-colony links

One benefit of colonies is that they enable webs to provide links to each
other, and indeed to each others' internals. For example, `front` might include
this:

	This program provides the front end of a complete retail solution for
	spider enthusiasts. Combined with //back//, the back end, it provides
	robust support for the sale of coconut matting, misters, and arboreal

...and so on. The link `//back//` leads to the home page of the Back Office
program, because `back` was the `link-name` in the table above.	And in
fact links can be more detailed:

	Unlike //back: Initialisation//, we do not need to reclaim memory here.

This link is to the section called "Initialisation" in the `back` web. Note
that these links do not need to use URLs, or worry about exactly what
path gets from one page to the other: it's all handled automatically, and
if we rearrange the site map one day, all these links will remain unbroken.

## Rearranging the site map

Suppose we don't want this arrangement:

	path         | leaf             | link-name | nav | crumbs | pattern
	------------ | ---------------- | --------- | --- | ------ | -------
	back/        | back-office.html | back      | --  |        | HTML   
	docs-assets/ | --               | --        | --  | --     | --     
	front/       | index.html       | front     | --  |        | HTML   
	inventory/   | index.html       | inventory | --  |        | HTML   

It seems asymmetric, somehow, that the URL for `front` is `front/index.html`
whereas the one for `back` is `back/back-office.html`. This has happened
because, for the sake of example, we made `back` a single-section web, but
never mind why: the point is, it's not what we want.

We can fix this by changing the colony file:

	Colony {
		member: "front"     at "front-office"
		member: "back"      at "back-office.py.md" to "back/index.html"
		member: "inventory" at "inventory-module"
	}

Note the addition of `to "back/index.html"`. Like `at`, `to` is an optional
clause in a member declaration, which overrides where Inweb would otherwise
put the `back` web pages within our website. (Member declarations can include
a number of optional clauses, which can be given in any order after the
member name.)

## Simple landing pages and the like

Something the site map might remind us of is that there's no home page yet:
weaving these three webs does not create a page at `arachnidretail.com/index.html`.

We now have the means to make one. Clearly we need the text of this landing page
to be somewhere: in fact, it will be a web in its own right, albeit a very small
and simple one which contains only commentary, not a program. We could store that
in its own file, but for the sake of demonstration, we'll instead define it
_inside the Colony file_.

Colony declarations are like other Inweb declarations, in that they can declare
other Inweb resources inside themselves, and that's what we do here. (See
//Resources and Declarations// for the general rules.) Here goes:

	Colony {
		member: "landing" to "index.html"
		member: "front" at "front-office"
		member: "back" at "back-office.py.md" to "back/index.html"
		member: "inventory" at "inventory-module"
		
		Page "landing" {
			# Welcome to Arachnid Retail
			
			An elegant //front end -> front// combined with an industry-leading
			//back end -> back// make it effortless to cater to arachnophiles
			everywhere.
		}
	}

Firstly, note the new member, called `landing`. No need to say where it is `at`:
the source for it is right here in the colony declaration, and Inweb finds it
automatically. But the `to "index.html"` causes this source to generate a
page at the top level of the website called `index.html` (rather than
`landing/index.html`, which would have been the default).

The table of materials now looks like so:

	member    | type | source location          
	--------- | ---- | -------------------------
	front     | book | front-office             
	inventory | book | inventory-module         
	landing   | page | (material in Colony file)
	back      | page | back-office.py.md        

And here's our sitemap:

	path         | leaf       | link-name | nav | crumbs | pattern
	------------ | ---------- | --------- | --- | ------ | -------
				 | index.html | landing   | --  |        | HTML   
	back/        | index.html | back      | --  |        | HTML   
	docs-assets/ | --         | --        | --  | --     | --     
	front/       | index.html | front     | --  |        | HTML   
	inventory/   | index.html | inventory | --  |        | HTML   

It's even possible to define a multi-section web from inside a colony, and
this is occasionally useful to bunch together some files which were never
written as a web. For example, suppose we have some Markdown files holding
regulations:

	Colony {
		...
		member: "regulations"

		...

		Web "regulations" {
			Title: Relevant regulations
			Notation: Markdown
			Purpose: Keeping track of various obligations.
			Version Number: 2025.1
	
			Sections
				"EU Regulations"       at "regs/EU_1022a.md"
				"USDA Regulations"     at "regs/USDA.md"
				"Japanese Regulations" at "regs/jp_31_2.md"
		}
	}

This makes a three-section web in which each section is pure commentary, and
in effect collates some Markdown files into an area of our website. The bill
of materials now looks like so:

	member      | type | source location               
	----------- | ---- | ------------------------------
	front       | book | front-office                  
	inventory   | book | inventory-module              
	regulations | book | (contents list in Colony file)
	landing     | page | (material in Colony file)     
	back        | page | back-office.py.md             

## Patterns

A _pattern_ is, for our purposes, a sort of empty website design waiting
to have commentary and program poured into it. (Actually, it's a template
for any sort of weave, not just one to a website, but never mind that now.)

The default design when Inweb weaves a web page is a pattern called `HTML`,
a plain-vanilla sort of look. This can be customised in many ways, and
Inweb lets users create their own patterns. Every pattern has a name.

Suppose we want to adopt a different pattern for our website. One way to do
this is to specify a `pattern` for each member:

		member: "landing" to "index.html" pattern "GitHubPages"
		member: "front" at "front-office" pattern "GitHubPages"
		member: "back" at "back-office.py.md" to "back/index.html" pattern "GitHubPages"
		member: "inventory" at "inventory-module" pattern "GitHubPages"

(The pattern `GitHubPages` is also supplied with Inweb: it's optimised for
showing off a program using the Pages feature at `github.com`.) Specifying
a `pattern` doesn't mean the web can't be woven any other way: it means,
for example, that `inweb weave ::front` would use `GitHubPages` as pattern,
but a command could still override that with `inweb weave ::front -as HTML`,
for example.

All that works, but it's painful to have to keep writing `pattern "GitHubPages"`.
So Inweb provides an alternative:

		default: pattern "GitHubPages"
		member: "landing" to "index.html"
		member: "front" at "front-office"
		member: "back" at "back-office.py.md" to "back/index.html"
		member: "inventory" at "inventory-module"

`default:` specifies that its clauses should apply to all subsequent `member:` lines.
There can be more than one:

		default: pattern "HTML"
		member: "landing" to "index.html"
		member: "inventory" at "inventory-module"
		
		default: pattern "GitHubPages"
		member: "front" at "front-office"
		member: "back" at "back-office.py.md" to "back/index.html"

Obviously, it makes no sense for `default:` to set the `to` or `at` clauses,
but it can accept anything else.

## Breadcrumbs

_Breadcrumbs_ make up a horizontal row of links at the top of a web page,
and they're often a good way to show where an individual section of code
sits within a colony's website. (The name comes from the trails of breadcrumbs
used by clever children to lead monsters in folk-tales such as _Le Petit Poucet_
or _Hansel und Gretel_.)

Each of the members of a colony can provide its own `breadcrumbs`, but the
usual thing is to make use of `default:` again. So, for example:

	default: pattern "GitHubPages" breadcrumbs "Home: //landing//"
	member: "landing" to "index.html" breadcrumbs ""
	member: "front" at "front-office"
	member: "back" at "back-office.py.md" to "back/index.html"
	member: "inventory" at "inventory-module"

The site map now becomes:

	path         | leaf       | link-name | nav | crumbs | pattern    
	------------ | ---------- | --------- | --- | ------ | -----------
				 | index.html | landing   | --  |        | GitHubPages
	back/        | index.html | back      | --  | A      | GitHubPages
	docs-assets/ | --         | --        | --  | --     | --         
	front/       | index.html | front     | --  | A      | GitHubPages
	inventory/   | index.html | inventory | --  | A      | GitHubPages

	A = Home: //landing//

This provides something nice and simple: the landing page, at the top of
the website, provides no breadcrumb links. The top page of `front` shows:

> **Home** > Front End

(That's because "Front End" is the actual title of the web whose member
name is `front`: the title isn't "front". Member names are like nicknames.)
`Home` is hyperlinked to point to the landing page; `Front End` is not.
The section "Displaying Consumables" in this web weaves to a page whose
top links are:

> **Home** > **Front End** > Displaying Consumables

And from that page, "Front End" is hyperlinked to the contents page for `front`.

A more elaborate breadcrumb design might look like this:

	default: pattern "GitHubPages"
	member: "landing" to "index.html"         breadcrumbs ""
	member: "inventory" at "inventory-module" breadcrumbs "Home: //landing//"

	default:                                  breadcrumbs "Home: //landing// > Ends"
	member: "front" at "front-office"
	member: "back" at "back-office.py.md" to "back/index.html"

`Home: //landing// > Ends` is a trail of two crumbs. The first takes the form
`TEXT: //LINK//`, and is hyperlinked; the second is just `TEXT`, not hyperlinked;
and the `>` divides the crumbs. Trails can be as long as we like, but really
long trails are seldom a very good idea.

These revised breadcrumbs would result in top-links like so:

> **Home** > Ends > **Front End** > Displaying Consumables

## Navigation sidebars

We can also, optionally, provide a navigation sidebar, providing further links.
These are too elaborate to write horizontally, like breadcrumbs. Instead, the
navigational content is written as a declaration:

	Colony {
		...
		
		Navigation {
			[[Item "landing"]]
			[[Item "front"]]
			[[Item "back"]]
			[[Item "inventory"]]
		}
	}

This makes for a sidebar containing a column of four links, and for example,
`[[Item "front"]]` is the text "front" linked to the colony address `//front//`:
meaning, it always goes to the home page of the front-end program, whatever
page it's coming from.

The text and destination of the link do not have to be the same. For example:

			[[Item "home" -> //landing//]]

has the text "home", but points to the landing page at `//landing//`.

Long columns of links are better, in practice, grouped into sub-clusters. This
can be done with "menu" declarations:

	Colony {
		...
		
		Navigation {
			[[Home "home" -> //landing//]]
			[[Menu "Ends"]]
			[[Item "front end" -> //front//]]
			[[Item "back end" -> //back//]]
			[[Menu "Modules"]]
			[[Item "inventory"]]
		}
	}

So now we have a top-level item, "home", declared as `Home` not `Item`, which
makes it a little grander; then a submenu called "Ends", with two items,
"front end" and "back end", then another submenu with just one item.

The links above were all written in the `//...//` notation of internal colony
locations, which protects the site against broken links when things are rearranged.
(Inweb will produce errors rather than weave something with an incorrect link.)
But it's also possible to link to an external website with an absolute URL:

			[[Menu "External"]]
			[[Item "schematic" -> https://en.wikipedia.org/wiki/Spider_web#/media/File:Orb_web_building_steps-01.svg]]

Images can be included in, or indeed entirely make up, the link text:

		[[Home "<Octagram.png@72>" -> //overview//]]
		[[Item "<github.png> github" -> https://github.com/ganelson/inweb]]

The site map for our `retail` colony now looks like so:

	path         | leaf       | link-name | nav        | crumbs | pattern    
	------------ | ---------- | --------- | ---------- | ------ | -----------
				 | index.html | landing   | (nameless) |        | GitHubPages
	back/        | index.html | back      | (nameless) | A      | GitHubPages
	docs-assets/ | --         | --        | --         | --     | --         
	front/       | index.html | front     | (nameless) | A      | GitHubPages
	inventory/   | index.html | inventory | (nameless) | A      | GitHubPages

	A = Home: //landing//

Note the "nav" column in this table: the four weaves all use the navigation
element called `(nameless)`. We could actually have named it, and indeed, we
could have created more than one, so that the sidebar can be different in
different areas of the website. In this version, we make two different
sidebars, a "broad" and a "detailed" one, and use the `navigation` clause
to say which one is to be used for which web:

	Colony {
		default: pattern "GitHubPages" breadcrumbs "Home: //landing//" navigation "broad"
		member: "landing" to "index.html" breadcrumbs ""
		member: "front" at "front-office"
		member: "back" at "back-office.py.md" to "back/index.html"
		member: "inventory" at "inventory-module" navigation "detailed"
		
		...
		
		Navigation "broad" {
			...
		}
		Navigation "detailed" {
			...
		}
	}

It may not be obvious why all of those rather heavy `[[` and `]]` markers
were used. The answer is that `Navigation` content can in fact use any HTML
content of our choosing, and that `[[` and `]]` tell Inweb to make substitutions
into that content, exactly as it does when weaving a web page from a pattern.

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

## Summary

This has been a lengthy tour, but the basic point should be clear enough: except
perhaps for the simplest of one-program websites, every endeavour with Inweb
will likely benefit from being organised into a colony. To sum up:

* A colony has 1 or more members, each declared by `member:`, unless it is
  from a different colony entirely, in which case `external:`.
* Each member has a _name_, and can optionally supply one or more of:
  - a _location_ using `at`,
  - a _website path_ using `to`,
  - a choice of _navigation links_ using `navigation`,
  - a choice of _breadcrumb links_ using `breadcrumbs`, and/or
  - a weaving _pattern_ using `pattern`.
* A line reading `default:` and then some of these clauses sets some default
  values for `navigation`, `breadcrumbs` and/or `pattern` which apply to
  subsequent members until cancelled by a change of `default:`.
* A colony can also contain declarations of:
  - single pages of commentary with `Page "name" { ... }`,
  - contents pages for a whole web with `Web "name" { ... }`,
  - language declarations with `Language "name" { ... }`,
  - notation declarations with `Notation "name" { ... }`, and/or
  - conventions to apply to colony members with `Conventions { ... }`.
* The command `inweb map COLONY` shows a sitemap, and `inweb map -fuller COLONY`
  a more extensive one. `COLONY` need not be specified if the current working
  directory contains the relevant `colony.inweb` file.
* Other Inweb commands can refer to members of a colony as `COLONY::MEMBER` or,
  if again Inweb can see the colony in the cwd, simply `::MEMBER`.
* `inweb weave` and `inweb tangle` can be applied to a colony instead of a web,
  in which case they act on each (internal) member of the colony in turn.
