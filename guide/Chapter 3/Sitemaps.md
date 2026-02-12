# Sitemaps

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
