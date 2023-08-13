[Markdown::] Markdown.

To parse a simplified form of the Markdown markup notation, and render the
result in HTML.

@ The following is a simple approach which implements only code samples in
backticks and emphasis, but it follows CommonMark rules and correctly handles
its examples. I am indebted to //CM v0.30 -> https://spec.commonmark.org/0.30//.

@h Tree. We will parse a paragraph of MD content into a tree made of this fairly
lightweight node:

@e PARAGRAPH_MIT from 1
@e MATERIAL_MIT
@e PLAIN_MIT
@e EMPHASIS_MIT
@e STRONG_MIT
@e CODE_MIT
@e URI_AUTOLINK_MIT
@e EMAIL_AUTOLINK_MIT
@e INLINE_HTML_MIT
@e LINE_BREAK_MIT
@e SOFT_BREAK_MIT
@e LINK_MIT
@e IMAGE_MIT
@e LINK_DEST_MIT
@e LINK_TITLE_MIT

=
typedef struct markdown_item {
	int type; /* one of the |*_MIT| types above */
	struct text_stream *sliced_from;
	int from;
	int to;
	struct markdown_item *next;
	struct markdown_item *down;
	struct markdown_item *copied_from;
	int cycle_count; /* used only for tracing the tree when debugging */
	int id; /* used only for tracing the tree when debugging */
	CLASS_DEFINITION
} markdown_item;

int md_ids = 1;
markdown_item *Markdown::new_item(int type) {
	markdown_item *md = CREATE(markdown_item);
	md->type = type;
	md->sliced_from = NULL; md->from = 0; md->to = -1;
	md->next = NULL; md->down = NULL;
	md->cycle_count = 0;
	md->id = md_ids++;
	md->copied_from = NULL;
	return md;
}

@ A "slice" contains a snipped of text, where by convention the portion is
from character positions |from| to |to| inclusive. If |to| is less than |from|,
it represents the empty snippet.

=
markdown_item *Markdown::new_slice(int type, text_stream *text, int from, int to) {
	markdown_item *md = Markdown::new_item(type);
	md->sliced_from = text;
	md->from = from;
	md->to = to;
	return md;
}

@ A deep copy of the tree handing from node |md|:

=
markdown_item *Markdown::deep_copy(markdown_item *md) {
	markdown_item *copied = Markdown::new_item(md->type);
	if (Str::len(md->sliced_from) > 0) {
		copied->sliced_from = Str::duplicate(md->sliced_from);
	}
	copied->from = md->from;
	copied->to = md->to;
	copied->copied_from = md;
	for (markdown_item *c = md->down; c; c = c->next)
		Markdown::add_to(Markdown::deep_copy(c), copied);
	return copied;
}

@ Enough of creation. The following makes |md| the latest child of |owner|:

=
void Markdown::add_to(markdown_item *md, markdown_item *owner) {
	md->next = NULL;
	if (owner->down == NULL) { owner->down = md; return; }
	for (markdown_item *ch = owner->down; ch; ch = ch->next)
		if (ch->next == NULL) { ch->next = md; return; }
}

@h Characters and escapes.
Properly this should include also non-ASCII Unicode characters of category Zs.

=
int Markdown::is_Unicode_whitespace(wchar_t c) {
	if (c == 0x0009) return TRUE;
	if (c == 0x000A) return TRUE;
	if (c == 0x000C) return TRUE;
	if (c == 0x000D) return TRUE;
	if (c == 0x0020) return TRUE;
	return FALSE;
}

@ Properly this should include also non-ASCII Unicode characters of category
Pc, Pd, Pe, Pf, Pi, Po, or Ps.

=
int Markdown::is_Unicode_punctuation(wchar_t c) {
	return Markdown::is_ASCII_punctuation(c);
}

@ Whereas these are fairly unarguable.

=
int Markdown::is_ASCII_letter(wchar_t c) {
	if ((c >= 'a') && (c <= 'z')) return TRUE;
	if ((c >= 'A') && (c <= 'Z')) return TRUE;
	return FALSE;
}

int Markdown::is_ASCII_digit(wchar_t c) {
	if ((c >= '0') && (c <= '9')) return TRUE;
	return FALSE;
}

int Markdown::is_control_character(wchar_t c) {
	if ((c >= 0x0001) && (c <= 0x001f)) return TRUE;
	if (c == 0x007f) return TRUE;
	return FALSE;
}

int Markdown::is_ASCII_punctuation(wchar_t c) {
	if ((c >= 0x0021) && (c <= 0x002F)) return TRUE;
	if ((c >= 0x003A) && (c <= 0x0040)) return TRUE;
	if ((c >= 0x005B) && (c <= 0x0060)) return TRUE;
	if ((c >= 0x007B) && (c <= 0x007E)) return TRUE;
	return FALSE;
}

@ This is a convenient adaptation of |Str::get_at| which reads from the slice
inside a markdown node. Note that it is able to see characters outside the
range being sliced: this is intentional and is needed for some of the
delimiter-scanning.

=
wchar_t Markdown::get_at(markdown_item *md, int at) {
	if (md == NULL) return 0;
	if (Str::len(md->sliced_from) == 0) return 0;
	return Str::get_at(md->sliced_from, at);
}

@ Markdown uses backslash as an escape character, with double-backslash meaning
a literal backslash. It follows that if a character is preceded by an odd number
of backslashes, it must be escaped; if an even (including zero) it is unescaped.

This function returns a harmless letter for an escaped active character, so
that it can be used to test for unescaped active characters.

=
wchar_t Markdown::get_unescaped(markdown_item *md, int at) {
	wchar_t c = Markdown::get_at(md, at);
	int preceding_backslashes = 0;
	while (Markdown::get_at(md, at - 1 - preceding_backslashes) == '\\')
		preceding_backslashes++;
	if (preceding_backslashes % 2 == 1) return 'a';
	return c;
}

@ An "unescaped run" is a sequence of one or more instances of |of|, which
must be non-zero, which are not escaped with a backslash.

=
int Markdown::unescaped_run(markdown_item *md, int at, wchar_t of) {
	int count = 0;
	while (Markdown::get_unescaped(md, at + count) == of) count++;
	if (Markdown::get_unescaped(md, at - 1) == of) count = 0;
	return count;
}

@h Width.
This function recursively calculates the number of characters of actual text
represented by a subtree.

=
int Markdown::width(markdown_item *md) {
	if (md) {
		int width = 0;
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				wchar_t c = Markdown::get_at(md, i);
				if (c == '\\') i++;
				width++;
			}
		}
		if ((md->type == CODE_MIT) || (md->type == URI_AUTOLINK_MIT) ||
			(md->type == EMAIL_AUTOLINK_MIT) || (md->type == INLINE_HTML_MIT)) {
			for (int i=md->from; i<=md->to; i++) {
				width++;
			}
		}
		if (md->type == LINE_BREAK_MIT) width++;
		if (md->type == SOFT_BREAK_MIT) width++;
		for (markdown_item *c = md->down; c; c = c->next)
			width += Markdown::width(c);
		return width;
	}
	return 0;
}

@h Debugging Markdown trees.
This rather defensively-written code is to print a tree which may be ill-founded
or not, in fact, be a tree at all. That should never happen, but if things which
should never happen never happened, we wouldn't need to debug.

=
int md_db_cycle_count = 1;

void Markdown::render_debug(OUTPUT_STREAM, markdown_item *md) {
	md_db_cycle_count++;
	Markdown::render_debug_r(OUT, md);
}

void Markdown::render_debug_r(OUTPUT_STREAM, markdown_item *md) {
	if (md) {
		WRITE("M%d ", md->id);
		if (md->cycle_count == md_db_cycle_count) {
			WRITE("AGAIN!\n");
			return;
		}
		md->cycle_count = md_db_cycle_count;
		switch (md->type) {
			case PARAGRAPH_MIT:      WRITE("PARAGRAPH");          break;
			case MATERIAL_MIT:       WRITE("MATERIAL");           break;
			case PLAIN_MIT:          WRITE("PLAIN");              @<Debug text@>; break;
			case EMPHASIS_MIT:       WRITE("EMPHASIS");           break;
			case STRONG_MIT:         WRITE("STRONG");             break;
			case LINK_MIT:           WRITE("LINK");               break;
			case IMAGE_MIT:          WRITE("IMAGE");              break;
			case LINK_DEST_MIT:      WRITE("LINK_DEST");          break;
			case LINK_TITLE_MIT:     WRITE("LINK_TITLE");         break;
			case CODE_MIT:           WRITE("CODE");               @<Debug text@>; break;
			case URI_AUTOLINK_MIT:   WRITE("URI_AUTOLINK");       @<Debug text@>; break;
			case EMAIL_AUTOLINK_MIT: WRITE("EMAIL_AUTOLINK");     @<Debug text@>; break;
			case INLINE_HTML_MIT:    WRITE("INLINE_HTML");        @<Debug text@>; break;
			case LINE_BREAK_MIT:     WRITE("LINE_BREAK");         break;
			case SOFT_BREAK_MIT:     WRITE("SOFT_BREAK");         break;
		}
		WRITE("\n");
		INDENT;
		for (markdown_item *c = md->down; c; c = c->next)
			Markdown::render_debug_r(OUT, c);
		OUTDENT;
	}
}

@<Debug text@> =
	WRITE("(%d, %d) from (%d, %d) = '", md->from, md->to, 0, Str::len(md->sliced_from) -1);
	for (int i = md->from; i <= md->to; i++) PUT(Str::get_at(md->sliced_from, i));
	WRITE("'");

@h Parsing.
The user should call |Markdown::parse(text)| on the body of a paragraph of
running text which may have Markdown notation in it, and obtains a tree.
No errors are ever issued: a unique feature of Markdown is that all inputs
are always legal.

=
int tracing_Markdown_parser = FALSE;
void Markdown::set_tracing(int state) {
	tracing_Markdown_parser = state;
}

markdown_item *Markdown::parse_paragraph(text_stream *text) {
	markdown_item *passage = Markdown::new_item(PARAGRAPH_MIT);
	passage->down = Markdown::parse(text);
	return passage;
}

markdown_item *Markdown::parse(text_stream *text) {
	markdown_item *passage = Markdown::new_item(MATERIAL_MIT);
	Markdown::parse_inline_matter(passage, text);
	return passage;
}

@ So, then, this takes the stretch of running text in |text| and parses it
into nodes which become the newest children of |owner|.

=
void Markdown::parse_inline_matter(markdown_item *owner, text_stream *text) {
	@<First pass: top-level inline items@>;
	@<Second pass: link and image inline items@>;
	@<Third pass: emphasis inline items@>;
}

@h Inline code.
At the top level, the inline items are code snippets, autolinks and raw HTML.
"Code spans, HTML tags, and autolinks have the same precedence", so we will
scan left to right.

@<First pass: top-level inline items@> =
	int i = 0;
	while (Str::get_at(text, i) == ' ') i++;
	int from = i;
	for (; i<Str::len(text); i++) {
		@<Does a backtick begin here?@>;
		@<Does an autolink begin here?@>;
		@<Does a raw HTML tag begin here?@>;
		@<Does a hard or soft line break occur here?@>;
		ContinueOuter: ;
	}
	if (from <= Str::len(text)-1) {
		int to = Str::len(text)-1;
		while (Str::get_at(text, to) == ' ') to--;
		if (to >= from) {
			markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, to);
			Markdown::add_to(md, owner);
		}
	}

@ See CommonMark 6.1: "A backtick string is a string of one or more backtick
characters that is neither preceded nor followed by a backtick." This returns
the length of a backtick string beginning at |at|, if one does, or 0 if it
does not.

=
int Markdown::backtick_string(text_stream *text, int at) {
	int count = 0;
	while (Str::get_at(text, at + count) == '`') count++;
	if (count == 0) return 0;
	if ((at > 0) && (Str::get_at(text, at - 1) == '`')) return 0;
	return count;
}

@<Does a backtick begin here?@> =
	int count = Markdown::backtick_string(text, i);
	if (count > 0) {
		for (int j=i+count+1; j<Str::len(text); j++) {
			if (Markdown::backtick_string(text, j) == count) {
				if (i-1 >= from) {
					markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
					Markdown::add_to(md, owner);
				}
				@<Insert an inline code item@>;
				i = j+count; from = j+count;
				goto ContinueOuter;
			}
		}
	}

@ "The contents of the code span are the characters between these two backtick strings".
Inside it, "line endings are converted to spaces", and "If the resulting string
both begins and ends with a space character, but does not consist entirely of
space characters, a single space character is removed from the front and back."

@<Insert an inline code item@> =
	int start = i+count, end = j-1;
	text_stream *codespan = Str::new();
	int all_spaces = TRUE;
	for (int k=start; k<=end; k++) {
		wchar_t c = Str::get_at(text, k);
		if (c == '\n') c = ' ';
		if (c != ' ') all_spaces = FALSE;
		PUT_TO(codespan, c);
	}
	if ((all_spaces == FALSE) && (Str::get_first_char(codespan) == ' ')
		 && (Str::get_last_char(codespan) == ' ')) {
		markdown_item *md = Markdown::new_slice(CODE_MIT, codespan, 1, Str::len(codespan)-2);
		Markdown::add_to(md, owner);		 
	} else {
		markdown_item *md = Markdown::new_slice(CODE_MIT, codespan, 0, Str::len(codespan)-1);
		Markdown::add_to(md, owner);
	}

@<Does an autolink begin here?@> =
	if (Str::get_at(text, i) == '<') {
		for (int j=i+1; j<Str::len(text); j++) {
			wchar_t c = Str::get_at(text, j);
			if (c == '>') {
				int link_from = i+1, link_to = j-1, count = j-i+1;
				if (tracing_Markdown_parser) {
					text_stream *OUT = STDOUT;
					WRITE("Investigating potential autolink: ");
					for (int k=i; k<=j; k++) PUT(Str::get_at(text, k));
					WRITE("\n");
				}
				@<Test for URI autolink@>;
				@<Test for email autolink@>;
				break;
			}
			if ((c == '<') ||
				(Markdown::is_Unicode_whitespace(c)) ||
				(Markdown::is_control_character(c)))
				break;
		}
	}

@ "A URI autolink consists of... a scheme followed by a colon followed by zero
or more characters other than ASCII control characters, space, <, and >... a
scheme is any sequence of 2–32 characters beginning with an ASCII letter and
followed by any combination of ASCII letters, digits, or the symbols plus,
period, or hyphen."

@<Test for URI autolink@> =
	int colon_at = -1;
	for (int k=link_from; k<=link_to; k++) if (Str::get_at(text, k) == ':') { colon_at = k; break; }
	if (colon_at >= 0) {
		int scheme_valid = TRUE;
		@<Vet the scheme@>;
		int link_valid = TRUE;
		@<Vet the link@>;
		if ((scheme_valid) && (link_valid)) {
			if (i-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(URI_AUTOLINK_MIT,
				text, link_from, link_to);
			Markdown::add_to(md, owner);
			i = j+count; from = j+count;
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found URI\n");
			goto ContinueOuter;			
		} else if (tracing_Markdown_parser) {
			if (scheme_valid == FALSE) WRITE_TO(STDOUT, "Colon suggested URI but scheme invalid\n");
			if (link_valid == FALSE) WRITE_TO(STDOUT, "Colon suggested URI but link invalid\n");
		}
	} else {
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Not a URI: no colon\n");
	}

@<Vet the scheme@> =
	int scheme_length = colon_at - link_from;
	if ((scheme_length < 2) || (scheme_length > 32)) scheme_valid = FALSE;
	for (int i=link_from; i<colon_at; i++) {
		wchar_t c = Str::get_at(text, i);
		if (!((Markdown::is_ASCII_letter(c)) ||
			((i > link_from) &&
				((Markdown::is_ASCII_digit(c)) || (c == '+') || (c == '-') || (c == '.')))))
			scheme_valid = FALSE;
	}

@<Vet the link@> =
	for (int i=colon_at+1; i<=link_to; i++) {
		wchar_t c = Str::get_at(text, i);
		if ((c == '<') || (c == '>') || (c == ' ') ||
			(Markdown::is_control_character(c)))
			link_valid = FALSE;
	}

@<Test for email autolink@> =
	int atsign_at = -1;
	for (int k=link_from; k<=link_to; k++) if (Str::get_at(text, k) == '@') { atsign_at = k; break; }
	if (atsign_at >= 0) {
		int username_valid = TRUE;
		@<Vet the username@>;
		int domain_valid = TRUE;
		@<Vet the domain name@>;
		if ((username_valid) && (domain_valid)) {
			if (i-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(EMAIL_AUTOLINK_MIT,
				text, link_from, link_to);
			Markdown::add_to(md, owner);
			i = j+count; from = j+count;
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found email\n");
			goto ContinueOuter;			
		} else if (tracing_Markdown_parser) {
			if (username_valid == FALSE) WRITE_TO(STDOUT, "At suggested email but username invalid\n");
			if (domain_valid == FALSE) WRITE_TO(STDOUT, "At suggested email but domain invalid\n");
		}
	} else {
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Not an email: no at-sign\n");
	}

@ What constitutes a legal email address follows the HTML 5 regular expression,
according to CommonMark. Good luck using |{{@1-x.2.z.w| as your email address,
but you absolutely can.

@<Vet the username@> =
	int username_length = atsign_at - link_from;
	if (username_length < 1) username_valid = FALSE;
	for (int i=link_from; i<atsign_at; i++) {
		wchar_t c = Str::get_at(text, i);
		if (!((Markdown::is_ASCII_letter(c)) ||
				(Markdown::is_ASCII_digit(c)) ||
				(c == '.') ||
				(c == '!') ||
				(c == '#') ||
				(c == '$') ||
				(c == '%') ||
				(c == '&') ||
				(c == '\'') ||
				(c == '*') ||
				(c == '+') ||
				(c == '/') ||
				(c == '=') ||
				(c == '?') ||
				(c == '^') ||
				(c == '_') ||
				(c == '`') ||
				(c == '{') ||
				(c == '|') ||
				(c == '}') ||
				(c == '~') ||
				(c == '-')))
			username_valid = FALSE;
	}

@<Vet the domain name@> =
	int segment_length = 0;
	for (int i=atsign_at+1; i<=link_to; i++) {
		wchar_t c = Str::get_at(text, i);
		if (segment_length == 0) {
			if (!((Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c))))
				domain_valid = FALSE;
		} else {
			if (c == '.') { segment_length = 0; continue; }
			if (c == '-') {
				if ((Str::get_at(text, i+1) == 0) || (Str::get_at(text, i+1) == '.'))
					domain_valid = FALSE;
			} else if (!((Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c))))
				domain_valid = FALSE;
		}
		segment_length++;
		if (segment_length >= 64) domain_valid = FALSE;
	}
	if (segment_length >= 64) domain_valid = FALSE;

@<Does a raw HTML tag begin here?@> =
	if (Str::get_at(text, i) == '<') {
		switch (Str::get_at(text, i+1)) {
			case '?': @<Does a processing instruction begin here?@>; break;
			case '!':
				if ((Str::get_at(text, i+2) == '-') && (Str::get_at(text, i+3) == '-'))
					@<Does an HTML comment begin here?@>;
				if ((Str::get_at(text, i+2) == '[') && (Str::get_at(text, i+3) == 'C') &&
					(Str::get_at(text, i+4) == 'D') && (Str::get_at(text, i+5) == 'A') &&
					(Str::get_at(text, i+6) == 'T') && (Str::get_at(text, i+7) == 'A') &&
					(Str::get_at(text, i+8) == '['))
					@<Does a CDATA section begin here?@>;
				if (Markdown::is_ASCII_letter(Str::get_at(text, i+2)))
					@<Does an HTML declaration begin here?@>;
				break;
			case '/': @<Does a close tag begin here?@>; break;
			default: @<Does an open tag begin here?@>; break;
		}
		NotATag: ;
	}

@ The content of a PI must be non-empty.

@<Does a processing instruction begin here?@> =
	for (int j = i+3; j<Str::len(text); j++)
		if ((Str::get_at(text, j) == '?') && (Str::get_at(text, j+1) == '>')) {
			int tag_from = i, tag_to = j+1;
			@<Allow it as a raw HTML tag@>;
		}

@ A comment can be empty, but cannot end in a dash or contain a double-dash:

@<Does an HTML comment begin here?@> =
	int bad_start = FALSE;
	if (Str::get_at(text, i+4) == '>') bad_start = TRUE;
	if ((Str::get_at(text, i+4) == '-') && (Str::get_at(text, i+5) == '>')) bad_start = TRUE;
	if (bad_start == FALSE)
		for (int j = i+4; j<Str::len(text); j++)
			if ((Str::get_at(text, j) == '-') && (Str::get_at(text, j+1) == '-')) {
				if (Str::get_at(text, j+2) == '>') {
					int tag_from = i, tag_to = j+2;
					@<Allow it as a raw HTML tag@>;
				}
				break;
			} 

@ The content of a declaration can be empty.

@<Does an HTML declaration begin here?@> =
	for (int j = i+2; j<Str::len(text); j++)
		if (Str::get_at(text, j) == '>') {
			int tag_from = i, tag_to = j;
			@<Allow it as a raw HTML tag@>;
		}

@ The content of a CDATA must be non-empty.

@<Does a CDATA section begin here?@> =
	for (int j = i+10; j<Str::len(text); j++)
		if ((Str::get_at(text, j) == ']') && (Str::get_at(text, j+1) == ']') &&
			(Str::get_at(text, j+2) == '>')) {
			int tag_from = i, tag_to = j+2;
			@<Allow it as a raw HTML tag@>;
		}

@<Does an open tag begin here?@> =
	int at = i+1;
	@<Advance past tag name@>;
	@<Advance past attributes@>;
	@<Advance past optional tag-whitespace@>;
	if (Str::get_at(text, at) == '/') at++;
	if (Str::get_at(text, at) == '>') {
		int tag_from = i, tag_to = at;
		@<Allow it as a raw HTML tag@>;
	}

@<Does a close tag begin here?@> =
	int at = i+2;
	@<Advance past tag name@>;
	@<Advance past optional tag-whitespace@>;
	if (Str::get_at(text, at) == '>') {
		int tag_from = i, tag_to = at;
		@<Allow it as a raw HTML tag@>;
	}

@<Advance past tag name@> =
	wchar_t c = Str::get_at(text, at);
	if (Markdown::is_ASCII_letter(c) == FALSE) goto NotATag;
	while ((c == '-') || (Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c)))
		c = Str::get_at(text, ++at);

@<Advance past attributes@> =
	while (TRUE) {
		int start_at = at;
		@<Advance past optional tag-whitespace@>;
		if (at == start_at) break;
		wchar_t c = Str::get_at(text, at);
		if ((c == '_') || (c == ':') || (Markdown::is_ASCII_letter(c))) {
			while ((c == '_') || (c == ':') || (c == '.') || (c == '-') ||
				(Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c)))
				c = Str::get_at(text, ++at);
			int start_value_at = at;
			@<Advance past optional tag-whitespace@>;
			if (Str::get_at(text, at) != '=') {
				at = start_value_at; goto DoneValueSpecification;
			}
			at++;
			@<Advance past optional tag-whitespace@>;
			@<Try for a single-quoted attribute value@>;
			@<Try for a double-quoted attribute value@>;
			@<Try for an unquoted attribute value@>;
			DoneValueSpecification: ;
		} else { at = start_at; break; }
	}

@<Try for an unquoted attribute value@> =
	int k = at;
	while (TRUE) {
		wchar_t c = Str::get_at(text, k);
		if ((c == ' ') || (c == '\t') || (c == '\n') || (c == '"') || (c == '\'') ||
			(c == '=') || (c == '<') || (c == '>') || (c == '`') || (c == 0))
			break;
		k++;
	}
	if (k == at) { at = start_value_at; goto DoneValueSpecification; }
	at = k; goto DoneValueSpecification;

@<Try for a single-quoted attribute value@> =
	if (Str::get_at(text, at) == '\'') {
		int k = at + 1;
		while ((Str::get_at(text, k) != '\'') && (Str::get_at(text, k) != 0))
			k++;
		if (Str::get_at(text, k) == '\'') { at = k+1; goto DoneValueSpecification; }
		at = start_value_at; goto DoneValueSpecification;
	}

@<Try for a double-quoted attribute value@> =
	if (Str::get_at(text, at) == '"') {
		int k = at + 1;
		while ((Str::get_at(text, k) != '"') && (Str::get_at(text, k) != 0))
			k++;
		if (Str::get_at(text, k) == '"') { at = k+1; goto DoneValueSpecification; }
		at = start_value_at; goto DoneValueSpecification;
	}

@<Advance past compulsory tag-whitespace@> =
	wchar_t c = Str::get_at(text, at);
	if ((c != ' ') && (c != '\t') && (c != '\n')) goto NotATag;
	@<Advance past optional tag-whitespace@>;

@<Advance past optional tag-whitespace@> =
	int line_ending_count = 0;
	while (TRUE) {
		wchar_t c = Str::get_at(text, at++);
		if (c == '\n') {
			line_ending_count++;
			if (line_ending_count == 2) break;
		}
		if ((c != ' ') && (c != '\t') && (c != '\n')) break;
	}
	at--;

@<Allow it as a raw HTML tag@> =
	if (i-1 >= from) {
		markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
		Markdown::add_to(md, owner);
	}
	markdown_item *md = Markdown::new_slice(INLINE_HTML_MIT, text, tag_from, tag_to);
	Markdown::add_to(md, owner);
	i = tag_to; from = tag_to + 1;
	if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found raw HTML\n");
	goto ContinueOuter;

@<Does a hard or soft line break occur here?@> =
	if (Str::get_at(text, i) == '\n') {
		int soak = 0;
		if (Str::get_at(text, i-1) == '\\') soak = 2;
		int preceding_spaces = 0;
		while (Str::get_at(text, i-1-preceding_spaces) == ' ') preceding_spaces++;
		if (preceding_spaces >= 2) soak = preceding_spaces+1;
		if (soak > 0) {
			if (i-soak >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-soak);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(LINE_BREAK_MIT, I"\n\n", 0, 1);
			Markdown::add_to(md, owner);
		} else {
			if (i-preceding_spaces-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-preceding_spaces-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(SOFT_BREAK_MIT, I"\n", 0, 0);
			Markdown::add_to(md, owner);
		}
		i++;
		while (Str::get_at(text, i) == ' ') i++;
		from = i;
		i--;
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found raw HTML\n");
		goto ContinueOuter;
	}

@h Links and images.

@<Second pass: link and image inline items@> =
	Markdown::scan_for_links_and_images(owner, FALSE);

@

=
void Markdown::scan_for_links_and_images(markdown_item *owner, int images_only) {
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "Beginning link/image pass:\n");
		Markdown::render_debug(STDOUT, owner);
	}
	md_charpos leftmost_pos = Markdown::first_pos(owner);
	while (TRUE) {
		if (tracing_Markdown_parser) {
			if (Markdown::somewhere(leftmost_pos)) {
				WRITE_TO(STDOUT, "Link/image notation scan from %c\n",
					Markdown::get(leftmost_pos));
				Markdown::render_debug(STDOUT, leftmost_pos.md);
			} else {
				WRITE_TO(STDOUT, "Link/image notation scan from start\n");
			}
		}
		md_link_parse found = Markdown::first_valid_link(leftmost_pos, Markdown::nowhere(), images_only, FALSE);
		if (found.is_link == NOT_APPLICABLE) break;
		if (tracing_Markdown_parser) {
			WRITE_TO(STDOUT, "Link matter: ");
			if (found.link_text_empty) WRITE_TO(STDOUT, "EMPTY\n");
			else Markdown::view_positions(STDOUT, found.link_text_from, found.link_text_to);
			WRITE_TO(STDOUT, "Link destination: ");
			if (found.link_destination_empty) WRITE_TO(STDOUT, "EMPTY\n");
			else Markdown::view_positions(STDOUT, found.link_destination_from, found.link_destination_to);
			WRITE_TO(STDOUT, "Link title: ");
			if (found.link_title_empty) WRITE_TO(STDOUT, "EMPTY\n");
			else Markdown::view_positions(STDOUT, found.link_title_from, found.link_title_to);
		}
		markdown_item *run = owner->down, *interstitial = NULL, *remainder = NULL;
		Markdown::cut_to_just_before(run, found.first, &run, &interstitial);
		Markdown::cut_to_just_after(interstitial, found.last, &interstitial, &remainder);
		markdown_item *link_text = NULL;
		markdown_item *link_destination = NULL;
		markdown_item *link_title = NULL;
		if (found.link_text_empty == FALSE) {
			Markdown::cut_to_just_before(interstitial, found.link_text_from, &interstitial, &link_text);
			Markdown::cut_to_just_after(link_text, found.link_text_to, &link_text, &interstitial);
		}
		if (Markdown::somewhere(found.link_destination_from)) {
			if (found.link_destination_empty == FALSE) {
				Markdown::cut_to_just_before(interstitial, found.link_destination_from, &interstitial, &link_destination);
				Markdown::cut_to_just_after(link_destination, found.link_destination_to, &link_destination, &interstitial);
			}
		}
		if (Markdown::somewhere(found.link_title_from)) {
			if (found.link_title_empty == FALSE) {
				Markdown::cut_to_just_before(interstitial, found.link_title_from, &interstitial, &link_title);
				Markdown::cut_to_just_after(link_title, found.link_title_to, &link_title, &interstitial);
			}
		}
		markdown_item *link_item = Markdown::new_item((found.is_link == TRUE)?LINK_MIT:IMAGE_MIT);
		markdown_item *matter = Markdown::new_item(MATERIAL_MIT);
		if (found.link_text_empty == FALSE) matter->down = link_text;
		Markdown::add_to(matter, link_item);
		if (found.is_link == TRUE)
			Markdown::scan_for_links_and_images(matter, TRUE);
		else
			Markdown::scan_for_links_and_images(matter, FALSE);
		if (link_destination) {
			markdown_item *dest_item = Markdown::new_item(LINK_DEST_MIT);
			if (found.link_destination_empty == FALSE) dest_item->down = link_destination;
			Markdown::add_to(dest_item, link_item);
		}
		if (link_title) {
			markdown_item *title_item = Markdown::new_item(LINK_TITLE_MIT);
			if (found.link_title_empty == FALSE) title_item->down = link_title;
			Markdown::add_to(title_item, link_item);
		}
		if (run) {
			owner->down = run;
			while (run->next) run = run->next; run->next = link_item;
		} else {
			owner->down = link_item;
		}
		link_item->next = remainder;
		if (tracing_Markdown_parser) {
			WRITE_TO(STDOUT, "After link surgery:\n");
			Markdown::render_debug(STDOUT, owner);
		}
		leftmost_pos = Markdown::left_edge_of(remainder);
	}
}

@ =
typedef struct md_charpos {
	struct markdown_item *md;
	struct markdown_item *md_prev;
	int at;
} md_charpos;

md_charpos Markdown::nowhere(void) {
	md_charpos pos;
	pos.md = NULL;
	pos.md_prev = NULL;
	pos.at = -1;
	return pos;
}

int Markdown::somewhere(md_charpos pos) {
	if (pos.md) return TRUE;
	return FALSE;
}

int Markdown::pos_eq(md_charpos A, md_charpos B) {
	if ((A.md) && (A.md == B.md) && (A.at == B.at)) return TRUE;
	if ((A.md == NULL) && (B.md == NULL)) return TRUE;
	return FALSE;
}

int Markdown::plainish(markdown_item *md) {
	if ((md) && ((md->type == PLAIN_MIT) || (md->type == LINE_BREAK_MIT) || (md->type == SOFT_BREAK_MIT)))
		return TRUE;
	return FALSE;
}

md_charpos Markdown::first_pos(markdown_item *owner) {
	markdown_item *md = (owner)?(owner->down):NULL;
	while ((md) && (Markdown::plainish(md) == FALSE)) md = md->next;
	if (md == NULL) return Markdown::nowhere();
	return Markdown::left_edge_of(md);
}

md_charpos Markdown::left_edge_of(markdown_item *md) {
	if (md == NULL) return Markdown::nowhere();
	md_charpos pos;
	pos.md = md;
	pos.md_prev = md;
	pos.at = md->from;
	return pos;
}

md_charpos Markdown::next_pos(md_charpos pos) {
	if (Markdown::somewhere(pos)) {
		if (pos.at < pos.md->to) { pos.at++; return pos; }
		pos.md_prev = pos.md;
		pos.md = pos.md->next;
		while ((pos.md) && (Markdown::plainish(pos.md) == FALSE)) pos.md = pos.md->next;
		if (pos.md) { pos.at = pos.md->from; return pos; }
	}
	return Markdown::nowhere();
}

md_charpos Markdown::next_pos_up_to(md_charpos pos, md_charpos end) {
	if ((Markdown::somewhere(end)) && (pos.md->sliced_from == end.md->sliced_from) && (pos.at >= end.at))
		return Markdown::nowhere();
	return Markdown::next_pos(pos);
}

md_charpos Markdown::next_pos_plainish_only(md_charpos pos) {
	if (Markdown::somewhere(pos)) {
		if (pos.at < pos.md->to) { pos.at++; return pos; }
		pos.md_prev = pos.md;
		pos.md = pos.md->next;
		if ((pos.md) && (Markdown::plainish(pos.md))) { pos.at = pos.md->from; return pos; }
	}
	return Markdown::nowhere();
}

md_charpos Markdown::next_pos_up_to_plainish_only(md_charpos pos, md_charpos end) {
	if ((Markdown::somewhere(end)) && (pos.md->sliced_from == end.md->sliced_from) && (pos.at >= end.at))
		return Markdown::nowhere();
	return Markdown::next_pos_plainish_only(pos);
}

wchar_t Markdown::get(md_charpos pos) {
	if (Markdown::somewhere(pos)) return Markdown::get_at(pos.md, pos.at);
	return 0;
}

int Markdown::is_in(md_charpos pos, markdown_item *md) {
	if ((Markdown::somewhere(pos)) && (md)) {
		if ((md->sliced_from) && (md->sliced_from == pos.md->sliced_from) &&
			(pos.at >= md->from) && (pos.at <= md->to)) return TRUE;
	}
	return FALSE;
}

void Markdown::view_positions(OUTPUT_STREAM, md_charpos A, md_charpos B) {
	if (Markdown::somewhere(A) == FALSE) { WRITE("NONE\n"); return; }
	for (md_charpos pos = A; Markdown::somewhere(pos); pos = Markdown::next_pos(pos)) {
		PUT(Markdown::get(pos));
		if (Markdown::pos_eq(pos, B)) break;
	}
	PUT('\n');
}

void Markdown::cut_to_just_before(markdown_item *chain_from, md_charpos cut_point,
	markdown_item **left_segment, markdown_item **right_segment) {
	markdown_item *L = chain_from, *R = NULL;
	if ((chain_from) && (Markdown::somewhere(cut_point))) {
		markdown_item *md, *md_prev = NULL;
		for (md = chain_from; (md) && (Markdown::is_in(cut_point, md) == FALSE);
			md_prev = md, md = md->next) ;
		if (md) {
			if (cut_point.at <= md->from) {
				if (md_prev) md_prev->next = NULL; else L = NULL;
				R = md;
			} else {
				int old_to = md->to;
				md->to = cut_point.at - 1;
				markdown_item *splinter = Markdown::new_slice(md->type, md->sliced_from, cut_point.at, old_to);
				splinter->next = md->next;
				md->next = NULL;
				R = splinter;
			}
		}
	}
	if (left_segment) *left_segment = L;
	if (right_segment) *right_segment = R;
}

void Markdown::cut_to_just_after(markdown_item *chain_from, md_charpos cut_point,
	markdown_item **left_segment, markdown_item **right_segment) {
	markdown_item *L = chain_from, *R = NULL;
	if ((chain_from) && (Markdown::somewhere(cut_point))) {
		markdown_item *md, *md_prev = NULL;
		for (md = chain_from; (md) && (Markdown::is_in(cut_point, md) == FALSE);
			md_prev = md, md = md->next) ;
		if (md) {
			if (cut_point.at >= md->to) {
				R = md->next;
				md->next = NULL;
			} else {
				int old_to = md->to;
				md->to = cut_point.at;
				markdown_item *splinter = Markdown::new_slice(md->type, md->sliced_from, cut_point.at + 1, old_to);
				splinter->next = md->next;
				md->next = NULL;
				R = splinter;
			}
		}
	}
	if (left_segment) *left_segment = L;
	if (right_segment) *right_segment = R;
}

typedef struct md_link_parse {
	int is_link; /* |TRUE| for link, |FALSE| for image, |NOT_APPLICABLE| for fail */
	struct md_charpos first;
	struct md_charpos link_text_from;
	struct md_charpos link_text_to;
	int link_text_empty;
	struct md_charpos link_destination_from;
	struct md_charpos link_destination_to;
	int link_destination_empty;
	struct md_charpos link_title_from;
	struct md_charpos link_title_to;
	int link_title_empty;
	struct md_charpos last;
} md_link_parse;

@

@d ABANDON_LINK(reason)
	{ if (tracing_Markdown_parser) { WRITE_TO(STDOUT, "Link abandoned: %s\n", reason); }
	pos = abandon_at; goto AbandonHope; }

@ =
md_link_parse Markdown::first_valid_link(md_charpos from, md_charpos to, int images_only, int links_only) {
	md_link_parse result;
	result.is_link = NOT_APPLICABLE;
	result.first = Markdown::nowhere();
	result.link_text_from = Markdown::nowhere();
	result.link_text_to = Markdown::nowhere();
	result.link_text_empty = NOT_APPLICABLE;
	result.link_destination_from = Markdown::nowhere();
	result.link_destination_to = Markdown::nowhere();
	result.link_destination_empty = NOT_APPLICABLE;
	result.link_title_from = Markdown::nowhere();
	result.link_title_to = Markdown::nowhere();
	result.link_title_empty = NOT_APPLICABLE;
	result.last = Markdown::nowhere();
	wchar_t prev_c = 0;
	md_charpos prev_pos = Markdown::nowhere();
	for (md_charpos pos = from; Markdown::somewhere(pos); pos = Markdown::next_pos_up_to(pos, to)) {
		wchar_t c = Markdown::get(pos);
		if ((c == '[') &&
			((links_only == FALSE) || (prev_c != '!')) &&
			((images_only == FALSE) || (prev_c == '!'))) {
			int link_rather_than_image = TRUE;
			result.first = pos;
			if ((prev_c == '!') && (links_only == FALSE)) {
				link_rather_than_image = FALSE; result.first = prev_pos;
			}
			
			if (link_rather_than_image) {
				if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Potential link found\n");
			} else {
				if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Potential image found\n");
			}
			md_charpos abandon_at = pos;
			@<Work out the link text@>;
			if (Markdown::get(pos) != '(') ABANDON_LINK("no '('");
			pos = Markdown::next_pos_up_to_plainish_only(pos, to);
			@<Advance pos by optional small amount of white space@>;
			if (Markdown::get(pos) != ')') @<Work out the link destination@>;
			@<Advance pos by optional small amount of white space@>;
			if (Markdown::get(pos) != ')') @<Work out the link title@>;
			@<Advance pos by optional small amount of white space@>;
			if (Markdown::get(pos) != ')') ABANDON_LINK("no ')'");
			result.last = pos;
			result.is_link = link_rather_than_image;
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Confirmed\n");
			return result;
		}
		AbandonHope: ;
		prev_pos = pos;
		prev_c = c;
	}
	return result;
}

@<Work out the link text@> =
	md_charpos prev_pos = pos;
	result.link_text_from = Markdown::next_pos_up_to(pos, to);
	wchar_t prev_c = 0;
	int bl = 0, count = 0;
	while (c != 0) {
		count++;
		if ((c == '[') && (prev_c != '\\')) bl++;
		if ((c == ']') && (prev_c != '\\')) { bl--; if (bl == 0) break; }		
		prev_pos = pos;
		prev_c = c;
		pos = Markdown::next_pos_up_to(pos, to);
		c = Markdown::get(pos);
	}
	if (c == 0) { pos = abandon_at; ABANDON_LINK("no end to linked matter"); }
	result.link_text_empty = (count<=2)?TRUE:FALSE;
	result.link_text_to = prev_pos;
	if (link_rather_than_image) {
		md_link_parse nested =
			Markdown::first_valid_link(result.link_text_from, result.link_text_to, FALSE, TRUE);
		if (nested.is_link != NOT_APPLICABLE) return nested;
	}
	pos = Markdown::next_pos_up_to_plainish_only(pos, to);
	
@<Work out the link destination@> =
	if (Markdown::get(pos) == '<') {
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
		result.link_destination_from = pos;
		int empty = TRUE;
		wchar_t prev_c = 0;
		while ((Markdown::get(pos) != '>') || (prev_c == '\\')) {
			if (Markdown::get(pos) == 0) ABANDON_LINK("no end to destination in angles");
			if (Markdown::get(pos) == '<') ABANDON_LINK("'<' in destination in angles");
			prev_pos = pos; prev_c = Markdown::get(pos);
			pos = Markdown::next_pos_up_to_plainish_only(pos, to); empty = FALSE;
		}
		result.link_destination_empty = empty;
		result.link_destination_to = prev_pos;
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
		if ((Markdown::get(pos) == '"') || (Markdown::get(pos) == '\'') || (Markdown::get(pos) == '(')) ABANDON_LINK("no gap between destination and title");
	} else {
		result.link_destination_from = pos;
		int bl = 1;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		while ((Markdown::get(pos) != ' ') && (Markdown::get(pos) != '\n') && (Markdown::get(pos) != '\t')) {
			wchar_t c = Markdown::get(pos);
			if ((c == '(') && (prev_c != '\\')) bl++;
			if ((c == ')') && (prev_c != '\\')) { bl--; if (bl == 0) break; }
			if (c == 0) ABANDON_LINK("no end to destination");
			if (Markdown::is_control_character(c)) ABANDON_LINK("control character in destination");
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::next_pos_up_to_plainish_only(pos, to); empty = FALSE;
		}
		result.link_destination_empty = empty;
		result.link_destination_to = prev_pos;
		if ((Markdown::get(pos) == '"') || (Markdown::get(pos) == '\'') || (Markdown::get(pos) == '(')) ABANDON_LINK("no gap between destination and title");
	}

@<Work out the link title@> =
	if (Markdown::get(pos) == '"') {
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
		result.link_title_from = pos;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		wchar_t c = Markdown::get(pos);
		while (c != 0) {
			wchar_t c = Markdown::get(pos);
			if ((c == '"') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::next_pos_up_to_plainish_only(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
	}
	else if (Markdown::get(pos) == '\'') {
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
		result.link_title_from = pos;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		wchar_t c = Markdown::get(pos);
		while (c != 0) {
			wchar_t c = Markdown::get(pos);
			if ((c == '\'') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::next_pos_up_to_plainish_only(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
	}
	else if (Markdown::get(pos) == '(') {
		pos = Markdown::next_pos_up_to(pos, to);
		result.link_title_from = pos;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		wchar_t c = Markdown::get(pos);
		while (c != 0) {
			wchar_t c = Markdown::get(pos);
			if ((c == '(') && (prev_c != '\\')) ABANDON_LINK("unescaped '(' in title");
			if ((c == ')') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::next_pos_up_to(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
	}

@<Advance pos by optional small amount of white space@> =
	int line_endings = 0;
	wchar_t c = Markdown::get(pos);
	while ((c == ' ') || (c == '\t') || (c == '\n')) {
		if (c == '\n') { line_endings++; if (line_endings >= 2) break; }
		pos = Markdown::next_pos_up_to_plainish_only(pos, to);
		c = Markdown::get(pos);
	}

@h Emphasis.
Well, that was easy. Now for the hardest pass, in which we look for the use
of asterisks and underscores for emphasis. This notation is deeply ambiguous
on its face, and CommonMark's precise specification is a bit of an ordeal,
but here goes.

@<Third pass: emphasis inline items@> =
	Markdown::fragment_into_emphasis_items(owner);

@ =
void Markdown::fragment_into_emphasis_items(markdown_item *owner) {
	for (markdown_item *md = owner->down; md; md = md->next)
		if (md->type == LINK_MIT)
			Markdown::fragment_into_emphasis_items(md->down);
	text_stream *OUT = STDOUT;
	if (tracing_Markdown_parser) {
		WRITE("Seeking emphasis in:\n");
		INDENT;
		Markdown::render_debug(STDOUT, owner);
	}
	@<Seek emphasis@>;
	if (tracing_Markdown_parser) {
		OUTDENT;
		WRITE("Emphasis search complete\n");
	}
}

@ "A delimiter run is either a sequence of one or more * characters that is not
preceded or followed by a non-backslash-escaped * character, or a sequence of
one or more _ characters that is not preceded or followed by a
non-backslash-escaped _ character."

This function returns 0 unless a delimiter run begins at |at|, and then returns
its length if this was asterisked, and minus its length if underscored.

=
int Markdown::delimiter_run(markdown_item *md, int at) {
	int count = Markdown::unescaped_run(md, at, '*');
	if ((count > 0) && (Markdown::get_unescaped(md, at-1) != '*')) return count;
	count = Markdown::unescaped_run(md, at, '_');
	if ((count > 0) && (Markdown::get_unescaped(md, at-1) != '_')) return -count;
	return 0;
}

@ "A left-flanking delimiter run is a delimiter run that is (1) not followed by
Unicode whitespace, and either (2a) not followed by a Unicode punctuation
character, or (2b) followed by a Unicode punctuation character and preceded by
Unicode whitespace or a Unicode punctuation character. For purposes of this
definition, the beginning and the end of the line count as Unicode whitespace."

"A right-flanking delimiter run is a delimiter run that is (1) not preceded by
Unicode whitespace, and either (2a) not preceded by a Unicode punctuation
character, or (2b) preceded by a Unicode punctuation character and followed by
Unicode whitespace or a Unicode punctuation character. For purposes of this
definition, the beginning and the end of the line count as Unicode whitespace."

=
int Markdown::left_flanking(markdown_item *md, int at, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	wchar_t followed_by = Markdown::get_unescaped(md, at + count);
	if ((followed_by == 0) || (Markdown::is_Unicode_whitespace(followed_by))) return FALSE;
	if (Markdown::is_Unicode_punctuation(followed_by) == FALSE) return TRUE;
	wchar_t preceded_by = Markdown::get_unescaped(md, at - 1);
	if ((preceded_by == 0) || (Markdown::is_Unicode_whitespace(preceded_by)) ||
		(Markdown::is_Unicode_punctuation(preceded_by))) return TRUE;
	return FALSE;
}

int Markdown::right_flanking(markdown_item *md, int at, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	wchar_t preceded_by = Markdown::get_unescaped(md, at - 1);
	if ((preceded_by == 0) || (Markdown::is_Unicode_whitespace(preceded_by))) return FALSE;
	if (Markdown::is_Unicode_punctuation(preceded_by) == FALSE) return TRUE;
	wchar_t followed_by = Markdown::get_unescaped(md, at + count);
	if ((followed_by == 0) || (Markdown::is_Unicode_whitespace(followed_by)) ||
		(Markdown::is_Unicode_punctuation(followed_by))) return TRUE;
	return FALSE;
}

@ The following expresses rules (1) to (8) in the CM specification, section 6.2.

=
int Markdown::can_open_emphasis(markdown_item *md, int at, int count) {
	if (Markdown::left_flanking(md, at, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (Markdown::right_flanking(md, at, count) == FALSE) return TRUE;
	wchar_t preceded_by = Markdown::get_unescaped(md, at - 1);
	if (Markdown::is_Unicode_punctuation(preceded_by)) return TRUE;
	return FALSE;
}

int Markdown::can_close_emphasis(markdown_item *md, int at, int count) {
	if (Markdown::right_flanking(md, at, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (Markdown::left_flanking(md, at, count) == FALSE) return TRUE;
	wchar_t followed_by = Markdown::get_unescaped(md, at - count); /* count < 0 here */
	if (Markdown::is_Unicode_punctuation(followed_by)) return TRUE;
	return FALSE;
}

@ This naive algorithm has every possibility of becoming computationally
explosive if a really knotty tangle of nested emphasis delimiters comes along,
though of course that is a rare occurrence. We're going to find every possible
way to pair opening and closing delimiters, and then score the results with a
system of penalties. Whichever solution has the least penalty is the winner.

In almost every example of normal Markdown written by actual human beings,
there will be just one open/close option at a time.

@d MAX_MD_EMPHASIS_PAIRS (MAX_MD_EMPHASIS_DELIMITERS*MAX_MD_EMPHASIS_DELIMITERS)

@<Seek emphasis@> =
	int no_delimiters = 0;
	md_emphasis_delimiter delimiters[MAX_MD_EMPHASIS_DELIMITERS];
	@<Find the possible emphasis delimiters@>;

	markdown_item *options[MAX_MD_EMPHASIS_DELIMITERS];
	int no_options = 0;
	for (int open_i = 0; open_i < no_delimiters; open_i++) {
		md_emphasis_delimiter *OD = &(delimiters[open_i]);
		if (OD->can_open == FALSE) continue;
		for (int close_i = open_i+1; close_i < no_delimiters; close_i++) {
			md_emphasis_delimiter *CD = &(delimiters[close_i]);
			if (CD->can_close == FALSE) continue;
			@<Reject this as a possible closer if it cannot match the opener@>;
			if (tracing_Markdown_parser) {
				WRITE("Option %d is to pair D%d with D%d\n", no_options, open_i, close_i);
			}
			@<Create the subtree which would result from this option being chosen@>;
		}
	}
	if (no_options > 0) @<Select the option with the lowest penalty@>;

@ We don't want to find every possible delimiter, in case the source text is
absolutely huge: indeed, we never exceed |MAX_MD_EMPHASIS_DELIMITERS|.

A further optimisation is that (a) we needn't even record delimiters which
can't open or close, (b) or delimiters which can only close and which occur
before any openers, (c) or anything after a point where we can clearly complete
at least one pair correctly.

For example, consider |This is *emphatic* and **so is this**.| Rule (c) makes
it unnecessary to look past the end of the word "emphatic", because by that
point we have seen an opener which cannot close and a closer which cannot open,
of equal widths. These can only pair with each other; so we can stop.

As a result, in almost all human-written Markdown, the algorithm below returns
exactly two delimiters, one open, one close.

In other situations, it's harder to predict what will happen. We will contain
the possible explosion by restricting to cases where at least one pair can be
made within the first |MAX_MD_EMPHASIS_DELIMITERS| potential delimiters, and
we can pretty safely keep that number small.

@d MAX_MD_EMPHASIS_DELIMITERS 10

=
typedef struct md_emphasis_delimiter {
	struct markdown_item *item; /* this will be a |PLAIN_MIT| node */
	int at; /* and this will be a position within it */
	int width; /* for example, 7 for a run of seven asterisks */
	int type; /* 1 for asterisks, -1 for underscores */
	int can_open; /* result of |Markdown::can_open_emphasis| on it */
	int can_close; /* result of |Markdown::can_close_emphasis| on it */
	CLASS_DEFINITION
} md_emphasis_delimiter;

@<Find the possible emphasis delimiters@> =
	int pos = 0, open_count[2] = { 0, 0 }, close_count[2] = { 0, 0 }, both_count[2] = { 0, 0 }; 
	for (markdown_item *md = owner->down; md; md = md->next) {
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++, pos++) {
				int run = Markdown::delimiter_run(md, i);
				if (run != 0) {
					if (no_delimiters >= MAX_MD_EMPHASIS_DELIMITERS) break;
					int can_open = Markdown::can_open_emphasis(md, i, run);
					int can_close = Markdown::can_close_emphasis(md, i, run);
					if ((no_delimiters == 0) && (can_open == FALSE)) continue;
					if ((can_open == FALSE) && (can_close == FALSE)) continue;
					md_emphasis_delimiter *P = &(delimiters[no_delimiters++]);
					P->at = i;
					P->item = md;
					P->width = (run>0)?run:(-run);
					P->type = (run>0)?1:-1;
					P->can_open = can_open;
					P->can_close = can_close;
					if (tracing_Markdown_parser) {
						WRITE("DR%d at %d with width %d type %d left, right %d, "
							"%d open, close %d, %d preceded '%c' followed '%c'\n",
							no_delimiters, pos, P->width, P->type,
							Markdown::left_flanking(md, P->at, run),
							Markdown::right_flanking(md, P->at, run),
							P->can_open, P->can_close,
							Markdown::get_unescaped(md, P->at - 1),
							Markdown::get_unescaped(md, P->at + P->width));
					}
					int x = (P->type>0)?0:1;
					if ((can_open) && (can_close == FALSE)) open_count[x] += P->width;
					if ((can_open == FALSE) && (can_close)) close_count[x] += P->width;
					if ((can_open) && (can_close)) both_count[x] += P->width;
					if ((both_count[0] == 0) && (open_count[0] == close_count[0]) &&
						(both_count[1] == 0) && (open_count[1] == close_count[1])) break;
				}
			}
		}
	}

@ We vet |OD| and |CD| to see if it's possible to pair them together. We
already know that |OD| can open and |CD| can close, and that |OD| precedes
|CD| ("The opening and closing delimiters must belong to separate delimiter
runs."). They must have the same type: asterisk pair with asterisks, underscores
with underscores.

That's when the CommonMark specification becomes kind of hilarious: "If one of
the delimiters can both open and close emphasis, then the sum of the lengths of
the delimiter runs containing the opening and closing delimiters must not be a
multiple of 3 unless both lengths are multiples of 3."

@<Reject this as a possible closer if it cannot match the opener@> =
	if (CD->type != OD->type) continue;
	if ((CD->can_open) || (OD->can_close)) {
		int sum = OD->width + CD->width;
		if (sum % 3 == 0) {
			if (OD->width % 3 != 0) continue;
			if (CD->width % 3 != 0) continue;
		}
	}

@ Okay, so now |OD| and |CD| are conceivable pairs to each other, and we
investigate the consequences. We need to copy the existing situation so
that we can alter it without destroying the original.

Note the two recursive uses of |Markdown::fragment_into_emphasis_items| to continue
the process of pairing: this is where the computational fuse is lit, with
the explosion to follow. But since each subtree contains fewer delimiter runs
than the original, it does at least terminate.

@<Create the subtree which would result from this option being chosen@> =
	markdown_item *option = Markdown::deep_copy(owner);
	options[no_options++] = option;
	markdown_item *OI = NULL, *CI = NULL;
	for (markdown_item *md = option->down; md; md = md->next) {
		if (md->copied_from == OD->item) OI = md;
		if (md->copied_from == CD->item) CI = md;
	}
	if ((OI == NULL) || (CI == NULL)) internal_error("copy accident");

	int width; /* number of delimiter characters we will trim */
	int cut1; /* last char before left delimiter */
	int cut2; /* first char after left delimiter */
	int cut3; /* last char before right delimiter */
	int cut4; /* first char after right delimiter */
	@<Draw the dotted lines where we will cut@>;

	@<Deactivate the active characters being acted on@>;

	markdown_item *em_top, *em_bottom;
	@<Make the chain of emphasis nodes from top to bottom@>;

	if (OI == CI) @<The opener and closer are in the same PLAIN item@>
	else @<The opener and closer are in different PLAIN items@>;

	Markdown::fragment_into_emphasis_items(em_bottom);
	Markdown::fragment_into_emphasis_items(option);

	if (tracing_Markdown_parser) {
		WRITE("Option %d is to fragment thus:\n", no_options);
		Markdown::render_debug(STDOUT, option);
		WRITE("Resulting in: ");
		Markdown::render(STDOUT, option);
		WRITE("Which scores %d penalty points\n", Markdown::penalty(option));
	}

@ This innocent-looking code is very tricky. The issue is that the two delimiters
may be of unequal width. We want to take as many asterisks/underscores away
as we can, so we set |width| to the minimum of the two lengths. But a complication
is that they need to be cropped to fit inside the slice of the node they belong
to first.

We then mark to remove |width| characters from the inside edges of each
delimiter, not the outside edges.

@<Draw the dotted lines where we will cut@> =
	int O_start = OD->at, O_width = OD->width;
	if (O_start < OI->from) { O_width -= (OI->from - O_start); O_start = OI->from; }

	int C_start = CD->at, C_width = CD->width;
	if (C_start + C_width - 1 > CI->to) { C_width = CI->to - C_start + 1; }

	width = O_width; if (width > C_width) width = C_width;

	cut2 = O_start + O_width;
	cut1 = cut2 - width - 1;

	cut3 = C_start - 1;
	cut4 = C_start + width;

@<Deactivate the active characters being acted on@> =
	for (int w=1; w<=width; w++) {
		Str::put_at(OI->sliced_from, cut1+w, ':');
		Str::put_at(CI->sliced_from, cut3+w, ':');
	}

@ Suppose we are peeling away 5 asterisks from the inside edges of each delimiter,
so that |width| is 5. There are only two strengths of emphasis in Markdown, so
this must be read as one of the various ways to add 1s and 2s to make 5.
CommonMark rule 13 reads "The number of nestings should be minimized.", so we
must use all 2s except for the 1 left over. Rule 14 says that left-over 1 must
be outermost. So this would give us:
= (text)
	EMPHASIS_MIT  <--- this is em_top
		STRONG_MIT
			STRONG_MIT  <--- this is em_bottom
				...the actual content being emphasised
=

@<Make the chain of emphasis nodes from top to bottom@> =
	em_top = Markdown::new_item(((width%2) == 1)?EMPHASIS_MIT:STRONG_MIT);
	if ((width%2) == 1) width -= 1; else width -= 2;
	em_bottom = em_top;
	while (width > 0) {
		markdown_item *g = Markdown::new_item(STRONG_MIT); width -= 2;
		em_bottom->down = g; em_bottom = g;
	}

@<The opener and closer are in the same PLAIN item@> =
	if (tracing_Markdown_parser) {
		WRITE("One item D%d(%d, %d) width %d -> %d, %d, %d, %d, %d, %d\n",
			OI->id, OI->from, OI->to, width, OI->from, cut1, cut2, cut3, cut4, OI->to);
	}
	markdown_item *was_next = OI->next;
	OI->next = em_top;
	em_bottom->down = Markdown::new_slice(PLAIN_MIT, OI->sliced_from, cut2, cut3);
	em_top->next = Markdown::new_slice(PLAIN_MIT, OI->sliced_from, cut4, OI->to);
	OI->to = cut1;
	em_top->next->next = was_next;

@<The opener and closer are in different PLAIN items@> =
	if (tracing_Markdown_parser) {
		WRITE("Multiple items D%d(%d, %d) ... D%d(%d, %d) width %d -> %d, %d, %d, %d, %d, %d\n",
			OI->id, OI->from, OI->to, CI->id, CI->from, CI->to,
			width, OI->from, cut1, cut2, cut3, cut4, CI->to);
	}
	if (cut2 <= OI->to) {
		markdown_item *left_inner_fragment =
			Markdown::new_slice(PLAIN_MIT, OI->sliced_from, cut2, OI->to);
		Markdown::add_to(left_inner_fragment, em_bottom);
	}
	OI->to = cut1;
	for (markdown_item *md = OI, *next_md = (md)?(md->next):NULL; (md) && (md != CI);
		md = next_md, next_md = (md)?(md->next):NULL)
		if ((md != OI) && (md != CI))
			Markdown::add_to(md, em_bottom);
	if (cut3 >= 0) {
		markdown_item *right_inner_fragment =
			Markdown::new_slice(PLAIN_MIT, CI->sliced_from, CI->from, cut3);
		Markdown::add_to(right_inner_fragment, em_bottom);
	}
	CI->from = cut4;
	OI->next = em_top; em_top->next = CI;

@<Select the option with the lowest penalty@> =
	int best_is = 1, best_score = 100000000;
	for (int pair_i = 0; pair_i < no_options; pair_i++) {
		int score = Markdown::penalty(options[pair_i]);
		if (score < best_score) { best_score = score; best_is = pair_i; }
	}
	if (tracing_Markdown_parser) {
		WRITE("Selected option %d with penalty %d\n", best_is, best_score);
	}
	owner->down = options[best_is]->down;

@ That just leaves the penalty scoring system: how unfortunate is a possible
reading of the Markdown syntax?

We score a whopping penalty for any unescaped asterisks and underscores left
over, because above all we want to pair as many delimiters as possible together.
(Some choices of pairings preclude others: it's a messy dynamic programming
problem to work this out in detail.)

We then impose a modest penalty on the width of a piece of emphasis, in
order to achieve CommonMark's rule 16: "When there are two potential emphasis
or strong emphasis spans with the same closing delimiter, the shorter one
(the one that opens later) takes precedence."

=
int Markdown::penalty(markdown_item *md) {
	if (md) {
		int penalty = 0;
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				wchar_t c = Markdown::get_unescaped(md, i);
				if ((c == '*') || (c == '_')) penalty += 100000;
			}
		}
		if ((md->type == EMPHASIS_MIT) || (md->type == STRONG_MIT))
			penalty += Markdown::width(md->down);
		for (markdown_item *c = md->down; c; c = c->next)
			penalty += Markdown::penalty(c);
		return penalty;
	}
	return 0;
}

@h Rendering.
This is blessedly simple by comparison.

=
void Markdown::render(OUTPUT_STREAM, markdown_item *md) {
	Markdown::render_r(OUT, md, TAGS_MDRMODE | ESCAPES_MDRMODE);
}

@

@d TAGS_MDRMODE 1
@d ESCAPES_MDRMODE 2
@d URI_MDRMODE 4

=
void Markdown::render_r(OUTPUT_STREAM, markdown_item *md, int mode) {
	if (md) {
		switch (md->type) {
			case PARAGRAPH_MIT: if (mode & TAGS_MDRMODE) HTML_OPEN("p");
								@<Recurse@>;
								if (mode & TAGS_MDRMODE) HTML_CLOSE("p");
								break;
			case MATERIAL_MIT: 	@<Recurse@>;
								break;
			case PLAIN_MIT:    	@<Render text@>;
								break;
			case EMPHASIS_MIT: 	if (mode & TAGS_MDRMODE) HTML_OPEN("em");
								@<Recurse@>;
								if (mode & TAGS_MDRMODE) HTML_CLOSE("em");
								break;
			case STRONG_MIT:   	if (mode & TAGS_MDRMODE) HTML_OPEN("strong");
								@<Recurse@>;
								if (mode & TAGS_MDRMODE) HTML_CLOSE("strong");
								break;
			case CODE_MIT:     	if (mode & TAGS_MDRMODE) HTML_OPEN("code");
								@<Render text raw@>;
								if (mode & TAGS_MDRMODE) HTML_CLOSE("code");
								break;
			case LINK_MIT:      @<Render link@>; break;
			case IMAGE_MIT:     @<Render image@>; break;
			case LINK_DEST_MIT: Markdown::render_slice(OUT, md->down, mode | URI_MDRMODE); break;
			case LINK_TITLE_MIT: @<Recurse@>; break;
			case LINE_BREAK_MIT: if (mode & TAGS_MDRMODE) WRITE("<br />\n"); break;
			case SOFT_BREAK_MIT: WRITE("\n"); break;
			case EMAIL_AUTOLINK_MIT: @<Render email link@>; break;
			case URI_AUTOLINK_MIT: @<Render URI link@>; break;
			case INLINE_HTML_MIT: @<Render text raw@>; break;
		}
	}
}

@<Recurse@> =
	for (markdown_item *c = md->down; c; c = c->next)
		Markdown::render_r(OUT, c, mode);

@<Render text@> =
	for (int i=md->from; i<=md->to; i++) {
		wchar_t c = Markdown::get_at(md, i);
		if ((c == '\\') && (i<md->to) && (Markdown::is_ASCII_punctuation(Markdown::get_at(md, i+1))))
			c = Markdown::get_at(md, ++i);
		Markdown::render_character(OUT, c);
	}

@<Render text unescaped@> =
	for (int i=md->from; i<=md->to; i++) {
		wchar_t c = Markdown::get_at(md, i);
		Markdown::render_character(OUT, c);
	}

@<Render text raw@> =
	for (int i=md->from; i<=md->to; i++) {
		wchar_t c = Markdown::get_at(md, i);
		PUT(c);
	}

@<Render link@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			Markdown::render_r(URI, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				Markdown::render_r(title, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			Markdown::render_r(title, md->down->next, mode);
		}
	}
	if (Str::len(title) > 0) {
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S\" title=\"%S\"", URI, title);
	} else {
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S\"", URI);
	}
	Markdown::render_r(OUT, md->down, mode);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("a");
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)

@<Render image@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(alt)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			Markdown::render_r(URI, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				Markdown::render_r(title, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			Markdown::render_r(title, md->down->next, mode);
		}
	}
	Markdown::render_r(alt, md->down, mode & (~TAGS_MDRMODE));
	if (Str::len(title) > 0) {
		HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" title=\"%S\" /", URI, alt, title);
	} else {
		HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" /", URI, alt);
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)
	DISCARD_TEXT(alt)

@<Render email link@> =
	text_stream *supplied_scheme = I"mailto:";
	@<Render autolink@>;

@<Render URI link@> =
	text_stream *supplied_scheme = NULL;
	@<Render autolink@>;

@<Render autolink@> =
	TEMPORARY_TEXT(address)
	Markdown::render_slice(address, md, (mode & (~ESCAPES_MDRMODE)) | URI_MDRMODE);
	if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S%S\"", supplied_scheme, address);
	@<Render text unescaped@>;
	if (mode & TAGS_MDRMODE) HTML_CLOSE("a");
	DISCARD_TEXT(address)

@

=
void Markdown::render_character(OUTPUT_STREAM, wchar_t c) {
	switch (c) {
		case '<': WRITE("&lt;"); break;
		case '&': WRITE("&amp;"); break;
		case '>': WRITE("&gt;"); break;
		case '"': WRITE("&quot;"); break;
		default: PUT(c); break;
	}
}

@

@d MARKDOWN_URI_HEX(x) {
		unsigned int z = (unsigned int) x;
		PUT('%');
		Markdown::render_hex_digit(OUT, z >> 4);
		Markdown::render_hex_digit(OUT, z & 0x0f);
	}

=
void Markdown::render_hex_digit(OUTPUT_STREAM, unsigned int x) {
	x = x%16;
	if (x<10) PUT('0'+(int) x);
	else PUT('A'+((int) x-10));
}

void Markdown::render_slice(OUTPUT_STREAM, markdown_item *md, int mode) {
	if (md) {
		for (int i=md->from; i<=md->to; i++) {
			wchar_t c = Markdown::get_at(md, i);
			if ((mode & ESCAPES_MDRMODE) && (c == '\\') && (i<md->to) &&
				(Markdown::is_ASCII_punctuation(Markdown::get_at(md, i+1))))
				c = Markdown::get_at(md, ++i);
			if (mode & URI_MDRMODE) {
				if (c >= 0x10000) {
					MARKDOWN_URI_HEX(0xF0 + (unsigned char) (c >> 18));
					MARKDOWN_URI_HEX(0x80 + (unsigned char) ((c >> 12) & 0x3f));
					MARKDOWN_URI_HEX( 0x80 + (unsigned char) ((c >> 6) & 0x3f));
					MARKDOWN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
				} else if (c >= 0x800) {
					MARKDOWN_URI_HEX(0xE0 + (unsigned char) (c >> 12));
					MARKDOWN_URI_HEX(0x80 + (unsigned char) ((c >> 6) & 0x3f));
					MARKDOWN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
				} else if (c >= 0x80) {
					MARKDOWN_URI_HEX(0xC0 + (unsigned char) (c >> 6));
					MARKDOWN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
				} else {
					switch (c) {
						case '<': WRITE("&lt;"); break;
						case '&': WRITE("&amp;"); break;
						case '>': WRITE("&gt;"); break;
						case '[': MARKDOWN_URI_HEX((unsigned char) c); break;
						case '\\':MARKDOWN_URI_HEX((unsigned char) c); break;
						case '\"':MARKDOWN_URI_HEX((unsigned char) c); break;
						case ']': MARKDOWN_URI_HEX((unsigned char) c); break;
						case ' ': MARKDOWN_URI_HEX((unsigned char) c); break;
						default: PUT(c); break;
					}
				}
			} else {
				Markdown::render_character(OUT, c);
			}
		}
	}
}
