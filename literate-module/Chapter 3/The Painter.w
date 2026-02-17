[Painter::] The Painter.

A simple syntax-colouring engine.

@ This is a very simple syntax colouring algorithm. The work is done by the
function |Painter::syntax_colour|, which can in principle be applied to texts
of any length. But it's usually convenient to run it on a long file one line
at a time, so that it is called repeatedly. The variable |colouring_state|
remembers where we were at the end of the previous line, so that we can pick
up again later at the start of the next.

Because of that, we need to call the following before we begin a run of calls
to |Painter::syntax_colour|:

=
int colouring_state = PLAIN_COLOUR;
int painter_count = 1;
void Painter::reset_syntax_colouring(programming_language *pl) {
	colouring_state = PLAIN_COLOUR;
	painter_count = 1;
}

@ As we begin, the text to colour is in |matter|, while |colouring| is an
equal-length text where each character represents the colour of its
corresponding character in |matter|. For example, we might start as:
= (text as PainterOutput)
	int x = 55;
	ppppppppppp
=
with every character having |PLAIN_COLOUR|, but end up with:
= (text as PainterOutput)
	int x = 55;
	rrrpipppnnp
=

@ So we begin by defining some colours. Note that there are two pseudo-colours
here as well (|UNQUOTED_COLOUR| and |NOT_A_COLOUR|), but the rest might all be
colurs in our painted output. These values are all legible ASCII characters
for convenient debugging, as in examples like |rrrpipppnnp| above.

@d DEFINITION_COLOUR 	'd'
@d FUNCTION_COLOUR		'f'
@d RESERVED_COLOUR		'r'
@d ELEMENT_COLOUR		'e'
@d IDENTIFIER_COLOUR	'i'
@d CHARACTER_COLOUR     'c'
@d CONSTANT_COLOUR		'n'
@d STRING_COLOUR		's'
@d PLAIN_COLOUR			'p'
@d EXTRACT_COLOUR		'x'
@d TYPE_COLOUR			't'
@d COMMENT_COLOUR		'!'
@d NEWLINE_COLOUR		'\n'
@d UNQUOTED_COLOUR      '_'

@d NOT_A_COLOUR         ' '

=
typedef struct custom_colour {
	struct text_stream *name;
	inchar32_t value;
	inchar32_t like_this;
	CLASS_DEFINITION
} custom_colour;

custom_colour *Painter::custom(text_stream *T, inchar32_t like, linked_list *L) {
	custom_colour *cc = CREATE(custom_colour);
	cc->name = Str::duplicate(T);
	cc->like_this = like;
	cc->value = 0;
	for (int i=0; i<Str::len(T); i++) {
		if (cc->value == 0) {
			inchar32_t candidate = Str::get_at(T, i);
			@<Try this candidate value@>;
		}
	}
	for (inchar32_t candidate = '1'; candidate <= '9'; candidate++)
		if (cc->value == 0)
			@<Try this candidate value@>;
	for (inchar32_t candidate = 'A'; candidate <= 'Z'; candidate++)
		if (cc->value == 0)
			@<Try this candidate value@>;
	if (cc->value == 0) cc->value = NOT_A_COLOUR;
	ADD_TO_LINKED_LIST(cc, custom_colour, L);
	return cc;
}

@<Try this candidate value@> =
	TEMPORARY_TEXT(ct)
	PUT_TO(ct, candidate);
	if (Str::includes(I"dfreicnspxh!_ ", ct) == FALSE) {
		int found = FALSE;
		custom_colour *ecc;
		LOOP_OVER_LINKED_LIST(ecc, custom_colour, L)
			if (candidate == ecc->value)
				found = TRUE;
		if (found == FALSE) cc->value = candidate;
	}
	DISCARD_TEXT(ct)

@

=
inchar32_t Painter::colour(linked_list *L, text_stream *T) {
	if (Str::eq(T, I"!string")) return STRING_COLOUR;
	if (Str::eq(T, I"!function")) return FUNCTION_COLOUR;
	if (Str::eq(T, I"!definition")) return DEFINITION_COLOUR;
	if (Str::eq(T, I"!reserved")) return RESERVED_COLOUR;
	if (Str::eq(T, I"!element")) return ELEMENT_COLOUR;
	if (Str::eq(T, I"!identifier")) return IDENTIFIER_COLOUR;
	if (Str::eq(T, I"!character")) return CHARACTER_COLOUR;
	if (Str::eq(T, I"!constant")) return CONSTANT_COLOUR;
	if (Str::eq(T, I"!plain")) return PLAIN_COLOUR;
	if (Str::eq(T, I"!extract")) return EXTRACT_COLOUR;
	if (Str::eq(T, I"!type")) return TYPE_COLOUR;
	if (Str::eq(T, I"!comment")) return COMMENT_COLOUR;
	custom_colour *ecc;
	LOOP_OVER_LINKED_LIST(ecc, custom_colour, L)
		if (Str::eq(T, ecc->name))
			return ecc->value;
	return NOT_A_COLOUR;
}

text_stream *Painter::colour_classname(programming_language *pl, inchar32_t col) {
	switch (col) {
		case DEFINITION_COLOUR: return I"definition-syntax";
		case FUNCTION_COLOUR:   return I"function-syntax";
		case RESERVED_COLOUR:   return I"reserved-syntax";
		case ELEMENT_COLOUR:    return I"element-syntax";
		case IDENTIFIER_COLOUR: return I"identifier-syntax";
		case TYPE_COLOUR:       return I"type-syntax";
		case CHARACTER_COLOUR:  return I"character-syntax";
		case CONSTANT_COLOUR:   return I"constant-syntax";
		case STRING_COLOUR:     return I"string-syntax";
		case PLAIN_COLOUR:      return I"plain-syntax";
		case EXTRACT_COLOUR:    return I"extract-syntax";
		case COMMENT_COLOUR:    return I"comment-syntax";
	}
	if (pl) {
		custom_colour *ecc;
		LOOP_OVER_LINKED_LIST(ecc, custom_colour, pl->custom_colours)
			if (col == ecc->value)
				return Painter::colour_classname(pl, ecc->like_this);
	}
	return NULL;
}

inchar32_t Painter::flatten(programming_language *pl, inchar32_t col) {
	switch (col) {
		case DEFINITION_COLOUR:
		case FUNCTION_COLOUR:
		case RESERVED_COLOUR:
		case ELEMENT_COLOUR:
		case IDENTIFIER_COLOUR:
		case CHARACTER_COLOUR:
		case CONSTANT_COLOUR:
		case STRING_COLOUR:
		case PLAIN_COLOUR:
		case EXTRACT_COLOUR:
		case COMMENT_COLOUR:
		case NEWLINE_COLOUR:
		case UNQUOTED_COLOUR:
		case TYPE_COLOUR:
		case NOT_A_COLOUR:
			return col;
	}
	custom_colour *ecc;
	LOOP_OVER_LINKED_LIST(ecc, custom_colour, pl->custom_colours)
		if (col == ecc->value)
			return Painter::flatten(pl, ecc->like_this);
	return NOT_A_COLOUR;
}

@ We get to that by using a language's rules on literals, and then executing
its colouring program.

=
int Painter::syntax_colour(programming_language *pl,
	hash_table *HT, text_stream *matter, text_stream *colouring, int with_comments,
	int flatten) {
	int from = 0, to = Str::len(matter) - 1;
	if (with_comments) {
		TEMPORARY_TEXT(part_before_comment)
		TEMPORARY_TEXT(part_within_comment)
		int found = FALSE;
		found = LanguageMethods::parse_comment(pl,
			matter, part_before_comment, part_within_comment);
		if (found) {
			int N = Str::len(matter);
			for (int i=Str::len(part_before_comment); i<N; i++)
				Str::put_at(colouring, i, COMMENT_COLOUR);
			from = 0; to = Str::len(part_before_comment);
		}
		DISCARD_TEXT(part_before_comment)
		DISCARD_TEXT(part_within_comment)
	}
	Painter::syntax_colour_inner(pl, HT, matter, colouring, from, to);
	if (flatten)
		for (int i=0; i<Str::len(colouring); i++)
			Str::put_at(colouring, i, Painter::flatten(pl, Str::get_at(colouring, i)));
	return FALSE;
}

void Painter::syntax_colour_inner(programming_language *pl,
	hash_table *HT, text_stream *matter, text_stream *colouring, int from, int to) {
	@<Spot identifiers, literal text and character constants@>;
	@<Spot literal numerical constants@>;
	@<Now run the colouring program@>;
}

@<Spot identifiers, literal text and character constants@> =
	inchar32_t squote = Str::get_first_char(pl->character_literal);
	inchar32_t squote_escape = Str::get_first_char(pl->character_literal_escape);
	inchar32_t dquote = Str::get_first_char(pl->string_literal);
	inchar32_t dquote_escape = Str::get_first_char(pl->string_literal_escape);
	for (int i=from; i <= to; i++) {
		inchar32_t skip = NOT_A_COLOUR;
		int one_off = -1, will_be = -1, glob = 1;
		switch (colouring_state) {
			case PLAIN_COLOUR: {
				inchar32_t c = Str::get_at(matter, i);
				if (c == dquote) {
					colouring_state = STRING_COLOUR;
					break;
				}
				if (c == squote) {
					colouring_state = CHARACTER_COLOUR;
					break;
				}
				if (Str::includes_at(matter, i, pl->multiline_comment_open)) {
					one_off = COMMENT_COLOUR; will_be = COMMENT_COLOUR;
					glob = Str::len(pl->multiline_comment_open);
				} else if (Str::includes_at(matter, i, pl->line_comment)) {
					one_off = COMMENT_COLOUR; will_be = PLAIN_COLOUR;
					glob = Str::len(matter) - i;
				} else if (Painter::identifier_at(pl, matter, colouring, i)) {
					one_off = IDENTIFIER_COLOUR;
				}
				break;
			}
			case COMMENT_COLOUR:
				if (Str::includes_at(matter, i, pl->multiline_comment_close)) {
					one_off = COMMENT_COLOUR; will_be = PLAIN_COLOUR;
					glob = Str::len(pl->multiline_comment_close);
				}
				break;
			case CHARACTER_COLOUR: {
				inchar32_t c = Str::get_at(matter, i);
				if (c == squote) will_be = PLAIN_COLOUR;
				if (c == squote_escape) skip = CHARACTER_COLOUR;
				break;
			}
			case STRING_COLOUR: {
				inchar32_t c = Str::get_at(matter, i);
				if (c == dquote) will_be = PLAIN_COLOUR;
				if (c == dquote_escape) skip = STRING_COLOUR;
				break;
			}
		}
		for (int j=0; j<glob; j++) {
			if (one_off >= 0) Str::put_at(colouring, i+j, (inchar32_t) one_off);
			else Str::put_at(colouring, i+j, (inchar32_t) colouring_state);
		}
		i += glob - 1;
		if (will_be >= 0) colouring_state = will_be;
		if ((skip != NOT_A_COLOUR) && (i<to)) {
			i++; Str::put_at(colouring, i, skip);
		}
	}

@<Spot literal numerical constants@> =
	int base = -1, dec_possible = TRUE, contiguous = 0, past_exp = FALSE, minus_allowed = TRUE;
	for (int i=from; i <= to; i++) {
		if ((Str::get_at(colouring, i) == PLAIN_COLOUR) ||
			(Str::get_at(colouring, i) == IDENTIFIER_COLOUR)) {
			inchar32_t c = Str::get_at(matter, i);
			if (Str::includes_at(matter, i, pl->binary_literal_prefix)) {
				base = 2;
				for (int j=0; j<Str::len(pl->binary_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				dec_possible = TRUE; contiguous++;
				i += Str::len(pl->binary_literal_prefix) - 1;
				continue;
			}
			if (Str::includes_at(matter, i, pl->octal_literal_prefix)) {
				base = 8;
				for (int j=0; j<Str::len(pl->octal_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				dec_possible = TRUE; contiguous++;
				i += Str::len(pl->octal_literal_prefix) - 1;
				continue;
			}
			if (Str::includes_at(matter, i, pl->hexadecimal_literal_prefix)) {
				base = 16;
				for (int j=0; j<Str::len(pl->hexadecimal_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				dec_possible = TRUE; contiguous++;
				i += Str::len(pl->hexadecimal_literal_prefix) - 1;
				continue;
			} 
			if ((Str::includes_at(matter, i, pl->negative_literal_prefix)) &&
				(((base == -1) && (dec_possible)) ||
				 ((past_exp) && (minus_allowed)))) {
				base = 10; contiguous++;
				for (int j=0; j<Str::len(pl->negative_literal_prefix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				i += Str::len(pl->negative_literal_prefix) - 1;
				minus_allowed = FALSE;
				continue;
			}
			if ((Str::includes_at(matter, i, pl->decimal_point_infix)) &&
				(base == 10) && (contiguous > 0)) {
				contiguous++;
				for (int j=0; j<Str::len(pl->decimal_point_infix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				i += Str::len(pl->decimal_point_infix) - 1;
				continue;
			}
			if ((Str::includes_at(matter, i, pl->exponent_infix)) &&
				(base == 10) && (contiguous > 0) && (past_exp == FALSE)) {
				contiguous++;
				for (int j=0; j<Str::len(pl->exponent_infix); j++)
					Str::put_at(colouring, i+j, (char) CONSTANT_COLOUR);
				i += Str::len(pl->exponent_infix) - 1;
				past_exp = TRUE; minus_allowed = TRUE;
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
				case 8: if ((Characters::isdigit(c)) &&
							(c != '8') && (c != '9')) pass = TRUE; break;
				case 10: if (Characters::isdigit(c)) pass = TRUE; break;
				case 16: if (Characters::isdigit(c)) pass = TRUE;
					inchar32_t d = Characters::tolower(c);
					if ((d == 'a') || (d == 'b') || (d == 'c') ||
						(d == 'd') || (d == 'e') || (d == 'f')) pass = TRUE;
					break;
			}
			if (pass) {
				Str::put_at(colouring, i, (char) CONSTANT_COLOUR);
				contiguous++;
			} else {
				if (Characters::is_whitespace(c)) dec_possible = TRUE;
				else dec_possible = FALSE;
				base = -1; contiguous = 0; past_exp = FALSE; minus_allowed = TRUE;
			}
		}
	}

@ For the moment, we always adopt the C rules on identifiers: they have to
begin with an underscore or letter, then continue with underscores or
alphanumeric characters, except that if the language allows it then they
can contain a |::| namespace divider.

=
int Painter::identifier_at(programming_language *pl,
	text_stream *matter, text_stream *colouring, int i) {
	inchar32_t c = Str::get_at(matter, i);
	if ((i > 0) && (Str::get_at(colouring, i-1) == IDENTIFIER_COLOUR)) {
		if ((c == '_') ||
			((c >= 'A') && (c <= 'Z')) ||
			((c >= 'a') && (c <= 'z')) ||
			((c >= '0') && (c <= '9'))) return TRUE;
		if ((c == ':') && (pl->supports_namespaces)) return TRUE;
	} else {
		inchar32_t d = 0;
		if (i > 0) d = Str::get_at(matter, i);
		if ((d >= '0') && (d <= '9')) return FALSE;
		if ((c == '_') ||
			((c >= 'A') && (c <= 'Z')) ||
			((c >= 'a') && (c <= 'z'))) return TRUE;
	}
	return FALSE;
}

@ With those preliminaries out of the way, the language's colouring program
takes over.

@<Now run the colouring program@> =
	if (pl->program)
		Painter::execute(HT, pl->program, matter, colouring, from, to, painter_count++);

@ The run-type for a block determines what the rules in it apply to: the
whole snippet of text, or each character on its own, or each run of characters
of a given sort. Note that we work width-first, as it were: we complete each
rule across the whole snippet before moving on to the next.

=
void Painter::execute(hash_table *HT, colouring_language_block *block, text_stream *matter,
	text_stream *colouring, int from, int to, int N) {
	if (block == NULL) internal_error("no block");
	TEMPORARY_TEXT(colouring_at_start)
	Str::copy(colouring_at_start, colouring);
	colouring_rule *rule;
	LOOP_OVER_LINKED_LIST(rule, colouring_rule, block->rules) {
		switch (block->run) {
			case WHOLE_LINE_CRULE_RUN:
				Painter::execute_rule(HT, rule, matter, colouring, from, to,
					(N == 0)?1:N);
				break;
			case CHARACTERS_CRULE_RUN:
				for (int i=from; i<=to; i++)
					Painter::execute_rule(HT, rule, matter, colouring, i, i, i-from+1);
				break;
			case CHARACTERS_IN_CRULE_RUN:
				for (int count=1, i=from; i<=to; i++)
					for (int j=0; j<Str::len(block->char_set); j++)
						if (Str::get_at(matter, i) == Str::get_at(block->char_set, j) ) {
							Painter::execute_rule(HT, rule, matter, colouring, i, i, count++);
							break;
						}
				break;
			case INSTANCES_CRULE_RUN: {
				int L = Str::len(block->run_instance) - 1;
				if (L >= 0)
					for (int count=1, i=from; i<=to - L; i++)
						if (Str::includes_at(matter, i, block->run_instance)) {
							Painter::execute_rule(HT, rule, matter, colouring, i, i+L, count++);
							i += L;
						}
				break;
			}
			case MATCHES_CRULE_RUN:
				for (int count=1, i=from; i<=to; i++) {
					int L = Languages::match_regexp_set_from(&(block->mr), matter, block->match_regexp_text, i);
					if (L > 0) {
						Painter::execute_rule(HT, rule, matter, colouring, i, i+L-1, count++);
						i += L-1;
					}
				}
				break;
			case BRACKETS_CRULE_RUN:
				for (int i=0; i<MAX_BRACKETED_SUBEXPRESSIONS; i++)
					if (block->mr.exp[i])
						Str::clear(block->mr.exp[i]);
				if (Languages::match_regexp_set(&(block->mr), matter, block->match_regexp_text))
					for (int count=1, i=0; i<MAX_BRACKETED_SUBEXPRESSIONS; i++)
						if (block->mr.exp_at[i] >= 0)
							Painter::execute_rule(HT, rule, matter, colouring,
								block->mr.exp_at[i],
								block->mr.exp_at[i] + Str::len(block->mr.exp[i])-1,
								count++);
				break;
			default: {
				int ident_from = -1, count = 1;
				for (int i=from; i<=to; i++) {
					int col = (int) Str::get_at(colouring_at_start, i);
					if ((col == block->run) ||
						((block->run == UNQUOTED_COLOUR) &&
							((col != STRING_COLOUR) && (col != CHARACTER_COLOUR)))) {
						if (ident_from == -1) ident_from = i;
					} else {
						if (ident_from >= 0)
							Painter::execute_rule(HT, rule, matter, colouring, ident_from, i-1, count++);
						ident_from = -1;
					}
				}
				if (ident_from >= 0)
					Painter::execute_rule(HT, rule, matter, colouring, ident_from, to, count++);
				break;
			}
		}
	}
	DISCARD_TEXT(colouring_at_start)
}

@ Rules have the form: if X, then Y.

=
void Painter::execute_rule(hash_table *HT, colouring_rule *rule, text_stream *matter,
	text_stream *colouring, int from, int to, int N) {
	if (Painter::satisfies(HT, rule, matter, colouring, from, to, N) == rule->sense)
		Painter::follow(HT, rule, matter, colouring, from, to);
}

@ Here we test the "if X":

@d UNSPACED_RULE_PREFIX 2 /* for |prefix P| */
@d SPACED_RULE_PREFIX 3 /* for |spaced prefix P| */
@d OPTIONALLY_SPACED_RULE_PREFIX 4 /* for |optionally spaced prefix P| */
@d UNSPACED_RULE_SUFFIX 5 /* for |suffix P| */
@d SPACED_RULE_SUFFIX 6 /* for |spaced suffix P| */
@d OPTIONALLY_SPACED_RULE_SUFFIX 7 /* for |optionally spaced suffix P| */

=
int Painter::satisfies(hash_table *HT, colouring_rule *rule, text_stream *matter,
	text_stream *colouring, int from, int to, int N) {
	if (rule->number > 0) {
		if (rule->number_of > 0) {
			if (rule->number != ((N-1)%(rule->number_of)) + 1) return FALSE;
		} else {
			if (rule->number != N) return FALSE;
		}
	} else if (Languages::nonempty_regexp_set(rule->match_regexp_text)) {
		TEMPORARY_TEXT(T)
		for (int j=from; j<=to; j++) PUT_TO(T, Str::get_at(matter, j));
		int rv = Languages::match_regexp_set(&(rule->mr), T, rule->match_regexp_text);
		DISCARD_TEXT(T)
		if (rv == FALSE) return FALSE;
	} else if (Str::len(rule->match_text) > 0) {
		if ((rule->match_prefix == UNSPACED_RULE_PREFIX) ||
			(rule->match_prefix == SPACED_RULE_PREFIX) ||
			(rule->match_prefix == OPTIONALLY_SPACED_RULE_PREFIX)) {
			int pos = from;
			if (rule->match_prefix != UNSPACED_RULE_PREFIX) {
				while ((pos > 0) && (Characters::is_whitespace(Str::get_at(rule->match_text, pos-1)))) pos--;
				if ((rule->match_prefix == SPACED_RULE_PREFIX) && (pos == from))
					return FALSE;
			}
			if (Str::includes_at(matter,
				pos-Str::len(rule->match_text), rule->match_text) == FALSE)
				return FALSE;
			rule->fix_position = pos-Str::len(rule->match_text);
		} else if ((rule->match_prefix == UNSPACED_RULE_SUFFIX) ||
			(rule->match_prefix == SPACED_RULE_SUFFIX) ||
			(rule->match_prefix == OPTIONALLY_SPACED_RULE_SUFFIX)) {
			int pos = to + 1;
			if (rule->match_prefix != UNSPACED_RULE_SUFFIX) {
				while ((pos < Str::len(rule->match_text)) && (Characters::is_whitespace(Str::get_at(rule->match_text, pos)))) pos++;
				if ((rule->match_prefix == SPACED_RULE_SUFFIX) && (pos == from))
					return FALSE;
			}
			if (Str::includes_at(matter, pos, rule->match_text) == FALSE)
				return FALSE;
			rule->fix_position = pos;
		} else {
			if (Str::len(rule->match_text) != to-from+1)
				return FALSE;
			for (int i=from; i<=to; i++)
				if (Str::get_at(matter, i) != Str::get_at(rule->match_text, i-from))
					return FALSE;
		}
	} else if (rule->match_keyword_of_colour != NOT_A_COLOUR) {
		TEMPORARY_TEXT(id)
		Str::substr(id, Str::at(matter, from), Str::at(matter, to+1));
		int rw = ReservedWords::is_reserved_word(HT, id, (int) rule->match_keyword_of_colour);
		DISCARD_TEXT(id)
		if (rw == FALSE) return FALSE;
	} else if (rule->match_colour != NOT_A_COLOUR) {
		for (int i=from; i<=to; i++)
			if (Str::get_at(colouring, i) != rule->match_colour)
				return FALSE;
	}
	return TRUE;
}

@ And here we carry out the "then Y":

=
void Painter::follow(hash_table *HT, colouring_rule *rule, text_stream *matter,
	text_stream *colouring, int from, int to) {
	if (rule->execute_block)
		Painter::execute(HT, rule->execute_block, matter, colouring, from, to, 0);
	else if (rule->debug) @<Print some debugging text@>
	else {
		if (rule->set_to_colour != NOT_A_COLOUR)
			for (int i=from; i<=to; i++)
				Str::put_at(colouring, i, rule->set_to_colour);
		if (rule->set_prefix_to_colour != NOT_A_COLOUR)
			for (int i=rule->fix_position; i<rule->fix_position+Str::len(rule->match_text); i++)
				Str::put_at(colouring, i, rule->set_prefix_to_colour);
	}
}

@<Print some debugging text@> =
	PRINT("[%d, %d] text: ", from, to);
	for (int i=from; i<=to; i++)
		PUT_TO(STDOUT, Str::get_at(matter, i));
	PRINT("\n[%d, %d] cols: ", from, to);
	for (int i=from; i<=to; i++)
		PUT_TO(STDOUT, Str::get_at(colouring, i));
	PRINT("\n");

@h Painting a file.

=
linked_list *Painter::lines(filename *F) {
	linked_list *L = NEW_LINKED_LIST(text_stream);
	TextFiles::read(F, FALSE, "unable to read file of textual extract", TRUE,
		&Painter::text_file_helper, NULL, L);
	int n = -1, c = 0;
	text_stream *T;
	LOOP_OVER_LINKED_LIST(T, text_stream, L) {
		c++;
		if (Str::is_whitespace(T) == FALSE)
			n = c;
	}
	if (n >= 0) {
		linked_list *R = NEW_LINKED_LIST(text_stream);
		c = 0;
		LOOP_OVER_LINKED_LIST(T, text_stream, L)
			if (++c <= n)
				ADD_TO_LINKED_LIST(T, text_stream, R);
		return R;
	}
	return L;
}

void Painter::text_file_helper(text_stream *text, text_file_position *tfp, void *state) {
	linked_list *L = (linked_list *) state;
	ADD_TO_LINKED_LIST(Str::duplicate(text), text_stream, L);
}

void Painter::colour_file(programming_language *pl, filename *F, text_stream *to, text_stream *coloured) {
	linked_list *L = Painter::lines(F);
	if (pl) Painter::reset_syntax_colouring(pl);
	int c = 1;
	text_stream *T;
	LOOP_OVER_LINKED_LIST(T, text_stream, L) {
		if (c++ > 1) { PUT_TO(to, '\n'); PUT_TO(coloured, NEWLINE_COLOUR); }
		Str::trim_white_space_at_end(T);
		TEMPORARY_TEXT(ST)
		TEMPORARY_TEXT(SC)
		LOOP_THROUGH_TEXT(pos, T)
			if (Str::get(pos) == '\t')
				WRITE_TO(ST, "    ");
			else
				PUT_TO(ST, Str::get(pos));
		if (pl) {
			Painter::syntax_colour(pl, (pl)?(&(pl->built_in_keywords)):NULL, ST, SC, TRUE, FALSE);
		} else {
			LOOP_THROUGH_TEXT(pos, ST)
				PUT_TO(SC, PLAIN_COLOUR);
		}
		WRITE_TO(to, "%S", ST);
		WRITE_TO(coloured, "%S", SC);
	}
	if (c > 0) { PUT_TO(to, '\n'); PUT_TO(coloured, NEWLINE_COLOUR); }
}

@ In the following, |q_mode| is 0 outside quotes, 1 inside a character literal,
and 2 inside a string literal; |c_mode| is 0 outside comments, 1 inside a line
comment, and 2 inside a multiline comment.

=
int Painter::parse_comment(programming_language *pl,
	text_stream *line, text_stream *part_before_comment, text_stream *part_within_comment) {
	int q_mode = 0, c_mode = 0, non_white_space = FALSE, c_position = -1, c_end = -1;
	for (int i=0; i<Str::len(line); i++) {
		inchar32_t c = Str::get_at(line, i);
		switch (c_mode) {
			case 0: @<Outside commentary@>; break;
			case 1: @<Inside a line comment@>; break;
			case 2: @<Inside a multiline comment@>; break;
		}
	}
	if (c_mode == 2) c_end = Str::len(line);
	if ((c_position >= 0) && (non_white_space == FALSE)) {
		Str::clear(part_before_comment);
		for (int i=0; i<c_position; i++)
			PUT_TO(part_before_comment, Str::get_at(line, i));
		Str::clear(part_within_comment);
		for (int i=c_position + 2; i<c_end; i++)
			PUT_TO(part_within_comment, Str::get_at(line, i));
		Str::trim_white_space_at_end(part_within_comment);
		return TRUE;
	}
	return FALSE;
}

@<Inside a multiline comment@> =
	if (Str::includes_at(line, i, pl->multiline_comment_close)) {
		c_mode = 0; c_end = i; i += Str::len(pl->multiline_comment_close) - 1;
	}

@<Inside a line comment@> =
	;

@<Outside commentary@> =
	switch (q_mode) {
		case 0: @<Outside quoted matter@>; break;
		case 1: @<Inside a literal character@>; break;
		case 2: @<Inside a literal string@>; break;
	}

@<Outside quoted matter@> =
	if (!(Characters::is_whitespace(c))) non_white_space = TRUE;
	if (c == Str::get_first_char(pl->string_literal)) q_mode = 2;
	else if (c == Str::get_first_char(pl->character_literal)) q_mode = 1;
	else if (Str::includes_at(line, i, pl->multiline_comment_open)) {
		c_mode = 2; c_position = i; non_white_space = FALSE;
		i += Str::len(pl->multiline_comment_open) - 1;
	} else if (Str::includes_at(line, i, pl->line_comment)) {
		c_mode = 1; c_position = i; c_end = Str::len(line); non_white_space = FALSE;
		i += Str::len(pl->line_comment) - 1;
	} else if (Str::includes_at(line, i, pl->whole_line_comment)) {
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

@<Inside a literal character@> =
	if (!(Characters::is_whitespace(c))) non_white_space = TRUE;
	if (c == Str::get_first_char(pl->character_literal_escape)) i += 1;
	if (c == Str::get_first_char(pl->character_literal)) q_mode = 0;
	q_mode = 0;

@<Inside a literal string@> =
	if (!(Characters::is_whitespace(c))) non_white_space = TRUE;
	if (c == Str::get_first_char(pl->string_literal_escape)) i += 1;
	if (c == Str::get_first_char(pl->string_literal)) q_mode = 0;
	q_mode = 0;
