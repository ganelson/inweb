[InwebAdvanceBuild::] inweb advance-build Subcommand.

The inweb advance-build subcommand manages the daily build code for a program,
following traditional Inform conventions.

@ The command line interface and help text:

@e ADVANCE_BUILD_CLSUB

@e CREATING_BUILD_CLSW

=
void InwebAdvanceBuild::cli(void) {
	CommandLine::begin_subcommand(ADVANCE_BUILD_CLSUB, U"advance-build");
	CommandLine::declare_heading(
		U"Usage: inweb advance-build [FILE | DIRECTORY | WEB]\n\n"
		U"Some webs (or sometimes colony directories) contain small text files,\n"
		U"normally named 'build.txt', which record a build code for the program\n"
		U"and an associated date. By convention the code has the format NLNN,\n"
		U"where N is a digit and L an English capital letter other that 'I' or 'O'.\n\n"
		U"This command looks at the build code file, if it exists. If today's date\n"
		U"is later the date in the file, the file is rewritten to increment the build\n"
		U"and reset the build date to today. All being well, the command should reply\n"
		U"with a message like one of these:\n\n"
		U"    Build code advanced from 6X87 (set on 8 September 2025) to 6X88\n"
		U"    Build code remains 6X88 since it is still 16 September 2025");

	CommandLine::declare_boolean_switch(CREATING_BUILD_CLSW, U"creating", 1,
		U"start a new build file if it does not already exist", FALSE);

	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_advance_build_settings {
	int creating_setting;
} inweb_advance_build_settings;

void InwebAdvanceBuild::initialise(inweb_advance_build_settings *iabs) {
	iabs->creating_setting = FALSE;
}

int InwebAdvanceBuild::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_advance_build_settings *iabs = &(ins->advance_build_settings);
	switch (id) {
		case CREATING_BUILD_CLSW: iabs->creating_setting = val; return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebAdvanceBuild::run(inweb_instructions *ins) {
	inweb_advance_build_settings *iabs = &(ins->advance_build_settings);
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_ALLOWED, FALSE, FALSE);
	if (op.W) {
		BuildFiles::advance_for_web(op.W, iabs->creating_setting);
	} else if (op.F) {
		if (TextFiles::exists(op.F)) BuildFiles::advance(op.F);
		else if (iabs->creating_setting) BuildFiles::new(op.F);
		else Errors::fatal_with_file("build file not found", op.F);
	} else {
		filename *F = Filenames::in(op.P, I"build.txt");
		if (TextFiles::exists(F)) BuildFiles::advance(F);
		else if (iabs->creating_setting) BuildFiles::new(F);
		else Errors::fatal_with_file("build file not found", F);
	}
}
