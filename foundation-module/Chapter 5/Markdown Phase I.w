[MDBlockParser::] Markdown Phase I.

Phase I of the Markdown parser: reading a series of lines into a tree of
container and leaf blocks.

@h Disclaimer.
Do not call functions in this section directly: use the API in //Markdown//.

@h State.
We now define the state of the Phase I parser preserved between successive
calls to the function |MDBlockParser::add_to_document|.

The most important part is the pair of stacks. The "container stack" holds the
chain of container blocks containing the current write position. For
example, if the words "Sundman traded the Z-Grill for a block of four Inverted
Jennys" appear in a paragraph under a list of notable philately deals, then
the container stack will consist of the |DOCUMENT_MIT| head node (position 0),
then an |UNORDERED_LIST_ITEM_MIT| node (position 1), and the |container_sp|
will be 2. The paragraph item does exist, but is not a container and is not
held on the stack; it will be one of the child nodes (in fact, the last one)
of the |UNORDERED_LIST_ITEM_MIT| node.

The container stack, then, refers to the actual tree, and provides us with a
quick way to access the latest goings-on. The full tree may be very large,
so we wouldn't want to traverse it every time a line came along: that would
have quadratic running time in the number of lines.

The "marker stack" records the notation used to specify this situation.
For example, the line |* > The future King George V paid £1,450 for an unused blue|
contains two "positional marker" notations: the |*| indicates an unordered list
item, the |>| a block quote. Here, then, the marker stack also holds two items.
But because we want the indexing of the two stacks to correspond exactly,
these two items are indexed 1 and 2, not 0 and 1. The hypothetical entry 0
on the marker stack would correspond to saying that the text is to go into
the document as a whole, and that goes without saying, so we do not use entry 0.

This correspondence means that when the line has been acted on, marker 1
(the |*|) leads to container 1 being an |UNORDERED_LIST_ITEM_MIT|, and
marker 2 (the |>|) leads to container 2 being a |BLOCK_QUOTE_MIT|. So at
some points during parsing, the two stacks line up nicely. Nevertheless,
they are not the same, and they have different stack pointers, because
at times one contains more entries than the other.

@ A dirty secret: the code below currently has a hard maximum on the nesting
depth of list items and block quotes. No human will remotely discover this,
and the only consequence of exceeding it is that we won't render block quotes
or list items deeper than that. It wouldn't be too hard to remove this hard
maximum, but it doesn't seem worth it.

@d MAX_MARKDOWN_CONTAINER_DEPTH 128 /* human users rarely exceed 2 */

=
typedef struct md_doc_state {
	struct markdown_variation *variation;
	struct markdown_item *tree_head;
	struct md_links_dictionary *link_references;

	struct markdown_item *containers[MAX_MARKDOWN_CONTAINER_DEPTH];
	int container_sp;

	struct positional_marker markers[MAX_MARKDOWN_CONTAINER_DEPTH];
	int marker_sp;
	int temporary_marker_limit;

	struct markdown_item *receiving_PARAGRAPH;
	struct markdown_item *receiving_CODE_ITEM;
	struct markdown_item *receiving_HTML;
	struct text_stream *blank_matter_after_receiver;

	struct md_fencing_data fencing;

	int HTML_end_condition;

	CLASS_DEFINITION
} md_doc_state;

md_doc_state *MDBlockParser::initialise(markdown_variation *variation,
	markdown_item *head, md_links_dictionary *dict) {
	md_doc_state *state = CREATE(md_doc_state);

	state->variation = variation;
	state->tree_head = head;
	state->link_references = dict;

	@<Initialise the two stacks@>;
	@<Initialise the receiver data@>;

	MDBlockParser::open_block(state, head);
	return state;
}

@<Initialise the two stacks@> =
	state->marker_sp = 0;
	for (int i=0; i < MAX_MARKDOWN_CONTAINER_DEPTH; i++)
		MDBlockParser::clear_marker(&(state->markers[i]));
	MDBlockParser::lift_marker_limit(state);

	state->container_sp = 1;
	for (int i=0; i < MAX_MARKDOWN_CONTAINER_DEPTH; i++) state->containers[i] = NULL;
	state->containers[0] = head;

@<Initialise the receiver data@> =
	state->receiving_PARAGRAPH = NULL;
	state->receiving_CODE_ITEM = NULL;
	state->receiving_HTML = NULL;
	state->blank_matter_after_receiver = Str::new();

	MDBlockParser::clear_fencing_data(state);
	MDBlockParser::clear_HTML_data(state);

@h Receivers.
A "receiver" is a block into which actual copy, that is, text, is poured. In
theory that would include headings, but headings are created by converting
them from paragraphs, so they are not included here: thus, there are just three.

We can never have two different paragraphs both being receivers at the same
time, and so on, but it is possible for both a paragraph and a code block
to be receivers simultaneously during parsing (for reasons to do with lazy
continuation and blank lines). So although it is tempting to have just a
single variable, "the current receiver item", we can't do that.

=
markdown_item *MDBlockParser::latest_paragraph(md_doc_state *state) {
	return state->receiving_PARAGRAPH;
}

markdown_item *MDBlockParser::latest_HTML_block(md_doc_state *state) {
	return state->receiving_HTML;
}

markdown_item *MDBlockParser::latest_code_block(md_doc_state *state) {
	return state->receiving_CODE_ITEM;
}
markdown_item *MDBlockParser::latest_receiver(md_doc_state *state, int type) {
	switch (type) {
		case PARAGRAPH_MIT: return state->receiving_PARAGRAPH;
		case CODE_BLOCK_MIT: return state->receiving_CODE_ITEM;
		case HTML_MIT: return state->receiving_HTML;
	}
	return NULL;
}

@ These functions make a block a receiver, or make it stop being one.

=
void MDBlockParser::make_receiver(md_doc_state *state, markdown_item *block) {
	if (block) {
		switch (block->type) {
			case PARAGRAPH_MIT:  state->receiving_PARAGRAPH = block; break;
			case CODE_BLOCK_MIT: state->receiving_CODE_ITEM = block; break;
			case HTML_MIT:       state->receiving_HTML = block; break;
		}
	}
	Str::clear(state->blank_matter_after_receiver);
}

void MDBlockParser::remove_receiver(md_doc_state *state, markdown_item *block) {
	if (block) {
		switch (block->type) {
			case PARAGRAPH_MIT:  state->receiving_PARAGRAPH = NULL; break;
			case CODE_BLOCK_MIT: state->receiving_CODE_ITEM = NULL; break;
			case HTML_MIT:       state->receiving_HTML = NULL; break;
		}
	}
}

@ "Fencing", in the sense of gardens not sword-fighting, happens when a 
fenced code block is being parsed. This requires quite a bit of extra state,
since we are not allowed to match a fence |~~~| with a fence |````|, and so on.
The width of the fence is the number of characters used in its opening, so
for example 3 for |~~~|.

Note that |fencing_material| is always 0 when we are not parsing a fenced
code block.

The "left margin" is measured in character positions (not string index points)
and is the number of characters by which the fenced code block is indented,
when this is required. (This happens sometimes when fenced code blocks occur
inside list items, for example.)

=
typedef struct md_fencing_data {
	wchar_t material; /* character used in the fence syntax */
	int width;
	struct markdown_item *fenced_code;
	int left_margin; /* measured as a position, not a string index */
} md_fencing_data;

void MDBlockParser::clear_fencing_data(md_doc_state *state) {
	state->fencing.material = 0;
	state->fencing.width = 0;
	state->fencing.fenced_code = NULL;
	state->fencing.left_margin = -1; /* meaning "none" */
}

@ Similarly, HTML blocks have closing syntax which depends on their opening
syntax, so we need to remember some state when parsing those, too.

=
void MDBlockParser::clear_HTML_data(md_doc_state *state) {
	state->HTML_end_condition = 0;
}

@h Markers.
Markers can survive from one line to the next, and indeed this is essential.
Consider the sequence
= (text)
	* Victorian stamps
	  - Penny Black
	* Edwardian stamps
=
Three positional markers are obvious in this text, but in fact there's a fourth
implicit one. The line |  - Penny Black| implicitly marks itself as being a subentry
of the outer entry, as if a ghostly asterisk were hiding behind the opening spacing.
In this case, we will parse that by preserving the marker from the previous line,
but flagging it as |continues_from_earlier_line|.

Note that block quote markers are never flagged as continuing, because they work
differently: instead of being implicitly continued, block quotes are explicitly so.
= (text)
	> This is all part of
	> the same block quote.
=

The |blank_counts| keeps track of how many blank lines follow, and is needed only
because of the special rule that a list item cannot begin with two blank lines.

=
typedef struct positional_marker {
	int item_type; /* |BLOCK_QUOTE_MIT|, |ORDERED_LIST_ITEM_MIT| or |UNORDERED_LIST_ITEM_MIT| */
	int indent;                /* minimum required indentation for subsequent lines to continue */
	int at;                    /* character position (not string index) of the start of the marker */
	int width;                 /* for example, 2 for |7) | or |7. |: the non-whitespace chars only */
	int list_item_value;       /* for example, 7 for |7) | or |7. | */
	wchar_t list_item_flavour; /* for example, |')'| for |7) | and |'.'| for |7. | */

	int continues_from_earlier_line;
	int blank_counts;
} positional_marker;

void MDBlockParser::clear_marker(positional_marker *marker) {
	marker->item_type = 0; /* which is not a valid item type: this will never be used */
	marker->width = 0;
	marker->indent = 0;
	marker->at = 0;
	marker->continues_from_earlier_line = FALSE;
	marker->list_item_value = 0;
	marker->list_item_flavour = 0;
	marker->blank_counts = 0;
}

@ Ordinarily, we can parse markers to our heart's content, or at least up to
|MAX_MARKDOWN_CONTAINER_DEPTH| of them. But sometimes we mustn't. Consider:
= (text)
	```
	> * 1) Whatever
	```
=
This is a fenced code block, so the tantalising string of potential markers,
|> * 1)|, is in fact part of the code being fenced. We need to prevent that,
so during the parsing of lines in such a block, the following limit is
imposed on the number of markers we are allowed to parse. (In this example, 0.)

=
void MDBlockParser::impose_marker_limit(md_doc_state *state, int limit) {
	state->temporary_marker_limit = limit;
}

void MDBlockParser::lift_marker_limit(md_doc_state *state) {
	state->temporary_marker_limit = 100000000;
}

@ The marker stack is only in some ways a stack: we have access at any time
to the markers at each level. Here, we put a new blank marker in place at
level |position|: remember that this counts from 1, not from 0.

=
positional_marker *MDBlockParser::new_marker_at(md_doc_state *state, int position, int type) {
	if ((type != BLOCK_QUOTE_MIT) &&
		(type != UNORDERED_LIST_ITEM_MIT) && (type != ORDERED_LIST_ITEM_MIT))
		internal_error("bad type for marker stack");
	if ((position <= 0) || (position >= MAX_MARKDOWN_CONTAINER_DEPTH))
		internal_error("marker out of range");
	positional_marker *marker = &(state->markers[position]);
	MDBlockParser::clear_marker(marker);
	marker->item_type = type;
	return marker;
}

@ And this gives access to the marker at any level.

=
positional_marker *MDBlockParser::marker_at(md_doc_state *state, int position) {
	if ((position <= 0) || (position >= MAX_MARKDOWN_CONTAINER_DEPTH)) return NULL;
	positional_marker *marker = &(state->markers[position]);
	if (marker->item_type == 0) return NULL;
	return marker;
}

@ Inevitably, more notation:

=
void MDBlockParser::debug_positional_stack(OUTPUT_STREAM,
	md_doc_state *state) {
	for (int i=1; i<MAX_MARKDOWN_CONTAINER_DEPTH; i++) {
		if (i == state->marker_sp) WRITE("[top] ");
		if ((i > state->marker_sp) && (state->markers[i].item_type == 0)) break;
		MDBlockParser::debug_marker(OUT, &(state->markers[i]), (i == state->marker_sp-1)?TRUE:FALSE);
	}
	if (state->marker_sp == 0) WRITE("empty");
	WRITE("\n");
}

void MDBlockParser::debug_marker(OUTPUT_STREAM, positional_marker *marker, int in_full) {
	if (marker == NULL) { WRITE("<no-marker>"); return; }
	if (marker->continues_from_earlier_line) WRITE("continuing:");
	switch (marker->item_type) {
		case BLOCK_QUOTE_MIT:         WRITE("> "); break;
		case UNORDERED_LIST_ITEM_MIT: WRITE("(%c) ", marker->list_item_flavour); break;
		case ORDERED_LIST_ITEM_MIT:   WRITE("%d%c ",
										marker->list_item_value, marker->list_item_flavour);
									  break;
		default: WRITE("<invalid-marker>"); break;
	}
	if (in_full) {
		WRITE("[at=%d] ", marker->at);
		WRITE("[min-indent=%d] ", marker->indent);
		if (marker->blank_counts) WRITE("[blanks=%d] ", marker->blank_counts);
	}
}

@ Let's finally do some actual parsing. Block quote markers are very simple:
they are just |>| signs. The following function indicates success by advancing
the read position, and failure by not doing so.

=
tabbed_string_iterator MDBlockParser::block_quote_marker(tabbed_string_iterator line_scanner) {
	if (TabbedStr::get_character(&line_scanner) != '>') return line_scanner;
	TabbedStr::advance(&line_scanner);
	return line_scanner;
}

@ Bullet list markers are |-|, |+| or |*|, this character being the "flavour".

=
tabbed_string_iterator MDBlockParser::bullet_list_marker(tabbed_string_iterator line_scanner,
	wchar_t *flavour) {
	tabbed_string_iterator old = line_scanner;
	if (MDBlockParser::thematic_marker(line_scanner.line, TabbedStr::get_index(&line_scanner))) return old;
	wchar_t c = TabbedStr::get_character(&line_scanner);
	if ((c == '-') || (c == '+') || (c == '*')) {
		TabbedStr::advance(&line_scanner);
		*flavour = c;
	}
	return line_scanner;
}

@ Ordered list markers are |N)| or |N.|, with the terminal character being the
flavour once more, and |N| being a string of up to 9 decimal digits. These
can include leading zeros, but not minus signs, and can only be in decimal.
They are in fact almost entirely thrown away as information, as we'll see
when we get to rendering, but we parse them anyway.

=
tabbed_string_iterator MDBlockParser::ordered_list_marker(tabbed_string_iterator line_scanner,
	int *v, wchar_t *flavour) {
	tabbed_string_iterator old = line_scanner;
	if (MDBlockParser::thematic_marker(line_scanner.line,
		TabbedStr::get_index(&line_scanner))) return old;
	wchar_t c = TabbedStr::get_character(&line_scanner);
	int dc = 0, val = 0;
	while (Characters::is_ASCII_digit(c)) {
		val = 10*val + (int) (c - '0');
		TabbedStr::advance(&line_scanner); dc++;
		c = TabbedStr::get_character(&line_scanner);
	}
	if ((dc < 1) || (dc > 9)) return old;
	c = TabbedStr::get_character(&line_scanner);
	if ((c == '.') || (c == ')')) {
		*flavour = c;
		*v = val;
		TabbedStr::advance(&line_scanner);
		return line_scanner;
	}
	return old;
}

@ A line which can be interpreted as a thematic break is never a list item,
so we need to parse those too. These always occur after the early phase in
which tabs count as spaces, so we no longer use a |tabbed_string_iterator|
here. The function returns either true or false.

=
int MDBlockParser::thematic_marker(text_stream *line, int index) {
	wchar_t c = Str::get_at(line, index);
	if ((c == '-') || (c == '_') || (c == '*')) {
		int ornament_count = 1;
		for (int j=index+1; j<Str::len(line); j++) {
			wchar_t d = Str::get_at(line, j);
			if (d == c) {
				if (ornament_count > 0) ornament_count++;
			} else {
				if ((d != ' ') && (d != '\t')) ornament_count = 0;
			}
		}
		if (ornament_count >= 3) return TRUE;
	}
	return FALSE;
}

@ So now we're ready for the main function which parses the prefix to a line,
moving the scanner past the sequence of positional markers which appear to be
present. Note that we observe any temporary marker limit, and that in the
remote contingency of |MAX_MARKDOWN_CONTAINER_DEPTH| being reached (e.g. if
somebody's cat stood on the "greater than" button when they weren't looking),
we simply ignore markers beyond that point.

On exit, the return value is the positional stack pointer, i.e., is the number
of markers read plus 1, and the line scanner has moved past each marker. If no
markers are found, the return value is 1 and the scanner has not moved.

The "left margin" is the width, in character positions, of any run of white
space at the start of the line. The first marker, if there is one, will
therefore begin at this character position.

=
int MDBlockParser::parse_positional_markers(md_doc_state *state, tabbed_string_iterator *line_scanner) {
	int sp = 1; /* next positional stack position to store into */
	
	int left_margin = TabbedStr::spaces_available(line_scanner);

	while (TRUE) {
		if (sp >= MAX_MARKDOWN_CONTAINER_DEPTH) break;
		if (sp >= state->temporary_marker_limit) break;

		tabbed_string_iterator rewind_point = *line_scanner;

		int interrupts_paragraph = FALSE;
		if (MDBlockParser::latest_paragraph(state)) interrupts_paragraph = TRUE;
		if ((sp < state->container_sp) &&
			((state->containers[sp]->type == UNORDERED_LIST_ITEM_MIT) ||
				(state->containers[sp]->type == ORDERED_LIST_ITEM_MIT)))
			interrupts_paragraph = FALSE;
	
		int available = TabbedStr::spaces_available(line_scanner);
		@<Is there enough space here to be able to infer a continuation of a marker?@>;
		@<Is there an explicit marker here?@>;
		break;
	}
	return sp;
}

@ Suppose we see these two lines in succession:
= (text)
	2)   This is list entry two.
	     It continues here.
=
The second line implies a continuation of the first because of the indentation
by five spaces, which is the |width| recorded in marker 1 (i.e., the |2)|)
recorded on line 1.

If we're in that position, we retain the marker from last time around, but
flag it as a continuation. (If we didn't, we would create a second list entry
also numbered |2)|.)

@<Is there enough space here to be able to infer a continuation of a marker?@> =
	positional_marker *marker = MDBlockParser::marker_at(state, sp);
	if ((sp < state->marker_sp) && (marker) && (marker->item_type != BLOCK_QUOTE_MIT) &&
		((TabbedStr::blank_from_here(line_scanner)) || (available >= marker->indent))) {
			TabbedStr::eat_spaces(state->markers[sp].indent, line_scanner);
			marker->continues_from_earlier_line = TRUE;
			sp++;
			continue;
	}

@ If there are more than four spaces, we have indented far enough to make this
a code block, so that any punctuation like |17.| that we see past that point
would be part of the quoted code, not a marker.

@<Is there an explicit marker here?@> =
	if (available < 4) {
		TabbedStr::eat_spaces(available, line_scanner);
		tabbed_string_iterator starts_at = *line_scanner;
		@<Is there a block quote marker here?@>;
		@<Is there a bullet list marker here?@>;
		@<Is there an ordered list marker here?@>;
		*line_scanner = rewind_point;
	}

@ The "black width" of a marker is the width in characters of the actual
non-spaces used to express it: so, |153. This is item 153.| has black width 3.
The "white width" is the black width plus the position width of any required
white spacing which follows. For block quote markers, no such spacing is
required - |>> This is a legal double block quote| - and so the white width
is the same as the black width.

@<Is there a block quote marker here?@> =
	tabbed_string_iterator adv = MDBlockParser::block_quote_marker(starts_at);
	int black_width = TabbedStr::get_position(&adv) - TabbedStr::get_position(line_scanner);
	if (black_width > 0) {
		TabbedStr::eat_space(&adv);
		int white_width = black_width;
		*line_scanner = adv;
		positional_marker *bq_m = MDBlockParser::new_marker_at(state, sp, BLOCK_QUOTE_MIT);
		bq_m->width = black_width;
		bq_m->at = TabbedStr::get_position(&starts_at);
		bq_m->indent = white_width + TabbedStr::spaces_available(line_scanner);
		if (sp == 1) bq_m->indent += left_margin;
		sp++;
		continue;
	}
	
@ Bullet list markers are not allowed to interrupt a paragraph going on from
the previous line: or rather, they are read as regular text if they do.

Bullets are recognised only as such if they occur at the end of the line, or
are followed by a single space. In the first case the white width equals the
black width, in the second case it is the black width plus 1.

@<Is there a bullet list marker here?@> =
	wchar_t flavour = 0;
	tabbed_string_iterator adv = MDBlockParser::bullet_list_marker(starts_at, &flavour);
	int black_width = TabbedStr::get_position(&adv) - TabbedStr::get_position(line_scanner);
	if (black_width > 0) {
		wchar_t next = TabbedStr::get_character(&adv);
		if ((next == ' ') || (next == 0)) {
			TabbedStr::eat_space(&adv);
			int white_width = TabbedStr::get_position(&adv) - TabbedStr::get_position(line_scanner);
			*line_scanner = adv;
			if ((TabbedStr::blank_from_here(line_scanner)) && (interrupts_paragraph)) {
				*line_scanner = rewind_point;
			} else {
				positional_marker *li_m =
					MDBlockParser::new_marker_at(state, sp, UNORDERED_LIST_ITEM_MIT);
				li_m->width = black_width;
				li_m->at = TabbedStr::get_position(&starts_at);
				li_m->indent = white_width + TabbedStr::spaces_available(line_scanner);
				if (sp == 1) li_m->indent += left_margin;
				li_m->list_item_flavour = flavour;
				sp++;
				continue;
			}
		}
	}

@ Ordered list markers are allowed to interrupt a paragraph, but only if the
number used in them is 1, so that there's some evidence the author intended a
list and hasn't simply written something like:
= (text)
	The Royal Philatelic Society London was founded on 10 April
	1869. Permission to use the prefix "Royal" was granted by King
	Edward VII in November 1906.
=
where we don't want to parse the |1869.| as beginning a list with first
entry "Permission to use...".

@<Is there an ordered list marker here?@> =
	wchar_t flavour = 0;
	int val = 0;
	tabbed_string_iterator adv = MDBlockParser::ordered_list_marker(starts_at, &val, &flavour);
	int black_width = TabbedStr::get_position(&adv) - TabbedStr::get_position(line_scanner);
	if (black_width > 0) {
		wchar_t next = TabbedStr::get_character(&adv);
		if ((next == ' ') || (next == 0)) {
			TabbedStr::eat_space(&adv);
			int white_width = TabbedStr::get_position(&adv) - TabbedStr::get_position(line_scanner);
			*line_scanner = adv;
			if (((TabbedStr::blank_from_here(line_scanner)) || (val != 1)) && (interrupts_paragraph)) {
				*line_scanner = rewind_point;
			} else {
				positional_marker *li_m =
					MDBlockParser::new_marker_at(state, sp, ORDERED_LIST_ITEM_MIT);
				li_m->width = black_width;
				li_m->at = TabbedStr::get_position(&starts_at);
				li_m->indent = white_width + TabbedStr::spaces_available(line_scanner);
				if (sp == 1) li_m->indent += left_margin;
				li_m->list_item_flavour = flavour;
				li_m->list_item_value = val;
				sp++;
				continue;
			}
		}
	}

@ It's convenient to provide a quick way to test if the innermost marker is
for a list entry which is new this time around (i.e., not a continuation).

=
positional_marker *MDBlockParser::innermost_marker(md_doc_state *state) {
	if (state->marker_sp == 1) return NULL;
	return MDBlockParser::marker_at(state, state->marker_sp - 1);
}

int MDBlockParser::marker_is_list_entry(positional_marker *marker) {
	if ((marker) &&
		((marker->item_type == ORDERED_LIST_ITEM_MIT) ||
			(marker->item_type == UNORDERED_LIST_ITEM_MIT)))
		return TRUE;
	return FALSE;
}

int MDBlockParser::marker_is_new_list_entry(positional_marker *marker) {
	if ((MDBlockParser::marker_is_list_entry(marker)) &&
		(marker->continues_from_earlier_line == FALSE))
		return TRUE;
	return FALSE;
}

@h Containers.
Enough on markers: we also need some preparatory work on container and leaf blocks.

A block can occasionally change type. For example, a |PARAGRAPH_MIT| may turn
out to be a heading after all because of a subsequent setext underline, and then
it must become a |HEADING_MIT|. We do this carefully to avoid getting the
receiver states cross-wired.

=
void MDBlockParser::change_type(md_doc_state *state, markdown_item *block, int t) {
	if (block == NULL) internal_error("no block");
	if (tracing_Markdown_parser) {
		PRINT("Change type: "); Markdown::debug_item(STDOUT, block);
	}
	if (block->open) MDBlockParser::remove_receiver(state, block);
	block->type = t;
	if (block->open) MDBlockParser::make_receiver(state, block);
	if (tracing_Markdown_parser) {
		PRINT(" -> "); Markdown::debug_item(STDOUT, block); PRINT("\n");
	}
}

@ This marks a block as being followed by white space line(s) in the context
of its own container. Tracking this is annoying, but we need it in order to
determine whether lists are loose or tight when rendering.

=
void MDBlockParser::mark_block_with_ws(md_doc_state *state, markdown_item *block) {
	if (block) {
		if (tracing_Markdown_parser) {
			PRINT("Mark as whitespace-following: "); Markdown::debug_item(STDOUT, block);
		}
		block->whitespace_follows = TRUE;
	}
}

@ We have a not-very-important concept of blocks being open or closed. Only
leaf and container blocks can meaningfully be opened: for other items, |block->open|
will remain |NOT_APPLICABLE|. A block can be opened only once, and closed only
once, and it can only be closed after it has been opened.

=
void MDBlockParser::open_block(md_doc_state *state, markdown_item *block) {
	if (block->open == NOT_APPLICABLE) {
		block->open = TRUE;
		MDBlockParser::close_block(state, MDBlockParser::latest_receiver(state, block->type));
		MDBlockParser::make_receiver(state, block);
	}
}

void MDBlockParser::close_block(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	if (at->open != TRUE) return;
	if (tracing_Markdown_parser) {
		PRINT("Closing: "); Markdown::debug_item(STDOUT, at); PRINT("\n");
		STREAM_INDENT(STDOUT);
	}
	at->open = FALSE;
	for (markdown_item *ch = at->down; ch; ch = ch->next)
		MDBlockParser::close_block(state, ch);
	if (tracing_Markdown_parser) {
		STREAM_OUTDENT(STDOUT);
	}
	MDBlockParser::remove_receiver(state, at);
	MDBlockParser::remove_link_references(state, at);
}

@ So when are blocks opened? We've already seen that the |DOCUMENT_MIT| block
is opened right at the start. As we will later see, container blocks are
opened when they are created. And the following function opens a new leaf
block and joins it to the tree:

=
void MDBlockParser::turn_over_a_new_leaf(md_doc_state *state, markdown_item *block) {
	MDBlockParser::open_block(state, block);
	Markdown::add_to(block, state->containers[state->container_sp-1]);
}

@h Comparing the two stacks.
As we shall see, it's going to be essential when deciding on lazy continuation
to see if the markers currently in place would cause a change in the container
stack.

=
int MDBlockParser::container_will_change(md_doc_state *state) {
	if (state->marker_sp > state->container_sp) return TRUE;
	for (int sp = 1; sp<state->marker_sp; sp++) {
		positional_marker *marker = MDBlockParser::marker_at(state, sp);
		if (marker->item_type != state->containers[sp]->type) return TRUE;
		if (MDBlockParser::marker_is_new_list_entry(marker)) return TRUE;
	}
	return FALSE;
}

@h The main function.
So, now we're off to the races. Unsurprisingly, we work from left to right.
We divide the line into four sections: left margin, positional markers,
intervening white space, and content. For example:
= (text)
	  -  21)   Thomas Keay Tapling (1855-1891) was an English politician.
	mmpppppppppcccccccccccccccccccccccccccc
	              He played first-class cricket and was also an eminent philatelist
	mmpppppppppwwwccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
=
Note that the intervening white space, if any, is the bonus white space beyond
any which is used to imply positional markers.

CommonMark requires that tabs are to be read as if spaces had been typed to
achieve the same effect as tabbed intervals of four spaces, but only for
purposes of determining block structure. So we parse with a tab-respecting
line scanner up to the beginning of the content, and then throw that away and
use regular string processing thereafter.

=
void MDBlockParser::add_to_document(md_doc_state *state, text_stream *line) {
	if (tracing_Markdown_parser) {
		PRINT("=======\nAdding '%S' to tree:\n", line);
		Markdown::debug_subtree(STDOUT, state->tree_head);
		PRINT("Positional stack carried over: ");
		MDBlockParser::debug_positional_stack(STDOUT, state);
		if (state->temporary_marker_limit < 100000000)
			PRINT("(Marker limit %d is in force)", state->temporary_marker_limit);
	}

	int marker_sp_left_over_from_last_line = state->marker_sp;

	tabbed_string_iterator line_scanner = TabbedStr::new(line, 4);
	@<Parse the left margin and the positional markers@>;

	int indentation = FALSE;
	@<Parse the white space between the markers and the content@>;

	if (tracing_Markdown_parser) {
		PRINT("Line '%S' ", line);
		PRINT("\n");
		PRINT("New positional stack: ");
		MDBlockParser::debug_positional_stack(STDOUT, state);
	}

	@<Parse the content@>;
}

@<Parse the left margin and the positional markers@> =
	state->marker_sp = MDBlockParser::parse_positional_markers(state, &line_scanner);

@<Parse the white space between the markers and the content@> =
	ReparseIntervening: ;
	positional_marker *innermost = MDBlockParser::innermost_marker(state);
	@<If the line is blank from here on, some of it may still be content@>;

	int intervening_space_width = TabbedStr::spaces_available(&line_scanner);
	
	if (intervening_space_width >= 4)
		@<This line is indented enough to be part of an indented code block@>;

	if (TabbedStr::blank_from_here(&line_scanner)) {
		if (MDBlockParser::marker_is_new_list_entry(innermost))
			@<This line will open a list item with no content as yet@>
		else if (MDBlockParser::marker_is_list_entry(innermost))
			@<But a list item cannot begin with two empty lines@>;
	}

	TabbedStr::eat_spaces(intervening_space_width, &line_scanner);

@ If the line contains only white space after the positional markers, that
does not necessarily mean there is no content. Consider:
= (text)
	12)  ~~~
	     This is a fenced code block.
	         
	     ~~~
=
Line 3 here contains an (implied) positional marker, since it's still part
of list item 12, but any white space occurring from the character position
underneath the |T| onwards is part of the content, and must live on in the
code block. We deal with this by moving the read position of the line
scanner (which is currently at the end of the line, wherever that is)
back to the |T| position.

@<If the line is blank from here on, some of it may still be content@> =
	if (TabbedStr::blank_from_here(&line_scanner))
		if ((innermost) && (innermost->continues_from_earlier_line))
			TabbedStr::seek(&line_scanner, innermost->at + innermost->indent);

@ Four or more spaces suggests indented code. If so, we want to consider
the intervening space as containing exactly four spaces (in position terms),
with any extras being part of the content. That requires us to set the
indentation level of a newly opening list item accordingly, so that on
subsequent lines the same margin will be followed.

@<This line is indented enough to be part of an indented code block@> =
	indentation = TRUE; intervening_space_width = 4;
	if (MDBlockParser::marker_is_new_list_entry(innermost)) {
		if (tracing_Markdown_parser) {
			PRINT("Opening line is code rule applies, and sets pos indent[%d] = %d\n",
				state->marker_sp, innermost->width + 1);
		}
		innermost->indent = innermost->width + 1;
	}

@ Suppose something like this:
= (text)
	12)
=
where there is not enough white space after the |)| to force indentation as a
new indented code block (i.e., of which the first line happens to be blank).
Where are we to set the indentation position for the |12)|? We make it the
absolute minimum: the black width plus 1.

@<This line will open a list item with no content as yet@> =
	if (tracing_Markdown_parser) {
		PRINT("Opening line is empty rule applies, and sets pos indent[%d] = %d\n",
			state->marker_sp, innermost->width + 1);
	}
	innermost->indent = innermost->width + 1;
	innermost->blank_counts = 1;

@ A list item is not permitted to begin with two blanks:
= (text)
	11)	
	    This is part of list item 11.

	12)
	
	    This is not part of list item 12.
=
So if we find ourselves in the situation of the blank line 5, we delete the
innermost marker, and go back to the start of the intervening space parsing,
because there's a new innermost marker now, and indentation also needs
reconsideration. 

Note that we also have to mark the list item not being continued as being
followed by white space.

@<But a list item cannot begin with two empty lines@> =
	if (innermost->blank_counts > 0) {
		if (tracing_Markdown_parser) {
			PRINT("Blank after blank opening rule applies\n");
		}
		MDBlockParser::mark_block_with_ws(state, state->containers[state->marker_sp-1]);
		state->marker_sp--;
		goto ReparseIntervening;
	}

@ We finally reach the content, and move from tab-respecting-parsing with a
scanner to regular character-by-character parsing. |content_index| is the
index position of the line at which content begins. There's actually a
tricky edge case here if we're in a code block where the content opens
with white space: we could find ourselves with the line scanner still midway
through a not-fully-consumed tab character. Infuriatingly, it is only
compliant with CommonMark to deal with this situation (by injecting additional
space characters not found in |line|) in certain cases, so for now we have
to live with this uneasy worry.

@<Parse the content@> =
	int content_index = TabbedStr::get_index(&line_scanner);
	
	if (tracing_Markdown_parser) {
		if (indentation) PRINT("Indentation present. ");
		PRINT("Content: '");
		for (int i=content_index; i<Str::len(line); i++)
			Markdown::debug_char_briefly(STDOUT, Str::get_at(line, i));
		PRINT("'\n");
	}

	int interpretations[NO_MDINTERPRETATIONS], details[NO_MDINTERPRETATIONS];
	@<Work out the possible interpretations of this content@>;

	if (interpretations[LAZY_CONTINUATION_MDINTERPRETATION])
		@<This is a lazy continuation@>
	else
		@<This is not a lazy continuation@>;

@ "Interpretations" are possible ways to understand the context, and some
lines are open to multiple interpretations. We need to find all possible ways
because CommonMark requires us to consider lazy continuation only when no other
interpretation is possible.

@<Work out the possible interpretations of this content@> =
	for (int which=0; which<NO_MDINTERPRETATIONS; which++)
		interpretations[which] =
			MDBlockParser::can_interpret_as(state, line, indentation, content_index,
				which, NULL, &(details[which]));
	@<Is this a lazy continuation?@>;

	if (tracing_Markdown_parser) {
		PRINT("interpretations: ");
		int c = 0;
		for (int which=0; which<NO_MDINTERPRETATIONS; which++) {
			if (interpretations[which]) {
				c++;
				switch (which) {
					case WHITESPACE_MDINTERPRETATION:        PRINT("white? "); break;
					case THEMATIC_MDINTERPRETATION:          PRINT("thematic? "); break;
					case ATX_HEADING_MDINTERPRETATION:       PRINT("atx? "); break;
					case SETEXT_UNDERLINE_MDINTERPRETATION:  PRINT("setext? "); break;
					case HTML_MDINTERPRETATION:              PRINT("html-open? "); break;
					case CODE_FENCE_OPEN_MDINTERPRETATION:   PRINT("fence-open? "); break;
					case CODE_FENCE_CLOSE_MDINTERPRETATION:  PRINT("fence-close? "); break;
					case CODE_BLOCK_MDINTERPRETATION:        PRINT("code? "); break;
					case FENCED_CODE_BLOCK_MDINTERPRETATION: PRINT("fenced-code? "); break;
					case LAZY_CONTINUATION_MDINTERPRETATION: PRINT("lazy-continuation? "); break;
					case HTML_CONTINUATION_MDINTERPRETATION: PRINT("html-continuation? "); break;
				}
			}
		}
		if (c == 0) PRINT("(none)");
		PRINT("\n");
		if (MDBlockParser::container_will_change(state)) PRINT("Container change coming\n");
	}

@ This is a little subtle. It seems obvious enough that these lines all belong
to the same paragraph:
= (text)
	By 1887 his collection was second only to that of Philippe Ferrari de La
	Renotière. Among his holdings were many world-famous rarities, including both
	values of the "Post Office" Mauritius and three examples of the Inverted
	Head Four Annas of India.
=
But "lazy continuation" goes further. It provides that if there is no indication
to the contrary, a line should be taken as a continuation of the current paragraph.
So for example:
= (text)
	1) By 1887 his collection was second only to that of Philippe Ferrari de La
	Renotière. Among...
=
Here, all of the lines are part of list entry |1)|. This is a different situation
from:
= (text)
	1) By 1887 his collection was second only to that of Philippe Ferrari de La
	   Renotière. Among...
=
where continuation occurs because the subsequent lines are indented to match
the list item marker's margin. The difference between these two cases is that
in the second case there is a continuing positional marker on the marker stack,
whereas in the first case there is not, since indentation was insufficient
for that.

The short version is that lines are LCs only if no other interpretation is
possible, but setext underlinings and certain kinds of raw HTML opening (but
not others) are exceptions to this. Because setext underlinings can be
syntactically identical to thematic division lines, we also have to ensure
that a thematic interpretation of that sort does not veto lazy continuation.
CommonMark requires close study here.

Note also that any requirement in the markers to create new list entries or
block quotes is enough to veto LC (this is what |MDBlockParser::container_will_change|
is testing for), and of course, there has to be a paragraph going on or else
there is nothing to continue.

@<Is this a lazy continuation?@> =
	if ((MDBlockParser::latest_paragraph(state)) &&
		(MDBlockParser::container_will_change(state) == FALSE)) {
		int lazy = TRUE;
		if ((interpretations[SETEXT_UNDERLINE_MDINTERPRETATION]) &&
			(state->marker_sp == state->container_sp))
			interpretations[THEMATIC_MDINTERPRETATION] = FALSE;
		for (int which=0; which<NO_MDINTERPRETATIONS; which++)
			if (interpretations[which]) {
				if (which == SETEXT_UNDERLINE_MDINTERPRETATION) continue;
				if ((which == HTML_MDINTERPRETATION) &&
					(details[which] == MISCPAIR_MDHTMLC)) continue;
				lazy = FALSE;
			}
		interpretations[LAZY_CONTINUATION_MDINTERPRETATION] = lazy;
	}
	if (interpretations[LAZY_CONTINUATION_MDINTERPRETATION] == FALSE)
		interpretations[SETEXT_UNDERLINE_MDINTERPRETATION] = FALSE;

@ As noted above, what's lazy about lazy continuation is that the markers were
not fully specified to match the containers, so that |marker_sp| is below
|container_sp|. But the markers from last time are still there on the stack,
so to retrieve them, all we have to do is raise |marker_sp| back to where it was.

As for the content, it's either paragraph copy or else a setext underline, but
can only be the latter if the alignment is right.

@<This is a lazy continuation@> =
	int sp = state->marker_sp;
	state->marker_sp = marker_sp_left_over_from_last_line;

	if ((sp == state->container_sp) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION]))
		@<Line is a setext underline and turns the existing paragraph into a heading@>;
	@<Line continues an existing paragraph@>;

@ With a sigh of relief, we're not in the lazy case here, and so the markers
are a true representation of what the containers ought to be. Since we're
not continuing a paragraph, it's now time to close any existing one, as it
can never be continued again.

The sequence of the interpretation tests is important here, as it decides
which take priority: for example, a blank line occurring inside HTML is
not white space and must be given the |HTML_CONTINUATION_MDINTERPRETATION|.
Each of the 10 possible outcomes below ends with a |return| from the function,
so exactly one will take effect.

@<This is not a lazy continuation@> =
	if (MDBlockParser::latest_paragraph(state))
		MDBlockParser::close_block(state, MDBlockParser::latest_paragraph(state));
	if ((MDBlockParser::latest_code_block(state)) &&
		(interpretations[CODE_BLOCK_MDINTERPRETATION] == FALSE) &&
		(interpretations[WHITESPACE_MDINTERPRETATION] == FALSE))
		MDBlockParser::close_block(state, MDBlockParser::latest_code_block(state));

	@<Make the container stack agree with the markers stack@>;

	if (interpretations[HTML_CONTINUATION_MDINTERPRETATION]) @<Line is part of HTML@>;
	if (interpretations[CODE_FENCE_OPEN_MDINTERPRETATION])   @<Line is an opening code fence@>;
	if (interpretations[CODE_FENCE_CLOSE_MDINTERPRETATION])  @<Line is a closing code fence@>;
	if (interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION]) @<Line is part of a fenced code block@>;
	if (interpretations[WHITESPACE_MDINTERPRETATION])        @<Line is whitespace@>;
	if (interpretations[ATX_HEADING_MDINTERPRETATION])       @<Line is an ATX heading@>;
	if (interpretations[THEMATIC_MDINTERPRETATION])          @<Line is a thematic break@>;
	if (interpretations[HTML_MDINTERPRETATION])              @<Line opens HTML@>;
	if (interpretations[CODE_BLOCK_MDINTERPRETATION])        @<Line is part of an indented code block@>;
	@<Line opens a new paragraph@>;

@ This is really the heart of the stacking algorithm: we've reached a point where
the row of markers has expressed a clear description of what the containers ought
to be. For example, if it read |* * > 2) Whatever|, we would have four items on
the marker stack, and we need to make sure that the container stack also has
four items (not counting item 0, the document head) which exactly match those
markers. 

@<Make the container stack agree with the markers stack@> =
	int wipe_down_to_pos;
	@<Find the outermost point of current disagreement@>;
	@<Close all existing containers inside that point@>;
	@<Open new containers as needed from that point to match the further markers@>;
	if (tracing_Markdown_parser) {
		PRINT("Container stack:");
		for (int sp = 0; sp<state->container_sp; sp++) {
			PRINT(" -> "); Markdown::debug_item(STDOUT, state->containers[sp]);
		}
		PRINT("\n");
	}

@ The two stacks may in fact agree up to a certain point, but they diverge
as soon as they run into a non-continued list marker. For example, with the
lines:
= (text)
	> > 1) Switzerland: Zurich: 1843 4 rappen, the unique unsevered horizontal strip of five;
	> > 2) Uruguay: 1858 120 centavos blue and 180 centavos green, in tête beche pairs, two of five known;
=
the outermost point of disagreement (i.e., the leftmost) is at stack position
3, where the two numbered item markers live. The eventual effect will be to
change the container stack from:
= (text)
	BLOCK_QUOTE_MIT
		BLOCK_QUOTE_MIT
			ORDERED_LIST_ITEM_MIT "Switzerland: Zurich: 1843..."
=
to become:
= (text)
	BLOCK_QUOTE_MIT
		BLOCK_QUOTE_MIT
			ORDERED_LIST_ITEM_MIT "Uruguay: 1858 120 centavos..."
=

@<Find the outermost point of current disagreement@> =
	int min_sp = state->marker_sp, max_sp = state->marker_sp;
	if (state->container_sp < min_sp) min_sp = state->container_sp;
	if (state->container_sp > max_sp) max_sp = state->container_sp;
	wipe_down_to_pos = min_sp;
	for (int sp = 1; sp<min_sp; sp++) {
		positional_marker *marker = MDBlockParser::marker_at(state, sp);
		if (MDBlockParser::marker_is_new_list_entry(marker) == TRUE) {
			wipe_down_to_pos = sp; break;
		}
	}	
	if (tracing_Markdown_parser) {
		PRINT("Stacks compared: ");
		if (wipe_down_to_pos == 1) PRINT(" WIPE");
		for (int sp=1; (sp<state->container_sp) || (sp<state->marker_sp); sp++) {
			PRINT(" ");
			if (sp >= state->marker_sp) PRINT("--");
			else MDBlockParser::debug_marker(STDOUT, MDBlockParser::marker_at(state, sp), TRUE);
			PRINT(" vs ");
			if (sp >= state->container_sp) PRINT("--");
			else Markdown::debug_item(STDOUT, state->containers[sp]);
			if (sp+1 == wipe_down_to_pos) PRINT(" WIPE");
		}
		PRINT("\n");
	}

@ This looks straightforward, but we need to be aware that if we are closing
a container which contains an incomplete fenced code block (one which never
reached its closing fence) then it needs to be ended as the container does;
and similarly for raw HTML which has not yet, and now never will, reach its
ending line.

@<Close all existing containers inside that point@> =
	for (int sp = state->container_sp-1; sp >= wipe_down_to_pos; sp--) {
		MDBlockParser::close_block(state, state->containers[sp]);
		state->containers[sp] = NULL;
	}
	state->container_sp = wipe_down_to_pos;
	if (state->container_sp < state->temporary_marker_limit) {
		if (state->fencing.material != 0) {
			@<Close the code fence@>;
			interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION] = FALSE;
		} else if (state->HTML_end_condition) {
			@<End the HTML block@>;
			interpretations[HTML_CONTINUATION_MDINTERPRETATION] = FALSE;
		}
		MDBlockParser::lift_marker_limit(state);
	}

@ And this is where all container items are born, except of course for the
outermost document item.

@<Open new containers as needed from that point to match the further markers@> =
	for (int sp = wipe_down_to_pos; sp<state->marker_sp; sp++) {
		positional_marker *marker = MDBlockParser::marker_at(state, sp);
		markdown_item *newbq = Markdown::new_item(marker->item_type);
		Markdown::set_item_number_and_flavour(newbq,
			marker->list_item_value, marker->list_item_flavour);
		Markdown::add_to(newbq, state->containers[sp-1]);
		state->containers[state->container_sp++] = newbq;
		MDBlockParser::open_block(state, newbq);
	}

@ That's it for the part of the algorithm which decides which interpretation
to give the content. There are 12 possible outcomes of that, and we'll give
them in the same priority sequence as was followed above.

First, the two paragraph-continuation cases, where a setext underline takes
priority. "Setext" stands for "Structure Enhanced Text", a precursor language
to Markdown created by Ian Feldman in 1991.
= (text)
	Women in Philately
	==================
	One of the earliest was Adelaide Lucy Fenton, who wrote articles in the
	1860s for the journal The Philatelist under the name Herbert Camoens.
=
This natural-looking notation survives in Markdown today, and line 2 above
is a "setext underline".

Dealing with it would be straightforward - simply make the paragraph item
holding "Women in Philately" a heading item, and throw the underline characters
away. But consider the following edge case:
= (text)
	[pb]: /pennyblacks.html "Penny Black catalogue"
	-----
=
Here |-----| looks like, and has been parsed as, a setext underline. But it
isn't, because in fact the whole paragraph was taken up with link references,
leaving it with no content. So the only way correctly to deal with this is to
remove the link references first and see if there's any para left.

It might seem tidier to deal with link references when they join paragraphs
but, infuriatingly, they can sometimes run across multiple lines, and moreover
can do so in a way such that the first line alone is also a valid link reference:
= (text)
	[pb]: /pennyblacks.html
	  "Penny Black catalogue"
	-----
=
So it is not safe to strip out link references until a paragraph is done.
In these cases where the apparent underline is, in fact, not an underline
because there was no content left, we have to preserve it as literal
content, opening a new paragraph to hold the |-----|.

@<Line is a setext underline and turns the existing paragraph into a heading@> =
	wchar_t c = Str::get_at(line, content_index);
	markdown_item *headb = MDBlockParser::latest_paragraph(state);
	if (headb) {
		MDBlockParser::remove_link_references(state, headb);
		if (headb->type == EMPTY_MIT) @<Line opens a new paragraph@>;
		MDBlockParser::change_type(state, headb, HEADING_MIT);
		if (c == '=') Markdown::set_heading_level(headb, 1);
		else Markdown::set_heading_level(headb, 2);
		Str::trim_white_space(headb->stashed);
	}
	return;

@ Actual paragraph continuation is much simpler.

@<Line continues an existing paragraph@> =
	markdown_item *parb = MDBlockParser::latest_paragraph(state);
	if ((parb) && (parb->type == PARAGRAPH_MIT)) {
		WRITE_TO(parb->stashed, "\n");
		for (int i = content_index; i<Str::len(line); i++) {
			wchar_t c = Str::get_at(line, i);
			PUT_TO(parb->stashed, c);
		}
	} else internal_error("no paragraph is open after all");
	return;

@ Now for the 10 possibilities which don't fall under lazy continuations.
Top of the heap is an HTML continuation line. This may or may not meet the
criteria to be the final line. Note that in two cases of HTML start/end
conditions, the final line is white space, but is not to be included in the
material itself. In the other five cases, the final line is part of the matter.

@<Line is part of HTML@> =
	markdown_item *latest = MDBlockParser::latest_HTML_block(state);
	if (latest == NULL) @<End the HTML block@>
	else {
		int ends = FALSE;
		@<Test for HTML end condition@>;
		if ((latest) && (!((ends) &&
			((state->HTML_end_condition == MISCSINGLE_MDHTMLC) ||
				(state->HTML_end_condition == MISCPAIR_MDHTMLC)))))
			@<Add text of line to HTML block@>;
		if (ends) @<End the HTML block@>
		return;
	}

@ Now to open a fenced code block, which means recording a lot of information
about it: the info string, if there is one, has to be preserved in the tree,
since it will be used during rendering to apply a CSS class. The other data
here is needed only during parsing, and remembers the syntax used here so that
we can make sure matching syntax is used on the closing line.

@<Line is an opening code fence@> =
	int post_count = details[CODE_FENCE_OPEN_MDINTERPRETATION];
	text_stream *info_string = Str::new();
	MDBlockParser::can_interpret_as(state, line, indentation, content_index,
		CODE_FENCE_OPEN_MDINTERPRETATION, info_string, NULL);
	wchar_t c = Str::get_at(line, content_index);
	markdown_item *cb = Markdown::new_item(CODE_BLOCK_MIT);
	cb->stashed = Str::new();
	cb->info_string = info_string;
	MDBlockParser::turn_over_a_new_leaf(state, cb);
	state->fencing.left_margin = TabbedStr::get_position(&line_scanner);
	state->fencing.material = c;
	state->fencing.width = post_count;
	state->fencing.fenced_code = cb;
	MDBlockParser::make_receiver(state, cb);
	MDBlockParser::impose_marker_limit(state, state->container_sp);
	return;

@ Next up, the closing line of a code fence. Note that this is not the only
way a fenced code block can end: it can also end when its container is closed,
see above.

@<Line is a closing code fence@> =
	@<Close the code fence@>;
	return;

@<Close the code fence@> =
	MDBlockParser::clear_fencing_data(state);
	MDBlockParser::lift_marker_limit(state);

@ Next, a continuation line in a fenced code block. Here we're subject to the
tricky issue mentioned above where the line scanner working through tabs
early in the line and reading them as if they were spaces, may in fact be
only part-way through a tab at the start of the content. If that happens,
we need to inject artificial space characters into the code put into the block,
thus faking the same visual effect. (It does not comply with CommonMark to use a
tab for this: we must use the correct fraction of a tab, using spaces as quarter-tabs.)

@<Line is part of a fenced code block@> =
	markdown_item *code_block = state->fencing.fenced_code;
	if ((state->fencing.left_margin >= 0) &&
		(state->fencing.left_margin < TabbedStr::get_position(&line_scanner)))
		TabbedStr::seek(&line_scanner, state->fencing.left_margin);
	while (TabbedStr::at_whole_character(&line_scanner) == FALSE) {
		PUT_TO(code_block->stashed, ' ');
		TabbedStr::advance(&line_scanner);
	}
	for (int i = TabbedStr::get_index(&line_scanner); i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(code_block->stashed, c);
	}
	PUT_TO(code_block->stashed, '\n');
	return;

@ And next, white space! Where the content is entirely blank to the reader's eye.
But that doesn't mean it should be discarded. There's an edge case (those happy
words again) where something like this happens, where I'm typing underscores
in place of spaces to make it more visible:
= (text)
	Here is some code:
	
	____You can see this is a code block,
	____because of the indentation by 4 spaces.
	_______
	____Now this is part of the same code block, and although
	____the whitespace line falling between the two looked blank,
	____it actually contained more than 4 spaces of indentation,
	____7 in fact, so three of those must be put into the block.
=
Those extra spaces are cached in |state->blank_matter_after_receiver|. They
can't be added to the code block yet because, of course, we don't yet know
when parsing the blank line whether the future lines will continue the code
block or not. (In this example, they will, but we can't know that.)

@<Line is whitespace@> =
	int sp = state->container_sp-1;
	if (state->markers[sp].continues_from_earlier_line) {
		if (state->containers[sp]->down) {
			for (markdown_item *ch = state->containers[sp]->down; ch; ch = ch->next)
				if ((ch->next == NULL) && (ch->type != BLOCK_QUOTE_MIT))
					MDBlockParser::mark_block_with_ws(state, ch);
		} else {
			MDBlockParser::mark_block_with_ws(state, state->containers[sp]);
		}
	}

	if (indentation)
		for (int i=content_index; i<Str::len(line); i++) {
			wchar_t c = Str::get_at(line, i);
			PUT_TO(state->blank_matter_after_receiver, c);
		}
	PUT_TO(state->blank_matter_after_receiver, '\n');
	return;
	
@ "ATX" was a direct precursor to Markdown, by Aaron Swartz, who collaborated
with John Gruber in its development: the term "ATX heading" preserves its
memory. (And indeed his. Whereas Gruber became a successful commentator and
Internet opinion-former through speech, Swartz's activism was more disruptive
and direct, and he was to be hounded to death by an overzealous Federal
prosecutor in 2013. He was just 26. But he deserves to be remembered for
pioneering work on RSS, podcasting, Reddit, Creative Commons, and numerous
other utopian Internet developments in that final decade when it was still
a hacker's playground. As with David Foster Wallace, we shall never know what
he might have gone on to give us.)

@<Line is an ATX heading@> =
	int hash_count = details[ATX_HEADING_MDINTERPRETATION];
	markdown_item *headb = Markdown::new_item(HEADING_MIT);
	Markdown::set_heading_level(headb, hash_count);
	text_stream *H = Str::new();
	headb->stashed = H;
	for (int i=content_index+hash_count; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		if ((Str::len(H) == 0) && ((c == ' ') || (c == '\t')))
			continue;
		PUT_TO(H, c);
	}
	while ((Str::get_last_char(H) == ' ') || (Str::get_last_char(H) == '\t'))
		Str::delete_last_character(H);
	for (int i=Str::len(H)-1; i>=0; i--) {
		if ((Str::get_at(H, i) == ' ') || (Str::get_at(H, i) == '\t')) {
			Str::truncate(H, i); break; 
		}
		if (Str::get_at(H, i) != '#') break;
		if (i == 0) Str::clear(H);
	}
	while ((Str::get_last_char(H) == ' ') || (Str::get_last_char(H) == '\t'))
		Str::delete_last_character(H);
	MDBlockParser::turn_over_a_new_leaf(state, headb);
	return;

@ Next, a thematic break. Which couldn't be easier: there's no text to preserve.
All thematic breaks are identical leaf blocks in the tree.

@<Line is a thematic break@> =
	markdown_item *themb = Markdown::new_item(THEMATIC_MIT);
	MDBlockParser::turn_over_a_new_leaf(state, themb);
	return;

@ And now for a line which opens a verbatim HTML block. Something to look
out for is that sometimes the opening line is also the closing line for such
a block, so we need to test for that.

@<Line opens HTML@> =
	state->HTML_end_condition = details[HTML_MDINTERPRETATION];
	if (tracing_Markdown_parser) {
		PRINT("enter HTML with end_condition = %d\n", state->HTML_end_condition);
	}
	markdown_item *htmlb = Markdown::new_item(HTML_MIT);
	htmlb->stashed = Str::new();
	MDBlockParser::turn_over_a_new_leaf(state, htmlb);
	MDBlockParser::impose_marker_limit(state, state->container_sp);
	@<Add text of line to HTML block@>;
	int ends = FALSE;
	@<Test for HTML end condition@>;
	if (ends) @<End the HTML block@>;
	return;

@<Add text of line to HTML block@> =
	markdown_item *latest = MDBlockParser::latest_HTML_block(state);
	int from = content_index;
	if (state->temporary_marker_limit == 1) from = 0;
	for (int i = from; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');

@<Test for HTML end condition@> =
	if (MDBlockParser::latest_HTML_block(state) == NULL) {
		if (tracing_Markdown_parser) {
			PRINT("HTML forcibly ended by closure of container\n");
		}
	} else {
		if (tracing_Markdown_parser) {
			PRINT("test '%S' for HTML_end_condition = %d\n", line, state->HTML_end_condition);
		}
		switch (state->HTML_end_condition) {
			case PRE_MDHTMLC:
				if ((Str::includes_insensitive(line, I"</pre>")) ||
					(Str::includes_insensitive(line, I"</script>")) ||
					(Str::includes_insensitive(line, I"</style>")) ||
					(Str::includes_insensitive(line, I"</textarea>")))
					ends = TRUE;
				break;
			case COMMENT_MDHTMLC:
				if (Str::includes(line, I"-->")) ends = TRUE;
				break;
			case QUERY_MDHTMLC:
				if (Str::includes(line, I"?>")) ends = TRUE;
				break;
			case PLING_MDHTMLC:
				if (Str::includes(line, I"!>")) ends = TRUE;
				break;
			case CDATA_MDHTMLC:
				if (Str::includes(line, I"]]>")) ends = TRUE;
				break;
			case MISCSINGLE_MDHTMLC:
			case MISCPAIR_MDHTMLC:
				if (Str::is_whitespace(line)) ends = TRUE;
				break;
		}
	}
	
	if (tracing_Markdown_parser) {
		PRINT("test outcome: %s\n", (ends)?"yes":"no");
	}

@<End the HTML block@> =
	markdown_item *latest = MDBlockParser::latest_HTML_block(state);
	MDBlockParser::clear_HTML_data(state);
	MDBlockParser::lift_marker_limit(state);
	if (latest) MDBlockParser::close_block(state, latest);

@ And now for a continuation of an existing indented (but not fenced) code
block:

@<Line is part of an indented code block@> =
	markdown_item *latest = MDBlockParser::latest_code_block(state);
	if (latest) {
		WRITE_TO(latest->stashed, "%S", state->blank_matter_after_receiver);
		Str::clear(state->blank_matter_after_receiver);
	} else {
		markdown_item *cb = Markdown::new_item(CODE_BLOCK_MIT);
		cb->stashed = Str::new();
		state->fencing.left_margin = -1;
		MDBlockParser::turn_over_a_new_leaf(state, cb);
		latest = cb;
	}
	while (TabbedStr::at_whole_character(&line_scanner) == FALSE) {
		PUT_TO(latest->stashed, ' ');
		TabbedStr::advance(&line_scanner);
	}
	for (int i = TabbedStr::get_index(&line_scanner); i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');
	return;

@ There's just one interpretation left to deal with, the lowest-priority
but a very common outcome:

@<Line opens a new paragraph@> =
	markdown_item *parb = Markdown::new_item(PARAGRAPH_MIT);
	parb->stashed = Str::new();
	MDBlockParser::turn_over_a_new_leaf(state, parb);
	for (int i=content_index; i<Str::len(line); i++)
		PUT_TO(parb->stashed, Str::get_at(line, i));
	return;

@h Finding interpretations.
That finally completes the main "process a line" function, but we delegated
a whole lot of syntactic parsing to work out which interpretations for a line
are tenable. So, here goes.

The following always says no to |LAZY_CONTINUATION_MDINTERPRETATION| because
it's not in a position to know: that decision depends on all the other
decisions, and on the situation at large as well. See above for where it is
actually decided.

@d NO_MDINTERPRETATIONS 12 /* well, okay, so there are actually 11, but... */

@e WHITESPACE_MDINTERPRETATION from 1
@e THEMATIC_MDINTERPRETATION
@e ATX_HEADING_MDINTERPRETATION
@e SETEXT_UNDERLINE_MDINTERPRETATION
@e HTML_MDINTERPRETATION
@e CODE_FENCE_OPEN_MDINTERPRETATION
@e CODE_FENCE_CLOSE_MDINTERPRETATION
@e CODE_BLOCK_MDINTERPRETATION
@e FENCED_CODE_BLOCK_MDINTERPRETATION
@e HTML_CONTINUATION_MDINTERPRETATION
@e LAZY_CONTINUATION_MDINTERPRETATION

=
int MDBlockParser::can_interpret_as(md_doc_state *state, text_stream *line,
	int indentation, int content_index, int which, text_stream *text_details, int *int_detail) {
	switch (which) {
		case WHITESPACE_MDINTERPRETATION:        @<Is WHITESPACE_MDINTERPRETATION tenable?@>;
		case THEMATIC_MDINTERPRETATION:          @<Is THEMATIC_MDINTERPRETATION tenable?@>;
		case ATX_HEADING_MDINTERPRETATION:       @<Is ATX_HEADING_MDINTERPRETATION tenable?@>;
		case SETEXT_UNDERLINE_MDINTERPRETATION:  @<Is SETEXT_UNDERLINE_MDINTERPRETATION tenable?@>;
		case CODE_FENCE_OPEN_MDINTERPRETATION:
		case CODE_FENCE_CLOSE_MDINTERPRETATION:  @<Is either code fence interpretation tenable?@>;
		case HTML_MDINTERPRETATION:              @<Is HTML_MDINTERPRETATION tenable?@>;
		case CODE_BLOCK_MDINTERPRETATION:        @<Is CODE_BLOCK_MDINTERPRETATION tenable?@>;
		case FENCED_CODE_BLOCK_MDINTERPRETATION: @<Is FENCED_CODE_BLOCK_MDINTERPRETATION tenable?@>;
		case HTML_CONTINUATION_MDINTERPRETATION: @<Is HTML_CONTINUATION_MDINTERPRETATION tenable?@>;
		case LAZY_CONTINUATION_MDINTERPRETATION: return FALSE;
		default: return FALSE;
	}
}

@<Is WHITESPACE_MDINTERPRETATION tenable?@> =
	for (int i=content_index; i<Str::len(line); i++)
		if ((Str::get_at(line, i) != ' ') && (Str::get_at(line, i) != '\t'))
			return FALSE;
	return TRUE;

@ Beware: indent a thematic marker like |-  -  -| far enough, and it becomes
part of a code block, not a thematic break at all.

@<Is THEMATIC_MDINTERPRETATION tenable?@> =
	if (indentation) return FALSE;
	return MDBlockParser::thematic_marker(line, content_index);

@ One to six |#| characters, followed by white space or the end of the line.
Note that there can be junk in the form of further |#|s at the far end,
but removing that junk is not our business here.

@<Is ATX_HEADING_MDINTERPRETATION tenable?@> =
	if (indentation) return FALSE;
	int hash_count = 0;
	while (Str::get_at(line, content_index+hash_count) == '#') hash_count++;
	if ((hash_count >= 1) && (hash_count <= 6) &&
		((Str::get_at(line, content_index+hash_count) == ' ') ||
			(Str::get_at(line, content_index+hash_count) == '\t') ||
			(Str::get_at(line, content_index+hash_count) == 0))) {
		if (int_detail) *int_detail = hash_count;
		return TRUE;
	}
	return FALSE;

@ Provided we're following a paragraph, any sequence of 1 or more identical
|-| or |=| characters followed by white space to the end of the line is a
setext underline.

@<Is SETEXT_UNDERLINE_MDINTERPRETATION tenable?@> =
	if (MDBlockParser::latest_paragraph(state) == NULL) return FALSE;
	if (indentation) return FALSE;
	wchar_t c = Str::get_at(line, content_index);
	if ((c == '-') || (c == '=')) {
		int ornament_count = 1, extraneous = 0;
		int j=content_index+1;
		for (; j<Str::len(line); j++) {
			wchar_t d = Str::get_at(line, j);
			if (d == c) ornament_count++;
			else break;
		}
		for (; j<Str::len(line); j++) {
			wchar_t d = Str::get_at(line, j);
			if ((d != ' ') && (d != '\t')) extraneous++;
		}
		if ((ornament_count > 0) && (extraneous == 0)) return TRUE;
	}
	return FALSE;

@ A code fence is a run of three or more backticks or three or more tildes,
except that if it's to be a closing fence then it only works if it matches the
opening fence, using at least as many of the same character. Thus:
= (text)
	---
	~~~~
	~~~~
	--
	-----
=
is in fact a single fenced code block. Once line 1 has been accepted as being
a |CODE_FENCE_OPEN_MDINTERPRETATION| case, the subsequent lines are not
the closing fence because they are too short or of the wrong kind, until we
reach line 5.

@<Is either code fence interpretation tenable?@> =
	if (indentation) return FALSE;
	if ((which == CODE_FENCE_OPEN_MDINTERPRETATION) && (state->fencing.material != 0))
		return FALSE;
	if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (state->fencing.material == 0))
		return FALSE;
	text_stream *info_string = text_details;
	wchar_t c = Str::get_at(line, content_index);
	if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (state->fencing.material != c))
		return FALSE;
	if ((c == '`') || (c == '~')) {
		int post_count = 0;
		int j = content_index;
		for (; j<Str::len(line); j++) {
			wchar_t d = Str::get_at(line, j);
			if (d == c) post_count++;
			else break;
		}
		if (post_count >= 3) {
			if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) &&
				(post_count < state->fencing.width)) return FALSE;
			@<Looks good so far, but what about the info string?@>;
		}
	}
	return FALSE;

@ We need to deal with backslashes used as escape characters in the info
string, which is an optional run of characters following the opening fence
on the same line. Note that a code fence is illegal if unescaped backticks
are used in it, where the backtick is the fencing material. In such a case,
it is not enough to reject the info string, we must reject the interpretation
of the line as |CODE_FENCE_OPEN_MDINTERPRETATION|.

@<Looks good so far, but what about the info string?@> =
	int ambiguous = FALSE, count = 0, escaped = FALSE;
	for (; j<Str::len(line); j++) {
		wchar_t d = Str::get_at(line, j);
		if ((escaped == FALSE) && (d == '\\') &&
			(Characters::is_ASCII_punctuation(Str::get_at(line, j+1))))
			escaped = TRUE;
		else {
			if ((escaped == FALSE) && (d == '`') && (c == d)) ambiguous = TRUE;
			PUT_TO(info_string, d); count++;
			escaped = FALSE;
		}
	}
	Str::trim_white_space(info_string);
	if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (count > 0)) return FALSE;
	if (ambiguous == FALSE) {
		if (int_detail) *int_detail = post_count;
		return TRUE;
	}

@ HTML blocks are runs of verbatim copy found inside the Markdown file and
passed straight through. This sounds easy, but the trick is to decide what
is, and isn't, HTML. The doctrine is that HTML begins on the first line which
meets a "start condition" and ends on the next which meets its corresponding
"end condition" (and that may be the same line, as noted above).

Simple enough? Infuriatingly, there are seven different pairs of start/end
condition for HTML blocks, referred to in CommonMark as types. They must not
quite be tested in their numerical order, since type 4 implies type 5, so
5 must be checked before 4.

The one piece of good news is that they all start with a |<| character.

@e PRE_MDHTMLC from 1   /* CommonMark type 1 */
@e COMMENT_MDHTMLC      /* CommonMark type 2 */
@e QUERY_MDHTMLC        /* CommonMark type 3 */
@e PLING_MDHTMLC        /* CommonMark type 4 */
@e CDATA_MDHTMLC        /* CommonMark type 5 */
@e MISCSINGLE_MDHTMLC   /* CommonMark type 6 */
@e MISCPAIR_MDHTMLC     /* CommonMark type 7 */

@<Is HTML_MDINTERPRETATION tenable?@> =
	if (indentation) return FALSE;
	wchar_t c = Str::get_at(line, content_index);
	if (c != '<') return FALSE;

	int condition_type = 0; /* not a valid condition */
	
	int i = content_index+1; /* i.e., the index after the |<| */
	TEMPORARY_TEXT(tag)
	for (; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		if ((c == ' ') || (c == '\t') || (c == '>')) break;
		PUT_TO(tag, c);
	}
	
	@<Is a PRE_MDHTMLC type HTML opening tenable?@>;
	@<Is a COMMENT_MDHTMLC type HTML opening tenable?@>;
	@<Is a QUERY_MDHTMLC type HTML opening tenable?@>;
	@<Is a CDATA_MDHTMLC type HTML opening tenable?@>;	
	@<Is a PLING_MDHTMLC type HTML opening tenable?@>;
	
	if (Str::get_first_char(tag) == '/') Str::delete_first_character(tag);
	for (int i=0; i<Str::len(tag); i++) {
		if (Str::get_at(tag, i) == '>') {
			Str::put_at(tag, i, 0); break;
		}
		if ((Str::get_at(tag, i) == '/') && (Str::get_at(tag, i+1) == '>')) {
			Str::put_at(tag, i, 0); break;
		}
	}

	@<Is a MISCSINGLE_MDHTMLC type HTML opening tenable?@>;
	@<Is a MISCPAIR_MDHTMLC type HTML opening tenable?@>;

	HTML_Start_Found: ;

	DISCARD_TEXT(tag)

	if (condition_type != 0) {		
		if (int_detail) *int_detail = condition_type;
		return TRUE;
	}
	return FALSE;

@<Is a PRE_MDHTMLC type HTML opening tenable?@> =	
	if ((Str::eq_insensitive(tag, I"pre")) ||
		(Str::eq_insensitive(tag, I"script")) ||
		(Str::eq_insensitive(tag, I"style")) ||
		(Str::eq_insensitive(tag, I"textarea"))) {
		condition_type = PRE_MDHTMLC; goto HTML_Start_Found;
	}

@<Is a COMMENT_MDHTMLC type HTML opening tenable?@> =	
	if (Str::begins_with(tag, I"!--")) {
		condition_type = COMMENT_MDHTMLC; goto HTML_Start_Found;
	}

@<Is a QUERY_MDHTMLC type HTML opening tenable?@> =	
	if (Str::begins_with(tag, I"?")) {
		condition_type = QUERY_MDHTMLC; goto HTML_Start_Found;
	}

@<Is a CDATA_MDHTMLC type HTML opening tenable?@> =
	if (Str::begins_with(tag, I"![CDATA[")) {
		condition_type = CDATA_MDHTMLC; goto HTML_Start_Found;
	}

@<Is a PLING_MDHTMLC type HTML opening tenable?@> =
	if (Str::begins_with(tag, I"!")) {
		condition_type = PLING_MDHTMLC; goto HTML_Start_Found;
	}

@<Is a MISCSINGLE_MDHTMLC type HTML opening tenable?@> =	
	if ((Str::eq_insensitive(tag, I"address")) ||
		(Str::eq_insensitive(tag, I"article")) ||
		(Str::eq_insensitive(tag, I"aside")) ||
		(Str::eq_insensitive(tag, I"base")) ||
		(Str::eq_insensitive(tag, I"basefont")) ||
		(Str::eq_insensitive(tag, I"blockquote")) ||
		(Str::eq_insensitive(tag, I"body")) ||
		(Str::eq_insensitive(tag, I"caption")) ||
		(Str::eq_insensitive(tag, I"center")) ||
		(Str::eq_insensitive(tag, I"col")) ||
		(Str::eq_insensitive(tag, I"colgroup")) ||
		(Str::eq_insensitive(tag, I"dd")) ||
		(Str::eq_insensitive(tag, I"details")) ||
		(Str::eq_insensitive(tag, I"dialog")) ||
		(Str::eq_insensitive(tag, I"dir")) ||
		(Str::eq_insensitive(tag, I"div")) ||
		(Str::eq_insensitive(tag, I"dl")) ||
		(Str::eq_insensitive(tag, I"dt")) ||
		(Str::eq_insensitive(tag, I"fieldset")) ||
		(Str::eq_insensitive(tag, I"figcaption")) ||
		(Str::eq_insensitive(tag, I"figure")) ||
		(Str::eq_insensitive(tag, I"footer")) ||
		(Str::eq_insensitive(tag, I"form")) ||
		(Str::eq_insensitive(tag, I"frame")) ||
		(Str::eq_insensitive(tag, I"frameset")) ||
		(Str::eq_insensitive(tag, I"h1")) ||
		(Str::eq_insensitive(tag, I"h2")) ||
		(Str::eq_insensitive(tag, I"h3")) ||
		(Str::eq_insensitive(tag, I"h4")) ||
		(Str::eq_insensitive(tag, I"h5")) ||
		(Str::eq_insensitive(tag, I"h6")) ||
		(Str::eq_insensitive(tag, I"head")) ||
		(Str::eq_insensitive(tag, I"header")) ||
		(Str::eq_insensitive(tag, I"hr")) ||
		(Str::eq_insensitive(tag, I"html")) ||
		(Str::eq_insensitive(tag, I"iframe")) ||
		(Str::eq_insensitive(tag, I"legend")) ||
		(Str::eq_insensitive(tag, I"li")) ||
		(Str::eq_insensitive(tag, I"link")) ||
		(Str::eq_insensitive(tag, I"main")) ||
		(Str::eq_insensitive(tag, I"menu")) ||
		(Str::eq_insensitive(tag, I"menuitem")) ||
		(Str::eq_insensitive(tag, I"nav")) ||
		(Str::eq_insensitive(tag, I"noframes")) ||
		(Str::eq_insensitive(tag, I"ol")) ||
		(Str::eq_insensitive(tag, I"optgroup")) ||
		(Str::eq_insensitive(tag, I"option")) ||
		(Str::eq_insensitive(tag, I"p")) ||
		(Str::eq_insensitive(tag, I"param")) ||
		(Str::eq_insensitive(tag, I"section")) ||
		(Str::eq_insensitive(tag, I"source")) ||
		(Str::eq_insensitive(tag, I"summary")) ||
		(Str::eq_insensitive(tag, I"table")) ||
		(Str::eq_insensitive(tag, I"tbody")) ||
		(Str::eq_insensitive(tag, I"td")) ||
		(Str::eq_insensitive(tag, I"tfoot")) ||
		(Str::eq_insensitive(tag, I"th")) ||
		(Str::eq_insensitive(tag, I"thead")) ||
		(Str::eq_insensitive(tag, I"title")) ||
		(Str::eq_insensitive(tag, I"tr")) ||
		(Str::eq_insensitive(tag, I"track")) ||
		(Str::eq_insensitive(tag, I"ul"))) {
		condition_type = MISCSINGLE_MDHTMLC; goto HTML_Start_Found;
	}

@ And now the really painful one. See CommonMark, but basically this is
where we have what looks like a tag and is not one that would cause |PRE_MDHTMLC|,
but can also be followed by HTML attributes and values: for example,
|<img src="this">| would be matched by the following.

@<Is a MISCPAIR_MDHTMLC type HTML opening tenable?@> =
	Str::clear(tag);
	WRITE_TO(tag, "%S", line);
	Str::trim_white_space(tag);
	if (Str::get_first_char(tag) == '<') { Str::delete_first_character(tag); Str::trim_white_space(tag); }
	int valid = TRUE, closing = FALSE;
	if (Str::get_first_char(tag) == '/') { closing = TRUE; Str::delete_first_character(tag); }
	TEMPORARY_TEXT(tag_name)
	int i = 0;
	for (; i<Str::len(tag); i++) {
		wchar_t c = Str::get_at(tag, i);
		if ((Characters::is_ASCII_letter(c)) ||
			((i > 0) && ((Characters::is_ASCII_digit(c)) || (c == '-'))))
			PUT_TO(tag_name, c);
		else break;
	}
	if (Str::len(tag_name) == 0) valid = FALSE;
	if ((Str::eq_insensitive(tag_name, I"pre")) ||
		(Str::eq_insensitive(tag_name, I"script")) ||
		(Str::eq_insensitive(tag_name, I"style")) ||
		(Str::eq_insensitive(tag_name, I"textarea"))) valid = FALSE;
	DISCARD_TEXT(tag_name)
	if (closing == FALSE) {
		while (TRUE) {
			wchar_t c = Str::get_at(tag, i);
			if ((c != ' ') && (c != '\t')) break;
			i = MDBlockParser::advance_past_spacing(tag, i);
			c = Str::get_at(tag, i);
			if ((c == '_') || (c == ':') || (Characters::is_ASCII_letter(c))) {
				i++; c = Str::get_at(tag, i);
				while ((c == '_') || (c == ':') || (c == '.') || (c == '-') ||
					(Characters::is_ASCII_letter(c)) || (Characters::is_ASCII_digit(c))) {
					i++; c = Str::get_at(tag, i);
				}
				i = MDBlockParser::advance_past_spacing(tag, i);
				if (Str::get_at(tag, i) == '=') {
					i++;
					i = MDBlockParser::advance_past_spacing(tag, i);
					wchar_t c = Str::get_at(tag, i);
					if (c == '\'') {
						i++; c = Str::get_at(tag, i);
						while ((c) && (c != '\'')) {
							i++; c = Str::get_at(tag, i);
						}
						if (c == 0) valid = FALSE;
						i++;
					} else if (c == '"') {
						i++; c = Str::get_at(tag, i);
						while ((c) && (c != '"')) {
							i++; c = Str::get_at(tag, i);
						}
						if (c == 0) valid = FALSE;
						i++;
					} else {
						int nc = 0;
						while ((c != 0) && (c != ' ') && (c != '\t') && (c != '\n') && (c != '"') &&
							(c != '\'') && (c != '=') && (c != '<') && (c != '>') && (c != '`')) {
							nc++; i++; c = Str::get_at(tag, i);
						}
						if (nc == 0) valid = FALSE;
						i++;
					}
					i = MDBlockParser::advance_past_spacing(tag, i);
				}
			} else break;
		}
	}
	if ((closing == FALSE) && (Str::get_at(tag, i) == '/')) i++;
	if (Str::get_at(tag, i) != '>') valid = FALSE; i++;
	i = MDBlockParser::advance_past_spacing(tag, i);
	if (Str::get_at(tag, i) != 0) valid = FALSE;
	if (valid) {
		condition_type = MISCPAIR_MDHTMLC; goto HTML_Start_Found;
	}

@ After which, the rest are anticlimactic:

@<Is CODE_BLOCK_MDINTERPRETATION tenable?@> =
	if (MDBlockParser::latest_paragraph(state)) return FALSE;
	if (indentation) return TRUE;
	return FALSE;

@<Is FENCED_CODE_BLOCK_MDINTERPRETATION tenable?@> =
	if (state->fencing.material != 0) return TRUE;
	return FALSE;

@<Is HTML_CONTINUATION_MDINTERPRETATION tenable?@> =
	if ((MDBlockParser::latest_HTML_block(state)) &&
		(state->HTML_end_condition != 0)) return TRUE;
	return FALSE;

@ The function above makes use of the following, where we skip white space provided
we do not skip an entire visually blank line.

=
int MDBlockParser::advance_past_spacing(text_stream *tag, int i) {
	int newlines = 0;
	wchar_t c = Str::get_at(tag, i);
	while ((c == ' ') || (c == '\t') || (c == '\n')) {
		if (c == '\n') {
			newlines++; if (newlines == 2) break;
		}
		i++; c = Str::get_at(tag, i);
	}
	return i;
}

@h Parsing link references.
When a paragraph contains link references, that will be at the beginning,
and they need to be excised. Since this can in principle leave the paragraph
entirely denuded of text, we may need to convert it to an |EMPTY_MIT| node.

=
int MDBlockParser::remove_link_references(md_doc_state *state, markdown_item *at) {
	if (at->type == PARAGRAPH_MIT) {
		int matched_to = 0;
		while (matched_to >= 0) {
			matched_to = -1;
			text_stream *X = at->stashed;
			@<Try to match a single link reference@>;
			if (matched_to > 0) {
				Str::delete_n_characters(at->stashed, matched_to);
				if (Str::len(at->stashed) == 0) {
					MDBlockParser::change_type(state, at, EMPTY_MIT);
					return TRUE;
				}
			}
		}
	}
	return FALSE;
}

@<Try to match a single link reference@> =
	int i = 0;
	while ((Str::get_at(X, i) == ' ') || (Str::get_at(X, i) == '\t')) i++;
	if (Str::get_at(X, i) == '[') {
		i++;
		int count = 0, ws_count = 0;
		TEMPORARY_TEXT(label)
		@<Find the label text@>;
		if ((Str::get_at(X, i) == ':') && (count <= 999) && (ws_count < count)) {
			i++;
			i = MDBlockParser::advance_past_spacing(X, i);
			
			int valid = TRUE;
			
			TEMPORARY_TEXT(destination)
			TEMPORARY_TEXT(title)
			@<Find the destination and title texts@>;

			if (valid) {
				Markdown::create(state->link_references, label, destination, title);
				matched_to = i;
			}
			DISCARD_TEXT(destination)
			DISCARD_TEXT(title)
		}
		DISCARD_TEXT(label)
	}

@<Find the label text@> =
	for (; i<Str::len(X); i++) {
		wchar_t c = Str::get_at(X, i);
		if ((c == '\\') && (Characters::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
			i++; c = Str::get_at(X, i);
		} else if (c == ']') { i++; break; }
		else if (c == '[') { count = 0; break; }
		if ((c == ' ') || (c == '\t') || (c == '\n')) ws_count++;
		PUT_TO(label, c);
		count++;
	}

@<Find the destination and title texts@> =
	wchar_t c = Str::get_at(X, i);
	if (c == '<') {
		i++; c = Str::get_at(X, i);
		while ((c != 0) && (c != '\n')) {
			if ((c == '\\') && (Characters::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
				i++; c = Str::get_at(X, i);
			} else if (c == '>') break;
			PUT_TO(destination, c);
			i++; c = Str::get_at(X, i);
		}
		if (Str::get_at(X, i) == '>') i++; else valid = FALSE;
	} else if ((c != 0) && (Characters::is_control_character(c) == FALSE)) {
		int bl = 0;
		while ((c != 0) && (c != ' ') && (Characters::is_control_character(c) == FALSE)) {
			if ((c == '\\') && (Characters::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
				i++; c = Str::get_at(X, i);
			} else if (c == '(') bl++;
			else if (c == ')') { bl--; if (bl < 0) valid = FALSE; }
			PUT_TO(destination, c);
			i++; c = Str::get_at(X, i);
		}
		if (bl != 0) valid = FALSE;
	} else valid = FALSE;

	ws_count = i;
	while ((Str::get_at(X, i) == ' ') || (Str::get_at(X, i) == '\t')) i++;
	int stop_here = -1;
	if ((valid) && (Str::get_at(X, i) == '\n')) stop_here = i;
	i = MDBlockParser::advance_past_spacing(X, i);
	ws_count = i - ws_count;
	wchar_t quot = 0;
	if (Str::get_at(X, i) == '"') quot = '"';
	if (Str::get_at(X, i) == '\'') quot = '\'';
	if ((ws_count > 0) && (quot)) {
		for (i++; i<Str::len(X); i++) {
			wchar_t c = Str::get_at(X, i);
			if ((c == '\\') && (Characters::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
				i++; c = Str::get_at(X, i);
			} else if (c == quot) break;
			PUT_TO(title, c);
		}
		if (Str::get_at(X, i) == quot) i++; else valid = FALSE;
	}
	while ((Str::get_at(X, i) == ' ') || (Str::get_at(X, i) == '\t')) i++;
	if ((Str::get_at(X, i) != 0) && (Str::get_at(X, i) != '\n')) valid = FALSE;
	i++;
	
	if ((valid == FALSE) && (stop_here >= 0)) { valid = TRUE; i = stop_here+1; }

@h The interstage.
Phase I is now complete except for two tidying-up operations needed for lists.
The first is to group together consecutive list entries which look as if they
belong to the same list; they need the same flavour and the same basic type
(ordered or unordered). We insert |ORDERED_LIST_MIT| or |UNORDERED_LIST_MIT|
items into the tree to hold these.

=
void MDBlockParser::gather_lists(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	for (markdown_item *c = at->down; c; c = c->next)
		MDBlockParser::gather_lists(state, c);
	for (markdown_item *c = at->down, *d = NULL; c; d = c, c = c->next) {
		if (MDBlockParser::in_same_list(c, c)) {
			int type = ORDERED_LIST_MIT;
			if (c->type == UNORDERED_LIST_ITEM_MIT) type = UNORDERED_LIST_MIT;
			markdown_item *list = Markdown::new_item(type);
			if (d) d->next = list; else at->down = list;
			list->down = c;
			while (MDBlockParser::in_same_list(c, c->next)) c = c->next;
			list->next = c->next;
			c->next = NULL;
			c = list;
		}
	}
}

int MDBlockParser::in_same_list(markdown_item *A, markdown_item *B) {
	if ((A) && (B) &&
		(Markdown::get_item_flavour(A)) &&
		(Markdown::get_item_flavour(A) == Markdown::get_item_flavour(B)))
		return TRUE;
	return FALSE;
}

@ In order to be able to detect looseness of lists, we will need to make
sure the white space flags are correct. Why would they be wrong, you ask?
Well, because the new |ORDERED_LIST_MIT| or |UNORDERED_LIST_MIT| items have
only just appeared, so had no opportunity to pick up these flags during Phase I.

=
void MDBlockParser::propagate_white_space_follows(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	for (markdown_item *c = at->down; c; c = c->next)
		MDBlockParser::propagate_white_space_follows(state, c);
	for (markdown_item *c = at->down; c; c = c->next)
		if ((c->next == NULL) && (c->whitespace_follows))
			MDBlockParser::mark_block_with_ws(state, at);
}
