# Collation

_Collation_ is the process used by Inweb when it makes a new file in the
weave output. For example, consider this weave (last seen in //Contents Pages//):

	$ inweb weave smorgasbord -to my_website
	weaving web "Sorting Smorgasbord" (Python program in MarkdownCode notation) as HTML
		[my_website/cnsr.html] [qcsr] 
		[index] 
		10 files copied to: my_website/assets

Here Inweb needs to make two section pages and one index page.

File                    | Collated from
----------------------- | --------------------------
`my_website/cnsr.html`  | `HTML/template-body.html`
`my_website/qcsr.html`  | `HTML/template-body.html`
`my_website/index.html` | `HTML/template-index.html`

Collation can also happen on smaller scales. When Inweb turns a `Navigation`
resource into the actual HTML for a sidebar of navigation links, it does that
by collation. (See //Sitemaps//.) And collation is also used when Inweb injects
content from plugins into web pages. (See //Asset Management//.) As this
demonstrates, one collation can include the output of another.

The basic idea is very simple. The template is a file like a pro-forma letter,
which has everything in place except the actual text. Collating fills this in
to make a finished letter.

For example, here is a template file for making an HTML page:

	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
	<html>
		<head>
			<title>[[Booklet Title]]</title>
			[[Plugins]]
		</head>
		<body>
	[[Weave Content]]
		</body>
	</html>

Collating with this is just copying it over verbatim: except for the placeholders
in double square brackets.

## Placeholders used on body pages

- `[[Weave Content]]` expands to the body of the web page -- the headings,
paragraphs and so on.

- `[[Plugins]]` expands to any links to CSS or Javascript files needed
by the plugins being used.

- Any item of metadata for the web expands to its value: thus `[[Title]]`,
`[[Author]]` and so on. (See //Metadata//.)

- `[[Booklet Title]]` is a title for the document, which Inweb works out
depending on what (and how much) it contains. For a single-page web, this
would be the title of the whole program; for just one section of a web, the
section title; and so on. (The quaint term "booklet title" is because literate
programming tools began in a world of making short book-like documents rather
than web pages.)

- For any metadata, placing the word `Capitalized` (or `Capitalised`) produces
that text in capital letters. Thus if `[[Author]]` expands to "Lucy Templeton",
then `[[Capitalized Author]]` expands to "LUCY TEMPLETON".

- `[[Navigation]]|` expands to the navigation sidebar in use when weaving
a colony of webs — see //Sitemaps// for more. What happens is that the content
of the navigation resource for the web is collated in.

- `[[Breadcrumbs]]` expands to the HTML for the breadcrumb trail of a page.
Again, see //Sitemaps//. Note that the `template-body.html` for `HTML` does
not contain this placeholder, and so the breadcrumb links aren't shown. But
the `template-body.html` for `GitHubPages`, for example, does.

- `[[Docs]]` is intended for webs being woven as part of a colony of webs
sharing a website: it expands to the URL for the home page.

- `[[Assets]]|` expands to the URL of the directory into which plugin
assets such as images are placed. An example of this in use can be found
in //Creating Patterns//, in the URL for the tapestry logo image. Note that
it might be the empty text, if the images are in the same directory as
the page being generated: and if it is not empty, then it contains a final
directory divider. It might typically expand to `project-assets/`. Because
of this a typical image URL in the template should be written `[[Assets]]image.jpg`,
not `[[Assets]]/image.jpg`, which may go wrong if `[[Assets]]|` is empty.

## Placeholders used on index pages

The `template-index.html` file has access to additional placeholders
enabling it to generate contents/index pages:

- 	One of the following details about the entire-web PDF (see below):

		[[Complete Leafname]]  [[Complete Extent]]  [[Complete PDF Size]]

-	One of the following details about the "current chapter" (again, see below):

		[[Chapter Title]]  [[Chapter Purpose]]  [[Chapter Leafname]]
		[[Chapter Extent]]  [[Chapter PDF Size]]  [[Chapter Errors]]

	The leafname is that of the typeset PDF; the extent is a page count;
	the errors result is a usually blank report.

-	One of the following details about the "current section" (again, see below):

		[[Section Title]]  [[Section Purpose]]  [[Section Leafname]]
		[[Section Extent]]  [[Section PDF Size]]  [[Section Errors]]
		[[Section Lines]]  [[Section Paragraphs]]  [[Section Mean]]
		[[Section Source]]

	Lines and Paragraphs are counts of the number of each; the Source
	substitution is the leafname of the literate source file. The Mean is the
	average number of lines per paragraph: where this is large, the section
	is rather raw and literate programming is not being used to the full.

-	`[[Repeat Chapter]]` and `[[Repeat Section]]` begin blocks of lines which
	are repeated for each chapter or section: the material to be repeated
	continues to the matching `[[End Repeat]]` line. The "current chapter or
	section" mentioned above is the one selected in the current innermost
	loop of that description.

-	`[[Repeat Module]]`, similarly, begins a repeat through the imported
	modules of the current web. (The main module, containing the actual material
	of the current web, does not count.) Within such a loop,

		[[Module Title]]  [[Module Purpose]]  [[Module Page]]

	can all be used to refer to the current module. `[[Module Page]]` expands
	to the relative URL of the module's own woven HTML form, provided that
	the module is listed as a member of the current colony file.

-	`[[Select ...]]` and `[[End Select]]` form a block which behaves like
	a repetition, but happens just once, for the named chapter or section.

	For example, the following pattern:
	
		To take chapter 3 as an example, for instance, we find -
		[[Select 3]]
		[[Repeat Section]]
			Section [[Section Title]], [[Section Code]], [[Section Lines]] lines.
		[[End Repeat]]
		[[End Select]]
	
	weaves a report somewhat like this:
	
		To take chapter 3 as an example, for instance, we find -
			Section Lexer, 3/lex, 1011 lines.
			Section Read Source Text, 3/read, 394 lines.
			Section Lexical Writing Back, 3/lwb, 376 lines.
			Section Lexical Services, 3/lexs, 606 lines.
			Section Vocabulary, 3/vocab, 338 lines.
			Section Built-In Words, 3/words, 1207 lines.
	
-	Finally, there is very limited support for conditionals with
	`[[If CONDITION]]`, an optional `[[Else]]`, and a compulsory `[[Endif]]`.
	Very few conditions are in fact allowed:

	- `[[If Chapters]]` tests whether the current web is divided into chapters,
	the alternative being that all the sections are in a notional chapter just
	called `Sections`.

	- `[[If Modules]]` tests whether the current web imports any modules.

	- `[[If Chapter Purpose]]`, inside a `[[Repeat Chapter]]`, tests whether the
	current chapter has a (non-empty) purpose text. Similarly for `[[If Section Purpose]]`
	and `[[If Module Purpose]]`.

	- `[[If Module Page]]`, inside a `[[Repeat Module]]`, tests whether the module
	appears (under its own name, i.e., not by a different name) as a member in
	the colony file, if there is one. In effect, this can be used to test whether
	it is safe to make a link to the module's own woven pages using `[[Module Page]]`.
