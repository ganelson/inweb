# Inweb version 7 'Escape to Danger'

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

