[Shell::] Shell.

Sending commands to the shell, on Unix-like platforms, or simulating
this on Windows.

@h Operating system interface.
Some of our programs have to issue commands to the host operating system,
to copy files, pass them through TeX, and so on. All of that is done using
the C standard library |system| function; the commands invoked are all
standard for POSIX, so will work on MacOS and Linux, but on a Windows system
they would need to be read in a POSIX-style environment like Cygwin or MSYS2.

=
void Shell::quote_path(OUTPUT_STREAM, pathname *P) {
	TEMPORARY_TEXT(FN)
	WRITE_TO(FN, "%p", P);
	Shell::quote_text(OUT, FN);
	DISCARD_TEXT(FN)
}

void Shell::quote_file(OUTPUT_STREAM, filename *F) {
	TEMPORARY_TEXT(FN)
	WRITE_TO(FN, "%f", F);
	Shell::quote_text(OUT, FN);
	DISCARD_TEXT(FN)
}

void Shell::plain(OUTPUT_STREAM, char *raw) {
	WRITE("%s", raw);
}

void Shell::plain_text(OUTPUT_STREAM, text_stream *raw) {
	WRITE("%S", raw);
}

void Shell::quote_text(OUTPUT_STREAM, text_stream *raw) {
	PUT(SHELL_QUOTE_CHARACTER);
	LOOP_THROUGH_TEXT(pos, raw) {
		wchar_t c = Str::get(pos);
		if (c == SHELL_QUOTE_CHARACTER) PUT('\\');
		PUT(c);
	}
	PUT(SHELL_QUOTE_CHARACTER);
	PUT(' ');
}

@ The generic shell code to apply |command| to a file |F|:

=
void Shell::apply(char *command, filename *F) {
	TEMPORARY_TEXT(COMMAND)
	Shell::plain(COMMAND, command);
	Shell::plain(COMMAND, " ");
	Shell::quote_file(COMMAND, F);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)
}
void Shell::apply_S(text_stream *command, filename *F) {
	TEMPORARY_TEXT(COMMAND)
	Shell::plain_text(COMMAND, command);
	Shell::plain(COMMAND, " ");
	Shell::quote_file(COMMAND, F);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)
}

@ Applications to using |rm| and |cp|:

=
void Shell::rm(filename *F) {
	Shell::apply("rm", F);
}

void Shell::copy(filename *F, pathname *T, char *options) {
	TEMPORARY_TEXT(COMMAND)
	Shell::plain(COMMAND, "cp ");
	Shell::plain(COMMAND, options);
	Shell::plain(COMMAND, " ");
	Shell::quote_file(COMMAND, F);
	Shell::quote_path(COMMAND, T);
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)
}

@ This writes the traditional Unix shell syntax for redirecting the output
from both |stdout| and |stderr| to the same named file.

=
void Shell::redirect(OUTPUT_STREAM, filename *F) {
	Shell::plain(OUT, ">");
	Shell::quote_file(OUT, F);
	Shell::plain(OUT, "2>&1");
}

@h Actual commands.
The scheme is that commands are composed using the above functions, and
then sent to this one.

We make the buffer here long enough for 8 filenames of worst-case length,
all transcoded to UTF-8 in the most unlucky way imaginable.

@d SPOOL_LENGTH 4*8*MAX_FILENAME_LENGTH

=
int shell_verbosity = FALSE;
void Shell::verbose(void) {
	shell_verbosity = TRUE;
}

int Shell::run(OUTPUT_STREAM) {
	if (shell_verbosity) PRINT("shell: %S\n", OUT);
	LOGIF(SHELL_USAGE, "shell: %S\n", OUT);
	char spool[SPOOL_LENGTH];
	Streams::write_as_locale_string(spool, OUT, SPOOL_LENGTH);
	if (debugger_mode) {
		WRITE_TO(STDOUT, "debugger mode suppressing shell command: %S\n", OUT);
		return 0;
	}
	int rv = Platform::system(spool);
	if (rv == -1) {
		WRITE_TO(STDERR, "shell: %S\n", OUT);
		internal_error("OS shell error");
	}
	if (rv == 127) {
		WRITE_TO(STDERR, "shell: %S\n", OUT);
		internal_error("Execution of the shell failed");
	}
	return rv;
}
