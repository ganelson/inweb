[Configuration::] Configuration.

To parse the command line arguments with which inweb was called,
and to handle any errors it needs to issue.

@h Instructions.
The following structure exists just to hold what the user specified on the
command line: there will only ever be one of these.

=
typedef struct inweb_instructions {
	int inweb_mode; /* our main mode of operation: one of the |*_MODE| constants */
	struct pathname *chosen_web; /* project folder relative to cwd */
	struct filename *chosen_file; /* or, single file relative to cwd */
	struct text_stream *chosen_range; /* which subset of this web we apply to (often, all of it) */
	int chosen_range_actually_chosen; /* rather than being a default choice */

	int swarm_mode; /* relevant to weaving only: one of the |*_SWARM| constants */
	struct text_stream *tag_setting; /* |-weave-tag X|: weave, but only the material tagged X */
	struct text_stream *weave_format; /* |-weave-as X|: for example, |-weave-as TeX| */
	struct text_stream *weave_pattern; /* |-weave-to X|: for example, |-weave-to HTML| */
	int weave_docs; /* |-docs|: for GitHub Pages */

	int show_languages_switch; /* |-show-languages|: print list of available PLs */
	int catalogue_switch; /* |-catalogue|: print catalogue of sections */
	int functions_switch; /* |-functions|: print catalogue of functions within sections */
	int structures_switch; /* |-structures|: print catalogue of structures within sections */
	int advance_switch; /* |-advance-build|: advance build file for web */
	int open_pdf_switch; /* |-open-pdf|: open any woven PDF in the OS once it is made */
	int scan_switch; /* |-scan|: simply show the syntactic scan of the source */
	struct filename *weave_to_setting; /* |-weave-to X|: the pathname X, if supplied */
	struct pathname *weave_into_setting; /* |-weave-into X|: the pathname X, if supplied */
	int sequential; /* give the sections sequential sigils */
	struct filename *tangle_setting; /* |-tangle-to X|: the pathname X, if supplied */
	struct filename *makefile_setting; /* |-makefile X|: the filename X, if supplied */
	struct filename *gitignore_setting; /* |-gitignore X|: the filename X, if supplied */
	struct filename *advance_setting; /* |-advance-build-file X|: advance build file X */
	struct filename *writeme_setting; /* |-write-me X|: advance build file X */
	struct filename *prototype_setting; /* |-prototype X|: the pathname X, if supplied */
	struct filename *navigation_setting; /* |-navigation X|: the filename X, if supplied */
	struct filename *colony_setting; /* |-colony X|: the filename X, if supplied */
	struct linked_list *breadcrumb_setting; /* of |breadcrumb_request| */
	int verbose_switch; /* |-verbose|: print names of files read to stdout */
	int targets; /* used only for parsing */

	struct programming_language *test_language_setting; /* |-test-language X| */
	struct filename *test_language_on_setting; /* |-test-language-on X| */

	struct pathname *import_setting; /* |-import X|: where to find imported webs */
} inweb_instructions;

typedef struct breadcrumb_request {
	struct text_stream *breadcrumb_text;
	struct text_stream *breadcrumb_link;
	MEMORY_MANAGEMENT
} breadcrumb_request;

@h Reading the command line.
The dull work of this is done by the Foundation module: all we need to do is
to enumerate constants for the Inweb-specific command line switches, and
then declare them.

=
inweb_instructions Configuration::read(int argc, char **argv) {
	inweb_instructions args;
	@<Initialise the args@>;
	@<Declare the command-line switches specific to Inweb@>;
	CommandLine::read(argc, argv, &args, &Configuration::switch, &Configuration::bareword);
	if ((args.chosen_web == NULL) && (args.chosen_file == NULL)) {
		if ((args.makefile_setting) || (args.gitignore_setting))
			args.inweb_mode = TRANSLATE_MODE;
		if (args.inweb_mode != TRANSLATE_MODE)
			args.inweb_mode = NO_MODE;
	}
	if (Str::len(args.chosen_range) == 0) {
		Str::copy(args.chosen_range, I"0");
	}
	return args;
}

@<Initialise the args@> =
	args.inweb_mode = NO_MODE;
	args.swarm_mode = SWARM_OFF_SWM;
	args.show_languages_switch = FALSE;
	args.catalogue_switch = FALSE;
	args.functions_switch = FALSE;
	args.structures_switch = FALSE;
	args.advance_switch = FALSE;
	args.open_pdf_switch = NOT_APPLICABLE;
	args.scan_switch = FALSE;
	args.verbose_switch = FALSE;
	args.chosen_web = NULL;
	args.chosen_file = NULL;
	args.chosen_range = Str::new();
	args.chosen_range_actually_chosen = FALSE;
	args.tangle_setting = NULL;
	args.weave_to_setting = NULL;
	args.weave_into_setting = NULL;
	args.makefile_setting = NULL;
	args.gitignore_setting = NULL;
	args.advance_setting = NULL;
	args.writeme_setting = NULL;
	args.prototype_setting = NULL;
	args.navigation_setting = NULL;
	args.colony_setting = NULL;
	args.breadcrumb_setting = NEW_LINKED_LIST(breadcrumb_request);
	args.tag_setting = Str::new();
	args.weave_pattern = Str::new_from_wide_string(L"HTML");
	args.weave_docs = FALSE;
	args.import_setting = NULL;
	args.targets = 0;
	args.test_language_setting = NULL;
	args.test_language_on_setting = NULL;

@ The CommandLine section of Foundation needs to be told what command-line
switches we want, other than the standard set (such as |-help|) which it
provides automatically.

@e VERBOSE_CLSW
@e IMPORT_FROM_CLSW

@e LANGUAGES_CLSG

@e LANGUAGE_CLSW
@e LANGUAGES_CLSW
@e SHOW_LANGUAGES_CLSW
@e TEST_LANGUAGE_CLSW
@e TEST_LANGUAGE_ON_CLSW

@e ANALYSIS_CLSG

@e CATALOGUE_CLSW
@e FUNCTIONS_CLSW
@e STRUCTURES_CLSW
@e ADVANCE_CLSW
@e GITIGNORE_CLSW
@e MAKEFILE_CLSW
@e WRITEME_CLSW
@e ADVANCE_FILE_CLSW
@e PROTOTYPE_CLSW
@e SCAN_CLSW

@e WEAVING_CLSG

@e WEAVE_CLSW
@e WEAVE_INTO_CLSW
@e WEAVE_TO_CLSW
@e OPEN_CLSW
@e WEAVE_AS_CLSW
@e WEAVE_TAG_CLSW
@e WEAVE_DOCS_CLSW
@e BREADCRUMB_CLSW
@e NAVIGATION_CLSW
@e COLONY_CLSW

@e TANGLING_CLSG

@e TANGLE_CLSW
@e TANGLE_TO_CLSW

@<Declare the command-line switches specific to Inweb@> =
	CommandLine::declare_heading(L"inweb: a tool for literate programming\n\n"
		L"Usage: inweb WEB OPTIONS RANGE\n\n"
		L"WEB must be a directory holding a literate program (a 'web')\n\n"
		L"The legal RANGEs are:\n"
		L"   all: complete web (the default if no TARGETS set)\n"
		L"   P: all preliminaries\n"
		L"   1: Chapter 1 (and so on)\n"
		L"   A: Appendix A (and so on, up to Appendix O)\n"
		L"   3/eg: section with abbreviated name \"3/eg\" (and so on)\n"
		L"You can also, or instead, specify:\n"
		L"   index: to weave an HTML page indexing the project\n"
		L"   chapters: to weave all chapters as individual documents\n"
		L"   sections: ditto with sections\n");

	CommandLine::begin_group(LANGUAGES_CLSG,
		I"for locating programming language definitions");
	CommandLine::declare_switch(LANGUAGE_CLSW, L"read-language", 2,
		L"read language definition from file X");
	CommandLine::declare_switch(LANGUAGES_CLSW, L"read-languages", 2,
		L"read all language definitions in path X");
	CommandLine::declare_switch(SHOW_LANGUAGES_CLSW, L"show-languages", 1,
		L"list programming languages supported by Inweb");
	CommandLine::declare_switch(TEST_LANGUAGE_CLSW, L"test-language", 2,
		L"test language X on...");
	CommandLine::declare_switch(TEST_LANGUAGE_ON_CLSW, L"test-language-on", 2,
		L"...the code in the file X");
	CommandLine::end_group();

	CommandLine::begin_group(ANALYSIS_CLSG,
		I"for analysing a web");
	CommandLine::declare_switch(CATALOGUE_CLSW, L"catalogue", 1,
		L"list the sections in the web");
	CommandLine::declare_switch(CATALOGUE_CLSW, L"catalog", 1,
		L"same as '-catalogue'");
	CommandLine::declare_switch(MAKEFILE_CLSW, L"makefile", 2,
		L"write a makefile for this web and store it in X");
	CommandLine::declare_switch(GITIGNORE_CLSW, L"gitignore", 2,
		L"write a .gitignore file for this web and store it in X");
	CommandLine::declare_switch(ADVANCE_FILE_CLSW, L"advance-build-file", 2,
		L"increment daily build code in file X");
	CommandLine::declare_switch(WRITEME_CLSW, L"write-me", 2,
		L"write a read-me file following instructions in file X");
	CommandLine::declare_switch(PROTOTYPE_CLSW, L"prototype", 2,
		L"translate makefile from prototype X");
	CommandLine::declare_switch(FUNCTIONS_CLSW, L"functions", 1,
		L"catalogue the functions in the web");
	CommandLine::declare_switch(STRUCTURES_CLSW, L"structures", 1,
		L"catalogue the structures in the web");
	CommandLine::declare_switch(ADVANCE_CLSW, L"advance-build", 1,
		L"increment daily build code for the web");
	CommandLine::declare_switch(SCAN_CLSW, L"scan", 1,
		L"scan the web");
	CommandLine::end_group();

	CommandLine::begin_group(WEAVING_CLSG,
		I"for weaving a web");
	CommandLine::declare_switch(WEAVE_DOCS_CLSW, L"weave-docs", 1,
		L"weave the web for use at GitHub Pages");
	CommandLine::declare_switch(WEAVE_CLSW, L"weave", 1,
		L"weave the web into human-readable form");
	CommandLine::declare_switch(WEAVE_INTO_CLSW, L"weave-into", 2,
		L"weave, but into directory X");
	CommandLine::declare_switch(WEAVE_TO_CLSW, L"weave-to", 2,
		L"weave, but to filename X (for single files only)");
	CommandLine::declare_switch(OPEN_CLSW, L"open", 1,
		L"weave then open woven file");
	CommandLine::declare_switch(WEAVE_AS_CLSW, L"weave-as", 2,
		L"set weave pattern to X (default is 'HTML')");
	CommandLine::declare_switch(WEAVE_TAG_CLSW, L"weave-tag", 2,
		L"weave, but only using material tagged as X");
	CommandLine::declare_switch(BREADCRUMB_CLSW, L"breadcrumb", 2,
		L"use the text X as a breadcrumb in overhead navigation");
	CommandLine::declare_switch(NAVIGATION_CLSW, L"navigation", 2,
		L"use the file X as a column of navigation links");
	CommandLine::declare_switch(COLONY_CLSW, L"colony", 2,
		L"use the file X as a list of webs in this colony");
	CommandLine::end_group();

	CommandLine::begin_group(TANGLING_CLSG,
		I"for tangling a web");
	CommandLine::declare_switch(TANGLE_CLSW, L"tangle", 1,
		L"tangle the web into machine-compilable form");
	CommandLine::declare_switch(TANGLE_TO_CLSW, L"tangle-to", 2,
		L"tangle, but to filename X");
	CommandLine::end_group();

	CommandLine::declare_boolean_switch(VERBOSE_CLSW, L"verbose", 1,
		L"explain what inweb is doing", FALSE);
	CommandLine::declare_switch(IMPORT_FROM_CLSW, L"import-from", 2,
		L"specify that imported modules are at pathname X");

@ Foundation calls this on any |-switch| argument read:

=
void Configuration::switch(int id, int val, text_stream *arg, void *state) {
	inweb_instructions *args = (inweb_instructions *) state;
	switch (id) {
		/* Miscellaneous */
		case VERBOSE_CLSW: args->verbose_switch = TRUE; break;
		case IMPORT_FROM_CLSW: args->import_setting = Pathnames::from_text(arg); break;

		/* Analysis */
		case LANGUAGE_CLSW:
			Languages::read_definition(Filenames::from_text(arg)); break;
		case LANGUAGES_CLSW:
			Languages::read_definitions(Pathnames::from_text(arg)); break;
		case SHOW_LANGUAGES_CLSW:
			args->show_languages_switch = TRUE;
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case TEST_LANGUAGE_CLSW:
			args->test_language_setting =
				Languages::read_definition(Filenames::from_text(arg));
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case TEST_LANGUAGE_ON_CLSW:
			args->test_language_on_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case CATALOGUE_CLSW:
			args->catalogue_switch = TRUE;
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case FUNCTIONS_CLSW:
			args->functions_switch = TRUE;
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case STRUCTURES_CLSW:
			args->structures_switch = TRUE;
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case ADVANCE_CLSW:
			args->advance_switch = TRUE;
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;
		case MAKEFILE_CLSW:
			args->makefile_setting = Filenames::from_text(arg);
			if (args->inweb_mode != TRANSLATE_MODE)
				Configuration::set_fundamental_mode(args, ANALYSE_MODE);
			break;
		case GITIGNORE_CLSW:
			args->gitignore_setting = Filenames::from_text(arg);
			if (args->inweb_mode != TRANSLATE_MODE)
				Configuration::set_fundamental_mode(args, ANALYSE_MODE);
			break;
		case ADVANCE_FILE_CLSW:
			args->advance_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, TRANSLATE_MODE);
			break;
		case WRITEME_CLSW:
			args->writeme_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, TRANSLATE_MODE);
			break;
		case PROTOTYPE_CLSW:
			args->prototype_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, TRANSLATE_MODE); break;
		case SCAN_CLSW:
			args->scan_switch = TRUE;
			Configuration::set_fundamental_mode(args, ANALYSE_MODE); break;

		/* Weave-related */
		case WEAVE_CLSW:
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case WEAVE_DOCS_CLSW:
			args->weave_docs = TRUE;
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case WEAVE_INTO_CLSW:
			args->weave_into_setting = Pathnames::from_text(arg);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case WEAVE_TO_CLSW:
			args->weave_to_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case OPEN_CLSW:
			args->open_pdf_switch = TRUE;
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case WEAVE_AS_CLSW:
			args->weave_pattern = Str::duplicate(arg);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case WEAVE_TAG_CLSW:
			args->tag_setting = Str::duplicate(arg);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case BREADCRUMB_CLSW:
			ADD_TO_LINKED_LIST(Configuration::breadcrumb(arg),
				breadcrumb_request, args->breadcrumb_setting);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case NAVIGATION_CLSW:
			args->navigation_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;
		case COLONY_CLSW:
			args->colony_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, WEAVE_MODE); break;

		/* Tangle-related */
		case TANGLE_CLSW:
			Configuration::set_fundamental_mode(args, TANGLE_MODE); break;
		case TANGLE_TO_CLSW:
			args->tangle_setting = Filenames::from_text(arg);
			Configuration::set_fundamental_mode(args, TANGLE_MODE); break;

		default: internal_error("unimplemented switch");
	}
}

breadcrumb_request *Configuration::breadcrumb(text_stream *arg) {
	breadcrumb_request *BR = CREATE(breadcrumb_request);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, arg, L"(%c*?): *(%c*)")) {
		BR->breadcrumb_text = Str::duplicate(mr.exp[0]);
		BR->breadcrumb_link = Str::duplicate(mr.exp[1]);	
	} else {
		BR->breadcrumb_text = Str::duplicate(arg);
		BR->breadcrumb_link = Str::duplicate(arg);
		WRITE_TO(BR->breadcrumb_link, ".html");
	}
	Regexp::dispose_of(&mr);
	return BR;
}

@ Foundation calls this routine on any command-line argument which is
neither a switch (like |-weave|), nor an argument for a switch (like
the |X| in |-weave-as X|).

=
void Configuration::bareword(int id, text_stream *opt, void *state) {
	inweb_instructions *args = (inweb_instructions *) state;
	if ((args->chosen_web == NULL) && (args->chosen_file == NULL)) {
		if (Str::suffix_eq(opt, I".inweb", 6))
			args->chosen_file = Filenames::from_text(opt);
		else
			args->chosen_web = Pathnames::from_text(opt);
	} else Configuration::set_range(args, opt);
}

@ Here we read a range. The special ranges |index|, |chapters| and |sections|
are converted into swarm settings instead. |all| is simply an alias for |0|.
Otherwise, a range is a chapter number/letter, or a section range.

=
void Configuration::set_range(inweb_instructions *args, text_stream *opt) {
	match_results mr = Regexp::create_mr();
	if (Str::eq_wide_string(opt, L"index")) {
		args->swarm_mode = SWARM_INDEX_SWM;
	} else if (Str::eq_wide_string(opt, L"chapters")) {
		args->swarm_mode = SWARM_CHAPTERS_SWM;
	} else if (Str::eq_wide_string(opt, L"sections")) {
		args->swarm_mode = SWARM_SECTIONS_SWM;
	} else {
		if (++args->targets > 1) Errors::fatal("at most one target may be given");
		if (Str::eq_wide_string(opt, L"all")) {
			Str::copy(args->chosen_range, I"0");
		} else if (((isalnum(Str::get_first_char(opt))) && (Str::len(opt) == 1))
			|| (Regexp::match(&mr, opt, L"%i+/%i+"))) {
			Str::copy(args->chosen_range, opt);
			string_position P = Str::start(args->chosen_range);
			Str::put(P, toupper(Str::get(P)));
		} else {
			TEMPORARY_TEXT(ERM);
			WRITE_TO(ERM, "target not recognised (see -help for more): %S", opt);
			Main::error_in_web(ERM, NULL);
			DISCARD_TEXT(ERM);
			exit(1);
		}
	}
	args->chosen_range_actually_chosen = TRUE;
	Regexp::dispose_of(&mr);
}

@ We can only be in a single mode at a time:

=
void Configuration::set_fundamental_mode(inweb_instructions *args, int new_material) {
	if ((args->inweb_mode != NO_MODE) && (args->inweb_mode != new_material))
		Errors::fatal("can only do one at a time - weaving, tangling or analysing");
	args->inweb_mode = new_material;
}
