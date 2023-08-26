[TextFiles::] Text Files.

To read text files of whatever flavour, one line at a time.

@h Text files.
Foundation was written mainly to support command-line tools which, of their
nature, deal with a lot of text files: source code of programs, configuration
files, HTML, XML and so on. The main aim of this section is to provide a
standard way to read in and iterate through lines of a text file.

First, though, here is a perhaps clumsy but effective way to test if a
file actually exists on disc at a given filename. Note that under the C standard,
it's entirely legal for |fopen| to behave more or less as it likes if asked to
open a directory as a file; and on MacOS, it sometimes opens a directory exactly
as if it were an empty text file. The safest way to ensure that a directory is
never confused with a file seems to be to try |opendir| on it, and the following
does essentially that.

=
int TextFiles::exists(filename *F) {
	TEMPORARY_TEXT(pn)
	WRITE_TO(pn, "%f", F);
	scan_directory *D = Directories::open_from(pn);
	DISCARD_TEXT(pn)
	if (D) {
		Directories::close(D);
		return FALSE;
	}
	FILE *HANDLE = Filenames::fopen(F, "rb");
	if (HANDLE == NULL) return FALSE;
	fclose(HANDLE);
	return TRUE;
}

@h Text file positions.
Here's how we record a position in a text file:

=
typedef struct text_file_position {
	struct filename *text_file_filename;
	FILE *handle_when_open;
	struct unicode_file_buffer ufb;
	int line_count; /* counting from 1 */
	int line_position;
	int skip_terminator;
	int actively_scanning; /* whether we are still interested in the rest of the file */
} text_file_position;

@ For access:

=
int TextFiles::get_line_count(text_file_position *tfp) {
	if (tfp == NULL) return 0;
	return tfp->line_count;
}

@ And this is for a real nowhere man:

=
text_file_position TextFiles::nowhere(void) {
	text_file_position tfp;
	tfp.text_file_filename = NULL;
	tfp.line_count = 0;
	tfp.line_position = 0;
	tfp.skip_terminator = FALSE;
	tfp.actively_scanning = FALSE;
	return tfp;
}

text_file_position TextFiles::at(filename *F, int line) {
	text_file_position tfp = TextFiles::nowhere();
	tfp.text_file_filename = F;
	tfp.line_count = line;
	return tfp;
}

@h Text file scanner.
We read lines in, delimited by any of the standard line-ending characters,
and send them one at a time to a function called |iterator|. Throughout,
we preserve a pointer called |state| to some object being used by the
client.

=
int TextFiles::read(filename *F, int escape_oddities, char *message, int serious,
	void (iterator)(text_stream *, text_file_position *, void *),
	text_file_position *start_at, void *state) {
	text_file_position tfp;
	if (escape_oddities) tfp.ufb = TextFiles::create_filtered_ufb(UNICODE_UFBHM);
	else tfp.ufb = TextFiles::create_ufb();
	@<Open the text file@>;
	@<Set the initial position, seeking it in the file if need be@>;
	@<Read in lines and send them one by one to the iterator@>;
	fclose(tfp.handle_when_open);
	return tfp.line_count;
}

@<Open the text file@> =
	tfp.handle_when_open = Filenames::fopen(F, "rb");
	if (tfp.handle_when_open == NULL) {
		if (message == NULL) return 0;
		if (serious) Errors::fatal_with_file(message, F);
		else { Errors::with_file(message, F); return 0; }
	}

@ The ANSI definition of |ftell| and |fseek| says that, with text files, the
only definite position value is 0 -- meaning the beginning of the file -- and
this is what we initialise |line_position| to. We must otherwise only write
values returned by |ftell| into this field.

@<Set the initial position, seeking it in the file if need be@> =
	if (start_at == NULL) {
		tfp.line_count = 1;
		tfp.line_position = 0;
		tfp.skip_terminator = 'X';
	} else {
		tfp = *start_at;
		if (fseek(tfp.handle_when_open, (long int) (tfp.line_position), SEEK_SET)) {
			if (serious) Errors::fatal_with_file("unable to seek position in file", F);
			Errors::with_file("unable to seek position in file", F);
			return 0;
		}
	}
	tfp.actively_scanning = TRUE;
	tfp.text_file_filename = F;

@ We aim to get this right whether the lines are terminated by |0A|, |0D|,
|0A 0D| or |0D 0A|. The final line is not required to be terminated.

@<Read in lines and send them one by one to the iterator@> =
	TEMPORARY_TEXT(line)
	int i = 0, c = ' ';
	while ((c != EOF) && (tfp.actively_scanning)) {
		c = TextFiles::utf8_fgetc(tfp.handle_when_open, NULL, &tfp.ufb);
		if ((c == EOF) || (c == '\x0a') || (c == '\x0d')) {
			Str::put_at(line, i, 0);
			if ((i > 0) || (c != tfp.skip_terminator)) {
				@<Feed the completed line to the iterator routine@>;
				if (c == '\x0a') tfp.skip_terminator = '\x0d';
				if (c == '\x0d') tfp.skip_terminator = '\x0a';
			} else tfp.skip_terminator = 'X';
			@<Update the text file position@>;
			i = 0;
		} else {
			Str::put_at(line, i++, (wchar_t) c);
		}
	}
	if ((i > 0) && (tfp.actively_scanning))
		@<Feed the completed line to the iterator routine@>;
	DISCARD_TEXT(line)

@ We update the line counter only when a line is actually sent:

@<Feed the completed line to the iterator routine@> =
	iterator(line, &tfp, state);
	tfp.line_count++;

@ But we update the text file position after every apparent line terminator.
This is because we might otherwise, on a Windows text file, end up with an
|ftell| position in between the |CR| and the |LF|; if we resume at that point,
later on, we'll then have an off-by-one error in the line numbering in the
resumption as compared to during the original pass.

Properly speaking, |ftell| returns a long |int|, not an |int|, but on a
32-bit-or-more integer machine, this gives us room for files to run to 2GB.
Text files seldom come that large.

@<Update the text file position@> =
	tfp.line_position = (int) (ftell(tfp.handle_when_open));
	if (tfp.line_position == -1) {
		if (serious)
			Errors::fatal_with_file("unable to determine position in file", F);
		else
			Errors::with_file("unable to determine position in file", F);
	}

@ =
void TextFiles::read_line(OUTPUT_STREAM, int escape_oddities, text_file_position *tfp) {
	Str::clear(OUT);
	int i = 0, c = ' ';
	while ((c != EOF) && (tfp->actively_scanning)) {
		c = TextFiles::utf8_fgetc(tfp->handle_when_open, NULL, &tfp->ufb);
		if ((c == EOF) || (c == '\x0a') || (c == '\x0d')) {
			Str::put_at(OUT, i, 0);
			if ((i > 0) || (c != tfp->skip_terminator)) {
				if (c == '\x0a') tfp->skip_terminator = '\x0d';
				if (c == '\x0d') tfp->skip_terminator = '\x0a';
			} else tfp->skip_terminator = 'X';
			tfp->line_position = (int) (ftell(tfp->handle_when_open));
			i = 0;
			tfp->line_count++; return;
		}
		Str::put_at(OUT, i++, (wchar_t) c);
	}
	if ((i > 0) && (tfp->actively_scanning)) tfp->line_count++;
}

@ The routine being iterated can indicate that it has had enough by
calling the following:

=
void TextFiles::lose_interest(text_file_position *tfp) {
	tfp->actively_scanning = FALSE;
}

@h Reading UTF-8 files.
The following routine reads a sequence of Unicode characters from a UTF-8
encoded file, but returns them as a sequence of ISO Latin-1 characters, a
trick it can only pull off by escaping non-ISO characters. This is done by
taking character number |N| and feeding it out, one character at a time, as
the text |[unicode N]|, writing the number in decimal. Only one UTF-8
file like this will be being read at a time, and the routine will be
repeatedly called until |EOF| or a line division.

Strictly speaking, we transmit not as ISO Latin-1 but as that subset of ISO
which have corresponding (different) codes in the ZSCII character set. This
excludes some typewriter symbols and a handful of letterforms, as we shall
see.

There are two exceptions: |TextFiles::utf8_fgetc| can also return the usual C
end-of-file pseudo-character |EOF|, and it can also return the Unicode BOM
(byte-ordering marker) pseudo-character, which is legal at the start of a
file and which is automatically prepended by some text editors and
word-processors when they save a UTF-8 file (though in fact it is not
required by the UTF-8 specification). Anyone calling |TextFiles::utf8_fgetc| must
check the return value for |EOF| every time, and for |0xFEFF| every time we
might be at the start of the file being read.

@e NONE_UFBHM from 1
@e ZSCII_UFBHM
@e UNICODE_UFBHM

=
typedef struct unicode_file_buffer {
	char unicode_feed_buffer[32]; /* holds a single escape such as "[unicode 3106]" */
	int ufb_counter; /* position in the unicode feed buffer */
	int handling_mode; /* one of the above */
} unicode_file_buffer;

unicode_file_buffer TextFiles::create_ufb(void) {
	unicode_file_buffer ufb;
	ufb.ufb_counter = -1;
	ufb.handling_mode = NONE_UFBHM;
	return ufb;
}

unicode_file_buffer TextFiles::create_filtered_ufb(int mode) {
	unicode_file_buffer ufb = TextFiles::create_ufb();
	ufb.handling_mode = mode;
	return ufb;
}

int TextFiles::utf8_fgetc(FILE *from, const char **or_from, unicode_file_buffer *ufb) {
	int c = EOF, conts, mode = (ufb)?ufb->handling_mode:NONE_UFBHM;
	if ((ufb) && (ufb->ufb_counter >= 0)) {
		if (ufb->unicode_feed_buffer[ufb->ufb_counter] == 0) ufb->ufb_counter = -1;
		else return ufb->unicode_feed_buffer[ufb->ufb_counter++];
	}
	if (from) c = fgetc(from); else if (or_from) c = ((unsigned char) *((*or_from)++));
	if (c == EOF) return c; /* ruling out EOF leaves a genuine byte from the file */
	if (c<0x80) return c; /* in all other cases, a UTF-8 continuation sequence begins */

	@<Unpack one to five continuation bytes to obtain the Unicode character code@>;
	if (c == 0xFEFF) return c; /* the Unicode BOM non-character */

    if (mode != NONE_UFBHM) @<Return Unicode fancy equivalents as simpler literals@>;

	if (mode == ZSCII_UFBHM) {
	    @<Return non-ASCII codes in the intersection of ISO Latin-1 and ZSCII as literals@>;
		if (ufb) {
			sprintf(ufb->unicode_feed_buffer, "[unicode %d]", c);
			ufb->ufb_counter = 1;
			return '[';
		}
		return '?';
	}
	return c;
}

@ Not every byte sequence is legal in a UTF-8 file: if we find a malformed
continuation, we process it as a question mark rather than throwing a
fatal error (which is pretty well the only alternative here). The user
is likely to see problem messages later on which arise from the question
marks, and that will have to do.

@<Unpack one to five continuation bytes to obtain the Unicode character code@> =
    if (c<0xC0) return '?'; /* malformed UTF-8 */
	if (c<0xE0) { c = c & 0x1f; conts = 1; }
	else if (c<0xF0) { c = c & 0xf; conts = 2; }
	else if (c<0xF8) { c = c & 0x7; conts = 3; }
	else if (c<0xFC) { c = c & 0x3; conts = 4; }
	else { c = c & 0x1; conts = 5; }
	while (conts > 0) {
		int d = EOF;
		if (from) d = fgetc(from); else if (or_from) d = ((unsigned char) *((*or_from)++));
		if (d == EOF) return '?'; /* malformed UTF-8 */
		c = c << 6;
		c = c + (d & 0x3F);
		conts--;
	}

@ For the ZSCII character set, see "The Inform 6 Designer's Manual", or
"The Z-Machine Standards Document". It offers a range of west European
accented letters which almost, but not quite, matches those on offer in
ISO Latin-1 -- it omits for example Icelandic lower case eth. (ZSCII was
developed in the 1980s by Infocom, Inc., to encode their interactive
fiction offerings. Had they been collaborating with J. R. R. Tolkien
rather than Douglas Adams, they might have filled this gap. As it was,
"eth" never occurred in any of their works.)

@<Return non-ASCII codes in the intersection of ISO Latin-1 and ZSCII as literals@> =
	if ((c == 0xa1) || (c == 0xa3) || (c == 0xbf)) return c; /* pound sign, inverted ! and ? */
	if ((c >= 0xc0) && (c <= 0xff)) { /* accented West European letters, but... */
		if ((c != 0xd0) && (c != 0xf0) && /* not Icelandic eths */
		    (c != 0xde) && (c != 0xfe) && /* nor Icelandic thorns */
			(c != 0xf7)) /* nor division signs */
			return c;
	}

@ We err on the safe side, accepting em-rules and non-breaking spaces, etc.,
where we would normally expect hyphens and ordinary spaces: this is intended
for the benefit of users with helpful word-processors which autocorrect
hyphens into em-rules when they are flanked by spaces, and so on.

We let the multiplication sign |0xd7| through even though ZSCII doesn't
support it, but convert it to an "x": this is so that we can parse numbers
in scientific notation.

@<Return Unicode fancy equivalents as simpler literals@> =
	if (c == 0x85) return '\x0d'; /* NEL, or "next line" */
	if (c == 0xa0) return ' '; /* non-breaking space */
	if (c == 0xd7) return 'x'; /* convert multiplication sign to lower case "x" */
	if ((c >= 0x2000) && (c <= 0x200a)) return ' '; /* space variants */
	if ((c >= 0x2010) && (c <= 0x2014)) return '-'; /* rules and dashes */
	if ((c >= 0x2018) && (c <= 0x2019)) return '\''; /* smart single quotes */
	if ((c >= 0x201c) && (c <= 0x201d)) return '"'; /* smart double quotes */
	if ((c >= 0x2028) && (c <= 0x2029)) return '\x0d'; /* fancy newlines */

@h Simple text file extraction.
Sometimes all we want is to copy a text file, line by line, into a text stream.
This returns the number of lines read in, which will be 0 if the file does not
exist.

=
int TextFiles::write_file_contents(OUTPUT_STREAM, filename *F) {
	return TextFiles::read(F, FALSE, NULL, FALSE,
		&TextFiles::write_file_contents_helper, NULL, OUT);
}

void TextFiles::write_file_contents_helper(text_stream *text, text_file_position *tfp,
	void *state) {
	text_stream *OUT = (text_stream *) state;
	WRITE("%S\n", text);
}
