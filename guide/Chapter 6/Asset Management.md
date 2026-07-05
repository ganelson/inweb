# Asset Management

## General rules

In the example pattern developed in //Creating Patterns//, there was just one
asset, the image `gobelins.jpg`. That was tucked away in its own plugin,
called `Logo`, and the files were arranged like so:

	Tapestry
		Logo
			gobelins.jpg
		Tapestry.inweb
		template-body.html

No special instructions were needed for Inweb to deal with this asset: Inweb
treats images as binary files which it simply copies into place. But other
assets can be handled differently, as we shall see.

An _asset_, then, is any file in a plugin subdirectory whose filename does
not begin with a `.` character. During a weave:

- For each file Inweb weaves, it includes only the plugins it needs.

- If it needs plugin `X`, Inweb includes every asset from the `X`
subdirectory of the pattern, _or_ from the `X` subdirectory of any pattern
it is based on. For example, if `Threaded` is based on `Tapestry` which is
based on `HTML`, and `HTML` needs the plugin `X`, then Inweb includes every
asset in `Threaded/X`, `Tapestry/X` and `HTML/X`. If the same filename appears
in more than one of these subdirectories, the top one wins: that is, the
version in `Threaded/X` takes precedence, and if that is missing, the version
in `Tapestry/X` would beat the one in `HTML/X`.

This looks as if it might involve a great deal of redundant file copying. If a
web has 200 section files and they each call for the same logo image to be copied,
199 of those file copies would be a waste of time. Inweb is therefore optimised
so that the copy will be made just once.

As in the tapestry-logo case above, Inweb does not need to be given explicit
instructions on how to include assets. If nothing has been said, then it copies
a file verbatim into the assets directory for the weave. For the `gobelins.jpg`,
that was exactly what was wanted. But (for example) CSS and Javascript files
need more delicate handling. Here is (part of) the `assets` portion of the `HTML` pattern
declaration:

	Pattern "HTML" {
		...
		assets
			...
			.html files: collate
			.js files: copy and embed {
				<script src="URL"></script>
			}
			.css files: copy and transform names and embed {
				<link href="URL" rel="stylesheet" rev="stylesheet" type="text/css">
			}
		end
	}

The `assets` portion consists of a list of _rules_, each of which consists of
a _selector_, then a colon, then a _disposition_. A selector says which files
should be handled by the rule:

Selector                      | selects for
----------------------------- | -----------
`all files`                   | everything
`.html files`                 | files with the `.html` file extension (case insensitively)
`README.md file`              | files with the leafname `README.md` (case insensitively)

In addition, a selector can optionally end with `in` and the name of a plugin.
Thus `all files in Bigfoot` matches all asset files in the plugin `Bigfoot`.

When Inweb tries to match an asset file against these rules, it chooses only the
first one in the pattern which matches. If that fails, and the pattern is based
on another pattern, Inweb tries to match the rules for that pattern instead, and
so on. If nothing at all works, it falls back on the rule:

	all files: copy

which, as noted above, means that it copies the asset file unmodified into the
assets directory for the weave.

Because, within each pattern, Inweb matches only the first rule to match, the
following would make no sense:

		assets
			.html files: collate
			exception.html file: copy
		end

An asset called `exception.html` would match the first rule anyway, so the second
rule can never be reached. To catch these accidents, Inweb produces an error if
a rule is placed where it can never have any effect. Instead, this is intended:

		assets
			exception.html file: copy
			.html files: collate
		end

In other words, always handle exceptional cases first.

So much for selectors. Dispositions are instructions for what to do with the
file. There can be multiple sub-instructions, in which case they are separated with
the word `and`. (Not with commas.) The possible instructions are:

1.	`ignore`. The main action is to do nothing with the asset file.

2.	`copy`. The main action is to copy the file directly into the shared
	assets directory for the weave. (This is the default main action.)

3. 	`privately copy`. The main action is to copy, but not into the shared
	assets directory: the copy does alongside the woven files for the web.

4.	`embed file`. The main action is to paste the entire contents of the asset file
	into the woven file itself, at the position where the `[[Plugins]]` placeholder in
	the template is expanded (see //Collation//). This will typically be in the
	`<head>` of an HTML file. Do not use this for binary files.

5.	`collate`. The main action is to collate the entire contents of the asset file
	into the woven file itself, at the position where the `[[Plugins]]` placeholder in
	the template is expanded (see //Collation//). This will typically be in the
	`<head>` of an HTML file. Do not use this for binary files.
	(The difference between `collate` and `embed file` is that any further placeholders
	in the asset text are expanded, too.)

In addition, the following variations are allowed:

1.	`collate to head`: same as `collate`.

2.	`collate to body`: same as `collate`, but the matter is placed into the
	top of the `<body>` of an HTML file, not the `<head>`.

3.	`collate to search box`: same as `collate`, but the matter is placed into a
	natural place for a search box within the `<body>` of an HTML file.

4.	`transform names`: see the note below on the Colouring Exception.

5.	`add data`: during a `copy`, look out for the placeholder `SEARCHDATA`
	and replace it with Inweb-generated search data for the plugin `SeekLocateDisplay`
	to make use of.

6.	`embed {`, followed by one or more lines, followed by `}`: as well as
	the main action, place this material into the woven file at the `[[Plugins]]`
	position. See below.

7.	`prefix {`, followed by one or more lines, followed by `}`: if the main
	action is `embed file`, embed this text first.

8.	`suffix {`, followed by one or more lines, followed by `}`: if the main
	action is `embed file`, embed this text afterwards.

For example, consider this rule:

		.js files: embed file and prefix {
			<script>
		} and suffix {
			</script>
		}

This says that any Javascript files should be embedded into the `<head>` of
an HTML file, but inside `<script>` ... `</script>` tags. Similarly, CSS
could be handled like so:

		.css files: embed file and transform names and prefix {
			<style type="text/css">
		} and suffix {
			</style>
		}

Alternatively (and this is what `HTML` does), Javascript files could be copied
over, but then loaded from within `<head>`. This is done thus:

			.js files: copy and embed {
				<script src="URL"></script>
			}

Note that the `URL` is replaced by the relative URL from the file being woven to
the copied file in the assets directory.

## The Colouring Exception

Inweb has a special tweak to handle the plugin `Colouring`, found in `HTML`.
This contains a single asset: the file `Colours.css`, which specifies the
appearance of code features. See //Creating Patterns// for an example of
how this can be rewritten.

The special feature is this: When Inweb is weaving code of a given language
`NAME`, it looks first to see if the `Colouring` plugin contains a file
called `NAME-Colours.css`. If it does, that's the CSS which will be used
for any code excerpts from that language. If not, the regular `Colours.css`
is used.

Multiple CSS files could thus be read in, all of which attempt to define
the same CSS classes. That is, if a web contains excerpts in both C and
Rust, then Inweb might need to use both `Colours.css` (for C) and
`Rust-Colours.css` (for Rust — supposing somebody has created this). In
theory that could cause problems, because they will have rival definitions
of the CSS class `span.identifier-syntax` (for example). However, Inweb
renames them automatically so that this does not happen, and that is
because of the previously enigmatic `transform names` instruction in the
following asset rule in the `HTML` pattern:

	.css files: copy and transform names and embed {
		<link href="URL" rel="stylesheet" rev="stylesheet" type="text/css">
	}
