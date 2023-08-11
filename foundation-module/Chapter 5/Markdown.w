[Markdown::] Markdown.

To parse a simplified form of the Markdown markup notation, and render the
result in HTML.

@ The following is a simple approach which implements only code samples in
backticks and emphasis, but it follows CommonMark rules and correctly handles
its examples. I am indebted to //CM v0.30 -> https://spec.commonmark.org/0.30//.

@h Tree. We will parse a paragraph of MD content into a tree made of this fairly
lightweight node:

@e PARAGRAPH_MIT from 1
@e MATERIAL_MIT
@e PLAIN_MIT
@e EMPHASIS_MIT
@e STRONG_MIT
@e CODE_MIT

=
typedef struct markdown_item {
	int type; /* one of the |*_MIT| types above */
	struct text_stream *sliced_from;
	int from;
	int to;
	struct markdown_item *next;
	struct markdown_item *down;
	struct markdown_item *copied_from;
	int cycle_count; /* used only for tracing the tree when debugging */
	int id; /* used only for tracing the tree when debugging */
	CLASS_DEFINITION
} markdown_item;

int md_ids = 1;
markdown_item *Markdown::new_item(int type) {
	markdown_item *md = CREATE(markdown_item);
	md->type = type;
	md->sliced_from = NULL; md->from = 0; md->to = -1;
	md->next = NULL; md->down = NULL;
	md->cycle_count = 0;
	md->id = md_ids++;
	md->copied_from = NULL;
	return md;
}

@ A "slice" contains a snipped of text, where by convention the portion is
from character positions |from| to |to| inclusive. If |to| is less than |from|,
it represents the empty snippet.

=
markdown_item *Markdown::new_slice(int type, text_stream *text, int from, int to) {
	markdown_item *md = Markdown::new_item(type);
	md->sliced_from = text;
	md->from = from;
	md->to = to;
	return md;
}

@ A deep copy of the tree handing from node |md|:

=
markdown_item *Markdown::deep_copy(markdown_item *md) {
	markdown_item *copied = Markdown::new_item(md->type);
	if (Str::len(md->sliced_from) > 0) {
		copied->sliced_from = Str::duplicate(md->sliced_from);
	}
	copied->from = md->from;
	copied->to = md->to;
	copied->copied_from = md;
	for (markdown_item *c = md->down; c; c = c->next)
		Markdown::add_to(Markdown::deep_copy(c), copied);
	return copied;
}

@ Enough of creation. The following makes |md| the latest child of |owner|:

=
void Markdown::add_to(markdown_item *md, markdown_item *owner) {
	md->next = NULL;
	if (owner->down == NULL) { owner->down = md; return; }
	for (markdown_item *ch = owner->down; ch; ch = ch->next)
		if (ch->next == NULL) { ch->next = md; return; }
}

@h Characters and escapes.
Properly this should include also non-ASCII Unicode characters of category Zs.

=
int Markdown::is_Unicode_whitespace(wchar_t c) {
	if (c == 0x0009) return TRUE;
	if (c == 0x000A) return TRUE;
	if (c == 0x000C) return TRUE;
	if (c == 0x000D) return TRUE;
	if (c == 0x0020) return TRUE;
	return FALSE;
}

@ Properly this should include also non-ASCII Unicode characters of category
Pc, Pd, Pe, Pf, Pi, Po, or Ps.

=
int Markdown::is_Unicode_punctuation(wchar_t c) {
	if ((c >= 0x0021) && (c <= 0x002F)) return TRUE;
	if ((c >= 0x003A) && (c <= 0x0040)) return TRUE;
	if ((c >= 0x005B) && (c <= 0x0060)) return TRUE;
	if ((c >= 0x007B) && (c <= 0x007E)) return TRUE;
	return FALSE;
}

@ This is a convenient adaptation of |Str::get_at| which reads from the slice
inside a markdown node:

=
wchar_t Markdown::get_at(markdown_item *md, int at) {
	if (md == NULL) return 0;
	if (Str::len(md->sliced_from) == 0) return 0;
//	if ((at < md->from) || (at > md->to)) return 0;
	return Str::get_at(md->sliced_from, at);
}

@ Markdown uses backslash as an escape character, with double-backslash meaning
a literal backslash. It follows that if a character is preceded by an odd number
of backslashes, it must be escaped; if an even (including zero) it is unescaped.

This function returns a harmless letter for an escaped active character, so
that it can be used to test for unescaped active characters.

=
wchar_t Markdown::get_unescaped(markdown_item *md, int at) {
	wchar_t c = Markdown::get_at(md, at);
	int preceding_backslashes = 0;
	while (Markdown::get_at(md, at - 1 - preceding_backslashes) == '\\')
		preceding_backslashes++;
	if (preceding_backslashes % 2 == 1) return 'a';
	return c;
}

@ An "unescaped run" is a sequence of one or more instances of |of|, which
must be non-zero, which are not escaped with a backslash.

=
int Markdown::unescaped_run(markdown_item *md, int at, wchar_t of) {
	int count = 0;
	while (Markdown::get_unescaped(md, at + count) == of) count++;
	if (Markdown::get_unescaped(md, at - 1) == of) count = 0;
	return count;
}

@h Width.
This function recursively calculates the number of characters of actual text
represented by a subtree.

=
int Markdown::width(markdown_item *md) {
	if (md) {
		int width = 0;
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				wchar_t c = Markdown::get_at(md, i);
				if (c == '\\') i++;
				width++;
			}
		}
		if (md->type == CODE_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				width++;
			}
		}
		for (markdown_item *c = md->down; c; c = c->next)
			width += Markdown::width(c);
		return width;
	}
	return 0;
}

@h Debugging Markdown trees.
This rather defensively-written code is to print a tree which may be ill-founded
or not, in fact, be a tree at all. That should never happen, but if things which
should never happen never happened, we wouldn't need to debug.

=
int md_db_cycle_count = 1;

void Markdown::render_debug(OUTPUT_STREAM, markdown_item *md) {
	md_db_cycle_count++;
	Markdown::render_debug_r(OUT, md);
}

void Markdown::render_debug_r(OUTPUT_STREAM, markdown_item *md) {
	if (md) {
		WRITE("M%d ", md->id);
		if (md->cycle_count == md_db_cycle_count) {
			WRITE("AGAIN!\n");
			return;
		}
		md->cycle_count = md_db_cycle_count;
		switch (md->type) {
			case PARAGRAPH_MIT: WRITE("PARAGRAPH"); break;
			case MATERIAL_MIT:  WRITE("MATERIAL");  break;
			case PLAIN_MIT:     WRITE("PLAIN");     @<Debug text@>; break;
			case EMPHASIS_MIT:  WRITE("EMPHASIS");  break;
			case STRONG_MIT:    WRITE("STRONG");    break;
			case CODE_MIT:      WRITE("CODE");      @<Debug text@>; break;
		}
		WRITE("\n");
		INDENT;
		for (markdown_item *c = md->down; c; c = c->next)
			Markdown::render_debug_r(OUT, c);
		OUTDENT;
	}
}

@<Debug text@> =
	WRITE("(%d, %d) from (%d, %d) = '", md->from, md->to, 0, Str::len(md->sliced_from) -1);
	for (int i = md->from; i <= md->to; i++) PUT(Str::get_at(md->sliced_from, i));
	WRITE("'");

@h Parsing.
The user should call |Markdown::parse(text)| on the body of a paragraph of
running text which may have Markdown notation in it, and obtains a tree.
No errors are ever issued: a unique feature of Markdown is that all inputs
are always legal.

=
int tracing_Markdown_parser = FALSE;
void Markdown::set_tracing(int state) {
	tracing_Markdown_parser = state;
}

markdown_item *Markdown::parse_paragraph(text_stream *text) {
	markdown_item *passage = Markdown::new_item(PARAGRAPH_MIT);
	passage->down = Markdown::parse(text);
	return passage;
}

markdown_item *Markdown::parse(text_stream *text) {
	markdown_item *passage = Markdown::new_item(MATERIAL_MIT);
	Markdown::parse_inline_matter(passage, text);
	return passage;
}

@ So, then, this takes the stretch of running text in |text| and parses it
into nodes which become the newest children of |owner|.

=
void Markdown::parse_inline_matter(markdown_item *owner, text_stream *text) {
	@<First pass: top-level inline items@>;
	@<Second pass: emphasis inline items@>;
}

@h Inline code.
At the top level, we look for code snippets inside backticks.

See CommonMark 6.1: "A backtick string is a string of one or more backtick
characters that is neither preceded nor followed by a backtick." This returns
the length of a backtick string beginning at |at|, if one does, or 0 if it
does not.

=
int Markdown::backtick_string(text_stream *text, int at) {
	int count = 0;
	while (Str::get_at(text, at + count) == '`') count++;
	if (count == 0) return 0;
	if ((at > 0) && (Str::get_at(text, at - 1) == '`')) return 0;
	return count;
}

@<First pass: top-level inline items@> =
	int from = 0;
	for (int i=0; i<Str::len(text); i++) {
		int count = Markdown::backtick_string(text, i);
		if (count > 0) {
			for (int j=i+count+1; j<Str::len(text); j++) {
				if (Markdown::backtick_string(text, j) == count) {
					if (i-1 >= from) {
						markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
						Markdown::add_to(md, owner);
					}
					@<Insert an inline code item@>;
					i = j+count; from = j+count;
					goto ContinueOuter;
				}
			}
		}
		ContinueOuter: ;
	}
	if (from <= Str::len(text)-1) {
		markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, Str::len(text)-1);
		Markdown::add_to(md, owner);
	}

@ "The contents of the code span are the characters between these two backtick strings".
Inside it, "line endings are converted to spaces", and "If the resulting string
both begins and ends with a space character, but does not consist entirely of
space characters, a single space character is removed from the front and back."

@<Insert an inline code item@> =
	int start = i+count, end = j-1;
	text_stream *codespan = Str::new();
	int all_spaces = TRUE;
	for (int k=start; k<=end; k++) {
		wchar_t c = Str::get_at(text, k);
		if (c == '\n') c = ' ';
		if (c != ' ') all_spaces = FALSE;
		PUT_TO(codespan, c);
	}
	if ((all_spaces == FALSE) && (Str::get_first_char(codespan) == ' ')
		 && (Str::get_last_char(codespan) == ' ')) {
		markdown_item *md = Markdown::new_slice(CODE_MIT, codespan, 1, Str::len(codespan)-2);
		Markdown::add_to(md, owner);		 
	} else {
		markdown_item *md = Markdown::new_slice(CODE_MIT, codespan, 0, Str::len(codespan)-1);
		Markdown::add_to(md, owner);
	}

@h Emphasis.
Well, that was easy. Now for the second pass, in which we look for the use
of asterisks and underscores for emphasis. This notation is deeply ambiguous
on its face, and CommonMark's precise specification is a bit of an ordeal,
but here goes.

@<Second pass: emphasis inline items@> =
	Markdown::fragment_into_emphasis_items(owner);

@ =
void Markdown::fragment_into_emphasis_items(markdown_item *owner) {
	text_stream *OUT = STDOUT;
	if (tracing_Markdown_parser) {
		INDENT;
		WRITE("Seeking emphasis in:\n");
		Markdown::render_debug(STDOUT, owner);
	}
	@<Seek emphasis@>;
	if (tracing_Markdown_parser) {
		WRITE("Emphasis search complete\n");
		OUTDENT;
	}
}

@ "A delimiter run is either a sequence of one or more * characters that is not
preceded or followed by a non-backslash-escaped * character, or a sequence of
one or more _ characters that is not preceded or followed by a
non-backslash-escaped _ character."

This function returns 0 unless a delimiter run begins at |at|, and then returns
its length if this was asterisked, and minus its length if underscored.

=
int Markdown::delimiter_run(markdown_item *md, int at) {
	int count = Markdown::unescaped_run(md, at, '*');
	if ((count > 0) && (Markdown::get_unescaped(md, at-1) != '*')) return count;
	count = Markdown::unescaped_run(md, at, '_');
	if ((count > 0) && (Markdown::get_unescaped(md, at-1) != '_')) return -count;
	return 0;
}

@ "A left-flanking delimiter run is a delimiter run that is (1) not followed by
Unicode whitespace, and either (2a) not followed by a Unicode punctuation
character, or (2b) followed by a Unicode punctuation character and preceded by
Unicode whitespace or a Unicode punctuation character. For purposes of this
definition, the beginning and the end of the line count as Unicode whitespace."

"A right-flanking delimiter run is a delimiter run that is (1) not preceded by
Unicode whitespace, and either (2a) not preceded by a Unicode punctuation
character, or (2b) preceded by a Unicode punctuation character and followed by
Unicode whitespace or a Unicode punctuation character. For purposes of this
definition, the beginning and the end of the line count as Unicode whitespace."

=
int Markdown::left_flanking(markdown_item *md, int at, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	wchar_t followed_by = Markdown::get_unescaped(md, at + count);
	if ((followed_by == 0) || (Markdown::is_Unicode_whitespace(followed_by))) return FALSE;
	if (Markdown::is_Unicode_punctuation(followed_by) == FALSE) return TRUE;
	wchar_t preceded_by = Markdown::get_unescaped(md, at - 1);
	if ((preceded_by == 0) || (Markdown::is_Unicode_whitespace(preceded_by)) ||
		(Markdown::is_Unicode_punctuation(preceded_by))) return TRUE;
	return FALSE;
}

int Markdown::right_flanking(markdown_item *md, int at, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	wchar_t preceded_by = Markdown::get_unescaped(md, at - 1);
	if ((preceded_by == 0) || (Markdown::is_Unicode_whitespace(preceded_by))) return FALSE;
	if (Markdown::is_Unicode_punctuation(preceded_by) == FALSE) return TRUE;
	wchar_t followed_by = Markdown::get_unescaped(md, at + count);
	if ((followed_by == 0) || (Markdown::is_Unicode_whitespace(followed_by)) ||
		(Markdown::is_Unicode_punctuation(followed_by))) return TRUE;
	return FALSE;
}

@ The following expresses rules (1) to (8) in the CM specification, section 6.2.

=
int Markdown::can_open_emphasis(markdown_item *md, int at, int count) {
	if (Markdown::left_flanking(md, at, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (Markdown::right_flanking(md, at, count) == FALSE) return TRUE;
	wchar_t preceded_by = Markdown::get_unescaped(md, at - 1);
	if (Markdown::is_Unicode_punctuation(preceded_by)) return TRUE;
	return FALSE;
}

int Markdown::can_close_emphasis(markdown_item *md, int at, int count) {
	if (Markdown::right_flanking(md, at, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (Markdown::left_flanking(md, at, count) == FALSE) return TRUE;
	wchar_t followed_by = Markdown::get_unescaped(md, at - count); /* count < 0 here */
	if (Markdown::is_Unicode_punctuation(followed_by)) return TRUE;
	return FALSE;
}

@ This naive algorithm has every possibility of becoming computationally
explosive if a really knotty tangle of nested emphasis delimiters comes along,
though of course that is a rare occurrence. We're going to find every possible
way to pair opening and closing delimiters, and then score the results with a
system of penalties. Whichever solution has the least penalty is the winner.

In almost every example of normal Markdown written by actual human beings,
there will be just one open/close option at a time.

@d MAX_MD_EMPHASIS_PAIRS (MAX_MD_EMPHASIS_DELIMITERS*MAX_MD_EMPHASIS_DELIMITERS)

@<Seek emphasis@> =
	int no_delimiters = 0;
	md_emphasis_delimiter delimiters[MAX_MD_EMPHASIS_DELIMITERS];
	@<Find the possible emphasis delimiters@>;

	markdown_item *options[MAX_MD_EMPHASIS_DELIMITERS];
	int no_options = 0;
	for (int open_i = 0; open_i < no_delimiters; open_i++) {
		md_emphasis_delimiter *OD = &(delimiters[open_i]);
		if (OD->can_open == FALSE) continue;
		for (int close_i = open_i+1; close_i < no_delimiters; close_i++) {
			md_emphasis_delimiter *CD = &(delimiters[close_i]);
			if (CD->can_close == FALSE) continue;
			@<Reject this as a possible closer if it cannot match the opener@>;
			if (tracing_Markdown_parser) {
				WRITE("Option %d is to pair D%d with D%d\n", no_options, open_i, close_i);
			}
			@<Create the subtree which would result from this option being chosen@>;
		}
	}
	if (no_options > 0) @<Select the option with the lowest penalty@>;

@ We don't want to find every possible delimiter, in case the source text is
absolutely huge: indeed, we never exceed |MAX_MD_EMPHASIS_DELIMITERS|.

A further optimisation is that (a) we needn't even record delimiters which
can't open or close, (b) or delimiters which can only close and which occur
before any openers, (c) or anything after a point where we can clearly complete
at least one pair correctly.

For example, consider |This is *emphatic* and **so is this**.| Rule (c) makes
it unnecessary to look past the end of the word "emphatic", because by that
point we have seen an opener which cannot close and a closer which cannot open,
of equal widths. These can only pair with each other; so we can stop.

As a result, in almost all human-written Markdown, the algorithm below returns
exactly two delimiters, one open, one close.

In other situations, it's harder to predict what will happen. We will contain
the possible explosion by restricting to cases where at least one pair can be
made within the first |MAX_MD_EMPHASIS_DELIMITERS| potential delimiters, and
we can pretty safely keep that number small.

@d MAX_MD_EMPHASIS_DELIMITERS 10

=
typedef struct md_emphasis_delimiter {
	struct markdown_item *item; /* this will be a |PLAIN_MIT| node */
	int at; /* and this will be a position within it */
	int width; /* for example, 7 for a run of seven asterisks */
	int type; /* 1 for asterisks, -1 for underscores */
	int can_open; /* result of |Markdown::can_open_emphasis| on it */
	int can_close; /* result of |Markdown::can_close_emphasis| on it */
	CLASS_DEFINITION
} md_emphasis_delimiter;

@<Find the possible emphasis delimiters@> =
	int pos = 0, open_count[2] = { 0, 0 }, close_count[2] = { 0, 0 }, both_count[2] = { 0, 0 }; 
	for (markdown_item *md = owner->down; md; md = md->next) {
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++, pos++) {
				int run = Markdown::delimiter_run(md, i);
				if (run != 0) {
					if (no_delimiters >= MAX_MD_EMPHASIS_DELIMITERS) break;
					int can_open = Markdown::can_open_emphasis(md, i, run);
					int can_close = Markdown::can_close_emphasis(md, i, run);
					if ((no_delimiters == 0) && (can_open == FALSE)) continue;
					if ((can_open == FALSE) && (can_close == FALSE)) continue;
					md_emphasis_delimiter *P = &(delimiters[no_delimiters++]);
					P->at = i;
					P->item = md;
					P->width = (run>0)?run:(-run);
					P->type = (run>0)?1:-1;
					P->can_open = can_open;
					P->can_close = can_close;
					if (tracing_Markdown_parser) {
						WRITE("DR%d at %d with width %d type %d left, right %d, "
							"%d open, close %d, %d preceded '%c' followed '%c'\n",
							no_delimiters, pos, P->width, P->type,
							Markdown::left_flanking(md, P->at, run),
							Markdown::right_flanking(md, P->at, run),
							P->can_open, P->can_close,
							Markdown::get_unescaped(md, P->at - 1),
							Markdown::get_unescaped(md, P->at + P->width));
					}
					int x = (P->type>0)?0:1;
					if ((can_open) && (can_close == FALSE)) open_count[x] += P->width;
					if ((can_open == FALSE) && (can_close)) close_count[x] += P->width;
					if ((can_open) && (can_close)) both_count[x] += P->width;
					if ((both_count[0] == 0) && (open_count[0] == close_count[0]) &&
						(both_count[1] == 0) && (open_count[1] == close_count[1])) break;
				}
			}
		}
	}

@ We vet |OD| and |CD| to see if it's possible to pair them together. We
already know that |OD| can open and |CD| can close, and that |OD| precedes
|CD| ("The opening and closing delimiters must belong to separate delimiter
runs."). They must have the same type: asterisk pair with asterisks, underscores
with underscores.

That's when the CommonMark specification becomes kind of hilarious: "If one of
the delimiters can both open and close emphasis, then the sum of the lengths of
the delimiter runs containing the opening and closing delimiters must not be a
multiple of 3 unless both lengths are multiples of 3."

@<Reject this as a possible closer if it cannot match the opener@> =
	if (CD->type != OD->type) continue;
	if ((CD->can_open) || (OD->can_close)) {
		int sum = OD->width + CD->width;
		if (sum % 3 == 0) {
			if (OD->width % 3 != 0) continue;
			if (CD->width % 3 != 0) continue;
		}
	}

@ Okay, so now |OD| and |CD| are conceivable pairs to each other, and we
investigate the consequences. We need to copy the existing situation so
that we can alter it without destroying the original.

Note the two recursive uses of |Markdown::fragment_into_emphasis_items| to continue
the process of pairing: this is where the computational fuse is lit, with
the explosion to follow. But since each subtree contains fewer delimiter runs
than the original, it does at least terminate.

@<Create the subtree which would result from this option being chosen@> =
	markdown_item *option = Markdown::deep_copy(owner);
	options[no_options++] = option;
	markdown_item *OI = NULL, *CI = NULL;
	for (markdown_item *md = option->down; md; md = md->next) {
		if (md->copied_from == OD->item) OI = md;
		if (md->copied_from == CD->item) CI = md;
	}
	if ((OI == NULL) || (CI == NULL)) internal_error("copy accident");

	int width; /* number of delimiter characters we will trim */
	int cut1; /* last char before left delimiter */
	int cut2; /* first char after left delimiter */
	int cut3; /* last char before right delimiter */
	int cut4; /* first char after right delimiter */
	@<Draw the dotted lines where we will cut@>;

	@<Deactivate the active characters being acted on@>;

	markdown_item *em_top, *em_bottom;
	@<Make the chain of emphasis nodes from top to bottom@>;

	if (OI == CI) @<The opener and closer are in the same PLAIN item@>
	else @<The opener and closer are in different PLAIN items@>;

	Markdown::fragment_into_emphasis_items(em_bottom);
	Markdown::fragment_into_emphasis_items(option);

	if (tracing_Markdown_parser) {
		WRITE("Option %d is to fragment thus:\n", no_options);
		Markdown::render_debug(STDOUT, option);
		WRITE("Resulting in: ");
		Markdown::render_md_purist(STDOUT, option);
		WRITE("Which scores %d penalty points\n", Markdown::penalty(option));
	}

@ This innocent-looking code is very tricky. The issue is that the two delimiters
may be of unequal width. We want to take as many asterisks/underscores away
as we can, so we set |width| to the minimum of the two lengths. But a complication
is that they need to be cropped to fit inside the slice of the node they belong
to first.

We then mark to remove |width| characters from the inside edges of each
delimiter, not the outside edges.

@<Draw the dotted lines where we will cut@> =
	int O_start = OD->at, O_width = OD->width;
	if (O_start < OI->from) { O_width -= (OI->from - O_start); O_start = OI->from; }

	int C_start = CD->at, C_width = CD->width;
	if (C_start + C_width - 1 > CI->to) { C_width = CI->to - C_start + 1; }

	width = O_width; if (width > C_width) width = C_width;

	cut2 = O_start + O_width;
	cut1 = cut2 - width - 1;

	cut3 = C_start - 1;
	cut4 = C_start + width;

@<Deactivate the active characters being acted on@> =
	for (int w=1; w<=width; w++) {
		Str::put_at(OI->sliced_from, cut1+w, ':');
		Str::put_at(CI->sliced_from, cut3+w, ':');
	}

@ Suppose we are peeling away 5 asterisks from the inside edges of each delimiter,
so that |width| is 5. There are only two strengths of emphasis in Markdown, so
this must be read as one of the various ways to add 1s and 2s to make 5.
CommonMark rule 13 reads "The number of nestings should be minimized.", so we
must use all 2s except for the 1 left over. Rule 14 says that left-over 1 must
be outermost. So this would give us:
= (text)
	EMPHASIS_MIT  <--- this is em_top
		STRONG_MIT
			STRONG_MIT  <--- this is em_bottom
				...the actual content being emphasised
=

@<Make the chain of emphasis nodes from top to bottom@> =
	em_top = Markdown::new_item(((width%2) == 1)?EMPHASIS_MIT:STRONG_MIT);
	if ((width%2) == 1) width -= 1; else width -= 2;
	em_bottom = em_top;
	while (width > 0) {
		markdown_item *g = Markdown::new_item(STRONG_MIT); width -= 2;
		em_bottom->down = g; em_bottom = g;
	}

@<The opener and closer are in the same PLAIN item@> =
	if (tracing_Markdown_parser) {
		WRITE("One item D%d(%d, %d) width %d -> %d, %d, %d, %d, %d, %d\n",
			OI->id, OI->from, OI->to, width, OI->from, cut1, cut2, cut3, cut4, OI->to);
	}
	markdown_item *was_next = OI->next;
	OI->next = em_top;
	em_bottom->down = Markdown::new_slice(PLAIN_MIT, OI->sliced_from, cut2, cut3);
	em_top->next = Markdown::new_slice(PLAIN_MIT, OI->sliced_from, cut4, OI->to);
	OI->to = cut1;
	em_top->next->next = was_next;

@<The opener and closer are in different PLAIN items@> =
	if (tracing_Markdown_parser) {
		WRITE("Multiple items D%d(%d, %d) ... D%d(%d, %d) width %d -> %d, %d, %d, %d, %d, %d\n",
			OI->id, OI->from, OI->to, CI->id, CI->from, CI->to,
			width, OI->from, cut1, cut2, cut3, cut4, CI->to);
	}
	if (cut2 <= OI->to) {
		markdown_item *left_inner_fragment =
			Markdown::new_slice(PLAIN_MIT, OI->sliced_from, cut2, OI->to);
		Markdown::add_to(left_inner_fragment, em_bottom);
	}
	OI->to = cut1;
	for (markdown_item *md = OI, *next_md = (md)?(md->next):NULL; (md) && (md != CI);
		md = next_md, next_md = (md)?(md->next):NULL)
		if ((md != OI) && (md != CI))
			Markdown::add_to(md, em_bottom);
	if (cut3 >= 0) {
		markdown_item *right_inner_fragment =
			Markdown::new_slice(PLAIN_MIT, CI->sliced_from, CI->from, cut3);
		Markdown::add_to(right_inner_fragment, em_bottom);
	}
	CI->from = cut4;
	OI->next = em_top; em_top->next = CI;

@<Select the option with the lowest penalty@> =
	int best_is = 1, best_score = 100000000;
	for (int pair_i = 0; pair_i < no_options; pair_i++) {
		int score = Markdown::penalty(options[pair_i]);
		if (score < best_score) { best_score = score; best_is = pair_i; }
	}
	if (tracing_Markdown_parser) {
		WRITE("Selected option %d with penalty %d\n", best_is, best_score);
	}
	owner->down = options[best_is]->down;

@ That just leaves the penalty scoring system: how unfortunate is a possible
reading of the Markdown syntax?

We score a whopping penalty for any unescaped asterisks and underscores left
over, because above all we want to pair as many delimiters as possible together.
(Some choices of pairings preclude others: it's a messy dynamic programming
problem to work this out in detail.)

We then impose a modest penalty on the width of a piece of emphasis, in
order to achieve CommonMark's rule 16: "When there are two potential emphasis
or strong emphasis spans with the same closing delimiter, the shorter one
(the one that opens later) takes precedence."

=
int Markdown::penalty(markdown_item *md) {
	if (md) {
		int penalty = 0;
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				wchar_t c = Markdown::get_unescaped(md, i);
				if ((c == '*') || (c == '_')) penalty += 100000;
			}
		}
		if ((md->type == EMPHASIS_MIT) || (md->type == STRONG_MIT))
			penalty += Markdown::width(md->down);
		for (markdown_item *c = md->down; c; c = c->next)
			penalty += Markdown::penalty(c);
		return penalty;
	}
	return 0;
}

@h Rendering.
This is blessedly simple by comparison.

=
void Markdown::render_md_purist(OUTPUT_STREAM, markdown_item *md) {
	if (md) {
		switch (md->type) {
			case PARAGRAPH_MIT: HTML_OPEN("p");
								@<Recurse@>;
								HTML_CLOSE("p");
								break;
			case MATERIAL_MIT: 	@<Recurse@>;
								break;
			case PLAIN_MIT:    	@<Render text@>;
								break;
			case EMPHASIS_MIT: 	HTML_OPEN("em");
								@<Recurse@>;
								HTML_CLOSE("em");
								break;
			case STRONG_MIT:   	HTML_OPEN("strong");
								@<Recurse@>;
								HTML_CLOSE("strong");
								break;
			case CODE_MIT:     	HTML_OPEN("code");
								@<Render text unescaped@>;
								HTML_CLOSE("code");
								break;
		}
	}
}

@<Recurse@> =
	for (markdown_item *c = md->down; c; c = c->next)
		Markdown::render_md_purist(OUT, c);

@<Render text@> =
	for (int i=md->from; i<=md->to; i++) {
		wchar_t c = Markdown::get_at(md, i);
		if (c == '\\') { i++; c = Markdown::get_at(md, i); }
		PUT(c);
	}

@<Render text unescaped@> =
	for (int i=md->from; i<=md->to; i++) {
		wchar_t c = Markdown::get_at(md, i);
		PUT(c);
	}
