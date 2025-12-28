# Make Files

Inweb provides a system for generating _makefiles_, that is, build instructions
to be used by the Unix utility `make`, much like its system for generating
//README Files//. The command `inweb make-makefile` works almost exactly like
`inweb make-readme`, and once again generates a makefile from a script:

	$ inweb make-makefile smorgasbord
	smorgasbord/smorgasbord.mkscript -> smorgasbord/smorgasbord.mk

A new switch, `-platform X`, allows the platform (i.e. operating system)
being targeted to be changed: by default, this is whatever Inweb is running
on, but with `-platform windows`, Inweb on MacOS can cosplay.

As for README scripts, the braces `{` and `}` are significant, and all of the
same rules apply: `{set ...}` can create variables, `{repeat ...}` can provide
loops, `{define ...}` can create new macros. In addition, the following
make-related macros are available:

- `{platform-settings}` splices in a set of platform-specific definitions
  for compiling C-like programs on the platform (i.e., operating system) in
  which Inweb has been installed. If you're using Windows, they will be Windows
  settings, and so on.

- `{identity-settings}` splices in four constant declarations:
  - `INWEB` is the path to the Inweb executable;
  - `INTEST` similarly for Intest;
  - `MYNAME` is the directory name in which the web is held;
  - `ME` is the pathname of this directory.

- `{dependent-files tool: TOOL}`, or `{dependent-files module: MODULES}`, or
  `{dependent-files tool-and-modules: BOTH}` all produce a run of the source files
  on which a tangle of a web is dependent. Basically, a web needs to be tangled
  again and recompiled after each time any of its section files changes, or its
  contents page changes, or the libraries it's using (as modules) have changed.
  Compiling lists of such dependent files by hand is liable to result in
  accidental omissions. `{dependent-files}` alone means all the files on which
  a tangle of the current web depends.

- `{modify-filenames original: FILE prefix: PREFIX suffix: SUFFIX}` takes the
  filename and adds either a prefix or a suffix to the unextended leafname.
  Both prefix and suffix clauses are optional, but of course if both are
  missing then nothing changes.

  For example, the following needs to compile something twice, once for each
  CPU architecture; if `TO` is, say, `binary.o`, then as modified this will be
  `binary_x86.o` and `binary_arm.o`.

      {define: compile to: TO from: FROM ?options: OPTS}
      	  clang -std=c11 -c $(MANYWARNINGS) $(CCOPTSX) -g {OPTS} -o {modify-filenames original: {TO} suffix: _x86} {FROM}
      	  clang -std=c11 -c $(MANYWARNINGS) $(CCOPTSA) -g {OPTS} -o {modify-filenames original: {TO} suffix: _arm} {FROM}
      {end-define}

For example, here's a minimal script capable of incrementally tangling and
recompiling a C program:

	{platform-settings}
	
	{identity-settings}
	
	$(ME)/Tangled/$(MYNAME): {dependent-files}
		$(call make-me)
	
	.PHONY: force
	force:
		$(call make-me)
	
	define make-me
		$(INWEB) tangle $(ME)
		{compile from: $(ME)/Tangled/$(MYNAME).c   to:   $(ME)/Tangled/$(MYNAME).o}
		{link from:    $(ME)/Tangled/$(MYNAME).o   to:   $(ME)/Tangled/$(MYNAME)$(EXEEXTENSION)}
	endef

Note that the macros `{compile ...}` and `{link ...}` are defined in the platform
settings, as is `EXEEXTENSION` (it's `.exe` on Windows and blank on most other
platforms), whereas `ME` and `MYNAME` are set in the identity settings.

## Conveniences for Inform

The main Inform repository's makefile is especially convoluted because of the
very large number of webs in it, which fall into several different categories.
Inweb provides a couple of macros to help manage that.

- `{component symbol: SYMBOL webname: WEBNAME path: PATH set: SET type: TYPE}`
  declares one of the "component" webs which might need to be built. For example:
  
      {component type: module symbol: WORDS webname: words path: services/words-module set: modules}

  tells Inweb that it needs to know about the module whose name in the colony is
  `words`, but which will be identified in this makefile using the symbol `WORDS`,
  and so on.

- `{components type: TYPE}` and `{end-components}` then provide a loop construct,
  which loops through all components declared as having the given type. Within
  the loop body, the variable `{SYMBOL}` holds the symbol of the current component.
