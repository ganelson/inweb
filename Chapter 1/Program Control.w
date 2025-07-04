[Main::] Program Control.

The top level, which decides what is to be done and then carries
this plan out.

@ Inweb has a single fundamental mode of operation: on any given run, it
is either tangling, weaving or analysing. These processes use the same input
and parsing code, but then do very different things to produce their output,
so the fork in the road is not met until halfway through Inweb's execution.

@e NO_MODE from 0 /* a special mode for doing nothing except printing command-line syntax */
@e ANALYSE_MODE   /* for -scan, -catalogue, -functions and so on */
@e TANGLE_MODE    /* for any form of -tangle */
@e WEAVE_MODE     /* for any form of -weave */
@e TRANSLATE_MODE /* a special mode for translating a multi-web makefile */

=
int fundamental_mode = NO_MODE;

@ This operation will be applied to a single web, and will apply to the whole
of that web unless we specify otherwise. Subsets of the web are represented by
short pieces of text called "ranges". This can be a section range like
|2/pine|, a chapter number like |12|, an appendix letter |A| or the
preliminaries block |P|, the special chapter |S| for the "Sections" chapter
of an unchaptered web, or the special value |0| to mean the entire web (which
is the default).

@ In order to run, Inweb needs to know where it is installed -- this
enables it to find its configuration file, the macros file, and so on.
Unless told otherwise on the command line, we'll assume Inweb is present
in the current working directory. The "materials" will then be in a further
subfolder called |Materials|.

= (early code)
pathname *path_to_inweb = NULL; /* where we are installed */

@ We count the errors in order to be able to exit with a suitable exit code.

= (early code)
int no_inweb_errors = 0;
int verbose_mode = FALSE;

@h Main routine.

=
int main(int argc, char **argv) {
	@<Initialise inweb@>;
	inweb_instructions args = Configuration::read(argc, argv);
	verbose_mode = args.verbose_switch;
	fundamental_mode = args.inweb_mode;
	path_to_inweb = Pathnames::installation_path("INWEB_PATH", I"inweb");
	if (verbose_mode) {
		PRINT("Installation path is %p\n", path_to_inweb);
		Locales::write_locales(STDOUT);
	}
	Pathnames::set_path_to_LP_resources(path_to_inweb);

	Main::follow_instructions(&args);

	@<Shut inweb down@>;
}

@<Initialise inweb@> =
	Foundation::start(argc, argv);
	WeavingFormats::create_weave_formats();

@<Shut inweb down@> =
	Foundation::end();
	return (no_inweb_errors == 0)?0:1;

@h Following instructions.
This is the whole program in a nutshell, and it's a pretty old-school
program: some input, some thinking, a choice of three forms of output.

=
void Main::follow_instructions(inweb_instructions *ins) {
	ls_web *W = NULL;
	if ((ins->chosen_web) || (ins->chosen_file)) {
		W = Main::load_web(ins->chosen_web, ins->chosen_file,
			WebModules::make_search_path(ins->import_setting), ins->weave_into_setting,
			ins->inweb_mode);
	}
	if (no_inweb_errors == 0) {
		if (ins->inweb_mode == TRANSLATE_MODE) @<Translate a makefile@>
		else if (ins->show_languages_switch) @<List available programming languages@>
		else if (ins->show_syntaxes_switch) @<List available LP syntaxes@>
		else if ((ins->test_language_setting) || (ins->test_language_on_setting)) @<Test a language@>
		else if (ins->inweb_mode != NO_MODE) @<Analyse, tangle or weave an existing web@>;
	}
}

@ This is a one-off featurette:

@<Translate a makefile@> =
	if ((ins->makefile_setting) && (ins->prototype_setting == NULL))
		ins->prototype_setting = Filenames::from_text(I"script.mkscript");
	if ((ins->gitignore_setting) && (ins->prototype_setting == NULL))
		ins->prototype_setting = Filenames::from_text(I"script.giscript");
	if ((ins->writeme_setting) && (ins->prototype_setting == NULL))
		ins->prototype_setting = Filenames::from_text(I"script.rmscript");
	if (ins->makefile_setting)
		Makefiles::write(W, ins->prototype_setting, ins->makefile_setting,
			WebModules::make_search_path(ins->import_setting), ins->platform_setting);
	else if (ins->gitignore_setting)
		Git::write_gitignore(W, ins->prototype_setting, ins->gitignore_setting);
	else if (ins->advance_setting)
		BuildFiles::advance(ins->advance_setting);
	else if (ins->writeme_setting)
		Readme::write(ins->prototype_setting, ins->writeme_setting);

@ As is this:

@<List available programming languages@> =
	Languages::read_definitions(NULL);
	Languages::show(STDOUT);

@<List available LP syntaxes@> =
	WebSyntax::write_known_syntaxes(STDOUT);

@ And this:

@<Test a language@> =
	if ((ins->test_language_setting) && (ins->test_language_on_setting)) {
		TEMPORARY_TEXT(matter)
		TEMPORARY_TEXT(coloured)
		Painter::colour_file(ins->test_language_setting, ins->test_language_on_setting,
			matter, coloured);
		PRINT("Test of colouring for language %S:\n%S\n%S\n",
			ins->test_language_setting->language_name, matter, coloured);
		DISCARD_TEXT(matter)
		DISCARD_TEXT(coloured)
	} else {
		Errors::fatal("-test-language and -test-language-on must both be given");
	}

@ But otherwise we do something with the given web:

@<Analyse, tangle or weave an existing web@> =
	if (ins->inweb_mode != ANALYSE_MODE) WebStructure::print_statistics(W);
	if (ins->inweb_mode == ANALYSE_MODE) @<Analyse the web@>;
	if (ins->inweb_mode == TANGLE_MODE) @<Tangle the web@>;
	if (ins->inweb_mode == WEAVE_MODE) @<Weave the web@>;

@ "Analysis" invokes any combination of the following diagnostic tools:

@<Analyse the web@> =
	if (ins->swarm_mode != SWARM_OFF_SWM)
		Errors::fatal("only specific parts of the web can be analysed");
	if (ins->catalogue_switch)
		CodeAnalysis::catalogue_the_sections(W, ins->chosen_range, BASIC_SECTIONCAT);
	if (ins->functions_switch)
		CodeAnalysis::catalogue_the_sections(W, ins->chosen_range, FUNCTIONS_SECTIONCAT);
	if (ins->structures_switch)
		CodeAnalysis::catalogue_the_sections(W, ins->chosen_range, STRUCTURES_SECTIONCAT);
	if (ins->makefile_setting)
		CodeAnalysis::write_makefile(W, ins->makefile_setting,
			WebModules::make_search_path(ins->import_setting), ins->platform_setting,
			Pathnames::path_to_inweb_materials());
	if (ins->gitignore_setting)
		CodeAnalysis::write_gitignore(W, ins->gitignore_setting,
			Pathnames::path_to_inweb_materials());
	if (ins->advance_switch)
		BuildFiles::advance_for_web(W);
	if (ins->scan_switch)
		WebStructure::write_web(STDOUT, W, ins->chosen_range);

@ We can tangle to any one of what might be several targets, numbered upwards
from 0. Target 0 always exists, and is the main program forming the web. For
many webs, this will in fact be the only target, but Inweb also allows
marked sections of a web to be independent targets -- the idea here is to
allow an Appendix in the web to contain a configuration file, or auxiliary
program, needed for the main program to work; this might be written in a
quite different language from the rest of the web, and tangles to a different
output, but needs to be part of the web since it's essential to an understanding
of the whole system.

In this section we determine |tn|, the target number wanted, and |tangle_to|,
the filename of the tangled code to write. This may have been set at the command
line , but otherwise we impose a sensible choice based on the target.

@<Tangle the web@> =
	TEMPORARY_TEXT(tangle_leaf)
	tangle_target *tn = NULL;
	if (Str::eq_wide_string(ins->chosen_range, U"0")) {
		@<Work out main tangle destination@>;
	} else if (WebRanges::to_section(W, ins->chosen_range)) {
		@<Work out an independent tangle destination, from one section of the web@>;
	}
	if (Str::len(tangle_leaf) == 0) { Errors::fatal("no tangle destination known"); }

	filename *tangle_to = ins->tangle_setting;
	if (tangle_to == NULL) {
		pathname *P = WebStructure::tangled_folder(W);
		if (W->single_file) P = Filenames::up(W->single_file);
		tangle_to = Filenames::in(P, tangle_leaf);
	}
	if (tn == NULL) tn = TangleTargets::primary_target(W);
	programming_language *pl = tn->tangle_language;
	PRINT("  tangling <%/f> (written in %S)\n", tangle_to, pl->language_name);
	text_stream TO_struct;
	text_stream *OUT = &TO_struct;
	if (STREAM_OPEN_TO_FILE(OUT, tangle_to, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", tangle_to);
	Tangler::tangle_web(OUT, W, Filenames::up(tangle_to), TangleTargets::primary_target(W));
	STREAM_CLOSE(OUT);
	if (ins->ctags_switch) Ctags::write(W, ins->ctags_setting);
	DISCARD_TEXT(tangle_leaf)

@ Here the target number is 0, and the tangle is of the main part of the web,
which for many small webs will be the entire thing.

@<Work out main tangle destination@> =
	tn = NULL;
	if (Bibliographic::data_exists(W, I"Short Title"))
		Str::copy(tangle_leaf, Bibliographic::get_datum(W, I"Short Title"));
	else
		Str::copy(tangle_leaf, Bibliographic::get_datum(W, I"Title"));
	Str::concatenate(tangle_leaf, W->web_language->file_extension);

@ If someone tangles, say, |2/eg| then the default filename is "Example Section".

@<Work out an independent tangle destination, from one section of the web@> =
	ls_section *S = WebRanges::to_section(W, ins->chosen_range);
	tn = S->sect_target;
	if (tn == NULL) Errors::fatal("section cannot be independently tangled");
	Str::copy(tangle_leaf, Filenames::get_leafname(S->source_file_for_section));

@ Weaving is not actually easier, it's just more thoroughly delegated:

@<Weave the web@> =
	weave_pattern *pattern = Patterns::find(W, ins->weave_pattern);
	if ((ins->chosen_range_actually_chosen == FALSE) && (W->single_file == NULL))
		Configuration::set_range(ins, pattern->default_range);

	int r = WeavingFormats::begin_weaving(W, pattern);
	if (r != SWARM_OFF_SWM) ins->swarm_mode = r;
	@<Assign section numbers for printing purposes@>;
	if (ins->swarm_mode == SWARM_OFF_SWM) {
		Swarm::weave_subset(W, ins->chosen_range, FALSE, ins->tag_setting, pattern,
			ins->weave_to_setting, ins->weave_into_setting,
			ins->breadcrumb_setting, ins->navigation_setting, verbose_mode);
	} else {
		Swarm::weave(W, ins->chosen_range, ins->swarm_mode, ins->tag_setting, pattern,
			ins->weave_to_setting, ins->weave_into_setting,
			ins->breadcrumb_setting, ins->navigation_setting, verbose_mode);
	}
	WeavingFormats::end_weaving(W, pattern);

@<Assign section numbers for printing purposes@> =
	ls_section *S; int k = 1;
	LOOP_OVER(S, ls_section)
		if (WebRanges::is_within(WebRanges::of(S), ins->chosen_range))
			WeavingDetails::set_section_number(S, k++);

@h Web reading.

=
ls_web *Main::load_web(pathname *P, filename *alt_F, module_search *I,
	pathname *redirection, int inweb_mode) {
	ls_web *W = WebStructure::get(P, alt_F, NULL, I, verbose_mode, TRUE, NULL);
	WebStructure::read_web_source(W, verbose_mode, (inweb_mode == WEAVE_MODE)?TRUE:FALSE);
	WebErrors::issue_all_recorded(W);
	@<Write the Inweb Version bibliographic datum@>;
	CodeAnalysis::initialise_analysis_details(W);
	WeavingDetails::initialise(W, redirection);
	CodeAnalysis::analyse_web(W, (inweb_mode == TANGLE_MODE)?TRUE:FALSE, (inweb_mode == WEAVE_MODE)?TRUE:FALSE);
	return W;
}

@<Write the Inweb Version bibliographic datum@> =
	TEMPORARY_TEXT(IB)
	WRITE_TO(IB, "[[Version Number]]");
	web_bibliographic_datum *bd = Bibliographic::set_datum(W, I"Inweb Version", IB);
	bd->declaration_permitted = FALSE;
	DISCARD_TEXT(IB)
