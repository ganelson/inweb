[InwebMake::] inweb make- Subcommands.

The inweb make-makefile, make-gitignore and make-readme subcommands are for
setting up a web. They share a common implementation.

@ The command line interface and help text:

@e MAKE_README_CLSUB
@e SCRIPT_CLSW
@e MAKE_TO_CLSW

@e MAKE_GITIGNORE_CLSUB

@e MAKE_MAKEFILE_CLSUB
@e PLATFORM_CLSW

=
void InwebMake::cli(void) {
	CommandLine::begin_subcommand(MAKE_README_CLSUB, U"make-readme");
	CommandLine::declare_heading(
		U"Usage: inweb make-readme [WEB] [-script FILE | -to FILE]*\n\n"
		U"This is a convenience for setting up a git repository at GitHub which\n"
		U"might, for example, host the woven source code as a web page. GitHub likes\n"
		U"repositories to contain a file called 'README.md' in Markdown format,\n"
		U"and this command can be used to create it with details conveniently\n"
		U"updated after each build.\n\n"
		U"A single file is written. If '-to FILE' is given, that's where. If not, it will\n"
		U"be 'README.md' in the directory of the given WEB; or, if no WEB is named, in the\n"
		U"current working directory.\n\n"
		U"There has to be a script to be followed. If '-script FILE' is specified, this\n" 
		U"will be it. Otherwise, for WEB or DIRECTORY, Inweb takes the directory name -\n"
		U"say, 'inexample' - and looks for 'inexample.rmscript' inside the directory,\n"
		U"or failing that, for 'scripts/inexample.rmscript' inside the directory. One\n"
		U"of these must exist, or the command will halt with an error.");
	CommandLine::declare_switch(MAKE_TO_CLSW, U"to", 2,
		U"write the output to the file X");
	CommandLine::declare_switch(SCRIPT_CLSW, U"script", 2,
		U"translate README.md file from prototype X");
	CommandLine::end_subcommand();
	
	CommandLine::begin_subcommand(MAKE_GITIGNORE_CLSUB, U"make-gitignore");
	CommandLine::declare_heading(
		U"Usage: inweb make-gitignore [WEB] [-script FILE | -to FILE]*\n\n"
		U"This is a convenience for placing a web under source control with git.\n"
		U"All git repositories can contain .gitignore files (often hidden on\n"
		U"systems like MacOS because of the initial '.' in the name) which list\n"
		U"files in the general vicinity which are ephemeral and should not be\n"
		U"tracked by source control. This command can create a suitable .gitignore\n"
		U"file.\n\n"
		U"A single file is written. If '-to FILE' is given, that's where. If not, it will\n"
		U"be '.gitignore' in the directory of the given WEB; or, if no WEB is named, in the\n"
		U"current working directory.\n\n"
		U"There has to be a script to be followed. If '-script FILE' is specified, this\n" 
		U"will be it. Otherwise, for WEB or DIRECTORY, Inweb takes the directory name -\n"
		U"say, 'inexample' - and looks for 'inexample.giscript' inside the directory,\n"
		U"or failing that, for 'scripts/inexample.giscript' inside the directory. If none\n"
		U"of these exist, a basic script inside Inweb called 'default.giscript' is used.");
	CommandLine::declare_switch(MAKE_TO_CLSW, U"to", 2,
		U"write the output to the file X");
	CommandLine::declare_switch(SCRIPT_CLSW, U"script", 2,
		U"translate .gitignore file from prototype X");
	CommandLine::end_subcommand();

	CommandLine::begin_subcommand(MAKE_MAKEFILE_CLSUB, U"make-makefile");
	CommandLine::declare_heading(
		U"Usage: inweb make-makefile [WEB] [-script FILE | -to FILE | -platform PLATFORM]*\n\n"
		U"If the standard Unix 'make' utility is being used as a build tool,\n"
		U"it can be cumbersome to create the necessary makefile for a complicated\n"
		U"web, because of the dependencies on section files inside multiple webs.\n"
		U"This command can help with that, and also produce cross-platform makefiles,\n"
		U"with suitable differences for MacOS, Windows and so on.\n\n"
		U"A single file is written. If '-to FILE' is given, that's where. If not, it will\n"
		U"be 'makefile' in the directory of the given WEB; or, if no WEB is named, in the\n"
		U"current working directory.\n\n"
		U"There has to be a script to be followed. If '-script FILE' is specified, this\n" 
		U"will be it. Otherwise, for WEB or DIRECTORY, Inweb takes the directory name -\n"
		U"say, 'inexample' - and looks for 'inexample.mkscript' inside the directory,\n"
		U"or failing that, for 'scripts/inexample.mkscript' inside the directory. If none\n"
		U"of these exist, a basic script inside Inweb called 'default.mkscript' is used.");
	CommandLine::declare_switch(MAKE_TO_CLSW, U"to", 2,
		U"write the output to the file X");
	CommandLine::declare_switch(SCRIPT_CLSW, U"script", 2,
		U"translate makefile from prototype X");
	CommandLine::declare_switch(PLATFORM_CLSW, U"platform", 2,
		U"use platform X (e.g. 'windows') when platform-specific details are needed");
	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_make_settings {
	struct filename *make_to_setting; /* |-to X|: for the various make commands */
	struct filename *prototype_setting; /* |-script X|: the pathname X, if supplied */
	struct text_stream *platform_setting; /* |-platform X|: sets prevailing platform to X */
} inweb_make_settings;

void InwebMake::initialise(inweb_make_settings *ims) {
	ims->make_to_setting = NULL;
	ims->prototype_setting = NULL;
	ims->platform_setting = NULL;
}

int InwebMake::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_make_settings *ims = &(ins->make_settings);
	switch (id) {
		case MAKE_TO_CLSW: ims->make_to_setting = Filenames::from_text(arg); return TRUE;
		case SCRIPT_CLSW: ims->prototype_setting = Filenames::from_text(arg); return TRUE;
		case PLATFORM_CLSW: ims->platform_setting = Str::duplicate(arg); return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebMake::run(inweb_instructions *ins) {
	inweb_make_settings *ims = &(ins->make_settings);
	switch (ins->subcommand) {
		case MAKE_README_CLSUB: @<Inweb make-readme command@>; break;
		case MAKE_GITIGNORE_CLSUB: @<Inweb make-gitignore command@>; break;
		case MAKE_MAKEFILE_CLSUB: @<Inweb make-makefile command@>; break;
	}
}

@<Inweb make-readme command@> =
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_ALLOWED, FALSE, FALSE);
	text_stream *default_write_leafname = I"README.md";
	text_stream *default_script_extension = I".rmscript";
	text_stream *default_script_leafname = NULL;
	filename *to_write = ims->make_to_setting;
	filename *script = ims->prototype_setting;
	@<Work out the script and destination@>;
	Readme::write(script, to_write);

@<Inweb make-gitignore command@> =
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_ALLOWED, FALSE, FALSE);
	text_stream *default_write_leafname = I".gitignore";
	text_stream *default_script_extension = I".giscript";
	text_stream *default_script_leafname = I"default.giscript";
	filename *to_write = ims->make_to_setting;
	filename *script = ims->prototype_setting;
	@<Work out the script and destination@>;
	Git::write_gitignore(script, to_write);

@<Inweb make-makefile command@> =
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_ALLOWED, FALSE, FALSE);
	text_stream *default_write_leafname = I"makefile";
	text_stream *default_script_extension = I".mkscript";
	text_stream *default_script_leafname = I"default.mkscript";
	filename *to_write = ims->make_to_setting;
	filename *script = ims->prototype_setting;
	@<Work out the script and destination@>;
	Makefiles::write(op.W, script, to_write, ims->platform_setting);

@ These make-something subcommands share a common set of conventions about how
to find the script, and so on:

@<Work out the script and destination@> =
	pathname *P = op.P;
	TEMPORARY_TEXT(leafname)
	if (op.W) {
		P = op.W->path_to_web;
		if (P == NULL) Errors::fatal("this command cannot be applied to a single-file web");
	}
	if (to_write == NULL) to_write = Filenames::in(P, default_write_leafname);
	WRITE_TO(leafname, "%S", Pathnames::directory_name(P));
	if ((Str::len(leafname) == 0) ||
		(Str::eq(leafname, I".")) || (Str::eq(leafname, I".."))) {
		Str::clear(leafname); WRITE_TO(leafname, "web");
	}
	WRITE_TO(leafname, "%S", default_script_extension);
	if (script == NULL) {
		filename *F = Filenames::in(P, leafname);
		if (TextFiles::exists(F) == FALSE)
			F = Filenames::in(Pathnames::down(P, I"scripts"), leafname);
		if (TextFiles::exists(F) == FALSE) {
			if (Str::len(default_script_leafname) == 0)
				Errors::fatal("no script is (obviously) present: use '-script X' to show me it");
			F = Filenames::in(Pathnames::path_to_inweb_materials(), default_script_leafname);
		}
		script = F;
	}
	PRINT("%f -> %f\n", script, to_write);
