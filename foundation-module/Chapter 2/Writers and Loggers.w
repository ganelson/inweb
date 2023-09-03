[Writers::] Writers and Loggers.

Formatted text output to streams.

@h Registration.
The main function here is modelled on the "minimum |printf|" function
used as an example in Kernighan and Ritchie, Chapter 7, but because it
prints to streams, it combines the traditional functions |printf|, |sprintf|
and |fprintf| in one. It also contains a number of doohickeys to provide
for a wider and extensible range of string interpolations.

Traditionally, in the C library, everything in the formatting string is
literal except for |%| escapes: thus |%d| means "integer goes here", and
so on. We follow this but allow extra |%| escapes unknown to K&R, and we
also allow a further family of |$| escapes intended for the debugging log
only; these are restricted to streams flagged as for debugging and generally
produce guru meditation numbers rather than user-friendly information.

Each escape, say |%z|, must be "registered" before use, and will be
given one of the following categories:

@d VACANT_ECAT 0		/* unregistered */
@d POINTER_ECAT 1		/* data to be printed is a pointer to a structure */
@d INTSIZED_ECAT 2		/* data to be printed is or fits into an integer */
@d WORDING_ECAT 3		/* data to be printed is a |wording| structure from inform7 */
@d DIRECT_ECAT 4		/* data must be printed directly by the code below */

@ We'll start with |%| escapes, which generalise the familiar |printf|
escapes such as |%d|. Cumbersomely, we need three sorts of escape: those where
the variable argument token is a pointer, those where it's essentially an
integer, and those where it's a structure used only in the Inform 7 compiler
called a |wording|. The standard C typechecker can't generalise across these,
so we have to do everything three times. (And then we have to do all that twice,
because the loggers don't use format strings.)

=
int escapes_registered = FALSE;
int escapes_category[2][128]; /* one of the |*_ECAT| values above */
void *the_escapes[2][128]; /* the function to call to implement this */

typedef void (*writer_function)(text_stream *, char *, void *);
typedef void (*writer_function_I)(text_stream *, char *, int);
typedef void (*log_function)(text_stream *, void *);
typedef void (*log_function_I)(text_stream *, int);
#ifdef WORDS_MODULE
	typedef void (*writer_function_W)(text_stream *, char *, wording);
	typedef void (*log_function_W)(text_stream *, wording);
#endif

@ =
void Writers::log_escape_usage(void) {
	for (int cat = 0; cat < 2; cat++) {
		char *alphanum = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
		LOG("Vacant escapes: %s: ", (cat == 0)?"%":"$");
		for (int i=0; alphanum[i]; i++)
			if (escapes_category[cat][(int) alphanum[i]] == VACANT_ECAT)
				LOG("%c", alphanum[i]);
			else
				LOG(".");
		LOG("\n");
	}
}

@ That gives us a number of front doors:

=
void Writers::register_writer(int esc, void (*f)(text_stream *, char *, void *)) {
	Writers::register_writer_p(0, esc, (void *) f, POINTER_ECAT);
}
void Writers::register_logger(int esc, void (*f)(text_stream *, void *)) {
	Writers::register_writer_p(1, esc, (void *) f, POINTER_ECAT);
}
void Writers::register_writer_I(int esc, void (*f)(text_stream *, char *, int)) {
	Writers::register_writer_p(0, esc, (void *) f, INTSIZED_ECAT);
}
void Writers::register_logger_I(int esc, void (*f)(text_stream *, int)) {
	Writers::register_writer_p(1, esc, (void *) f, INTSIZED_ECAT);
}
#ifdef WORDS_MODULE
#define Writers::register_writer_W(esc, f) Writers::register_writer_p(0, esc, (void *) f, WORDING_ECAT);
#define Writers::register_logger_W(esc, f) Writers::register_writer_p(1, esc, (void *) f, WORDING_ECAT);
#endif

@ All leading to:

=
void Writers::register_writer_p(int set, int esc, void *f, int cat) {
	if (escapes_registered == FALSE) @<Initialise the table of escapes@>;
	if ((esc < 0) || (esc >= 128) ||
		((Characters::isalpha((inchar32_t) esc) == FALSE) &&
			(Characters::isdigit((inchar32_t) esc) == FALSE)))
		internal_error("nonalphabetic escape");
	if (escapes_category[set][esc] != VACANT_ECAT) {
		WRITE_TO(STDERR, "Clashing escape is %s%c\n", (set == 0)?"%":"$", esc);
		internal_error("clash of escapes");
	}
	escapes_category[set][esc] = cat;
	the_escapes[set][esc] = f;
}

@ We're going to implement |%d| and a few others directly, so those are marked
in the table as being unavailable for registration.

Note that we don't support |%f| for floats; but we do add our very own |%w|
for wide strings.

@<Initialise the table of escapes@> =
	escapes_registered = TRUE;
	for (int e=0; e<2; e++)
		for (int i=0; i<128; i++) {
			the_escapes[e][i] = NULL; escapes_category[e][i] = VACANT_ECAT;
		}
	escapes_category[0]['c'] = DIRECT_ECAT;
	escapes_category[0]['d'] = DIRECT_ECAT;
	escapes_category[0]['g'] = DIRECT_ECAT;
	escapes_category[0]['i'] = DIRECT_ECAT;
	escapes_category[0]['s'] = DIRECT_ECAT;
	escapes_category[0]['w'] = DIRECT_ECAT;
	escapes_category[0]['x'] = DIRECT_ECAT;
	escapes_category[0]['%'] = DIRECT_ECAT;
	escapes_category[0]['$'] = DIRECT_ECAT;
	escapes_category[1]['%'] = DIRECT_ECAT;
	escapes_category[1]['$'] = DIRECT_ECAT;

@h Writing.
We can finally get on with that formatted-print function we've all been
waiting for:

=
void Writers::printf(text_stream *stream, char *fmt, ...) {
	va_list ap; /* the variable argument list signified by the dots */
	char *p;
	if (stream == NULL) return;
	va_start(ap, fmt); /* macro to begin variable argument processing */
	for (p = fmt; *p; p++) {
		switch (*p) {
			case '%': {
				int set = 0; @<Deal with escape sequences@>;
				break;
			}
			case '$': {
				int set = 1;
				if ((stream->stream_flags) & USES_LOG_ESCAPES_STRF)
					@<Deal with escape sequences@>
				else Streams::putc('$', stream);
				break;
			}
			case '"':
				if (stream->stream_flags & USES_I6_ESCAPES_STRF)
					Streams::putc('~', stream);
				else Streams::putci(*p, stream);
				break;
			case '\n':
				Streams::putci(*p, stream);
				break;
			default: Streams::putci(*p, stream); break;
		}
	}
	va_end(ap); /* macro to end variable argument processing */
}

@<Deal with escape sequences@> =
	char format_string[8];
	int esc_number = ' ';
	int i = 0;
	format_string[i++] = *(p++);
	while (*p) {
		format_string[i++] = *p;
		if ((islower(*p)) || (isupper(*p)) || ((set == 1) && (isdigit(*p))) ||
			(*p == '%')) esc_number = (int) *p;
		p++;
		if ((esc_number != ' ') || (i==6)) break;
	}
	format_string[i] = 0; p--;
	if ((esc_number<0) || (esc_number > 255)) esc_number = 0;
	switch (escapes_category[set][esc_number]) {
		case POINTER_ECAT: {
			if (set == 0) {
				writer_function f = (writer_function) the_escapes[0][esc_number];
				void *q = va_arg(ap, void *);
				(*f)(stream, format_string+1, q);
			} else {
				log_function f = (log_function) the_escapes[1][esc_number];
				void *q = va_arg(ap, void *);
				(*f)(stream, q);
			}
			break;
		}
		case INTSIZED_ECAT: {
			if (set == 0) {
				writer_function_I f = (writer_function_I) the_escapes[0][esc_number];
				int N = va_arg(ap, int);
				(*f)(stream, format_string+1, N);
			} else {
				log_function_I f = (log_function_I) the_escapes[1][esc_number];
				int N = va_arg(ap, int);
				(*f)(stream, N);
			}
			break;
		}
		case WORDING_ECAT: {
			#ifdef WORDS_MODULE
			if (set == 0) {
				writer_function_W f = (writer_function_W) the_escapes[0][esc_number];
				wording W = va_arg(ap, wording);
				(*f)(stream, format_string+1, W);
			} else {
				log_function_W f = (log_function_W) the_escapes[1][esc_number];
				wording W = va_arg(ap, wording);
				(*f)(stream, W);
			}
			#endif
			break;
		}
		case DIRECT_ECAT: @<Implement this using the original printf@>; break;
		case VACANT_ECAT:
			WRITE_TO(STDERR, "*** Bad WRITE escape: <%s> ***\n", format_string);
			internal_error("Unknown string escape");
			break;
	}

@ Here the traditional C library helps us out with the difficult ones to get
right. We don't trouble to check that correct |printf| escapes have been used:
instead, we pass anything in the form of a percentage sign, followed by
up to four nonalphabetic modifying characters, followed by an alphabetic
category character for numerical printing, straight through to |sprintf|
or |fprintf|.

Thus an escape like |%04d| is handled by the standard C library, but not
|%s|, which we handle directly. That's for two reasons: first, we want to
be careful to prevent overruns of memory streams; second, we need to ensure
that the correct encoding is used when writing to disc. The numerical
escapes involve only characters whose representation is the same in all our
file encodings, but expanding |%s| does not.

@<Implement this using the original printf@> =
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wformat-nonliteral"
	switch (esc_number) {
		case 'c': { /* |char| is promoted to |int| in variable arguments */
			int ival = va_arg(ap, int);
			Streams::putci(ival, stream);
			break;
		}
		case 'd': case 'i': case 'x': {
			int ival = va_arg(ap, int);
			char temp[256];
			if (snprintf(temp, 255, format_string, ival) >= 255) strcpy(temp, "?");
			for (int j = 0; temp[j]; j++) Streams::putci(temp[j], stream);
			break;
		}
		case 'g': {
			double dval = va_arg(ap, double);
			char temp[256];
			if (snprintf(temp, 255, format_string, dval) >= 255) strcpy(temp, "?");
			for (int j = 0; temp[j]; j++) Streams::putci(temp[j], stream);
			break;
		}
		case 's':
			for (char *sval = va_arg(ap, char *); *sval; sval++) Streams::putci(*sval, stream);
			break;
		case 'w': {
			inchar32_t *W = (inchar32_t *) va_arg(ap, inchar32_t *);
			for (int j = 0; W[j]; j++) Streams::putc(W[j], stream);
			break;
		}
		case '%': Streams::putc('%', stream); break;
		case '$': Streams::putc('$', stream); break;
	}
	#pragma clang diagnostic pop

@h Abbreviation macros.
The following proved convenient for Inform, at any rate.

@d REGISTER_WRITER(c, f) Writers::register_logger(c, &f##_writer);
@d COMPILE_WRITER(t, f)
	void f##_writer(text_stream *format, void *obj) { text_stream *SDL = DL; DL = format; if (DL) f((t) obj); DL = SDL; }

@d REGISTER_WRITER_I(c, f) Writers::register_logger_I(c, &f##_writer);
@d COMPILE_WRITER_I(t, f)
	void f##_writer(text_stream *format, int I) { text_stream *SDL = DL; DL = format; if (DL) f((t) I); DL = SDL; }
