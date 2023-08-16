[MarkdownParser::] Markdown Parsing.

To parse a simplified form of the Markdown markup notation.

@h Parsing.
The user should call |MarkdownParser::inline(text)| on the body of a paragraph of
running text which may have Markdown notation in it, and obtains a tree.
No errors are ever issued: a unique feature of Markdown is that all inputs
are always legal.

=
int tracing_Markdown_parser = FALSE;
void MarkdownParser::set_tracing(int state) {
	tracing_Markdown_parser = state;
}

markdown_item *MarkdownParser::passage(text_stream *text) {
	if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Begin Markdown parse, phase I\n");
	md_doc_state state;
	state.doc = Markdown::new_item(DOCUMENT_MIT);
	state.doc->open = TRUE;
	state.code_indent_to_strip = 0;
	state.blanks = Str::new();
	state.fencing_material = 0;
	state.fence_width = 0;
	state.fenced_code = NULL;
	state.HTML_end_condition = 0;
	state.link_references = Dictionaries::new(32, FALSE);

	for (int i=0; i < 100; i++) state.current_leaves[i] = NULL;
	for (int i=0; i < 100; i++) state.containers[i] = NULL;
	for (int i=0; i < 100; i++) state.positionals[i] = 0;
	for (int i=0; i < 100; i++) state.positionals_indent[i] = 0;
	for (int i=0; i < 100; i++) state.positionals_implied[i] = 0;
	for (int i=0; i < 100; i++) state.positional_values[i] = 0;
	
	state.container_sp = 1;
	state.containers[0] = state.doc;

	state.positional_sp = 0;

	TEMPORARY_TEXT(line)
	LOOP_THROUGH_TEXT(pos, text) {
		wchar_t c = Str::get(pos);
		if (c == '\n') {
			MarkdownParser::add_to_document(&state, line);
			Str::clear(line);
		} else {
			PUT_TO(line, c);
		}
	}
	if (Str::len(line) > 0) MarkdownParser::add_to_document(&state, line);
	MarkdownParser::close_block(&state, state.doc);
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "======\nGathering lists\n");
	}
	MarkdownParser::gather_lists(&state, state.doc);
	MarkdownParser::propagate_white_space_follows(&state, state.doc);
	state.doc->open = FALSE;
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "======\nPhase II\n");
		Markdown::debug_subtree(STDOUT, state.doc);
		WRITE_TO(STDOUT, "\nRecursing to work out inlines:\n");
	}
	MarkdownParser::inline_recursion(&state, state.doc);
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "======\nFinal tree:\n");
		Markdown::debug_subtree(STDOUT, state.doc);
		WRITE_TO(STDOUT, "End Markdown parse\n======\n");
	}
	return state.doc;
}

typedef struct md_doc_state {
	struct markdown_item *doc;
	struct text_stream *blanks;
	int code_indent_to_strip;
	wchar_t fencing_material;
	struct markdown_item *fenced_code;
	int fence_width;
	int fence_sp;
	int HTML_end_condition;
	struct dictionary *link_references;
	struct markdown_item *containers[100];
	struct markdown_item *current_leaves[100];
	int container_sp;
	int positionals[100];
	int positionals_indent[100];
	int positionals_implied[100];
	int positional_values[100];
	int positional_sp;
} md_doc_state;

typedef struct md_doc_reference {
	struct text_stream *destination;
	struct text_stream *title;
	CLASS_DEFINITION
} md_doc_reference;

typedef struct md_whitespacer {
	struct text_stream *line;
	int pos;
	int spaces_in_hand;
	int spaces_read;
} md_whitespacer;

md_whitespacer MarkdownParser::begin_eating_space_from(text_stream *line, int pos) {
	md_whitespacer mdw;
	mdw.line = line;
	mdw.pos = pos;
	mdw.spaces_in_hand = 0;
	mdw.spaces_read = 0;
	return mdw;
}

int MarkdownParser::eat_space(md_whitespacer *mdw) {
	if (mdw == NULL) internal_error("no mdw");
	if (mdw->spaces_in_hand > 0) {
		mdw->spaces_in_hand--; return TRUE;
	}
	wchar_t c = Str::get_at(mdw->line, mdw->pos);
// PRINT("EAT AT %d = %c\n", mdw->pos, c);
	if (c == ' ') { mdw->pos++; mdw->spaces_read++; return TRUE; }
	if (c == '\t') {
		mdw->pos++;
		mdw->spaces_in_hand = mdw->spaces_in_hand + 3 - (mdw->spaces_read)%4;
		return TRUE;
	}
	return FALSE;
}

int MarkdownParser::eat_spaces(int N, md_whitespacer *mdw) {
	md_whitespacer copy = *mdw;
	for (int i=1; i<=N; i++)
		if (MarkdownParser::eat_space(mdw) == FALSE) {
			*mdw = copy;
			return FALSE;
		}
	return TRUE;
}

int MarkdownParser::spaces_available(md_whitespacer *mdw) {
	md_whitespacer copy = *mdw;
	int total = 0;
	while (MarkdownParser::eat_space(&copy)) total++;
	return total;
}

int MarkdownParser::blank_from_here(md_whitespacer *mdw) {
	for (int i=mdw->pos; i<Str::len(mdw->line); i++) {
		wchar_t c = Str::get_at(mdw->line, i);
		if ((c != ' ') && (c != '\t')) return FALSE;
	}
	return TRUE;
}

void MarkdownParser::add_to_document(md_doc_state *state, text_stream *line) {
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "=======\nAdding '%S' to tree:\n", line);
		Markdown::debug_subtree(STDOUT, state->doc);
	}
	if ((MarkdownParser::block_open(state, HTML_MIT)) &&
		(state->HTML_end_condition != 0)) @<Line is part of HTML@>;

	int explicit_markers = 0, first_implicit_marker = -1;
	int sp = 0, last_explicit_list_marker_sp = 0;
	md_whitespacer mdw = MarkdownParser::begin_eating_space_from(line, 0);

	int min_indent_to_continue = -1;
	while (TRUE) {
		if (sp > 50) { PRINT("Stack overflow!"); break; }
		if ((state->fenced_code) && (sp >= state->fence_sp-1)) break;
		md_whitespacer copy = mdw;
		int available = MarkdownParser::spaces_available(&mdw);
		if (min_indent_to_continue < 0) min_indent_to_continue = available;
		else min_indent_to_continue = 0;
		if ((sp < state->positional_sp) &&
				(state->positionals[sp] != BLOCK_QUOTE_MIT) &&
				((MarkdownParser::blank_from_here(&mdw)) ||
					(available >= state->positionals_indent[sp]))) {
				MarkdownParser::eat_spaces(state->positionals_indent[sp], &mdw);
				if (first_implicit_marker < 0) first_implicit_marker = sp;
				state->positionals_implied[sp] = TRUE;
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
			MarkdownParser::eat_spaces(available, &mdw);
 //PRINT("FROM %d\n", mdw.pos);
			int L = MarkdownParser::block_quote_marker(line, mdw.pos);
			if (L > 0) {
//				if ((Str::get_at(line, mdw.pos+L) == ' ') || (Str::get_at(line, mdw.pos+L) == 0)) {
					if (Str::get_at(line, mdw.pos+L) == ' ') L++;
					mdw.pos += L;
					state->positionals[sp] = BLOCK_QUOTE_MIT;
					state->positionals_indent[sp] = min_indent_to_continue + L + MarkdownParser::spaces_available(&mdw);
					state->positionals_implied[sp] = FALSE;
					state->positional_values[sp++] = 0;
					explicit_markers++;
					continue;
//				}
			}
			int val = 0;
			L = MarkdownParser::bullet_list_marker(line, mdw.pos, &val);
			if (L > 0) {
				if ((Str::get_at(line, mdw.pos+L) == ' ') || (Str::get_at(line, mdw.pos+L) == 0)) {
					if (Str::get_at(line, mdw.pos+L) == ' ') L++;
// PRINT("At %d,  L=%d, sa=%d\n", mdw.pos, L, MarkdownParser::spaces_available(&mdw));
//if (interrupts_paragraph) PRINT("Interrupts\n");
					mdw.pos += L;
					if ((MarkdownParser::blank_from_here(&mdw)) && (interrupts_paragraph)) {
						mdw = copy;
					} else {
						state->positionals[sp] = UNORDERED_LIST_ITEM_MIT;
						state->positionals_indent[sp] = min_indent_to_continue + L + MarkdownParser::spaces_available(&mdw);
						state->positionals_implied[sp] = FALSE;
						state->positional_values[sp++] = val;
						explicit_markers++;
						last_explicit_list_marker_sp = sp;
						continue;
					}
				}
			}
			L = MarkdownParser::ordered_list_marker(line, mdw.pos, &val);
			if (L > 0) {
				if ((Str::get_at(line, mdw.pos+L) == ' ') || (Str::get_at(line, mdw.pos+L) == 0)) {
					if (Str::get_at(line, mdw.pos+L) == ' ') L++;
//PRINT("At %d,  L=%d, bfh=%d\n", mdw.pos, L, MarkdownParser::blank_from_here(&mdw));
//if (interrupts_paragraph) PRINT("Interrupts with val = %d\n", val);
					mdw.pos += L;
					if (((MarkdownParser::blank_from_here(&mdw)) || (val != 1)) && (interrupts_paragraph)) {
						mdw = copy;
					} else {
	//PRINT("GHre!\n");
						state->positionals[sp] = ORDERED_LIST_ITEM_MIT;
						state->positionals_indent[sp] = min_indent_to_continue + L + MarkdownParser::spaces_available(&mdw);
						state->positionals_implied[sp] = FALSE;
						state->positional_values[sp++] = val;
						last_explicit_list_marker_sp = sp;
						continue;
					}
				}
			}
			mdw = copy;
		}
		break;
	}
	state->positional_sp = sp;

	int available = MarkdownParser::spaces_available(&mdw);
	int indentation = 0;
	if (available >= 4) { indentation = 1; available = 4; }
	MarkdownParser::eat_spaces(available, &mdw);
	int left_code_gutter = mdw.pos;
	int initial_spacing = mdw.pos;
	
	if (tracing_Markdown_parser) {
		PRINT("Line '%S' (length %d)\n", line, Str::len(line));
		for (int i=0; i<state->positional_sp; i++) {
			if (first_implicit_marker == i) PRINT("! ");
			switch (state->positionals[i]) {
				case BLOCK_QUOTE_MIT: PRINT("blockquote "); break;
				case UNORDERED_LIST_MIT: PRINT("ul "); break;
				case ORDERED_LIST_MIT: PRINT("ol "); break;
				case UNORDERED_LIST_ITEM_MIT: PRINT("(*) "); break;
				case ORDERED_LIST_ITEM_MIT: PRINT("(%d) ", state->positional_values[i]); break;
			}
		}
		if (state->positional_sp > 0) {
			PRINT("[min-indent=%d]\n", state->positionals_indent[state->positional_sp - 1]);
		}
		PRINT("Line has indentation = %d, then: '", indentation);
		for (int i=initial_spacing; i<Str::len(line); i++)
			PUT_TO(STDOUT, Str::get_at(line, i));
		PRINT("'\n");
	}

	int interpretations[20], details[20];
	for (int i=0; i<20; i++) {
		interpretations[i] =
			MarkdownParser::can_interpret_as(state, line, indentation, initial_spacing, i, NULL, &(details[i]));
	}
	
	if ((state->current_leaves[PARAGRAPH_MIT]) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION]) && (state->positional_sp == state->container_sp-1))
		interpretations[THEMATIC_MDINTERPRETATION] = FALSE;

	int N = 0; for (int i=0; i<20; i++) if (interpretations[i]) N++;

	if ((state->current_leaves[PARAGRAPH_MIT]) && (MarkdownParser::container_will_change(state) == FALSE) &&
		((N == 0) || ((N == 1) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION])))) {
		
		interpretations[LAZY_CONTINUATION_MDINTERPRETATION] = TRUE;
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
					case HTML_MDINTERPRETATION: PRINT("html? "); break;
					case CODE_FENCE_OPEN_MDINTERPRETATION: PRINT("fence-open? "); break;
					case CODE_FENCE_CLOSE_MDINTERPRETATION: PRINT("fence-close? "); break;
					case CODE_BLOCK_MDINTERPRETATION: PRINT("code? "); break;
					case FENCED_CODE_BLOCK_MDINTERPRETATION: PRINT("fenced-code? "); break;
					case LAZY_CONTINUATION_MDINTERPRETATION: PRINT("lazy-continuation? "); break;
				}
			}
		}
		if (c == 0) PRINT("(none)");
		PRINT("\n");
		if (MarkdownParser::container_will_change(state)) PRINT("Container change coming\n");
	}

	if (interpretations[LAZY_CONTINUATION_MDINTERPRETATION]) {
		if ((state->positional_sp == state->container_sp-1) && (interpretations[SETEXT_UNDERLINE_MDINTERPRETATION])) @<Line is a setext underline@>;
		@<Line forms piece of paragraph@>;
	} else {
		if (state->current_leaves[PARAGRAPH_MIT])
			MarkdownParser::close_block(state, state->current_leaves[PARAGRAPH_MIT]);
		if ((state->current_leaves[CODE_BLOCK_MIT]) && (interpretations[CODE_BLOCK_MDINTERPRETATION] == FALSE) && (interpretations[WHITESPACE_MDINTERPRETATION] == FALSE))
			MarkdownParser::close_block(state, state->current_leaves[CODE_BLOCK_MIT]);
	}

	MarkdownParser::establish_context(state);
	if ((state->fenced_code) && (state->fence_sp > state->container_sp)) {
		@<Close the code fence@>;
		interpretations[FENCED_CODE_BLOCK_MDINTERPRETATION] = FALSE;
	}

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
	if (state->containers[sp]->type != BLOCK_QUOTE_MIT)
	for (sp = last_explicit_list_marker_sp; sp<state->container_sp; sp++) {
		if (state->containers[sp]->down) {
			for (markdown_item *ch = state->containers[sp]->down; ch; ch = ch->next)
				if (ch->next == NULL)
					ch->whitespace_follows = TRUE;
		} else {
			state->containers[sp]->whitespace_follows = TRUE;
		}
	}
	switch (state->HTML_end_condition) {
		case MISCSINGLE_MDHTMLC:
		case MISCPAIR_MDHTMLC:
			state->HTML_end_condition = 0;
			break;
	}
	if (indentation > 0)
		for (int i=left_code_gutter; i<Str::len(line); i++) {
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
	MarkdownParser::add_block(state, htmlb);
	@<Add text of line to HTML block@>;
	@<Test for HTML end condition@>;
	return;

@<Line is part of HTML@> =
	@<Add text of line to HTML block@>;
	@<Test for HTML end condition@>;
	return;

@<Add text of line to HTML block@> =
	markdown_item *latest = state->current_leaves[HTML_MIT];
	for (int i = 0; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');

@<Test for HTML end condition@> =
	if (tracing_Markdown_parser) {
		PRINT("test '%S' for HTML_end_condition = %d\n", line, state->HTML_end_condition);
	}
	int ends = FALSE;
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
		case MISCSINGLE_MDHTMLC: break;
		case MISCPAIR_MDHTMLC: break;
	}
	if (tracing_Markdown_parser) {
		PRINT("test outcome: %s\n", (ends)?"yes":"no");
	}
	if (ends) {
		state->HTML_end_condition = 0;
		MarkdownParser::close_block(state, state->current_leaves[HTML_MIT]);
	}

@<Line is an ATX heading@> =
	int hash_count = details[ATX_HEADING_MDINTERPRETATION];
	markdown_item *headb = Markdown::new_item(HEADING_MIT);
	headb->details = hash_count;
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
	MarkdownParser::add_block(state, headb);
	return;

@<Line is a setext underline@> =
	wchar_t c = Str::get_at(line, initial_spacing);
	markdown_item *headb = state->current_leaves[PARAGRAPH_MIT];
	if (headb) {
		MarkdownParser::remove_link_references(state, headb);
		if (headb->type == LINK_REF_MIT) @<Line forms piece of paragraph@>;
		MarkdownParser::change_type(state, headb, HEADING_MIT);
		if (c == '=') headb->details = 1; else headb->details = 2;
		Str::trim_white_space(headb->stashed);
	}
	return;

@<Line is a thematic break@> =
	markdown_item *themb = Markdown::new_item(THEMATIC_MIT);
	MarkdownParser::add_block(state, themb);
	return;

@<Line is an opening code fence@> =
	int post_count = details[CODE_FENCE_OPEN_MDINTERPRETATION];
	text_stream *info_string = Str::new();
	MarkdownParser::can_interpret_as(state, line, indentation, initial_spacing, CODE_FENCE_OPEN_MDINTERPRETATION, info_string, NULL);
	wchar_t c = Str::get_at(line, initial_spacing);
	markdown_item *cb = Markdown::new_item(CODE_BLOCK_MIT);
	cb->stashed = Str::new();
	cb->info_string = info_string;
	MarkdownParser::add_block(state, cb);
	state->code_indent_to_strip = initial_spacing;
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

@<Line is part of an indented code block@> =
	markdown_item *latest = state->current_leaves[CODE_BLOCK_MIT];
	if (latest) {
		WRITE_TO(latest->stashed, "%S", state->blanks);
		Str::clear(state->blanks);
	} else {
		markdown_item *cb = Markdown::new_item(CODE_BLOCK_MIT);
		cb->stashed = Str::new();
		state->code_indent_to_strip = -1;
		MarkdownParser::add_block(state, cb);
		latest = cb;
	}
	for (int i=left_code_gutter; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		PUT_TO(latest->stashed, c);
	}
	PUT_TO(latest->stashed, '\n');
	return;

@<Line is part of a fenced code block@> =
	int from = state->code_indent_to_strip;
	if (from > initial_spacing) from = initial_spacing;
	for (int i = from; i<Str::len(line); i++) {
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
		MarkdownParser::add_block(state, parb);
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

=
int MarkdownParser::can_interpret_as(md_doc_state *state, text_stream *line,
	int indentation, int initial_spacing, int which, text_stream *text_details, int *int_detail) {
	switch (which) {
		case WHITESPACE_MDINTERPRETATION:
			for (int i=initial_spacing; i<Str::len(line); i++)
				if ((Str::get_at(line, i) != ' ') && (Str::get_at(line, i) != '\t'))
					return FALSE;
			return TRUE;
		case THEMATIC_MDINTERPRETATION:
			if (indentation > 0) return FALSE;
			return MarkdownParser::thematic_marker(line, initial_spacing);
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
			if (MarkdownParser::block_open(state, PARAGRAPH_MIT) == FALSE) return FALSE;
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
					int ambiguous = FALSE, count = 0;
					for (; j<Str::len(line); j++) {
						wchar_t d = Str::get_at(line, j);
						if ((d == '`') && (c == d)) ambiguous = TRUE;
						PUT_TO(info_string, d); count++;
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
			if (MarkdownParser::block_open(state, PARAGRAPH_MIT)) return FALSE;
			if (indentation > 0) return TRUE;
			return FALSE;
		case FENCED_CODE_BLOCK_MDINTERPRETATION:
			if (state->fenced_code) return TRUE;
			return FALSE;
		case LAZY_CONTINUATION_MDINTERPRETATION:
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
	
	
	if (Str::begins_with(tag, I"!")) {
		cond = PLING_MDHTMLC; goto HTML_Start_Found;
	}
	

	if (Str::begins_with(tag, I"![CDATA[")) {
		cond = CDATA_MDHTMLC; goto HTML_Start_Found;
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
		int valid = TRUE, closing = FALSE;
		if (Str::get_first_char(tag) == '/') { closing = TRUE; Str::delete_first_character(tag); }
		TEMPORARY_TEXT(tag_name)
		int i = 0;
		for (; i<Str::len(tag); i++) {
			wchar_t c = Str::get_at(tag, i);
			if ((Markdown::is_ASCII_letter(c)) ||
				((i > 0) && ((Markdown::is_ASCII_digit(c)) || (c == '-'))))
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
				i = MarkdownParser::advance_past_spacing(tag, i);
				c = Str::get_at(tag, i);
				if ((c == '_') || (c == ':') || (Markdown::is_ASCII_letter(c))) {
					i++; c = Str::get_at(tag, i);
					while ((c == '_') || (c == ':') || (c == '.') || (c == '-') ||
						(Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c))) {
						i++; c = Str::get_at(tag, i);
					}
					i = MarkdownParser::advance_past_spacing(tag, i);
					if (Str::get_at(tag, i) == '=') {
						i = MarkdownParser::advance_past_spacing(tag, i);
						wchar_t c = Str::get_at(tag, i);
						if (c == '\'') {
							i++; c = Str::get_at(tag, i);
							while ((c) && (c != '\'')) {
								i++; c = Str::get_at(tag, i);
							}
							if (c == 0) valid = FALSE;
						} else if (c == '"') {
							i++; c = Str::get_at(tag, i);
							while ((c) && (c != '"')) {
								i++; c = Str::get_at(tag, i);
							}
							if (c == 0) valid = FALSE;
						} else {
							int nc = 0;
							while ((c != ' ') && (c != '\t') && (c != '\n') && (c != '"') &&
								(c != '\'') && (c != '=') && (c != '<') && (c != '>') && (c != '`')) {
								nc++; i++; c = Str::get_at(tag, i);
							}
							if (nc == 0) valid = FALSE;
						}
						i = MarkdownParser::advance_past_spacing(tag, i);
					}
				} else break;
			}
		}
		if ((closing == FALSE) && (Str::get_at(tag, i) == '/')) i++;
		if (Str::get_at(tag, i) != '>') valid = FALSE;
		i = MarkdownParser::advance_past_spacing(tag, i);
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

@ This is supposed to perform Unicode case fold, but in fact just does a
toupper.

=
void MarkdownParser::normalise_label(text_stream *label) {
	TEMPORARY_TEXT(normal)
	for (int i=0, ws = FALSE; i<Str::len(label); i++) {
		wchar_t c = Str::get_at(label, i);
		if ((c == ' ') || (c == '\t') || (c == '\n')) {
			ws = TRUE; continue;
		} else if (ws) {
			PUT_TO(normal, ' ');
		}
		ws = FALSE;
		if ((c >= 0x03B1) && (c <= 0x03C9)) PUT_TO(normal, c - 0x20);
		else if (c == 0x00DF) WRITE_TO(normal, "SS");
		else if (c == 0x1E9E) WRITE_TO(normal, "SS");
		else PUT_TO(normal, Characters::toupper(c));
	}
	Str::clear(label); WRITE_TO(label, "%S", normal);
	DISCARD_TEXT(normal)
}

int MarkdownParser::container_will_change(md_doc_state *state) {
/*
PRINT("psp = %d, sp = %d: ", state->positional_sp, state->container_sp);
for (int i=0; (i<state->container_sp-1) || (i<state->positional_sp); i++) {
	PRINT("p:%d s:%d; ", (i<state->positional_sp)?state->positionals[i]:0,
		(i<state->container_sp-1)?(state->containers[i+1]->type):0);
}
PRINT("\n");
*/
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

void MarkdownParser::establish_context(md_doc_state *state) {
// Want to find the first deviation now.

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
		MarkdownParser::close_block(state, state->containers[sp]);
		state->containers[sp] = NULL;
	}

// And now build up from there.

	for (int sp = wipe_down_to_pos; sp<state->positional_sp; sp++) {
				markdown_item *newbq = Markdown::new_item(state->positionals[sp]);
				Markdown::add_to(newbq, state->containers[sp]);
				MarkdownParser::open_block(state, newbq);
				state->containers[sp+1] = newbq;
				newbq->details = state->positional_values[sp];
	}
	state->container_sp = state->positional_sp+1;
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "Container stack:");
		for (int sp = 0; sp<state->container_sp; sp++) {
			WRITE_TO(STDOUT, " -> "); Markdown::debug_item(STDOUT, state->containers[sp]);
		}
		WRITE_TO(STDOUT, "\n");
	}
}

void MarkdownParser::open_block(md_doc_state *state, markdown_item *block) {
	if (block->open == NOT_APPLICABLE) {
		block->open = TRUE;
		MarkdownParser::close_block(state, state->current_leaves[block->type]);
		state->current_leaves[block->type] = block;
	}
}

markdown_item *MarkdownParser::add_block(md_doc_state *state, markdown_item *block) {
	block->open = TRUE;
	Markdown::add_to(block, state->containers[state->container_sp-1]);
	if (state->current_leaves[block->type])
		MarkdownParser::close_block(state, state->current_leaves[block->type]);
	state->current_leaves[block->type] = block;
	Str::clear(state->blanks);
	return block;
}

void MarkdownParser::change_type(md_doc_state *state, markdown_item *block, int t) {
	if (block == NULL) internal_error("no block");
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "Change type: "); Markdown::debug_item(STDOUT, block);
	}
	if (block->open) state->current_leaves[block->type] = NULL;
	block->type = t;
	if (block->open) state->current_leaves[t] = block;
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, " -> "); Markdown::debug_item(STDOUT, block); WRITE_TO(STDOUT, "\n");
	}
}

int MarkdownParser::block_open(md_doc_state *state, int type) {
	if (state->current_leaves[type]) {
//		if (Str::len(state->blanks) > 0) return -1;
		return TRUE;
	}
	return FALSE;
}

int MarkdownParser::advance_past_spacing(text_stream *tag, int i) {
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

int MarkdownParser::block_quote_marker(text_stream *line, int at) {
	if (Str::get_at(line, at) != '>') return 0;
	return 1;
}

int MarkdownParser::bullet_list_marker(text_stream *line, int at, int *v) {
	if (MarkdownParser::thematic_marker(line, at)) return 0;
	wchar_t c = Str::get_at(line, at);
	if ((c == '-') || (c == '+') || (c == '*')) {
		*v = c; return 1;
	}
	return 0;
}

int MarkdownParser::ordered_list_marker(text_stream *line, int at, int *v) {
	if (MarkdownParser::thematic_marker(line, at)) return 0;
	wchar_t c = Str::get_at(line, at);
	int dc = 0, val = 0;
	while (Markdown::is_ASCII_digit(c)) {
		val = 10*val + (int) (c - '0');
		at++; dc++;
		c = Str::get_at(line, at);
	}
	if ((dc < 1) || (dc > 9)) return 0;
	c = Str::get_at(line, at);
	if ((c == '.') || (c == ')')) {
		if (c == ')') val = -1-val;
		*v = val; return dc+1;
	}
	return 0;
}

int MarkdownParser::thematic_marker(text_stream *line, int initial_spacing) {
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
void MarkdownParser::close_block(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	if (at->open != TRUE) return;
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "Closing: "); Markdown::debug_item(STDOUT, at); WRITE_TO(STDOUT, "\n");
		STREAM_INDENT(STDOUT);
	}
	at->open = FALSE;
	for (markdown_item *ch = at->down; ch; ch = ch->next)
		MarkdownParser::close_block(state, ch);
	if (tracing_Markdown_parser) {
		STREAM_OUTDENT(STDOUT);
	}
	state->current_leaves[at->type] = NULL;
	MarkdownParser::remove_link_references(state, at);
}

int MarkdownParser::can_remove_link_references(md_doc_state *state, markdown_item *at) {
	return MarkdownParser::remove_link_references_inner(state, at, FALSE);
}

void MarkdownParser::remove_link_references(md_doc_state *state, markdown_item *at) {
	MarkdownParser::remove_link_references_inner(state, at, TRUE);
}

int MarkdownParser::remove_link_references_inner(md_doc_state *state, markdown_item *at, int go_ahead) {
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
					MarkdownParser::change_type(state, at, LINK_REF_MIT);
					return TRUE;
				}
			}
		}
	}
	return FALSE;
/*			
			text_stream *A = Str::new();
			for (int j=pos + matched_to; j<Str::len(at->stashed); j++)
				PUT_TO(A, Str::get_at(at->stashed, j));
			Str::truncate(at->stashed, pos+matched_to);
			if (Str::len(A) 
				MarkdownParser::change_type(state, at, LINK_REF_MIT);
			if (matched_to < Str::len(at->stashed)) {
				if (Str::is_whitespace(A) == FALSE) {
					Str::trim_white_space(A);
					markdown_item *newp = Markdown::new_item(original_type);
					newp->stashed = A;
					if (tracing_Markdown_parser) {
						WRITE_TO(STDOUT, "Splitting off: ");
						Markdown::debug_item(STDOUT, newp);
						WRITE_TO(STDOUT, "\n");
					}
					MarkdownParser::open_block(state, newp);
					newp->next = at->next;
					at->next = newp;
					MarkdownParser::close_block(state, newp);
				}
				
			}
		} 
	}
*/
}

@<Try this one@> =
	int i = 0;
	while ((Str::get_at(X, i) == ' ') || (Str::get_at(X, i) == '\t')) i++;
	if (Str::get_at(X, i) == '[') {
//WRITE_TO(STDOUT, "X = <%S>\n", X);
		i++;
		int count = 0, ws_count = 0;
		TEMPORARY_TEXT(label)
		for (; i<Str::len(X); i++) {
			wchar_t c = Str::get_at(X, i);
			if ((c == '\\') && (Markdown::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
				i++; c = Str::get_at(X, i);
			} else if (c == ']') { i++; break; }
			else if (c == '[') { count = 0; break; }
			if ((c == ' ') || (c == '\t') || (c == '\n')) ws_count++;
			PUT_TO(label, c);
			count++;
		}
//WRITE_TO(STDOUT, "label = <%S>, i = %d %c %d %d\n", label, i, Str::get_at(X, i), count, ws_count);
		if ((Str::get_at(X, i) == ':') && (count <= 999) && (ws_count < count)) {
			i++;
			i = MarkdownParser::advance_past_spacing(X, i);
			
			int valid = TRUE;
//WRITE_TO(STDOUT, "dest at %d %c, valid = %d\n", i, Str::get_at(X, i), valid);
			
			TEMPORARY_TEXT(destination)
			TEMPORARY_TEXT(title)
			wchar_t c = Str::get_at(X, i);
			if (c == '<') {
				i++; c = Str::get_at(X, i);
				while ((c != 0) && (c != '\n')) {
					if ((c == '\\') && (Markdown::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
						i++; c = Str::get_at(X, i);
					} else if (c == '>') break;
					PUT_TO(destination, c);
					i++; c = Str::get_at(X, i);
				}
				if (Str::get_at(X, i) == '>') i++; else valid = FALSE;
			} else if ((c != 0) && (Markdown::is_control_character(c) == FALSE)) {
				int bl = 0;
				while ((c != 0) && (c != ' ') && (Markdown::is_control_character(c) == FALSE)) {
					if ((c == '\\') && (Markdown::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
						i++; c = Str::get_at(X, i);
					} else if (c == '(') bl++;
					else if (c == ')') { bl--; if (bl < 0) valid = FALSE; }
					PUT_TO(destination, c);
					i++; c = Str::get_at(X, i);
				}
				if (bl != 0) valid = FALSE;
			} else valid = FALSE;

//WRITE_TO(STDOUT, "pretitle at %d %c, valid = %d\n", i, Str::get_at(X, i), valid);
			ws_count = i;
//			c = Str::get_at(X, i);
//			while ((c == ' ') || (c == '\t')) {
//				i++, ws_count++; c = Str::get_at(X, i);
//			}
			while ((Str::get_at(X, i) == ' ') || (Str::get_at(X, i) == '\t')) i++;
			int stop_here = -1;
			if ((valid) && (Str::get_at(X, i) == '\n')) stop_here = i;
			i = MarkdownParser::advance_past_spacing(X, i);
			ws_count = i - ws_count;
//WRITE_TO(STDOUT, "title at %d %c, valid = %d\n", i, Str::get_at(X, i), valid);
			wchar_t quot = 0;
			if (Str::get_at(X, i) == '"') quot = '"';
			if (Str::get_at(X, i) == '\'') quot = '\'';
			if ((ws_count > 0) && (quot)) {
				for (i++; i<Str::len(X); i++) {
					wchar_t c = Str::get_at(X, i);
					if ((c == '\\') && (Markdown::is_ASCII_punctuation(Str::get_at(X, i+1)))) {
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
//WRITE_TO(STDOUT, "end at %d %c, valid = %d\n", i, Str::get_at(X, i), valid);

			if (valid) {
				if (go_ahead) {
					MarkdownParser::normalise_label(label);
					if (tracing_Markdown_parser) {
						WRITE_TO(STDOUT, "[%S] := %S", label, destination);
						if (Str::len(title) > 0) 
							WRITE_TO(STDOUT, " with title %S", title);
						WRITE_TO(STDOUT, "\n");
					}
					md_doc_reference *link_ref = CREATE(md_doc_reference);
					link_ref->destination = Str::duplicate(destination);
					link_ref->title = Str::duplicate(title);			
					if (Dictionaries::find(state->link_references, label) == NULL) {
						dict_entry *de = Dictionaries::create(state->link_references, label);
						if (de) de->value = link_ref;
					}
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
void MarkdownParser::gather_lists(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	for (markdown_item *c = at->down; c; c = c->next)
		MarkdownParser::gather_lists(state, c);
	for (markdown_item *c = at->down, *d = NULL; c; d = c, c = c->next) {
		if (MarkdownParser::in_same_list(c, c)) {
			int type = ORDERED_LIST_MIT;
			if (c->type == UNORDERED_LIST_ITEM_MIT) type = UNORDERED_LIST_MIT;
			markdown_item *list = Markdown::new_item(type);
			if (d) d->next = list; else at->down = list;
			list->down = c;
			while (MarkdownParser::in_same_list(c, c->next)) c = c->next;
			list->next = c->next;
//			list->whitespace_follows = c->whitespace_follows;
			c->next = NULL;
			c = list;
		}
	}
}

void MarkdownParser::propagate_white_space_follows(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	for (markdown_item *c = at->down; c; c = c->next)
		MarkdownParser::propagate_white_space_follows(state, c);
	for (markdown_item *c = at->down; c; c = c->next)
		if ((c->next == NULL) && (c->whitespace_follows))
			at->whitespace_follows = TRUE;
}

int MarkdownParser::in_same_list(markdown_item *A, markdown_item *B) {
	if ((A) && (B) &&
		(A->type == ORDERED_LIST_ITEM_MIT) && (A->type == B->type)) {
		if ((A->details >= 0) && (B->details >= 0)) return TRUE;
		if ((A->details < 0) && (B->details < 0)) return TRUE;
	}
	if ((A) && (B) &&
		(A->type == UNORDERED_LIST_ITEM_MIT) && (A->type == B->type)) {
		if (A->details == B->details) return TRUE;
	}
	return FALSE;
}

@

=
void MarkdownParser::inline_recursion(md_doc_state *state, markdown_item *at) {
	if (at == NULL) return;
	if (at->type == PARAGRAPH_MIT)
		at->down = MarkdownParser::inline(state, at->stashed);
	if (at->type == HEADING_MIT)
		at->down = MarkdownParser::inline(state, at->stashed);
	for (markdown_item *c = at->down; c; c = c->next)
		MarkdownParser::inline_recursion(state, c);
}

markdown_item *MarkdownParser::paragraph(text_stream *text) {
	return MarkdownParser::passage(text);
}

markdown_item *MarkdownParser::inline(md_doc_state *state, text_stream *text) {
	markdown_item *owner = Markdown::new_item(MATERIAL_MIT);
	MarkdownParser::make_inline_chain(owner, text);
	MarkdownParser::links_and_images(state, owner, FALSE);
	MarkdownParser::emphasis(owner);
	return owner;
}

@h Inline code.
At the top level, the inline items are code snippets, autolinks and raw HTML.
"Code spans, HTML tags, and autolinks have the same precedence", so we will
scan left to right. The result of this is the initial chain of items. If
nothing of interest is found, there's just a single PLAIN item containing
the entire text, but with leading and trailing spaces removed.

=
markdown_item *MarkdownParser::make_inline_chain(markdown_item *owner, text_stream *text) {
	int i = 0;
	while (Str::get_at(text, i) == ' ') i++;
	int from = i;
	for (; i<Str::len(text); i++) {
		@<Does a backtick begin here?@>;
		@<Does an autolink begin here?@>;
		@<Does a raw HTML tag begin here?@>;
		@<Does a hard or soft line break occur here?@>;
		ContinueOuter: ;
	}
	if (from <= Str::len(text)-1) {
		int to = Str::len(text)-1;
		while (Str::get_at(text, to) == ' ') to--;
		if (to >= from) {
			markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, to);
			Markdown::add_to(md, owner);
		}
	}
	return owner;
}

@ See CommonMark 6.1: "A backtick string is a string of one or more backtick
characters that is neither preceded nor followed by a backtick." This returns
the length of a backtick string beginning at |at|, if one does, or 0 if it
does not.

=
int MarkdownParser::backtick_string(text_stream *text, int at) {
	int count = 0;
	while (Str::get_at(text, at + count) == '`') count++;
	if (count == 0) return 0;
	if ((at > 0) && (Str::get_at(text, at - 1) == '`')) return 0;
	return count;
}

@<Does a backtick begin here?@> =
	int count = MarkdownParser::backtick_string(text, i);
	if (count > 0) {
		for (int j=i+count+1; j<Str::len(text); j++) {
			if (MarkdownParser::backtick_string(text, j) == count) {
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

@<Does an autolink begin here?@> =
	if (Str::get_at(text, i) == '<') {
		for (int j=i+1; j<Str::len(text); j++) {
			wchar_t c = Str::get_at(text, j);
			if (c == '>') {
				int link_from = i+1, link_to = j-1, count = j-i+1;
				if (tracing_Markdown_parser) {
					text_stream *OUT = STDOUT;
					WRITE("Investigating potential autolink: ");
					for (int k=i; k<=j; k++) PUT(Str::get_at(text, k));
					WRITE("\n");
				}
				@<Test for URI autolink@>;
				@<Test for email autolink@>;
				break;
			}
			if ((c == '<') ||
				(Markdown::is_Unicode_whitespace(c)) ||
				(Markdown::is_control_character(c)))
				break;
		}
	}

@ "A URI autolink consists of... a scheme followed by a colon followed by zero
or more characters other than ASCII control characters, space, <, and >... a
scheme is any sequence of 2–32 characters beginning with an ASCII letter and
followed by any combination of ASCII letters, digits, or the symbols plus,
period, or hyphen."

@<Test for URI autolink@> =
	int colon_at = -1;
	for (int k=link_from; k<=link_to; k++) if (Str::get_at(text, k) == ':') { colon_at = k; break; }
	if (colon_at >= 0) {
		int scheme_valid = TRUE;
		@<Vet the scheme@>;
		int link_valid = TRUE;
		@<Vet the link@>;
		if ((scheme_valid) && (link_valid)) {
			if (i-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(URI_AUTOLINK_MIT,
				text, link_from, link_to);
			Markdown::add_to(md, owner);
			i = link_to+1; from = link_to+2;
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found URI from = %c\n", Markdown::get_at(md, from));
			goto ContinueOuter;			
		} else if (tracing_Markdown_parser) {
			if (scheme_valid == FALSE) WRITE_TO(STDOUT, "Colon suggested URI but scheme invalid\n");
			if (link_valid == FALSE) WRITE_TO(STDOUT, "Colon suggested URI but link invalid\n");
		}
	} else {
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Not a URI: no colon\n");
	}

@<Vet the scheme@> =
	int scheme_length = colon_at - link_from;
	if ((scheme_length < 2) || (scheme_length > 32)) scheme_valid = FALSE;
	for (int i=link_from; i<colon_at; i++) {
		wchar_t c = Str::get_at(text, i);
		if (!((Markdown::is_ASCII_letter(c)) ||
			((i > link_from) &&
				((Markdown::is_ASCII_digit(c)) || (c == '+') || (c == '-') || (c == '.')))))
			scheme_valid = FALSE;
	}

@<Vet the link@> =
	for (int i=colon_at+1; i<=link_to; i++) {
		wchar_t c = Str::get_at(text, i);
		if ((c == '<') || (c == '>') || (c == ' ') ||
			(Markdown::is_control_character(c)))
			link_valid = FALSE;
	}

@<Test for email autolink@> =
	int atsign_at = -1;
	for (int k=link_from; k<=link_to; k++) if (Str::get_at(text, k) == '@') { atsign_at = k; break; }
	if (atsign_at >= 0) {
		int username_valid = TRUE;
		@<Vet the username@>;
		int domain_valid = TRUE;
		@<Vet the domain name@>;
		if ((username_valid) && (domain_valid)) {
			if (i-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(EMAIL_AUTOLINK_MIT,
				text, link_from, link_to);
			Markdown::add_to(md, owner);
			i = j+count; from = j+count;
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found email\n");
			goto ContinueOuter;			
		} else if (tracing_Markdown_parser) {
			if (username_valid == FALSE) WRITE_TO(STDOUT, "At suggested email but username invalid\n");
			if (domain_valid == FALSE) WRITE_TO(STDOUT, "At suggested email but domain invalid\n");
		}
	} else {
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Not an email: no at-sign\n");
	}

@ What constitutes a legal email address follows the HTML 5 regular expression,
according to CommonMark. Good luck using |{{@1-x.2.z.w| as your email address,
but you absolutely can.

@<Vet the username@> =
	int username_length = atsign_at - link_from;
	if (username_length < 1) username_valid = FALSE;
	for (int i=link_from; i<atsign_at; i++) {
		wchar_t c = Str::get_at(text, i);
		if (!((Markdown::is_ASCII_letter(c)) ||
				(Markdown::is_ASCII_digit(c)) ||
				(c == '.') ||
				(c == '!') ||
				(c == '#') ||
				(c == '$') ||
				(c == '%') ||
				(c == '&') ||
				(c == '\'') ||
				(c == '*') ||
				(c == '+') ||
				(c == '/') ||
				(c == '=') ||
				(c == '?') ||
				(c == '^') ||
				(c == '_') ||
				(c == '`') ||
				(c == '{') ||
				(c == '|') ||
				(c == '}') ||
				(c == '~') ||
				(c == '-')))
			username_valid = FALSE;
	}

@<Vet the domain name@> =
	int segment_length = 0;
	for (int i=atsign_at+1; i<=link_to; i++) {
		wchar_t c = Str::get_at(text, i);
		if (segment_length == 0) {
			if (!((Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c))))
				domain_valid = FALSE;
		} else {
			if (c == '.') { segment_length = 0; continue; }
			if (c == '-') {
				if ((Str::get_at(text, i+1) == 0) || (Str::get_at(text, i+1) == '.'))
					domain_valid = FALSE;
			} else if (!((Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c))))
				domain_valid = FALSE;
		}
		segment_length++;
		if (segment_length >= 64) domain_valid = FALSE;
	}
	if (segment_length >= 64) domain_valid = FALSE;

@<Does a raw HTML tag begin here?@> =
	if (Str::get_at(text, i) == '<') {
		switch (Str::get_at(text, i+1)) {
			case '?': @<Does a processing instruction begin here?@>; break;
			case '!':
				if ((Str::get_at(text, i+2) == '-') && (Str::get_at(text, i+3) == '-'))
					@<Does an HTML comment begin here?@>;
				if ((Str::get_at(text, i+2) == '[') && (Str::get_at(text, i+3) == 'C') &&
					(Str::get_at(text, i+4) == 'D') && (Str::get_at(text, i+5) == 'A') &&
					(Str::get_at(text, i+6) == 'T') && (Str::get_at(text, i+7) == 'A') &&
					(Str::get_at(text, i+8) == '['))
					@<Does a CDATA section begin here?@>;
				if (Markdown::is_ASCII_letter(Str::get_at(text, i+2)))
					@<Does an HTML declaration begin here?@>;
				break;
			case '/': @<Does a close tag begin here?@>; break;
			default: @<Does an open tag begin here?@>; break;
		}
		NotATag: ;
	}

@ The content of a PI must be non-empty.

@<Does a processing instruction begin here?@> =
	for (int j = i+3; j<Str::len(text); j++)
		if ((Str::get_at(text, j) == '?') && (Str::get_at(text, j+1) == '>')) {
			int tag_from = i, tag_to = j+1;
			@<Allow it as a raw HTML tag@>;
		}

@ A comment can be empty, but cannot end in a dash or contain a double-dash:

@<Does an HTML comment begin here?@> =
	int bad_start = FALSE;
	if (Str::get_at(text, i+4) == '>') bad_start = TRUE;
	if ((Str::get_at(text, i+4) == '-') && (Str::get_at(text, i+5) == '>')) bad_start = TRUE;
	if (bad_start == FALSE)
		for (int j = i+4; j<Str::len(text); j++)
			if ((Str::get_at(text, j) == '-') && (Str::get_at(text, j+1) == '-')) {
				if (Str::get_at(text, j+2) == '>') {
					int tag_from = i, tag_to = j+2;
					@<Allow it as a raw HTML tag@>;
				}
				break;
			} 

@ The content of a declaration can be empty.

@<Does an HTML declaration begin here?@> =
	for (int j = i+2; j<Str::len(text); j++)
		if (Str::get_at(text, j) == '>') {
			int tag_from = i, tag_to = j;
			@<Allow it as a raw HTML tag@>;
		}

@ The content of a CDATA must be non-empty.

@<Does a CDATA section begin here?@> =
	for (int j = i+10; j<Str::len(text); j++)
		if ((Str::get_at(text, j) == ']') && (Str::get_at(text, j+1) == ']') &&
			(Str::get_at(text, j+2) == '>')) {
			int tag_from = i, tag_to = j+2;
			@<Allow it as a raw HTML tag@>;
		}

@<Does an open tag begin here?@> =
	int at = i+1;
	@<Advance past tag name@>;
	@<Advance past attributes@>;
	@<Advance past optional tag-whitespace@>;
	if (Str::get_at(text, at) == '/') at++;
	if (Str::get_at(text, at) == '>') {
		int tag_from = i, tag_to = at;
		@<Allow it as a raw HTML tag@>;
	}

@<Does a close tag begin here?@> =
	int at = i+2;
	@<Advance past tag name@>;
	@<Advance past optional tag-whitespace@>;
	if (Str::get_at(text, at) == '>') {
		int tag_from = i, tag_to = at;
		@<Allow it as a raw HTML tag@>;
	}

@<Advance past tag name@> =
	wchar_t c = Str::get_at(text, at);
	if (Markdown::is_ASCII_letter(c) == FALSE) goto NotATag;
	while ((c == '-') || (Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c)))
		c = Str::get_at(text, ++at);

@<Advance past attributes@> =
	while (TRUE) {
		int start_at = at;
		@<Advance past optional tag-whitespace@>;
		if (at == start_at) break;
		wchar_t c = Str::get_at(text, at);
		if ((c == '_') || (c == ':') || (Markdown::is_ASCII_letter(c))) {
			while ((c == '_') || (c == ':') || (c == '.') || (c == '-') ||
				(Markdown::is_ASCII_letter(c)) || (Markdown::is_ASCII_digit(c)))
				c = Str::get_at(text, ++at);
			int start_value_at = at;
			@<Advance past optional tag-whitespace@>;
			if (Str::get_at(text, at) != '=') {
				at = start_value_at; goto DoneValueSpecification;
			}
			at++;
			@<Advance past optional tag-whitespace@>;
			@<Try for a single-quoted attribute value@>;
			@<Try for a double-quoted attribute value@>;
			@<Try for an unquoted attribute value@>;
			DoneValueSpecification: ;
		} else { at = start_at; break; }
	}

@<Try for an unquoted attribute value@> =
	int k = at;
	while (TRUE) {
		wchar_t c = Str::get_at(text, k);
		if ((c == ' ') || (c == '\t') || (c == '\n') || (c == '"') || (c == '\'') ||
			(c == '=') || (c == '<') || (c == '>') || (c == '`') || (c == 0))
			break;
		k++;
	}
	if (k == at) { at = start_value_at; goto DoneValueSpecification; }
	at = k; goto DoneValueSpecification;

@<Try for a single-quoted attribute value@> =
	if (Str::get_at(text, at) == '\'') {
		int k = at + 1;
		while ((Str::get_at(text, k) != '\'') && (Str::get_at(text, k) != 0))
			k++;
		if (Str::get_at(text, k) == '\'') { at = k+1; goto DoneValueSpecification; }
		at = start_value_at; goto DoneValueSpecification;
	}

@<Try for a double-quoted attribute value@> =
	if (Str::get_at(text, at) == '"') {
		int k = at + 1;
		while ((Str::get_at(text, k) != '"') && (Str::get_at(text, k) != 0))
			k++;
		if (Str::get_at(text, k) == '"') { at = k+1; goto DoneValueSpecification; }
		at = start_value_at; goto DoneValueSpecification;
	}

@<Advance past compulsory tag-whitespace@> =
	wchar_t c = Str::get_at(text, at);
	if ((c != ' ') && (c != '\t') && (c != '\n')) goto NotATag;
	@<Advance past optional tag-whitespace@>;

@<Advance past optional tag-whitespace@> =
	int line_ending_count = 0;
	while (TRUE) {
		wchar_t c = Str::get_at(text, at++);
		if (c == '\n') {
			line_ending_count++;
			if (line_ending_count == 2) break;
		}
		if ((c != ' ') && (c != '\t') && (c != '\n')) break;
	}
	at--;

@<Allow it as a raw HTML tag@> =
	if (i-1 >= from) {
		markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-1);
		Markdown::add_to(md, owner);
	}
	markdown_item *md = Markdown::new_slice(INLINE_HTML_MIT, text, tag_from, tag_to);
	Markdown::add_to(md, owner);
	i = tag_to; from = tag_to + 1;
	if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found raw HTML\n");
	goto ContinueOuter;

@<Does a hard or soft line break occur here?@> =
	if (Str::get_at(text, i) == '\n') {
		int soak = 0;
		if (Str::get_at(text, i-1) == '\\') soak = 2;
		int preceding_spaces = 0;
		while (Str::get_at(text, i-1-preceding_spaces) == ' ') preceding_spaces++;
		if (preceding_spaces >= 2) soak = preceding_spaces+1;
		if (soak > 0) {
			if (i-soak >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-soak);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(LINE_BREAK_MIT, I"\n\n", 0, 1);
			Markdown::add_to(md, owner);
		} else {
			if (i-preceding_spaces-1 >= from) {
				markdown_item *md = Markdown::new_slice(PLAIN_MIT, text, from, i-preceding_spaces-1);
				Markdown::add_to(md, owner);
			}
			markdown_item *md = Markdown::new_slice(SOFT_BREAK_MIT, I"\n", 0, 0);
			Markdown::add_to(md, owner);
		}
		i++;
		while (Str::get_at(text, i) == ' ') i++;
		from = i;
		i--;
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Found raw HTML\n");
		goto ContinueOuter;
	}

@h Links and images.

=
void MarkdownParser::links_and_images(md_doc_state *state, markdown_item *owner, int images_only) {
	if (owner == NULL) return;
	if (tracing_Markdown_parser) {
		WRITE_TO(STDOUT, "Beginning link/image pass:\n");
		Markdown::debug_subtree(STDOUT, owner);
	}
	md_charpos leftmost_pos = Markdown::left_edge_of(owner->down);
	while (TRUE) {
		if (tracing_Markdown_parser) {
			if (Markdown::somewhere(leftmost_pos)) {
				WRITE_TO(STDOUT, "Link/image notation scan from %c\n",
					Markdown::get(leftmost_pos));
				Markdown::debug_subtree(STDOUT, leftmost_pos.md);
			} else {
				WRITE_TO(STDOUT, "Link/image notation scan from start\n");
			}
		}
		md_link_parse found = MarkdownParser::first_valid_link(state,
			leftmost_pos, Markdown::nowhere(), images_only, FALSE);
		if (found.is_link == NOT_APPLICABLE) break;
		md_doc_reference *ref = found.link_reference;
		if (tracing_Markdown_parser) {
			WRITE_TO(STDOUT, "Link matter: ");
			if (found.link_text_empty) WRITE_TO(STDOUT, "EMPTY\n");
			else Markdown::debug_interval(STDOUT, found.link_text_from, found.link_text_to);
			if (ref) {
				WRITE_TO(STDOUT, "Link destination (reference): %S\n", ref->destination);
				WRITE_TO(STDOUT, "Link title (reference): %S\n", ref->title);
			} else {
				WRITE_TO(STDOUT, "Link destination: ");
				if (found.link_destination_empty) WRITE_TO(STDOUT, "EMPTY\n");
				else Markdown::debug_interval(STDOUT, found.link_destination_from, found.link_destination_to);
				WRITE_TO(STDOUT, "Link title: ");
				if (found.link_title_empty) WRITE_TO(STDOUT, "EMPTY\n");
				else Markdown::debug_interval(STDOUT, found.link_title_from, found.link_title_to);
			}
		}
		markdown_item *chain = owner->down, *found_text = NULL, *remainder = NULL;
		Markdown::cut_interval(chain, found.first, found.last, &chain, &found_text, &remainder);

		markdown_item *link_text = NULL;
		markdown_item *link_destination = NULL;
		markdown_item *link_title = NULL;
		if (found.link_text_empty == FALSE)
			Markdown::cut_interval(found_text, found.link_text_from, found.link_text_to,
				NULL, &link_text, &found_text);
		if ((Markdown::somewhere(found.link_destination_from)) &&
			(found.link_destination_empty == FALSE))
			Markdown::cut_interval(found_text, found.link_destination_from, found.link_destination_to,
				NULL, &link_destination, &found_text);
		if ((Markdown::somewhere(found.link_title_from)) && (found.link_title_empty == FALSE))
			Markdown::cut_interval(found_text, found.link_title_from, found.link_title_to,
				NULL, &link_title, &found_text);
		markdown_item *link_item = Markdown::new_item((found.is_link == TRUE)?LINK_MIT:IMAGE_MIT);
		markdown_item *matter = Markdown::new_item(MATERIAL_MIT);
		if (found.link_text_empty == FALSE) matter->down = link_text;
		Markdown::add_to(matter, link_item);
		if (found.is_link == TRUE) MarkdownParser::links_and_images(state, matter, TRUE);
		else MarkdownParser::links_and_images(state, matter, FALSE);
		if (ref) {
			if (Str::len(ref->destination) > 0) {
				markdown_item *dest_item = Markdown::new_item(LINK_DEST_MIT);
				dest_item->down = Markdown::new_slice(PLAIN_MIT, ref->destination, 0, Str::len(ref->destination)-1);
				Markdown::add_to(dest_item, link_item);
			}
			if (Str::len(ref->title) > 0) {
				markdown_item *title_item = Markdown::new_item(LINK_TITLE_MIT);
				title_item->down = Markdown::new_slice(PLAIN_MIT, ref->title, 0, Str::len(ref->title)-1);
				Markdown::add_to(title_item, link_item);
			}
		} else {
			if (link_destination) {
				markdown_item *dest_item = Markdown::new_item(LINK_DEST_MIT);
				if (found.link_destination_empty == FALSE) dest_item->down = link_destination;
				Markdown::add_to(dest_item, link_item);
			}
			if (link_title) {
				markdown_item *title_item = Markdown::new_item(LINK_TITLE_MIT);
				if (found.link_title_empty == FALSE) title_item->down = link_title;
				Markdown::add_to(title_item, link_item);
			}
		}
		if (chain) {
			owner->down = chain;
			while (chain->next) chain = chain->next; chain->next = link_item;
		} else {
			owner->down = link_item;
		}
		link_item->next = remainder;
		if (tracing_Markdown_parser) {
			WRITE_TO(STDOUT, "After link surgery:\n");
			Markdown::debug_subtree(STDOUT, owner);
		}
		leftmost_pos = Markdown::left_edge_of(remainder);
	}
}


typedef struct md_link_parse {
	int is_link; /* |TRUE| for link, |FALSE| for image, |NOT_APPLICABLE| for fail */
	struct md_charpos first;
	struct md_charpos link_text_from;
	struct md_charpos link_text_to;
	int link_text_empty;
	struct md_charpos link_destination_from;
	struct md_charpos link_destination_to;
	int link_destination_empty;
	struct md_charpos link_title_from;
	struct md_charpos link_title_to;
	int link_title_empty;
	struct md_doc_reference *link_reference;
	struct md_charpos last;
} md_link_parse;

@

@d ABANDON_LINK(reason)
	{ if (tracing_Markdown_parser) { WRITE_TO(STDOUT, "Link abandoned: %s\n", reason); }
	pos = abandon_at; goto AbandonHope; }

@ =
md_link_parse MarkdownParser::first_valid_link(md_doc_state *state,
	md_charpos from, md_charpos to, int images_only, int links_only) {
	md_link_parse result;
	result.is_link = NOT_APPLICABLE;
	result.first = Markdown::nowhere();
	result.link_text_from = Markdown::nowhere();
	result.link_text_to = Markdown::nowhere();
	result.link_text_empty = NOT_APPLICABLE;
	result.link_destination_from = Markdown::nowhere();
	result.link_destination_to = Markdown::nowhere();
	result.link_destination_empty = NOT_APPLICABLE;
	result.link_title_from = Markdown::nowhere();
	result.link_title_to = Markdown::nowhere();
	result.link_title_empty = NOT_APPLICABLE;
	result.link_reference = FALSE;
	result.last = Markdown::nowhere();
	wchar_t prev_c = 0;
	md_charpos prev_pos = Markdown::nowhere();
	int escaped = FALSE;
	for (md_charpos pos = from; Markdown::somewhere(pos); pos = Markdown::advance_up_to(pos, to)) {
		wchar_t c = Markdown::get(pos);
		if ((c == '\\') && (escaped == FALSE)) escaped = TRUE;
		else {
			if ((c == '[') && (escaped == FALSE)) {
				md_charpos pass_pos = pos;
				for (int pass=1; pass<=2; pass++) {
					if (tracing_Markdown_parser) {
						WRITE_TO(STDOUT, "Pass %d: at ", pass);
						Markdown::debug_pos(STDOUT, pos);
						WRITE_TO(STDOUT, "\n");
					}
					if (pass == 2) pos = pass_pos;
					@<See if a link begins here@>;
					AbandonHope: ;
				}
			}
			if (escaped == FALSE) {
				prev_c = c;
				prev_pos = pos;	
			}
			escaped = FALSE;
		}
	}
	return result;
}

@<See if a link begins here@> =
	if (((links_only == FALSE) || (prev_c != '!')) &&
		((images_only == FALSE) || (prev_c == '!'))) {
		int link_rather_than_image = TRUE;
		result.first = pos;
		if ((prev_c == '!') && (links_only == FALSE)) {
			link_rather_than_image = FALSE; result.first = prev_pos;
		}
	
		if (link_rather_than_image) {
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Potential link found\n");
		} else {
			if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Potential image found\n");
		}
		md_charpos abandon_at = pos;
		@<Work out the link text@>;
		if (Markdown::get(pos) == '[') {
			@<Work out the reference@>;
		} else {
			if ((Markdown::get(pos) != '(') || (pass == 2)) {
				TEMPORARY_TEXT(label)
				for (md_charpos pos = result.link_text_from; Markdown::somewhere(pos); pos = Markdown::advance(pos)) {
					PUT_TO(label, Markdown::get(pos));
					if (Markdown::pos_eq(pos, result.link_text_to)) break;
				}
				MarkdownParser::unescape(label);
				if (Str::is_whitespace(label)) ABANDON_LINK("reference empty");
				if (Str::len(label) > 999) ABANDON_LINK("overlong reference");
				MarkdownParser::normalise_label(label);
				if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Looking up reference (a) '%S'\n", label);
				md_doc_reference *ref = NULL;
				dict_entry *de = Dictionaries::find(state->link_references, label);
				if (de) ref = (md_doc_reference *) Dictionaries::value_for_entry(de);
				if (ref == NULL) ABANDON_LINK("no '(' and not a valid reference");
				result.link_reference = ref;
				pos = result.link_text_to;
				pos = Markdown::advance_up_to(pos, to);
				DISCARD_TEXT(label)
			} else {
				pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
				@<Advance pos by optional small amount of white space@>;
				if (Markdown::get(pos) != ')') @<Work out the link destination@>;
				@<Advance pos by optional small amount of white space@>;
				if (Markdown::get(pos) != ')') @<Work out the link title@>;
				@<Advance pos by optional small amount of white space@>;
				if (Markdown::get(pos) != ')') ABANDON_LINK("no ')'");
			}
		}
		result.last = pos;
		result.is_link = link_rather_than_image;
		if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Confirmed\n");
		return result;
	}

@<Work out the link text@> =
	wchar_t c = Markdown::get(pos);
	md_charpos prev_pos = pos;
	result.link_text_from = Markdown::advance_up_to(pos, to);
	wchar_t prev_c = 0;
	int bl = 0, count = 0, escaped = FALSE;
	while (c != 0) {
		if ((c == '\\') && (escaped == FALSE)) {
			escaped = TRUE;
		} else {
			count++;
			if ((c == '[') && (escaped == FALSE)) bl++;
			if ((c == ']') && (escaped == FALSE)) { bl--; if (bl == 0) break; }
			escaped = FALSE;
		}
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to(pos, to);
			c = Markdown::get(pos);
	}
	if (c == 0) { pos = abandon_at; ABANDON_LINK("no end to linked matter"); }
	result.link_text_empty = (count<=2)?TRUE:FALSE;
	result.link_text_to = prev_pos;
	if (link_rather_than_image) {
		md_link_parse nested =
			MarkdownParser::first_valid_link(state,
				result.link_text_from, result.link_text_to, FALSE, TRUE);
		if (nested.is_link != NOT_APPLICABLE) return nested;
	}
	pos = Markdown::advance_up_to_plainish_only(pos, to);

@<Work out the reference@> =
	md_charpos prev_pos = pos;
	pos = Markdown::advance_up_to_plainish_only(pos, to);
	result.link_destination_from = pos;
	wchar_t prev_c = 0;
	int bl = 1, escaping = FALSE;
	TEMPORARY_TEXT(label)
	wchar_t c = Markdown::get(pos);
	while (c != 0) {
		if ((c == '\\') && (escaping == FALSE)) {
			escaping = TRUE;
		} else {
			if (escaping) {
				if ((c != '[') && (c != ']') && (c != '\\')) PUT_TO(label, '\\');
			} else {
				if (c == '[') bl++;
				if (c == ']') { bl--; if (bl == 0) break; }
			}
			PUT_TO(label, c);
			escaping = FALSE;
		}
		prev_pos = pos;
		prev_c = c;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
		c = Markdown::get(pos);
	}
	if (c == 0) { pos = abandon_at; ABANDON_LINK("no end to reference"); }
	if (Str::len(label) == 0) {
		for (md_charpos pos = result.link_text_from; Markdown::somewhere(pos); pos = Markdown::advance(pos)) {
			PUT_TO(label, Markdown::get(pos));
			if (Markdown::pos_eq(pos, result.link_text_to)) break;
		}
	}
	if (Str::is_whitespace(label)) ABANDON_LINK("reference empty");
	if (Str::len(label) > 999) ABANDON_LINK("overlong reference");
	MarkdownParser::normalise_label(label);
	if (tracing_Markdown_parser) WRITE_TO(STDOUT, "Looking up reference (b) '%S'\n", label);
	md_doc_reference *ref = NULL;
	dict_entry *de = Dictionaries::find(state->link_references, label);
	if (de) ref = (md_doc_reference *) Dictionaries::value_for_entry(de);
	if (ref == NULL) ABANDON_LINK("unknown reference");
	result.link_reference = ref;

@<Work out the link destination@> =
	if (Markdown::get(pos) == '<') {
		pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
		result.link_destination_from = pos;
		int empty = TRUE;
		wchar_t prev_c = 0;
		while ((Markdown::get(pos) != '>') || (prev_c == '\\')) {
			if (Markdown::get(pos) == 0) ABANDON_LINK("no end to destination in angles");
			if (Markdown::get(pos) == '<') ABANDON_LINK("'<' in destination in angles");
			if (Markdown::get(pos) == '\n') ABANDON_LINK("reference includes line end");
			prev_pos = pos; prev_c = Markdown::get(pos);
			pos = Markdown::advance_up_to_quasi_plainish_only(pos, to); empty = FALSE;
		}
		result.link_destination_empty = empty;
		result.link_destination_to = prev_pos;
		pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
		if ((Markdown::get(pos) == '"') || (Markdown::get(pos) == '\'') ||
			(Markdown::get(pos) == '(')) ABANDON_LINK("no gap between destination and title");
	} else {
		result.link_destination_from = pos;
		int bl = 1;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		while ((Markdown::get(pos) != ' ') && (Markdown::get(pos) != '\n') &&
			(Markdown::get(pos) != '\t')) {
			wchar_t c = Markdown::get(pos);
			if ((c == '(') && (prev_c != '\\')) bl++;
			if ((c == ')') && (prev_c != '\\')) { bl--; if (bl == 0) break; }
			if (c == 0) ABANDON_LINK("no end to destination");
			if (Markdown::is_control_character(c)) ABANDON_LINK("control character in destination");
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to_quasi_plainish_only(pos, to); empty = FALSE;
		}
		result.link_destination_empty = empty;
		result.link_destination_to = prev_pos;
		if ((Markdown::get(pos) == '"') || (Markdown::get(pos) == '\'') ||
			(Markdown::get(pos) == '(')) ABANDON_LINK("no gap between destination and title");
	}

@<Work out the link title@> =
	if (Markdown::get(pos) == '"') {
		pos = Markdown::advance_up_to_plainish_only(pos, to);
		result.link_title_from = pos;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		wchar_t c = Markdown::get(pos);
		while (c != 0) {
			wchar_t c = Markdown::get(pos);
			if ((c == '"') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to_plainish_only(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
	}
	else if (Markdown::get(pos) == '\'') {
		pos = Markdown::advance_up_to_plainish_only(pos, to);
		result.link_title_from = pos;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		wchar_t c = Markdown::get(pos);
		while (c != 0) {
			wchar_t c = Markdown::get(pos);
			if ((c == '\'') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to_plainish_only(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
	}
	else if (Markdown::get(pos) == '(') {
		pos = Markdown::advance_up_to(pos, to);
		result.link_title_from = pos;
		wchar_t prev_c = 0;
		md_charpos prev_pos = pos;
		int empty = TRUE;
		wchar_t c = Markdown::get(pos);
		while (c != 0) {
			wchar_t c = Markdown::get(pos);
			if ((c == '(') && (prev_c != '\\')) ABANDON_LINK("unescaped '(' in title");
			if ((c == ')') && (prev_c != '\\')) break;
			prev_pos = pos;
			prev_c = c;
			pos = Markdown::advance_up_to(pos, to); empty = FALSE;
		}
		if (c == 0) ABANDON_LINK("no end to title");
		result.link_title_empty = empty;
		result.link_title_to = prev_pos;
		pos = Markdown::advance_up_to_plainish_only(pos, to);
	}

@<Advance pos by optional small amount of white space@> =
	int line_endings = 0;
	wchar_t c = Markdown::get(pos);
	while ((c == ' ') || (c == '\t') || (c == '\n')) {
		if (c == '\n') { line_endings++; if (line_endings >= 2) break; }
		pos = Markdown::advance_up_to_quasi_plainish_only(pos, to);
		c = Markdown::get(pos);
	}

@

=
void MarkdownParser::unescape(text_stream *label) {
	TEMPORARY_TEXT(to)
	for (int i=0; i<Str::len(label); i++) {
		if ((Str::get_at(label, i) == '\\') &&
			((Str::get_at(label, i+1) == '[') ||
				(Str::get_at(label, i+1) == '\\') ||
				(Str::get_at(label, i+1) == ']')))
			i++;
		PUT_TO(to, Str::get_at(label, i));
	}
	Str::clear(label); WRITE_TO(label, "%S", to);
	DISCARD_TEXT(to)
}


@h Emphasis.
Well, that was easy. Now for the hardest pass, in which we look for the use
of asterisks and underscores for emphasis. This notation is deeply ambiguous
on its face, and CommonMark's precise specification is a bit of an ordeal,
but here goes.

=
void MarkdownParser::emphasis(markdown_item *owner) {
	for (markdown_item *md = owner->down; md; md = md->next)
		if ((md->type == LINK_MIT) || (md->type == IMAGE_MIT))
			MarkdownParser::emphasis(md->down);
	text_stream *OUT = STDOUT;
	if (tracing_Markdown_parser) {
		WRITE("Seeking emphasis in:\n");
		INDENT;
		Markdown::debug_subtree(STDOUT, owner);
	}
	@<Seek emphasis@>;
	if (tracing_Markdown_parser) {
		OUTDENT;
		WRITE("Emphasis search complete\n");
	}
}

@ "A delimiter run is either a sequence of one or more * characters that is not
preceded or followed by a non-backslash-escaped * character, or a sequence of
one or more _ characters that is not preceded or followed by a
non-backslash-escaped _ character."

This function returns 0 unless a delimiter run begins at |at|, and then returns
its length if this was asterisked, and minus its length if underscored.

=
int MarkdownParser::delimiter_run(md_charpos pos) {
	int count = Markdown::unescaped_run(pos, '*');
	if ((count > 0) && (Markdown::get_unescaped(pos, -1) != '*')) return count;
	count = Markdown::unescaped_run(pos, '_');
	if ((count > 0) && (Markdown::get_unescaped(pos, -1) != '_')) return -count;
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
int MarkdownParser::left_flanking(md_charpos pos, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	wchar_t followed_by = Markdown::get_unescaped(pos, count);
	if ((followed_by == 0) || (Markdown::is_Unicode_whitespace(followed_by))) return FALSE;
	if (Markdown::is_Unicode_punctuation(followed_by) == FALSE) return TRUE;
	wchar_t preceded_by = Markdown::get_unescaped(pos, -1);
	if ((preceded_by == 0) || (Markdown::is_Unicode_whitespace(preceded_by)) ||
		(Markdown::is_Unicode_punctuation(preceded_by))) return TRUE;
	return FALSE;
}

int MarkdownParser::right_flanking(md_charpos pos, int count) {
	if (count == 0) return FALSE;
	if (count < 0) count = -count;
	wchar_t preceded_by = Markdown::get_unescaped(pos, -1);
	if ((preceded_by == 0) || (Markdown::is_Unicode_whitespace(preceded_by))) return FALSE;
	if (Markdown::is_Unicode_punctuation(preceded_by) == FALSE) return TRUE;
	wchar_t followed_by = Markdown::get_unescaped(pos, count);
	if ((followed_by == 0) || (Markdown::is_Unicode_whitespace(followed_by)) ||
		(Markdown::is_Unicode_punctuation(followed_by))) return TRUE;
	return FALSE;
}

@ The following expresses rules (1) to (8) in the CM specification, section 6.2.

=
int MarkdownParser::can_open_emphasis(md_charpos pos, int count) {
	if (MarkdownParser::left_flanking(pos, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (MarkdownParser::right_flanking(pos, count) == FALSE) return TRUE;
	wchar_t preceded_by = Markdown::get_unescaped(pos, -1);
	if (Markdown::is_Unicode_punctuation(preceded_by)) return TRUE;
	return FALSE;
}

int MarkdownParser::can_close_emphasis(md_charpos pos, int count) {
	if (MarkdownParser::right_flanking(pos, count) == FALSE) return FALSE;
	if (count > 0) return TRUE;
	if (MarkdownParser::left_flanking(pos, count) == FALSE) return TRUE;
	wchar_t followed_by = Markdown::get_unescaped(pos, -count); /* count < 0 here */
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
	struct md_charpos pos; /* first character in the run */
	int width;             /* for example, 7 for a run of seven asterisks */
	int type;              /* 1 for asterisks, -1 for underscores */
	int can_open;          /* result of |MarkdownParser::can_open_emphasis| on it */
	int can_close;         /* result of |MarkdownParser::can_close_emphasis| on it */
	CLASS_DEFINITION
} md_emphasis_delimiter;

@<Find the possible emphasis delimiters@> =
	int open_count[2] = { 0, 0 }, close_count[2] = { 0, 0 }, both_count[2] = { 0, 0 }; 
	for (md_charpos pos = Markdown::left_edge_of(owner->down);
		Markdown::somewhere(pos); pos = Markdown::advance(pos)) {
		int run = MarkdownParser::delimiter_run(pos);
		if (run != 0) {
			if (no_delimiters >= MAX_MD_EMPHASIS_DELIMITERS) break;
			int can_open = MarkdownParser::can_open_emphasis(pos, run);
			int can_close = MarkdownParser::can_close_emphasis(pos, run);
			if ((no_delimiters == 0) && (can_open == FALSE)) continue;
			if ((can_open == FALSE) && (can_close == FALSE)) continue;
			md_emphasis_delimiter *P = &(delimiters[no_delimiters++]);
			P->pos = pos;
			P->width = (run>0)?run:(-run);
			P->type = (run>0)?1:-1;
			P->can_open = can_open;
			P->can_close = can_close;
			if (tracing_Markdown_parser) {
				WRITE("DR%d at ", no_delimiters);
				Markdown::debug_pos(OUT, pos);
				WRITE(" width %d type %d", P->width, P->type);
				if (MarkdownParser::left_flanking(pos, run)) WRITE(", left-flanking");
				if (MarkdownParser::right_flanking(pos, run)) WRITE(", right-flanking");
				if (P->can_open) WRITE(", can-open");
				if (P->can_close) WRITE(", can-close");
				WRITE(", preceded by ");
				Markdown::debug_char(OUT, Markdown::get_unescaped(P->pos, -1));
				WRITE(", followed by ");
				Markdown::debug_char(OUT, Markdown::get_unescaped(P->pos, P->width));
				WRITE("\n");
			}
			int x = (P->type>0)?0:1;
			if ((can_open) && (can_close == FALSE)) open_count[x] += P->width;
			if ((can_open == FALSE) && (can_close)) close_count[x] += P->width;
			if ((can_open) && (can_close)) both_count[x] += P->width;
			if ((both_count[0] == 0) && (open_count[0] == close_count[0]) &&
				(both_count[1] == 0) && (open_count[1] == close_count[1])) break;
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

Note the two recursive uses of |MarkdownParser::emphasis| to continue
the process of pairing: this is where the computational fuse is lit, with
the explosion to follow. But since each subtree contains fewer delimiter runs
than the original, it does at least terminate.

@<Create the subtree which would result from this option being chosen@> =
	markdown_item *option = Markdown::deep_copy(owner);
	options[no_options++] = option;
	markdown_item *OI = NULL, *CI = NULL;
	for (markdown_item *md = option->down; md; md = md->next) {
		if (md->copied_from == OD->pos.md) OI = md;
		if (md->copied_from == CD->pos.md) CI = md;
	}
	if ((OI == NULL) || (CI == NULL)) internal_error("copy accident");

	int width; /* number of delimiter characters we will trim */
	md_charpos first_trimmed_char_left;
	md_charpos last_trimmed_char_left;
	md_charpos first_trimmed_char_right;
	md_charpos last_trimmed_char_right;
	@<Draw the dotted lines where we will cut@>;

	@<Deactivate the active characters being acted on@>;

	markdown_item *em_top, *em_bottom;
	@<Make the chain of emphasis items from top to bottom@>;
	@<Perform the tree surgery to insert the emphasis item@>;

	MarkdownParser::emphasis(em_bottom);
	MarkdownParser::emphasis(option);

	if (tracing_Markdown_parser) {
		WRITE("Option %d is to fragment thus:\n", no_options);
		Markdown::debug_subtree(STDOUT, option);
		WRITE("Resulting in: ");
		MarkdownRenderer::go(STDOUT, option);
		WRITE("\nWhich scores %d penalty points\n", MarkdownParser::penalty(option));
	}

@ This innocent-looking code is very tricky. The issue is that the two delimiters
may be of unequal width. We want to take as many asterisks/underscores away
as we can, so we set |width| to the minimum of the two lengths. But a complication
is that they need to be cropped to fit inside the slice of the node they belong
to first.

We then mark to remove |width| characters from the inside edges of each
delimiter, not the outside edges.

@<Draw the dotted lines where we will cut@> =
	int O_start = OD->pos.at, O_width = OD->width;
	if (O_start < OI->from) { O_width -= (OI->from - O_start); O_start = OI->from; }

	int C_start = CD->pos.at, C_width = CD->width;
	if (C_start + C_width - 1 > CI->to) { C_width = CI->to - C_start + 1; }

	width = O_width; if (width > C_width) width = C_width;

	first_trimmed_char_left = Markdown::pos(OI, O_start + O_width - width);
	last_trimmed_char_left = Markdown::pos(OI, O_start + O_width - 1);
	first_trimmed_char_right = Markdown::pos(CI, C_start);
	last_trimmed_char_right = Markdown::pos(CI, C_start + width - 1);

	if (tracing_Markdown_parser) {
		WRITE(" first left = "); Markdown::debug_pos(OUT, first_trimmed_char_left);
		WRITE("\n  last left = "); Markdown::debug_pos(OUT, last_trimmed_char_left);
		WRITE("\nfirst right = "); Markdown::debug_pos(OUT, first_trimmed_char_right);
		WRITE("\n last right = "); Markdown::debug_pos(OUT, last_trimmed_char_right);
		WRITE("\n");
	}

@<Deactivate the active characters being acted on@> =
	for (int w=0; w<width; w++) {
		Markdown::put_offset(first_trimmed_char_left, w, ':');
		Markdown::put_offset(first_trimmed_char_right, w, ':');
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

@<Make the chain of emphasis items from top to bottom@> =
	em_top = Markdown::new_item(((width%2) == 1)?EMPHASIS_MIT:STRONG_MIT);
	if ((width%2) == 1) width -= 1; else width -= 2;
	em_bottom = em_top;
	while (width > 0) {
		markdown_item *g = Markdown::new_item(STRONG_MIT); width -= 2;
		em_bottom->down = g; em_bottom = g;
	}

@<Perform the tree surgery to insert the emphasis item@> =
	markdown_item *chain = option->down;
	if (tracing_Markdown_parser) {
		Markdown::debug_chain_label(OUT, chain, I"Before surgery");
	}
	markdown_item *before_emphasis = NULL, *emphasis = NULL, *after_emphasis = NULL;
	Markdown::cut_to_just_before(chain, first_trimmed_char_left,
		&before_emphasis, &emphasis);
	Markdown::cut_to_just_at(emphasis, last_trimmed_char_left,
		NULL, &emphasis);
	Markdown::cut_to_just_before(emphasis, first_trimmed_char_right,
		&emphasis, &after_emphasis);
	Markdown::cut_to_just_at(after_emphasis, last_trimmed_char_right,
		NULL, &after_emphasis);

	if (tracing_Markdown_parser) {
		Markdown::debug_chain_label(OUT, before_emphasis, I"Before emphasis");
		Markdown::debug_chain_label(OUT, emphasis, I"Emphasis");
		Markdown::debug_chain_label(OUT, after_emphasis, I"After emphasis");
	}

	option->down = before_emphasis;
	if (option->down) {
		chain = option->down;
		while ((chain) && (chain->next)) chain = chain->next;
		chain->next = em_top;
	} else {
		option->down = em_top;
	}
	em_top->next = after_emphasis;
	em_bottom->down = emphasis;

@<Select the option with the lowest penalty@> =
	int best_is = 1, best_score = 100000000;
	for (int pair_i = 0; pair_i < no_options; pair_i++) {
		int score = MarkdownParser::penalty(options[pair_i]);
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
int MarkdownParser::penalty(markdown_item *md) {
	if (md) {
		int penalty = 0;
		if (md->type == PLAIN_MIT) {
			for (int i=md->from; i<=md->to; i++) {
				md_charpos pos = Markdown::pos(md, i);
				wchar_t c = Markdown::get_unescaped(pos, 0);
				if ((c == '*') || (c == '_')) penalty += 100000;
			}
		}
		if ((md->type == EMPHASIS_MIT) || (md->type == STRONG_MIT))
			penalty += Markdown::width(md->down);
		for (markdown_item *c = md->down; c; c = c->next)
			penalty += MarkdownParser::penalty(c);
		return penalty;
	}
	return 0;
}
