[InwebTangle::] inweb tangle Subcommand.

The inweb tangle subcommand tangles a web.

@ The command line interface and help text:

@e TANGLING_CLSUB

@e TANGLE_TO_CLSW
@e TANGLE_ONLY_CLSW

@e CTAGS_CLSG
@e CTAGS_TO_CLSW
@e CTAGS_CLSW

=
void InwebTangle::cli(void) {
	CommandLine::begin_subcommand(TANGLING_CLSUB, U"tangle");
	CommandLine::declare_heading(
		U"Usage: inweb tangle [WEB]\n\n"
		U"Tangling is one of the two fundamental operations of literate programming\n"
		U"(for the other, see 'inweb help weave'). It strips out the markup in a web,\n"
		U"rearranging it back into its linear structure if it had been presented\n"
		U"differently for the sake of exposition, and writes out a file which, while\n"
		U"not very legible to a human reader, can be interpreted or compiled and then run.\n\n"
		U"If no WEB is specified, Inweb tries to tangle the current working directory.\n\n"
		U"If the WEB occupies a directory, the output is placed in its 'Tangled' subdirectory\n"
		U"by default, but '-to FILE' can be used to move this.\n\n"
		U"Some webs are set up so that certain sections or chapters tangle to independent\n"
		U"'targets', typically configuration files or other sidekick programs. If so, '-only'\n"
		U"can be used to make just that one independent target. Otherwise, all targets are made.\n\n"
		U"For some languages Inweb can detect where functions and symbols are defined, and\n"
		U"can use this to make a standard 'Universal Ctags' file of locations in the source;\n"
		U"which can be of benefit to text editors and other coding tools.");

	CommandLine::declare_switch(TANGLE_TO_CLSW, U"to", 2,
		U"write the tangled program to filename X");
	CommandLine::declare_switch(TANGLE_ONLY_CLSW, U"only", 2,
		U"tangle only the section or chapter whose abbreviation is X");

	CommandLine::begin_group(CTAGS_CLSG,
		I"support for Universal Ctags");
	CommandLine::declare_switch(CTAGS_TO_CLSW, U"ctags-to", 2,
		U"write Universal Ctags file to X rather than to 'tags'");
	CommandLine::declare_boolean_switch(CTAGS_CLSW, U"ctags", 1,
		U"write a Universal Ctags file when tangling larger webs", TRUE);
	CommandLine::end_group();
	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_tangle_settings {
	struct filename *tangle_setting; /* |-to X|: the tangling */
	int tangle_to_STDOUT; /* |-to -| */
	struct inweb_range_specifier subset;
	int ctags_switch; /* |-ctags|: generate a set of Universal Ctags on each tangle */
	struct filename *ctags_setting; /* |-ctags-to X|: the pathname X, if supplied */
} inweb_tangle_settings;

void InwebTangle::initialise(inweb_tangle_settings *its) {
	its->tangle_setting = NULL;
	its->tangle_to_STDOUT = FALSE;
	its->subset = Configuration::new_range_specifier();
	its->ctags_switch = NOT_APPLICABLE;
	its->ctags_setting = NULL;
}

int InwebTangle::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_tangle_settings *its = &(ins->tangle_settings);
	switch (id) {
		case TANGLE_TO_CLSW:
			if (Str::eq(arg, I"-")) {
				its->tangle_to_STDOUT = TRUE; its->tangle_setting = NULL;
			} else {
				its->tangle_to_STDOUT = FALSE; its->tangle_setting = Filenames::from_text(arg);
			}
			return TRUE;
		case TANGLE_ONLY_CLSW: Configuration::set_range(&(its->subset), arg, FALSE); return TRUE;
		case CTAGS_CLSW: its->ctags_switch = val; return TRUE;
		case CTAGS_TO_CLSW: its->ctags_setting = Filenames::from_text(arg); return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebTangle::run(inweb_instructions *ins) {
	inweb_tangle_settings *its = &(ins->tangle_settings);
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_COMPULSORY, TRUE, FALSE);
	if (no_inweb_errors > 0) return;
	ls_web *W = op.W;
	if (its->ctags_switch == NOT_APPLICABLE) {
		if ((W->is_page == FALSE) && (Ctags::useful_tags_exist(W))) its->ctags_switch = TRUE;
		else its->ctags_switch = FALSE;
	}
	@<Tangle the web@>;
}

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
	tangle_target *target = NULL;
	if (Str::eq_wide_string(its->subset.range, U"0"))
		@<Work out main tangle destination@>
	else if (WebRanges::to_section(W, its->subset.range))
		@<Work out an independent tangle destination, from one section of the web@>;
	if (Str::len(tangle_leaf) == 0) Errors::fatal("no tangle destination known");

	filename *tangle_to = its->tangle_setting;
	if (its->tangle_to_STDOUT) silent_mode = TRUE;
	else if (tangle_to == NULL) {
		pathname *P;
		if (W->single_file) P = Filenames::up(W->single_file);
		else P = WebStructure::tangled_folder(W);
		tangle_to = Filenames::in(P, tangle_leaf);
	}
	if (silent_mode == FALSE) {
		PRINT("tangling "); WebStructure::print_web_identity(W);
		PRINT(" to file '%f'\n", tangle_to);
	}
	text_stream *OUT = STDOUT;
	text_stream TO_struct;
	if (its->tangle_to_STDOUT == FALSE) {
		OUT = &TO_struct;
		if (STREAM_OPEN_TO_FILE(OUT, tangle_to, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write tangled file", tangle_to);
	}
	Tangler::tangle_web(OUT, W, Filenames::up(tangle_to), TangleTargets::primary_target(W));
	if (its->tangle_to_STDOUT == FALSE)
		STREAM_CLOSE(OUT);
	if (its->ctags_switch == TRUE) Ctags::write(W, its->ctags_setting);
	DISCARD_TEXT(tangle_leaf)

@ For the main tangle of a web (usually the only one), the destination leafname
defaults to something like its program name with |.c| (or |.cpp|, |.swift|, ...,
as appropriate) tacked on:

@<Work out main tangle destination@> =
	target = TangleTargets::primary_target(W);
	if (W->single_file) {
		Filenames::write_unextended_leafname(tangle_leaf, W->single_file);
		TEMPORARY_TEXT(pen)
		Filenames::write_penultimate_extension(pen, W->single_file);
		if (Str::len(pen) > 0)
			Str::concatenate(tangle_leaf, pen);
		else
			Str::concatenate(tangle_leaf, Languages::canonical_file_extension(WebStructure::web_language(W)));
		DISCARD_TEXT(pen)
	} else {
		if (Bibliographic::data_exists(W, I"Short Title"))
			Str::copy(tangle_leaf, Bibliographic::get_datum(W, I"Short Title"));
		else
			Str::copy(tangle_leaf, Bibliographic::get_datum(W, I"Title"));
		Str::concatenate(tangle_leaf, Languages::canonical_file_extension(WebStructure::web_language(W)));
	}

@ Side-tangles, which most webs do not have, default to the leafname of
their sections:

@<Work out an independent tangle destination, from one section of the web@> =
	ls_section *S = WebRanges::to_section(W, its->subset.range);
	target = TangleTargets::of_section(S);
	if (target == NULL) Errors::fatal("section cannot be independently tangled");
	Str::copy(tangle_leaf, Filenames::get_leafname(S->source_file_for_section));

