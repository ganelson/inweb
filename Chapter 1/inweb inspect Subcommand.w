[InwebInspect::] inweb inspect Subcommand.

The inweb inspect subcommand describes a web or other resource without changing it.

@ The command line interface and help text:

@e INSPECT_CLSUB
@e INSPECT_ONLY_CLSW
@e RESOURCES_CLSW
@e SCAN_CLSW
@e CLIKE_CLSG
@e FUNCTIONS_CLSW
@e STRUCTURES_CLSW

=
void InwebInspect::cli(void) {
	CommandLine::begin_subcommand(INSPECT_CLSUB, U"inspect");
	CommandLine::declare_heading(
		U"Usage: inweb inspect [WEB [RANGE] | FILE]\n\n"
		U"This shows the contents of a web, colony, or other Inweb resource without\n"
		U"changing it or taking any action.");

	CommandLine::declare_switch(RESOURCES_CLSW, U"resources", 1,
		U"show the Inweb resources (such as languages and notations) available");

	CommandLine::begin_group(CLIKE_CLSG,
		I"when inspecting webs only");
	CommandLine::declare_switch(INSPECT_ONLY_CLSW, U"only", 2,
		U"inspect only the section or chapter whose abbreviation is X");
	CommandLine::declare_switch(SCAN_CLSW, U"scan", 1,
		U"parse the web and display its syntax tree (can produce lots of output)");
	CommandLine::declare_switch(FUNCTIONS_CLSW, U"functions", 1,
		U"catalogue the functions in the web");
	CommandLine::declare_switch(STRUCTURES_CLSW, U"structures", 1,
		U"catalogue the structures in the web");
	CommandLine::end_group();

	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_inspect_settings {
	struct inweb_range_specifier subset;
	int functions_switch; /* |-functions|: print catalogue of functions within sections */
	int structures_switch; /* |-structures|: print catalogue of structures within sections */
	int scan_switch; /* |-scan|: simply show the syntactic scan of the source */
	int resources_switch; /* |-resources|: show WCL objects in scope */
} inweb_inspect_settings;

void InwebInspect::initialise(inweb_inspect_settings *iis) {
	iis->subset = Configuration::new_range_specifier();
	iis->functions_switch = FALSE;
	iis->structures_switch = FALSE;
	iis->scan_switch = FALSE;
	iis->resources_switch = FALSE;
}

int InwebInspect::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_inspect_settings *iis = &(ins->inspect_settings);
	switch (id) {
		case INSPECT_ONLY_CLSW: Configuration::set_range(&(iis->subset), arg, FALSE); return TRUE;
		case FUNCTIONS_CLSW: iis->functions_switch = val; return TRUE;
		case STRUCTURES_CLSW: iis->structures_switch = val; return TRUE;
		case SCAN_CLSW: iis->scan_switch = val; return TRUE;
		case RESOURCES_CLSW: iis->resources_switch = val; return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebInspect::run(inweb_instructions *ins) {
	inweb_inspect_settings *iis = &(ins->inspect_settings);
	int type = WEB_OPERAND_ALLOWED;
	if (iis->scan_switch) type = WEB_OPERAND_COMPULSORY;
	if (iis->functions_switch) type = WEB_OPERAND_COMPULSORY;
	if (iis->structures_switch) type = WEB_OPERAND_COMPULSORY;
	inweb_operand op = Configuration::operand(ins, type, FALSE, FALSE);
	if (iis->resources_switch) {
		if (op.D) {
			WCL::write_briefly(STDOUT, op.D);
			PRINT("-- with the following Inweb resources available for use:\n");
		} else {
			PRINT("The following Inweb resources are available for any web or colony to use:\n");
		}
		WCL::write_sorted_list_of_declaration_resources(STDOUT, op.D, -1);
	} else if (op.W) {
		WebStructure::print_statistics(op.W);
		if (iis->scan_switch)
			WebStructure::write_web(STDOUT, op.W, iis->subset.range);
		else if (iis->functions_switch)
			CodeAnalysis::catalogue_the_sections(op.W, iis->subset.range, FUNCTIONS_SECTIONCAT);
		else if (iis->structures_switch)
			CodeAnalysis::catalogue_the_sections(op.W, iis->subset.range, STRUCTURES_SECTIONCAT);
		else
			CodeAnalysis::catalogue_the_sections(op.W, iis->subset.range, BASIC_SECTIONCAT);
	} else if (op.D) {
		WCL::write(STDOUT, op.D);
	} else if (op.F) PRINT("Unable to identify file '%f' as Inweb resources\n", op.F);
	else if (op.P) PRINT("Unable to identify directory '%p' as Inweb resources\n", op.P);
}
