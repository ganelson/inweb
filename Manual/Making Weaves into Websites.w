Making Weaves into Websites.

How to present one or more weaves on a shared website, for example using
GitHub Pages.

@h GitHub Pages.
If a project is hosted at GitHub, then the GitHub Pages service is the ideal
place to serve a woven copy of the project to the world: the |docs| subdirectory
of a repository is simply served as a website, once this is enabled from the
owner's Github control panel.

First, the simple case: our repository is a single web, called |example|.
We suppose that the current working directory is one up from this, and contains
the installation of |inweb| as well as |example|. Then:
= (text as ConsoleText)
	$ ls
	inweb   example
	$ inweb/Tangled/inweb example -weave-as GitHubPages -weave-into example/docs
=
will do the trick. (|GitHubPages| is a pattern refining the default |HTML| one.)

@h Colonies.
A collection of webs gathered in one place is, for want of a better word,
called a "colony". (Some social species of spiders form colonies, and share
webs which are collectively woven.)

Inweb provides support for colonies, and this enables us to manage the more
complicated case where there are multiple webs in a repository, but which need
to share the same |docs| area. Now the problem to tackle is that we have two
or more webs in our |example| repository, one at |example/aleph|, the other
at |example/beth|.

The first thing to do is to write a colony file -- we could put this anywhere
in the repository, but let's say at |example/colony.txt|:
= (text as ConsoleText)
	pattern: GitHubPages
	web: "aleph" at "example/aleph" in "example/docs/aleph"
	web: "beth" at "example/beth" in "example/docs/beth"
=
This is, in effect, a set of presets of Inweb's command-line settings. We can
now write, for example,
= (text as ConsoleText)
	$ inweb/Tangled/inweb -colony example/colony.txt -member beth -weave
=
and this is equivalent to
= (text as ConsoleText)
	$ inweb/Tangled/inweb example/beth -weave -weave-into example/docs/beth -weave-as GitHubPages
=
The idea is that |-member M| chooses |M| as the current web, and automatically
sets its default settings: |-weave-to|, |-weave-as|, |-navigation| and
|-breadcrumb| are all handled like this.

@ These pathnames are taken relative to the current working directory of
the user (not to the location of the colony file). For //inweb//, this
is conventionally the directory above the actual web, and that's why the
file needs to say:
= (text)
	home: inweb/docs
=
This overrides the default setting (just |docs|), and is the path to the
home page of the Github Docs area for the repository.

@ The use of a colony also enables cross-references from the weave of one
web to the weave of another, even when they are independent programs. For
example, a section of code in |beth| could say:
= (text)
	Handling file system problems is more of a job for //aleph// than
	for us, so we'll just proceed. (See //aleph: Error Recovery//.)
=
and these links would both work. Without the use of a colony file, neither
one could be recognised, because Inweb wouldn't know what |aleph| even was.
To demonstrate that right here, see //goldbach: The Sieve of Eratosthenes//.
That last sentence was typed as:
= (text)
	To demonstrate that right here, see //goldbach: The Sieve of Eratosthenes//.
=
Cross-references to other webs or modules in the same colony can be to chapters
or sections, or simply to the entire web in question -- see //goldbach// --
but not to functions or types in those webs: that would require Inweb to read
every web in the colony into memory, which would slow it down too much.

@ As a more sustained example, here is the current version of the colony file
for the Inweb repository:
= (text from Figures/colony.txt)
As this demonstrates, either webs, or modules, or both, can be declared.
Each one gives (a) a short name, (b) a location relative to the current
working directory, and (c) a similar location for its woven collection of
files. The file can also specify navigation and breadcrumbs material, and
the pattern; each of these applies to each subsequent declaration until the
setting in question changes again. (Setting to |none| removes them.)

Also notable here is that the colony contains a single-page web called
|index.inweb|. (You can see that it's a single-page web, rather than something
more substantial, because the location ends |.inweb| rather than being a
directory name.) The point of this web is that it weaves to the |index.html|
home page; it's referred to in links as being the "overview", because that's
its name as a web.

@h The navigation sidebar.
When assembling large numbers of woven websites together, as is needed for
example by the main Inform repository's GitHub pages, we need to navigate
externally as well as internally: that is, the page for one tool will need
a way to link to pages for other tools.

This is why the |GitHubPages| pattern has a navigation sidebar, to the left
of the main part of each page. The template file contains a special expansion
written |[[Navigation]]|, and this expands to the HTML for a column of links.

The pattern also has a row of breadcrumbs along the top, for navigation within
the current web.

@ By default, Inweb looks for a file called |nav.html| in two directories: the
one above the destination, and the destination. If both exist, they are both
used. If neither exists, the expansion is empty, but no error is produced.

However, this can be overridden at the command line, with |-navigation N|,
where |N| is the filename for a suitable fragment of navigation HTML, and
it can also be preset in the Colony file (see above).

@ Inweb in fact makes it easy to write such navigation files, providing
commands which mean that little HTML need be written at all. This is the
one which generates the sidebar visible to the left of the pages on the
Inweb |docs| site:
= (text from Figures/nav.txt)
As this shows, there's some HTML for the top left corner area, and then
a list of items and submenus. |[[Link "overview"]]| opens a link to the
colony item called |overview|; |[[URL "inweb"]]| writes a minimal-length
relative URL to reach the named directory, and |[[Docs]]| to the home page
of the Github Docs area for the repository. |[[Menu "External"]]| begins
a submenu among the items. |[[Item "X"]]| makes a menu item whose title is
|X| and which links to the colony item called |X|; |[[Item "Y" -> Z]]| is
more general, and makes the text |Y| point to either an external web page,
recognised by beginning with |http|, or else a web cross-reference. Thus:
= (text)
	[[Item "innards" -> //inweb: Programming Languages//]]
=
would make a menu item called "innards" leading to a section in Chapter 4
of the Inweb source.

An item text can begin or end with an icon name, in angle brackets. For
example:
= (text)
	[[Item "<github.png> github" -> https://github.com/ganelson/intest]]
=
This icon should be in the |docs| home of the repository. Note that the
|GithubPages| pattern automatically includes the |github.png| icon, so
that one's guaranteed to be present.

@h The trail of breadcrumbs.
Inweb automatically adds web, chapter and section titles to the trail of
breadcrumbs above each page: for example,
= (text)
Beth > Chapter 4 > File Organisation
=
That may be sufficient in itself. However, it's possible to add extra
crumbs to the left. Suppose we want:
= (text)
Home > Beth > Chapter 4 > File Organisation
=
where Home is a link to |example/docs/index.html|. One way is to run Inweb
with |-breadcrumb 'Home:index.html'|; another is to add this to the Colony
file, as
= (text)
	breadcrumbs: "Home: index.html"
=
We can add more than one, by, e.g., |-breadcrumb 'Home:index.html' -breadcrumb 'Webs: webs.html'|.
= (text)
	breadcrumbs: "Home: index.html" > "Webs: webs.html"
=
The links after the colon can also be Inweb cross-references, so, for example,
= (text)
	breadcrumbs: "Overview: //overview//"
=
makes a link to the web/module called |overview| in the colony file.
