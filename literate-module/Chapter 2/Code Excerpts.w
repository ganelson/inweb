[CodeExcerpts::] Code Excerpts.

To manage excerpts of code which may have to be tangled or woven.

@

=
typedef struct ls_code_excerpt {
	struct linked_list *splice_list; /* of |holon_splice| */
	CLASS_DEFINITION
} ls_code_excerpt;

ls_code_excerpt *CodeExcerpts::new(void) {
	ls_code_excerpt *ex = CREATE(ls_code_excerpt);
	ex->splice_list = NEW_LINKED_LIST(holon_splice);
	return ex;
}

@

@d LOOP_OVER_CODE_EXCERPT(hs, ex)
	LOOP_OVER_LINKED_LIST(hs, holon_splice, ex->splice_list)
@d LOOP_OVER_HOLON_DEFINITION(hs, holon)
	LOOP_OVER_CODE_EXCERPT(hs, holon->corresponding_chunk->code_excerpt)

@ Because of the notations for splicing one holon into another, the code
lines in a holon may still contain literate-programming syntax, rather than
literally being the target code. We parse those lines of code into a series
of "splices", each containing a fragment of a line.

@e CODE_LSHST from 1
@e EXPANSION_LSHST
@e FILE_EXPANSION_LSHST
@e COMMAND_LSHST
@e VERBATIM_LSHST
@e COMMENT_LSHST

=
typedef struct holon_splice {
	int type; /* one of the |*_LSHST| constants */
	struct ls_holon *expansion;
	struct text_stream *texts[3];
	struct markdown_item *comment_as_markdown;
	struct ls_line *line;
	CLASS_DEFINITION
} holon_splice;

holon_splice *CodeExcerpts::new_splice(ls_code_excerpt *ex, ls_line *lst, int type) {
	holon_splice *hs = CREATE(holon_splice);
	hs->type = type;
	hs->expansion = NULL;
	for (int i=0; i<3; i++) hs->texts[i] = NULL;
	hs->comment_as_markdown = NULL;
	hs->line = lst;
	ADD_TO_LINKED_LIST(hs, holon_splice, ex->splice_list);
	return hs;
}

holon_splice *CodeExcerpts::new_code_splice(ls_code_excerpt *ex, ls_line *lst, text_stream *text, int from, int to) {
	holon_splice *hs = CodeExcerpts::new_splice(ex, lst, CODE_LSHST);
	hs->texts[0] = Str::new();
	for (int i=from; i<=to; i++) PUT_TO(hs->texts[0], Str::get_at(text, i));
	return hs;
}

@ The code content of a splice must be extracted from the original line.

=
text_stream *CodeExcerpts::line_code(ls_line *lst) {
	return lst->classification.operand1;
}

text_stream *CodeExcerpts::splice_code(holon_splice *hs) {
	return CodeExcerpts::line_code(hs->line);
}

@

=
ls_code_excerpt *CodeExcerpts::from_illiterate_uncommented_code(text_stream *raw, ls_line *ref) {
	ls_code_excerpt *ex = CodeExcerpts::new();
	holon_splice *hs = CodeExcerpts::new_splice(ex, ref, CODE_LSHST);
	hs->texts[0] = Str::duplicate(raw);
	return ex;
}

void CodeExcerpts::parse(ls_holon_namespace *ns, ls_code_excerpt *ex,
	ls_line *lst, text_stream *from_text, ls_notation *ntn, programming_language *pl) {
	TEMPORARY_TEXT(name)
	TEMPORARY_TEXT(command)
	TEMPORARY_TEXT(comment)
	TEMPORARY_TEXT(pre_comment_code)
	ls_line *pre_comment_lst = NULL;
	int pre_comment_from = 0, pre_comment_to = -1;

	finite_state_machine *machine = HolonSyntax::get(ntn, pl);
	FSM::reset_machine(machine);
	Str::clear(name); Str::clear(command);
	int from = 0, to = -1;
	text_stream *recording_to = NULL, *comment_open = NULL, *comment_close = NULL;
	ls_line *last_line = lst, *first_line = lst;
	if (from_text == NULL) {
		for (; lst; lst = lst->next_line) {
			from_text = CodeExcerpts::line_code(lst);
			@<Scan content@>;
			last_line = lst;
		}
	} else if (lst) {
		first_line = lst;
		for (; lst; lst = lst->next_line) {
			if (lst != first_line) from_text = CodeExcerpts::line_code(lst);
			@<Scan content@>;
			last_line = lst;
		}
	} else {
		@<Scan content@>;
	}
	@<Check final state of machine@>;
	DISCARD_TEXT(name)
	DISCARD_TEXT(command)
	DISCARD_TEXT(comment)
	DISCARD_TEXT(pre_comment_code)
	holon_splice *hs;
	LOOP_OVER_CODE_EXCERPT(hs, ex)
		if (hs->type == CODE_LSHST)
			WebNotation::postprocess(hs->texts[0], ntn);
}

@<Scan content@> =
	from = 0, to = -1;
	int i; inchar32_t c;
	for (i=0; i<Str::len(from_text); i++) {
		c = Str::get_at(from_text, i); @<Run FSM@>;
	}
	c = '\n'; @<Run FSM@>;
	to = Str::len(from_text)-1;
	if ((to >= from) || ((from == 0) && (to == -1) && (lst->next_line))) {
		fsm_state *current = FSM::last_nonintermediate_state(machine);
		if ((Str::ne(current->mnemonic, I"multi-line-comment")) &&
			(Str::ne(current->mnemonic, I"holon")) &&
			(Str::ne(current->mnemonic, I"file-holon")))
			CodeExcerpts::new_code_splice(ex, lst, from_text, from, to);
	}

@<Run FSM@> =
	int N = 0, event = FSM::cycle_machine(machine, c, &N);
	if (recording_to) PUT_TO(recording_to, c);
	switch (event) {
		case NAME_START_FSMEVENT:
			Str::clear(name); to = i-Str::len(WebNotation::left(ntn, NAMED_HOLONS_NTNMARKER));
			recording_to = name;
			break;
		case NAME_END_FSMEVENT: {
			recording_to = NULL;
			int excess = Str::len(WebNotation::right(ntn, NAMED_HOLONS_NTNMARKER));
			Str::truncate(name, Str::len(name) - excess);
			@<Splice code@>;
			to = i;
			@<Splice holon@>;
			break;
		}
		case FILE_NAME_START_FSMEVENT:
			Str::clear(name); to = i-Str::len(WebNotation::left(ntn, FILE_NAMED_HOLONS_NTNMARKER));
			recording_to = name;
			break;
		case FILE_NAME_END_FSMEVENT: {
			recording_to = NULL;
			int excess = Str::len(WebNotation::right(ntn, FILE_NAMED_HOLONS_NTNMARKER));
			Str::truncate(name, Str::len(name) - excess);
			@<Splice code@>;
			to = i;
			@<Splice file holon@>;
			break;
		}
		case COMMAND_START_FSMEVENT:
			Str::clear(command);
			to = i-Str::len(WebNotation::left(ntn, METADATA_IN_STRINGS_NTNMARKER));
			recording_to = command;
			break;
		case COMMAND_END_FSMEVENT: {
			recording_to = NULL;
			@<Splice code@>;
			int excess = Str::len(WebNotation::right(ntn, METADATA_IN_STRINGS_NTNMARKER));
			Str::truncate(command, Str::len(command) - excess);
			to = i;
			@<Splice command@>;
			break;
		}
		case VERBATIM_START_FSMEVENT:
			Str::clear(command);
			to = i-Str::len(WebNotation::left(ntn, VERBATIM_CODE_NTNMARKER));
			recording_to = command;
			break;
		case VERBATIM_END_FSMEVENT: {
			recording_to = NULL;
			@<Splice code@>;
			int excess = Str::len(WebNotation::right(ntn, VERBATIM_CODE_NTNMARKER));
			Str::truncate(command, Str::len(command) - excess);
			to = i;
			@<Splice verbatim@>;
			break;
		}
		case COMMENT_START_FSMEVENT:
			Str::clear(comment); to = i-N; recording_to = comment;
			Str::clear(pre_comment_code);
			WRITE_TO(pre_comment_code, "%S", from_text);
			pre_comment_lst = lst;
			pre_comment_from = from;
			pre_comment_to = to;
			comment_open = Str::new();
			for (int j=to+1; j<=i; j++) PUT_TO(comment_open, Str::get_at(from_text, j));
			break;
		case COMMENT_END_FSMEVENT: {
			recording_to = NULL;
			if (pre_comment_to >= pre_comment_from)
				CodeExcerpts::new_code_splice(ex, pre_comment_lst, pre_comment_code, pre_comment_from, pre_comment_to);
			from = to + 1; to = -1;
			comment_close = Str::new();
			for (int j=Str::len(comment)-N; j<Str::len(comment); j++)
				PUT_TO(comment_close, Str::get_at(comment, j));
			Str::truncate(comment, Str::len(comment) - N);
			to = i;
			@<Splice comment@>;
			break;
		}
	}

@<Splice code@> =
	if (to >= from)
		CodeExcerpts::new_code_splice(ex, lst, from_text, from, to);
	from = to + 1; to = -1;

@<Splice holon@> =
	if (to >= from) {
		holon_splice *hs = CodeExcerpts::new_splice(ex, lst, EXPANSION_LSHST);
		hs->texts[0] = Str::duplicate(name);
		if (Holons::abbreviated(name) == FALSE) {
			TEMPORARY_TEXT(sanitised)
			Holons::sanitise_name(sanitised, name);
			Holons::add_un_to_namespace(sanitised, NULL, ns);
			DISCARD_TEXT(sanitised)
		}
	}
	from = to + 1; to = -1;

@<Splice file holon@> =
	if (to >= from) {
		holon_splice *hs = CodeExcerpts::new_splice(ex, lst, EXPANSION_LSHST);
		hs->texts[0] = Str::duplicate(name);
		if (Holons::abbreviated(name) == FALSE) {
			TEMPORARY_TEXT(sanitised)
			Holons::sanitise_name(sanitised, name);
			Holons::add_un_to_namespace(sanitised, NULL, ns);
			DISCARD_TEXT(sanitised)
		}
	}
	from = to + 1; to = -1;

@<Splice command@> =
	if (to >= from) {
		holon_splice *hs = CodeExcerpts::new_splice(ex, lst, COMMAND_LSHST);
		hs->texts[0] = Str::duplicate(command);
	}
	from = to + 1; to = -1;

@<Splice verbatim@> =
	if (to >= from) {
		holon_splice *hs = CodeExcerpts::new_splice(ex, lst, VERBATIM_LSHST);
		hs->texts[0] = Str::duplicate(command);
	}
	from = to + 1; to = -1;

@<Splice comment@> =
	if (to >= from) {
		holon_splice *hs = CodeExcerpts::new_splice(ex, lst, COMMENT_LSHST);
		hs->texts[0] = Str::duplicate(comment);
		hs->texts[1] = Str::duplicate(comment_open);
		hs->texts[2] = Str::duplicate(comment_close);
	}
	from = to + 1; to = -1;

@<Check final state of machine@> =
	fsm_state *final = FSM::last_nonintermediate_state(machine);
	if (Str::eq(final->mnemonic, I"string"))
		WebErrors::record_at(I"code excerpt ends with string literal open", last_line);
	if (Str::eq(final->mnemonic, I"character"))
		WebErrors::record_at(I"code excerpt ends with character literal open", last_line);
	if (Str::eq(final->mnemonic, I"multi-line-comment"))
		WebErrors::record_at(I"code excerpt ends with comment open", last_line);
