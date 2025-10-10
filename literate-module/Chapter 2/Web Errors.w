[WebErrors::] Web Errors.

To store and sometimes to issue errors arising from parsing malformed webs
of literate source text.

@ Errors usually can't be reported at the time when they're detected, so we
need to store them up, with this:

=
typedef struct ls_error {
	int warning;
	struct ls_line *line;
	struct text_file_position tfp;
	struct text_stream *message;
	CLASS_DEFINITION
} ls_error;

void WebErrors::record_at(text_stream *message, ls_line *lst) {
	if (lst == NULL) {
		internal_error("unlocated error");
	} else {
		ls_unit *lsu = lst->owning_chunk->owner->owning_unit;
		WebErrors::record_in_unit(message, lst, lsu);
	}
}

void WebErrors::record_warning_at(text_stream *message, ls_line *lst) {
	if (lst == NULL) {
		internal_error("unlocated warning");
	} else {
		ls_unit *lsu = lst->owning_chunk->owner->owning_unit;
		WebErrors::record_warning_in_unit(message, lst, lsu);
	}
}

ls_error *WebErrors::record_in_unit(text_stream *message, ls_line *lst, ls_unit *lsu) {
	ls_error *error = CREATE(ls_error);
	error->warning = FALSE;
	error->message = Str::duplicate(message);
	error->tfp = lst->origin;
	error->line = lst;
	if (lsu == NULL) lsu = LiterateSource::unit_of_line(lst);
	if (lsu == NULL) internal_error("unlocated error");
	ADD_TO_LINKED_LIST(error, ls_error, lsu->errors);
	return error;
}

void WebErrors::record_warning_in_unit(text_stream *message, ls_line *lst, ls_unit *lsu) {
	ls_error *error = CREATE(ls_error);
	error->warning = TRUE;
	error->message = Str::duplicate(message);
	error->tfp = lst->origin;
	error->line = lst;
	ADD_TO_LINKED_LIST(error, ls_error, lsu->errors);
}

void WebErrors::write(OUTPUT_STREAM, ls_error *error) {
	if (error->warning) WRITE("tangle warning: ");
	else WRITE("tangle error: ");
	if (error->tfp.text_file_filename)
		WRITE("%f, line %d: ", error->tfp.text_file_filename, error->tfp.line_count);
	WRITE("%S", error->message);
}

@ These are ways to issue errors immediately, then:

=
void WebErrors::issue_at(text_stream *message, ls_line *lst) {
	if (lst) {
		ls_error *error = WebErrors::record_in_unit(message, lst, NULL);
		WebErrors::issue_recorded(error);
	} else {
		#ifdef THIS_IS_INWEB
		no_inweb_errors++;
		#endif
		Errors::in_text_file_S(message, NULL);
	}
}

void WebErrors::issue_recorded(ls_error *error) {
	if (error->warning) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "warning: %S", error->message);
		Errors::in_text_file_S(msg, &(error->tfp));
		DISCARD_TEXT(msg)
	} else {
		Errors::in_text_file_S(error->message, &(error->tfp));
	}
	if (error->line) WRITE_TO(STDERR, "%07d  %S\n",
		error->tfp.line_count, error->line->text);
	#ifdef THIS_IS_INWEB
	no_inweb_errors++;
	#endif
}

void WebErrors::issue_all_recorded(ls_web *W) {
	ls_chapter *C;
	ls_section *S;
	ls_error *error;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			LOOP_OVER_LINKED_LIST(error, ls_error, S->literate_source->errors)
				WebErrors::issue_recorded(error);
}
