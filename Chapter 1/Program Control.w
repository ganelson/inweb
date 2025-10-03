[Main::] Program Control.

The top level, which is little more than a demarcation between subcommands.

@ Every program using //foundation// must define this:

@d PROGRAM_NAME "inweb"

@ Almost all of the literate programming functionality which powers Inweb is
now library-ized into //foundation//, but it is very slightly modified when
used inside Inweb itself, and those modifications come into effect when the
following is defined:

@d THIS_IS_INWEB

@ As we will see, reading the command line is not an entirely simple business,
but otherwise we do as little as possible here, and delegate everything to
the subcommands.

=
int main(int argc, char **argv) {
	@<Initialise inweb@>;
	inweb_instructions args = Configuration::read(argc, argv);
	@<Make some global settings@>;
	if (no_inweb_errors == 0) {
		switch (args.subcommand) {
			case ADVANCE_BUILD_CLSUB:  InwebAdvanceBuild::run(&args); break;
			case INSPECT_CLSUB:        InwebInspect::run(&args); break;
			case MAP_CLSUB:            InwebMap::run(&args); break;
			case MAKE_README_CLSUB:    InwebMake::run(&args); break;
			case MAKE_GITIGNORE_CLSUB: InwebMake::run(&args); break;
			case MAKE_MAKEFILE_CLSUB:  InwebMake::run(&args); break;
			case TEST_LANGUAGE_CLSUB:  InwebTestLanguage::run(&args); break;
			case WEAVE_CLSUB:          InwebWeave::run(&args); break;
			case TANGLING_CLSUB:       InwebTangle::run(&args); break;
		}
	}
	@<Shut inweb down@>;
}

@<Initialise inweb@> =
	Foundation::start(argc, argv);
	WeavingFormats::create_weave_formats();

@ We keep global settings to a minimum. Note that the installation path can
only be set after the command-line switches are read, since they can change it.

= (early code)
pathname *path_to_inweb = NULL; /* where we are installed */
int no_inweb_errors = 0;
int verbose_mode = FALSE;
int old_inweb_compatibility_mode = TRUE;

@<Make some global settings@> =
	verbose_mode = args.verbose_switch;
	old_inweb_compatibility_mode = TRUE;
	path_to_inweb = Pathnames::installation_path("INWEB_PATH", I"inweb");
	if (verbose_mode) {
		PRINT("Installation path is %p\n", path_to_inweb);
		Locales::write_locales(STDOUT);
	}
	pathname *M = Pathnames::path_to_inweb_materials();
	Pathnames::set_path_to_LP_resources(M);
	if (args.import_setting)
		WebModules::set_default_search_path(
			WebModules::make_search_path(args.import_setting));

@<Shut inweb down@> =
	Foundation::end();
	return (no_inweb_errors == 0)?0:1;
