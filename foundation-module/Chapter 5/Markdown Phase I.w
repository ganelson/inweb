[MDBlockParser::] Markdown Phase I.

Phase I of the Markdown parser: reading a series of lines into a tree of
container and leaf blocks.

@h Disclaimer.
Do not call functions in this section directly: use the API in //Markdown//.

@ Parser state.

=
typedef struct md_doc_state {
	struct markdown_item *doc;
	struct text_stream *blanks;
	int code_indent_to_strip; /* measured as a position, not a string index */
	wchar_t fencing_material;
	struct markdown_item *fenced_code;
	int fence_width;
	int fence_sp;
	int HTML_end_condition;
	struct md_links_dictionary *link_references;
	struct markdown_item *containers[100];
	struct markdown_item *current_leaves[100];
	int container_sp;
	int positionals[100];
	int positionals_indent[100];
	int positionals_at[100];
	int positionals_implied[100];
	int positional_values[100];
	wchar_t positional_flavours[100];
	int positional_blank_counts[100];
	int positional_sp;
	CLASS_DEFINITION
} md_doc_state;

md_doc_state *MDBlockParser::initialise(markdown_item *head, md_links_dictionary *dict) {
	md_doc_state *state = CREATE(md_doc_state);

	state->doc = head;
	state->doc->open = TRUE;
	state->code_indent_to_strip = -1;
	state->blanks = Str::new();
	state->fencing_material = 0;
	state->fence_width = 0;
	state->fenced_code = NULL;
	state->fence_sp = 100000000;
	state->HTML_end_condition = 0;
	state->link_references = dict;

	for (int i=0; i < 100; i++) state->current_leaves[i] = NULL;
	for (int i=0; i < 100; i++) state->containers[i] = NULL;
	for (int i=0; i < 100; i++) state->positionals[i] = 0;
	for (int i=0; i < 100; i++) state->positionals_indent[i] = 0;
	for (int i=0; i < 100; i++) state->positionals_at[i] = 0;
	for (int i=0; i < 100; i++) state->positionals_implied[i] = 0;
	for (int i=0; i < 100; i++) state->positional_values[i] = 0;
	for (int i=0; i < 100; i++) state->positional_flavours[i] = 0;
	for (int i=0; i < 100; i++) state->positional_blank_counts[i] = 0;
	
	state->container_sp = 1;
	state->containers[0] = head;

	state->positional_sp = 0;
	return state;
}


void MDBlockParser::debug_positional_stack(OUTPUT_STREAM, md_doc_state *state, int first_implicit_marker) {
	for (int i=0; i<state->positional_sp; i++) {
		if (first_implicit_marker == i) WRITE("! ");
		switch (state->positionals[i]) {
			case BLOCK_QUOTE_MIT: WRITE("blockquote "); break;
			case UNORDERED_LIST_MIT: WRITE("ul "); break;
			case ORDERED_LIST_MIT: WRITE("ol "); break;
			case UNORDERED_LIST_ITEM_MIT: WRITE("(%c) ", state->positional_flavours[i]); break;
			case ORDERED_LIST_ITEM_MIT: WRITE("%d%c ", state->positional_values[i], state->positional_flavours[i]); break;
		}
	}
	if (state->positional_sp > 0) {
		WRITE("[blank=%d] ", state->positional_blank_counts[state->positional_sp - 1]);
		WRITE("[at=%d] ", state->positionals_at[state->positional_sp - 1]);
		WRITE("[min-indent=%d] ", state->positionals_indent[state->positional_sp - 1]);
	} else {
		WRITE("empty\n");
	}
	WRITE("\n");
}

void MDBlockParser::add_to_document(md_doc_state *state, text_stream *line) {
	if (tracing_Markdown_parser) {
		PRINT("=======\nAdding '%S' to tree:\n", line);
		Markdown::debug_subtree(STDOUT, state->doc);
		PRINT("Positional stack carried over: ");
		MDBlockParser::debug_positional_stack(STDOUT, state, -1);
	}
	int explicit_markers = 0, first_implicit_marker = -1;
	int sp = 0, last_explicit_list_marker_sp = 0, last_explicit_list_marker_width = -1;
	tabbed_string_iterator mdw = TabbedStr::new(line, 4);

	int min_indent_to_continue = -1;
	while (TRUE) {
		if (sp > 50) { PRINT("Stack overflow!"); break; }
		if (sp >= state->fence_sp-1) break;
		tabbed_string_iterator copy = mdw;
		int available = TabbedStr::spaces_available(&mdw);
		if (min_indent_to_continue < 0) min_indent_to_continue = available;
		else min_indent_to_continue = 0;
		if ((sp < state->positional_sp) &&
				(state->positionals[sp] != BLOCK_QUOTE_MIT) &&
				((TabbedStr::blank_from_here(&mdw)) ||
					(available >= state->positionals_indent[sp]))) {
				TabbedStr::eat_spaces(state->positionals_indent[sp], &mdw);
				if (first_implicit_marker < 0) first_implicit_marker = sp;
				state->positionals_implied[sp] = TRUE;
				state->positional_flavours[sp] = 0;
				state->positional_values[sp++] = 0;
				continue;
		}
		int interrupts_paragraph = FALSE;
		if (state->current_leaves[PARAGRAPH_MIT])
			interrupts_paragraph = TRUE;
		if ((sp < state->container_sp-1) &&
			((state->containers[sp+1]->type == UNORDERED_LIST_ITEM_MIT) ||
				(state->containers[sp+1]->type == ORDERED_LIST_ITEM_MIT)))
			interrupts_paragraph = FALSE;
		
		if (available < 4) {
			TabbedStr::eat_spaces(available, &mdw);
 			tabbed_string_iterator starts_at = mdw;
			tabbed_string_iterator adv = MDBlockParser::block_quote_marker(starts_at);
			if (TabbedStr::get_position(&adv) > TabbedStr::get_position(&mdw)) {
					TabbedStr::eat_space(&adv);
					int L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&mdw);
					mdw = adv;
					state->positionals[sp] = BLOCK_QUOTE_MIT;
					state->positionals_indent[sp] = min_indent_to_continue + L + TabbedStr::spaces_available(&mdw);
					state->positionals_implied[sp] = FALSE;
					state->positional_blank_counts[sp] = 0;
					state->positionals_at[sp] = TabbedStr::get_position(&starts_at);
					state->positional_flavours[sp] = 0;
					state->positional_values[sp++] = 0;
					explicit_markers++;
					continue;
			}
			wchar_t flavour = 0;
			adv = MDBlockParser::bullet_list_marker(starts_at, &flavour);
			if (TabbedStr::get_position(&adv) > TabbedStr::get_position(&mdw)) {
				wchar_t next = TabbedStr::get_character(&adv);
				if ((next == ' ') || (next == 0)) {
					int orig_L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&mdw);
					TabbedStr::eat_space(&adv);
					int L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&mdw);
					mdw = adv;
					if ((TabbedStr::blank_from_here(&mdw)) && (interrupts_paragraph)) {
						mdw = copy;
					} else {
						last_explicit_list_marker_sp = sp;
						last_explicit_list_marker_width = orig_L;
						state->positionals[sp] = UNORDERED_LIST_ITEM_MIT;
						state->positionals_indent[sp] = min_indent_to_continue + L + TabbedStr::spaces_available(&mdw);
						state->positionals_implied[sp] = FALSE;
						state->positional_blank_counts[sp] = 0;
						state->positionals_at[sp] = TabbedStr::get_position(&starts_at);
						state->positional_flavours[sp] = flavour;
						state->positional_values[sp++] = 0;
						explicit_markers++;
						continue;
					}
				}
			}
			int val = 0;
			adv = MDBlockParser::ordered_list_marker(starts_at, &val, &flavour);
			if (TabbedStr::get_position(&adv) > TabbedStr::get_position(&mdw)) {
				wchar_t next = TabbedStr::get_character(&adv);
				if ((next == ' ') || (next == 0)) {
					int orig_L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&mdw);
					TabbedStr::eat_space(&adv);
					int L = TabbedStr::get_index(&adv) - TabbedStr::get_index(&mdw);
					mdw = adv;
					if (((TabbedStr::blank_from_here(&mdw)) || (val != 1)) && (interrupts_paragraph)) {
						mdw = copy;
					} else {
						last_explicit_list_marker_sp = sp;
						last_explicit_list_marker_width = orig_L;
						state->positionals[sp] = ORDERED_LIST_ITEM_MIT;
						state->positionals_indent[sp] = min_indent_to_continue + L + TabbedStr::spaces_available(&mdw);
						state->positionals_implied[sp] = FALSE;
						state->positional_blank_counts[sp] = 0;
						state->positionals_at[sp] = TabbedStr::get_position(&starts_at);
						state->positional_flavours[sp] = flavour;
						state->positional_values[sp++] = val;
						explicit_markers++;
						continue;
					}
				}
			}
			mdw = copy;
		}
		break;
	}
	int old_psp = state->positional_sp;
	state->positional_sp = sp;

	if (TabbedStr::blank_from_here(&mdw))
		if (state->positionals_implied[sp-1])
			TabbedStr::seek(&mdw,
				state->positionals_at[sp-1] + state->positionals_indent[sp-1]);

	int available = TabbedStr::spaces_available(&mdw);
			if (tracing_Markdown_parser) {
				PRINT("mdw is at %d , available = %d, positionals_at = %d ind = %d\n", TabbedStr::get_index(&mdw), available, state->positionals_at[sp-1], state->positionals_indent[sp-1]);
			}
	int indentation = 0;
	
	if (available >= 4) {
		indentation = 1; available = 4;
		if ((last_explicit_list_marker_width >= 0) &&
			(last_explicit_list_marker_sp == state->positional_sp-1)) {
			if (tracing_Markdown_parser) {
				PRINT("Opening line is code rule applies, and sets pos indent[%d] = %d\n",
					last_explicit_list_marker_sp, last_explicit_list_marker_width + 1);
			}
			state->positionals_indent[last_explicit_list_marker_sp] = last_explicit_list_marker_width + 1;
		}
	}
	if (TabbedStr::blank_from_here(&mdw)) {
		if ((last_explicit_list_marker_width >= 0) &&
			(last_explicit_list_marker_sp == state->positional_sp-1)) {
			if (tracing_Markdown_parser) {
				PRINT("Opening line is empty rule applies, and sets pos indent[%d] = %d\n",
					last_explicit_list_marker_sp, last_explicit_list_marker_width + 1);
			}
			state->positionals_indent[last_explicit_list_marker_sp] = last_explicit_list_marker_width + 1;
			state->positional_blank_counts[last_explicit_list_marker_sp] = 1;
		} else {
			while ((state->positional_sp > 0) &&
					(state->positional_blank_counts[state->positional_sp-1] > 0)) {
				if (tracing_Markdown_parser) {
					PRINT("Blank after blank opening rule applies\n");
				}
				MDBlockParser::mark_block_with_ws(state, state->containers[state->positional_sp]);
				state->positional_sp--;
				sp--;
			}
		}
	}
	TabbedStr::eat_spaces(available, &mdw);
	int initial_spacing = TabbedStr::get_index(&mdw);
	
	if (tracing_Markdown_parser) {
		PRINT("Line '%S' (fence sp = %d)\n", line, state->fence_sp);
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

	if ((state->current_leaves[PARAGRAPH_MIT]) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION]) && (state->positional_sp == state->container_sp-1))
		interpretations[THEMATIC_MDINTERPRETATION] = FALSE;

	int N = 0; for (int i=0; i<20; i++) if (interpretations[i]) N++;

	if ((state->current_leaves[PARAGRAPH_MIT]) && (MDBlockParser::container_will_change(state) == FALSE)) {
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
		int sp = state->positional_sp;
		state->positional_sp = old_psp;
		if ((sp == state->container_sp-1) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION])) @<Line is a setext underline@>;
		@<Line forms piece of paragraph@>;
	} else {
		if (state->current_leaves[PARAGRAPH_MIT])
			MDBlockParser::close_block(state, state->current_leaves[PARAGRAPH_MIT]);
		if ((state->current_leaves[CODE_BLOCK_MIT]) && (interpretations[CODE_BLOCK_MDINTERPRETATION] == FALSE) && (interpretations[WHITESPACE_MDINTERPRETATION] == FALSE))
			MDBlockParser::close_block(state, state->current_leaves[CODE_BLOCK_MIT]);
	}

	MDBlockParser::establish_context(state);
	if ((state->fenced_code) && (state->fence_sp > state->container_sp)) {
		@<Close the code fence@>;
		interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION] = FALSE;
	}
	if (interpretations[HTML_CONTINUATION_MDINTERPRETATION]) @<Line is part of HTML@>;
	if (interpretations[CODE_FENCE_OPEN_MDINTERPRETATION]) @<Line is an opening code fence@>;
	if (interpretations[CODE_FENCE_CLOSE_MDINTERPRETATION]) @<Line is a closing code fence@>;
	if (interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION]) @<Line is part of a fenced code block@>;
	if (interpretations[WHITESPACE_MDINTERPRETATION]) @<Line is whitespace@>;
	if ((state->current_leaves[PARAGRAPH_MIT]) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION])) @<Line is a setext underline@>;
	if (interpretations[ATX_HEADING_MDINTERPRETATION]) @<Line is an ATX heading@>;
	if (interpretations[THEMATIC_MDINTERPRETATION]) @<Line is a thematic break@>;
	if (interpretations[HTML_MDINTERPRETATION]) @<Line opens HTML@>;
	if (interpretations[CODE_BLOCK_MDINTERPRETATION]) @<Line is part of an indented code block@>;
	@<Line forms piece of paragraph@>;
}

@<Line is whitespace@> =
	last_explicit_list_marker_sp = state->container_sp-1;
	int sp = state->container_sp-1;
	if (state->positionals_implied[sp-1]) {
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
			PUT_TO(state->blanks, c);
		}
	PUT_TO(state->blanks, '\n');
	return;
	
@<Line opens HTML@> =
	state->HTML_end_condition = details[HTML_MDINTERPRETATION];
	if (tracing_Markdown_parser) {
		PRINT("enter HTML with end_condition = %d\n", state->HTML_end_condition);
	}
	markdown_item *htmlb = Markdown::new_item(HTML_MIT);
	htmlb->stashed = Str::new();
	MDBlockParser::add_block(state, htmlb);
	state->fence_sp = state->container_sp;	
	@<Add text of line to HTML block@>;
	int ends = FALSE;
	@<Test for HTML end condition@>;
	if (ends) @<End the HTML block@>;
	return;

@<Line is part of HTML@> =
	markdown_item *latest = state->current_leaves[HTML_MIT];
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
	markdown_item *latest = state->current_leaves[HTML_MIT];
	int from = initial_spacing;
	if (state->fence_sp == 1) from = 0;
//WRITE_TO(latest->stashed, "(hey: %d)", state->fence_sp);
	for (int i = from; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');

@<End the HTML block@> =
	markdown_item *latest = state->current_leaves[HTML_MIT];
	state->HTML_end_condition = 0;
	state->fence_sp = 10000000;
	if (latest) MDBlockParser::close_block(state, latest);

@<Test for HTML end condition@> =
	if (state->current_leaves[HTML_MIT] == NULL) {
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
	MDBlockParser::add_block(state, headb);
	return;

@<Line is a setext underline@> =
	wchar_t c = Str::get_at(line, initial_spacing);
	markdown_item *headb = state->current_leaves[PARAGRAPH_MIT];
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
	MDBlockParser::add_block(state, themb);
	return;

@<Line is an opening code fence@> =
	int post_count = details[CODE_FENCE_OPEN_MDINTERPRETATION];
	text_stream *info_string = Str::new();
	MDBlockParser::can_interpret_as(state, line, indentation, initial_spacing, CODE_FENCE_OPEN_MDINTERPRETATION, info_string, NULL);
	wchar_t c = Str::get_at(line, initial_spacing);
	markdown_item *cb = Markdown::new_item(CODE_BLOCK_MIT);
	cb->stashed = Str::new();
	cb->info_string = info_string;
	MDBlockParser::add_block(state, cb);
	state->code_indent_to_strip = TabbedStr::get_position(&mdw);
	state->fencing_material = c;
	state->fence_width = post_count;
	state->fenced_code = cb;
	state->fence_sp = state->container_sp;
	return;

@<Line is a closing code fence@> =
	@<Close the code fence@>;
	return;

@<Close the code fence@> =
	state->fencing_material = 0; state->fence_width = 0; state->fenced_code = NULL;
	state->fence_sp = 10000000;

@<Line is part of an indented code block@> =
	markdown_item *latest = state->current_leaves[CODE_BLOCK_MIT];
	if (latest) {
		WRITE_TO(latest->stashed, "%S", state->blanks);
		Str::clear(state->blanks);
	} else {
		markdown_item *cb = Markdown::new_item(CODE_BLOCK_MIT);
		cb->stashed = Str::new();
		state->code_indent_to_strip = -1;
		MDBlockParser::add_block(state, cb);
		latest = cb;
	}
	while (TabbedStr::at_whole_character(&mdw) == FALSE) {
		PUT_TO(latest->stashed, ' ');
		TabbedStr::advance(&mdw);
	}
	for (int i = TabbedStr::get_index(&mdw); i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');
	return;

@<Line is part of a fenced code block@> =
	if ((state->code_indent_to_strip >= 0) &&
		(state->code_indent_to_strip < TabbedStr::get_position(&mdw)))
		TabbedStr::seek(&mdw, state->code_indent_to_strip);
	while (TabbedStr::at_whole_character(&mdw) == FALSE) {
		PUT_TO(state->fenced_code->stashed, ' ');
		TabbedStr::advance(&mdw);
	}
	for (int i = TabbedStr::get_index(&mdw); i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(state->fenced_code->stashed, c);
	}
	PUT_TO(state->fenced_code->stashed, '\n');
	return;

@<Line forms piece of paragraph@> =
	markdown_item *parb = state->current_leaves[PARAGRAPH_MIT];
	if ((parb) && (parb->type == PARAGRAPH_MIT)) {
		WRITE_TO(parb->stashed, "\n");
		for (int i = initial_spacing; i<Str::len(line); i++) {
			wchar_t c = Str::get_at(line, i);
			PUT_TO(parb->stashed, c);
		}
	} else {
		markdown_item *parb = Markdown::new_item(PARAGRAPH_MIT);
		parb->stashed = Str::new();
		MDBlockParser::add_block(state, parb);
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
			if (MDBlockParser::block_open(state, PARAGRAPH_MIT) == FALSE) return FALSE;
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
			if ((which == CODE_FENCE_OPEN_MDINTERPRETATION) && (state->fenced_code)) return FALSE;
			if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (state->fenced_code == NULL)) return FALSE;
			text_stream *info_string = text_details;
			wchar_t c = Str::get_at(line, initial_spacing);
			if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (state->fencing_material != c)) return FALSE;
			if ((c == '`') || (c == '~')) {
				int post_count = 0;
				int j = initial_spacing;
				for (; j<Str::len(line); j++) {
					wchar_t d = Str::get_at(line, j);
					if (d == c) post_count++;
					else break;
				}
				if (post_count >= 3) {
					if ((which == CODE_FENCE_CLOSE_MDINTERPRETATION) && (post_count < state->fence_width)) return FALSE;
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
			if (MDBlockParser::block_open(state, PARAGRAPH_MIT)) return FALSE;
			if (indentation > 0) return TRUE;
			return FALSE;
		case FENCED_CODE_BLOCK_MDINTERPRETATION:
			if (state->fenced_code) return TRUE;
			return FALSE;
		case LAZY_CONTINUATION_MDINTERPRETATION:
			return FALSE;
		case HTML_CONTINUATION_MDINTERPRETATION:
			if ((MDBlockParser::block_open(state, HTML_MIT)) &&
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
	if (state->positional_sp + 1 > state->container_sp) return TRUE;

	for (int sp = 0; sp<state->positional_sp; sp++) {
		if (state->positionals[sp] != state->containers[sp+1]->type) { /* PRINT("X%d\n", sp); */ return TRUE; }
		if (state->positionals_implied[sp] == FALSE) {
			if (state->containers[sp+1]->type != BLOCK_QUOTE_MIT) {
				 /* PRINT("Y%d\n", sp); */ return TRUE;
			}
		}
	}

	if (state->positional_sp + 1 < state->container_sp) {
		if (state->positional_sp > 0) {
			int p_top = state->positionals[state->positional_sp-1];
			int s_top = state->containers[state->container_sp-1]->type;
			if ((p_top == s_top) && (p_top != BLOCK_QUOTE_MIT)) return TRUE;
		}
	}

	return FALSE;
}

void MDBlockParser::establish_context(md_doc_state *state) {
	int wipe_down_to_pos = state->positional_sp;
	for (int sp = 0; sp<state->positional_sp; sp++) {
		if (sp == state->container_sp-1) { wipe_down_to_pos = sp; break; }
		int p_type = state->positionals[sp];
		int s_type = state->containers[sp+1]->type;
		if (p_type != s_type) { wipe_down_to_pos = sp; break; }
		if ((p_type != BLOCK_QUOTE_MIT) && (state->positionals_implied[sp] == FALSE)) { wipe_down_to_pos = sp; break; }
	}

	if (tracing_Markdown_parser) {
		PRINT("psp = %d, sp = %d:", state->positional_sp, state->container_sp);
		if (0 == wipe_down_to_pos) PRINT(" WIPE");
		for (int i=0; (i<state->container_sp-1) || (i<state->positional_sp); i++) {
			PRINT(" p:%d s:%d;", (i<state->positional_sp)?state->positionals[i]:0,
				(i<state->container_sp-1)?(state->containers[i+1]->type):0);
			if (i+1 == wipe_down_to_pos) PRINT(" WIPE");
		}
		PRINT("\n");
	}

	for (int sp = state->container_sp-1; sp>=wipe_down_to_pos+1; sp--) {
		MDBlockParser::close_block(state, state->containers[sp]);
		state->containers[sp] = NULL;
	}

	for (int sp = wipe_down_to_pos; sp<state->positional_sp; sp++) {
		markdown_item *newbq = Markdown::new_item(state->positionals[sp]);
		Markdown::add_to(newbq, state->containers[sp]);
		MDBlockParser::open_block(state, newbq);
		state->containers[sp+1] = newbq;
		Markdown::set_item_number_and_flavour(newbq, state->positional_values[sp], state->positional_flavours[sp]);
	}
	state->container_sp = state->positional_sp+1;
	if (tracing_Markdown_parser) {
		PRINT("Container stack:");
		for (int sp = 0; sp<state->container_sp; sp++) {
			PRINT(" -> "); Markdown::debug_item(STDOUT, state->containers[sp]);
		}
		PRINT("\n");
	}
}

void MDBlockParser::mark_block_with_ws(md_doc_state *state, markdown_item *block) {
	if (block) {
		if (tracing_Markdown_parser) {
			PRINT("Mark as whitespace-following: "); Markdown::debug_item(STDOUT, block);
		}
		block->whitespace_follows = TRUE;
	}
}

void MDBlockParser::open_block(md_doc_state *state, markdown_item *block) {
	if (block->open == NOT_APPLICABLE) {
		block->open = TRUE;
		MDBlockParser::close_block(state, state->current_leaves[block->type]);
		state->current_leaves[block->type] = block;
	}
}

markdown_item *MDBlockParser::add_block(md_doc_state *state, markdown_item *block) {
	block->open = TRUE;
	Markdown::add_to(block, state->containers[state->container_sp-1]);
	if (state->current_leaves[block->type])
		MDBlockParser::close_block(state, state->current_leaves[block->type]);
	state->current_leaves[block->type] = block;
	Str::clear(state->blanks);
	return block;
}

void MDBlockParser::change_type(md_doc_state *state, markdown_item *block, int t) {
	if (block == NULL) internal_error("no block");
	if (tracing_Markdown_parser) {
		PRINT("Change type: "); Markdown::debug_item(STDOUT, block);
	}
	if (block->open) state->current_leaves[block->type] = NULL;
	block->type = t;
	if (block->open) state->current_leaves[t] = block;
	if (tracing_Markdown_parser) {
		PRINT(" -> "); Markdown::debug_item(STDOUT, block); PRINT("\n");
	}
}

int MDBlockParser::block_open(md_doc_state *state, int type) {
	if (state->current_leaves[type]) {
		return TRUE;
	}
	return FALSE;
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

tabbed_string_iterator MDBlockParser::block_quote_marker(tabbed_string_iterator mdw) {
	if (TabbedStr::get_character(&mdw) != '>') return mdw;
	TabbedStr::advance(&mdw);
	return mdw;
}

tabbed_string_iterator MDBlockParser::bullet_list_marker(tabbed_string_iterator mdw, wchar_t *flavour) {
	tabbed_string_iterator old = mdw;
	if (MDBlockParser::thematic_marker(mdw.line, TabbedStr::get_index(&mdw))) return old;
	wchar_t c = TabbedStr::get_character(&mdw);
	if ((c == '-') || (c == '+') || (c == '*')) {
		TabbedStr::advance(&mdw);
		*flavour = c;
	}
	return mdw;
}

tabbed_string_iterator MDBlockParser::ordered_list_marker(tabbed_string_iterator mdw, int *v, wchar_t *flavour) {
	tabbed_string_iterator old = mdw;
	if (MDBlockParser::thematic_marker(mdw.line, TabbedStr::get_index(&mdw))) return old;
	wchar_t c = TabbedStr::get_character(&mdw);
	int dc = 0, val = 0;
	while (Characters::is_ASCII_digit(c)) {
		val = 10*val + (int) (c - '0');
		TabbedStr::advance(&mdw); dc++;
		c = TabbedStr::get_character(&mdw);
	}
	if ((dc < 1) || (dc > 9)) return old;
	c = TabbedStr::get_character(&mdw);
	if ((c == '.') || (c == ')')) {
		*flavour = c;
		*v = val;
		TabbedStr::advance(&mdw);
		return mdw;
	}
	return old;
}

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

@

=
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
	state->current_leaves[at->type] = NULL;
	MDBlockParser::remove_link_references(state, at);
}

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
