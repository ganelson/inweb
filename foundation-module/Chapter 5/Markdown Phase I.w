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

md_doc_state *MDBlockParser::initialise(markdown_item *head, md_links_dictionary *dict) {
	md_doc_state *state = CREATE(md_doc_state);

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
	int list_item_value;       /* for example, 7 for |7) | or |7. | */
	wchar_t list_item_flavour; /* for example, |')'| for |7) | and |'.'| for |7. | */

	int continues_from_earlier_line;
	int blank_counts;
} positional_marker;

void MDBlockParser::clear_marker(positional_marker *marker) {
	marker->item_type = 0; /* which is not a valid item type: this will never be used */
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
	md_doc_state *state, int first_implicit_marker) {
	for (int i=1; i<MAX_MARKDOWN_CONTAINER_DEPTH; i++) {
		if (first_implicit_marker == i) WRITE("! ");
		if (i == state->marker_sp) WRITE("[top] ");
		if ((i > state->marker_sp) && (state->markers[i].item_type == 0)) break;
		MDBlockParser::debug_marker(OUT, &(state->markers[i]), (i == state->marker_sp-1)?TRUE:FALSE);
	}
	if (state->marker_sp == 0) WRITE("empty");
	WRITE("\n");
}

void MDBlockParser::debug_marker(OUTPUT_STREAM, positional_marker *marker, int in_full) {
	if (marker == NULL) { WRITE("<no-marker>"); return; }
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
	if (MDBlockParser::thematic_marker(line_scanner.line, TabbedStr::get_index(&line_scanner))) return old;
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
int MDBlockParser::thematic_marker(text_stream *line, int initial_spacing) {
	wchar_t c = Str::get_at(line, initial_spacing);
	if ((c == '-') || (c == '_') || (c == '*')) {
		int ornament_count = 1;
		for (int j=initial_spacing+1; j<Str::len(line); j++) {
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

@h The main function.
So, now we're off to the races.

=
void MDBlockParser::add_to_document(md_doc_state *state, text_stream *line) {
	if (tracing_Markdown_parser) {
		PRINT("=======\nAdding '%S' to tree:\n", line);
		Markdown::debug_subtree(STDOUT, state->tree_head);
		PRINT("Positional stack carried over: ");
		MDBlockParser::debug_positional_stack(STDOUT, state, -1);
	}
	int first_implicit_marker = -1;
	int sp = 1, last_explicit_list_marker_sp = 1, last_explicit_list_marker_width = -1;
	tabbed_string_iterator line_scanner = TabbedStr::new(line, 4);

	int min_indent_to_continue = -1;
	while (TRUE) {
		if (sp >= MAX_MARKDOWN_CONTAINER_DEPTH) break;
		if (sp >= state->temporary_marker_limit) break;
		tabbed_string_iterator copy = line_scanner;
		int available = TabbedStr::spaces_available(&line_scanner);
		if (min_indent_to_continue < 0) min_indent_to_continue = available;
		else min_indent_to_continue = 0;
		positional_marker *marker = MDBlockParser::marker_at(state, sp);
		if ((sp < state->marker_sp) && (marker) && (marker->item_type != BLOCK_QUOTE_MIT) &&
			((TabbedStr::blank_from_here(&line_scanner)) || (available >= marker->indent))) {
				TabbedStr::eat_spaces(state->markers[sp].indent, &line_scanner);
				if (first_implicit_marker < 0) first_implicit_marker = sp;
				marker->continues_from_earlier_line = TRUE;
				sp++;
				continue;
		}
		int interrupts_paragraph = FALSE;
		if (MDBlockParser::latest_paragraph(state))
			interrupts_paragraph = TRUE;
		if ((sp < state->container_sp) &&
			((state->containers[sp]->type == UNORDERED_LIST_ITEM_MIT) ||
				(state->containers[sp]->type == ORDERED_LIST_ITEM_MIT)))
			interrupts_paragraph = FALSE;
		
		if (available < 4) {
			TabbedStr::eat_spaces(available, &line_scanner);
 			tabbed_string_iterator starts_at = line_scanner;
			tabbed_string_iterator adv = MDBlockParser::block_quote_marker(starts_at);
			if (TabbedStr::get_position(&adv) > TabbedStr::get_position(&line_scanner)) {
					TabbedStr::eat_space(&adv);
					int L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&line_scanner);
					line_scanner = adv;
					positional_marker *bq_m = MDBlockParser::new_marker_at(state, sp, BLOCK_QUOTE_MIT);
					bq_m->at = TabbedStr::get_position(&starts_at);
					bq_m->indent = min_indent_to_continue + L + TabbedStr::spaces_available(&line_scanner);
					sp++;
					continue;
			}
			wchar_t flavour = 0;
			adv = MDBlockParser::bullet_list_marker(starts_at, &flavour);
			if (TabbedStr::get_position(&adv) > TabbedStr::get_position(&line_scanner)) {
				wchar_t next = TabbedStr::get_character(&adv);
				if ((next == ' ') || (next == 0)) {
					int orig_L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&line_scanner);
					TabbedStr::eat_space(&adv);
					int L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&line_scanner);
					line_scanner = adv;
					if ((TabbedStr::blank_from_here(&line_scanner)) && (interrupts_paragraph)) {
						line_scanner = copy;
					} else {
						last_explicit_list_marker_sp = sp;
						last_explicit_list_marker_width = orig_L;
						positional_marker *li_m = MDBlockParser::new_marker_at(state, sp, UNORDERED_LIST_ITEM_MIT);
						li_m->at = TabbedStr::get_position(&starts_at);
						li_m->indent = min_indent_to_continue + L + TabbedStr::spaces_available(&line_scanner);
						li_m->list_item_flavour = flavour;
						sp++;
						continue;
					}
				}
			}
			int val = 0;
			adv = MDBlockParser::ordered_list_marker(starts_at, &val, &flavour);
			if (TabbedStr::get_position(&adv) > TabbedStr::get_position(&line_scanner)) {
				wchar_t next = TabbedStr::get_character(&adv);
				if ((next == ' ') || (next == 0)) {
					int orig_L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&line_scanner);
					TabbedStr::eat_space(&adv);
					int L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&line_scanner);
					line_scanner = adv;
					if (((TabbedStr::blank_from_here(&line_scanner)) || (val != 1)) && (interrupts_paragraph)) {
						line_scanner = copy;
					} else {
						last_explicit_list_marker_sp = sp;
						last_explicit_list_marker_width = orig_L;
						positional_marker *li_m = MDBlockParser::new_marker_at(state, sp, ORDERED_LIST_ITEM_MIT);
						li_m->at = TabbedStr::get_position(&starts_at);
						li_m->indent = min_indent_to_continue + L + TabbedStr::spaces_available(&line_scanner);
						li_m->list_item_flavour = flavour;
						li_m->list_item_value = val;
						sp++;
						continue;
					}
				}
			}
			line_scanner = copy;
		}
		break;
	}
	int old_psp = state->marker_sp;
	state->marker_sp = sp;

	if (TabbedStr::blank_from_here(&line_scanner))
		if (state->markers[sp-1].continues_from_earlier_line)
			TabbedStr::seek(&line_scanner,
				state->markers[sp-1].at + state->markers[sp-1].indent);

	int available = TabbedStr::spaces_available(&line_scanner);
			if (tracing_Markdown_parser) {
				PRINT("line_scanner is at %d , available = %d, positionals_at = %d ind = %d\n", TabbedStr::get_index(&line_scanner), available, state->markers[sp-1].at, state->markers[sp-1].indent);
			}
	int indentation = 0;
	
	if (available >= 4) {
		indentation = 1; available = 4;
		if ((last_explicit_list_marker_width >= 0) &&
			(last_explicit_list_marker_sp == state->marker_sp-1)) {
			if (tracing_Markdown_parser) {
				PRINT("Opening line is code rule applies, and sets pos indent[%d] = %d\n",
					last_explicit_list_marker_sp, last_explicit_list_marker_width + 1);
			}
			state->markers[last_explicit_list_marker_sp].indent = last_explicit_list_marker_width + 1;
		}
	}
	if (TabbedStr::blank_from_here(&line_scanner)) {
		if ((last_explicit_list_marker_width >= 0) &&
			(last_explicit_list_marker_sp == state->marker_sp-1)) {
			if (tracing_Markdown_parser) {
				PRINT("Opening line is empty rule applies, and sets pos indent[%d] = %d\n",
					last_explicit_list_marker_sp, last_explicit_list_marker_width + 1);
			}
			state->markers[last_explicit_list_marker_sp].indent = last_explicit_list_marker_width + 1;
			state->markers[last_explicit_list_marker_sp].blank_counts = 1;
		} else {
			while ((state->marker_sp > 1) &&
					(state->markers[state->marker_sp-1].blank_counts > 0)) {
				if (tracing_Markdown_parser) {
					PRINT("Blank after blank opening rule applies\n");
				}
				MDBlockParser::mark_block_with_ws(state, state->containers[state->marker_sp-1]);
				state->marker_sp--;
				sp--;
			}
		}
	}
	TabbedStr::eat_spaces(available, &line_scanner);
	int initial_spacing = TabbedStr::get_index(&line_scanner);
	
	if (tracing_Markdown_parser) {
		PRINT("Line '%S' ", line);
		if (state->temporary_marker_limit < 100000000)
			PRINT("(marker limit %d)", state->temporary_marker_limit);
		PRINT("\n");
		PRINT("New positional stack: ");
		MDBlockParser::debug_positional_stack(STDOUT, state, first_implicit_marker);
		PRINT("Line has indentation = %d, then: '", indentation);
		for (int i=initial_spacing; i<Str::len(line); i++)
			PUT_TO(STDOUT, Str::get_at(line, i));
		PRINT("'\n");
	}

	int interpretations[20], details[20];
	for (int i=0; i<20; i++)
		interpretations[i] =
			MDBlockParser::can_interpret_as(state, line, indentation, initial_spacing, i, NULL, &(details[i]));

	if ((MDBlockParser::latest_paragraph(state)) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION]) && (state->marker_sp == state->container_sp))
		interpretations[THEMATIC_MDINTERPRETATION] = FALSE;

	int N = 0; for (int i=0; i<20; i++) if (interpretations[i]) N++;

	if ((MDBlockParser::latest_paragraph(state)) && (MDBlockParser::container_will_change(state) == FALSE)) {
		int lazy = TRUE;
		for (int i=0; i<20; i++)
			if (interpretations[i]) {
				if (i == SETEXT_UNDERLINE_MDINTERPRETATION) continue;
				if ((i == HTML_MDINTERPRETATION) && (details[i] == MISCPAIR_MDHTMLC)) continue;
				lazy = FALSE;
			}
		interpretations[LAZY_CONTINUATION_MDINTERPRETATION] = lazy;
	}

	if (tracing_Markdown_parser) {
		PRINT("interpretations: ");
		int c = 0;
		for (int i=0; i<20; i++) {
			if (interpretations[i]) {
				c++;
				switch (i) {
					case WHITESPACE_MDINTERPRETATION: PRINT("white? "); break;
					case THEMATIC_MDINTERPRETATION: PRINT("thematic? "); break;
					case ATX_HEADING_MDINTERPRETATION: PRINT("atx? "); break;
					case SETEXT_UNDERLINE_MDINTERPRETATION: PRINT("setext? "); break;
					case HTML_MDINTERPRETATION: PRINT("html-open? "); break;
					case CODE_FENCE_OPEN_MDINTERPRETATION: PRINT("fence-open? "); break;
					case CODE_FENCE_CLOSE_MDINTERPRETATION: PRINT("fence-close? "); break;
					case CODE_BLOCK_MDINTERPRETATION: PRINT("code? "); break;
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

	if (interpretations[LAZY_CONTINUATION_MDINTERPRETATION]) {
		int sp = state->marker_sp;
		state->marker_sp = old_psp;
		if ((sp == state->container_sp) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION])) @<Line is a setext underline@>;
		@<Line forms piece of paragraph@>;
	} else {
		if (MDBlockParser::latest_paragraph(state))
			MDBlockParser::close_block(state, MDBlockParser::latest_paragraph(state));
		if ((MDBlockParser::latest_code_block(state)) && (interpretations[CODE_BLOCK_MDINTERPRETATION] == FALSE) && (interpretations[WHITESPACE_MDINTERPRETATION] == FALSE))
			MDBlockParser::close_block(state, MDBlockParser::latest_code_block(state));
	}

	MDBlockParser::establish_context(state);
	if ((state->fencing.material != 0) && (state->container_sp < state->temporary_marker_limit)) {
		@<Close the code fence@>;
		interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION] = FALSE;
	}
	if (interpretations[HTML_CONTINUATION_MDINTERPRETATION]) @<Line is part of HTML@>;
	if (interpretations[CODE_FENCE_OPEN_MDINTERPRETATION]) @<Line is an opening code fence@>;
	if (interpretations[CODE_FENCE_CLOSE_MDINTERPRETATION]) @<Line is a closing code fence@>;
	if (interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION]) @<Line is part of a fenced code block@>;
	if (interpretations[WHITESPACE_MDINTERPRETATION]) @<Line is whitespace@>;
	if ((MDBlockParser::latest_paragraph(state)) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION])) @<Line is a setext underline@>;
	if (interpretations[ATX_HEADING_MDINTERPRETATION]) @<Line is an ATX heading@>;
	if (interpretations[THEMATIC_MDINTERPRETATION]) @<Line is a thematic break@>;
	if (interpretations[HTML_MDINTERPRETATION]) @<Line opens HTML@>;
	if (interpretations[CODE_BLOCK_MDINTERPRETATION]) @<Line is part of an indented code block@>;
	@<Line forms piece of paragraph@>;
}

@<Line is whitespace@> =
	last_explicit_list_marker_sp = state->container_sp-1;
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

	if (indentation > 0)
		for (int i=initial_spacing; i<Str::len(line); i++) {
			wchar_t c = Str::get_at(line, i);
			PUT_TO(state->blank_matter_after_receiver, c);
		}
	PUT_TO(state->blank_matter_after_receiver, '\n');
	return;
	
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

@<Add text of line to HTML block@> =
	markdown_item *latest = MDBlockParser::latest_HTML_block(state);
	int from = initial_spacing;
	if (state->temporary_marker_limit == 1) from = 0;
	for (int i = from; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');

@<End the HTML block@> =
	markdown_item *latest = MDBlockParser::latest_HTML_block(state);
	MDBlockParser::clear_HTML_data(state);
	MDBlockParser::lift_marker_limit(state);
	if (latest) MDBlockParser::close_block(state, latest);

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

@ "ATX" was the precursor to Markdown, by Aaron Swartz, and the term "ATX heading"
preserves its memory. (And indeed his: hounded to death by an overzealous Federal
prosecutor in 2013, who considered his Internet activism criminal, Swartz deserves
to be remembered for pioneering work on RSS, which enabled podcasting, on Reddit
and numerous other early Internet developments.)

@<Line is an ATX heading@> =
	int hash_count = details[ATX_HEADING_MDINTERPRETATION];
	markdown_item *headb = Markdown::new_item(HEADING_MIT);
	Markdown::set_heading_level(headb, hash_count);
	text_stream *H = Str::new();
	headb->stashed = H;
	for (int i=initial_spacing+hash_count; i<Str::len(line); i++) {
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

@<Line is a setext underline@> =
	wchar_t c = Str::get_at(line, initial_spacing);
	markdown_item *headb = MDBlockParser::latest_paragraph(state);
	if (headb) {
		MDBlockParser::remove_link_references(state, headb);
		if (headb->type == EMPTY_MIT) @<Line forms piece of paragraph@>;
		MDBlockParser::change_type(state, headb, HEADING_MIT);
		if (c == '=') Markdown::set_heading_level(headb, 1);
		else Markdown::set_heading_level(headb, 2);
		Str::trim_white_space(headb->stashed);
	}
	return;

@<Line is a thematic break@> =
	markdown_item *themb = Markdown::new_item(THEMATIC_MIT);
	MDBlockParser::turn_over_a_new_leaf(state, themb);
	return;

@<Line is an opening code fence@> =
	int post_count = details[CODE_FENCE_OPEN_MDINTERPRETATION];
	text_stream *info_string = Str::new();
	MDBlockParser::can_interpret_as(state, line, indentation, initial_spacing, CODE_FENCE_OPEN_MDINTERPRETATION, info_string, NULL);
	wchar_t c = Str::get_at(line, initial_spacing);
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

@<Line is a closing code fence@> =
	@<Close the code fence@>;
	return;

@<Close the code fence@> =
	MDBlockParser::clear_fencing_data(state);
	MDBlockParser::lift_marker_limit(state);

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

@<Line forms piece of paragraph@> =
	markdown_item *parb = MDBlockParser::latest_paragraph(state);
	if ((parb) && (parb->type == PARAGRAPH_MIT)) {
		WRITE_TO(parb->stashed, "\n");
		for (int i = initial_spacing; i<Str::len(line); i++) {
			wchar_t c = Str::get_at(line, i);
			PUT_TO(parb->stashed, c);
		}
	} else {
		markdown_item *parb = Markdown::new_item(PARAGRAPH_MIT);
		parb->stashed = Str::new();
		MDBlockParser::turn_over_a_new_leaf(state, parb);
		for (int i=initial_spacing; i<Str::len(line); i++)
			PUT_TO(parb->stashed, Str::get_at(line, i));
	}
	return;

@

@e WHITESPACE_MDINTERPRETATION from 1
@e THEMATIC_MDINTERPRETATION
@e ATX_HEADING_MDINTERPRETATION
@e SETEXT_UNDERLINE_MDINTERPRETATION
@e HTML_MDINTERPRETATION
@e CODE_FENCE_OPEN_MDINTERPRETATION
@e CODE_FENCE_CLOSE_MDINTERPRETATION
@e CODE_BLOCK_MDINTERPRETATION
@e FENCED_CODE_BLOCK_MDINTERPRETATION
@e LAZY_CONTINUATION_MDINTERPRETATION
@e HTML_CONTINUATION_MDINTERPRETATION

=
int MDBlockParser::can_interpret_as(md_doc_state *state, text_stream *line,
	int indentation, int initial_spacing, int which, text_stream *text_details, int *int_detail) {
	switch (which) {
		case WHITESPACE_MDINTERPRETATION:
			for (int i=initial_spacing; i<Str::len(line); i++)
				if ((Str::get_at(line, i) != ' ') && (Str::get_at(line, i) != '\t'))
					return FALSE;
			return TRUE;
		case THEMATIC_MDINTERPRETATION:
			if (indentation > 0) return FALSE;
			return MDBlockParser::thematic_marker(line, initial_spacing);
		case ATX_HEADING_MDINTERPRETATION: {
			if (indentation > 0) return FALSE;
			int hash_count = 0;
			while (Str::get_at(line, initial_spacing+hash_count) == '#') hash_count++;
			if ((hash_count >= 1) && (hash_count <= 6) &&
				((Str::get_at(line, initial_spacing+hash_count) == ' ') ||
					(Str::get_at(line, initial_spacing+hash_count) == '\t') ||
					(Str::get_at(line, initial_spacing+hash_count) == 0))) {
				if (int_detail) *int_detail = hash_count;
				return TRUE;
			}
			return FALSE;
		}
		case SETEXT_UNDERLINE_MDINTERPRETATION: {
			if (MDBlockParser::latest_paragraph(state) == NULL) return FALSE;
			if (indentation > 0) return FALSE;
			wchar_t c = Str::get_at(line, initial_spacing);
			if ((c == '-') || (c == '=')) {
				int ornament_count = 1, extraneous = 0;
				int j=initial_spacing+1;
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
		}
		case CODE_FENCE_OPEN_MDINTERPRETATION:
		case CODE_FENCE_CLOSE_MDINTERPRETATION: {
			if (indentation > 0) return FALSE;
			if ((which == CODE_FENCE_OPEN_MDINTERPRETATION) && (state->fencing.material != 0)) return FALSE;
			if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (state->fencing.material == 0)) return FALSE;
			text_stream *info_string = text_details;
			wchar_t c = Str::get_at(line, initial_spacing);
			if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (state->fencing.material != c)) return FALSE;
			if ((c == '`') || (c == '~')) {
				int post_count = 0;
				int j = initial_spacing;
				for (; j<Str::len(line); j++) {
					wchar_t d = Str::get_at(line, j);
					if (d == c) post_count++;
					else break;
				}
				if (post_count >= 3) {
					if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (post_count < state->fencing.width)) return FALSE;
					int ambiguous = FALSE, count = 0, escaped = FALSE;
					for (; j<Str::len(line); j++) {
						wchar_t d = Str::get_at(line, j);
						if ((escaped == FALSE) && (d == '\\') && (Characters::is_ASCII_punctuation(Str::get_at(line, j+1))))
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
				}
			}
			return FALSE;
		}
		case HTML_MDINTERPRETATION:
			if (indentation > 0) return FALSE;
			@<Parse as HTML start line@>;
		case CODE_BLOCK_MDINTERPRETATION:
			if (MDBlockParser::latest_paragraph(state)) return FALSE;
			if (indentation > 0) return TRUE;
			return FALSE;
		case FENCED_CODE_BLOCK_MDINTERPRETATION:
			if (state->fencing.material != 0) return TRUE;
			return FALSE;
		case LAZY_CONTINUATION_MDINTERPRETATION:
			return FALSE;
		case HTML_CONTINUATION_MDINTERPRETATION:
			if ((MDBlockParser::latest_HTML_block(state)) &&
				(state->HTML_end_condition != 0)) return TRUE;
			return FALSE;
		default: return FALSE;
	}
}

@ There are, appallingly, seven possible pairs of start/end condition for
HTML blocks.

@e PRE_MDHTMLC from 1
@e COMMENT_MDHTMLC
@e QUERY_MDHTMLC
@e PLING_MDHTMLC
@e CDATA_MDHTMLC
@e MISCSINGLE_MDHTMLC
@e MISCPAIR_MDHTMLC

@<Parse as HTML start line@> =
	wchar_t c = Str::get_at(line, initial_spacing);
	if (c != '<') return FALSE;

	int cond = 0;
	
	int i = initial_spacing+1;
	TEMPORARY_TEXT(tag)
	for (; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		if ((c == ' ') || (c == '\t') || (c == '>')) break;
		PUT_TO(tag, c);
	}
	if ((Str::eq_insensitive(tag, I"pre")) ||
		(Str::eq_insensitive(tag, I"script")) ||
		(Str::eq_insensitive(tag, I"style")) ||
		(Str::eq_insensitive(tag, I"textarea"))) {
		cond = PRE_MDHTMLC; goto HTML_Start_Found;
	}
	
	if (Str::begins_with(tag, I"!--")) {
		cond = COMMENT_MDHTMLC; goto HTML_Start_Found;
	}
	
	
	if (Str::begins_with(tag, I"?")) {
		cond = QUERY_MDHTMLC; goto HTML_Start_Found;
	}
	
	if (Str::begins_with(tag, I"![CDATA[")) {
		cond = CDATA_MDHTMLC; goto HTML_Start_Found;
	}
	
	
	if (Str::begins_with(tag, I"!")) {
		cond = PLING_MDHTMLC; goto HTML_Start_Found;
	}
	

	
	if (Str::get_first_char(tag) == '/') Str::delete_first_character(tag);
	for (int i=0; i<Str::len(tag); i++) {
		if (Str::get_at(tag, i) == '>') { Str::put_at(tag, i, 0); break; }
		if ((Str::get_at(tag, i) == '/') && (Str::get_at(tag, i+1) == '>')) { Str::put_at(tag, i, 0); break; }
	}
	
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
		cond = MISCSINGLE_MDHTMLC; goto HTML_Start_Found;
	}
	
	
	if (cond == 0) {
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
			cond = MISCPAIR_MDHTMLC; goto HTML_Start_Found;
		}
	}

	if (cond != 0) {
		HTML_Start_Found:
		if (int_detail) *int_detail = cond;
		return TRUE;
	}

	return FALSE;

@

=
int MDBlockParser::container_will_change(md_doc_state *state) {
	if (state->marker_sp > state->container_sp) return TRUE;

	for (int sp = 1; sp<state->marker_sp; sp++) {
		if (state->markers[sp].item_type != state->containers[sp]->type) { /* PRINT("X%d\n", sp); */ return TRUE; }
		if (state->markers[sp].continues_from_earlier_line == FALSE) {
			if (state->containers[sp]->type != BLOCK_QUOTE_MIT) {
				 /* PRINT("Y%d\n", sp); */ return TRUE;
			}
		}
	}

	if (state->marker_sp < state->container_sp) {
		if (state->marker_sp > 1) {
			int p_top = state->markers[state->marker_sp-1].item_type;
			int s_top = state->containers[state->container_sp-1]->type;
			if ((p_top == s_top) && (p_top != BLOCK_QUOTE_MIT)) return TRUE;
		}
	}

	return FALSE;
}

void MDBlockParser::establish_context(md_doc_state *state) {
	int wipe_down_to_pos = state->marker_sp;
	for (int sp = 1; sp<state->marker_sp; sp++) {
		if (sp == state->container_sp) { wipe_down_to_pos = sp; break; }
		int p_type = state->markers[sp].item_type;
		int s_type = state->containers[sp]->type;
		if (p_type != s_type) { wipe_down_to_pos = sp; break; }
		if ((p_type != BLOCK_QUOTE_MIT) && (state->markers[sp].continues_from_earlier_line == FALSE)) { wipe_down_to_pos = sp; break; }
	}

	if (tracing_Markdown_parser) {
		PRINT("psp = %d, sp = %d:", state->marker_sp, state->container_sp);
		if (1 == wipe_down_to_pos) PRINT(" WIPE");
		for (int i=1; (i<state->container_sp) || (i<state->marker_sp); i++) {
			PRINT(" p:%d s:%d;", (i<state->marker_sp)?state->markers[i].item_type:0,
				(i<state->container_sp)?(state->containers[i]->type):0);
			if (i+1 == wipe_down_to_pos) PRINT(" WIPE");
		}
		PRINT("\n");
	}

	for (int sp = state->container_sp-1; sp >= wipe_down_to_pos; sp--) {
		MDBlockParser::close_block(state, state->containers[sp]);
		state->containers[sp] = NULL;
	}

	for (int sp = wipe_down_to_pos; sp<state->marker_sp; sp++) {
		markdown_item *newbq = Markdown::new_item(state->markers[sp].item_type);
		Markdown::add_to(newbq, state->containers[sp-1]);
		MDBlockParser::open_block(state, newbq);
		state->containers[sp] = newbq;
		Markdown::set_item_number_and_flavour(newbq, state->markers[sp].list_item_value, state->markers[sp].list_item_flavour);
	}
	state->container_sp = state->marker_sp;
	if (tracing_Markdown_parser) {
		PRINT("Container stack:");
		for (int sp = 0; sp<state->container_sp; sp++) {
			PRINT(" -> "); Markdown::debug_item(STDOUT, state->containers[sp]);
		}
		PRINT("\n");
	}
}

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

@

=

int MDBlockParser::can_remove_link_references(md_doc_state *state, markdown_item *at) {
	return MDBlockParser::remove_link_references_inner(state, at, FALSE);
}

void MDBlockParser::remove_link_references(md_doc_state *state, markdown_item *at) {
	MDBlockParser::remove_link_references_inner(state, at, TRUE);
}

int MDBlockParser::remove_link_references_inner(md_doc_state *state, markdown_item *at, int go_ahead) {
	int original_type = at->type;
	if (original_type == PARAGRAPH_MIT) {
		int matched_to = 0;
		while (matched_to >= 0) {
			matched_to = -1;
			TEMPORARY_TEXT(X)
			Str::clear(X);
			for (int j=0; j<Str::len(at->stashed); j++)
				PUT_TO(X, Str::get_at(at->stashed, j));
			@<Try this one@>;
			DISCARD_TEXT(X)
			if (matched_to > 0) {
				if (go_ahead == FALSE) return TRUE;
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

@<Try this one@> =
	int i = 0;
	while ((Str::get_at(X, i) == ' ') || (Str::get_at(X, i) == '\t')) i++;
	if (Str::get_at(X, i) == '[') {
		i++;
		int count = 0, ws_count = 0;
		TEMPORARY_TEXT(label)
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
		if ((Str::get_at(X, i) == ':') && (count <= 999) && (ws_count < count)) {
			i++;
			i = MDBlockParser::advance_past_spacing(X, i);
			
			int valid = TRUE;
			
			TEMPORARY_TEXT(destination)
			TEMPORARY_TEXT(title)
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

			if (valid) {
				if (go_ahead) {
					Markdown::create(state->link_references, label, destination, title);
				}
				matched_to = i;
			}
			DISCARD_TEXT(destination)
			DISCARD_TEXT(title)
		}
		DISCARD_TEXT(label)
	}

@

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

void MDBlockParser::propagate_white_space_follows(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	for (markdown_item *c = at->down; c; c = c->next)
		MDBlockParser::propagate_white_space_follows(state, c);
	for (markdown_item *c = at->down; c; c = c->next)
		if ((c->next == NULL) && (c->whitespace_follows))
			MDBlockParser::mark_block_with_ws(state, at);
}

int MDBlockParser::in_same_list(markdown_item *A, markdown_item *B) {
	if ((A) && (B) &&
		(Markdown::get_item_flavour(A)) &&
		(Markdown::get_item_flavour(A) == Markdown::get_item_flavour(B)))
		return TRUE;
	return FALSE;
}
