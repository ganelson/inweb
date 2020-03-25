# Inweb 7

v7-alpha.1+1A02 'Escape to Danger' (25 March 2020)

## About Inweb

Inweb offers a modern approach to literate programming. Unlike the original
LP tools of the late 1970s, led by Donald Knuth, or of the 1990s revival,
Inweb aims to serve programmers in the Github age. It scales to much larger
programs than CWEB, and since 2004 has been the tool used by the
[Inform programming language project](https://github.com/ganelson/inform),
where it manages a 300,000-line code base.

Literate programming is a methodology created by Donald Knuth in the late
1970s. A literate program, or "web", is written as a narrative intended to
be readable by humans as well as by other programs. The human-readable form
for Inweb (which is itself a web) is here: [&#9733;&nbsp;inweb](docs/inweb/index.html).

For the Inweb manual, see [&#9733;&nbsp;inweb/Preliminaries](docs/inweb/M-iti).

__Disclaimer__. Because this is a private repository (until the next public
release of Inform, when it will open), its GitHub pages server cannot be
enabled yet. As a result links marked &#9733; lead only to raw HTML
source, not to served web pages. They can in the mean time be browsed offline
as static HTML files stored in "docs".

## Licence

Except as noted, copyright in material in this repository (the "Package") is
held by Graham Nelson (the "Author"), who retains copyright so that there is
a single point of reference. As from the first date of this repository
becoming public, the Package is placed under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).
This is a highly permissive licence, used by Perl among other notable projects,
recognised by the Open Source Initiative as open and by the Free Software
Foundation as free in both senses.

## Build Instructions

Inweb is intentionally self-sufficient, with no dependencies on any other
software beyond a modern C compiler. However, it does in a sense depend on
itself: because Inweb is itself a web, you need Inweb to compile Inweb.
Getting around that circularity means that the initial setup takes a few steps.

Make a directory in which to work: let's call this "work". Then:

* Change the current directory to this: "cd work"
* Clone Inweb: "git clone https://github.com/ganelson/inweb.git"
* Run **one of the following commands**. Unix is for any generic version of Unix,
non-Linux, non-MacOS: Solaris, for example. Android support is currently disabled,
though only because its build settings are currently missing from the inweb
distribution. The older macos32 platform won't build with the MacOS SDK from
10.14 onwards, and in any case 32-bit executables won't run from 10.15 onwards:
so use the default macos unless you need to build for an old version of MacOS.
	* "make -f inweb/inweb.mk macos"
	* "make -f inweb/inweb.mk macos32"
	* "make -f inweb/inweb.mk linux"
	* "make -f inweb/inweb.mk windows"
	* "make -f inweb/inweb.mk unix"
	* "make -f inweb/inweb.mk android"
* Perform the initial compilation: "make -f inweb/inweb.mk initial"
* Test that all is well: "inweb/Tangled/inweb -help"

You should now have a working copy of Inweb. To build it again, no need to
use "initial", and you should just: "make -f inweb/inweb.mk"

## Also Included

Inweb contains a substantial library of code shared by a number of other
programs, such as the [Intest testing tool](https://github.com/ganelson/intest)
and the [Inform compiler and related tools](https://github.com/ganelson/inform).

This library is called "Foundation", and has its own web
here: [&#9733;&nbsp;foundation-module](docs/foundation-module/index.html).

A small executable for running unit tests against Foundation is also included:
[&#9733;&nbsp;foundation-test](docs/foundation-test/index.html).

## Testing Inweb

If you have also built Intest as "work/intest", then you can try these:

* intest/Tangled/intest inweb all
* intest/Tangled/intest inweb/foundation-test all

### Colophon

This README.mk file was generated automatically by Inweb, and should not
be edited. To make changes, edit scripts/READMEscript.txt and re-generate.

