[WebIndexing::] Web Indexing.

Gathering indexing marks for a web, and sorting them into a woven index.

@

@e LITERAL_CHARACTER_FSMEVENT

=
finite_state_machine *WebIndexing::make_indexing_machine(linked_list *conventions) {
	fsm_state *base_state = FSM::new_state(I"unindexed");
	finite_state_machine *machine = FSM::new_machine(base_state);
	
/*	text_stream *magic = Conventions::get_textual_from(conventions, LITERAL_CHARACTERS_LSCONVENTION);
	text_stream *paraphrase = Conventions::get_textual2_from(conventions, LITERAL_CHARACTERS_LSCONVENTION);
	if ((Str::len(magic) > 0) && (Str::len(paraphrase) > 0)) {
		FSM::add_transition_spelling_out_with_events(base_state,
			paraphrase, base_state, NO_FSMEVENT, LITERAL_CHARACTER_FSMEVENT);
	}
*/
	text_stream *on = Conventions::get_textual_from(conventions, COMMENTS_LSCONVENTION);
	text_stream *off = Conventions::get_textual2_from(conventions, COMMENTS_LSCONVENTION);
	int on_event = WEB_COMMENT_START_FSMEVENT, off_event = WEB_COMMENT_END_FSMEVENT;
	text_stream *mnemonic = I"web-comment";
	@<Add indexing transition pair to fsm@>;

	on = Conventions::get_textual_from(conventions, INDEX_LSCONVENTION);
	off = Conventions::get_textual2_from(conventions, INDEX_LSCONVENTION);
	on_event = INDEX_START_FSMEVENT; off_event = INDEX_END_FSMEVENT;
	mnemonic = I"index-entry";
	@<Add indexing transition pair to fsm@>;

	on = Conventions::get_textual_from(conventions, IMPORTANT_INDEX_LSCONVENTION);
	off = Conventions::get_textual2_from(conventions, IMPORTANT_INDEX_LSCONVENTION);
	on_event = IMPORTANT_INDEX_START_FSMEVENT; off_event = IMPORTANT_INDEX_END_FSMEVENT;
	mnemonic = I"important-index-entry";
	@<Add indexing transition pair to fsm@>;
	
	on = Conventions::get_textual_from(conventions, TT_INDEX_LSCONVENTION);
	off = Conventions::get_textual2_from(conventions, TT_INDEX_LSCONVENTION);
	on_event = TT_INDEX_START_FSMEVENT; off_event = TT_INDEX_END_FSMEVENT;
	mnemonic = I"tt-index-entry";
	@<Add indexing transition pair to fsm@>;

	on = Conventions::get_textual_from(conventions, IMPORTANT_TT_INDEX_LSCONVENTION);
	off = Conventions::get_textual2_from(conventions, IMPORTANT_TT_INDEX_LSCONVENTION);
	on_event = IMPORTANT_INDEX_START_FSMEVENT; off_event = IMPORTANT_TT_INDEX_END_FSMEVENT;
	mnemonic = I"important-tt-index-entry";
	@<Add indexing transition pair to fsm@>;
	
	on = Conventions::get_textual_from(conventions, NS_INDEX_LSCONVENTION);
	off = Conventions::get_textual2_from(conventions, NS_INDEX_LSCONVENTION);
	on_event = NS_INDEX_START_FSMEVENT; off_event = NS_INDEX_END_FSMEVENT;
	mnemonic = I"ns-index-entry";
	@<Add indexing transition pair to fsm@>;

	on = Conventions::get_textual_from(conventions, IMPORTANT_NS_INDEX_LSCONVENTION);
	off = Conventions::get_textual2_from(conventions, IMPORTANT_NS_INDEX_LSCONVENTION);
	on_event = IMPORTANT_INDEX_START_FSMEVENT; off_event = IMPORTANT_NS_INDEX_END_FSMEVENT;
	mnemonic = I"important-ns-index-entry";
	@<Add indexing transition pair to fsm@>;
	
	return machine;
}

@

@e WEB_COMMENT_START_FSMEVENT
@e WEB_COMMENT_END_FSMEVENT
@e INDEX_START_FSMEVENT
@e IMPORTANT_INDEX_START_FSMEVENT
@e TT_INDEX_START_FSMEVENT
@e IMPORTANT_TT_INDEX_START_FSMEVENT
@e NS_INDEX_START_FSMEVENT
@e IMPORTANT_NS_INDEX_START_FSMEVENT
@e INDEX_END_FSMEVENT
@e IMPORTANT_INDEX_END_FSMEVENT
@e TT_INDEX_END_FSMEVENT
@e IMPORTANT_TT_INDEX_END_FSMEVENT
@e NS_INDEX_END_FSMEVENT
@e IMPORTANT_NS_INDEX_END_FSMEVENT

@<Add indexing transition pair to fsm@> =
	if ((Str::len(on) > 0) && (Str::len(off) > 0)) {
		fsm_state *mid_state = FSM::new_state(mnemonic);
		FSM::add_transition_spelling_out_with_events(base_state,
			on, mid_state, NO_FSMEVENT, on_event);
		FSM::add_transition_spelling_out_with_events(mid_state,
			off, base_state, NO_FSMEVENT, off_event);
	}

@

=
typedef struct ls_index_mark {
	struct text_stream *text;
	int style;
	int important;
	struct ls_paragraph *at;
	CLASS_DEFINITION
} ls_index_mark;

ls_index_mark *WebIndexing::new_mark(text_stream *text, int style, int important) {
	ls_index_mark *ie = CREATE(ls_index_mark);
	ie->text = Str::duplicate(text);
	ie->style = style;
	ie->important = important;
	ie->at = NULL;
	return ie;
}

linked_list *WebIndexing::index_from_line(OUTPUT_STREAM, text_stream *line, ls_notation *syntax, text_stream **error) {
	linked_list *L = NULL;
	TEMPORARY_TEXT(control_text)
	finite_state_machine *machine = syntax->indexing_machine;
	if (machine) {
		FSM::reset_machine(machine);
		text_stream *to = OUT;
		for (int i=0; i<Str::len(line); i++) {
			inchar32_t c = Str::get_at(line, i);
			PUT_TO(to, c);
			@<Run indexing machine@>;
		}
		@<Check final state of indexing machine@>;
	} else {
		Str::copy(OUT, line);
	}
	DISCARD_TEXT(control_text)
	return L;
}

@<Run indexing machine@> =
	int len = 0;
	int event = FSM::cycle_machine(machine, c, &len);
	switch (event) {
		case LITERAL_CHARACTER_FSMEVENT:
			Str::truncate(OUT, Str::len(OUT) - len);
			WRITE("___inweb_protected___");
			
			break;			
		case WEB_COMMENT_START_FSMEVENT:
		case INDEX_START_FSMEVENT:
		case IMPORTANT_INDEX_START_FSMEVENT:
		case TT_INDEX_START_FSMEVENT:
		case IMPORTANT_TT_INDEX_START_FSMEVENT:
		case NS_INDEX_START_FSMEVENT:
		case IMPORTANT_NS_INDEX_START_FSMEVENT:
			Str::clear(control_text);
			Str::truncate(OUT, Str::len(OUT) - len);
			to = control_text;
			break;

		case INDEX_END_FSMEVENT:
		case IMPORTANT_INDEX_END_FSMEVENT:
		case TT_INDEX_END_FSMEVENT:
		case IMPORTANT_TT_INDEX_END_FSMEVENT:
		case NS_INDEX_END_FSMEVENT:
		case IMPORTANT_NS_INDEX_END_FSMEVENT:
			Str::truncate(control_text, Str::len(control_text) - len);
			ls_index_mark *ie = NULL;
			switch (event) {
				case INDEX_END_FSMEVENT:              ie = WebIndexing::new_mark(control_text, 1, FALSE); break;
				case IMPORTANT_INDEX_END_FSMEVENT:    ie = WebIndexing::new_mark(control_text, 1, TRUE);  break;
				case TT_INDEX_END_FSMEVENT:           ie = WebIndexing::new_mark(control_text, 2, FALSE); break;
				case IMPORTANT_TT_INDEX_END_FSMEVENT: ie = WebIndexing::new_mark(control_text, 2, TRUE); break;
				case NS_INDEX_END_FSMEVENT:           ie = WebIndexing::new_mark(control_text, 3, FALSE); break;
				case IMPORTANT_NS_INDEX_END_FSMEVENT: ie = WebIndexing::new_mark(control_text, 3, TRUE); break;
				default: internal_error("unknown index event");
			}
			if (L == NULL) L = NEW_LINKED_LIST(ls_index_mark);
			ADD_TO_LINKED_LIST(ie, ls_index_mark, L);
			to = OUT;
			break;

		case WEB_COMMENT_END_FSMEVENT:
			to = OUT;
			break;
	}

@<Check final state of indexing machine@> =
	fsm_state *final = FSM::last_nonintermediate_state(machine);
	if (Str::ne(final->mnemonic, I"unindexed"))
		*error = I"line contains incomplete index entry";

@

=
typedef struct ls_index {
	struct linked_list *all_marks; /* of |ls_index_mark| */
	struct dictionary *lemmas;
	int no_lemmas_sorted;
	struct ls_index_lemma **lemmas_sorted;
	CLASS_DEFINITION
} ls_index;

typedef struct ls_index_lemma {
	struct text_stream *sort_key;
	struct text_stream *text;
	int style;
	struct linked_list *marks; /* of |ls_index_mark| */
	struct ls_index_lemma *parent;
	CLASS_DEFINITION
} ls_index_lemma;

ls_index *WebIndexing::new_index(void) {
	ls_index *index = CREATE(ls_index);
	index->all_marks = NEW_LINKED_LIST(ls_index_mark);
	index->lemmas = NULL;
	index->no_lemmas_sorted = 0;
	index->lemmas_sorted = NULL;
	return index;
}

void WebIndexing::index_at(ls_index_mark *ie, ls_paragraph *at) {
	ls_web *W = ((at)?(at->owning_unit):NULL)?(at->owning_unit->context):NULL;
	if (W) {
		ie->at = at;
		ADD_TO_LINKED_LIST(ie, ls_index_mark, W->index->all_marks);
	}
}

void WebIndexing::index_function_at(text_stream *fn, ls_paragraph *at) {
	TEMPORARY_TEXT(lemma)
	WRITE_TO(lemma, "functions > %S", fn);
	ls_web *W = ((at)?(at->owning_unit):NULL)?(at->owning_unit->context):NULL;
	if (W) {
		ls_index_mark *ie = WebIndexing::new_mark(lemma, 2, TRUE);
		ie->at = at;
		ADD_TO_LINKED_LIST(ie, ls_index_mark, W->index->all_marks);
	}
	DISCARD_TEXT(lemma)
}

void WebIndexing::index_structure_at(text_stream *str, ls_paragraph *at) {
	TEMPORARY_TEXT(lemma)
	WRITE_TO(lemma, "structures > %S", str);
	ls_web *W = ((at)?(at->owning_unit):NULL)?(at->owning_unit->context):NULL;
	if (W) {
		ls_index_mark *ie = WebIndexing::new_mark(lemma, 2, TRUE);
		ie->at = at;
		ADD_TO_LINKED_LIST(ie, ls_index_mark, W->index->all_marks);
	}
	DISCARD_TEXT(lemma)
}

void WebIndexing::sort(ls_index *index, text_stream *range) {
	index->lemmas = Dictionaries::new(1024, FALSE);
	linked_list *lemmas = NEW_LINKED_LIST(ls_index_lemma);
	
	ls_index_mark *mark;
	LOOP_OVER_LINKED_LIST(mark, ls_index_mark, index->all_marks) {
		ls_section *S = LiterateSource::section_of_par(mark->at);
		if ((S) && (WebRanges::is_within(WebRanges::of(S), range))) {
			ls_index_lemma *lemma = WebIndexing::obtain(index, lemmas, mark->style, mark->text);
			ls_index_mark *seen;
			int found = FALSE;
			LOOP_OVER_LINKED_LIST(seen, ls_index_mark, lemma->marks)
				if (seen->at == mark->at) {
					found = TRUE;
					if (mark->important) seen->important = TRUE;
					break;
				}
			if (found == FALSE)
				ADD_TO_LINKED_LIST(mark, ls_index_mark, lemma->marks);
		}
	}
	int N = LinkedLists::len(lemmas);
	if (N == 0) {
		index->lemmas_sorted = NULL;
		return;
	}
	
	index->lemmas_sorted = (ls_index_lemma **)
		(Memory::calloc(N, sizeof(ls_index_lemma *), ARRAY_SORTING_MREASON));
	int i=0;
	ls_index_lemma *lemma;
	LOOP_OVER_LINKED_LIST(lemma, ls_index_lemma, lemmas)
		index->lemmas_sorted[i++] = lemma;
	index->no_lemmas_sorted = N;
	qsort(index->lemmas_sorted, (size_t) N, sizeof(ls_index_lemma *), WebIndexing::compare_lemmas);
}

ls_index_lemma *WebIndexing::obtain(ls_index *index, linked_list *lemmas, int style, text_stream *text) {
	ls_index_lemma *parent_lemma = NULL;
	int from = 0;
	for (int i=0; i<Str::len(text); i++)
		if (Str::includes_at(text, i, I" > "))
			from = i+3;
	if (from > 0) {
		TEMPORARY_TEXT(prefix)
		for (int j=0; j<from-3; j++) PUT_TO(prefix, Str::get_at(text, j));
		parent_lemma = WebIndexing::obtain(index, lemmas, 1, prefix);
		DISCARD_TEXT(prefix)
	}

	ls_index_lemma *lemma = NULL;
	TEMPORARY_TEXT(key)
	WRITE_TO(key, "%S  %d", text, style);
	if (Dictionaries::find(index->lemmas, key)) {
		lemma = Dictionaries::read_value(index->lemmas, key);
	} else {
		lemma = CREATE(ls_index_lemma);
		lemma->sort_key = Str::duplicate(key);
		lemma->text = Str::new();
		for (int j=from; j<Str::len(text); j++) PUT_TO(lemma->text, Str::get_at(text, j));
		lemma->style = style;
		lemma->marks = NEW_LINKED_LIST(ls_index_mark);
		lemma->parent = parent_lemma;
		Dictionaries::create(index->lemmas, key);
		Dictionaries::write_value(index->lemmas, key, lemma);
		ADD_TO_LINKED_LIST(lemma, ls_index_lemma, lemmas);
	}
	DISCARD_TEXT(key)
	return lemma;
}

int WebIndexing::compare_lemmas(const void *ent1, const void *ent2) {
	text_stream *tx1 = (*((const ls_index_lemma **) ent1))->sort_key;
	text_stream *tx2 = (*((const ls_index_lemma **) ent2))->sort_key;
	return Str::cmp_insensitive(tx1, tx2);
}

void WebIndexing::inspect_index(OUTPUT_STREAM, ls_web *W, text_stream *range) {
	ls_index *index = W->index;
	if (index->lemmas_sorted == NULL) WebIndexing::sort(index, range);
	if (index->lemmas_sorted)
		for (int i=0; i<(int) (index->no_lemmas_sorted); i++) {
			ls_index_lemma *lemma = index->lemmas_sorted[i];
			for (ls_index_lemma *l2 = lemma->parent; l2; l2 = l2->parent) WRITE("    ");
			if (lemma->style == 2) WRITE("`");
			if (lemma->style == 3) WRITE("/");
			WRITE("%S", lemma->text);
			if (lemma->style == 2) WRITE("`");
			if (lemma->style == 3) WRITE("/");
			ls_index_mark *mark; int c = 0;
			LOOP_OVER_LINKED_LIST(mark, ls_index_mark, lemma->marks) {
				if (c++ > 0) WRITE(", "); else WRITE("  ");
				if (mark->important) WRITE("_");
				WRITE("%S", mark->at->paragraph_number);
				if (mark->important) WRITE("_");
			}
			WRITE("\n");
		}
}
