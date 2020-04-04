[ACMESupport::] ACME Support.

To support webs written in the ACME assembly language syntax.

@h Creation.
This is just plain text, in fact, but with syntax colouring.

=
programming_language *ACMESupport::create(void) {
	programming_language *pl = Languages::new_language(I"ACME", I".a");
	METHOD_ADD(pl, COMMENT_TAN_MTID, ACMESupport::comment);
	METHOD_ADD(pl, PARSE_COMMENT_TAN_MTID, ACMESupport::parse_comment);
	METHOD_ADD(pl, RESET_SYNTAX_COLOURING_WEA_MTID, ACMESupport::reset_syntax_colouring);
	METHOD_ADD(pl, SYNTAX_COLOUR_WEA_MTID, ACMESupport::syntax_colour);
	return pl;
}

@h Tangling methods.

=
void ACMESupport::comment(programming_language *self,
	text_stream *OUT, text_stream *comm) {
	WRITE("; %S\n", comm);
}

int ACMESupport::parse_comment(programming_language *self,
	text_stream *line, text_stream *part_before_comment, text_stream *part_within_comment) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"; *")) {
		Str::clear(part_before_comment);
		Str::copy(part_within_comment, I"");
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, line, L"; (%c*?) *")) {
		Str::clear(part_before_comment);
		Str::copy(part_within_comment, mr.exp[0]);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, line, L"(%c*);")) {
		Str::copy(part_before_comment, mr.exp[0]);
		Str::copy(part_within_comment, I"");
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, line, L"(%c*); (%c*?) *")) {
		Str::copy(part_before_comment, mr.exp[0]);
		Str::copy(part_within_comment, mr.exp[1]);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	Regexp::dispose_of(&mr);
	return FALSE;
}

@h Syntax colouring.
This is a very simple syntax colouring algorithm. The state at any given
time is a single variable, the current category of code being looked at:

=
void ACMESupport::reset_syntax_colouring(programming_language *self) {
	colouring_state = PLAIN_COLOUR;
}

@ =
int ACMESupport::syntax_colour(programming_language *self, text_stream *OUT, weave_target *wv,
	web *W, chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *colouring) {
	for (int i=0; i < Str::len(matter); i++) {
		int skip = FALSE, one_off = -1, will_be = -1;
		switch (colouring_state) {
			case PLAIN_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\"': colouring_state = STRING_COLOUR; break;
					case '\'': colouring_state = CHAR_LITERAL_COLOUR; break;
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
	for (int i=0; i < Str::len(matter); i++) {
		switch (Str::get_at(matter, i)) {
			case '+': Str::put_at(colouring, i, IDENTIFIER_COLOUR); break;
			case '-': Str::put_at(colouring, i, IDENTIFIER_COLOUR); break;
		}
	}
	return FALSE;
}

@<Find identifiers and colour them appropriately@> =
	int ident_from = -1;
	for (int i=0; i < Str::len(matter); i++) {
		if (Str::get_at(colouring, i) == IDENTIFIER_COLOUR) {
			if (ident_from == -1) ident_from = i;
		} else {
			if (ident_from >= 0)
				ACMESupport::colour_ident(S, matter, colouring, ident_from, i-1);
			ident_from = -1;
		}
	}
	if (ident_from >= 0)
		ACMESupport::colour_ident(S, matter, colouring, ident_from, Str::len(matter)-1);

@ Here we look at a word made up of identifier characters -- such as |int|, |X|,
or |CLike::colour_ident| -- and decide whether to recolour its characters on
the basis of what it means.

=
void ACMESupport::colour_ident(section *S, text_stream *matter, text_stream *colouring, int from, int to) {
	TEMPORARY_TEXT(id);
	Str::substr(id, Str::at(matter, from), Str::at(matter, to+1));

	int override = RESERVED_COLOUR;
	if ((from > 0) && (Str::get_at(matter, from-1) == '.')) override = -1;
	if ((from > 0) && (Str::get_at(matter, from-1) == '$')) override = PLAIN_COLOUR;
	if ((from > 0) && (Str::get_at(matter, from-1) == '!')) override = ELEMENT_COLOUR;
	if ((from > 0) && (Characters::isdigit(Str::get_at(matter, from-1)))) override = PLAIN_COLOUR;

	if (override >= 0)
		for (int i=from; i<=to; i++)
			Str::put_at(colouring, i, override);
	DISCARD_TEXT(id);
}
