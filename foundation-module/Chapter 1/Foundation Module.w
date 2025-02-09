[Foundation::] Foundation Module.

Starting up and shutting down.

@h Introduction.
The Foundation module supplies some of the conveniences of more modern
programming languages to ANSI C. It offers the usual stuff of standard
libraries everywhere: memory management, collection classes, filename
and file system accesss, regular-expression matching and so on. At one
time the higher-level material formed a second module called "Foundation
and Empire", but now it's all consolidated into a single everything-you-need
module. Almost all functionality is optional and can be ignored if not
wanted. With a few provisos, the code is thread-safe, sturdy and well
tested, since it forms the support code for the Inform programming
language's compiler and outlying tools, including Inweb itself. If you
need to write a command-line utility in ANSI C with no dependencies on
other tools or libraries to speak of, you could do worse.

To use |foundation|, the Contents section of a web should include:
= (text)
	Import: foundation
=
before beginning the chapter rundown. There are then a few conventions
which must be followed. The |main| routine for the client should, as one
of its very first acts, call |Foundation::start()|, and should similarly, just
before it exits, call |Foundation::end()|. Any other module used should be
started after Foundation starts, and ended before Foundation ends.

In addition, the client's source code needs to define a few symbols to indicate
what it needs in the way of memory allocation. For an example, see the code
for Inweb itself.

@h Basic definitions.
These are all from the ANSI C standard library (or the pthread POSIX standard),
which means that Inweb will tangle them up to the top of the C source code.
Because pthread is not normally available on Windows, a special header is
supplied instead for that case.

= (very early code)
#include <ctype.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

typedef uint32_t inchar32_t;

@ =
text_stream *DL = NULL; /* Current destination of debugging text: kept |NULL| until opened */

@ We'll use three truth states, the third of which can also mean "unknown".

@d TRUE 1
@d FALSE 0
@d NOT_APPLICABLE 2

@ And we recognise two different encodings for narrow (i.e., |char *|) C strings.

@d UTF8_ENC 1 /* Write as UTF-8 without BOM */
@d ISO_ENC 2 /* Write as ISO Latin-1 (i.e., no conversion needed) */

@ It is assumed that our host filing system can manage at least 30-character
filenames, that space is legal as a character in a filename, and that trailing
extensions can be longer than 3 characters (in particular, that |.html| is
allowed). There are no clear rules but on Windows |MAX_PATH| can be as low as
260, and on Mac OS X the equivalent limit is 1024; both systems can house
files buried more deeply, but in both cases the user interface to the
operating system fails to recognise them. Some Linux implementations raise the
equivalent |PATH_MAX| limit as high as 4096. This seems a reasonable
compromise in practice:

@d MAX_FILENAME_LENGTH 1025

@ Very occasionally we'll store a pointer as data:

=
typedef uintptr_t pointer_sized_int;

@h The beginning and the end.
As noted above, the client needs to call these when starting up and when
shutting down.

The Inweb notation |[[textliterals]]| inserts declarations of I-literals,
that is, literal |text_stream *| values written as |I"strings"|. It should
never be used anywhere but here.

=
void Foundation::start(int argc, char **argv) {
	CommandLine::set_locale(argc, argv);
	Platform::configure_terminal();	
	Memory::start();
	@<Register the default stream writers@>;
	[[textliterals]];
	Time::begin();
	Pathnames::start();
	MarkdownVariations::start();
	WebSyntax::create();
	SPDXLicences::create();
	@<Register the default debugging log aspects@>;
	@<Register the default debugging log writers@>;
	@<Register the default command line switches@>;
}

@ After calling |Foundation::start()|, the client can register further stream
writing routines, following these models: they define the meaning of escape
characters in |WRITE|, our version of formatted printing. |%f|, for example,
prints a filename by calling |Filenames::writer|.

@<Register the default stream writers@> =
	Writers::register_writer('f', &Filenames::writer);
	Writers::register_writer('p', &Pathnames::writer);
	Writers::register_writer('v', &VersionNumbers::writer);
	Writers::register_writer('S', &Streams::writer);

@ We provide a full logging service, in which different "aspects" can be
switched on or off. Each aspect represents an activity of the program about
which a narrative is printed, or not printed, to the debugging log file.
The following are always provided, but are all off by default.

@<Register the default debugging log aspects@> =
	Log::declare_aspect(DEBUGGING_LOG_INCLUSIONS_DA, U"debugging log inclusions", FALSE, FALSE);
	Log::declare_aspect(SHELL_USAGE_DA, U"shell usage", FALSE, FALSE);
	Log::declare_aspect(MEMORY_USAGE_DA, U"memory usage", FALSE, FALSE);
	Log::declare_aspect(TEXT_FILES_DA, U"text files", FALSE, FALSE);

@ Debugging log writers are similar to stream writers, but implement the |$|
escapes only available to the debugging log. For example, |$S| calls the
|Streams::log| function to print a textual representation of the current
state of a stream.

@<Register the default debugging log writers@> =
	Writers::register_logger('a', &Tries::log_avinue);
	Writers::register_logger('S', &Streams::log);

@ We provide an optional service for parsing the command line. By default,
the |-log A| switch makes that aspect active, though it's hyphenated, so
for example |-log memory-usage| or |-log no-memory-usage|. |-fixtime| is
used to ease automated testing: we don't want to reject the output from
some tool just because it contains today's date and not the date when the
test was set up. |-crash| tells the tool to crash on a fatal error, rather
than to exit cleanly, to make it easier to diagnose in a debugger.

@e LOG_CLSW from 0
@e VERSION_CLSW
@e CRASH_CLSW
@e HELP_CLSW
@e FIXTIME_CLSW
@e AT_CLSW
@e LOCALE_CLSW

@<Register the default command line switches@> =
	CommandLine::begin_group(FOUNDATION_CLSG, NULL);
	CommandLine::declare_switch(LOG_CLSW, U"log", 2,
		U"write the debugging log to include diagnostics on X");
	CommandLine::declare_switch(VERSION_CLSW, U"version", 1,
		U"print out version number");
	CommandLine::declare_boolean_switch(CRASH_CLSW, U"crash", 1,
		U"intentionally crash on internal errors, for backtracing", FALSE);
	CommandLine::declare_switch(HELP_CLSW, U"help", 1,
		U"print this help information");
	CommandLine::declare_boolean_switch(FIXTIME_CLSW, U"fixtime", 1,
		U"pretend the time is 11 a.m. on 28 March 2016 for testing", FALSE);
	CommandLine::declare_switch(AT_CLSW, U"at", 2,
		U"specify that this tool is installed at X");
	CommandLine::declare_switch(LOCALE_CLSW, U"locale", 2,
		U"set locales as 'L=E', L being shell or console, E platform, utf-8 or iso-latin1");
	CommandLine::end_group();

@ Once the following has been called, it is not safe to use any of the
|foundation| facilities. It should be called on any normal exit, but not on
an early termination due to a fatal error, as this may lead to thread
safety problems.

=
void Foundation::end(void) {
	if (Log::aspect_switched_on(MEMORY_USAGE_DA)) Memory::log_statistics();
	Log::close();
	Memory::free();
}
