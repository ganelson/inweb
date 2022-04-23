[Makefiles::] Makefiles.

Constructing a suitable makefile for a simple inweb project.

@h Introduction.
At some point, the material in this section will probably be spun out into an
an independent tool called "inmake". It's a simple utility for constructing makefiles,
but has gradually become less simple over time, as is the way of these things.

The idea is simple enough: the user writes a "makescript", which is really a
makefile but with the possibility of using some higher-level features, and we
translate that it into an actual makefile (which is usually longer and less
easy to read).

@

=
typedef struct makefile_specifics {
	struct web *for_web;
	struct dictionary *tools_dictionary;
	struct dictionary *webs_dictionary;
	struct dictionary *modules_dictionary;
	struct module_search *search_path;
	CLASS_DEFINITION
} makefile_specifics;

void Makefiles::write(web *W, filename *prototype, filename *F, module_search *I) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	Preprocessor::reserve_macro(L, I"platform-settings", NULL, Makefiles::platform_settings_expander);
	Preprocessor::reserve_macro(L, I"identity-settings", NULL, Makefiles::identity_settings_expander);
	Preprocessor::reserve_macro(L, I"component",
		I"symbol: SYMBOL webname: WEBNAME path: PATH set: SET type: TYPE",
		Makefiles::component_expander);
	Preprocessor::reserve_macro(L, I"dependent-files",
		I"?tool: TOOL ?module: MODULES ?tool-and-modules: BOTH",
		Makefiles::dependent_files_expander);
	Preprocessor::reserve_repeat_macro(L, I"components", I"type: TYPE ?set: SET",
		Makefiles::components_expander);
	makefile_specifics *specifics = CREATE(makefile_specifics);
	specifics->for_web = W;
	specifics->tools_dictionary = Dictionaries::new(16, FALSE);
	specifics->webs_dictionary = Dictionaries::new(16, FALSE);
	specifics->modules_dictionary = Dictionaries::new(16, FALSE);
	specifics->search_path = I;
	text_stream *header = Str::new();
	WRITE_TO(header, "# This makefile was automatically written by inweb -makefile\n");
	WRITE_TO(header, "# and is not intended for human editing\n\n");
	WRITE_TO(STDOUT, "(Read script from %f)\n", prototype);
	Preprocessor::preprocess(prototype, F, header, L, STORE_POINTER_makefile_specifics(specifics));
}

void Makefiles::identity_settings_expander(preprocessor_macro *mm, preprocessor_state *PPS, text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *OUT = PPS->dest;
	WRITE("INWEB = "); Makefiles::pathname_slashed(OUT, path_to_inweb); WRITE("/Tangled/inweb\n");
	pathname *path_to_intest = Pathnames::down(Pathnames::up(path_to_inweb), I"intest");
	WRITE("INTEST = "); Makefiles::pathname_slashed(OUT, path_to_intest); WRITE("/Tangled/intest\n");
	if (specifics->for_web) {
		WRITE("MYNAME = %S\n", Pathnames::directory_name(specifics->for_web->md->path_to_web));
		WRITE("ME = "); Makefiles::pathname_slashed(OUT, specifics->for_web->md->path_to_web);
		WRITE("\n");
		PPS->last_line_was_blank = FALSE;
	}
}

void Makefiles::component_expander(preprocessor_macro *mm, preprocessor_state *PPS, text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *OUT = PPS->dest;

	text_stream *symbol = parameter_values[0];
	text_stream *webname = parameter_values[1];
	text_stream *path = parameter_values[2];
	text_stream *set = parameter_values[3];
	text_stream *category = parameter_values[4];
	
	int marker = -1;
	dictionary *D = NULL;
	if (Str::eq(category, I"tool")) {
		marker = MAKEFILE_TOOL_MOM;
		D = specifics->tools_dictionary;
	} else if (Str::eq(category, I"web")) {
		marker = MAKEFILE_WEB_MOM;
		D = specifics->webs_dictionary;
	} else if (Str::eq(category, I"module")) {
		marker = MAKEFILE_MODULE_MOM;
		D = specifics->modules_dictionary;
	} else {
		Errors::in_text_file("category should be 'tool', 'module' or 'web'", tfp);
	}
	if (D) {
		WRITE("%SLEAF = %S\n", symbol, webname);
		WRITE("%SWEB = %S\n", symbol, path);
		WRITE("%SMAKER = $(%SWEB)/%S.mk\n", symbol, symbol, webname);
		WRITE("%SX = $(%SWEB)/Tangled/%S\n", symbol, symbol, webname);
		PPS->last_line_was_blank = FALSE;
		web_md *Wm = Reader::load_web_md(Pathnames::from_text(path), NULL, specifics->search_path, TRUE);
		Wm->as_module->module_name = Str::duplicate(symbol);
		Wm->as_module->module_tag = Str::duplicate(set);
		Wm->as_module->origin_marker = marker;
		Dictionaries::create(D, symbol);
		Dictionaries::write_value(D, symbol, Wm);
	}
}

void Makefiles::dependent_files_expander(preprocessor_macro *mm, preprocessor_state *PPS, text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *OUT = PPS->dest;

	text_stream *tool = parameter_values[0];
	text_stream *modules = parameter_values[1];
	text_stream *both = parameter_values[2];
	if (Str::len(tool) > 0) {
		if (Dictionaries::find(specifics->tools_dictionary, tool)) {
			web_md *Wm = Dictionaries::read_value(specifics->tools_dictionary, tool);
			Makefiles::pattern(OUT, Wm->as_module->sections_md, Wm->contents_filename);
		} else if (Dictionaries::find(specifics->webs_dictionary, tool)) {
			web_md *Wm = Dictionaries::read_value(specifics->webs_dictionary, tool);
			Makefiles::pattern(OUT, Wm->as_module->sections_md, Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown tool '%S' to find dependencies for", tool);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else if (Str::len(modules) > 0) {
		if (Dictionaries::find(specifics->modules_dictionary, modules)) {
			web_md *Wm = Dictionaries::read_value(specifics->modules_dictionary, modules);
			Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown module '%S' to find dependencies for", modules);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else if (Str::len(both) > 0) {
		if (Dictionaries::find(specifics->tools_dictionary, both)) {
			web_md *Wm = Dictionaries::read_value(specifics->tools_dictionary, both);
			Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
		} else if (Dictionaries::find(specifics->webs_dictionary, both)) {
			web_md *Wm = Dictionaries::read_value(specifics->webs_dictionary, both);
			Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown tool '%S' to find dependencies for", both);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else {
		Makefiles::pattern(OUT, specifics->for_web->md->sections_md, specifics->for_web->md->contents_filename);
	}
	WRITE("\n");
	PPS->last_line_was_blank = FALSE;
}

void Makefiles::platform_settings_expander(preprocessor_macro *mm, preprocessor_state *PPS, text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	filename *prototype = Filenames::in(path_to_inweb, I"platform-settings.mk");
	text_stream *INWEBPLATFORM = Str::new();
	TextFiles::read(prototype, FALSE, "can't open platform settings file",
		TRUE, Makefiles::seek_INWEBPLATFORM, NULL, INWEBPLATFORM);
	if (Str::len(INWEBPLATFORM) == 0) {
		Errors::in_text_file(
			"found platform settings file, but it does not set INWEBPLATFORM", tfp);
	} else {
		pathname *P = Pathnames::down(path_to_inweb, I"Materials");
		P = Pathnames::down(P, I"platforms");
		WRITE_TO(INWEBPLATFORM, ".mkscript");
		filename *F = Filenames::in(P, INWEBPLATFORM);
		TextFiles::read(F, FALSE, "can't open platform definitions file",
			TRUE, Preprocessor::scan_line, NULL, PPS);
		WRITE_TO(STDOUT, "(Read definitions file '%S' from ", INWEBPLATFORM);
		Pathnames::to_text_relative(STDOUT, path_to_inweb, P);
		WRITE_TO(STDOUT, ")\n");
	}
}

void Makefiles::components_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	rep->loop_var_name = I"SYMBOL";
	text_stream *category = parameter_values[0];
	text_stream *set = parameter_values[1];
	if (Str::len(set) == 0) set = I"all";
	if (Str::eq(category, I"tool")) {
		int marker = MAKEFILE_TOOL_MOM;
		@<Make the web iterations@>;	
	} else if (Str::eq(category, I"web")) {
		int marker = MAKEFILE_WEB_MOM;
		@<Make the web iterations@>;	
	} else if (Str::eq(category, I"module")) {
		int marker = MAKEFILE_MODULE_MOM;
		@<Make the web iterations@>;	
	} else {
		Errors::in_text_file("category should be 'tool', 'module' or 'web'", tfp);
	}
}

@<Make the web iterations@> =
	module *M;
	LOOP_OVER(M, module) {
		if ((M->origin_marker == marker) &&
			((Str::eq(set, I"all")) || (Str::eq(set, M->module_tag)))) {
			text_stream *value = M->module_name;
			ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, rep->iterations);
		}
	}

@ =
void Makefiles::pathname_slashed(OUTPUT_STREAM, pathname *P) {
	TEMPORARY_TEXT(PT)
	WRITE_TO(PT, "%p", P);
	LOOP_THROUGH_TEXT(pos, PT) {
		wchar_t c = Str::get(pos);
		if (c == ' ') WRITE("\\ ");
		else PUT(c);
	}
	DISCARD_TEXT(PT)
}

void Makefiles::pattern(OUTPUT_STREAM, linked_list *L, filename *F) {
	dictionary *patterns_done = Dictionaries::new(16, TRUE);
	if (F) @<Add pattern for file F, if not already given@>;
	section_md *Sm;
	LOOP_OVER_LINKED_LIST(Sm, section_md, L) {
		filename *F = Sm->source_file_for_section;
		@<Add pattern for file F, if not already given@>;
	}
}

@<Add pattern for file F, if not already given@> =
	pathname *P = Filenames::up(F);
	TEMPORARY_TEXT(leaf_pattern)
	WRITE_TO(leaf_pattern, "%S", Pathnames::directory_name(P));
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, leaf_pattern, L"Chapter %d*")) {
		Str::clear(leaf_pattern); WRITE_TO(leaf_pattern, "Chapter*");
	} else if (Regexp::match(&mr, leaf_pattern, L"Appendix %C")) {
		Str::clear(leaf_pattern); WRITE_TO(leaf_pattern, "Appendix*");
	}
	Regexp::dispose_of(&mr);
	TEMPORARY_TEXT(tester)
	WRITE_TO(tester, "%p/%S/*", Pathnames::up(P), leaf_pattern);
	DISCARD_TEXT(leaf_pattern)
	Filenames::write_extension(tester, F);
	if (Dictionaries::find(patterns_done, tester) == NULL) {
		WRITE_TO(Dictionaries::create_text(patterns_done, tester), "got this");
		WRITE(" ");
		LOOP_THROUGH_TEXT(pos, tester) {
			wchar_t c = Str::get(pos);
			if (c == ' ') PUT('\\');
			PUT(c);
		}
	}
	DISCARD_TEXT(tester)

@ This is used to scan the platform settings file for a definition line in the
shape INWEBPLATFORM = PLATFORM, in order to find out what PLATFORM the make file
will be used on.

=
void Makefiles::seek_INWEBPLATFORM(text_stream *line, text_file_position *tfp, void *X) {
	text_stream *OUT = (text_stream *) X;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *INWEBPLATFORM = (%C+) *")) WRITE("%S", mr.exp[0]);
	Regexp::dispose_of(&mr);
}

