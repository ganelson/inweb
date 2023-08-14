[Markdown::] Markdown.

To parse a simplified form of the Markdown markup notation, and render the
result in HTML.

@ The following is a simple approach which implements only a subset of
Markdown as yet, but it follows CommonMark rules and correctly handles
its examples. I am indebted to //CM v0.30 -> https://spec.commonmark.org/0.30//.

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
	return Markdown::is_ASCII_punctuation(c);
}

@ Whereas these are fairly unarguable.

=
int Markdown::is_ASCII_letter(wchar_t c) {
	if ((c >= 'a') && (c <= 'z')) return TRUE;
	if ((c >= 'A') && (c <= 'Z')) return TRUE;
	return FALSE;
}

int Markdown::is_ASCII_digit(wchar_t c) {
	if ((c >= '0') && (c <= '9')) return TRUE;
	return FALSE;
}

int Markdown::is_control_character(wchar_t c) {
	if ((c >= 0x0001) && (c <= 0x001f)) return TRUE;
	if (c == 0x007f) return TRUE;
	return FALSE;
}

int Markdown::is_ASCII_punctuation(wchar_t c) {
	if ((c >= 0x0021) && (c <= 0x002F)) return TRUE;
	if ((c >= 0x003A) && (c <= 0x0040)) return TRUE;
	if ((c >= 0x005B) && (c <= 0x0060)) return TRUE;
	if ((c >= 0x007B) && (c <= 0x007E)) return TRUE;
	return FALSE;
}

@h Item types.
We will parse a paragraph of MD content into a tree of nodes, each of which
has one of the following types:

@e DOCUMENT_MIT from 1
@e PARAGRAPH_MIT
@e THEMATIC_MIT
@e ATX_MIT
@e SETEXT_MIT
@e INDENTED_CODE_MIT
@e FENCED_CODE_MIT
@e HTML_MIT
@e LINK_REF_MIT
@e BLOCK_QUOTE_MIT
@e LIST_MIT
@e LIST_ITEM_MIT
@e MATERIAL_MIT
@e PLAIN_MIT
@e EMPHASIS_MIT
@e STRONG_MIT
@e CODE_MIT
@e URI_AUTOLINK_MIT
@e EMAIL_AUTOLINK_MIT
@e INLINE_HTML_MIT
@e LINE_BREAK_MIT
@e SOFT_BREAK_MIT
@e LINK_MIT
@e IMAGE_MIT
@e LINK_DEST_MIT
@e LINK_TITLE_MIT

=
text_stream *Markdown::item_type_name(int t) {
	switch (t) {
		case DOCUMENT_MIT:       return I"DOCUMENT_MIT";
		case PARAGRAPH_MIT:      return I"PARAGRAPH";
		case THEMATIC_MIT:       return I"THEMATIC";
		case ATX_MIT:            return I"ATX";
		case SETEXT_MIT:         return I"SETEXT";
		case INDENTED_CODE_MIT:  return I"INDENTED_CODE";
		case FENCED_CODE_MIT:    return I"FENCED_CODE";
		case HTML_MIT:           return I"HTML";
		case LINK_REF_MIT:       return I"LINK_REF";
		case BLOCK_QUOTE_MIT:    return I"BLOCK_QUOTE";
		case LIST_MIT:           return I"LIST";
		case LIST_ITEM_MIT:      return I"LIST_ITEM";
		case MATERIAL_MIT:       return I"MATERIAL";
		case PLAIN_MIT:          return I"PLAIN";
		case EMPHASIS_MIT:       return I"EMPHASIS";
		case STRONG_MIT:         return I"STRONG";
		case LINK_MIT:           return I"LINK";
		case IMAGE_MIT:          return I"IMAGE";
		case LINK_DEST_MIT:      return I"LINK_DEST";
		case LINK_TITLE_MIT:     return I"LINK_TITLE";
		case CODE_MIT:           return I"CODE";
		case URI_AUTOLINK_MIT:   return I"URI_AUTOLINK";
		case EMAIL_AUTOLINK_MIT: return I"EMAIL_AUTOLINK";
		case INLINE_HTML_MIT:    return I"INLINE_HTML";
		case LINE_BREAK_MIT:     return I"LINE_BREAK";
		case SOFT_BREAK_MIT:     return I"SOFT_BREAK";
		default:                 return I"<UNKNOWN>";
	}
}

int Markdown::item_type_container_block(int t) {
	switch (t) {
		case DOCUMENT_MIT:       return TRUE;
		case BLOCK_QUOTE_MIT:    return TRUE;
		case LIST_MIT:           return TRUE;
		case LIST_ITEM_MIT:      return TRUE;
	}
	return FALSE;
}

int Markdown::item_type_leaf_block(int t) {
	switch (t) {
		case PARAGRAPH_MIT:      return TRUE;
		case THEMATIC_MIT:       return TRUE;
		case ATX_MIT:            return TRUE;
		case SETEXT_MIT:         return TRUE;
		case INDENTED_CODE_MIT:  return TRUE;
		case FENCED_CODE_MIT:    return TRUE;
		case HTML_MIT:           return TRUE;
		case LINK_REF_MIT:       return TRUE;
		case BLOCK_QUOTE_MIT:    return TRUE;
	}
	return FALSE;
}

int Markdown::item_type_slices(int t) {
	switch (t) {
		case PLAIN_MIT:          return TRUE;
		case CODE_MIT:           return TRUE;
		case URI_AUTOLINK_MIT:   return TRUE;
		case EMAIL_AUTOLINK_MIT: return TRUE;
		case INLINE_HTML_MIT:    return TRUE;
		case LINE_BREAK_MIT:     return TRUE;
		case SOFT_BREAK_MIT:     return TRUE;
	}
	return FALSE;
}

int Markdown::item_type_plainish(int t) {
	switch (t) {
		case PLAIN_MIT:          return TRUE;
		case LINE_BREAK_MIT:     return TRUE;
		case SOFT_BREAK_MIT:     return TRUE;
	}
	return FALSE;
}

@h Items.

=
typedef struct markdown_item {
	int type; /* one of the |*_MIT| types above */
	struct text_stream *sliced_from;
	int from;
	int to;
	struct markdown_item *next;
	struct markdown_item *down;
	struct markdown_item *copied_from;
	int whitespace_follows;
	struct text_stream *stashed;
	int details;
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
	md->whitespace_follows = FALSE;
	md->stashed = NULL;
	md->details = 0;
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

@ A "plainish" item contains plain text and/or line breaks:

=
int Markdown::plainish(markdown_item *md) {
	if (md) return Markdown::item_type_plainish(md->type);
	return FALSE;
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

@ This is a convenient adaptation of |Str::get_at| which reads from the slice
inside a markdown node. Note that it is able to see characters outside the
range being sliced: this is intentional and is needed for some of the
delimiter-scanning.

=
wchar_t Markdown::get_at(markdown_item *md, int at) {
	if (md == NULL) return 0;
	if (Str::len(md->sliced_from) == 0) return 0;
	return Str::get_at(md->sliced_from, at);
}

@ Markdown uses backslash as an escape character, with double-backslash meaning
a literal backslash. It follows that if a character is preceded by an odd number
of backslashes, it must be escaped; if an even (including zero) it is unescaped.

This function returns a harmless letter for an escaped active character, so
that it can be used to test for unescaped active characters.

=
wchar_t Markdown::get_unescaped(md_charpos pos, int offset) {
	wchar_t c = Markdown::get_offset(pos, offset);
	int preceding_backslashes = 0;
	while (Markdown::get_offset(pos, offset - 1 - preceding_backslashes) == '\\')
		preceding_backslashes++;
	if (preceding_backslashes % 2 == 1) return 'a';
	return c;
}

@ An "unescaped run" is a sequence of one or more instances of |of|, which
must be non-zero, which are not escaped with a backslash.

=
int Markdown::unescaped_run(md_charpos pos, wchar_t of) {
	int count = 0;
	while (Markdown::get_unescaped(pos, count) == of) count++;
	if (Markdown::get_unescaped(pos, -1) == of) count = 0;
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
		if ((md->type == CODE_MIT) || (md->type == URI_AUTOLINK_MIT) ||
			(md->type == EMAIL_AUTOLINK_MIT) || (md->type == INLINE_HTML_MIT)) {
			for (int i=md->from; i<=md->to; i++) {
				width++;
			}
		}
		if (md->type == LINE_BREAK_MIT) width++;
		if (md->type == SOFT_BREAK_MIT) width++;
		for (markdown_item *c = md->down; c; c = c->next)
			width += Markdown::width(c);
		return width;
	}
	return 0;
}

@ It turns out to be convenient to represent a run of material being worked
on as a linked list of items, and then we want to represent sub-intervals of
that list, which means we need a way to indicate "character position X in item Y".
This is provided by:

=
typedef struct md_charpos {
	struct markdown_item *md;
	int at;
} md_charpos;

@ The equivalent of a null pointer, or an unset marker:

=
md_charpos Markdown::nowhere(void) {
	md_charpos pos;
	pos.md = NULL;
	pos.at = -1;
	return pos;
}

md_charpos Markdown::pos(markdown_item *md, int at) {
	if (md == NULL) return Markdown::nowhere();
	md_charpos pos;
	pos.md = md;
	pos.at = at;
	return pos;
}

int Markdown::somewhere(md_charpos pos) {
	if (pos.md) return TRUE;
	return FALSE;
}

@ This is a rather strict form of equality:

=
int Markdown::pos_eq(md_charpos A, md_charpos B) {
	if ((A.md) && (A.md == B.md) && (A.at == B.at)) return TRUE;
	if ((A.md == NULL) && (B.md == NULL)) return TRUE;
	return FALSE;
}

@ Whereas this is more lax, and reflects the fact that, when surgery
is going on to split items into new items, there can be multiple items which
represent the same piece of text:

=
int Markdown::is_in(md_charpos pos, markdown_item *md) {
	if ((Markdown::somewhere(pos)) && (md)) {
		if ((md->sliced_from) && (md->sliced_from == pos.md->sliced_from) &&
			(pos.at >= md->from) && (pos.at <= md->to)) return TRUE;
	}
	return FALSE;
}

@ "The Left Edge of Nowhere" would make a good pulp 70s sci-fi paperback, but
failing that:

=
md_charpos Markdown::left_edge_of(markdown_item *md) {
	if (md == NULL) return Markdown::nowhere();
	return Markdown::pos(md, md->from);
}

@ To "advance" is to move one character position forward in the linked list
of items. Note that the position must remain in a plainish item at all times,
and this may mean that whole non-plainish items are skipped.

=
md_charpos Markdown::advance(md_charpos pos) {
	if (Markdown::somewhere(pos)) {
		if (pos.at < pos.md->to) { pos.at++; return pos; }
		pos.md = pos.md->next;
		while ((pos.md) && (Markdown::plainish(pos.md) == FALSE)) pos.md = pos.md->next;
		if (pos.md) { pos.at = pos.md->from; return pos; }
	}
	return Markdown::nowhere();
}

@ A more restrictive version halts at the first non-plainish item:

=
md_charpos Markdown::advance_plainish_only(md_charpos pos) {
	if (Markdown::somewhere(pos)) {
		if (pos.at < pos.md->to) { pos.at++; return pos; }
		pos.md = pos.md->next;
		if ((pos.md) && (Markdown::plainish(pos.md))) { pos.at = pos.md->from; return pos; }
	}
	return Markdown::nowhere();
}

@ And these halt at a specific point:

=
md_charpos Markdown::advance_up_to(md_charpos pos, md_charpos end) {
	if ((Markdown::somewhere(end)) &&
		(pos.md->sliced_from == end.md->sliced_from) && (pos.at >= end.at))
		return Markdown::nowhere();
	return Markdown::advance(pos);
}

md_charpos Markdown::advance_up_to_plainish_only(md_charpos pos, md_charpos end) {
	if ((Markdown::somewhere(end)) &&
		(pos.md->sliced_from == end.md->sliced_from) && (pos.at >= end.at))
		return Markdown::nowhere();
	return Markdown::advance_plainish_only(pos);
}

@ The character at a given position:

=
wchar_t Markdown::get(md_charpos pos) {
	return Markdown::get_offset(pos, 0);
}

wchar_t Markdown::get_offset(md_charpos pos, int by) {
	if (Markdown::somewhere(pos)) return Markdown::get_at(pos.md, pos.at + by);
	return 0;
}

void Markdown::put(md_charpos pos, wchar_t c) {
	Markdown::put_offset(pos, 0, c);
}

void Markdown::put_offset(md_charpos pos, int by, wchar_t c) {
	if (Markdown::somewhere(pos)) Str::put_at(pos.md->sliced_from, pos.at + by, c);
}

@ Now for some surgery. We want to take a linked list (the "chain") and cut
it into a left and right hand side, which partition its character positions
exactly. If the cut point does not represent a position in the list, then
the righthand piece will be empty.

We will need two versions of this: in the first, the "cut point" character
becomes the leftmost character of the righthand piece.

=
void Markdown::cut_to_just_before(markdown_item *chain_from, md_charpos cut_point,
	markdown_item **left_segment, markdown_item **right_segment) {
	markdown_item *L = chain_from, *R = NULL;
	if ((chain_from) && (Markdown::somewhere(cut_point))) {
		markdown_item *md, *md_prev = NULL;
		for (md = chain_from; (md) && (Markdown::is_in(cut_point, md) == FALSE);
			md_prev = md, md = md->next) ;
		if (md) {
			if (cut_point.at <= md->from) {
				if (md_prev) md_prev->next = NULL; else L = NULL;
				R = md;
			} else {
				int old_to = md->to;
				md->to = cut_point.at - 1;
				markdown_item *splinter =
					Markdown::new_slice(md->type, md->sliced_from, cut_point.at, old_to);
				splinter->next = md->next;
				md->next = NULL;
				R = splinter;
			}
		}
	}
	if (left_segment) *left_segment = L;
	if (right_segment) *right_segment = R;
}

@ In this version, the "cut point" becomes the rightmost character of the
lefthand piece.

=
void Markdown::cut_to_just_at(markdown_item *chain_from, md_charpos cut_point,
	markdown_item **left_segment, markdown_item **right_segment) {
	markdown_item *L = chain_from, *R = NULL;
	if ((chain_from) && (Markdown::somewhere(cut_point))) {
		markdown_item *md, *md_prev = NULL;
		for (md = chain_from; (md) && (Markdown::is_in(cut_point, md) == FALSE);
			md_prev = md, md = md->next) ;
		if (md) {
			if (cut_point.at >= md->to) {
				R = md->next;
				md->next = NULL;
			} else {
				int old_to = md->to;
				md->to = cut_point.at;
				markdown_item *splinter =
					Markdown::new_slice(md->type, md->sliced_from, cut_point.at + 1, old_to);
				splinter->next = md->next;
				md->next = NULL;
				R = splinter;
			}
		}
	}
	if (left_segment) *left_segment = L;
	if (right_segment) *right_segment = R;
}

@ Combining these, we can cut a chain into three, with the middle part being
the range |A| to |B| inclusive.

=
void Markdown::cut_interval(markdown_item *chain_from, md_charpos A, md_charpos B,
	markdown_item **left_segment, markdown_item **middle_segment, markdown_item **right_segment) {
	markdown_item *interstitial = NULL;
	Markdown::cut_to_just_before(chain_from, A, left_segment, &interstitial);
	Markdown::cut_to_just_at(interstitial, B, &interstitial, right_segment);
	if (middle_segment) *middle_segment = interstitial;
}

@h Debugging.
This prints the internal tree representation of Markdown: none of this code
is needed either for parsing or rendering.

=
void Markdown::debug_char(OUTPUT_STREAM, wchar_t c) {
	switch (c) {
		case 0:    WRITE("NULL"); break;
		case '\n': WRITE("NEWLINE"); break;
		case '\t': WRITE("TAB"); break;
		case ' ':  WRITE("SPACE"); break;
		case 0xA0: WRITE("NONBREAKING-SPACE"); break;
		default:   WRITE("'%c'", c); break;
	}
}

void Markdown::debug_char_briefly(OUTPUT_STREAM, wchar_t c) {
	switch (c) {
		case 0:    WRITE("\\x0000"); break;
		case '\n': WRITE("\\n"); break;
		case '\t': WRITE("\\t"); break;
		case '\\': WRITE("\\\\"); break;
		default:   WRITE("%c", c); break;
	}
}

void Markdown::debug_pos(OUTPUT_STREAM, md_charpos A) {
	if (Markdown::somewhere(A) == FALSE) { WRITE("{nowhere}"); return; }
	WRITE("{");
	Markdown::debug_item(OUT, A.md);
	WRITE(" at %d = ", A.at);
	Markdown::debug_char(OUT, Markdown::get(A));
	WRITE("}");
}

void Markdown::debug_interval(OUTPUT_STREAM, md_charpos A, md_charpos B) {
	if (Markdown::somewhere(A) == FALSE) { WRITE("NONE\n"); return; }
	WRITE("[");
	Markdown::debug_pos(OUT, A);
	WRITE("...");
	Markdown::debug_pos(OUT, B);
	WRITE(" - ");
	for (md_charpos pos = A; Markdown::somewhere(pos); pos = Markdown::advance(pos)) {
		Markdown::debug_char(OUT, Markdown::get(pos));
		if (Markdown::pos_eq(pos, B)) break;
		WRITE(",");
	}
	WRITE("]\n");
}

void Markdown::debug_item(OUTPUT_STREAM, markdown_item *md) {
	if (md == NULL) { WRITE("<no-item>"); return; }
	WRITE("%S-", Markdown::item_type_name(md->type));
	WRITE("M%d", md->id);
	if (md->copied_from) WRITE("<-M%d", md->copied_from->id);
	if (Markdown::item_type_slices(md->type)) {
		WRITE("(%d = '", md->from);
		for (int i = md->from; i <= md->to; i++) {
			Markdown::debug_char_briefly(OUT, Str::get_at(md->sliced_from, i));
		}
		WRITE("' = %d", md->to);
		WRITE(")");
	}
}

@h Trees and chains.
This rather defensively-written code is to print a tree or chain which may be
ill-founded or otherwise damaged. That should never happen, but if things which
should never happen never happened, we wouldn't need to debug.

=
int md_db_cycle_count = 1;

void Markdown::debug_subtree(OUTPUT_STREAM, markdown_item *md) {
	md_db_cycle_count++;
	Markdown::debug_item_r(OUT, md);
}

void Markdown::debug_chain(OUTPUT_STREAM, markdown_item *md) {
	Markdown::debug_chain_label(OUT, md, I"CHAIN");
}

void Markdown::debug_chain_label(OUTPUT_STREAM, markdown_item *md, text_stream *label) {
	md_db_cycle_count++;
	WRITE("%S:\n", label);
	INDENT;
	if (md)
		for (; md; md = md->next) {
			WRITE(" -> ");
			Markdown::debug_item_r(OUT, md);
		}
	else
		WRITE("<none>\n");
	OUTDENT;
}

@ Both of which recursively use:

=
void Markdown::debug_item_r(OUTPUT_STREAM, markdown_item *md) {
	if (md) {
		Markdown::debug_item(OUT, md);
		if (md->cycle_count == md_db_cycle_count) {
			WRITE("AGAIN!\n");
		} else {
			md->cycle_count = md_db_cycle_count;
			WRITE("\n");
			INDENT;
			for (markdown_item *c = md->down; c; c = c->next)
				Markdown::debug_item_r(OUT, c);
			OUTDENT;
		}
	}
}
