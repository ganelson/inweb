[InformSupport::] Inform Support.

To support webs written in Inform 6 or 7.

@h Inform 6.

=
programming_language *InformSupport::create_I6(void) {
	programming_language *pl = Languages::new_language(I"Inform 6", I".i6");
	pl->source_file_extension = I".i6t";
	METHOD_ADD(pl, COMMENT_TAN_MTID, InformSupport::I6_comment);
	METHOD_ADD(pl, OPEN_IFDEF_TAN_MTID, InformSupport::I6_open_ifdef);
	METHOD_ADD(pl, CLOSE_IFDEF_TAN_MTID, InformSupport::I6_close_ifdef);
	METHOD_ADD(pl, WEAVE_CODE_LINE_WEA_MTID, InformSupport::I6_weave_code_line);
	METHOD_ADD(pl, RESET_SYNTAX_COLOURING_WEA_MTID, InformSupport::I6_reset_syntax_colouring);
	METHOD_ADD(pl, BEGIN_WEAVE_WEA_MTID, InformSupport::I6_begin_weave);
	METHOD_ADD(pl, SYNTAX_COLOUR_WEA_MTID, InformSupport::I6_syntax_colour);

	return pl;
}

void InformSupport::I6_comment(programming_language *pl, text_stream *OUT, text_stream *comm) {
	WRITE("! %S\n", comm);
}

void InformSupport::I6_open_ifdef(programming_language *self, text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) WRITE("#ifdef %S;\n", symbol);
	else WRITE("#ifndef %S;\n", symbol);
}

void InformSupport::I6_close_ifdef(programming_language *self, text_stream *OUT, text_stream *symbol, int sense) {
	WRITE("#endif; /* %S */\n", symbol);
}

@h Syntax colouring.
This is a very simple syntax colouring algorithm. The state at any given
time is a single variable, the current category of code being looked at:

=
void InformSupport::I6_begin_weave(programming_language *self, section *S, weave_target *wv) {
	Analyser::mark_reserved_word(S, I"Constant", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"Array", RESERVED_COLOUR);

	Analyser::mark_reserved_word(S, I"box", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"break", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"child", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"children", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"continue", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"default", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"do", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"elder", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"eldest", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"else", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"false", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"font", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"for", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"give", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"has", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"hasnt", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"if", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"in", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"indirect", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"inversion", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"jump", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"metaclass", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"move", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"new_line", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"nothing", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"notin", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"objectloop", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"ofclass", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"or", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"parent", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"print", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"print_ret", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"provides", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"quit", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"random", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"read", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"remove", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"restore", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"return", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"rfalse", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"rtrue", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"save", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"sibling", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"spaces", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"string", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"style", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"switch", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"to", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"true", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"until", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"while", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"younger", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"youngest", RESERVED_COLOUR);
}

void InformSupport::I6_reset_syntax_colouring(programming_language *self) {
	colouring_state = PLAIN_COLOUR;
}
int InformSupport::I6_weave_code_line(programming_language *self, text_stream *OUT,
	weave_target *wv, web *W, chapter *C, section *S, source_line *L,
	text_stream *matter, text_stream *concluding_comment) {
	colouring_state = PLAIN_COLOUR;
	return FALSE;
}

@ =
int InformSupport::I6_syntax_colour(programming_language *self, text_stream *OUT, weave_target *wv,
	web *W, chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *colouring) {
	for (int i=0; i < Str::len(matter); i++) {
		int skip = FALSE, one_off = -1, will_be = -1;
		switch (colouring_state) {
			case PLAIN_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\"': colouring_state = STRING_COLOUR; break;
					case '\'': colouring_state = CHAR_LITERAL_COLOUR; break;
					case '!': colouring_state = COMMENT_COLOUR; break;
				}
				if ((Regexp::identifier_char(Str::get_at(matter, i))) &&
					(Str::get_at(matter, i) != ':')) {
					if ((!(isdigit(Str::get_at(matter, i)))) ||
						((i>0) && (Str::get_at(colouring, i-1) == IDENTIFIER_COLOUR)))
						one_off = IDENTIFIER_COLOUR;
				}
				break;
			case CHAR_LITERAL_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\\': skip = TRUE; break;
					case '\'': will_be = PLAIN_COLOUR; break;
				}
				break;
			case STRING_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\\': skip = TRUE; break;
					case '\"': will_be = PLAIN_COLOUR; break;
				}
				break;				
		}
		if (one_off >= 0) Str::put_at(colouring, i, (char) one_off);
		else Str::put_at(colouring, i, (char) colouring_state);
		if (will_be >= 0) colouring_state = (char) will_be;
		if ((skip) && (Str::get_at(matter, i+1))) i++;
	}
	@<Find identifiers and colour them appropriately@>;
	return FALSE;
}

@ Note that an identifier, followed by |::| and then another identifier, is
merged here into one long identifier. Thus in the code |r = X::Y(1);|, the
above routine would identify three identifiers, |r|, |X| and |Y|; but the
code below merges these into |r| and |X::Y|.

@<Find identifiers and colour them appropriately@> =
	int base = -1, dec_possible = TRUE;
	for (int i=0; i < Str::len(matter); i++) {
		if ((Str::get_at(colouring, i) == PLAIN_COLOUR) ||
			(Str::get_at(colouring, i) == IDENTIFIER_COLOUR)) {
			wchar_t c = Str::get_at(matter, i);
			if (c == '$') {
				if (base == 16) base = 2; else base = 16;
				Str::put_at(colouring, i, (char) CONSTANT_COLOUR);
				dec_possible = TRUE;
				continue;
			}
			if ((c == '-') && (dec_possible)) {
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
	int ident_from = -1;
	for (int i=0; i < Str::len(matter); i++) {
		if (Str::get_at(colouring, i) == IDENTIFIER_COLOUR) {
			if (ident_from == -1) ident_from = i;
		} else {
			if (ident_from >= 0)
				InformSupport::I6_colour_ident(S, matter, colouring, ident_from, i-1);
			ident_from = -1;
		}
	}
	if (ident_from >= 0)
		InformSupport::I6_colour_ident(S, matter, colouring, ident_from, Str::len(matter)-1);

@ Here we look at a word made up of identifier characters and decide whether to
recolour its characters on the basis of what it means.

=
void InformSupport::I6_colour_ident(section *S, text_stream *matter, text_stream *colouring, int from, int to) {
	TEMPORARY_TEXT(id);
	Str::substr(id, Str::at(matter, from), Str::at(matter, to+1));

	int override = -1;
	if (Analyser::is_reserved_word(S, id, FUNCTION_COLOUR)) override = FUNCTION_COLOUR;
	if (Analyser::is_reserved_word(S, id, RESERVED_COLOUR)) override = RESERVED_COLOUR;
	if (Analyser::is_reserved_word(S, id, CONSTANT_COLOUR)) override = CONSTANT_COLOUR;
	if (Analyser::is_reserved_word(S, id, ELEMENT_COLOUR)) {
		int at = --from;
		while ((at > 0) && (Characters::is_space_or_tab(Str::get_at(matter, at)))) at--;
		if (((at >= 0) && (Str::get_at(matter, at) == '.')) ||
			((at >= 0) && (Str::get_at(matter, at-1) == '-') && (Str::get_at(matter, at) == '>')))
			override = ELEMENT_COLOUR;
	}

	if (override >= 0)
		for (int i=from; i<=to; i++)
			Str::put_at(colouring, i, override);
	DISCARD_TEXT(id);
}

@h Inform 7.

=
programming_language *InformSupport::create_I7(void) {
	programming_language *pl = Languages::new_language(I"Inform 7", I".i7x");
	METHOD_ADD(pl, COMMENT_TAN_MTID, InformSupport::I7_comment);
	METHOD_ADD(pl, SUPPRESS_DISCLAIMER_TAN_MTID, InformSupport::suppress_disclaimer);
	return pl;
}

void InformSupport::I7_comment(programming_language *pl, text_stream *OUT, text_stream *comm) {
	WRITE("[%S]\n", comm);
}

@ This is here so that tangling the Standard Rules extension doesn't insert
a spurious comment betraying Inweb's involvement in the process.

=
int InformSupport::suppress_disclaimer(programming_language *pl) {
	return TRUE;
}
