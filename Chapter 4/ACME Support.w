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

void ACMESupport::expand(OUTPUT_STREAM, text_stream *prototype, text_stream *S, int N, filename *F) {
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
void ACMESupport::shebang(programming_language *pl, text_stream *OUT, web *W, tangle_target *target) {
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
	ACMESupport::expand(OUT, pl->start_definition, term, -1, NULL);
	Tangler::tangle_code(OUT, start, S, L);
	return TRUE;
}

int ACMESupport::prolong_definition(programming_language *pl,
	text_stream *OUT, text_stream *more, section *S, source_line *L) {
	ACMESupport::expand(OUT, pl->prolong_definition, NULL, -1, NULL);
	Tangler::tangle_code(OUT, more, S, L);
	return TRUE;
}

int ACMESupport::end_definition(programming_language *pl,
	text_stream *OUT, section *S, source_line *L) {
	ACMESupport::expand(OUT, pl->end_definition, NULL, -1, NULL);
	return TRUE;
}

void ACMESupport::I6_open_ifdef(programming_language *pl, text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) ACMESupport::expand(OUT, pl->start_ifdef, symbol, -1, NULL);
	else ACMESupport::expand(OUT, pl->start_ifndef, symbol, -1, NULL);
}

void ACMESupport::I6_close_ifdef(programming_language *pl, text_stream *OUT, text_stream *symbol, int sense) {
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
	}
	else if (Str::len(pl->line_comment) > 0) {
		ACMESupport::expand(OUT, pl->line_comment, NULL, -1, NULL);
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
		}
	}
	if ((c_position >= 0) && (non_white_space == FALSE)) {
		Str::clear(part_before_comment);
		for (int i=0; i<c_position; i++) PUT_TO(part_before_comment, Str::get_at(line, i));
		Str::clear(part_within_comment);
		for (int i=c_position + 2; i<c_end; i++) PUT_TO(part_within_comment, Str::get_at(line, i));
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
		Analyser::mark_reserved_word(S, rw->word, rw->colour);
}

@h Syntax colouring.
This is a very simple syntax colouring algorithm. The state at any given
time is a single variable, the current category of code being looked at:

=
void ACMESupport::reset_syntax_colouring(programming_language *pl) {
	colouring_state = PLAIN_COLOUR;
}

@ =
int ACMESupport::syntax_colour(programming_language *pl, text_stream *OUT, weave_target *wv,
	web *W, chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *colouring) {
	@<Make preliminary colouring@>;
	@<Spot literal numerical constants@>;
	linked_list *rules = pl->program->rules;
	ACMESupport::execute(S, rules, matter, colouring, 0, Str::len(matter));
	return FALSE;
}

@<Make preliminary colouring@> =
	int squote = Str::get_first_char(pl->character_literal);
	int squote_escape = Str::get_first_char(pl->character_literal_escape);
	int dquote = Str::get_first_char(pl->string_literal);
	int dquote_escape = Str::get_first_char(pl->string_literal_escape);
	for (int i=0; i < Str::len(matter); i++) {
		int skip = 0, one_off = -1, will_be = -1;
		switch (colouring_state) {
			case PLAIN_COLOUR: {
				wchar_t c = Str::get_at(matter, i);
				if (c == dquote) {
					colouring_state = STRING_COLOUR;
					break;
				}
				if (c == squote) {
					colouring_state = CHAR_LITERAL_COLOUR;
					break;
				}
				if (ACMESupport::identifier_at(pl, matter, colouring, i))
					one_off = IDENTIFIER_COLOUR;
				break;
			}
			case CHAR_LITERAL_COLOUR: {
				wchar_t c = Str::get_at(matter, i);
				if (c == squote) will_be = PLAIN_COLOUR;
				if (c == squote_escape) skip = 1;
				break;
			}
			case STRING_COLOUR: {
				wchar_t c = Str::get_at(matter, i);
				if (c == dquote) will_be = PLAIN_COLOUR;
				if (c == dquote_escape) skip = 1;
				break;
			}
		}
		if (one_off >= 0) Str::put_at(colouring, i, (char) one_off);
		else Str::put_at(colouring, i, (char) colouring_state);
		if (will_be >= 0) colouring_state = (char) will_be;
		if (skip > 0) i += skip;
	}

@<Spot literal numerical constants@> =
	int base = -1, dec_possible = TRUE;
	for (int i=0; i < Str::len(matter); i++) {
		if ((Str::get_at(colouring, i) == PLAIN_COLOUR) ||
			(Str::get_at(colouring, i) == IDENTIFIER_COLOUR)) {
			wchar_t c = Str::get_at(matter, i);
			if (ACMESupport::text_at(matter, i, pl->binary_literal_prefix)) {
				base = 2;
				for (int j=0; j<Str::len(pl->binary_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				dec_possible = TRUE;
				continue;
			} else if (ACMESupport::text_at(matter, i, pl->octal_literal_prefix)) {
				base = 8;
				for (int j=0; j<Str::len(pl->octal_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				dec_possible = TRUE;
				continue;
			} else if (ACMESupport::text_at(matter, i, pl->hexadecimal_literal_prefix)) {
				base = 16;
				for (int j=0; j<Str::len(pl->hexadecimal_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				dec_possible = TRUE;
				continue;
			} 
			if ((ACMESupport::text_at(matter, i, pl->negative_literal_prefix)) &&
				(dec_possible) && (base == 0)) {
				base = 10;
				Str::put_at(colouring, i, (char) CONSTANT_COLOUR);
				continue;
			}
			int pass = FALSE;
			switch (base) {
				case -1: 
					if ((dec_possible) && (Characters::isdigit(c))) {
						base = 10; pass = TRUE;
					}
					break;
				case 2: if ((c == '0') || (c == '1')) pass = TRUE; break;
				case 10: if (Characters::isdigit(c)) pass = TRUE; break;
				case 16: if (Characters::isdigit(c)) pass = TRUE;
					int d = Characters::tolower(c);
					if ((d == 'a') || (d == 'b') || (d == 'c') ||
						(d == 'd') || (d == 'e') || (d == 'f')) pass = TRUE;
					break;
			}
			if (pass) {
				Str::put_at(colouring, i, (char) CONSTANT_COLOUR);
			} else {
				if (Characters::is_whitespace(c)) dec_possible = TRUE;
				else dec_possible = FALSE;
				base = -1;
			}
		}
	}

@

=
int ACMESupport::identifier_at(programming_language *pl, text_stream *matter, text_stream *colouring, int i) {
	wchar_t c = Str::get_at(matter, i);
	if ((i > 0) && (Str::get_at(colouring, i-1) == IDENTIFIER_COLOUR)) {
		if ((c == '_') ||
			((c >= 'A') && (c <= 'Z')) ||
			((c >= 'a') && (c <= 'z')) ||
			((c >= '0') && (c <= '9'))) return TRUE;
		if ((c == ':') && (pl->supports_namespaces)) return TRUE;
	} else {
		wchar_t d = 0;
		if (i > 0) d = Str::get_at(matter, i);
		if ((d >= '0') && (d <= '9')) return FALSE;
		if ((c == '_') ||
			((c >= 'A') && (c <= 'Z')) ||
			((c >= 'a') && (c <= 'z'))) return TRUE;
	}
	return FALSE;
}

@ 

=
void ACMESupport::execute(section *S, linked_list *rules, text_stream *matter,
	text_stream *colouring, int from, int to) {
	colouring_rule *rule;
	LOOP_OVER_LINKED_LIST(rule, colouring_rule, rules) {
		if (rule->run == CHARACTERS_CRULE_RUN) {
			for (int i=from; i<=to; i++)
				ACMESupport::execute(S, rule->block->rules, matter, colouring, i, i);
		} else if (rule->run == WHOLE_LINE_CRULE_RUN) {
			if (ACMESupport::satisfies(S, rule, matter, colouring, from, to))
				ACMESupport::follow(S, rule, matter, colouring, from, to);
		} else {
			int ident_from = -1;
			for (int i=from; i<=to; i++) {
				int col = Str::get_at(colouring, i);
				if ((col == rule->run) ||
					((rule->run == UNQUOTED_COLOUR) &&
						((col != STRING_COLOUR) && (col != CHAR_LITERAL_COLOUR)))) {
					if (ident_from == -1) ident_from = i;
				} else {
					if (ident_from >= 0)
						ACMESupport::execute(S, rule->block->rules, matter, colouring, ident_from, i-1);
					ident_from = -1;
				}
			}
			if (ident_from >= 0)
				ACMESupport::execute(S, rule->block->rules, matter, colouring, ident_from, to);
		}
	}
}

int ACMESupport::satisfies(section *S, colouring_rule *rule, text_stream *matter,
	text_stream *colouring, int from, int to) {
	if (Str::len(rule->on) > 0) {
		if (rule->prefix != NOT_A_RULE_PREFIX) {
			int pos = from;
			if (rule->prefix != UNSPACED_RULE_PREFIX) {
				while ((pos > 0) && (Characters::is_whitespace(pos-1))) pos--;
				if ((rule->prefix == SPACED_RULE_PREFIX) && (pos == from))
					return FALSE;
			}
			if (ACMESupport::text_at(matter, pos-Str::len(rule->on), rule->on) == FALSE)
				return FALSE;
		} else {
			if (Str::ne(matter, rule->on)) return FALSE;
		}
	} else if (rule->keyword_colour != NOT_A_COLOUR) {
		TEMPORARY_TEXT(id);
		Str::substr(id, Str::at(matter, from), Str::at(matter, to+1));
		int rw = Analyser::is_reserved_word(S, id, rule->keyword_colour);
		DISCARD_TEXT(id);
		if (rw == FALSE) return FALSE;
	}
	return TRUE;
}

void ACMESupport::follow(section *S, colouring_rule *rule, text_stream *matter,
	text_stream *colouring, int from, int to) {
	if (rule->block) ACMESupport::execute(S, rule->block->rules, matter, colouring, from, to);
	else 
		for (int i=from; i<=to; i++)
			Str::put_at(colouring, i, rule->colour);
}
