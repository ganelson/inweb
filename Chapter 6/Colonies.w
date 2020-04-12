[Colonies::] Colonies.

Cross-referencing multiple webs gathered together.

@

=
typedef struct colony {
	struct linked_list *members; /* of |colony_member| */
	MEMORY_MANAGEMENT
} colony;

typedef struct colony_member {
	int web_rather_than_module;
	struct text_stream *name;
	struct text_stream *path;
	struct pathname *weave_path;
	struct web_md *loaded;
	MEMORY_MANAGEMENT
} colony_member;

@ =
void Colonies::load(filename *F) {
	colony *C = CREATE(colony);
	C->members = NEW_LINKED_LIST(colony_member);
	TextFiles::read(F, FALSE, "can't open colony file",
		TRUE, Colonies::read_line, NULL, (void *) C);
}

void Colonies::read_line(text_stream *line, text_file_position *tfp, void *v_C) {
	colony *C = (colony *) v_C;

	Str::trim_white_space(line); /* ignore trailing space */
	if (Str::len(line) == 0) return; /* ignore blank lines */
	if (Str::get_first_char(line) == '#') return; /* lines opening with |#| are comments */

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c*?): \"*(%C+)\" at \"(%c*)\" in \"(%c*)\"")) {
		colony_member *CM = CREATE(colony_member);
		if (Str::eq(mr.exp[0], I"web")) CM->web_rather_than_module = TRUE;
		else if (Str::eq(mr.exp[0], I"module")) CM->web_rather_than_module = FALSE;
		else {
			CM->web_rather_than_module = FALSE;
			Errors::in_text_file("text before ':' must be 'web' or 'module'", tfp);
		}
		CM->name = Str::duplicate(mr.exp[1]);
		CM->path = Str::duplicate(mr.exp[2]);
		CM->weave_path = Pathnames::from_text(mr.exp[3]);
		CM->loaded = NULL;
		ADD_TO_LINKED_LIST(CM, colony_member, C->members);
	} else {
		Errors::in_text_file("unable to read colony member", tfp);
	}
	Regexp::dispose_of(&mr);
}

@ =
colony_member *Colonies::member(text_stream *T) {
	colony *C;
	LOOP_OVER(C, colony) {
		colony_member *CM;
		LOOP_OVER_LINKED_LIST(CM, colony_member, C->members)
			if (Str::eq_insensitive(T, CM->name))
				return CM;
	}
	return NULL;
}

@ =
module *Colonies::as_module(colony_member *CM, source_line *L, web_md *Wm) {
	if (CM->loaded == NULL) {
		if ((Wm) && (Str::eq_insensitive(Wm->as_module->module_name, CM->name)))
			CM->loaded = Wm;
	}
	if (CM->loaded == NULL) {
		if (Wm) {
			module *M;
			LOOP_OVER_LINKED_LIST(M, module, Wm->as_module->dependencies)
				if (Str::eq_insensitive(M->module_name, CM->name))
					CM->loaded = Wm;
		}
	}
	if (CM->loaded == NULL) {
		filename *F = NULL;
		pathname *P = NULL;
		if (Str::suffix_eq(CM->path, I".inweb", 6))
			F = Filenames::from_text(CM->path);
		else
			P = Pathnames::from_text(CM->path);
		PRINT("So %f and %p\n", F, P);
		CM->loaded = WebMetadata::get_without_modules(P, F);
	}
	if (CM->loaded == NULL) {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "unable to load '%S'", CM->name);
		Main::error_in_web(err, L);
		return NULL;
	}
	return CM->loaded->as_module;
}

@ The following must decide what a reference like "Chapter 3" should refer
to: that is, whether it makes unamgiguous sense, and if so, what URL we should
link to, and what the full text of the link might be.

=
int Colonies::resolve_reference_in_weave(text_stream *url, text_stream *title,
	weave_target *wv, text_stream *text, web_md *Wm, source_line *L) {
	module *from_M = (Wm)?(Wm->as_module):NULL;
	module *search_M = from_M;
	colony_member *search_CM = NULL;
	match_results mr = Regexp::create_mr();
	int external = FALSE;
	
	search_CM = Colonies::member(text);
	if (search_CM) {
		module *found_M = Colonies::as_module(search_CM, L, Wm);
		section_md *found_Sm = FIRST_IN_LINKED_LIST(section_md, found_M->sections_md);
		int bare_module_name = TRUE;
		WRITE_TO(title, "%S", search_CM->name);
		@<Resolved@>;
		return TRUE;
	}

	if (Regexp::match(&mr, text, L"(%c*?): (%c*)")) {
		search_CM = Colonies::member(mr.exp[0]);
		if (search_CM) {
			module *found_M = Colonies::as_module(search_CM, L, Wm);
			if (found_M) {
				search_M = found_M;
				text = Str::duplicate(mr.exp[1]);
				external = TRUE;
			}
		}
	}
	Regexp::dispose_of(&mr);

	if (search_M == NULL) internal_error("no search module");

	module *found_M = NULL;
	section_md *found_Sm = NULL;
	int bare_module_name = FALSE;
	int N = WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
		title, search_M, text, FALSE);
	if (N == 0) {
		if ((L) && (external == FALSE)) @<Try references to non-sections@>;
		Main::error_in_web(I"Can't find this cross-reference", L);
		return FALSE;
	} else if (N > 1) {
		Main::error_in_web(I"Multiple cross-references might be meant here", L);
		WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
			title, search_M, text, TRUE);
		return FALSE;
	} else {
		@<Resolved@>;
		return TRUE;
	}
}

@<Try references to non-sections@> =
	language_function *fn;
	LOOP_OVER(fn, language_function) {
		if (Str::eq_insensitive(fn->function_name, text)) {
			HTMLFormat::xref(url, wv, fn->function_header_at->owning_paragraph,
				L->owning_section, TRUE);
			WRITE_TO(title, "%S", fn->function_name);
			return TRUE;
		}
	}
	language_type *str;
	LOOP_OVER(str, language_type) {
		if (Str::eq_insensitive(str->structure_name, text)) {
			HTMLFormat::xref(url, wv, str->structure_header_at->owning_paragraph,
				L->owning_section, TRUE);
			WRITE_TO(title, "%S", str->structure_name);
			return TRUE;
		}
	}

@<Resolved@> =
	if (found_M == NULL) internal_error("could not locate M");
	if (search_CM) {
		pathname *from = Filenames::get_path_to(wv->weave_to);
		pathname *to = search_CM->weave_path;
		int found = FALSE;
		for (pathname *P = to; P && (found == FALSE); P = Pathnames::up(P)) {
			TEMPORARY_TEXT(PT);
			WRITE_TO(PT, "%p", P);
			int q_up_count = 0;
			for (pathname *Q = from; Q && (found == FALSE); Q = Pathnames::up(Q)) {
				TEMPORARY_TEXT(QT);
				WRITE_TO(QT, "%p", Q);
				if (Str::eq(PT, QT)) {
					for (int i=0; i<q_up_count; i++)
						WRITE_TO(url, "../");
					TEMPORARY_TEXT(FPT);
					WRITE_TO(FPT, "%p", to);
					Str::substr(url, Str::at(FPT, Str::len(PT) + 1), Str::end(FPT));
					found = TRUE;
				}
				DISCARD_TEXT(QT);
				q_up_count++;
			}
			DISCARD_TEXT(PT);
		}
		if (found == FALSE) internal_error("no relation made");
		if (Str::len(url) > 0) WRITE_TO(url, "/");
		if (bare_module_name) WRITE_TO(url, "index.html");
		else if (found_Sm) HTMLFormat::section_URL(url, wv, found_Sm); 
		if (bare_module_name == FALSE)
			WRITE_TO(title, " (in %S)", search_CM->name);
	} else {
		if (found_M != from_M) {
			WRITE_TO(url, "../%S-module/", found_M->module_name);
		}
		HTMLFormat::section_URL(url, wv, found_Sm); 
		if ((bare_module_name == FALSE) && (found_M != from_M)) {
			WRITE_TO(title, " (in %S)", found_M->module_name);
		}
	}
	return TRUE;
