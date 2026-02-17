# Conventions

A _convention_ is a sort of preference setting which changes the normal way
a web is woven, tangled, or simply read in. There are relatively few of these,
and the generic values are usually sensible, so most webs will never need
to change them.

The currently applicable conventions can be seen using `inweb inspect -conventions`:

	$ inweb inspect -conventions smorgasbord
	web "Sorting Smorgasbord" (Python program in MarkdownCode notation): 2 sections : 10 paragraphs : 114 lines
	(generic)  paragraph numbers are visible
	(generic)  namespaces are unenforced
	(generic)  sections are not numbered sequentially

...and so forth. For example, `paragraph numbers are visible` is a convention.
`(generic)` means that it applies because this generically applies to every web,
unless Inweb is given any instructions to the contrary.

Conventions can be specified on the contents page of a web. For example, we could
rewrite `Contents.inweb` for `smorgasbord` to read:

	Title: Sorting Smorgasbord
	Author: Various Artists
	Notation: MarkdownCode
	Language: Python
	
	Sections
		Counting Sort
		Quick Sort

	Conventions {
		sections are numbered sequentially
	}

Note that conventions appear after the contents rundown, and in braces. (That's
because this is technically a _declaration_: see //Resources and Declarations//.)
We then see:

	$ inweb inspect -conventions smorgasbord
	web "Sorting Smorgasbord" (Python program in MarkdownCode notation): 2 sections : 10 paragraphs : 114 lines
	(generic)  paragraph numbers are visible
	(generic)  namespaces are unenforced
	(web)      sections are numbered sequentially

...and so on. Note that `(web)`, showing that the web makes the convention this
time. (For the effect this change actually has, see below.)

Conventions can be made, in fact, in five ways:

- `(generic)` means this is Inweb's default;
- `(language)` means that the language, in the above example `Python`, chose this;
- `(notation)` means that the web's notation, in the above example `MarkdownCode`, chose this;
- `(-using)` means that a file of conventions read by `-using FILE` chose this;
- `(colony)` means that the colony, if there is one, made the choice;
- and `(web)` means that the web's contents page said so.

In this list, later sources beat earlier ones. (`inweb inspect -conventions -fuller`
shows exactly how this trail is resolved.)

So, for example, if you have many unrelated programs which you want to set some
common preferences for, or if you want to set preferences for a single-file web
which has no contents page, the best way is probably to create a standalone preferences
file — called, say, `prefs.inweb`. This could for example read:

	Conventions {
		namespaces are enforced
		holon names are written between ▶️ and ◀️
	}

Whereupon `inweb weave program.c.md -using prefs.inweb` would have these
conventions applied, but `inweb weave program.c.md` would not.

On the other hand, if you want to apply some conventions across a set of programs
which are closely related, it's probably better to create a colony for them
(see //Colonies//) and then include conventions at the foot of the colony file.

## Conventions changing how webs are read in

* `commentary uses Markdown markup`, `commentary uses simplified markup`,
  or `commentary uses TeX markup`. Here, something confusing must be explained:
  Inweb supports multiple notations for webs, including the one called `MarkdownCode`
  which is used in most of this guide. Other notations look very different.
  But all of them feature some sort of markup features in their
  commentary: some way to indicate that text should be italicised, for example.
  So it can be the case that `commentary uses Markdown markup`, even
  if the notation is not `MarkdownCode`. Older Inweb webs have traditionally
  used `commentary uses simplified markup`, which as the name suggests, is
  more restricted. At present, `commentary uses TeX markup` is experimental
  and not fully working. Generically, `commentary uses simplified markup`.

* `a summary under the title is read as the purpose`,
  `an italicised summary under the title is read as the purpose`, or
  `a summary under the title is not read as the purpose`.
  See //Metadata//, which describes what `an italicised summary under the title is read as the purpose`
  does, since that's the normal setting for Markdown-notation webs. Older
  Inweb webs tended to use `a summary under the title is read as the purpose`,
  which doesn't require the summary to be in italics, but does require it to
  be the only text "in limbo", that is, occurring before the first explicit
  paragraph opening. (This makes no sense for Markdown because there are no
  explicit paragraph markers in that notation.) Generically, though,
  `a summary under the title is not read as the purpose`; notations must
  actively decide to allow this.

* `holon names can be abbreviated`, `holon names can be abbreviated even at declarations`,
  or `holon names cannot be abbreviated`.
  This controls whether it's legal to refer to a holon like `{{do something long}}`
  with three dots, i.e., as `{{do something...}`. Generically, `holon names can be abbreviated`,
  which means that _uses_ of holons can be abbreviated, but _declarations_
  cannot. `holon names can be abbreviated even at declarations` enables the
  freer use of abbreviations customary in Knuth's original literate programming
  tools, which is just a little risqué for Inweb's more conservative tastes.
  For example, it allows:
  
      {{Start up}} =
          print("Welcome.")
          {{Initialise all the variables and allocate memory}}
      
      {{Init...}} =
          x = 1

  ...which Inweb would ordinarily reject.

* `holon names can contain styling` or `holon names cannot contain styling`.
  Should the name of a holon be treated as commentary text, allowing italics
  or maths notation, for example, or should it be plain text? This affects,
  for example, how ``{{if $x_i < 2^7$, clear `buffer`}}`` would be woven
  (though of course it makes no difference to the resulting program).
  Generically, `holon names can contain styling`.

* `comments can contain styling` or `comments cannot contain styling`.
  Same issue, but for comments in code. Should `x++; /* since $x<2^7$ */`
  have the TeX notation converted to mathematics, for example? This is
  more contentious, because people do use comments to comment out code,
  and that might contain notations which coincide with markup; and so
  generically, `comments cannot contain styling`. But especially
  mathematical programs might benefit from changing this.

* `holon names are written between LEFT and RIGHT`. This changes the notation
  being used so that holon names are delimited by whatever characters you give
  in the strings `LEFT` and `RIGHT`. You might want to do this just to change
  the aesthetics. For example,

      holon names are written between ⟨ and ⟩
      holon names are written between (* and *)

  Or you might need to make a change because the language you're programming
  in clashes against your preferred notation. It is also possible to remove
  the ability to name holons altogether:
  
      holons are not named
  
  Generically, `holon names are written between {{ and }}`.

* `paragraph tags are written between LEFT and RIGHT`. This changes the notation
  being used so that tags attached to certain paragraphs are written in a
  different way. For example,

      paragraph tags are written between (TAG: and )

  It is also possible to remove the ability to to tag paragraphs altogether:
  
      paragraph tags are not recognised
  
  Generically, `paragraph tags are not recognised`, but 

* `TeX notation is used for mathematics` or `TeX notation is not used for mathematics`.
Some Inweb notations (including its Markdown ones) recognise TeX notation with
`$` and `$$` to delineate mathematical formulae. But this can be turned off.
Generically, `TeX notation is used for mathematics`.

* `footnotes are recognised` or `footnotes are not recognised`. Similarly, some
notations (including its Markdown ones) recognise `[1]`, `[2]` and so forth
as footnote numbers, and react accordingly. But this can be turned off.
Generically, `footnotes are recognised`.

## Conventions affecting weaving

* `paragraph numbers are visible` or `paragraph numbers are invisible`. Affects
only weaving. Holons of code are normally numbered in woven output: for example,
§1, §1.1, and so on. Occasionally this is a distraction, so it can be turned
off. Generically, `paragraph numbers are visible`.

* `sections are numbered sequentially` or `sections are not numbered sequentially`.
Affects how commands are read, and affects weaving. Sections are ordinarily given
brief abbreviations derived from their titles: for example, "Commentary in Markdown"
might be abbreviated `cim`. This affects leafnames of HTML files generated by
weaving, and also how some commands like `inweb weave guide -only cim` are read.
If `sections are numbered sequentially` is used, sections are instead abbreviated
`s1`, `s2`, `s3` and so on. Generically, `sections are not numbered sequentially`.

## Conventions affecting tangling

* `metadata in strings are written between LEFT and RIGHT`. This changes the notation
  being used when metadata like `Author` need to be expanded inside strings
  within holons. For example,

      metadata in strings are written between <substitute: and >

  It is also possible to remove this feature altogether:
  
      metadata in strings are not recognised

  Generically, in fact, `metadata in strings are not recognised`, but the
  notations mostly used by Inweb say that `metadata in strings are written between [[ and ]]`,
  so in practice this is the default.

* `namespaces are enforced` or `namespaces are unenforced`. Affects only tangling.
This will produce an error if the program attempts to make a function declaration
which doesn't belong to the namespace declared by the section as its own.
In practice, this is useful only for the pseudo-language InC. Generically,
`namespaces are unenforced`.

* `whitespace lines opening holons are tangled` or `whitespace lines opening holons are not tangled`.
  If a holon of code opens with one or more lines of white space, should they be
  included in the tangled output? (This can't arise with the Markdown notation,
  but other notations might allow it to.) Generically, `whitespace lines opening holons are tangled`.

* `whitespace lines closing holons are tangled` or `whitespace lines closing holons are not tangled`.
  If a holon of code closes with one or more lines of white space, should they be
  included in the tangled output? (This can't arise with the Markdown notation,
  but other notations might allow it to.) Generically, `whitespace lines closing holons are tangled`.

* `named holons are tangled between PREFIX and SUFFIX` or
  `named holons are not tangled with prefix or suffix`. Generically,
  `named holons are tangled between <NEWLINE> and <NEWLINE>`, but for example,
  the language definition for C includes the convention
  `named holons are tangled between <NEWLINE>{<NEWLINE> and }<NEWLINE>`, and
  the CWEB-compatibility notation takes it away again, since this was not a
  feature of CWEB, and it will cause some CWEB programs to fail to compile.
  
  This convention is a device to enable holons to behave like code blocks in
  C (and similar languages): see //Holons as Code Blocks//.

## Conventions affecting tangling of C and related languages

See //Special C Features// for a proper explanation of these. Note that these
conventions take effect only for languages declared as being "C-like"; using
them on, say, a Python web would do nothing.

* `standard library #includes are tangled early in the program` or
  `standard library #includes are treated like any other code`.
  Generically, `standard library #includes are treated like any other code`, but
  language definitions for C and variants of C usually say otherwise.

* `typedefs are tangled early in the program` or
  `typedefs are treated like any other code`.
  Generically, `typedefs are treated like any other code`, but language definitions for
  C and variants of C usually say otherwise.

* `typedef structs are tangled early and reordered logically` or
  `typedef structs are treated like any other code`.
  Generically, `typedef structs are treated like any other code`, but language
  definitions for C and variants of C usually say otherwise.

* `function predeclarations are tangled automatically` or
  `functions are treated like any other code`.
  Generically, `functions are treated like any other code`,
  but language definitions for C and variants of C usually say otherwise.
