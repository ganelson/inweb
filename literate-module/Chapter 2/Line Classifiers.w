[LineClassifiers::] Line Classifiers.

Simple matching grammars to decide what LP content is present in a given text.

@h Classifiers.
A line classifier is really just a list of rules:

=
typedef struct ls_classifier {
	struct linked_list *rules; /* of |ls_notation_rule| */
	CLASS_DEFINITION
} ls_classifier;

ls_classifier *LineClassifiers::new(void) {
	ls_classifier *lc = CREATE(ls_classifier);
	lc->rules = NEW_LINKED_LIST(ls_notation_rule);
	return lc;
}

void LineClassifiers::add_rule(ls_classifier *lc, ls_notation_rule *R) {
	ADD_TO_LINKED_LIST(R, ls_notation_rule, lc->rules);
}

@h Rules.
Each rule consists of three pieces: a condition, which has to hold for the match
to be allowed at all; a textual pattern which the line has to match; and then
the result if the rule should succeed.

=
typedef struct ls_notation_rule {
	struct ls_notation_rule_condition condition; /* provided this is met... */
	struct ls_notation_rule_pattern pattern;     /* and the line matches this... */
	struct ls_notation_rule_outcome outcome;     /* then we classify like so */
	CLASS_DEFINITION
} ls_notation_rule;

ls_notation_rule *LineClassifiers::new_rule(ls_notation_rule_condition condition,
	ls_notation_rule_pattern pattern, ls_notation_rule_outcome outcome) {
	ls_notation_rule *R = CREATE(ls_notation_rule);
	R->condition = condition;
	R->outcome = outcome;
	R->pattern = pattern;
	return R;
}

@h Parsing.
The following takes pattern text |pt| and tail text |tail|, and either adds
a valid rule to the classifier and returns |NULL|, or does nothing and returns
a non-empty error message as text.

=
text_stream *LineClassifiers::parse_rule(ls_classifier *lc, text_stream *pt, text_stream *tail) {
	match_results mr = Regexp::create_mr();
	text_stream *error = NULL;
	ls_notation_rule_condition condition = LineClassifiers::truth_condition();
	if (Regexp::match(&mr, tail, U"(%c+) if (%c+)")) {
		tail = mr.exp[0];
		condition = LineClassifiers::parse_condition(mr.exp[1], &error);
	}
	if (Str::len(error) == 0) {
		ls_notation_rule_outcome outcome = LineClassifiers::parse_outcome(tail, &error);
		if (Str::len(error) == 0) {
			ls_notation_rule_pattern pattern = LineClassifiers::parse_pattern(pt, Conventions::generic_set(), &error);
			if (Str::len(error) == 0) {
				ls_notation_rule *R = LineClassifiers::new_rule(condition, pattern, outcome);
				LineClassifiers::add_rule(lc, R);
			}
		}
	}
	Regexp::dispose_of(&mr);
	return error;
}

@ An annoying subtlety here is that the pattern part of a rule depends on the
conventions in play, and they might have changed since the classifier was first
created. So the following reparses all of the patterns in light of the conventions
currently in force. That shouldn't throw errors, because any errors should have
come up earlier; but, better safe than sorry.

It would be possible to rewrite the matching code so that there was no need for
this reparsing, but that would classify lines more slowly, and speed counts here.
The reparsing is done only once per weave or tangle, so it's costing us basically
nothing in overhead. What must be fast is the matching code applied to every line.

=
void LineClassifiers::reparse_patterns_with_new_conventions(ls_classifier *lc,
	struct linked_list *conventions) {
	ls_notation_rule *R;
	LOOP_OVER_LINKED_LIST(R, ls_notation_rule, lc->rules) {
		text_stream *error = NULL;
		R->pattern = LineClassifiers::parse_pattern(R->pattern.parsed_from, conventions, &error);
		if (Str::len(error) > 0)
			WebErrors::issue_at(error, NULL);
	}
}

@h Matching.
We find the first rule in the list which applies to the given text, and return
it; if none apply, we return |NULL|. What matches may depend on what has been
classified in previous lines, which forms the |context|.

If a match is made, then the content of any wildcards is written into the
supplied |wildcards| array.

@d TRACE_LCLASSIFIER FALSE

=
typedef struct ls_classifier_context {
	struct ls_class *previously; /* how the previous line was classified */
	int single_file;             /* is this in a single-file web? */
	int whitespace_nature;       /* of the current line: a |*_LINESHADE| value */
	struct ls_notation *ntn;     /* notation currently in use */
} ls_classifier_context;

ls_notation_rule *LineClassifiers::match(ls_classifier *lc, text_stream *full_text,
	ls_classifier_context *context, text_stream **wildcards) {
	ls_notation_rule *R;
	if (TRACE_LCLASSIFIER) WRITE_TO(STDERR, "Match %S (wsn %d, pwsn %d, psft %d)\n",
		full_text, context->whitespace_nature,
		context->previously->whitespace_nature, context->previously->follows_title);

	LOOP_OVER_LINKED_LIST(R, ls_notation_rule, lc->rules)
		if (LineClassifiers::condition_met(&(R->condition), context))
			if (LineClassifiers::match_pattern(&(R->pattern), full_text, wildcards)) {
				if (TRACE_LCLASSIFIER)
					WRITE_TO(STDERR, "Success with outcome %d\n", R->outcome.outcome_ID);
				return R;
			}

	return NULL;
}

@h Conditions.
The condition applied to a rule — for example, |if following title| — is
turned into one of these:

=
typedef struct ls_notation_rule_condition {
	int negated; /* if |TRUE|, means we must be not in the given context */
	int atomic_condition; /* one of the |*_LSNRCAC| values below */
} ls_notation_rule_condition;

ls_notation_rule_condition LineClassifiers::truth_condition(void) {
	ls_notation_rule_condition condition;
	condition.atomic_condition = ANY_LSNRCAC;
	condition.negated = FALSE;
	return condition;
}

@ The "atomic conditions" are as follows:

@e ANY_LSNRCAC from 0 /* represents "always true" */
@e FIRST_LINE_LSNRCAC
@e FIRST_LINE_SF_LSNRCAC
@e FOLLOWING_TITLE_LSNRCAC
@e DEFINITION_LSNRCAC
@e EXTRACT_LSNRCAC
@e HOLON_LSNRCAC
@e TEXTEXTRACT_LSNRCAC
@e INDENTED_LSNRCAC
@e PTAG_SUPPORTED_LSNRCAC

=
ls_notation_rule_condition LineClassifiers::parse_condition(text_stream *ct, text_stream **error) {
	ls_notation_rule_condition condition = LineClassifiers::truth_condition();
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, ct, U"not (%c+)")) {
		condition = LineClassifiers::parse_condition(mr.exp[0], error);
		condition.negated = (condition.negated)?FALSE:TRUE;
		return condition;
	} else {
		int AC = -1;
		if (Str::eq(ct, I"on first line"))                AC = FIRST_LINE_LSNRCAC;
		if (Str::eq(ct, I"on first line of only file"))   AC = FIRST_LINE_SF_LSNRCAC;
		if (Str::eq(ct, I"following title"))              AC = FOLLOWING_TITLE_LSNRCAC;
		if (Str::eq(ct, I"in definition context"))        AC = DEFINITION_LSNRCAC;
		if (Str::eq(ct, I"in extract context"))           AC = EXTRACT_LSNRCAC;
		if (Str::eq(ct, I"in textextract context"))       AC = TEXTEXTRACT_LSNRCAC;
		if (Str::eq(ct, I"in holon context"))             AC = HOLON_LSNRCAC;
		if (Str::eq(ct, I"in indented context"))          AC = INDENTED_LSNRCAC;
		if (Str::eq(ct, I"paragraph tags supported"))     AC = PTAG_SUPPORTED_LSNRCAC;
		if (condition.atomic_condition < 0) {
			*error = Str::new();
			WRITE_TO(*error, "unknown condition '%S'", ct);
			condition.atomic_condition = ANY_LSNRCAC;
		} else {
			condition.atomic_condition = AC;
		}
	}
	Regexp::dispose_of(&mr);
	return condition;
}

@ Whether conditions hold or not depends on the surrounding context:

=
int LineClassifiers::condition_met(ls_notation_rule_condition *condition, ls_classifier_context *context) {
	int top_flag = FALSE;
	if (context->previously->major == UNCLASSIFIED_MAJLC) top_flag = TRUE;
	int applies = FALSE;
	switch (condition->atomic_condition) {
		case FIRST_LINE_LSNRCAC:
			if (top_flag) applies = TRUE; break;
		case FIRST_LINE_SF_LSNRCAC:
			if ((context->single_file) && (top_flag)) applies = TRUE; break;
		case FOLLOWING_TITLE_LSNRCAC:
			if (context->previously->follows_title) applies = TRUE; break;
		case INDENTED_LSNRCAC:
			if ((context->whitespace_nature == WHITE_LINESHADE) &&
				(context->previously->whitespace_nature == BLACK_LINESHADE))
				applies = FALSE;
			else if ((context->whitespace_nature != BLACK_LINESHADE) &&
				(context->previously->whitespace_nature != BLACK_LINESHADE))
				applies = TRUE;
			break;
		case DEFINITION_LSNRCAC:
			if (LineClassification::definition_lines_can_follow(
				context->previously->major, context->previously->minor)) applies = TRUE;
			break;
		case EXTRACT_LSNRCAC:
			if (LineClassification::extract_lines_can_follow(
				context->previously->major, context->previously->minor)) applies = TRUE;
			break;
		case TEXTEXTRACT_LSNRCAC:
			if ((LineClassification::extract_lines_can_follow(
				context->previously->major, context->previously->minor)) &&
				(LineClassification::code_lines_can_follow(
				context->previously->major, context->previously->minor) == FALSE)) applies = TRUE;
			break;
		case HOLON_LSNRCAC:
			if (LineClassification::code_lines_can_follow(
				context->previously->major, context->previously->minor)) applies = TRUE;
			break;
		case PTAG_SUPPORTED_LSNRCAC:
			if (WebNotation::supports_paragraph_tags(context->ntn)) applies = TRUE;
		default:
			applies = TRUE;
			break;
	}
	if (condition->negated) applies = applies?FALSE:TRUE;
	return applies;
}

@h Patterns.
Now for the textual pattern. We have a very simple model: the line must,
once trailing whitespace is removed, match a sequence of tokens, each of
which is either fixed wording or a wildcard meaning "one or more characters".
The wildcards on a given line are numbered from 0, and each can only appear
once; but they need not occur in numerical order, and need not all be present.

@d MAX_LSSRTOKENS (2*NO_DEFINED_LSWILDCARD_VALUES+1)

=
typedef struct ls_notation_rule_pattern {
	int strip_indents;
	int no_tokens;
	struct ls_srtoken tokens[MAX_LSSRTOKENS];
	struct text_stream *parsed_from;
} ls_notation_rule_pattern;

ls_notation_rule_pattern LineClassifiers::new_pattern(void) {
	ls_notation_rule_pattern pattern;
	pattern.strip_indents = 0;
	pattern.no_tokens = 0;
	pattern.parsed_from = NULL;
	return pattern;
}

@ So here are the tokens:

=
typedef struct ls_srtoken {
	struct text_stream *fixed_content;
	int wildcard;
	int whitespace;
	int nonwhitespace;
	int digital;
} ls_srtoken;

ls_srtoken LineClassifiers::fixed_token(text_stream *text, int from, int to) {
	ls_srtoken tok;
	tok.fixed_content = Str::new();
	for (int j=from; j<=to; j++) PUT_TO(tok.fixed_content, Str::get_at(text, j));
	tok.wildcard = -1;
	tok.whitespace = FALSE;
	tok.nonwhitespace = FALSE;
	tok.digital = FALSE;
	return tok;
}

ls_srtoken LineClassifiers::wildcard_token(int n) {
	if ((n < MATERIAL_LSWILDCARD) || (n >= NO_DEFINED_LSWILDCARD_VALUES))
		internal_error("wildcard out of range");
	ls_srtoken tok;
	tok.fixed_content = NULL;
	tok.wildcard = n;
	tok.whitespace = FALSE;
	tok.nonwhitespace = FALSE;
	tok.digital = FALSE;
	return tok;
}

@ The following parses source code such as |@enum MATERIAL(NONWHITESPACE) from SECOND|
into a |ls_notation_rule_pattern|.

@e MATERIAL_LSWILDCARD from 0
@e SECOND_LSWILDCARD
@e THIRD_LSWILDCARD
@e FOURTH_LSWILDCARD
@e OPTIONS_LSWILDCARD
@e RESIDUE_LSWILDCARD

=
ls_notation_rule_pattern LineClassifiers::parse_pattern(text_stream *pt,
	linked_list *conventions, text_stream **error) {
	ls_notation_rule_pattern pattern = LineClassifiers::new_pattern();
	pattern.parsed_from = Str::duplicate(pt);
	TEMPORARY_TEXT(text)
	for (int i=0; i<Str::len(pt); i++) {
		if (Str::includes_at(pt, i, I"<INDENT>")) {
			if (Str::len(text) > 0) {
				*error = I"<INDENT> can be used only at the start of a pattern";
				return pattern;
			}
			pattern.strip_indents++;
			i += Str::len(I"<INDENT>") - 1; continue;
		}
		if (Str::includes_at(pt, i, I"<OPENHOLON>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual_from(conventions, HOLON_NAME_SYNTAX_LSCONVENTION));
			i += Str::len(I"<OPENHOLON>") - 1; continue;
		}
		if (Str::includes_at(pt, i, I"<CLOSEHOLON>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual2_from(conventions, HOLON_NAME_SYNTAX_LSCONVENTION));
			i += Str::len(I"<CLOSEHOLON>") - 1; continue;
		}
		if (Str::includes_at(pt, i, I"<OPENFILEHOLON>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual_from(conventions, FILE_HOLON_NAME_SYNTAX_LSCONVENTION));
			i += Str::len(I"<OPENFILEHOLON>") - 1; continue;
		}
		if (Str::includes_at(pt, i, I"<CLOSEFILEHOLON>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual2_from(conventions, FILE_HOLON_NAME_SYNTAX_LSCONVENTION));
			i += Str::len(I"<CLOSEFILEHOLON>") - 1; continue;
		}
		if (Str::includes_at(pt, i, I"<OPENTAG>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual_from(conventions, TAGS_SYNTAX_LSCONVENTION));
			i += Str::len(I"<OPENTAG>") - 1; continue;
		}
		if (Str::includes_at(pt, i, I"<CLOSETAG>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual2_from(conventions, TAGS_SYNTAX_LSCONVENTION));
			i += Str::len(I"<CLOSETAG>") - 1; continue;
		}
		PUT_TO(text, Str::get_at(pt, i));
	}
	int from = 0;
	for (int i=0; i<Str::len(text); i++) {
		if (pattern.no_tokens + 2 > MAX_LSSRTOKENS) break;
		if (Str::includes_at(text, i, I"MATERIAL")) {
			if (from < i) pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, i-1);
			pattern.tokens[pattern.no_tokens++] = LineClassifiers::wildcard_token(MATERIAL_LSWILDCARD);
			from = i + Str::len(I"MATERIAL");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"SECOND")) {
			if (from < i) pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, i-1);
			pattern.tokens[pattern.no_tokens++] = LineClassifiers::wildcard_token(SECOND_LSWILDCARD);
			from = i + Str::len(I"SECOND");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"THIRD")) {
			if (from < i) pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, i-1);
			pattern.tokens[pattern.no_tokens++] = LineClassifiers::wildcard_token(THIRD_LSWILDCARD);
			from = i + Str::len(I"THIRD");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"FOURTH")) {
			if (from < i) pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, i-1);
			pattern.tokens[pattern.no_tokens++] = LineClassifiers::wildcard_token(FOURTH_LSWILDCARD);
			from = i + Str::len(I"FOURTH");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"OPTIONS")) {
			if (from < i) pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, i-1);
			pattern.tokens[pattern.no_tokens++] = LineClassifiers::wildcard_token(OPTIONS_LSWILDCARD);
			from = i + Str::len(I"OPTIONS");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"RESIDUE")) {
			if (from < i) pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, i-1);
			pattern.tokens[pattern.no_tokens++] = LineClassifiers::wildcard_token(RESIDUE_LSWILDCARD);
			from = i + Str::len(I"RESIDUE");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"(WHITESPACE)")) {
			if ((pattern.no_tokens == 0) || (pattern.tokens[pattern.no_tokens-1].wildcard < 0) || (i != from)) {
				*error = I"(WHITESPACE) can be used only immediately after a wildcard";
				return pattern;
			}
			pattern.tokens[pattern.no_tokens-1].whitespace = TRUE;
			from = i + Str::len(I"(WHITESPACE)");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"(NONWHITESPACE)")) {
			if ((pattern.no_tokens == 0) || (pattern.tokens[pattern.no_tokens-1].wildcard < 0) || (i != from)) {
				*error = I"(NONWHITESPACE) can be used only immediately after a wildcard";
				return pattern;
			}
			pattern.tokens[pattern.no_tokens-1].nonwhitespace = TRUE;
			from = i + Str::len(I"(NONWHITESPACE)");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"(DIGITS)")) {
			if ((pattern.no_tokens == 0) || (pattern.tokens[pattern.no_tokens-1].wildcard < 0) || (i != from)) {
				*error = I"(DIGITS) can be used only immediately after a wildcard";
				return pattern;
			}
			pattern.tokens[pattern.no_tokens-1].digital = TRUE;
			from = i + Str::len(I"(DIGITS)");
			i = from - 1; continue;
		}
	}
	if ((from < Str::len(text)) && (pattern.no_tokens < MAX_LSSRTOKENS))
		pattern.tokens[pattern.no_tokens++] = LineClassifiers::fixed_token(text, from, Str::len(text)-1);
	int usages[NO_DEFINED_LSWILDCARD_VALUES];
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++) usages[i] = 0;
	for (int i=0; i<pattern.no_tokens; i++)
		if (pattern.tokens[i].wildcard >= 0) {
			usages[pattern.tokens[i].wildcard]++;
			if ((i < pattern.no_tokens - 1) && (pattern.tokens[i+1].wildcard >= 0)) {
				pattern.no_tokens = 1;
				*error = I"two consecutive wildcards in pattern";
				return pattern;
			}
		}
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++)
		if (usages[i] > 1) {
			pattern.no_tokens = 1;
			*error = I"wildcards can be used only once each in a pattern";
			return pattern;
		}
	DISCARD_TEXT(text)
	return pattern;
}

@ So now we match text against a given pattern:

=
int LineClassifiers::match_pattern(ls_notation_rule_pattern *pattern, text_stream *full_text,
	text_stream **wildcards) {
	TEMPORARY_TEXT(text)
	@<Reduce the line indentation to allow for <INDENT> markers@>;
	@<Try to find a match against the text@>;
	DISCARD_TEXT(text)
	return FALSE;
}

@ Each |<INDENT>| marker at the start of the pattern represents one tab's worth
of white space to strip from the start of the line being matched. This does that:

@<Reduce the line indentation to allow for <INDENT> markers@> =
	int wsc = 0, on = (pattern->strip_indents == 0)?TRUE:FALSE;
	for (int i=0; i<Str::len(full_text); i++) {
		inchar32_t c = Str::get_at(full_text, i);
		if (on) {
			PUT_TO(text, c);
		} else {
			if (c == ' ') wsc++;
			else if (c == '\t') wsc = (wsc/4+1)*4;
			if (wsc == 4*pattern->strip_indents) on = TRUE;
		}
	}
	if (on == FALSE) return FALSE; /* that is, no match: insufficient indentation */

@ And now we try to make a textual match. Note that we clear the wildcard
variables each time, since otherwise we could have results from a previous
partial but failed match lingering on into a successful one.

Note that an empty token list matches only a whitespace line, since the text
we are matching has already had its whitespace at each end trimmed, so that
a whitespace line leads to the empty text here.

@<Try to find a match against the text@> =
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++)
		if (wildcards[i]) Str::clear(wildcards[i]);
	int match_from = 0, match_to = pattern->no_tokens - 1;
	int p_from = 0, p_to = Str::len(text) - 1;
	while (match_from <= match_to) {
		if (TRACE_LCLASSIFIER) WRITE_TO(STDERR, "Match tokens %d to %d, chars %c to %c\n",
			match_from, match_to, Str::get_at(text, p_from), Str::get_at(text, p_to));
		@<If the leftmost token is fixed text, check that it matches@>;
		@<If the rightmost token is fixed text, check that it matches@>;
		@<If only one token is left, it must be a wildcard, so copy the remaining text into it@>;
		@<At this point, the leftmost tokens must be a wildcard followed by fixed text, so look ahead@>;
	}
	if ((match_from > match_to) && (p_from > p_to)) return TRUE;
	if (TRACE_LCLASSIFIER) WRITE_TO(STDERR, "Failure\n");

@<If the leftmost token is fixed text, check that it matches@> =
	if (pattern->tokens[match_from].wildcard < 0) {
		text_stream *prefix = pattern->tokens[match_from].fixed_content;
		if (Str::includes_at(text, p_from, prefix) == FALSE) break;
		p_from += Str::len(prefix);
		match_from++;
		continue;
	}

@<If the rightmost token is fixed text, check that it matches@> =
	if (pattern->tokens[match_to].wildcard < 0) {
		text_stream *suffix = pattern->tokens[match_to].fixed_content;
		if (Str::includes_at(text, p_to - Str::len(suffix) + 1, suffix) == FALSE) break;
		p_to -= Str::len(suffix);
		match_to--;
		continue;
	}

@<If only one token is left, it must be a wildcard, so copy the remaining text into it@> =
	if (match_from == match_to) {
		text_stream *WT = wildcards[pattern->tokens[match_from].wildcard];
		Str::substr(WT, Str::at(text, p_from), Str::at(text, p_to+1));
		if ((pattern->tokens[match_from].nonwhitespace) &&
			((Str::includes_character(WT, ' ')) || (Str::includes_character(WT, '\t'))))
			break;
		if ((pattern->tokens[match_from].whitespace) && (Str::is_whitespace(WT) == FALSE))
			break;
		if (pattern->tokens[match_from].digital) {
			int not_digital = FALSE;
			for (int i=0; i<Str::len(WT); i++)
				if (Characters::isdigit(Str::get_at(WT, i)) == FALSE)
					not_digital = TRUE;
			if (not_digital) break;
		}
		p_from = p_to + 1;
		match_from++;
		continue;
	}

@ The leftmost token must be a wildcard because if it were fixed wording then
we would have checked it already; it cannot be the only token, because we've
just handled that case; so there is a next token, which cannot be a wildcard
because we cannot have two consecutive wildcards. And therefore...

Note that we use a non-greedy algorithm, i.e., we make the earliest match
possible, and with no backtracking to check other possibilities. This is a
deliberately simple parser, intended to work quickly on simple unambiguous
grammars.

@<At this point, the leftmost tokens must be a wildcard followed by fixed text, so look ahead@> =
	if (pattern->tokens[match_from+1].wildcard >= 0) internal_error("consecutive wildcard tokens");
	int lookahead = p_from+1, l_to = p_to - Str::len(pattern->tokens[match_from+1].fixed_content);
	for (; lookahead <= l_to; lookahead++)
		if (Str::includes_at(text, lookahead, pattern->tokens[match_from+1].fixed_content)) {
			text_stream *WT = wildcards[pattern->tokens[match_from].wildcard];
			Str::substr(WT, Str::at(text, p_from), Str::at(text, lookahead));
			p_from = lookahead + Str::len(pattern->tokens[match_from+1].fixed_content);
			match_from += 2;
			break;					
		} else if ((pattern->tokens[match_from].nonwhitespace) && (Characters::is_whitespace(Str::get_at(text, lookahead))))
			lookahead = l_to + 1;
	if (lookahead > l_to) break;

@h Outcomes and their options.
If successful, a rule produces an "outcome" such as |namedholon| or |code|,
together perhaps with options such as |earlyholonoption|.

=
typedef struct ls_notation_rule_outcome {
	int outcome_ID;            /* one of the |*_LSNROID| values below */
	int options_applied;       /* a bitmap of |*_LSNROBIT| values below */
	int new_paragraph;         /* does this line implicitly begin a new para? */
	struct text_stream *error; /* on a match, in fact throw this error */
} ls_notation_rule_outcome;

ls_notation_rule_outcome LineClassifiers::new_outcome(void) {
	ls_notation_rule_outcome outcome;
	outcome.outcome_ID = NO_LSNROID;
	outcome.options_applied = 0;
	outcome.new_paragraph = FALSE;
	outcome.error = NULL;
	return outcome;
}

ls_notation_rule_outcome LineClassifiers::parse_outcome(text_stream *ot, text_stream **error) {
	ls_notation_rule_outcome outcome = LineClassifiers::new_outcome();
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, ot, U"error \"(%c+)\"")) {
		outcome.error = Str::duplicate(mr.exp[0]);
		outcome.outcome_ID = COMMENTARY_LSNROID;
	} else {
		if (Regexp::match(&mr, ot, U"(%c+) in new paragraph")) {
			ot = Str::duplicate(mr.exp[0]);
			outcome.new_paragraph = TRUE;
		}
		while (Regexp::match(&mr, ot, U"(%c+) with (%C+)")) {
			ot = Str::duplicate(mr.exp[0]);
			int opt = LineClassifiers::outcome_by_name(mr.exp[1]);
			if (opt == NO_LSNROID) {
				*error = Str::new();
				WRITE_TO(*error, "unknown option '%S'", mr.exp[1]);
			} else {
				int B = LineClassifiers::option_bit(opt);
				if (B == -1) {
					*error = Str::new();
					WRITE_TO(*error, "an outcome, not an option: '%S'", mr.exp[1]);
				} else {
					outcome.options_applied |= B;
				}
			}
		}
		outcome.outcome_ID = LineClassifiers::outcome_by_name(ot);
		if (outcome.outcome_ID == NO_LSNROID) {
			*error = Str::new();
			WRITE_TO(*error, "unknown outcome '%S'", ot);
			outcome.outcome_ID = COMMENTARY_LSNROID;
		}
	}
	Regexp::dispose_of(&mr);
	return outcome;
}

@ These outcome and option IDs share an enumeration; first, here are the outcomes.
Note that |NO_LSNROID| is never the outcome of any rule: it's a value
used to mean "nothing matched".

@e NO_LSNROID from 0

@e AUDIO_LSNROID
@e BEGINPARAGRAPH_LSNROID
@e CAROUSELEND_LSNROID
@e CAROUSELSLIDE_LSNROID
@e CODE_LSNROID
@e COMMENTARY_LSNROID
@e DEFINITION_LSNROID
@e DEFINITIONCONTINUED_LSNROID
@e DOWNLOAD_LSNROID
@e EMBEDDEDVIDEO_LSNROID
@e ENDEXTRACT_LSNROID
@e ENUMERATION_LSNROID
@e EXTRACT_LSNROID
@e FIGURE_LSNROID
@e FILEHOLON_LSNROID
@e FORMATIDENTIFIER_LSNROID
@e HTML_LSNROID
@e INCLUDEFILE_LSNROID
@e MAKEDEFINITIONSHERE_LSNROID
@e NAMEDHOLON_LSNROID
@e NAMELESSHOLON_LSNROID
@e PARAGRAPHTAG_LSNROID
@e PARAGRAPHTITLING_LSNROID
@e PURPOSE_LSNROID
@e QUOTATION_LSNROID
@e TEXTASCODEEXTRACT_LSNROID
@e TEXTEXTRACT_LSNROID
@e TEXTEXTRACTTO_LSNROID
@e TITLE_LSNROID
@e VIDEO_LSNROID

@ And here are the options which some of the above may be given:

@e HYPERLINKED_LSNROID
@e UNDISPLAYED_LSNROID

@e WEBWIDEHOLON_LSNROID
@e VERYEARLYHOLON_LSNROID
@e EARLYHOLON_LSNROID
@e LATEHOLON_LSNROID
@e VERYLATEHOLON_LSNROID

@e CONTINUATION_LSNROID

@e SUPERHEADING_LSNROID
@e LEVEL1_LSNROID
@e LEVEL2_LSNROID
@e LEVEL3_LSNROID
@e LEVEL4_LSNROID
@e LEVEL5_LSNROID

@e SILENT_LSNROID

@e WITHPURPOSE_LSNROID

@e CAPTIONABOVE_LSNROID
@e CAPTIONBELOW_LSNROID

@e DEFAULT_LSNROID

@ The following converts outcome/option names to their enumerated values:

=
int LineClassifiers::outcome_by_name(text_stream *outcome) {
	if (Str::eq(outcome, I"audio"))                return AUDIO_LSNROID;
	if (Str::eq(outcome, I"beginparagraph"))       return BEGINPARAGRAPH_LSNROID;
	if (Str::eq(outcome, I"carouselend"))          return CAROUSELEND_LSNROID;
	if (Str::eq(outcome, I"carouselslide"))        return CAROUSELSLIDE_LSNROID;
	if (Str::eq(outcome, I"code"))                 return CODE_LSNROID;
	if (Str::eq(outcome, I"commentary"))           return COMMENTARY_LSNROID;
	if (Str::eq(outcome, I"definition"))           return DEFINITION_LSNROID;
	if (Str::eq(outcome, I"definitioncontinued"))  return DEFINITIONCONTINUED_LSNROID;
	if (Str::eq(outcome, I"download"))             return DOWNLOAD_LSNROID;
	if (Str::eq(outcome, I"embeddedvideo"))        return EMBEDDEDVIDEO_LSNROID;
	if (Str::eq(outcome, I"endextract"))           return ENDEXTRACT_LSNROID;
	if (Str::eq(outcome, I"enumeration"))          return ENUMERATION_LSNROID;
	if (Str::eq(outcome, I"extract"))              return EXTRACT_LSNROID;
	if (Str::eq(outcome, I"figure"))               return FIGURE_LSNROID;
	if (Str::eq(outcome, I"fileholon"))   		   return FILEHOLON_LSNROID;
	if (Str::eq(outcome, I"formatidentifier"))     return FORMATIDENTIFIER_LSNROID;
	if (Str::eq(outcome, I"html"))                 return HTML_LSNROID;
	if (Str::eq(outcome, I"includefile"))          return INCLUDEFILE_LSNROID;
	if (Str::eq(outcome, I"makedefinitionshere"))  return MAKEDEFINITIONSHERE_LSNROID;
	if (Str::eq(outcome, I"namedholon"))    	   return NAMEDHOLON_LSNROID;
	if (Str::eq(outcome, I"namelessholon"))        return NAMELESSHOLON_LSNROID;
	if (Str::eq(outcome, I"paragraphtag"))         return PARAGRAPHTAG_LSNROID;
	if (Str::eq(outcome, I"paragraphtitling"))     return PARAGRAPHTITLING_LSNROID;
	if (Str::eq(outcome, I"purpose"))              return PURPOSE_LSNROID;
	if (Str::eq(outcome, I"quotation"))            return QUOTATION_LSNROID;
	if (Str::eq(outcome, I"textascodeextract"))    return TEXTASCODEEXTRACT_LSNROID;
	if (Str::eq(outcome, I"textextract"))          return TEXTEXTRACT_LSNROID;
	if (Str::eq(outcome, I"textextractto"))        return TEXTEXTRACTTO_LSNROID;
	if (Str::eq(outcome, I"title"))                return TITLE_LSNROID;
	if (Str::eq(outcome, I"video"))                return VIDEO_LSNROID;
	
	if (Str::eq(outcome, I"hyperlinkedoption"))    return HYPERLINKED_LSNROID;
	if (Str::eq(outcome, I"undisplayedoption"))    return UNDISPLAYED_LSNROID;

	if (Str::eq(outcome, I"webwideholonoption"))   return WEBWIDEHOLON_LSNROID;
	if (Str::eq(outcome, I"veryearlyholonoption")) return VERYEARLYHOLON_LSNROID;
	if (Str::eq(outcome, I"earlyholonoption"))     return EARLYHOLON_LSNROID;
	if (Str::eq(outcome, I"lateholonoption"))      return LATEHOLON_LSNROID;
	if (Str::eq(outcome, I"verylateholonoption"))  return VERYLATEHOLON_LSNROID;

	if (Str::eq(outcome, I"continuationoption"))   return CONTINUATION_LSNROID;

	if (Str::eq(outcome, I"superheadingoption"))   return SUPERHEADING_LSNROID;
	if (Str::eq(outcome, I"subheading1option"))    return LEVEL1_LSNROID;
	if (Str::eq(outcome, I"subheading2option"))    return LEVEL2_LSNROID;
	if (Str::eq(outcome, I"subheading3option"))    return LEVEL3_LSNROID;
	if (Str::eq(outcome, I"subheading4option"))    return LEVEL4_LSNROID;
	if (Str::eq(outcome, I"subheading5option"))    return LEVEL5_LSNROID;

	if (Str::eq(outcome, I"silentoption"))         return SILENT_LSNROID;

	if (Str::eq(outcome, I"withpurposeoption"))    return WITHPURPOSE_LSNROID;

	if (Str::eq(outcome, I"captionaboveoption"))   return CAPTIONABOVE_LSNROID;
	if (Str::eq(outcome, I"captionbelowoption"))   return CAPTIONBELOW_LSNROID;

	if (Str::eq(outcome, I"defaultoption"))        return DEFAULT_LSNROID;

	return NO_LSNROID;
}

@ The following bits are high enough up that a valid options bitmap can never
equal a valid outcome ID, but at present we make no use of this fact.

@d HYPERLINKED_LSNROBIT     0x000100
@d UNDISPLAYED_LSNROBIT     0x000200

@d WEBWIDEHOLON_LSNROBIT    0x000400
@d VERYEARLYHOLON_LSNROBIT  0x000800
@d EARLYHOLON_LSNROBIT      0x001000
@d LATEHOLON_LSNROBIT       0x002000
@d VERYLATEHOLON_LSNROBIT   0x004000

@d CONTINUATION_LSNROBIT    0x008000

@d SUPERHEADING_LSNROBIT    0x010000
@d LEVEL1_LSNROBIT          0x020000
@d LEVEL2_LSNROBIT          0x040000
@d LEVEL3_LSNROBIT          0x080000
@d LEVEL4_LSNROBIT          0x100000
@d LEVEL5_LSNROBIT          0x200000

@d SILENT_LSNROBIT          0x400000

@d WITHPURPOSE_LSNROBIT     0x800000

@d WITHPURPOSE_LSNROBIT     0x800000

@d CAPTIONABOVE_LSNROBIT   0x1000000
@d CAPTIONBELOW_LSNROBIT   0x2000000

@d DEFAULT_LSNROBIT        0x4000000

=
int LineClassifiers::option_bit(int O) {
	switch (O) {
		case HYPERLINKED_LSNROID:    return HYPERLINKED_LSNROBIT;
		case UNDISPLAYED_LSNROID:    return UNDISPLAYED_LSNROBIT;
	
		case WEBWIDEHOLON_LSNROID:   return WEBWIDEHOLON_LSNROBIT;
		case VERYEARLYHOLON_LSNROID: return VERYEARLYHOLON_LSNROBIT;
		case EARLYHOLON_LSNROID:     return EARLYHOLON_LSNROBIT;
		case LATEHOLON_LSNROID:      return LATEHOLON_LSNROBIT;
		case VERYLATEHOLON_LSNROID:  return VERYLATEHOLON_LSNROBIT;
	
		case CONTINUATION_LSNROID:   return CONTINUATION_LSNROBIT;
	
		case SUPERHEADING_LSNROID:   return SUPERHEADING_LSNROBIT;
		case LEVEL1_LSNROID:         return LEVEL1_LSNROBIT;
		case LEVEL2_LSNROID:         return LEVEL2_LSNROBIT;
		case LEVEL3_LSNROID:         return LEVEL3_LSNROBIT;
		case LEVEL4_LSNROID:         return LEVEL4_LSNROBIT;
		case LEVEL5_LSNROID:         return LEVEL5_LSNROBIT;

		case SILENT_LSNROID:         return SILENT_LSNROBIT;

		case WITHPURPOSE_LSNROID:    return WITHPURPOSE_LSNROBIT;
		
		case CAPTIONABOVE_LSNROID:   return CAPTIONABOVE_LSNROBIT;
		case CAPTIONBELOW_LSNROID:   return CAPTIONBELOW_LSNROBIT;
		
		case DEFAULT_LSNROID:        return DEFAULT_LSNROBIT;
	}
	return -1;
}
