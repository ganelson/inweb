@-> ../README.md
# Inweb @version(inweb)

## About Inweb

Inweb offers a modern approach to literate programming, a methodology created
by Donald Knuth in the late 1970s. A literate program, or "web", is constructed
in a narrative way, and is intended to be readable by humans as well as by
other programs. For example, the human-readable (or "woven") form of Inweb
itself is [here](docs/webs.html).

A comprehensive Inweb manual can be [read here](docs/inweb/P-iti.html).

Inweb is intentionally self-sufficient, with no dependencies on any other
software: it cam be built on any platform supporting the gcc or clang C
compilers. Its main use since 2004 has been to build the Inform compiler and
its associated tools (see [ganelson/inform](https://github.com/ganelson/inform)),
including another general-purpose tool, [ganelson/intest](https://github.com/ganelson/intest).

## Licence

Except as noted, copyright in material in this repository (the "Package") is
held by Graham Nelson (the "Author"), who retains copyright so that there is
a single point of reference. As from the first date of this repository
becoming public, the Package is placed under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).
This is a highly permissive licence, used by Perl among other notable projects,
recognised by the Open Source Initiative as open and by the Free Software
Foundation as free in both senses.

## Build Instructions

Inweb is itself a literate program. There is clearly a circularity here: to
compile Inweb, you must first run Inweb to "tangle" it, that is, to prepare
it for compilation. But if you already had Inweb, you wouldn't need to compile it.
Because of that, and because of the need to run cross-platform, the initial
setup takes a few minutes:

* Create a directory to work in, called, say, "work". Change the current directory to this.
* Clone Inweb as "work/inweb".
* Run **one of the following commands**. Unix is for any generic version of Unix,
non-Linux, non-MacOS: Solaris, for example. Android support is currently disabled
(though only because its build settings are currently missing from the inweb
distribution). The older macos32 platform won't build with the MacOS SDK from
10.14 onwards, and in any case 32-bit executables won't run from 10.15 onwards:
so use the default macos unless you need to build for an old version of MacOS.
	* "make -f inweb/inweb.mk macos"
	* "make -f inweb/inweb.mk macos32"
	* "make -f inweb/inweb.mk linux"
	* "make -f inweb/inweb.mk windows"
	* "make -f inweb/inweb.mk unix"
	* "make -f inweb/inweb.mk android"
* You should see some typical make chatter, ending in a reply such as "===
Platform set to 64-bit MacOS. Now: make -f inweb/inweb.mk initial ===".
(All that happened, in fact, was that a platform-specific file of make settings —
what compilers to use, what options, and so on — was copied over to become the
file inweb/platform-settings.mk.)
* Now run the command:
	* "make -f inweb/inweb.mk initial"
* You should now have a working copy of Inweb. For a simple test, try
"inweb/Tangled/inweb -help". To build Inweb again, no need to use "initial",
and simply:
	* "make -f inweb/inweb.mk"

@-> ../docs/webs.html
@define web(program, manual)
	<li>
		<p><a href="@program/index.html"><spon class="sectiontitle">@program</span></a> -
		@version(@program)
		- <span class="purpose">@purpose(@program)</span>
		Documentation is <a href="@program/@manual.html">here</a>.</p>
	</li>
@end
@define subweb(owner, program)
	<li>
		<p>↳ <a href="docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		<span class="purpose">@purpose(@owner/@program)</span></p>
	</li>
@end
@define mod(owner, module)
	<li>
		<p>↳ <a href="docs/@module-module/index.html"><spon class="sectiontitle">@module</span></a> (module) -
		<span class="purpose">@purpose(@owner/@module-module)</span></p>
	</li>
@end
@define extweb(program)
	<li>
		<p><a href="../@program/docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		@version(@program)
		- <span class="purpose">@purpose(@program)</span>
		This has its own repository, with its own &#9733; Webs page.</p>
	</li>
@end
@define extsubweb(owner, program)
	<li>
		<p>↳ <a href="../@owner/docs/webs.html"><spon class="sectiontitle">@program</span></a> -
		<span class="purpose">@purpose(@owner/@program)</span></p>
	</li>
@end
@define extmod(owner, module)
	<li>
		<p>↳ <a href="../@owner/docs/@module-module/index.html"><spon class="sectiontitle">@module</span></a> (module) -
		<span class="purpose">@purpose(@owner/@module-module)</span></p>
	</li>
@end
<html>
	<head>
		<title>Inform &#9733; Webs</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
		<meta http-equiv="Content-Language" content="en-gb">
		<link href="inweb/inweb.css" rel="stylesheet" rev="stylesheet" type="text/css">
	</head>

	<body>
		<ul class="crumbs"><li><b>&#9733;</b></li><li><b>Webs</b></li></ul>
		<p class="purpose">Human-readable source code.</p>
		<hr>
		<p class="chapter">
This GitHub project was written as a literate program, powered by a LP tool
called Inweb. While almost all programs at Github are open to inspection, most
are difficult for new readers to navigate, and are not structured for extended
reading. By contrast, a "web" (the term goes back to Knuth: see
<a href="https://en.wikipedia.org/wiki/Literate_programming">Wikipedia</a>)
is designed to be read by humans in its "woven" form, and to be compiled or
run by computers in its "tangled" form.
These pages showcase the woven form, and are for human eyes only.</p>
		<hr>
		<p class="chapter">This repository includes the following webs:</p>
		<ul class="sectionlist">
			@web('inweb', 'P-iti')
			@mod('inweb', 'foundation')
			@subweb('inweb', 'foundation-test')
		</ul>
	</body>
</html>
