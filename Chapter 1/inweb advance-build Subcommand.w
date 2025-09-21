[InwebAdvanceBuild::] inweb advance-build Subcommand.

The inweb advance-build subcommand manages the daily build code for a program,
following traditional Inform conventions.

@ The command line interface and help text:

@e ADVANCE_BUILD_CLSUB

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
	CommandLine::end_subcommand();
}

@ In operation:

=
void InwebAdvanceBuild::run(inweb_instructions *ins) {
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_ALLOWED, FALSE, FALSE);
	if (op.W) BuildFiles::advance_for_web(op.W);
	else if ((op.F) && (TextFiles::exists(op.F)))
		BuildFiles::advance(op.F);
	else if (op.P) {
		filename *F = Filenames::in(op.P, I"build.txt");
		if (TextFiles::exists(F)) BuildFiles::advance(F);
		else Errors::fatal_with_file("build file not found", F);
	} else Errors::fatal("must specify a web, a path or an (existing) file");
}
