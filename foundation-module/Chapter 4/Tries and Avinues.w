[Tries::] Tries and Avinues.

To examine heads and tails of text, to see how it may inflect.

@h Tries.
The standard data structure for searches through possible prefixes or
suffixes is a "trie". The term goes back to Edward Fredkin in 1961;
some pronounce it "try" and some "tree", and either would be a fair
description. Like hash tables, tries are a means of minimising string
comparisons when sorting through possible outcomes based on a text.

The trie is a tree with three kinds of node:

- "Heads". Every trie has exactly one such node, and it's always the root.
There are two versions of this: a start head represents matching from the
front of a text, whereas an end head represents matching from the back.

- "Choices". A choice node has a given match character, say an "f", and
represents which node to go to next if this is the current character in the
text. It must either be a valid Unicode character or |TRIE_ANYTHING|, which
is a wildcard representing "any text of any length here". Since a choice
must always lead somewhere, |on_success| must point to another node.
There can be any number of choices at a given position, so choice nodes
are always organised in linked lists joined by |next|.

- "Terminals", always leaves, which have match character set to the
impossible value |TRIE_STOP|, and for which |match_outcome| is non-null; thus,
different terminal nodes can result in different outcomes if they are ever
reached at the end of a successful scan. A terminal node is always the only item
in a list.

@d TRIE_START -1 /* head: the root of a trie parsing forwards from the start */
@d TRIE_END -2 /* head: the root of a trie parsing backwards from the end */
@d TRIE_ANYTHING 10003 /* choice: match any text here */
@d TRIE_ANY_GROUP 10001 /* choice: match any character from this group */
@d TRIE_NOT_GROUP 10002 /* choice: match any character not in this group */
@d TRIE_STOP -3 /* terminal: here's the outcome */

@d MAX_TRIE_GROUP_SIZE 26 /* size of the allowable groups of characters */

=
typedef struct match_trie {
	int match_character; /* or one of the special cases above */
	inchar32_t group_characters[MAX_TRIE_GROUP_SIZE+1];
	inchar32_t *match_outcome;
	struct match_trie *on_success;
	struct match_trie *next;
} match_trie;

@ We have just one routine for extending and scanning the trie: it either
tries to find whether a text |p| leads to any outcome in the existing trie,
or else forcibly extends the existing trie to ensure that it does.

It might look as if calling |Tries::search| always returns |add_outcome| when
this is set, but this isn't true: if the trie already contains a node
representing how to deal with |p|, we get whatever outcome is already
established.

There are two motions to keep track of: our progress through the text |p|
being scanned, and our progress through the trie which tells us how to scan it.

We scan the text either forwards or backwards, starting with the first or
last character and then working through, finishing with a 0 terminator.
(This is true even if working backwards: we pretend the character stored
before the text began is 0.) |i| represents the index of our current position
in |p|, and runs either from 0 up to |N| or from |N-1| down to |-1|,
where |N| is the number of characters in |p|.

We scan the trie using a pair of pointers. |prev| is the last node we
successfully left, and |pos| is one we are currently at, which can be
either a terminal node or a choice node (in which case it's the head of
a linked list of such nodes).

@d MAX_TRIE_REWIND 10 /* that should be far, far more rewinding than necessary */

=
inchar32_t *Tries::search(match_trie *T, text_stream *p, inchar32_t *add_outcome) {
	if (T == NULL) internal_error("no trie to search");

	int start, endpoint, delta;
	@<Look at the root node of the trie, setting up the scan accordingly@>;

	match_trie *prev = NULL, *pos = T;
	@<Accept the current node of the trie@>;

	int rewind_sp = 0;
	int rewind_points[MAX_TRIE_REWIND];
	match_trie *rewind_positions[MAX_TRIE_REWIND];
	match_trie *rewind_prev_positions[MAX_TRIE_REWIND];

	for (int i = start; i != endpoint+delta; i += delta) {
		inchar32_t group[MAX_TRIE_GROUP_SIZE+1];
		int g = 0; /* size of group */
		inchar32_t c = (i<0)?0:(Str::get_at(p, i)); /* i.e., zero at the two ends of the text */
		if ((c >= 0x20) && (c <= 0x7f)) c = Characters::tolower(c); /* normalise it within ASCII */
		if (c == 0x20) { c = 0; i = endpoint - delta; } /* force any space to be equivalent to the final 0 */
		if (add_outcome) {
			inchar32_t pairc = 0;
			if (c == '<') pairc = '>';
			if (c == '>') pairc = '<';
			if (pairc) {
				int j;
				for (j = i+delta; j != endpoint; j += delta) {
					inchar32_t ch = (j<0)?0:(Str::get_at(p, j));
					if (ch == pairc) break;
					if (g > MAX_TRIE_GROUP_SIZE) { g = 0; break; }
					group[g++] = ch;
				}
				group[g] = 0;
				if (g > 0) i = j;
			}
		}
		if (c == '*') endpoint -= delta;

		RewindHere:
		@<Look through the possible exits from this position and move on if any match@>;
		if (add_outcome == NULL) {
			if (rewind_sp > 0) {
				i = rewind_points[rewind_sp-1];
				pos = rewind_positions[rewind_sp-1];
				prev = rewind_prev_positions[rewind_sp-1];
				rewind_sp--;
				goto RewindHere;
			}
			return NULL; /* failure! */
		}
		@<We have run out of trie and must create a new exit to continue@>;
	}
	if ((pos) && (pos->match_character == TRIE_ANYTHING)) @<Accept the current node of the trie@>;
	if ((pos) && (pos->match_outcome)) return pos->match_outcome; /* success! */
	if (add_outcome == NULL) return NULL; /* failure! */

	if (pos == NULL)
		@<We failed by running out of trie, so we must add a terminal node to make this string acceptable@>
	else
		@<We failed by finishing at a non-terminal node, so we must add an outcome@>;
}

@<Look at the root node of the trie, setting up the scan accordingly@> =
	start = 0; endpoint = Str::len(p); delta = 1;
	if (T->match_character == TRIE_END) { start = Str::len(p)-1; endpoint = -1; delta = -1; }

@ In general trie searches can be made more efficient if the trie is shuffled
so that the most recently matched exit in the list if moved to the top, as
this tends to make commonly used exits migrate upwards and rarities downwards.
But we aren't going to search these tries anything like intensively enough
to make it worth the trouble.

(The following cannot be a |while| loop since C does not allow us to |break|
or |continue| out of an outer loop from an inner one.)

@<Look through the possible exits from this position and move on if any match@> =
	int ambig = 0, unambig = 0;
	match_trie *point;
	for (point = pos; point; point = point->next)
		if (Tries::is_ambiguous(point)) ambig++;
		else unambig++;

	FauxWhileLoop:
	if (pos) {
		if ((add_outcome == NULL) || (Tries::is_ambiguous(pos) == FALSE))
			if (Tries::matches(pos, c)) {
				if (pos->match_character == TRIE_ANYTHING) break;
				if ((add_outcome == NULL) && (ambig > 0) && (ambig+unambig > 1)
					&& (rewind_sp < MAX_TRIE_REWIND)) {
					rewind_points[rewind_sp] = i;
					rewind_positions[rewind_sp] = pos->next;
					rewind_prev_positions[rewind_sp] = prev;
					rewind_sp++;
				}
				@<Accept the current node of the trie@>;
				continue;
			}
		pos = pos->next;
		goto FauxWhileLoop;
	}

@<We have run out of trie and must create a new exit to continue@> =
	match_trie *new_pos = NULL;
	if (g > 0) {
		int nt = TRIE_ANY_GROUP;
		inchar32_t *from = group;
		if (group[0] == '!') { from++; nt = TRIE_NOT_GROUP; }
		if (group[(int) Wide::len(group)-1] == '!') {
			group[(int) Wide::len(group)-1] = 0; nt = TRIE_NOT_GROUP;
		}
		new_pos = Tries::new(nt);
		Wide::copy(new_pos->group_characters, from);
	} else if (c == '*') new_pos = Tries::new(TRIE_ANYTHING);
	else new_pos = Tries::new((int)c);

	if (prev->on_success == NULL) prev->on_success = new_pos;
	else {
		match_trie *ppoint = NULL, *point;
		for (point = prev->on_success; point; ppoint = point, point = point->next) {
			if (new_pos->match_character < point->match_character) {
				if (ppoint == NULL) {
					new_pos->next = prev->on_success;
					prev->on_success = new_pos;
				} else {
					ppoint->next = new_pos;
					new_pos->next = point;
				}
				break;
			}
			if (point->next == NULL) {
				point->next = new_pos;
				break;
			}
		}
	}

	pos = new_pos;
	@<Accept the current node of the trie@>; continue;

@<Accept the current node of the trie@> =
	if (pos == NULL) internal_error("trie invariant broken");
	prev = pos; pos = prev->on_success;

@ If |pos| is |NULL| then it follows that |prev->on_success| is |NULL|, since
this is how |pos| was calculated; so to add a new terminal node we simply add
it there.

@<We failed by running out of trie, so we must add a terminal node to make this string acceptable@> =
	prev->on_success = Tries::new(TRIE_STOP);
	prev->on_success->match_outcome = add_outcome;
	return add_outcome;

@<We failed by finishing at a non-terminal node, so we must add an outcome@> =
	prev->on_success = Tries::new(TRIE_STOP);
	prev->on_success->match_outcome = add_outcome;
	return add_outcome;

@ Single nodes are matched thus:

=
int Tries::matches(match_trie *pos, inchar32_t c) {
	if (pos->match_character == TRIE_ANYTHING) return TRUE;
	if (pos->match_character == TRIE_ANY_GROUP) {
		int k;
		for (k = 0; pos->group_characters[k]; k++)
			if (c == pos->group_characters[k])
				return TRUE;
		return FALSE;
	}
	if (pos->match_character == TRIE_NOT_GROUP) {
		int k;
		for (k = 0; pos->group_characters[k]; k++)
			if (c == pos->group_characters[k])
				return FALSE;
		return TRUE;
	}
	if (pos->match_character == (int)c) return TRUE;
	return FALSE;
}

int Tries::is_ambiguous(match_trie *pos) {
	if (pos->match_character == TRIE_ANYTHING) return TRUE;
	if (pos->match_character == TRIE_ANY_GROUP) return TRUE;
	if (pos->match_character == TRIE_NOT_GROUP) return TRUE;
	return FALSE;
}

@ Where:

=
match_trie *Tries::new(int mc) {
	match_trie *T = CREATE(match_trie);
	T->match_character = mc;
	T->match_outcome = NULL;
	T->on_success = NULL;
	T->next = NULL;
	return T;
}

@h Avinues.
A trie is only a limited form of finite state machine. We're not going to need
the whole power of these, but we do find it useful to chain a series of tries
together. The idea is to scan against one trie, then, if there's no result,
start again with the next, and so on. Inform therefore often matches text
against a linked list of tries: we'll call that an "avinue".

=
typedef struct match_avinue {
	struct match_trie *the_trie;
	struct match_avinue *next;
} match_avinue;

@ An avinue starts out with a single trie, which itself has just a single
head node (of either sort).

=
match_avinue *Tries::new_avinue(int from_start) {
	match_avinue *A = CREATE(match_avinue);
	A->next = NULL;
	A->the_trie = Tries::new(from_start);
	return A;
}

void Tries::add_to_avinue(match_avinue *mt, text_stream *from, inchar32_t *to) {
	if ((mt == NULL) || (mt->the_trie == NULL)) internal_error("null trie");
	Tries::search(mt->the_trie, from, to);
}

@ The following duplicates an avinue, pointing to the same sequence of
tries.

=
match_avinue *Tries::duplicate_avinue(match_avinue *A) {
	match_avinue *F = NULL, *FL = NULL;
	while (A) {
		match_avinue *FN = CREATE(match_avinue);
		FN->next = NULL;
		FN->the_trie = A->the_trie;
		A = A->next;
		if (FL) FL->next = FN;
		if (F == NULL) F = FN;
		FL = FN;
	}
	return F;
}

@ As noted above, searching an avinue is a matter of searching with each
trie in turn until one matches (if it does).

=
inchar32_t *Tries::search_avinue(match_avinue *T, text_stream *p) {
	inchar32_t *result = NULL;
	while ((T) && (result == NULL)) {
		result = Tries::search(T->the_trie, p, NULL);
		T = T->next;
	}
	return result;
}

@h Logging.

=
void Tries::log_avinue(OUTPUT_STREAM, void *vA) {
	match_avinue *A = (match_avinue *) vA;
	WRITE("Avinue:\n"); INDENT;
	int n = 1;
	while (A) {
		WRITE("Trie %d:\n", n++); INDENT;
		Tries::log(OUT, A->the_trie);
		OUTDENT;
		A = A->next;
	}
	OUTDENT;
}

void Tries::log(OUTPUT_STREAM, match_trie *T) {
	for (; T; T = T->next) {
		switch (T->match_character) {
			case TRIE_START: WRITE("Start"); break;
			case TRIE_END: WRITE("End"); break;
			case TRIE_ANYTHING: WRITE("Anything"); break;
			case TRIE_ANY_GROUP: WRITE("Group <%w>", T->group_characters); break;
			case TRIE_NOT_GROUP: WRITE("Negated group <%w>", T->group_characters); break;
			case TRIE_STOP: WRITE("Stop"); break;
			case 0: WRITE("00"); break;
			default: WRITE("%c", T->match_character); break;
		}
		if (T->match_outcome) WRITE(" --> %s", T->match_outcome);
		WRITE("\n");
		if (T->on_success) {
			INDENT; Tries::log(OUT, T->on_success); OUTDENT;
		}
	}
}
