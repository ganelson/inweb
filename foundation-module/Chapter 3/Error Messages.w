[Errors::] Error Messages.

A basic system for command-line tool error messages.

@h Errors handler.
The user can provide a routine to deal with error messages before they're
issued. If this returns |FALSE|, nothing is printed to |stderr|.

=
int (*errors_handler)(text_stream *, int) = NULL;
void (*internal_errors_handler)(void *, char *, char *, int) = NULL;

void Errors::set_handler(int (*f)(text_stream *, int)) {
	errors_handler = f;
}
void Errors::set_internal_handler(void (*f)(void *, char *, char *, int)) {
	internal_errors_handler = f;
}

int problem_count = 0;
int Errors::have_occurred(void) {
	if (problem_count > 0) return TRUE;
	return FALSE;
}

void Errors::issue(text_stream *message, int fatality) {
	int rv = TRUE;
	if (errors_handler) rv = (*errors_handler)(message, fatality);
	if (rv) WRITE_TO(STDERR, "%S", message);
	if (fatality) Errors::die(); else problem_count++;
}

@h Error messages.
Ah, they kill you; or they don't. The fatal kind cause an exit code of 2, to
distinguish this from a proper completion in which non-fatal errors occur.
These two routines (alone) can be caused by failures of the memory allocation
or streams systems, and therefore must be written with a little care to use
the temporary stream, not some other string which might need fresh allocation.

=
void Errors::fatal(char *message) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: fatal error: %s\n", INTOOL_NAME, message);
	Errors::issue(ERM, TRUE);
	DISCARD_TEXT(ERM)
}

void Errors::fatal_with_C_string(char *message, char *parameter) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: fatal error: ", INTOOL_NAME);
	WRITE_TO(ERM, message, parameter);
	WRITE_TO(ERM, "\n");
	Errors::issue(ERM, TRUE);
	DISCARD_TEXT(ERM)
}

void Errors::fatal_with_text(char *message, text_stream *parameter) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: fatal error: ", INTOOL_NAME);
	WRITE_TO(ERM, message, parameter);
	WRITE_TO(ERM, "\n");
	Errors::issue(ERM, TRUE);
	DISCARD_TEXT(ERM)
}

void Errors::fatal_with_file(char *message, filename *F) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: fatal error: %s: %f\n", INTOOL_NAME, message, F);
	Errors::issue(ERM, TRUE);
	DISCARD_TEXT(ERM)
}

void Errors::fatal_with_path(char *message, pathname *P) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: fatal error: %s: %p\n", INTOOL_NAME, message, P);
	Errors::issue(ERM, TRUE);
	DISCARD_TEXT(ERM)
}

@ Assertion failures lead to the following:

@d internal_error(message) Errors::internal_error_handler(NULL, message, __FILE__, __LINE__)

=
void Errors::internal_error_handler(void *p, char *message, char *f, int lc) {
	if (internal_errors_handler)
		(*internal_errors_handler)(p, message, f, lc);
	else
		Errors::fatal_with_C_string("internal error (%s)", message);
}

@h Deliberately crashing.
It's sometimes convenient to get a backtrace from the debugger when an error
occurs unexpectedly, and one way to do that is to force a division by zero.
(This is only enabled by |-crash| at the command line and is for debugging only.)

=
int debugger_mode = FALSE;
void Errors::enter_debugger_mode(void) {
	debugger_mode = TRUE;
	printf("(Debugger mode enabled: will crash on fatal errors)\n");
}

void Errors::die(void) { /* as void as it gets */
	if (DL) STREAM_FLUSH(DL);
	if (debugger_mode) {
		WRITE_TO(STDERR, "(crashing intentionally to allow backtrace)\n");
		int to_deliberately_crash = 0;
		printf("%d", 1/to_deliberately_crash);
	}
	/* on a fatal exit, memory isn't freed, because that causes threading problems */
	exit(2);
}

@h Survivable errors.
The trick with error messages is to indicate where they occur, and we can
specify this at three levels of abstraction:

=
void Errors::nowhere(char *message) {
	Errors::in_text_file(message, NULL);
}

void Errors::in_text_file(char *message, text_file_position *here) {
	if (here)
		Errors::at_position(message, here->text_file_filename, here->line_count);
	else
		Errors::at_position(message, NULL, 0);
}

void Errors::in_text_file_S(text_stream *message, text_file_position *here) {
	if (here)
		Errors::at_position_S(message, here->text_file_filename, here->line_count);
	else
		Errors::at_position_S(message, NULL, 0);
}

@ Which funnel through:

=
void Errors::at_position(char *message, filename *file, int line) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: ", INTOOL_NAME);
	if (file) WRITE_TO(ERM, "%f, line %d: ", file, line);
	WRITE_TO(ERM, "%s\n", message);
	Errors::issue(ERM, FALSE);
	DISCARD_TEXT(ERM)
}

void Errors::at_position_S(text_stream *message, filename *file, int line) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: ", INTOOL_NAME);
	if (file) WRITE_TO(ERM, "%f, line %d: ", file, line);
	WRITE_TO(ERM, "%S\n", message);
	Errors::issue(ERM, FALSE);
	DISCARD_TEXT(ERM)
}

@ Lastly:

=
void Errors::with_file(char *message, filename *F) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: %f: %s\n", INTOOL_NAME, F, message);
	Errors::issue(ERM, FALSE);
	DISCARD_TEXT(ERM)
}

void Errors::with_text(char *message, text_stream *T) {
	TEMPORARY_TEXT(ERM)
	WRITE_TO(ERM, "%s: ", INTOOL_NAME);
	WRITE_TO(ERM, message, T);
	WRITE_TO(ERM, "\n");
	Errors::issue(ERM, FALSE);
	DISCARD_TEXT(ERM)
}
