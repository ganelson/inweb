[ACMESupport::] ACME Support.

For generic programming languages by the ACME corporation.

@h One Dozen ACME Explosive Tennis Balls.
Older readers will remember that Wile E. Coyote, when wishing to frustrate
Road Runner with some ingenious device, would invariably buy it from the Acme
Corporation, which manufactured everything imaginable. See Wikipedia, "Acme
Corporation", for much else.

For us, ACME is an imaginary programming language, providing generic support
for comments and syntax colouring. Ironically, this code grew out of a language
actually called ACME: the 6502 assembler of the same name.

=
void ACMESupport::add_fallbacks(programming_language *pl) {	
	if (Methods::provided(pl->methods, PARSE_COMMENT_TAN_MTID) == FALSE)
		METHOD_ADD(pl, PARSE_COMMENT_TAN_MTID, ACMESupport::parse_comment);
	if (Methods::provided(pl->methods, COMMENT_TAN_MTID) == FALSE)
		METHOD_ADD(pl, COMMENT_TAN_MTID, ACMESupport::comment);
	if (Methods::provided(pl->methods, SHEBANG_TAN_MTID) == FALSE)
		METHOD_ADD(pl, SHEBANG_TAN_MTID, ACMESupport::shebang);
	if (Methods::provided(pl->methods, BEFORE_MACRO_EXPANSION_TAN_MTID) == FALSE)
		METHOD_ADD(pl, BEFORE_MACRO_EXPANSION_TAN_MTID, ACMESupport::before_macro_expansion);
	if (Methods::provided(pl->methods, AFTER_MACRO_EXPANSION_TAN_MTID) == FALSE)
		METHOD_ADD(pl, AFTER_MACRO_EXPANSION_TAN_MTID, ACMESupport::after_macro_expansion);
	if (Methods::provided(pl->methods, START_DEFN_TAN_MTID) == FALSE)
		METHOD_ADD(pl, START_DEFN_TAN_MTID, ACMESupport::start_definition);
	if (Methods::provided(pl->methods, PROLONG_DEFN_TAN_MTID) == FALSE)
		METHOD_ADD(pl, PROLONG_DEFN_TAN_MTID, ACMESupport::prolong_definition);
	if (Methods::provided(pl->methods, END_DEFN_TAN_MTID) == FALSE)
		METHOD_ADD(pl, END_DEFN_TAN_MTID, ACMESupport::end_definition);
	if (Methods::provided(pl->methods, OPEN_IFDEF_TAN_MTID) == FALSE)
		METHOD_ADD(pl, OPEN_IFDEF_TAN_MTID, ACMESupport::I6_open_ifdef);
	if (Methods::provided(pl->methods, CLOSE_IFDEF_TAN_MTID) == FALSE)
		METHOD_ADD(pl, CLOSE_IFDEF_TAN_MTID, ACMESupport::I6_close_ifdef);
	if (Methods::provided(pl->methods, INSERT_LINE_MARKER_TAN_MTID) == FALSE)
		METHOD_ADD(pl, INSERT_LINE_MARKER_TAN_MTID, ACMESupport::insert_line_marker);
	if (Methods::provided(pl->methods, SUPPRESS_DISCLAIMER_TAN_MTID) == FALSE)
		METHOD_ADD(pl, SUPPRESS_DISCLAIMER_TAN_MTID, ACMESupport::suppress_disclaimer);
	if (Methods::provided(pl->methods, BEGIN_WEAVE_WEA_MTID) == FALSE)
		METHOD_ADD(pl, BEGIN_WEAVE_WEA_MTID, ACMESupport::begin_weave);
	if (Methods::provided(pl->methods, RESET_SYNTAX_COLOURING_WEA_MTID) == FALSE)
		METHOD_ADD(pl, RESET_SYNTAX_COLOURING_WEA_MTID, ACMESupport::reset_syntax_colouring);
	if (Methods::provided(pl->methods, SYNTAX_COLOUR_WEA_MTID) == FALSE)
		METHOD_ADD(pl, SYNTAX_COLOUR_WEA_MTID, ACMESupport::syntax_colour);
}

@ This utility does a very limited |WRITE|-like job. (We don't want to use
the actual |WRITE| because that would make it possible for malicious language
files to crash Inweb.)

=
void ACMESupport::expand(OUTPUT_STREAM, text_stream *prototype, text_stream *S,
	int N, filename *F) {
	if (Str::len(prototype) > 0) {
		for (int i=0; i<Str::len(prototype); i++) {
			wchar_t c = Str::get_at(prototype, i);
			if ((c == '%') && (Str::get_at(prototype, i+1) == 'S') && (S)) {
				WRITE("%S", S);
				i++;
			} else if ((c == '%') && (Str::get_at(prototype, i+1) == 'd') && (N >= 0)) {
				WRITE("%d", N);
				i++;
			} else if ((c == '%') && (Str::get_at(prototype, i+1) == 'f') && (F)) {
				WRITE("%/f", F);
				i++;
			} else {
				PUT(c);
			}
		}
	}
}

@h Tangling methods.

=
void ACMESupport::shebang(programming_language *pl, text_stream *OUT, web *W,
	tangle_target *target) {
	ACMESupport::expand(OUT, pl->shebang, NULL, -1, NULL);
}

void ACMESupport::before_macro_expansion(programming_language *pl,
	OUTPUT_STREAM, para_macro *pmac) {
	ACMESupport::expand(OUT, pl->before_macro_expansion, NULL, -1, NULL);
}

void ACMESupport::after_macro_expansion(programming_language *pl,
	OUTPUT_STREAM, para_macro *pmac) {
	ACMESupport::expand(OUT, pl->after_macro_expansion, NULL, -1, NULL);
}

int ACMESupport::start_definition(programming_language *pl, text_stream *OUT,
	text_stream *term, text_stream *start, section *S, source_line *L) {
	if (LanguageMethods::supports_definitions(pl)) {
		ACMESupport::expand(OUT, pl->start_definition, term, -1, NULL);
		Tangler::tangle_code(OUT, start, S, L);
	}
	return TRUE;
}

int ACMESupport::prolong_definition(programming_language *pl,
	text_stream *OUT, text_stream *more, section *S, source_line *L) {
	if (LanguageMethods::supports_definitions(pl)) {
		ACMESupport::expand(OUT, pl->prolong_definition, NULL, -1, NULL);
		Tangler::tangle_code(OUT, more, S, L);
	}
	return TRUE;
}

int ACMESupport::end_definition(programming_language *pl,
	text_stream *OUT, section *S, source_line *L) {
	if (LanguageMethods::supports_definitions(pl)) {
		ACMESupport::expand(OUT, pl->end_definition, NULL, -1, NULL);
	}
	return TRUE;
}

void ACMESupport::I6_open_ifdef(programming_language *pl,
	text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) ACMESupport::expand(OUT, pl->start_ifdef, symbol, -1, NULL);
	else ACMESupport::expand(OUT, pl->start_ifndef, symbol, -1, NULL);
}

void ACMESupport::I6_close_ifdef(programming_language *pl,
	text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) ACMESupport::expand(OUT, pl->end_ifdef, symbol, -1, NULL);
	else ACMESupport::expand(OUT, pl->end_ifndef, symbol, -1, NULL);
}

void ACMESupport::insert_line_marker(programming_language *pl,
	text_stream *OUT, source_line *L) {
	ACMESupport::expand(OUT, pl->line_marker, NULL,
		L->source.line_count, L->source.text_file_filename);
}

void ACMESupport::comment(programming_language *pl,
	text_stream *OUT, text_stream *comm) {
	if (Str::len(pl->multiline_comment_open) > 0) {
		ACMESupport::expand(OUT, pl->multiline_comment_open, NULL, -1, NULL);
		WRITE(" %S ", comm);
		ACMESupport::expand(OUT, pl->multiline_comment_close, NULL, -1, NULL);
		WRITE("\n");
	} else if (Str::len(pl->line_comment) > 0) {
		ACMESupport::expand(OUT, pl->line_comment, NULL, -1, NULL);
		WRITE(" %S\n", comm);
	} else if (Str::len(pl->whole_line_comment) > 0) {
		ACMESupport::expand(OUT, pl->whole_line_comment, NULL, -1, NULL);
		WRITE(" %S\n", comm);
	}
}

int ACMESupport::parse_comment(programming_language *pl,
	text_stream *line, text_stream *part_before_comment, text_stream *part_within_comment) {
	int q_mode = 0, c_mode = FALSE, non_white_space = FALSE, c_position = -1, c_end = -1;
	for (int i=0; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		if (c_mode == 2) {
			if (ACMESupport::text_at(line, i, pl->multiline_comment_close)) {
				c_mode = 0; c_end = i; i += Str::len(pl->multiline_comment_close) - 1;
			}
		} else {
			if ((c_mode == 0) && (!(Characters::is_whitespace(c)))) non_white_space = TRUE;
			if ((c == Str::get_first_char(pl->string_literal_escape)) && (q_mode == 2)) i += 1;
			if ((c == Str::get_first_char(pl->character_literal_escape)) && (q_mode == 1)) i += 1;
			if (c == Str::get_first_char(pl->string_literal)) {
				if (q_mode == 0) q_mode = 2;
				else if (q_mode == 2) q_mode = 0;
			}
			if (c == Str::get_first_char(pl->character_literal)) {
				if (q_mode == 0) q_mode = 1;
				else if (q_mode == 1) q_mode = 0;
			}
			if (ACMESupport::text_at(line, i, pl->multiline_comment_open)) {
				c_mode = 2; c_position = i; non_white_space = FALSE;
				i += Str::len(pl->multiline_comment_open) - 1;
			}
			if (ACMESupport::text_at(line, i, pl->line_comment)) {
				c_mode = 1; c_position = i; c_end = Str::len(line); non_white_space = FALSE;
				i += Str::len(pl->line_comment) - 1;
			}
			if (ACMESupport::text_at(line, i, pl->whole_line_comment)) {
				int material_exists = FALSE;
				for (int j=0; j<i; j++)
					if (!(Characters::is_whitespace(Str::get_at(line, j))))
						material_exists = TRUE;
				if (material_exists == FALSE) {
					c_mode = 1; c_position = i; c_end = Str::len(line);
					non_white_space = FALSE;
					i += Str::len(pl->whole_line_comment) - 1;
				}
			}
		}
	}
	if ((c_position >= 0) && (non_white_space == FALSE)) {
		Str::clear(part_before_comment);
		for (int i=0; i<c_position; i++)
			PUT_TO(part_before_comment, Str::get_at(line, i));
		Str::clear(part_within_comment);
		for (int i=c_position + 2; i<c_end; i++)
			PUT_TO(part_within_comment, Str::get_at(line, i));
		Str::trim_white_space(part_within_comment);
		return TRUE;
	}
	return FALSE;
}

int ACMESupport::text_at(text_stream *line, int i, text_stream *pattern) {
	if (Str::len(pattern) == 0) return FALSE;
	if (i < 0) return FALSE;
	if (i + Str::len(pattern) > Str::len(line)) return FALSE;
	LOOP_THROUGH_TEXT(pos, pattern)
		if (Str::get(pos) != Str::get_at(line, i++))
			return FALSE;
	return TRUE;
}

@ This is here so that tangling the Standard Rules extension doesn't insert
a spurious comment betraying Inweb's involvement in the process.

=
int ACMESupport::suppress_disclaimer(programming_language *pl) {
	return pl->suppress_disclaimer;
}

@

=
void ACMESupport::begin_weave(programming_language *pl, section *S, weave_target *wv) {
	reserved_word *rw;
	LOOP_OVER_LINKED_LIST(rw, reserved_word, pl->reserved_words)
		Analyser::mark_reserved_word_for_section(S, rw->word, rw->colour);
}

@ ACME has all of its syntax-colouring done by the default engine:

=
void ACMESupport::reset_syntax_colouring(programming_language *pl) {
	Painter::reset_syntax_colouring(pl);
}

int ACMESupport::syntax_colour(programming_language *pl, text_stream *OUT, weave_target *wv,
	web *W, chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *colouring) {
	hash_table *ht = &(S->sect_target->symbols);
	if ((L->category == TEXT_EXTRACT_LCAT) && (pl != S->sect_language))
		ht = &(pl->built_in_keywords);
	return Painter::syntax_colour(pl, ht, matter, colouring, FALSE);
}
