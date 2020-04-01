[Main::] Program Control.

The top level, which decides what is to be done and then carries
this plan out.

@ Inweb syntax has gradually shifted over the years, but there are two main
versions: the second was cleaned up and simplified from the first in 2019.

=
int default_inweb_syntax = V2_SYNTAX;

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

When weaving in "swarm mode", however, the user chooses a multiplicity of
operations rather than just one. Now it's no longer a matter of weaving a
particular section or chapter: we can weave all of the sections or chapters,
one after another.

@e SWARM_OFF_SWM from 0
@e SWARM_INDEX_SWM    /* make index(es) as if swarming, but don't actually swarm */
@e SWARM_CHAPTERS_SWM /* swarm the chapters */
@e SWARM_SECTIONS_SWM /* swarm the individual sections */

@ In order to run, Inweb needs to know where it is installed -- this
enables it to find its configuration file, the macros file, and so on.
Unless told otherwise on the command line, we'll assume Inweb is present
in the current working directory. The "materials" will then be in a further
subfolder called |Materials|.

=
pathname *path_to_inweb = NULL; /* where we are installed */
pathname *path_to_inweb_materials = NULL; /* the materials pathname */
pathname *path_to_inweb_patterns = NULL; /* where built-in patterns are stored */

@ We count the errors in order to be able to exit with a suitable exit code.

=
int no_inweb_errors = 0;

@h Main routine.

=
int main(int argc, char **argv) {
	@<Initialise inweb@>;
	inweb_instructions args = Configuration::read(argc, argv);
	fundamental_mode = args.inweb_mode;
	path_to_inweb = Pathnames::installation_path("INWEB_PATH", I"inweb");
	if (args.verbose_switch) PRINT("Installation path is %p\n", path_to_inweb);
	path_to_inweb_patterns = Pathnames::subfolder(path_to_inweb, I"Patterns");
	path_to_inweb_materials = Pathnames::subfolder(path_to_inweb, I"Materials");

	Main::follow_instructions(&args);

	@<Shut inweb down@>;
}

@<Initialise inweb@> =
	Foundation::start();
	Languages::create_programming_languages();
	Formats::create_weave_formats();

@<Shut inweb down@> =
	Foundation::end();
	return (no_inweb_errors == 0)?0:1;

@h Following instructions.
This is the whole program in a nutshell, and it's a pretty old-school
program: some input, some thinking, a choice of three forms of output.

=
void Main::follow_instructions(inweb_instructions *ins) {
	web *W = NULL;
	if ((ins->chosen_web) || (ins->chosen_file))
		W = Reader::load_web(ins->chosen_web, ins->chosen_file,
			WebModules::make_search_path(ins->import_setting), ins->verbose_switch,
			ins->inweb_mode, ins->weave_into_setting, TRUE);
	if (no_inweb_errors == 0) {
		if (ins->inweb_mode == TRANSLATE_MODE) @<Translate a makefile@>
		else if (ins->inweb_mode != NO_MODE) @<Analyse, tangle or weave an existing web@>;
	}
}

@ This is a one-off featurette:

@<Translate a makefile@> =
	if ((ins->makefile_setting) && (ins->prototype_setting == NULL))
		ins->prototype_setting = Filenames::from_text(I"makescript.txt");
	if ((ins->gitignore_setting) && (ins->prototype_setting == NULL))
		ins->prototype_setting = Filenames::from_text(I"gitignorescript.txt");
	if ((ins->writeme_setting) && (ins->prototype_setting == NULL))
		ins->prototype_setting = Filenames::from_text(I"READMEscript.txt");
	if (ins->makefile_setting)
		Makefiles::write(W, ins->prototype_setting, ins->makefile_setting);
	else if (ins->gitignore_setting)
		Git::write_gitignore(W, ins->prototype_setting, ins->gitignore_setting);
	else if (ins->advance_setting)
		BuildFiles::advance(ins->advance_setting);
	else if (ins->writeme_setting)
		Readme::write(ins->prototype_setting, ins->writeme_setting);

@ But otherwise we do something with the given web:

@<Analyse, tangle or weave an existing web@> =
	WebStructure::print_web_statistics(W->md);
	if (ins->inweb_mode == ANALYSE_MODE) @<Analyse the web@>;
	if (ins->inweb_mode == TANGLE_MODE) @<Tangle the web@>;
	if (ins->inweb_mode == WEAVE_MODE) @<Weave the web@>;

@ "Analysis" invokes any combination of the following diagnostic tools:

@<Analyse the web@> =
	if (ins->swarm_mode != SWARM_OFF_SWM)
		Errors::fatal("only specific parts of the web can be analysed");
	if (ins->catalogue_switch)
		Analyser::catalogue_the_sections(W, ins->chosen_range, BASIC_SECTIONCAT);
	if (ins->functions_switch)
		Analyser::catalogue_the_sections(W, ins->chosen_range, FUNCTIONS_SECTIONCAT);
	if (ins->structures_switch)
		Analyser::catalogue_the_sections(W, ins->chosen_range, STRUCTURES_SECTIONCAT);
	if (ins->makefile_setting)
		Analyser::write_makefile(W, ins->makefile_setting);
	if (ins->gitignore_setting)
		Analyser::write_gitignore(W, ins->gitignore_setting);
	if (ins->advance_switch)
		BuildFiles::advance_for_web(W->md);
	if (ins->scan_switch)
		Analyser::scan_line_categories(W, ins->chosen_range);

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
	TEMPORARY_TEXT(tangle_leaf);
	tangle_target *tn = NULL;
	if (Str::eq_wide_string(ins->chosen_range, L"0")) {
		@<Work out main tangle destination@>;
	} else if (Reader::get_section_for_range(W, ins->chosen_range)) {
		@<Work out an independent tangle destination, from one section of the web@>;
	}
	if (Str::len(tangle_leaf) == 0) { Errors::fatal("no tangle destination known"); }

	filename *tangle_to = ins->tangle_setting;
	if (tangle_to == NULL) {
		pathname *P = Reader::tangled_folder(W);
		if (W->md->single_file) P = Filenames::get_path_to(W->md->single_file);
		tangle_to = Filenames::in_folder(P, tangle_leaf);
	}
	if (tn == NULL) tn = Tangler::primary_target(W);
	Tangler::go(W, tn, tangle_to);
	DISCARD_TEXT(tangle_leaf);

@ Here the target number is 0, and the tangle is of the main part of the web,
which for many small webs will be the entire thing.

@<Work out main tangle destination@> =
	tn = NULL;
	if (Bibliographic::data_exists(W->md, I"Short Title"))
		Str::copy(tangle_leaf, Bibliographic::get_datum(W->md, I"Short Title"));
	else
		Str::copy(tangle_leaf, Bibliographic::get_datum(W->md, I"Title"));
	Str::concatenate(tangle_leaf, W->main_language->file_extension);

@ If someone tangles, say, |2/eg| then the default filename is "Example Section".

@<Work out an independent tangle destination, from one section of the web@> =
	section *S = Reader::get_section_for_range(W, ins->chosen_range);
	tn = S->sect_target;
	if (tn == NULL) Errors::fatal("section cannot be independently tangled");
	Str::copy(tangle_leaf, Filenames::get_leafname(S->md->source_file_for_section));

@ Weaving is not actually easier, it's just more thoroughly delegated:

@<Weave the web@> =
	Numbering::number_web(W);
	if (ins->weave_docs) @<Prepare a docs weave@>;

	theme_tag *tag = Tags::find_by_name(ins->tag_setting, FALSE);
	if ((Str::len(ins->tag_setting) > 0) && (tag == NULL))
		Errors::fatal_with_text("no such theme as '%S'", ins->tag_setting);

	weave_pattern *pattern = Patterns::find(W, ins->weave_pattern);
	if ((ins->chosen_range_actually_chosen == FALSE) && (ins->chosen_file == NULL))
		Configuration::set_range(ins, pattern->default_range);

	int r = Formats::begin_weaving(W, pattern);
	if (r != SWARM_OFF_SWM) ins->swarm_mode = r;
	@<Assign section numbers for printing purposes@>;
	if (ins->swarm_mode == SWARM_OFF_SWM) {
		int shall_we_open = ins->open_pdf_switch;
		if (shall_we_open == NOT_APPLICABLE) { /* i.e., if it wasn't set at the command line */
			if (Str::len(pattern->open_command) > 0) shall_we_open = TRUE;
			else shall_we_open = FALSE;
		}
		if (tag) PRINT("Tag!\n");
		Swarm::weave_subset(W, ins->chosen_range, shall_we_open, tag, pattern,
			ins->weave_to_setting, ins->weave_into_setting, ins->weave_docs,
			ins->breadcrumb_setting, ins->navigation_setting);
	} else {
		Swarm::weave(W, ins->chosen_range, ins->swarm_mode, tag, pattern,
			ins->weave_to_setting, ins->weave_into_setting, ins->weave_docs,
			ins->breadcrumb_setting, ins->navigation_setting);
	}
	Formats::end_weaving(W, pattern);

@ If the |-weave-docs| option was used, we have to weave into a subfolder of
|docs|, and we'll create it if it doesn't already exist.

@<Prepare a docs weave@> =
	if (ins->weave_into_setting == NULL) {
		pathname *docs = Pathnames::subfolder(W->md->path_to_web, I"docs");
		Pathnames::create_in_file_system(docs);
		text_stream *leaf = Str::new();
		if (Bibliographic::data_exists(W->md, I"Short Title"))
			Str::copy(leaf, Bibliographic::get_datum(W->md, I"Short Title"));
		else
			Str::copy(leaf, Bibliographic::get_datum(W->md, I"Title"));
		if (Str::len(leaf) > 0) {
			ins->weave_into_setting = Pathnames::subfolder(docs, leaf);
			Pathnames::create_in_file_system(ins->weave_into_setting);
		} else ins->weave_into_setting = docs;
	} else {
		Pathnames::create_in_file_system(ins->weave_into_setting);
	}
	W->redirect_weaves_to = ins->weave_into_setting;
	ins->weave_pattern = I"GitHubPages";

@<Assign section numbers for printing purposes@> =
	section *S; int k = 1;
	LOOP_OVER(S, section)
		if (Reader::range_within(S->sect_range, ins->chosen_range))
			S->printed_number = k++;

@h Error messages.
The Foundation module provides convenient functions to issue error messages,
but we'll use the following wrapper when issuing an error at a line of web
source:

=
void Main::error_in_web(text_stream *message, source_line *sl) {
	if (sl) {
		Errors::in_text_file_S(message, &(sl->source));
		WRITE_TO(STDERR, "%07d  %S\n", sl->source.line_count, sl->text);
	} else {
		Errors::in_text_file_S(message, NULL);
	}
	no_inweb_errors++;
}
