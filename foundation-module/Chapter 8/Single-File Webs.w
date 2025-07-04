[SingleFileWebs::] Single-File Webs.

To scan a single-file web looking for indications of its syntax and/or programming
language, and to assemble a minimal web structure around its one unit of source.

@ A single-file web consists one one section, which is the only one in its
chapter, which is the only one in its web. The web has just one module (the
whole thing), and -- for now, at least -- cannot import others.

The following function doesn't read in the source code stored in the web, it
simply takes a preliminary look.

=
void SingleFileWebs::reconnoiter(ls_web *W, int verbosely) {
	sfw_reader_state RS;
	@<Initialise the reader state@>;
	if (W->web_syntax) WebSyntax::declare_syntax_for_web(W, W->web_syntax);
	TextFiles::read(W->single_file, FALSE, "can't open contents file",
		TRUE, SingleFileWebs::read_sf_line, NULL, &RS);

	ls_chapter *C = WebStructure::new_ls_chapter(W, I"S", I"Sections");
	WebModules::add_chapter(W->main_module, C);
	ls_section *S = WebStructure::new_ls_section(C, I"All");
	S->source_file_for_section = W->single_file;
	if (RS.skip_from > 0) S->skip_from = RS.skip_from;
	if (RS.skip_to > 0) S->skip_to = RS.skip_to;

	if (RS.detected_syntax == NULL) @<Try to deduce the syntax from the filename extension@>;

	@<Apply any detected syntax and programming language to the web@>;

	if (verbosely)
		PRINT("(Single-file web at %f: syntax %S, language %S: skipping line(s) %d-%d)\n",
		W->single_file,
		W->web_syntax?(W->web_syntax->name):(I"none"),
		W->web_language?(W->web_language->language_name):(I"none"),
		S->skip_from, S->skip_to);
}

@ Very much a last resort: this is used only if we didn't know the syntax in
advance, and the file didn't declare one explicitly, and didn't have a shebang.

@<Try to deduce the syntax from the filename extension@> =
	RS.detected_syntax = WebSyntax::guess_from_filename(W->single_file);
	if (RS.detected_syntax == NULL) RS.detected_syntax = WebSyntax::default();

@<Apply any detected syntax and programming language to the web@> =
	WebSyntax::declare_syntax_for_web(W, RS.detected_syntax);

	if (RS.detected_language) {
		W->web_language = RS.detected_language;
		C->ch_language = RS.detected_language;
		S->sect_language = RS.detected_language;
	}

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
	struct ls_syntax *detected_syntax;
	struct programming_language *detected_language;
	int skip_from;
	int skip_to;

	/* Where we are in the file: */
	int reading_opening_stanza;
	int reading_syntax_instructions;

	/* Relevant only when reading syntax instructions: */
	struct text_stream *syntax_prefix;
	struct text_stream *syntax_suffix;
} sfw_reader_state;

@<Initialise the reader state@> =
	RS.W = W;

	RS.detected_syntax = W->web_syntax; /* with |NULL| meaning not yet known */
	RS.detected_language = NULL; /* i.e., unknown */
	RS.skip_from = 0; /* meaning, skip nothing */
	RS.skip_to = 0;

	RS.reading_opening_stanza = TRUE;
	RS.reading_syntax_instructions = FALSE;
	RS.syntax_prefix = NULL;
	RS.syntax_suffix = NULL;

@

=
void SingleFileWebs::read_sf_line(text_stream *line, text_file_position *tfp, void *X) {
	sfw_reader_state *RS = (sfw_reader_state *) X;
	if (Str::is_whitespace(line)) RS->reading_opening_stanza = FALSE;

	if ((RS->detected_syntax == NULL) && (tfp->line_count == 1))
		@<Look for a shebang on line 1@>;

	if (RS->reading_opening_stanza) @<Look for key-value pairs at the top of the file@>;
	
	if (RS->reading_syntax_instructions == FALSE)
		@<Enter syntax instructions block@>
	else if (RS->reading_syntax_instructions == TRUE)
		@<Parse a line within the syntax instructions block@>;
}

@ Maybe the opening line of the web indicates what the web syntax is, and if
so, maybe it also reveals the title and/or author. Note that this line is
part of the web, and is not skipped.

@<Look for a shebang on line 1@> =
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(author)
	ls_syntax *S = WebSyntax::guess_from_shebang(line, tfp, title, author);
	if (S) {
		RS->detected_syntax = S;
		if (Str::len(title) > 0) Bibliographic::set_datum(RS->W, I"Title", title);
		if (Str::len(author) > 0) Bibliographic::set_datum(RS->W, I"Author", author);
		RS->reading_syntax_instructions = NOT_APPLICABLE;
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
			(WebSyntax::supports(RS->detected_syntax, KEY_VALUE_PAIRS_WSF))) &&
		(Bibliographic::parse_kvp(RS->W, line, TRUE, tfp, key))) {
		if (Str::eq(key, I"Web Syntax Version")) {
			ls_syntax *S = WebSyntax::syntax_by_name(Bibliographic::get_datum(RS->W, key));
			if (S) RS->detected_syntax = S;
		}
		if (Str::eq(key, I"Language")) {
			programming_language *L = TangleTargets::find_language(Bibliographic::get_datum(RS->W, key), RS->W,
				FALSE);
			if (L) RS->detected_language = L;
		}
		RS->skip_from = 1; RS->skip_to = tfp->line_count;
		RS->reading_syntax_instructions = NOT_APPLICABLE;
	} else {
		RS->reading_opening_stanza = FALSE;
	}
	DISCARD_TEXT(key)

@ That just leaves the ad-hoc syntax definition.

@<Enter syntax instructions block@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%c*? *)inweb syntax:(%c*?) *")) {
		RS->syntax_prefix = Str::duplicate(mr.exp[0]);
		RS->syntax_suffix = Str::duplicate(mr.exp[1]);
		Str::trim_white_space_at_end(RS->syntax_suffix);
		RS->reading_syntax_instructions = TRUE;
		RS->detected_syntax = WebSyntax::read_definition(NULL);
		RS->skip_from = tfp->line_count;
	}
	Regexp::dispose_of(&mr);

@<Parse a line within the syntax instructions block@> =
	Str::trim_white_space_at_end(line);
	if ((Str::begins_with(line, RS->syntax_prefix)) &&
		(Str::ends_with(line, RS->syntax_suffix))) {
		TEMPORARY_TEXT(middle)
		Str::substr(middle,
			Str::at(line, Str::len(RS->syntax_prefix)), 
			Str::at(line, Str::len(line) - Str::len(RS->syntax_suffix)));
		text_stream *error = WebSyntax::apply_syntax_setting(RS->detected_syntax, middle);
		DISCARD_TEXT(middle)
		if (Str::len(error) > 0) Errors::in_text_file_S(error, tfp);
		RS->skip_to = tfp->line_count;
	} else {
		RS->reading_syntax_instructions = NOT_APPLICABLE;
	}
