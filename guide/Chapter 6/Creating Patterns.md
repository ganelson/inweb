# Creating Patterns

In this section, two new example patterns will be created, each a way to
make slightly different websites.

## Tapestry

Suppose `pyramid.c.w` is some web in the current working directory, and we create
a new pattern called `Tapestry`:

	pyramid.c.w
	Tapestry
		Tapestry.inweb
		
A minimal declaration can be minimal indeed. Here's just enough for
`Tapestry.inweb` to get going:

	Pattern "Tapestry" {
		based on: HTML
	}

And now:

	$ inweb weave pyramid.c.w -as Tapestry -using Tapestry
	weaving web "Hilbert's Pyramid" (C program in MarkdownCode notation) as Tapestry
		generated: sample.html
		10 files copied to: sample-assets

Any pattern can be based on any (one) other pattern, which doesn't have to be
one of those built into Inweb. So it would be quite feasible to create one
new pattern, `Fancy`, based on `HTML`, and then another, `SuperFancy`, based
on `Fancy`. This of course means it would be possible to set up a world in
which pattern `Flip` is based on `Flop`, and at the same time `Flop` is based
on `Flip`: no good can come of that.

So far, `Tapestry` behaves identically to `HTML` in every respect, so it's
not very useful yet. Besides the declaration file, a pattern directory can
contain any of the following:

- A template file for creating the woven content from literate source.
- A similar template for creating an index or contents page.
- An "asset file": perhaps a CSS file, or an image.
- A "plugin" subdirectory, which contains one or more asset files.

For example, at time of writing the `HTML` template built into Inweb contains:

	Base
	Bigfoot
	Breadcrumbs
	Carousel
	Colouring
	Downloads
	Embedding
	HTML.inweb
	MathJax3
	Popups
	template-body.html
	template-index.html

Of these, `HTML.inweb` is the declaration file, and `template-body.html` and
`template-index.html` are the templates. Everything else here is a subdirectory
containing a plugin. (There are no "loose assets": all the assets are in plugins.)

Plugins are not sophisticated in themselves, and are really just a way to give
a name to a bundle of design aiming to accomplish one thing. For example,
`Breadcrumbs` contains the CSS needed for the row of breadcrumb links at the
top of a web page, along with an image used to texture them.

	Breadcrumbs
		crumbs.gif
		Breadcrumbs.css

Exactly how assets are used is a topic for later, but the point here is that
our `Tapestry` weaves will also contain all of these plugins, because it is
based on `HTML`. It can also contain new plugins, if we want. For example,
suppose we want every page woven with `Tapestry` to have a little icon of
a tapestry at the bottom. That will clearly need every weave to include
this image file. But how is this to be done?

The answer is that `Tapestry` can contain a new plugin. It will be very simple:
just a directory called `Logo` which contains our logo image, called `gobelins.jpg`.
The files in this example now look like so:

	pyramid.c.w
	Tapestry
		Logo
			gobelins.jpg
		Tapestry.inweb

Now when the weave is made as `Tapestry`, the image `gobelins.jpg` is automatically
copied into the "assets" directory of the website being created.

But that doesn't cause it to appear on any web pages: at present, it's just
sitting unused on the server. In order to brand every page with this logo, we
need the HTML for each page to contain an image tag.

This is where we need to provide a changed version of `template-body.html`, the
prototype web page from which all other pages on the website will be made. The
generic version in `HTML` is surprisingly short:

	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
	<html>
		<head>
			<title>[[Booklet Title]]</title>
			[[Plugins]]
		</head>
		<body class="commentary-font">
	[[Weave Content]]
		</body>
	</html>

When Inweb makes a page, it performs what's called _collation_ on this file.
That means it copies the thing out, but substitutes appropriate content for
certain placeholders written in double-square brackets, like `[[Weave Content]]`.
(This is often replaced by a massive amount of HTML, in fact: all the woven
code and commentary from the section.)

So here's a revised version:

	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
	<html>
		<head>
			<title>[[Booklet Title]]</title>
			[[Plugins]]
		</head>
		<body class="commentary-font">
	[[Weave Content]]
		<hr>
		<img src="[[Assets]]gobelins.jpg" alt="Tapestry Logo">
		<p>Brought to you by the Tapestry Foundation.</p>
		</body>
	</html>

Note the new lines at the bottom of the body of the page. Weaving with this
now produces pages looking as normal, except for a ruled line at the bottom,
and a shot of corporate branding.

The setup now looks like so:

	pyramid.c.w
	Tapestry
		Logo
			gobelins.jpg
		Tapestry.inweb
		template-body.html

Why did this work? Well, when Inweb needs a file from a pattern — for example
`template-body.html` — it looks for it first in the pattern currently in use;
if the file isn't there, it looks in the pattern that is based on; and so on.
So if `Tapestry` provides `template-body.html`, that's the template file used.
If not, Inweb turns next to `HTML/template-body.html`, because `Tapestry`
is based on `HTML`.

This can also be used to give `Tapestry` a modified version of one of the plugins
in HTML — allowing us to change the CSS or Javascript code in use. For example,
the plugin `Colouring` contains the colour choices made by `HTML`. The `Colouring`
plugin contains other things too, but the file to monkey with is
`Colouring/Colours.css`. We can provide a new version:

	pyramid.c.w
	Tapestry
		Colouring
			Colours.css
		Logo
			gobelins.jpg
		Tapestry.inweb
		template-body.html

And now the version of `Colours.css` used by Inweb (on a `Tapestry` weave)
will be this new one, not the original still in `HTML`. Note that we are
not under any obligation to provide the rest of the plugin: we only need
to provide replacements for the files we want to change.

So, for example, `Colours.css` contains the line:

	span.identifier-syntax  { color: #4040ff; }

This is a not-too-light green. Rewriting the line as:

	span.identifier-syntax  { color: #111111; }

makes the identifiers a very dark charcoal grey. (Strictly speaking, it does
this to any code syntax-coloured as `!identifier`, or as a colour like it:
see //Syntax Colouring Programs//.)

## MonoGitHub

As a further example: suppose the following is placed in a `MonoGitHub` directory, with
the name `MonoGitHub.inweb` —

	pattern "MonoGitHub" {
		based on: GitHubPages
	}

Then a subdirectory `Base` is added, with just one file in it, `Fonts.css`,
which reads:

	.code-font { font-family: monospace; }
	.commentary-font { font-family: monospace; }

When weaving with this new pattern, Inweb will use the new `Fonts.css` file
rather than the one in the `Base` plugin of `HTML`. Pages will then use
a monospaced font for commentary as well as code. All the other files of
`Base` remain as they were, and there's no need to provide duplicates here.
