# Summary of Patterns

A pattern declaration must be in a file called `NAME.inweb` which is inside a
directory of plugins and templates, called `NAME`. The declaration should
be written thus:

	Language "NAME" {
		...
	}

where the body `...` consists of blank lines, or of any of the following,
given in any order:

*	`based on: ENAME` declares that the new pattern is based on an existing one
	called `ENAME`. For the pattern to be used, Inweb must be able to see that
	existing pattern somewhere: it will halt with an error if not. Any of the
	settings in this section (other than `based on`) will be taken from `ENAME`
	if the new pattern does not specify them.

*	`default range: RANGE` tells Inweb how granular the weave of a multi-section
	web should be, by default. `default range: sections` means that each section
	should be woven to its own file. `default range: chapters` means that each
	chapter is in its own file, which presents all its sections in turn.

*	`format: FORMAT` gives the fundamental kind of output being made. This must
	be one of those supported by Inweb:
	
		HTML  ePub  plain  TeX  TestingInweb

	`ePub` is the book format; `plain` is plain text; `TeX` is (plain) TeX;
	and `TestingInweb` should not be used except for its advertised purpose.

*	`block template: FILE` tells Inweb _not_ to read a file of this name from
	the template(s) that the current template is based on. This can only be
	used with template files like `template-body.html`. (It is less fuss to
	change the version of `template-body.html`: simply supply a replacement
	in the new template's directory. But if the idea is to not have the file
	at all, then this command is needed.)

*	`plugin: PNAME` tells Inweb to include the plugin `PNAME`, which should be
	a subdirectory called `PNAME` of the pattern directory. It should contain
	asset files: see //Asset Management//.

*	`mathematics plugin: PNAME` tells Inweb to include `PNAME` if and only if
	the weave includes any TeX mathematics formulae in commentary.

*	`footnotes plugin: PNAME` tells Inweb to include `PNAME` if and only if
	the weave includes any use of footnotes in commentary.

*	`assets`, followed by lines containing instructions on how to include
	files of various types, followed by an `end` line. See //Asset Management//.

*	`initial extension: .EXT` is useful only when `commands` are supplied.
	See //The Post-Weave//.

*	`commands`, followed by lines containing post-weave shell script commands,
	followed by an `end` line. See //The Post-Weave//.
