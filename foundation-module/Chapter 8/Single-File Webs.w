[SingleFileWebs::] Single-File Webs.

To scan a single-file web looking for indications of its syntax and/or programming
language, and to assemble a minimal web structure around its one unit of source.

@ A single-file web consists one one section, which is the only one in its
chapter, which is the only one in its web. The web has just one module (the
whole thing), and -- for now, at least -- cannot import others.

The following function doesn't read in the source code stored in the web, it
simply takes a preliminary look.

=
void SingleFileWebs::reconnoiter(ls_web *W) {
	sfw_reader_state RS;
	@<Initialise the reader state@>;
	if (W->web_syntax) WebNotation::declare_syntax_for_web(W, W->web_syntax);
	
	wcl_declaration *D = W->declaration;
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		SingleFileWebs::read_sf_line(line, &tfp, (void *) &RS);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	if (WCL::count_errors(D) > 0) { WCL::report_errors(D); return; }

	ls_chapter *C = WebStructure::new_ls_chapter(W, I"S", I"Sections");
	WebModules::add_chapter(W->main_module, C);
	ls_section *S = WebStructure::new_ls_section(C, I"All", NULL);
	S->source_file_for_section = W->single_file;
	S->source_declaration_for_section = D;
	if (RS.skip_from > 0) S->skip_from = RS.skip_from;
	if (RS.skip_to > 0) S->skip_to = RS.skip_to;

	if (RS.detected_syntax == NULL) @<Try to deduce the syntax from the filename extension@>;

	@<Apply any detected syntax and programming language to the web@>;
}

@ Very much a last resort: this is used only if we didn't know the syntax in
advance, and the file didn't declare one explicitly, and didn't have a shebang.

@<Try to deduce the syntax from the filename extension@> =
	if (W->single_file)
		RS.detected_syntax = WebNotation::guess_from_filename(W, W->single_file);
	if (RS.detected_syntax == NULL) RS.detected_syntax = WebNotation::default();

@<Apply any detected syntax and programming language to the web@> =
	WebNotation::declare_syntax_for_web(W, RS.detected_syntax);

	if (RS.detected_language) WebStructure::set_language(W, RS.detected_language);

@ We are hoping to deduce the web syntax, the programming language, and
whether there is a stretch of lines in the file which are not part of the
source and should be skipped when the section is read in.

The bulk of the file will, of course, be the literate source for the section.
However, it can optionally have exactly one of the following:

(a) A shebang line at the top, indicating the syntax and perhaps also the
title and author, but which is part of the web and is not skipped; or

(b) An opening run of key-value pairs, followed by a blank line, in
which case these are used to set bibliographic data, and are skipped; or

(c) A contiguous run of lines, anywhere in the file, which actually
specifies an ad-hoc syntax to apply to just that file, in which case the
lines containing those syntax definitions are skipped.

=
typedef struct sfw_reader_state {
	struct ls_web *W;

	/* What we aim to find out: */
	struct ls_notation *detected_syntax;
	struct programming_language *detected_language;
	int skip_from;
	int skip_to;

	/* Where we are in the file: */
	int reading_opening_stanza;
	int line_count;
} sfw_reader_state;

@<Initialise the reader state@> =
	RS.W = W;

	RS.detected_syntax = W->web_syntax; /* with |NULL| meaning not yet known */
	RS.detected_language = NULL; /* i.e., unknown */
	RS.skip_from = 0; /* meaning, skip nothing */
	RS.skip_to = 0;
	RS.line_count = 0;

	RS.reading_opening_stanza = TRUE;

@

=
void SingleFileWebs::read_sf_line(text_stream *line, text_file_position *tfp, void *X) {
	sfw_reader_state *RS = (sfw_reader_state *) X;
	RS->line_count++;
	if (Str::is_whitespace(line)) RS->reading_opening_stanza = FALSE;

	if ((RS->detected_syntax == NULL) && (RS->line_count == 1))
		@<Look for a shebang on line 1@>;

	if (RS->reading_opening_stanza) @<Look for key-value pairs at the top of the file@>;
}

@ Maybe the opening line of the web indicates what the web syntax is, and if
so, maybe it also reveals the title and/or author. Note that this line is
part of the web, and is not skipped.

@<Look for a shebang on line 1@> =
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(author)
	ls_notation *S = WebNotation::guess_from_shebang(RS->W, line, tfp, title, author);
	if (S) {
		RS->detected_syntax = S;
		if (Str::len(title) > 0) Bibliographic::set_datum(RS->W, I"Title", title);
		if (Str::len(author) > 0) Bibliographic::set_datum(RS->W, I"Author", author);
		RS->reading_opening_stanza = FALSE;
	}
	DISCARD_TEXT(title)
	DISCARD_TEXT(author)
	if (S) return;

@ React particularly to syntax or programming language declarations, and otherwise
pass bibliographic data on. Note that the opening run of these continues until
the first line which doesn't match, and is then trimmed away by being skipped.

@<Look for key-value pairs at the top of the file@> =
	TEMPORARY_TEXT(key)
	if (((RS->detected_syntax == NULL) ||
			(WebNotation::supports(RS->detected_syntax, KEY_VALUE_PAIRS_WSF))) &&
		(Bibliographic::parse_kvp(RS->W, line, TRUE, tfp, key))) {
		if (Str::eq(key, I"Web Syntax Version")) {
			WCL::error(RS->W->declaration, tfp, I"'Web Syntax Version' has been withdrawn");
			ls_notation *S = WebNotation::syntax_by_name(RS->W, Bibliographic::get_datum(RS->W, key));
			if (S) RS->detected_syntax = S;
		}
		if (Str::eq(key, I"Notation")) {
			ls_notation *S = WebNotation::syntax_by_name(RS->W, Bibliographic::get_datum(RS->W, key));
			if (S) RS->detected_syntax = S;
		}
		if (Str::eq(key, I"Language")) {
			programming_language *L = Languages::find(RS->W, Bibliographic::get_datum(RS->W, key));
			if (L) RS->detected_language = L;
		}
		RS->skip_from = 1; RS->skip_to = tfp->line_count;
	} else {
		RS->reading_opening_stanza = FALSE;
	}
	DISCARD_TEXT(key)
