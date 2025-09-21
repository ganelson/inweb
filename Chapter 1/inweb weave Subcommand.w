[InwebWeave::] inweb weave Subcommand.

The inweb weave subcommand weaves a web.

@ The command line interface and help text:

@e WEAVE_CLSUB
@e WEAVE_TO_CLSW
@e WEAVE_AS_CLSW

@e WEAVING_SELECTION_CLSG
@e ONLY_CLSW
@e WEAVE_TAG_CLSW

@e WEAVING_HTML_CLSG
@e BREADCRUMB_CLSW
@e NAVIGATION_CLSW

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
		
	CommandLine::begin_group(WEAVING_SELECTION_CLSG,
		I"for weaving only part of a web, not the whole thing");	
	CommandLine::declare_switch(ONLY_CLSW, U"only", 2,
		U"weave only the section or chapter whose abbreviation is X");
	CommandLine::declare_switch(WEAVE_TAG_CLSW, U"only-tagged-as", 2,
		U"weave only those paragraphs in the web tagged as X");

	CommandLine::begin_group(WEAVING_HTML_CLSG,
		I"relevant only for HTML-based patterns with navigation links");
	CommandLine::declare_switch(BREADCRUMB_CLSW, U"breadcrumb", 2,
		U"use the text X as a breadcrumb in overhead navigation");
	CommandLine::declare_switch(NAVIGATION_CLSW, U"navigation", 2,
		U"use the file X as a column of navigation links");
	CommandLine::end_group();
	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_weave_settings {
	struct inweb_range_specifier subset;
	struct filename *weave_to_setting;
	struct pathname *weave_into_setting;
	struct text_stream *tag_setting;
	struct text_stream *weave_pattern;
	struct linked_list *breadcrumb_setting;
	struct filename *navigation_setting;
} inweb_weave_settings;

void InwebWeave::initialise(inweb_weave_settings *iws) {
	iws->subset = Configuration::new_range_specifier();
	iws->weave_to_setting = NULL;
	iws->weave_into_setting = NULL;
	iws->tag_setting = Str::new();
	iws->weave_pattern = I"";
	iws->breadcrumb_setting = NEW_LINKED_LIST(breadcrumb_request);
	iws->navigation_setting = NULL;
}

int InwebWeave::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_weave_settings *iws = &(ins->weave_settings);
	switch (id) {
		case WEAVE_TO_CLSW:
			iws->weave_to_setting = NULL;
			iws->weave_into_setting = Pathnames::from_text(arg);
			if (Directories::exists(iws->weave_into_setting)) return TRUE;
			iws->weave_into_setting = NULL;
			iws->weave_to_setting = Filenames::from_text(arg);
			return TRUE;
		case WEAVE_AS_CLSW: iws->weave_pattern = Str::duplicate(arg); return TRUE;
		case ONLY_CLSW: Configuration::set_range(&(iws->subset), arg, TRUE); return TRUE;
		case WEAVE_TAG_CLSW: iws->tag_setting = Str::duplicate(arg); return TRUE;
		case BREADCRUMB_CLSW:
			ADD_TO_LINKED_LIST(Colonies::request_breadcrumb(arg),
				breadcrumb_request, iws->breadcrumb_setting);
			return TRUE;
		case NAVIGATION_CLSW: iws->navigation_setting = Filenames::from_text(arg); return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebWeave::run(inweb_instructions *ins) {
	inweb_weave_settings *iws = &(ins->weave_settings);
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_COMPULSORY, FALSE, TRUE);
	ls_web *W = op.W;
	WebStructure::print_statistics(W);
	if (op.CM) @<Fill in some blanks from the colony membership@>;
	text_stream *name = iws->weave_pattern;
	if (Str::len(name) == 0) name = I"HTML";
	weave_pattern *pattern = Patterns::find(W, name);
	if ((iws->subset.chosen_range_actually_chosen == FALSE) && (W->single_file == NULL))
		Configuration::set_range(&(iws->subset), pattern->default_range, TRUE);
	Swarm::weave(op.C, W, iws->weave_to_setting, iws->weave_into_setting, pattern,
		iws->subset.swarm_mode, iws->subset.range, iws->tag_setting,
		iws->breadcrumb_setting, iws->navigation_setting, verbose_mode);
}

@ This is one of the few subcommands making using of the colony membership |op.CM|,
which even so is used only for putting together the panels of navigation links
in HTML to other colony members, or for re-routing the output.

@<Fill in some blanks from the colony membership@> =
	if (Str::len(iws->weave_pattern) == 0)
		iws->weave_pattern = op.CM->default_weave_pattern;
	if (LinkedLists::len(iws->breadcrumb_setting) == 0)
		iws->breadcrumb_setting = op.CM->breadcrumb_tail;
	if (iws->navigation_setting == NULL)
		iws->navigation_setting = op.CM->navigation;
	if (iws->weave_into_setting == NULL)
		iws->weave_into_setting = op.CM->weave_path;
