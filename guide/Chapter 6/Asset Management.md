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
need more delicate handling. Here is the `assets` portion of the `HTML` pattern
declaration:

	Pattern "HTML" {
		...
		assets
			collate .html files
			copy .js files
			for each .js file embed {
				<script src="URL"></script>
			}
			copy .css files
			for each .css file embed {
				<link href="URL" rel="stylesheet" rev="stylesheet" type="text/css">
			}
			transform names in .css files
		end
	}

As this may suggest, Inweb decides how to include an asset based on its filename
extension, which is assumed to indicate what kind of contents it has. For any
given extension, four methods of inclusion are possible:

1.	`copy .WHATEVER files`. This is default, and means a file is copied over
	directly into the assets directory for the weave.

2. 	`privately copy .WHATEVER files`. The same, but never put into the shared
	assets directory: it's always copied alongside the woven files for the web.

3.	`embed .WHATEVER files`. The file is not copied. Instead, its entire contents
	are pasted into the woven file itself, when the `[[Plugins]]` placeholder in
	the template is expanded (see //Collation//). Do not use this for binary files.

4.	`collate .WHATEVER files`. Like a `copy`, but the file collated into place
	rather than being copied over: which means that placeholders in it will be
	expanded. (See //Collation//.) Do not use this for binary files.

In addition, text (presumably code of some kind, but Inweb doesn't
distinguish) can be pasted into the embedded text in `[[Plugins]]` for each
copied or embedded asset. This:

			for each .js file embed {
				<script src="URL"></script>
			}

says that whenever a Javascript file is copied, a corresponding line should be
pasted in to `[[Plugins]]`. The `URL` is replaced by the relative URL from the
file being woven to the copied file in the assets directory. In the `HTML`
template file `template-body.html`, the `[[Plugins]]` content is then
collated into the `<head>` of the web page.

An alternative strategy would be:

		embed .js files
		for each .js file prefix {
			<script>
		}
		for each .js file suffix {
			</script>
		}

Now the Javascript files are not copied: they are written into the `[[Plugins]]`
placeholder. But the `prefix` text appears before each one, and the `suffix`
one after each one.

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
because of the previously enigmatic line

			transform names in .css files

in the `assets` rules for `HTML`, shown above.
