[Makefiles::] Makefiles.

Constructing a suitable makefile for a simple inweb project.

@ This section offers just one function, which constructs a makefile by
following a "prototype".

=
typedef struct makefile_state {
	struct web *for_web;
	struct text_stream to_makefile;
	struct text_stream *repeat_block; /* a "repeatblock" body being scanned */
	int inside_block; /* scanning a "repeatblock" into that text? */
	int last_line_was_blank; /* used to suppress runs of multiple blank lines */
	int allow_commands; /* permit the prototype to use special commands */
} makefile_state;

void Makefiles::write(web *W, filename *prototype, filename *F) {
	makefile_state MS;
	MS.for_web = W;
	MS.last_line_was_blank = TRUE;
	MS.repeat_block = Str::new();
	MS.inside_block = FALSE;
	MS.allow_commands = TRUE;
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
		if (Regexp::match(&mr, line, L" *{repeatblock} *")) @<Begin a repeat block@>;
		if (Regexp::match(&mr, line, L" *{endblock} *"))  @<End a repeat block@>;
		if (MS->inside_block) @<Deal with a line in a repeat block@>;

		if (Regexp::match(&mr, line, L"(%c*){repeatspan}(%c*?){endspan}(%c*)")) @<Deal with a repeat span@>;

		if (Regexp::match(&mr, line, L" *{identity-settings} *")) @<Expand identity-settings@>;
		if (Regexp::match(&mr, line, L" *{platform-settings} *")) @<Expand platform-settings@>;

		if (Regexp::match(&mr, line, L" *{tool} *(%C+) (%C+) (%c+) *")) @<Declare a tool@>;
		if (Regexp::match(&mr, line, L" *{module} *(%C+) (%C+) (%c+) *")) @<Declare a module@>;
		if (Regexp::match(&mr, line, L" *{dep} *(%C+) on (%C+) *")) @<Declare a dependency@>;

		if (Regexp::match(&mr, line, L"(%c*?) *{dependent-files} *")) @<Expand dependent-files@>;
		if (Regexp::match(&mr, line, L"(%c*?) *{dependent-files-for} *(%C+)")) @<Expand dependent-files-for@>;
	}
	Regexp::dispose_of(&mr);

	@<And otherwise copy the line straight through@>;
}

@<Begin a repeat block@> =
	if (MS->inside_block) Errors::in_text_file("nested repeat blocks are not allowed", tfp);
	MS->inside_block = TRUE;
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
	Makefiles::repeat(OUT, NULL, TRUE, MS->repeat_block, TRUE, NULL, tfp, MS);
	Str::clear(MS->repeat_block);
	Regexp::dispose_of(&mr);
	return;

@<Deal with a repeat span@> =
	WRITE("%S", mr.exp[0]);
	Makefiles::repeat(OUT, I" ", FALSE, mr.exp[1], FALSE, NULL, tfp, MS);
	WRITE("%S\n", mr.exp[2]);
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Expand platform-settings@> =
	filename *prototype = Filenames::in_folder(path_to_inweb, I"platform-settings.mk");
	MS->allow_commands = FALSE;
	TextFiles::read(prototype, FALSE, "can't open make settings file",
		TRUE, Makefiles::scan_makefile_line, NULL, MS);
	Regexp::dispose_of(&mr);
	MS->allow_commands = TRUE;
	return;

@<Expand identity-settings@> =
	WRITE("MYNAME = %S\n", Pathnames::directory_name(MS->for_web->path_to_web));
	WRITE("ME = %p\n", MS->for_web->path_to_web);
	module *MW = MS->for_web->as_module;
	module *X = FIRST_IN_LINKED_LIST(module, MW->dependencies);
	if (X) {
		WRITE("# which depends on:\n");
		int N = 1;
		LOOP_OVER_LINKED_LIST(X, module, MW->dependencies) {
			WRITE("MODULE%d = %p\n", N, X->module_location);
			N++;
		}
	}
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Declare a tool@> =
	Modules::new(mr.exp[0], Pathnames::from_text(mr.exp[2]), MAKEFILE_TOOL_MOM);
	WRITE("%SWEB = %S\n", mr.exp[0], mr.exp[2]);
	WRITE("%SMAKER = $(%SWEB)/%S.mk\n", mr.exp[0], mr.exp[0], mr.exp[1]);
	WRITE("%SX = $(%SWEB)/Tangled/%S\n", mr.exp[0], mr.exp[0], mr.exp[1]);
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Declare a module@> =
	Modules::new(mr.exp[0], Pathnames::from_text(mr.exp[2]), MAKEFILE_MODULE_MOM);
	WRITE("%SWEB = %S\n", mr.exp[0], mr.exp[2]);
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Declare a dependency@> =
	module *MA = Modules::find_loaded_by_name(tfp, mr.exp[0]);
	module *MB = Modules::find_loaded_by_name(tfp, mr.exp[1]);
	if ((MA) && (MB)) Modules::dependency(MA, MB);
	Regexp::dispose_of(&mr);
	return;

@<Expand dependent-files@> =
	WRITE("%S", mr.exp[0]);
	if ((MS->for_web) && (MS->for_web->chaptered == FALSE))
		WRITE(" $(ME)/Contents.w $(ME)/Sections/*.w");
	else
		WRITE(" $(ME)/Contents.w $(ME)/Chapter*/*.w");
	module *MW = MS->for_web->as_module;
	module *X = FIRST_IN_LINKED_LIST(module, MW->dependencies);
	if (X) {
		int N = 1;
		LOOP_OVER_LINKED_LIST(X, module, MW->dependencies) {
			WRITE(" $(MODULE%d)/Contents.w $(MODULE%d)/Chapter*/*.w", N, N);
			N++;
		}
	}
	WRITE("\n");
	MS->last_line_was_blank = FALSE;
	Regexp::dispose_of(&mr);
	return;

@<Expand dependent-files-for@> =
	WRITE("%S", mr.exp[0]);
	module *MW = Modules::find_loaded_by_name(tfp, mr.exp[1]);
	if (MW) {
		WRITE(" $(%SWEB)/Contents.w $(%SWEB)/Chapter*/*.w",
			MW->module_name, MW->module_name, MW->module_name);
		module *X;
		LOOP_OVER_LINKED_LIST(X, module, MW->dependencies) {
			WRITE(" $(%SWEB)/Contents.w $(%SWEB)/Chapter*/*.w",
				X->module_name, X->module_name, X->module_name);
		}
		WRITE("\n");
	}
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

@ And finally, the following handles repetitions both of blocks and of spans:

=
void Makefiles::repeat(OUTPUT_STREAM, text_stream *prefix, int every_time, text_stream *matter,
	int as_lines, text_stream *suffix, text_file_position *tfp, makefile_state *MS) {
	module *M;
	int c = 0;
	LOOP_OVER(M, module) {
		if (M->origin_marker == MAKEFILE_TOOL_MOM) {
			if ((prefix) && ((c++ > 0) || (every_time))) WRITE("%S", prefix);
			if (matter) {
				TEMPORARY_TEXT(line);
				LOOP_THROUGH_TEXT(pos, matter) {
					if (Str::get(pos) == '\n') {
						if (as_lines) {
							Makefiles::scan_makefile_line(line, tfp, (void *) MS);
							Str::clear(line);
						}
					} else {
						if (Str::get(pos) == '*') {
							WRITE_TO(line, "%S", M->module_name);
						} else {
							PUT_TO(line, Str::get(pos));
						}
					}
				}
				if (!as_lines) WRITE("%S", line);
				DISCARD_TEXT(line);
			}
			if (suffix) WRITE("%S", suffix);
		}
	}
}
