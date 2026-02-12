# Gitignore Files

Inweb provides a system for generating `.gitignore` files, for use with the
git version control system, much like its system for generating //README Files//.
The command `inweb make-gitignore` works almost exactly like
`inweb make-readme`, and once again generates a makefile from a script:

	$ inweb make-gitignore smorgasbord
	smorgasbord/smorgasbord.giscript -> smorgasbord/.gitignore

Note that this resulting file may be "hidden" in some operating systems, on
account of the name beginning with a `.`: for example, it will usually not
be displayed by the Finder in MacOS.

As for README scripts, the braces `{` and `}` are significant, and all of the
same rules apply: `{set ...}` can create variables, `{repeat ...}` can provide
loops, `{define ...}` can create new macros.

Just one gitignore-related macro is additionally provided:

- `{basics}`, which instructs git to ignore any woven output in the subdirectory
  `Woven` or tangled output in `Tangled`, and also any ctags file.
