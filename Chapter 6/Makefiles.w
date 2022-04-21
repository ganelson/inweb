[Makefiles::] Makefiles.

Constructing a suitable makefile for a simple inweb project.

@ This section offers just one function, which constructs a makefile by
following a "prototype".

@d MAX_MAKEFILE_MACRO_PARAMETERS 8
@d MAX_MAKEFILE_MACRO_LINES 128

=
typedef struct makefile_macro {
	struct text_stream *identifier;
	struct makefile_macro_parameter *parameters[MAX_MAKEFILE_MACRO_PARAMETERS];
	int no_parameters;
	struct text_stream *lines[MAX_MAKEFILE_MACRO_LINES];
	int no_lines;
	CLASS_DEFINITION
} makefile_macro;

typedef struct makefile_macro_parameter {
	struct text_stream *name;
	struct text_stream *definition_token;
	int optional;
	CLASS_DEFINITION
} makefile_macro_parameter;

typedef struct makefile_macro_playback {
	struct makefile_macro *which;
	struct text_stream *parameter_values[MAX_MAKEFILE_MACRO_PARAMETERS];
	int line_position;
	struct makefile_macro_playback *prior_to_this;
	struct text_stream *text_to_follow;
	CLASS_DEFINITION
} makefile_macro_playback;

typedef struct makefile_state {
	struct web *for_web;
	struct text_stream to_makefile;
	struct text_stream *repeat_block; /* a "repeatblock" body being scanned */
	struct makefile_macro *defining; /* a "define" body being scanned */
	struct makefile_macro_playback *playing_back;
	int inside_block; /* scanning a "repeatblock" into that text? */
	int last_line_was_blank; /* used to suppress runs of multiple blank lines */
	int allow_commands; /* permit the prototype to use special commands */
	int repeat_scope; /* during a repeat, either |MAKEFILE_TOOL_MOM| or |MAKEFILE_MODULE_MOM| */
	struct text_stream *repeat_tag;
	struct dictionary *tools_dictionary;
	struct dictionary *webs_dictionary;
	struct dictionary *modules_dictionary;
	struct module_search *search_path;
} makefile_state;

void Makefiles::write(web *W, filename *prototype, filename *F, module_search *I) {
	makefile_state MS;
	MS.for_web = W;
	MS.last_line_was_blank = TRUE;
	MS.repeat_block = Str::new();
	MS.defining = NULL;
	MS.playing_back = NULL;
	MS.inside_block = FALSE;
	MS.allow_commands = TRUE;
	MS.tools_dictionary = Dictionaries::new(16, FALSE);
	MS.webs_dictionary = Dictionaries::new(16, FALSE);
	MS.modules_dictionary = Dictionaries::new(16, FALSE);
	MS.search_path = I;
	MS.repeat_scope = -1;
	MS.repeat_tag = NULL;
	text_stream *OUT = &(MS.to_makefile);
	if (STREAM_OPEN_TO_FILE(OUT, F, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", F);
	WRITE("# This makefile was automatically written by inweb -makefile\n");
	WRITE("# and is not intended for human editing\n\n");
	TextFiles::read(prototype, FALSE, "can't open prototype file",
		TRUE, Makefiles::scan_makefile_line, NULL, &MS);
	STREAM_CLOSE(OUT);
	WRITE_TO(STDOUT, "Wrote makefile '%f' from script '%f'\n", F, prototype);
}

@ =
void Makefiles::scan_makefile_line(text_stream *line, text_file_position *tfp, void *X) {
	makefile_state *MS = (makefile_state *) X;
	text_stream *OUT = &(MS->to_makefile);

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *#%c*")) { Regexp::dispose_of(&mr); return; } // Skip comment lines
	if (MS->allow_commands) {
		if (Regexp::match(&mr, line, L" *{define: *(%C+) (%c*)} *")) @<Begin a definition@>;
		if (Regexp::match(&mr, line, L" *{end-define} *")) @<End a definition@>;
		if (MS->defining) @<Continue a definition@>;

		if (Regexp::match(&mr, line, L" *{repeat-tools-block:(%C*)} *"))
			@<Begin a repeat tool block@>;
		if (Regexp::match(&mr, line, L" *{repeat-webs-block:(%C*)} *"))
			@<Begin a repeat web block@>;
		if (Regexp::match(&mr, line, L" *{repeat-modules-block:(%C*)} *"))
			@<Begin a repeat module block@>;
		if (Regexp::match(&mr, line, L" *{end-block} *")) @<End a repeat block@>;
		if (MS->inside_block) @<Deal with a line in a repeat block@>;

		if (Regexp::match(&mr, line, L"(%c*){repeat-tools-span}(%c*?){end-span}(%c*)"))
			@<Deal with a repeat span@>;
		if (Regexp::match(&mr, line, L"(%c*){repeat-webs-span}(%c*?){end-span}(%c*)"))
			@<Deal with a repeat web span@>;
		if (Regexp::match(&mr, line, L"(%c*){repeat-modules-span}(%c*?){end-span}(%c*)"))
			@<Deal with a repeat module span@>;

		if (Regexp::match(&mr, line, L" *{identity-settings} *")) @<Expand identity-settings@>;
		if (Regexp::match(&mr, line, L" *{platform-settings} *")) @<Expand platform-settings@>;

		if (Regexp::match(&mr, line, L" *{tool} *(%C+) (%C+) (%c+) (%C+) *")) @<Declare a tool@>;
		if (Regexp::match(&mr, line, L" *{web} *(%C+) (%C+) (%c+) (%C+) *")) @<Declare a web@>;
		if (Regexp::match(&mr, line, L" *{module} *(%C+) (%C+) (%c+) (%C+) *")) @<Declare a module@>;

		if (Regexp::match(&mr, line, L"(%c*?) *{dependent-files} *")) @<Expand dependent-files@>;
		if (Regexp::match(&mr, line, L"(%c*?) *{dependent-files-for-tool-alone} *(%C+)"))
			@<Expand dependent-files-for-tool-alone@>;
		if (Regexp::match(&mr, line, L"(%c*?) *{dependent-files-for-tool-and-modules} *(%C+)"))
			@<Expand dependent-files-for-tool@>;
		if (Regexp::match(&mr, line, L"(%c*?) *{dependent-files-for-module} *(%C+)"))
			@<Expand dependent-files-for-module@>;
		
		if (Regexp::match(&mr, line, L"(%c*?) *{(%C+) *(%c+?)} *(%c*?)")) @<Expand a macro@>;
	}
	Regexp::dispose_of(&mr);

	@<And otherwise copy the line straight through@>;
}

@<Begin a definition@> =
	if (MS->defining) Errors::in_text_file("nested definitions are not allowed", tfp);
	text_stream *name = mr.exp[0];
	text_stream *parameter_specification = mr.exp[1];
	makefile_macro *new_macro = CREATE(makefile_macro);
	new_macro->identifier = Str::duplicate(name);
	new_macro->no_parameters = 0;
	new_macro->no_lines = 0;

	match_results mr2 = Regexp::create_mr();
	while (Regexp::match(&mr2, parameter_specification, L" *(%C+): *(%C+) *(%c*)")) {
		if (new_macro->no_parameters >= MAX_MAKEFILE_MACRO_PARAMETERS) {
			Errors::in_text_file("too many parameters in this definition", tfp);
			break;
		}
		makefile_macro_parameter *new_parameter = CREATE(makefile_macro_parameter);
		new_parameter->name = Str::duplicate(mr2.exp[0]);
		new_parameter->definition_token = Str::duplicate(mr2.exp[1]);
		new_parameter->optional = FALSE;
		if (Str::get_first_char(new_parameter->name) == '?') {
			new_parameter->optional = TRUE;
			Str::delete_first_character(new_parameter->name);
		}
		new_macro->parameters[new_macro->no_parameters++] = new_parameter;
		Str::clear(parameter_specification);
		Str::copy(parameter_specification, mr2.exp[2]);
	}
	Regexp::dispose_of(&mr2);
	if (Str::is_whitespace(parameter_specification) == FALSE)
		Errors::in_text_file("parameter list for this definition is malformed", tfp);
	
	MS->defining = new_macro;
	Regexp::dispose_of(&mr);
	return;

@<Continue a definition@> =
	if (MS->defining->no_lines >= MAX_MAKEFILE_MACRO_LINES) {
		Errors::in_text_file("too many lines in this definition", tfp);
	} else {
		MS->defining->lines[MS->defining->no_lines++] = Str::duplicate(line);
	}
	Regexp::dispose_of(&mr);
	return;

@<End a definition@> =
	if (MS->defining == NULL) Errors::in_text_file("{end-define} without {define: ...}", tfp);
	MS->defining = NULL;
	Regexp::dispose_of(&mr);
	return;

@<Expand a macro@> =
	text_stream *before_matter = mr.exp[0];
	text_stream *identifier = mr.exp[1];
	text_stream *parameter_settings = mr.exp[2];
	text_stream *after_matter = mr.exp[3];
	
	makefile_macro_playback *playback = CREATE(makefile_macro_playback);
	playback->which = NULL;
	makefile_macro *mm;
	LOOP_OVER(mm, makefile_macro)
		if (Str::eq(mm->identifier, identifier))
			playback->which = mm;
	if (playback->which == NULL) {
		Errors::in_text_file("unknown macro or command in braces", tfp);
		Regexp::dispose_of(&mr);
		return;
	}
	
	for (int i=0; i<MAX_MAKEFILE_MACRO_PARAMETERS; i++)
		playback->parameter_values[i] = NULL;

	match_results mr2 = Regexp::create_mr();
	while (Regexp::match(&mr2, parameter_settings, L" *(%C+): *(%C+) *(%c*)")) {
		text_stream *setting = mr2.exp[0];
		text_stream *value = mr2.exp[1];
		text_stream *remainder = mr2.exp[2];
		int found = FALSE;
		for (int i=0; i<playback->which->no_parameters; i++)
			if (Str::eq(setting, playback->which->parameters[i]->name)) {
				found = TRUE;
				playback->parameter_values[i] = Str::duplicate(value);
			}
		if (found == FALSE) Errors::in_text_file("unknown parameter in this macro", tfp);
		Str::clear(parameter_settings);
		Str::copy(parameter_settings, remainder);
	}
	Regexp::dispose_of(&mr2);
	if (Str::is_whitespace(parameter_settings) == FALSE)
		Errors::in_text_file("parameter list for this macro is malformed", tfp);
	
	for (int i=0; i<playback->which->no_parameters; i++)
		if (playback->parameter_values[i] == NULL)
			if (playback->which->parameters[i]->optional == FALSE)
				Errors::in_text_file("compulsory macro parameter not given", tfp);

	playback->line_position = 0;
	playback->prior_to_this = MS->playing_back;
	playback->text_to_follow = NULL;	
	if (Str::is_whitespace(after_matter) == FALSE)
		playback->text_to_follow = Str::duplicate(after_matter);

	MS->playing_back = playback;
	WRITE("%S", before_matter);
	for (int i=0; i<playback->which->no_lines; i++) {
		TEMPORARY_TEXT(line)
		text_stream *from = playback->which->lines[i];
		for (int j=0; j<Str::len(from); j++) {
			if (Str::get_at(from, j) == '{') {
				int closed = FALSE, old_j = j;
				TEMPORARY_TEXT(token)
				for (j++; j<Str::len(from); j++) {
					if (Str::get_at(from, j) == '}') { closed = TRUE; break; }
					PUT_TO(token, Str::get_at(from, j));
				}
				if (closed) {
					int found = FALSE;
					for (int i=0; i<playback->which->no_parameters; i++)
						if (Str::eq(token, playback->which->parameters[i]->definition_token)) {
							found = TRUE;
							WRITE_TO(line, "%S", playback->parameter_values[i]);
						}
					if (found == FALSE) closed = FALSE;
				}
				DISCARD_TEXT(token)
				if (closed == FALSE) { j = old_j; PUT_TO(line, '{'); }
			} else {
				PUT_TO(line, Str::get_at(from, j));
			}
		}
		Makefiles::scan_makefile_line(line, tfp, (void *) MS);
		DISCARD_TEXT(line)
	}
	MS->playing_back = playback->prior_to_this;
	if (Str::is_whitespace(after_matter) == FALSE)
		WRITE("%S\n", after_matter);
	Regexp::dispose_of(&mr);
	return;

@<Begin a repeat tool block@> =
	int marker = MAKEFILE_TOOL_MOM;
	@<Begin a repeat block@>;

@<Begin a repeat web block@> =
	int marker = MAKEFILE_WEB_MOM;
	@<Begin a repeat block@>;

@<Begin a repeat module block@> =
	int marker = MAKEFILE_MODULE_MOM;
	@<Begin a repeat block@>;

@<Begin a repeat block@> =
	if (MS->inside_block) Errors::in_text_file("nested repeat blocks are not allowed", tfp);
	MS->inside_block = TRUE;
	MS->repeat_scope = marker;
	MS->repeat_tag = Str::duplicate(mr.exp[0]);
	Str::clear(MS->repeat_block);
	Regexp::dispose_of(&mr);
	return;

@<Deal with a line in a repeat block@> =
	WRITE_TO(MS->repeat_block, "%S\n", line);
	return;

@<End a repeat block@> =
	if (MS->inside_block == FALSE)
		Errors::in_text_file("{endblock} without {repeatblock}", tfp);
	MS->inside_block = FALSE;
	Makefiles::repeat(OUT, NULL, TRUE, MS->repeat_block, TRUE, NULL, tfp, MS, MS->repeat_scope, MS->repeat_tag);
	Str::clear(MS->repeat_block);
	Regexp::dispose_of(&mr);
	return;

@<Deal with a repeat span@> =
	int marker = MAKEFILE_TOOL_MOM;
	@<Begin a repeat span@>;

@<Deal with a repeat web span@> =
	int marker = MAKEFILE_WEB_MOM;
	@<Begin a repeat span@>;

@<Deal with a repeat module span@> =
	int marker = MAKEFILE_MODULE_MOM;
	@<Begin a repeat span@>;

@<Begin a repeat span@> =
	WRITE("%S", mr.exp[0]);
	Makefiles::repeat(OUT, I" ", FALSE, mr.exp[1], FALSE, NULL, tfp, MS, marker, I"all");
	WRITE("%S\n", mr.exp[2]);
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Expand platform-settings@> =
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
			TRUE, Makefiles::scan_makefile_line, NULL, MS);
		WRITE_TO(STDOUT, "(Read definitions from %f)\n", F);
	}
	Regexp::dispose_of(&mr);
	return;

@<Expand identity-settings@> =
	WRITE("INWEB = "); Makefiles::pathname_slashed(OUT, path_to_inweb); WRITE("/Tangled/inweb\n");
	pathname *path_to_intest = Pathnames::down(Pathnames::up(path_to_inweb), I"intest");
	WRITE("INTEST = "); Makefiles::pathname_slashed(OUT, path_to_intest); WRITE("/Tangled/intest\n");
	if (MS->for_web) {
		WRITE("MYNAME = %S\n", Pathnames::directory_name(MS->for_web->md->path_to_web));
		WRITE("ME = "); Makefiles::pathname_slashed(OUT, MS->for_web->md->path_to_web);
		WRITE("\n");
		MS->last_line_was_blank = FALSE;
	}
	Regexp::dispose_of(&mr);
	return;

@<Declare a tool@> =
	int marker = MAKEFILE_TOOL_MOM;
	dictionary *D = MS->tools_dictionary;
	@<Declare something@>;

@<Declare a web@> =
	int marker = MAKEFILE_WEB_MOM;
	dictionary *D = MS->webs_dictionary;
	@<Declare something@>;

@<Declare a module@> =
	int marker = MAKEFILE_MODULE_MOM;
	dictionary *D = MS->modules_dictionary;
	@<Declare something@>;

@<Declare something@> =
	WRITE("%SLEAF = %S\n", mr.exp[0], mr.exp[1]);
	WRITE("%SWEB = %S\n", mr.exp[0], mr.exp[2]);
	WRITE("%SMAKER = $(%SWEB)/%S.mk\n", mr.exp[0], mr.exp[0], mr.exp[1]);
	WRITE("%SX = $(%SWEB)/Tangled/%S\n", mr.exp[0], mr.exp[0], mr.exp[1]);
	MS->last_line_was_blank = FALSE;
	web_md *Wm = Reader::load_web_md(Pathnames::from_text(mr.exp[2]), NULL, MS->search_path, TRUE);
	Wm->as_module->module_name = Str::duplicate(mr.exp[0]);
	Wm->as_module->module_tag = Str::duplicate(mr.exp[3]);
	Wm->as_module->origin_marker = marker;
	Dictionaries::create(D, mr.exp[0]);
	Dictionaries::write_value(D, mr.exp[0], Wm);
	Regexp::dispose_of(&mr);
	return;

@<Expand dependent-files@> =
	WRITE("%S", mr.exp[0]);
	Makefiles::pattern(OUT, MS->for_web->md->sections_md, MS->for_web->md->contents_filename);
	WRITE("\n");
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Expand dependent-files-for-tool@> =
	WRITE("%S", mr.exp[0]);
	if (Dictionaries::find(MS->tools_dictionary, mr.exp[1])) {
		web_md *Wm = Dictionaries::read_value(MS->tools_dictionary, mr.exp[1]);
		Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
	} else if (Dictionaries::find(MS->webs_dictionary, mr.exp[1])) {
		web_md *Wm = Dictionaries::read_value(MS->webs_dictionary, mr.exp[1]);
		Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
	} else {
		PRINT("Tool %S\n", mr.exp[0]);
		Errors::in_text_file("unknown tool to find dependencies for", tfp);
	}
	WRITE("\n");
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Expand dependent-files-for-tool-alone@> =
	WRITE("%S", mr.exp[0]);
	if (Dictionaries::find(MS->tools_dictionary, mr.exp[1])) {
		web_md *Wm = Dictionaries::read_value(MS->tools_dictionary, mr.exp[1]);
		Makefiles::pattern(OUT, Wm->as_module->sections_md, Wm->contents_filename);
	} else if (Dictionaries::find(MS->webs_dictionary, mr.exp[1])) {
		web_md *Wm = Dictionaries::read_value(MS->webs_dictionary, mr.exp[1]);
		Makefiles::pattern(OUT, Wm->as_module->sections_md, Wm->contents_filename);
	} else {
		PRINT("Tool %S\n", mr.exp[0]);
		Errors::in_text_file("unknown tool to find dependencies for", tfp);
	}
	WRITE("\n");
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Expand dependent-files-for-module@> =
	WRITE("%S", mr.exp[0]);
	if (Dictionaries::find(MS->modules_dictionary, mr.exp[1])) {
		web_md *Wm = Dictionaries::read_value(MS->modules_dictionary, mr.exp[1]);
		Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
	} else {
		Errors::in_text_file("unknown module to find dependencies for", tfp);
		WRITE_TO(STDERR, "-- module name: %S\n", mr.exp[1]);
	}
	WRITE("\n");
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<And otherwise copy the line straight through@> =
	if (Str::len(line) == 0) {
		if (MS->last_line_was_blank == FALSE) WRITE("\n");
		MS->last_line_was_blank = TRUE;
	} else {
		MS->last_line_was_blank = FALSE;
		WRITE("%S\n", line);
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

@ And finally, the following handles repetitions both of blocks and of spans:

=
void Makefiles::repeat(OUTPUT_STREAM, text_stream *prefix, int every_time, text_stream *matter,
	int as_lines, text_stream *suffix, text_file_position *tfp, makefile_state *MS, int over, text_stream *tag) {
	module *M;
	int c = 0;
	LOOP_OVER(M, module) {
		if ((M->origin_marker == over) &&
			((Str::eq(tag, I"all")) || (Str::eq(tag, M->module_tag)))) {
			if ((prefix) && ((c++ > 0) || (every_time))) WRITE("%S", prefix);
			if (matter) {
				TEMPORARY_TEXT(line)
				LOOP_THROUGH_TEXT(pos, matter) {
					if (Str::get(pos) == '\n') {
						if (as_lines) {
							Makefiles::scan_makefile_line(line, tfp, (void *) MS);
							Str::clear(line);
						}
					} else {
						if (Str::get(pos) == '@') {
							WRITE_TO(line, "%S", M->module_name);
						} else {
							PUT_TO(line, Str::get(pos));
						}
					}
				}
				if (!as_lines) WRITE("%S", line);
				DISCARD_TEXT(line)
			}
			if (suffix) WRITE("%S", suffix);
		}
	}
}

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
