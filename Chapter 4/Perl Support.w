[PerlSupport::] Perl Support.

To support webs written in Perl.

@h Creation.
Support for Perl is pretty minimal, in fact, and since the Inform project
no longer uses Perl as the language of any of its tools, improving all this
(adding syntax colouring, say) isn't a priority.

=
programming_language *PerlSupport::create(void) {
	programming_language *pl = Languages::new_language(I"Perl", I".pl");

	METHOD_ADD(pl, SHEBANG_TAN_MTID, PerlSupport::shebang);
	METHOD_ADD(pl, START_DEFN_TAN_MTID, PerlSupport::start_definition);
	METHOD_ADD(pl, END_DEFN_TAN_MTID, PerlSupport::end_definition);
	METHOD_ADD(pl, INSERT_LINE_MARKER_TAN_MTID, PerlSupport::insert_line_marker);
	METHOD_ADD(pl, BEFORE_MACRO_EXPANSION_TAN_MTID, PerlSupport::before_macro_expansion);
	METHOD_ADD(pl, AFTER_MACRO_EXPANSION_TAN_MTID, PerlSupport::after_macro_expansion);
	METHOD_ADD(pl, PARSE_COMMENT_TAN_MTID, PerlSupport::parse_comment);
	METHOD_ADD(pl, COMMENT_TAN_MTID, PerlSupport::comment);

	return pl;
}

@h Tangling methods.

=
void PerlSupport::shebang(programming_language *self, text_stream *OUT, web *W, tangle_target *target) {
	WRITE("#!/usr/bin/perl\n\n");
}

int PerlSupport::start_definition(programming_language *self, text_stream *OUT,
	text_stream *term, text_stream *start, section *S, source_line *L) {
	WRITE("%S = ", term);
	Tangler::tangle_code(OUT, start, S, L);
	return TRUE;
}

int PerlSupport::end_definition(programming_language *self,
	text_stream *OUT, section *S, source_line *L) {
	WRITE("\n;\n");
	return TRUE;
}

@ In its usual zany way, Perl recognises the same |#line| syntax as C, thus in
principle overloading its comment notation |#|:

=
void PerlSupport::insert_line_marker(programming_language *self,
	text_stream *OUT, source_line *L) {
	WRITE("#line %d \"%/f\"\n",
		L->source.line_count,
		L->source.text_file_filename);
}

@ =
void PerlSupport::before_macro_expansion(programming_language *self,
	OUTPUT_STREAM, para_macro *pmac) {
	WRITE("\n{\n");
}

void PerlSupport::after_macro_expansion(programming_language *self,
	OUTPUT_STREAM, para_macro *pmac) {
	WRITE("}\n");
}

@ =
void PerlSupport::comment(programming_language *self,
	text_stream *OUT, text_stream *comm) {
	WRITE("# %S\n", comm);
}

int PerlSupport::parse_comment(programming_language *self,
	text_stream *line, text_stream *part_before_comment, text_stream *part_within_comment) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"# (%c*?) *")) {
		Str::clear(part_before_comment);
		Str::copy(part_within_comment, mr.exp[0]);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, line, L"(%c*) # (%c*?) *")) {
		Str::copy(part_before_comment, mr.exp[0]);
		Str::copy(part_within_comment, mr.exp[1]);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	Regexp::dispose_of(&mr);
	return FALSE;
}
