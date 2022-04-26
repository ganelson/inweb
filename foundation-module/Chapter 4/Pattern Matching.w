[Regexp::] Pattern Matching.

To provide a limited regular-expression parser.

@h Character types.
We will define white space as spaces and tabs only, since the various kinds
of line terminator will always be stripped out before this is applied.

=
int Regexp::white_space(int c) {
	if ((c == ' ') || (c == '\t')) return TRUE;
	return FALSE;
}

@ The presence of |:| here is perhaps a bit surprising, since it's illegal in
C and has other meanings in other languages, but it's legal in C-for-Inform
identifiers.

=
int Regexp::identifier_char(int c) {
	if ((c == '_') || (c == ':') ||
		((c >= 'A') && (c <= 'Z')) ||
		((c >= 'a') && (c <= 'z')) ||
		((c >= '0') && (c <= '9'))) return TRUE;
	return FALSE;
}

@h Simple parsing.
The following finds the earliest minimal-length substring of a string,
delimited by two pairs of characters: for example, |<<| and |>>|. This could
easily be done as a regular expression using |Regexp::match|, but the routine
here is much quicker.

=
int Regexp::find_expansion(text_stream *text, wchar_t on1, wchar_t on2,
	wchar_t off1, wchar_t off2, int *len) {
	for (int i = 0; i < Str::len(text); i++)
		if ((Str::get_at(text, i) == on1) && (Str::get_at(text, i+1) == on2)) {
			for (int j=i+2; j < Str::len(text); j++)
				if ((Str::get_at(text, j) == off1) && (Str::get_at(text, j+1) == off2)) {
					*len = j+2-i;
					return i;
				}
		}
	return -1;
}

@ Still more simply:

=
int Regexp::find_open_brace(text_stream *text) {
	for (int i=0; i < Str::len(text); i++)
		if (Str::get_at(text, i) == '{')
			return i;
	return -1;
}

@ Note that we count the empty string as being white space. Again, this is
equivalent to |Regexp::match(p, " *")|, but much faster.

=
int Regexp::string_is_white_space(text_stream *text) {
	LOOP_THROUGH_TEXT(P, text)
		if (Regexp::white_space(Str::get(P)) == FALSE)
			return FALSE;
	return TRUE;
}

@h A Worse PCRE.
I originally wanted to call the function in this section |a_better_sscanf|, then
thought perhaps |a_worse_PCRE| would be more true. (PCRE is Philip Hazel's superb
C implementation of regular-expression parsing, but I didn't need its full strength,
and I didn't want to complicate the build process by linking to it.)

This is a very minimal regular expression parser, simply for convenience of parsing
short texts against particularly simple patterns. Here is an example of use:
= (text as code)
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L"fish (%d+) ([a-zA-Z_][a-zA-Z0-9_]*) *") {
	    PRINT("Fish number: %S\n", mr.exp[0]);
	    PRINT("Fish name: %S\n", mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
=
Note the |L| at the front of the regex itself: this is a wide string.

This tries to match the given |text| to see if it consists of the word fish,
then any amount of whitespace, then a string of digits which are copied into
|mr->exp[0]|, then whitespace again, and then an alphanumeric identifier to be
copied into |mr->exp[1]|, and finally optional whitespace. (If no match is
made, the contents of the found strings are undefined.)

Note that this differs from, for example, Perl's regular expression matcher
in several ways. The regular expression syntax is slightly different and in
general simpler. A match has to be made from start to end, so it's as if there
were an implicit |^| at the front and |$| at the back (in Perl terms). The
full match text is therefore always the entire text put in, so there's no
need to record this. In Perl, matching against |m/(.*) plus (.*)/| would
set three subexpressions: number 0 would be the whole text matched, number
1 would be the first bracketed part, number 2 the second. Here, though, the
corresponding regex would be written |L"(%c*) plus (%c*)"|, and the bracketed
terms would be subexpressions 0 and 1.

@d MAX_BRACKETED_SUBEXPRESSIONS 5 /* this many bracketed subexpressions can be extracted */

@ The internal state of the matcher is stored as follows:

=
typedef struct match_position {
	int tpos; /* position within text being matched */
	int ppos; /* position within pattern */
	int bc; /* count of bracketed subexpressions so far begun */
	int bl; /* bracket indentation level */
	int bracket_nesting[MAX_BRACKETED_SUBEXPRESSIONS];
	/* which subexpression numbers (0, 1, 2, 3) correspond to which nesting */
	int brackets_start[MAX_BRACKETED_SUBEXPRESSIONS], brackets_end[MAX_BRACKETED_SUBEXPRESSIONS];
	/* positions in text being matched, inclusive */
} match_position;

@  It may appear that match texts are limited to 64 characters here, but they
are not. They are simply a little faster to access if short.

@d MATCH_TEXT_INITIAL_ALLOCATION 64

=
typedef struct match_result {
	wchar_t match_text_storage[MATCH_TEXT_INITIAL_ALLOCATION];
	struct text_stream match_text_struct;
} match_result;
typedef struct match_results {
	int no_matched_texts;
	struct match_result exp_storage[MAX_BRACKETED_SUBEXPRESSIONS];
	struct text_stream *exp[MAX_BRACKETED_SUBEXPRESSIONS];
	int exp_at[MAX_BRACKETED_SUBEXPRESSIONS];
} match_results;

@ Match result objects are inherently ephemeral, and we can expect to be
creating them and throwing them away frequently. This must be done
explicitly. Note that the storage required is on the C stack (unless some
result strings grow very large), so that it's very quick to allocate and
deallocate.

=
match_results Regexp::create_mr(void) {
	match_results mr;
	mr.no_matched_texts = 0;
	for (int i=0; i<MAX_BRACKETED_SUBEXPRESSIONS; i++) {
		mr.exp[i] = NULL;
		mr.exp_at[i] = -1;
	}
	return mr;
}

void Regexp::dispose_of(match_results *mr) {
	if (mr) {
		for (int i=0; i<MAX_BRACKETED_SUBEXPRESSIONS; i++)
			if (mr->exp[i]) {
				STREAM_CLOSE(mr->exp[i]);
				mr->exp[i] = NULL;
			}
		mr->no_matched_texts = 0;
	}
}

@ So, then: the matcher itself.

=
int Regexp::match(match_results *mr, text_stream *text, wchar_t *pattern) {
	if (mr) Regexp::prepare(mr);
	int rv = (Regexp::match_r(mr, text, pattern, NULL, FALSE) >= 0)?TRUE:FALSE;
	if ((mr) && (rv == FALSE)) Regexp::dispose_of(mr);
	return rv;
}

int Regexp::match_from(match_results *mr, text_stream *text, wchar_t *pattern,
	int x, int allow_partial) {
	int match_to = x;
	if (x < Str::len(text)) {
		if (mr) Regexp::prepare(mr);
		match_position at;
		at.tpos = x; at.ppos = 0; at.bc = 0; at.bl = 0;
		match_to = Regexp::match_r(mr, text, pattern, &at, allow_partial);
		if (match_to == -1) {
			match_to = x;
			if (mr) Regexp::dispose_of(mr);
		}
	}
	return match_to - x;
}

void Regexp::prepare(match_results *mr) {
	if (mr) {
		mr->no_matched_texts = 0;
		for (int i=0; i<MAX_BRACKETED_SUBEXPRESSIONS; i++) {
			mr->exp_at[i] = -1;
			if (mr->exp[i]) STREAM_CLOSE(mr->exp[i]);
			mr->exp_storage[i].match_text_struct =
				Streams::new_buffer(
					MATCH_TEXT_INITIAL_ALLOCATION, mr->exp_storage[i].match_text_storage);
			mr->exp_storage[i].match_text_struct.stream_flags |= FOR_RE_STRF;
			mr->exp[i] = &(mr->exp_storage[i].match_text_struct);
		}
	}
}

@ =
int Regexp::match_r(match_results *mr, text_stream *text, wchar_t *pattern,
	match_position *scan_from, int allow_partial) {
	match_position at;
	if (scan_from) at = *scan_from;
	else { at.tpos = 0; at.ppos = 0; at.bc = 0; at.bl = 0; }
	while ((Str::get_at(text, at.tpos)) || (pattern[at.ppos])) {
		if ((allow_partial) && (pattern[at.ppos] == 0)) break;
		@<Parentheses in the match pattern set up substrings to extract@>;

		int chcl, /* what class of characters to match: a |*_CHARCLASS| value */
			range_from, range_to, /* for |LITERAL_CHARCLASS| only */
			reverse = FALSE; /* require a non-match rather than a match */
		@<Extract the character class to match from the pattern@>;

		int rep_from = 1, rep_to = 1; /* minimum and maximum number of repetitions */
		int greedy = TRUE; /* go for a maximal-length match if possible */
		@<Extract repetition markers from the pattern@>;

		int reps = 0;
		@<Count how many repetitions can be made here@>;
		if (reps < rep_from) return -1;

		/* we can now accept anything from |rep_from| to |reps| repetitions */
		if (rep_from == reps) { at.tpos += reps; continue; }
		@<Try all possible match lengths until we find a match@>;

		/* no match length worked, so no match */
		return -1;
	}
	@<Copy the bracketed texts found into the global strings@>;
	return at.tpos;
}

@<Parentheses in the match pattern set up substrings to extract@> =
	if (pattern[at.ppos] == '(') {
		if (at.bl < MAX_BRACKETED_SUBEXPRESSIONS) at.bracket_nesting[at.bl] = -1;
		if (at.bc < MAX_BRACKETED_SUBEXPRESSIONS) {
			at.bracket_nesting[at.bl] = at.bc;
			at.brackets_start[at.bc] = at.tpos; at.brackets_end[at.bc] = -1;
		}
		at.bl++; at.bc++; at.ppos++;
		continue;
	}
	if (pattern[at.ppos] == ')') {
		at.bl--;
		if ((at.bl >= 0) && (at.bl < MAX_BRACKETED_SUBEXPRESSIONS) && (at.bracket_nesting[at.bl] >= 0))
			at.brackets_end[at.bracket_nesting[at.bl]] = at.tpos-1;
		at.ppos++;
		continue;
	}

@<Extract the character class to match from the pattern@> =
	if (pattern[at.ppos] == 0) return -1;
	int len = 0;
	chcl = Regexp::get_cclass(pattern, at.ppos, &len, &range_from, &range_to, &reverse);
	if (at.ppos+len > Wide::len(pattern)) internal_error("Yikes");
	else at.ppos += len;

@ This is standard regular-expression notation, except that I haven't bothered
to implement numeric repetition counts, which we won't need:

@<Extract repetition markers from the pattern@> =
	if (chcl == WHITESPACE_CHARCLASS) {
		rep_from = 1; rep_to = Str::len(text)-at.tpos;
	}
	if (pattern[at.ppos] == '+') {
		rep_from = 1; rep_to = Str::len(text)-at.tpos; at.ppos++;
	} else if (pattern[at.ppos] == '*') {
		rep_from = 0; rep_to = Str::len(text)-at.tpos; at.ppos++;
	}
	if (pattern[at.ppos] == '?') { greedy = FALSE; at.ppos++; }

@<Count how many repetitions can be made here@> =
	for (reps = 0; ((Str::get_at(text, at.tpos+reps)) && (reps < rep_to)); reps++)
		if (Regexp::test_cclass(Str::get_at(text, at.tpos+reps), chcl,
			range_from, range_to, pattern, reverse) == FALSE)
			break;

@<Try all possible match lengths until we find a match@> =
	int from = rep_from, to = reps, dj = 1, from_tpos = at.tpos;
	if (greedy) { from = reps; to = rep_from; dj = -1; }
	for (int j = from; j != to+dj; j += dj) {
		at.tpos = from_tpos + j;
		int try = Regexp::match_r(mr, text, pattern, &at, allow_partial);
		if (try >= 0) return try;
	}

@<Copy the bracketed texts found into the global strings@> =
	if (mr) {
		for (int i=0; i<at.bc; i++) {
			Str::clear(mr->exp[i]);
			for (int j = at.brackets_start[i]; j <= at.brackets_end[i]; j++)
				PUT_TO(mr->exp[i], Str::get_at(text, j));
			mr->exp_at[i] = at.brackets_start[i];
		}
		mr->no_matched_texts = at.bc;
	}

@ So then: most characters in the pattern are taken literally (if the pattern
says |q|, the only match is with a lower-case letter "q"), except that:

(a) a space means "one or more characters of white space";
(b) |%d| means any decimal digit;
(c) |%c| means any character at all;
(d) |%C| means any character which isn't white space;
(e) |%i| means any character from the identifier class (see above);
(f) |%p| means any character which can be used in the name of a Preform
nonterminal, which is to say, an identifier character or a hyphen;
(g) |%P| means the same or else a colon;
(h) |%t| means a tab;
(i) |%q| means a double-quote.

|%| otherwise makes a literal escape; a space means any whitespace character;
square brackets enclose literal alternatives, and note as usual with grep
engines that |[]xyz]| is legal and makes a set of four possibilities, the
first of which is a literal close square; within a set, a hyphen makes a
character range; an initial |^| negates the result; and otherwise everything
is literal.

@d ANY_CHARCLASS 1
@d DIGIT_CHARCLASS 2
@d WHITESPACE_CHARCLASS 3
@d NONWHITESPACE_CHARCLASS 4
@d IDENTIFIER_CHARCLASS 5
@d PREFORM_CHARCLASS 6
@d PREFORMC_CHARCLASS 7
@d LITERAL_CHARCLASS 8
@d TAB_CHARCLASS 9
@d QUOTE_CHARCLASS 10

=
int Regexp::get_cclass(wchar_t *pattern, int ppos, int *len, int *from, int *to, int *reverse) {
	if (pattern[ppos] == '^') { ppos++; *reverse = TRUE; } else { *reverse = FALSE; }
	switch (pattern[ppos]) {
		case '%':
			ppos++;
			*len = 2;
			switch (pattern[ppos]) {
				case 'd': return DIGIT_CHARCLASS;
				case 'c': return ANY_CHARCLASS;
				case 'C': return NONWHITESPACE_CHARCLASS;
				case 'i': return IDENTIFIER_CHARCLASS;
				case 'p': return PREFORM_CHARCLASS;
				case 'P': return PREFORMC_CHARCLASS;
				case 'q': return QUOTE_CHARCLASS;
				case 't': return TAB_CHARCLASS;
			}
			*from = ppos; *to = ppos; return LITERAL_CHARCLASS;
		case '[':
			*from = ppos+1;
			ppos += 2;
			while ((pattern[ppos]) && (pattern[ppos] != ']')) ppos++;
			*to = ppos - 1; *len = ppos - *from + 2;
			return LITERAL_CHARCLASS;
		case ' ':
			*len = 1; return WHITESPACE_CHARCLASS;
	}
	*len = 1; *from = ppos; *to = ppos; return LITERAL_CHARCLASS;
}

@ =
int Regexp::test_cclass(int c, int chcl, int range_from, int range_to, wchar_t *drawn_from, int reverse) {
	int match = FALSE;
	switch (chcl) {
		case ANY_CHARCLASS: if (c) match = TRUE; break;
		case DIGIT_CHARCLASS: if (isdigit(c)) match = TRUE; break;
		case WHITESPACE_CHARCLASS: if (Characters::is_whitespace(c)) match = TRUE; break;
		case TAB_CHARCLASS: if (c == '\t') match = TRUE; break;
		case NONWHITESPACE_CHARCLASS: if (!(Characters::is_whitespace(c))) match = TRUE; break;
		case QUOTE_CHARCLASS: if (c != '\"') match = TRUE; break;
		case IDENTIFIER_CHARCLASS: if (Regexp::identifier_char(c)) match = TRUE; break;
		case PREFORM_CHARCLASS: if ((c == '-') || (c == '_') ||
			((c >= 'a') && (c <= 'z')) ||
			((c >= '0') && (c <= '9'))) match = TRUE; break;
		case PREFORMC_CHARCLASS: if ((c == '-') || (c == '_') || (c == ':') ||
			((c >= 'a') && (c <= 'z')) ||
			((c >= '0') && (c <= '9'))) match = TRUE; break;
		case LITERAL_CHARCLASS:
			if ((range_to > range_from) && (drawn_from[range_from] == '^')) {
				range_from++; reverse = reverse?FALSE:TRUE;
			}
			for (int j = range_from; j <= range_to; j++) {
				int c1 = drawn_from[j], c2 = c1;
				if ((j+1 < range_to) && (drawn_from[j+1] == '-')) { c2 = drawn_from[j+2]; j += 2; }
				if ((c >= c1) && (c <= c2)) {
					match = TRUE; break;
				}
			}
			break;
	}
	if (reverse) match = (match)?FALSE:TRUE;
	return match;
}

@h Replacement.
And this routine conveniently handles searching and replacing. This time we
can match at substrings of the |text| (i.e., we are not forced to match
from the start right to the end), and multiple replacements can be made.
For example,
= (text as code)
	Regexp::replace(text, L"[aeiou]", L"!", REP_REPEATING);
=
will turn the |text| "goose eggs" into "g!!s! !ggs".

@d REP_REPEATING 1
@d REP_ATSTART 2

=
int Regexp::replace(text_stream *text, wchar_t *pattern, wchar_t *replacement, int options) {
	TEMPORARY_TEXT(altered)
	match_results mr = Regexp::create_mr();
	int changes = 0;
	for (int i=0, L=Str::len(text); i<L; i++) {
		match_position mp; mp.tpos = i; mp.ppos = 0; mp.bc = 0; mp.bl = 0;
		Regexp::prepare(&mr);
		int try = Regexp::match_r(&mr, text, pattern, &mp, TRUE);
		if (try >= 0) {
			if (replacement)
				for (int j=0; replacement[j]; j++) {
					int c = replacement[j];
					if (c == '%') {
						j++;
						int ind = replacement[j] - '0';
						if ((ind >= 0) && (ind < MAX_BRACKETED_SUBEXPRESSIONS))
							WRITE_TO(altered, "%S", mr.exp[ind]);
						else
							PUT_TO(altered, replacement[j]);
					} else {
						PUT_TO(altered, replacement[j]);
					}
				}
			int left = L - try;
			changes++;
			Regexp::dispose_of(&mr);
			L = Str::len(text); i = L-left-1;
			if ((options & REP_REPEATING) == 0) { @<Add the rest@>; break; }
			continue;
		} else PUT_TO(altered, Str::get_at(text, i));
		if (options & REP_ATSTART) { @<Add the rest@>; break; }
	}
	Regexp::dispose_of(&mr);
	if (changes > 0) Str::copy(text, altered);
	DISCARD_TEXT(altered)
	return changes;
}

@<Add the rest@> =
	for (i++; i<L; i++)
		PUT_TO(altered, Str::get_at(text, i));
