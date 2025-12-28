[InwebWeave::] inweb weave Subcommand.

The inweb weave subcommand weaves a web.

@ The command line interface and help text:

@e WEAVE_CLSUB
@e WEAVE_TO_CLSW
@e WEAVE_AS_CLSW

@e WEAVING_SELECTION_CLSG
@e ONLY_CLSW
@e WEAVE_TAG_CLSW
@e CREATING_CLSW

=
void InwebWeave::cli(void) {
	CommandLine::begin_subcommand(WEAVE_CLSUB, U"weave");
	CommandLine::declare_heading(
		U"Usage: inweb weave [WEB]\n\n"
		U"Weaving is one of the two fundamental operations of literate programming\n"
		U"(for the other, see 'inweb help tangle'). It presents the program in a web\n"
		U"as readably as possible, to facilitate human readers who want to see how\n"
		U"the program works, or why decisions were taken as they were.\n\n"
		U"If no WEB is specified, Inweb tries to weave the current working directory.\n\n"
		U"If the WEB occupies a directory, the output is placed in its 'Woven' subdirectory\n"
		U"by default, but '-to DIRECTORY' can be used to move this (note that DIRECTORY\n"
		U"must already exist). If the WEB is smaller, the woven output might also be just\n"
		U"a single file, and '-to FILE' can be used to select this.\n\n"
		U"For modern LP the most common way to weave a program is to make it into a\n"
		U"website, but there are alternatives, and there are numerous different ways\n"
		U"to make websites. A 'weave pattern' is a set of weaving conventions used by\n"
		U"Inweb, and providing new weave patterns is a good way to customise it. The\n"
		U"'-as PATTERN' switch allows a choice: '-as HTML' and 'as GitHubPages' are\n"
		U"the commonest patterns used.\n\n"
		U"Using '-only 2', we can weave Chapter 2 alone, and '-only 2/it', or similar,\n"
		U"weaves individual sections alone. '-only sections' divides the whole web up\n"
		U"into individual sections, but then weaves all of them independently. Similarly\n"
		U"for '-only chapters'. The default is '-only all', which just does everything.");
	CommandLine::declare_switch(WEAVE_TO_CLSW, U"to", 2,
		U"write the output to a new file X, or into a directory X");
	CommandLine::declare_switch(WEAVE_AS_CLSW, U"as", 2,
		U"set weave pattern to X (default is 'HTML')");
	CommandLine::declare_boolean_switch(CREATING_CLSW, U"creating", 1,
		U"create directories as needed to put the woven output into", FALSE);
		
	CommandLine::begin_group(WEAVING_SELECTION_CLSG,
		I"for weaving only part of a web, not the whole thing");	
	CommandLine::declare_switch(ONLY_CLSW, U"only", 2,
		U"weave only the section or chapter whose abbreviation is X");
	CommandLine::declare_switch(WEAVE_TAG_CLSW, U"only-tagged-as", 2,
		U"weave only those paragraphs in the web tagged as X");
	CommandLine::end_group();
	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_weave_settings {
	struct inweb_range_specifier subset;
	struct text_stream *to_setting;
	struct text_stream *tag_setting;
	struct text_stream *pattern_name;
	int creating_setting;
} inweb_weave_settings;

void InwebWeave::initialise(inweb_weave_settings *iws) {
	iws->subset = Configuration::new_range_specifier();
	iws->to_setting = NULL;
	iws->tag_setting = Str::new();
	iws->pattern_name = I"";
	iws->creating_setting = FALSE;
}

int InwebWeave::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_weave_settings *iws = &(ins->weave_settings);
	switch (id) {
		case WEAVE_TO_CLSW: iws->to_setting = Str::duplicate(arg); return TRUE;
		case WEAVE_AS_CLSW: iws->pattern_name = Str::duplicate(arg); return TRUE;
		case ONLY_CLSW: Configuration::set_range(&(iws->subset), arg, TRUE); return TRUE;
		case WEAVE_TAG_CLSW: iws->tag_setting = Str::duplicate(arg); return TRUE;
		case CREATING_CLSW: iws->creating_setting = val; return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebWeave::run(inweb_instructions *ins) {
	inweb_weave_settings *iws = &(ins->weave_settings);
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_PREFERRED, FALSE, TRUE);
	if (no_inweb_errors > 0) return;
	if (op.W) InwebWeave::run_on(iws, op.C, op.CM, op.W);
	else if (op.C) InwebWeave::run_on_colony(iws, op.C);
	else if ((op.D) && (op.D->declaration_type == COLONY_WCLTYPE)) {
		WCL::parse_declarations_throwing_errors(op.D);
		ls_colony *C = RETRIEVE_POINTER_ls_colony(op.D->object_declared);
		InwebWeave::run_on_colony(iws, C);
	} else {
		if (op.F) Errors::fatal_with_file("file does not appear to be either a web or a colony", op.F);
		if (op.P) Errors::fatal_with_path("directory does not appear to be either a web or a colony", op.P);
		Errors::fatal("inweb weave has to apply to a web or a colony");
	}
}

void InwebWeave::run_on_colony(inweb_weave_settings *iws, ls_colony *C) {
	pathname *into = Colonies::home(C);
	if (Str::len(iws->to_setting) > 0) {
		pathname *P = Pathnames::from_text(iws->to_setting);
		filename *F = Filenames::from_text(iws->to_setting);
		if (Directories::exists(P)) {
			into = P;
		} else if (TextFiles::exists(F)) {
			Errors::fatal_with_path("this is a file, not a directory", P);
		} else {
			into = P;
		}
	}
	Colonies::set_redirect(C, into);
	Colonies::fully_load(C);
	int N = 0;
	ls_colony_member *CM;
	LOOP_OVER_LINKED_LIST(CM, ls_colony_member, C->members)
		if (CM->external == FALSE)
			N++;
	linked_list *skeleton = Colonies::skeleton(C, into);
	@<Ensure that the skeleton of directories needed does exist@>;
	int M = 0;
	LOOP_OVER_LINKED_LIST(CM, ls_colony_member, C->members)
		if (CM->external == FALSE) {
			M++;
			if (M > 1) PRINT("\n");
			PRINT("(Weave %d of %d: %S)\n", M, N, CM->name);
			ls_web *W = WebStructure::read_fully(C, CM->loaded->declaration, FALSE, TRUE, verbose_mode);
			inweb_weave_settings mutable_copy = *iws;
			InwebWeave::run_on(&mutable_copy, C, CM, W);
		}
	if (M == 0) PRINT("(Nothing to do: no internal members in this colony)\n");
	Colonies::set_redirect(C, NULL);
}

@<Ensure that the skeleton of directories needed does exist@> =
	if ((verbose_mode) && (LinkedLists::len(skeleton) > 0)) {
		PRINT("skeleton of directories needed for weave to work: ");
		pathname *P;
		LOOP_OVER_LINKED_LIST(P, pathname, skeleton)
			PRINT("%p  ", P);
		PRINT("\n");
	}
	linked_list *missing_bones = NEW_LINKED_LIST(pathname);
	pathname *P;
	LOOP_OVER_LINKED_LIST(P, pathname, skeleton)
		if (Directories::exists(P) == FALSE) {
			if (iws->creating_setting) {
				if (Pathnames::create_in_file_system(P) == FALSE)
					Errors::fatal_with_path("tried to create directory because of -creating, but file system refused", P);
				if (silent_mode == FALSE) PRINT("(created directory '%p')\n", P);
			} else {
				ADD_TO_LINKED_LIST(P, pathname, missing_bones);
			}
		}
	int mbc = LinkedLists::len(missing_bones);
	if (mbc == 1) WRITE_TO(STDERR, "the weave would require this directory to exist:\n");
	if (mbc > 1) WRITE_TO(STDERR, "the weave would require these %d directories to exist:\n", mbc);
	LOOP_OVER_LINKED_LIST(P, pathname, missing_bones)
		WRITE_TO(STDERR, "    %p\n", P);
	if (mbc > 0) {
		if (mbc == 1) Errors::fatal("giving up: either make it by hand, or run again with -creating set");
		else Errors::fatal("giving up: either make them by hand, or run again with -creating set");
	}	

@ =
void InwebWeave::run_on(inweb_weave_settings *iws, ls_colony *C, ls_colony_member *CM, ls_web *W) {
	filename *weave_to_setting = NULL;
	pathname *weave_into_setting = NULL;
	if (silent_mode == FALSE) {
		PRINT("weaving "); WebStructure::print_web_identity(W);
		if (Str::len(iws->tag_setting) > 0) PRINT(" ('%S' paragraphs only)", iws->tag_setting);
	}
	if (CM) @<Fill in some blanks from the colony membership@>;
	text_stream *name = iws->pattern_name;
	if (Str::len(name) == 0) name = I"HTML";
	ls_pattern *pattern = Patterns::find(W->declaration, name);
	Patterns::impose(W, pattern);
	if (silent_mode == FALSE) {
		PRINT(" as %S", pattern->pattern_name);
		if (Str::len(pattern->based_on_name) > 0) PRINT(" (based on %S)", pattern->based_on_name);
		PRINT("\n");
	}
	if ((iws->subset.chosen_range_actually_chosen == FALSE) && (W->is_page == FALSE))
		Configuration::set_range(&(iws->subset), Patterns::get_default_range(W, pattern), TRUE);
	if (Str::len(iws->to_setting) > 0) {
		pathname *P = Pathnames::from_text(iws->to_setting);
		filename *F = Filenames::from_text(iws->to_setting);
		if (Directories::exists(P)) {
			weave_into_setting = P;
		} else if (TextFiles::exists(F)) {
			weave_to_setting = F;
		} else if (iws->creating_setting) {
			weave_into_setting = P;
			if (Pathnames::create_in_file_system_recursively(P) == FALSE)
				Errors::fatal_with_path("unable to create directory", P);
		} else {
			Errors::fatal_with_path("directory does not exist: either make it by hand, or run again with -creating set", P);
		}
	}
	if (weave_into_setting) {
		if (C) Colonies::set_redirect(C, weave_into_setting);
		else Swarm::redirect(W, NULL, weave_into_setting);
	}
	if (Patterns::html_based(W->declaration, pattern)) {
		linked_list *skeleton = Colonies::web_skeleton(W, C, CM, weave_into_setting);
		@<Ensure that the skeleton of directories needed does exist@>;
	}
	if (weave_into_setting) Swarm::cancel_redirection(W);

	Swarm::weave(C, CM, W, weave_to_setting, weave_into_setting, pattern,
		iws->subset.swarm_mode, iws->subset.range, iws->tag_setting, verbose_mode, silent_mode);

	if (weave_into_setting) {
		if (C) Colonies::set_redirect(C, NULL);
		Swarm::cancel_redirection(W);
	}
}

@ This is one of the few subcommands making use of the colony membership |op.CM|,
which even so is used only for putting together the panels of navigation links
in HTML to other colony members, or for re-routing the output.

@<Fill in some blanks from the colony membership@> =
	if (Str::len(iws->pattern_name) == 0)
		iws->pattern_name = CM->default_pattern_name;
	if (Str::len(iws->to_setting) > 0)
		weave_into_setting = Colonies::weave_path(CM);
