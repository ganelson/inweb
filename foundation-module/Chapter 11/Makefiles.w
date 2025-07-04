[Makefiles::] Makefiles.

Constructing a suitable makefile for a simple inweb project.

@h Preprocessing.
We will use //foundation: Preprocessor// with four special macros and one
special loop construct.

=
void Makefiles::write(ls_web *W, filename *prototype, filename *F, module_search *I,
	text_stream *platform) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	Preprocessor::new_macro(L,
		I"platform-settings", NULL,
		Makefiles::platform_settings_expander, NULL);
	Preprocessor::new_macro(L,
		I"identity-settings", NULL,
		Makefiles::identity_settings_expander, NULL);
	preprocessor_macro *mf = Preprocessor::new_macro(L,
		I"modify-filenames", I"original: ORIGINAL ?suffix: SUFFIX ?prefix: PREFIX",
		Makefiles::modify_filenames_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(mf);
	Preprocessor::new_macro(L,
		I"component", I"symbol: SYMBOL webname: WEBNAME path: PATH set: SET type: TYPE",
		Makefiles::component_expander, NULL);
	Preprocessor::new_macro(L,
		I"dependent-files", I"?tool: TOOL ?module: MODULES ?tool-and-modules: BOTH",
		Makefiles::dependent_files_expander, NULL);
	Preprocessor::new_loop_macro(L,
		I"components", I"type: TYPE ?set: SET",
		Makefiles::components_expander, NULL);

	makefile_specifics *specifics = CREATE(makefile_specifics);
	@<Initialise the specific data for makefile-preprocessing@>;

	text_stream *header = Str::new();
	WRITE_TO(header, "# This makefile was automatically written by inweb -makefile\n");
	WRITE_TO(header, "# and is not intended for human editing\n\n");
	WRITE_TO(STDOUT, "(Read script from %f)\n", prototype);

	Preprocessor::preprocess(prototype, F, header, L,
		STORE_POINTER_makefile_specifics(specifics), '#', ISO_ENC);
}

@ We will allow a makescript to declare "components" (webs, really), so we need
a data structure to store those declarations in:

=
typedef struct makefile_specifics {
	struct ls_web *for_web; /* if one has been set at the command line */
	struct dictionary *tools_dictionary;   /* components with |type: tool| */
	struct dictionary *webs_dictionary;    /* components with |type: web| */
	struct dictionary *modules_dictionary; /* components with |type: module| */
	struct module_search *search_path;
	struct text_stream *which_platform;
	CLASS_DEFINITION
} makefile_specifics;

@<Initialise the specific data for makefile-preprocessing@> =
	specifics->for_web = W;
	specifics->tools_dictionary = Dictionaries::new(16, FALSE);
	specifics->webs_dictionary = Dictionaries::new(16, FALSE);
	specifics->modules_dictionary = Dictionaries::new(16, FALSE);
	specifics->search_path = I;
	specifics->which_platform = platform;

@h The identity-settings expander.

=
void Makefiles::identity_settings_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *OUT = PPS->dest;
	WRITE("INWEB = "); Makefiles::pathname_slashed(OUT, Pathnames::path_to_inweb()); WRITE("/Tangled/inweb\n");
	pathname *path_to_intest = Pathnames::down(Pathnames::up(Pathnames::path_to_inweb()), I"intest");
	WRITE("INTEST = "); Makefiles::pathname_slashed(OUT, path_to_intest); WRITE("/Tangled/intest\n");
	if (specifics->for_web) {
		WRITE("MYNAME = %S\n", Pathnames::directory_name(specifics->for_web->path_to_web));
		WRITE("ME = "); Makefiles::pathname_slashed(OUT, specifics->for_web->path_to_web);
		WRITE("\n");
		PPS->last_line_was_blank = FALSE;
	}
}

@h The platform-settings expander.
We first scan the platform settings file for a definition line in the shape
INWEBPLATFORM = PLATFORM, in order to find out what PLATFORM the make file will
be used on. Then we splice in the appropriate file of standard definitions for
that platform.

=
void Makefiles::platform_settings_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *INWEBPLATFORM = Str::duplicate(specifics->which_platform);
	if (Str::len(INWEBPLATFORM) == 0) {
		filename *ps = Filenames::in(Pathnames::path_to_inweb(), I"platform-settings.mk");
		TextFiles::read(ps, FALSE, "can't open platform settings file",
			TRUE, Makefiles::seek_INWEBPLATFORM, NULL, INWEBPLATFORM);
	}
	if (Str::len(INWEBPLATFORM) == 0) {
		Errors::in_text_file(
			"found platform settings file, but it does not set INWEBPLATFORM", tfp);
	} else {
		pathname *P = Pathnames::down(Pathnames::path_to_inweb(), I"Materials");
		P = Pathnames::down(P, I"platforms");
		WRITE_TO(INWEBPLATFORM, ".mkscript");
		filename *F = Filenames::in(P, INWEBPLATFORM);
		TextFiles::read(F, FALSE, "can't open platform definitions file",
			TRUE, Preprocessor::scan_line, NULL, PPS);
		WRITE_TO(STDOUT, "(Read definitions file '%S' from ", INWEBPLATFORM);
		Pathnames::to_text_relative(STDOUT, Pathnames::path_to_inweb(), P);
		WRITE_TO(STDOUT, ")\n");
	}
}

void Makefiles::seek_INWEBPLATFORM(text_stream *line, text_file_position *tfp, void *X) {
	text_stream *OUT = (text_stream *) X;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U" *INWEBPLATFORM = (%C+) *")) WRITE("%S", mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@h The modify filename expander.

=
void Makefiles::modify_filenames_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	text_stream *OUT = PPS->dest;

	text_stream *original = parameter_values[0];
	text_stream *suffix = parameter_values[1];
	text_stream *prefix = parameter_values[2];

	inchar32_t previous = 'X'; int quoted = FALSE, boundary = FALSE;
	TEMPORARY_TEXT(captured)
	LOOP_THROUGH_TEXT(pos, original) {
		inchar32_t c = Str::get(pos);
		if (c == '\'') { quoted = quoted?FALSE:TRUE; }
		if (Characters::is_whitespace(c)) {
			if ((previous != '\\') && (quoted == FALSE)) boundary = TRUE;
		} else {
			if (boundary) @<Captured a name@>;
			boundary = FALSE;
		}
		PUT_TO(captured, c);
		previous = c;
	}
	@<Captured a name@>
	DISCARD_TEXT(captured)
}

@<Captured a name@> =
	Str::trim_white_space(captured);
	if (Str::len(captured) > 0) {
		int in_quotes = FALSE;
		if ((Str::get_first_char(captured) == '\'') && (Str::get_last_char(captured) == '\'')) {
			Str::delete_first_character(captured);
			Str::delete_last_character(captured);
			in_quotes = TRUE;
		}
		if (in_quotes) WRITE("'");
		int last_slash = -1;
		for (int i=0; i<Str::len(captured); i++)
			if (Str::get_at(captured, i) == '/')
				last_slash = i;
		int last_dot = Str::len(captured);
		for (int i=last_slash+1; i<Str::len(captured); i++)
			if (Str::get_at(captured, i) == '.')
				last_dot = i;
		for (int i=0; i<=last_slash; i++) PUT(Str::get_at(captured, i));
		WRITE("%S", prefix);
		for (int i=last_slash+1; i<last_dot; i++) PUT(Str::get_at(captured, i));
		WRITE("%S", suffix);
		for (int i=last_dot; i<Str::len(captured); i++) PUT(Str::get_at(captured, i));
		if (in_quotes) WRITE("'");
		Str::clear(captured);
		WRITE(" ");
	}

@h The component expander.

=
void Makefiles::component_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *OUT = PPS->dest;

	text_stream *symbol = parameter_values[0];
	text_stream *webname = parameter_values[1];
	text_stream *path = parameter_values[2];
	text_stream *set = parameter_values[3];
	text_stream *category = parameter_values[4];
	
	if (Str::eq(category, I"tool")) {
		int marker = MAKEFILE_TOOL_MOM;
		dictionary *D = specifics->tools_dictionary;
		@<Add to dictionary@>;
		@<Derive some make symbols@>;
	} else if (Str::eq(category, I"web")) {
		int marker = MAKEFILE_WEB_MOM;
		dictionary *D = specifics->webs_dictionary;
		@<Add to dictionary@>;
		@<Derive some make symbols@>;
	} else if (Str::eq(category, I"module")) {
		int marker = MAKEFILE_MODULE_MOM;
		dictionary *D = specifics->modules_dictionary;
		@<Add to dictionary@>;
		@<Derive some make symbols@>;
	} else {
		Errors::in_text_file("category should be 'tool', 'module' or 'web'", tfp);
	}
	PPS->last_line_was_blank = FALSE;
}

@<Add to dictionary@> =
	#ifndef THIS_IS_INWEB
	int verbose_mode = FALSE;
	#endif
	ls_web *Wm = WebStructure::get(Pathnames::from_text(path), NULL, NULL,
		specifics->search_path, verbose_mode, TRUE, NULL);
	Wm->main_module->module_name = Str::duplicate(symbol);
	Wm->main_module->module_tag = Str::duplicate(set);
	Wm->main_module->origin_marker = marker;
	Dictionaries::create(D, symbol);
	Dictionaries::write_value(D, symbol, Wm);

@<Derive some make symbols@> =
	WRITE("%SLEAF = %S\n", symbol, webname);
	WRITE("%SWEB = %S\n", symbol, path);
	WRITE("%SMAKER = $(%SWEB)/%S.mk\n", symbol, symbol, webname);
	WRITE("%SX = $(%SWEB)/Tangled/%S\n", symbol, symbol, webname);

@h The components loop construct.

=
void Makefiles::components_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	Preprocessor::set_loop_var_name(loop, I"SYMBOL");
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
	ls_module *M;
	LOOP_OVER(M, ls_module) {
		if ((M->origin_marker == marker) &&
			((Str::eq(set, I"all")) || (Str::eq(set, M->module_tag)))) {
			text_stream *value = M->module_name;
			Preprocessor::add_loop_iteration(loop, value);
		}
	}

@h The dependent-files expander.

=
void Makefiles::dependent_files_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	makefile_specifics *specifics = RETRIEVE_POINTER_makefile_specifics(PPS->specifics);
	text_stream *OUT = PPS->dest;

	text_stream *tool = parameter_values[0];
	text_stream *modules = parameter_values[1];
	text_stream *both = parameter_values[2];
	if (Str::len(tool) > 0) {
		if (Dictionaries::find(specifics->tools_dictionary, tool)) {
			ls_web *Wm = Dictionaries::read_value(specifics->tools_dictionary, tool);
			Makefiles::pattern(OUT, Makefiles::all_sections_in_module(Wm->main_module), Wm->contents_filename);
		} else if (Dictionaries::find(specifics->webs_dictionary, tool)) {
			ls_web *Wm = Dictionaries::read_value(specifics->webs_dictionary, tool);
			Makefiles::pattern(OUT, Makefiles::all_sections_in_module(Wm->main_module), Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown tool '%S' to find dependencies for", tool);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else if (Str::len(modules) > 0) {
		if (Dictionaries::find(specifics->modules_dictionary, modules)) {
			ls_web *Wm = Dictionaries::read_value(specifics->modules_dictionary, modules);
			Makefiles::pattern(OUT, Makefiles::all_sections(Wm), Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown module '%S' to find dependencies for", modules);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else if (Str::len(both) > 0) {
		if (Dictionaries::find(specifics->tools_dictionary, both)) {
			ls_web *Wm = Dictionaries::read_value(specifics->tools_dictionary, both);
			Makefiles::pattern(OUT, Makefiles::all_sections(Wm), Wm->contents_filename);
		} else if (Dictionaries::find(specifics->webs_dictionary, both)) {
			ls_web *Wm = Dictionaries::read_value(specifics->webs_dictionary, both);
			Makefiles::pattern(OUT, Makefiles::all_sections(Wm), Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown tool '%S' to find dependencies for", both);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else {
		Makefiles::pattern(OUT, Makefiles::all_sections(specifics->for_web),
			specifics->for_web->contents_filename);
	}
	WRITE("\n");
	PPS->last_line_was_blank = FALSE;
}

linked_list *Makefiles::all_sections(ls_web *W) {
	linked_list *L = NEW_LINKED_LIST(ls_section);
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			ADD_TO_LINKED_LIST(S, ls_section, L);
	return L;
}

linked_list *Makefiles::all_sections_in_module(ls_module *M) {
	linked_list *L = NEW_LINKED_LIST(ls_section);
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, M->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			ADD_TO_LINKED_LIST(S, ls_section, L);
	return L;
}

@ This outputs a makefile pattern matching a bunch of web source code filenames:
say, |inweb/Chapter\ %d/*.w|.

=
void Makefiles::pattern(OUTPUT_STREAM, linked_list *L, filename *F) {
	dictionary *patterns_done = Dictionaries::new(16, TRUE);
	if (F) @<Add pattern for file F, if not already given@>;
	ls_section *Sm;
	LOOP_OVER_LINKED_LIST(Sm, ls_section, L) {
		filename *F = Sm->source_file_for_section;
		@<Add pattern for file F, if not already given@>;
	}
}

@<Add pattern for file F, if not already given@> =
	pathname *P = Filenames::up(F);
	TEMPORARY_TEXT(leaf_pattern)
	WRITE_TO(leaf_pattern, "%S", Pathnames::directory_name(P));
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, leaf_pattern, U"Chapter %d*")) {
		Str::clear(leaf_pattern); WRITE_TO(leaf_pattern, "Chapter*");
	} else if (Regexp::match(&mr, leaf_pattern, U"Appendix %C")) {
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
			inchar32_t c = Str::get(pos);
			if (c == ' ') PUT('\\');
			PUT(c);
		}
	}
	DISCARD_TEXT(tester)

@ In makefile syntax, spaces must be preceded by slashes in filenames. (That
bald statement really doesn't begin to go into how awkward makefiles can be
when filenames have spaces in, but there we are.)

=
void Makefiles::pathname_slashed(OUTPUT_STREAM, pathname *P) {
	TEMPORARY_TEXT(PT)
	WRITE_TO(PT, "%p", P);
	LOOP_THROUGH_TEXT(pos, PT) {
		inchar32_t c = Str::get(pos);
		if (c == ' ') WRITE("\\ ");
		else PUT(c);
	}
	DISCARD_TEXT(PT)
}
