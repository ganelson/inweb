[Configuration::] Configuration.

To parse the command line arguments with which inweb was called,
and to handle any errors it needs to issue.

@h Instructions.
The following structure exists just to hold what the user specified on the
command line: there will only ever be one of these.

As with any complex tool, Inweb has a welter of command-line switches and options,
and for clarity here we break them down into individual CLIs for each subcommand.
Thus, switches for one subcommand are inaccessible in the others. In this section
of code, we manage only a handful of shared settings, together with some functions
providing a common set of conventions for parsing the most common settings.

=
typedef struct inweb_instructions {
	int subcommand; /* our main mode of operation: one of the |*_CLSUB| constants */
	int verbose_switch; /* |-verbose|: print names of files read to stdout */
	struct pathname *import_setting; /* |-import X|: where to find imported webs */

	struct inweb_weave_settings weave_settings;
	struct inweb_tangle_settings tangle_settings;
	struct inweb_inspect_settings inspect_settings;
	struct inweb_make_settings make_settings;
	struct inweb_test_language_settings test_language_settings;

	struct text_stream *temp_colony_setting; /* |-colony X|: file or path, if supplied */
	struct text_stream *temp_member_setting; /* |-member X|: sets web to member X of colony */
	struct pathname *temp_path_setting; /* project folder relative to cwd */
	struct filename *temp_file_setting; /* or, single file relative to cwd */
} inweb_instructions;

@h Reading the command line.
The dull work of this is done by the Foundation module: all we need to do is
to enumerate constants for the Inweb-specific command line switches, and
then declare them.

=
inweb_instructions Configuration::read(int argc, char **argv) {
	inweb_instructions args;
	@<Initialise the args@>;
	@<Declare the command-line switches specific to Inweb@>;
	args.subcommand = CommandLine::read(argc, argv, &args,
		&Configuration::switch, &Configuration::bareword);
	return args;
}

@<Initialise the args@> =
	args.subcommand = NO_CLSUB;
	args.verbose_switch = FALSE;
	args.import_setting = NULL;

	InwebWeave::initialise(&(args.weave_settings));
	InwebTangle::initialise(&(args.tangle_settings));
	InwebInspect::initialise(&(args.inspect_settings));
	InwebMake::initialise(&(args.make_settings));
	InwebTestLanguage::initialise(&(args.test_language_settings));

	args.temp_colony_setting = NULL;
	args.temp_member_setting = NULL;
	args.temp_path_setting = NULL;
	args.temp_file_setting = NULL;

@ The CommandLine section of Foundation needs to be told what command-line
switches we want, other than the standard set (such as |-help|) which it
provides automatically.

@e VERBOSE_CLSW
@e IMPORT_FROM_CLSW
@e USING_CLSW
@e COLONY_CLSW
@e MEMBER_CLSW

@<Declare the command-line switches specific to Inweb@> =
	CommandLine::declare_heading(U"inweb: a tool for literate programming\n\n"
		U"Inweb is a system for literate programming. It deals with 'webs',\n"
		U"programs written in conventional programming languages like C (which\n"
		U"Inweb calls 'languages') marked up in human-readable ways to reveal\n"
		U"their structure and explain their motivation. Inweb can handle multiple\n"
		U"markup syntaxes (which it calls 'notations'). It can also group together\n"
		U"multiple webs into connected masses, which it calls 'colonies'.\n\n"
		U"Inweb is an all-in-one tool for LP which is divided up into subcommands,\n"
		U"each able to perform a different task. 'inweb tangle' and 'inweb weave'\n"
		U"are the two used constantly: tangling processes a web into a form\n"
		U"which can be compiled, and weaving makes it into something human-readable.\n\n"
		U"Usage: inweb COMMAND [DETAILS]\n\n"
		U"where the DETAILS are different for each COMMAND.");

	CommandLine::resume_group(FOUNDATION_CLSG);
	CommandLine::declare_boolean_switch(VERBOSE_CLSW, U"verbose", 1,
		U"explain what inweb is doing", FALSE);
	CommandLine::declare_switch(IMPORT_FROM_CLSW, U"import-from", 2,
		U"specify that imported modules are at pathname X");
	CommandLine::declare_switch(USING_CLSW, U"using", 2,
		U"making Inweb resources in the file or path X available to all webs");
	CommandLine::declare_switch(COLONY_CLSW, U"colony", 2,
		U"if the newer 'colony:" U":member' notation is problematic, use this and '-member'");
	CommandLine::declare_switch(MEMBER_CLSW, U"member", 2,
		U"if the newer 'colony:" U":member' notation is problematic, use this and '-colony'");
	CommandLine::end_group();

	InwebWeave::cli();
	InwebTangle::cli();
	InwebInspect::cli();
	InwebMake::cli();
	InwebAdvanceBuild::cli();
	InwebTestLanguage::cli();

@ Foundation calls this on any |-switch| argument read:

=
void Configuration::switch(int id, int val, text_stream *arg, void *state) {
	inweb_instructions *args = (inweb_instructions *) state;
	if (InwebWeave::switch(args, id, val, arg)) return;
	if (InwebTangle::switch(args, id, val, arg)) return;
	if (InwebMake::switch(args, id, val, arg)) return;
	if (InwebInspect::switch(args, id, val, arg)) return;
	if (InwebTestLanguage::switch(args, id, val, arg)) return;
	switch (id) {
		/* Miscellaneous */
		case VERBOSE_CLSW: args->verbose_switch = TRUE; break;
		case IMPORT_FROM_CLSW: args->import_setting = Pathnames::from_text(arg); break;
		case USING_CLSW: {
			filename *F = Filenames::from_text(arg);
			if (TextFiles::exists(F)) {
				WCL::make_resources_at_file_global(F);
			} else {
				pathname *P = Pathnames::from_text(arg);
				if (Directories::exists(P)) WCL::make_resources_at_path_global(P);
			}
			break;
		}

		/* The alternate way to specify a web as a colony member: */
		case COLONY_CLSW: args->temp_colony_setting = Str::duplicate(arg); break;
		case MEMBER_CLSW: args->temp_member_setting = Str::duplicate(arg); break;

		default: internal_error("unimplemented switch");
	}
}

@ Foundation calls this routine on any command-line argument which is neither a
switch, nor an argument for a switch. For the Inweb subcommands, this means it
is specifies a web, or else a file, or else a path. Details are written into
the temporary settings first, because they can only be understood in the light
of other settings which might not have been made yet.

=
void Configuration::bareword(int id, text_stream *opt, void *state) {
	inweb_instructions *args = (inweb_instructions *) state;
	match_results mr = Regexp::create_mr();
	int used = FALSE;
	if (Regexp::match(&mr, opt, U"(%c*?)::(%c*)")) {
		if (Str::len(mr.exp[0]) > 0) {
			if (Str::len(args->temp_colony_setting) == 0) {
				args->temp_colony_setting = Str::duplicate(mr.exp[0]); used = TRUE;
			} else
				Errors::fatal("the colony before a '::' can be set only once");
		}
		if (Str::len(mr.exp[1]) > 0) {
			if (Str::len(args->temp_member_setting) == 0) {
				args->temp_member_setting = Str::duplicate(mr.exp[1]); used = TRUE;
			} else
				Errors::fatal("the member after a '::' can be set only once");
		}
	} else {
		if ((args->temp_path_setting == NULL) && (args->temp_file_setting == NULL)) {
			filename *putative = Filenames::from_text(opt);
			pathname *putative_path = Pathnames::from_text(opt);
			if (TextFiles::exists(putative)) {
				args->temp_file_setting = putative; used = TRUE;
			} else if (Directories::exists(putative_path)) {
				args->temp_path_setting = putative_path; used = TRUE;
			}
		}
	}
	if (used == FALSE) {
		Errors::fatal_with_text("does not seem to be either a web, a file or a directory: '%S'", opt);
	}
	int tally = 0;
	if ((Str::len(args->temp_colony_setting) > 0) || (Str::len(args->temp_member_setting) > 0)) tally++;
	if (args->temp_file_setting) tally++;
	if (args->temp_path_setting) tally++;
	if (tally > 1)
		Errors::fatal("only one argument can follow the command, except where -switches are used");
	Regexp::dispose_of(&mr);
}

@h Main operand.
Most of our subcommands take a single main operand, which is deduced from the
temporary settings made above. Our aim will be to produce one of these objects:

=
typedef struct inweb_operand {
	struct wcl_declaration *D;
	struct ls_web *W;
	struct colony *C;
	struct colony_member *CM;
	struct filename *F;
	struct pathname *P;
} inweb_operand;

@ Our exact wishes depend on the subcommand used. On the other hand, we want to
apply consistent conventions for different commands as far as possible. So we
compromise and allow subcommands to choose what they will allow in the main
operand, but otherwise use the same rules for all of them:

@d NO_OPERAND_ALLOWED 0
@d WEB_OPERAND_ALLOWED 1        /* i.e., a web, a path, or a file */
@d WEB_OPERAND_DISALLOWED 2     /* i.e., a path or a file only */
@d WEB_OPERAND_COMPULSORY 3     /* i.e., a web only */

@ A further tweak is that we sometimes want the web to be read in a particular
way (if a web is what is provided). If |enumerating| is set then values will be
assigned to enumerated constants found in the web -- this is unnecessary most
of the time, and will be meaningless or impossible if only a subset of the web
is being considered. If |weaving| is set, then certain sorts of code rewriting
are not performed (for example, the I-string constants like |I"this"| used in
the InC language are not rewritten as their regular C implementations).

@ The conventions below are very carefully arranged, which is always a warning
sign in any algorithm. The aim is to infer as much as possible from as little
input as possible, that is, to allow the user to be vague... but not too vague.

=
inweb_operand Configuration::operand(inweb_instructions *ins, int requirement,
	int enumerating, int weaving) {
	if (requirement == NO_OPERAND_ALLOWED) @<Fail if any operand was supplied@>;

	inweb_operand op = { NULL, NULL, NULL, NULL, NULL, NULL };

	filename *colony_file = NULL;
	int inferred_web_as_colony_member = FALSE;
	if (requirement != WEB_OPERAND_DISALLOWED) {
		@<Find the colony@>;
		if (Str::len(ins->temp_member_setting) > 0) @<Find the member@>;
	}
	if (ins->temp_file_setting) @<Read this file as WCL resources@>;
	if (requirement != WEB_OPERAND_DISALLOWED) @<Try to read our file or path as a web@>;
	@<Tidy up our findings@>;

	if (requirement == WEB_OPERAND_COMPULSORY) @<Fail if no web was supplied@>;
	return op;
}

@<Fail if any operand was supplied@> =
	if ((Str::len(ins->temp_colony_setting) > 0) ||
		(Str::len(ins->temp_member_setting) > 0) ||
		(ins->temp_path_setting) ||
		(ins->temp_file_setting))
		Errors::fatal("this command does not accept a web or file as argument");
	
@<Fail if no web was supplied@> =	
	if (op.W == NULL)
		Errors::fatal("no web was specified");

@<Find the colony@> =
	if (Str::len(ins->temp_colony_setting) > 0) @<Locate the colony file from its setting@>
	else @<Try to find a nearby colony file@>;

	if (colony_file) {
		op.C = Colonies::load(colony_file);
		if (op.C == NULL) Errors::fatal_with_file("not a valid colony file", colony_file);
	}

@ So this looks at the text |C| from |-colony C| or else from |C::M|, if either
of those syntaxes was used. If we are here, |C| is non-empty. It should either
be a valid filename, or a valid directory name for a directory containing either
a |colony.inweb| or |colony.txt| file.

@<Locate the colony file from its setting@> =
	colony_file = Filenames::from_text(ins->temp_colony_setting);
	if (TextFiles::exists(colony_file) == FALSE) {
		pathname *P = Pathnames::from_text(ins->temp_colony_setting);
		if (Directories::exists(P)) {
			colony_file = Filenames::in(P, I"colony.inweb");
			if (TextFiles::exists(colony_file) == FALSE)
				colony_file = Filenames::in(P, I"colony.txt");
		}
	}
	if (TextFiles::exists(colony_file) == FALSE)
		Errors::fatal_with_text("cannot find a colony file for '%S'",
			ins->temp_colony_setting);

@ This alternative strategy is used if no such colony text is provided. That
doesn't mean there is no colony file in play: just that the user hasn't specified
it. If we can in fact find a colony file close to the relevant file or above
the relevant path, we'll use that.

@<Try to find a nearby colony file@> =
	pathname *search = NULL;
	if (ins->temp_file_setting) search = Filenames::up(ins->temp_file_setting);
	else if (ins->temp_path_setting) search = ins->temp_path_setting;
	@<Look for a colony file in the search directory@>;
	while ((colony_file == NULL) && (search)) {
		search = Pathnames::up(search);
		@<Look for a colony file in the search directory@>;
	}

@<Look for a colony file in the search directory@> =
	filename *CF = Filenames::in(search, I"colony.inweb");
	if ((TextFiles::exists(CF) == FALSE) && (old_inweb_compatibility_mode))
		CF = Filenames::in(search, I"colony.txt");
	if (TextFiles::exists(CF)) colony_file = CF;

@ This looks at the text |M| from |-member M| or else from |C::M|, if either
of those syntaxes was used. Note that it's absolutely necessary for a colony
file to exist and be valid, on order for this to make sense, and moreover |M|
has to be one of its member names; lastly, there must actually be a web in
the place that the colony file says it will be.

@<Find the member@> =
	if (op.C == NULL)
		Errors::fatal_with_text("can't find a colony file in which to seek '%S'",
			ins->temp_member_setting);
	op.CM = Colonies::find(op.C, ins->temp_member_setting);
	if (op.CM == NULL)
		Errors::fatal_with_text("the colony has no member called '%S'",
			ins->temp_member_setting);
	if ((ins->temp_path_setting == NULL) && (ins->temp_file_setting == NULL)) {
		pathname *P = Filenames::up(colony_file);
		P = NULL; /* for now */
		filename *putative = Filenames::from_text_relative(P, op.CM->path);
		pathname *putative_path = Pathnames::from_text_relative(P, op.CM->path);
		if (TextFiles::exists(putative))
			ins->temp_file_setting = putative;
		else if (Directories::exists(putative_path))
			ins->temp_path_setting = putative_path;
		else {
			TEMPORARY_TEXT(ERM)
			WRITE_TO(ERM,
				"colony member '%S' should be at '%S', but nothing's there (%f)",
				ins->temp_member_setting, op.CM->path, putative);
			WebErrors::issue_at(ERM, NULL);
			DISCARD_TEXT(ERM)
		}
		inferred_web_as_colony_member = TRUE;
	} else {
		Errors::fatal("cannot specify a web and also a colony member");
	}

@ So here we have a single file, and try to read it as WCL. WCL is a format
which can hold multiple different sorts of resource: a WCL file can explicitly
say what kind it holds, but if it doesn't, we have to guess that from context.
Here's where we do the guessing.

@<Read this file as WCL resources@> =
	int presume = MISCELLANY_WCLTYPE; /* i.e., make no assumptions */
	if ((requirement == WEB_OPERAND_COMPULSORY) ||
		(inferred_web_as_colony_member)) presume = WEB_WCLTYPE;
	else {
		if (Str::eq_insensitive(Filenames::get_leafname(ins->temp_file_setting), I"colony.inweb"))
			presume = COLONY_WCLTYPE;
		if (old_inweb_compatibility_mode) {
			TEMPORARY_TEXT(ext)
			Filenames::write_extension(ext, ins->temp_file_setting);
			if (Str::eq_insensitive(Filenames::get_leafname(ins->temp_file_setting), I"colony.txt"))
				presume = COLONY_WCLTYPE;
			if (Str::eq_insensitive(ext, I".inwebc"))
				presume = WEB_WCLTYPE;
			if (Str::eq_insensitive(ext, I".inwebsyntax"))
				presume = NOTATION_WCLTYPE;
			if (Str::eq_insensitive(ext, I".ildf"))
				presume = LANGUAGE_WCLTYPE;
			DISCARD_TEXT(ext)
		}
	}
	op.D = WCL::read_for_type_only_forgivingly(ins->temp_file_setting, presume);

@ A single file will only be a web if it's not already been parsed as something
else (say, a language definition); a path will only be a web if it contains a
contents section.

@<Try to read our file or path as a web@> =
	if ((op.D == NULL) || (op.D->declaration_type == WEB_WCLTYPE)) {
		if (((ins->temp_path_setting) &&
			(TextFiles::exists(Filenames::in(ins->temp_path_setting, I"Contents.w")))) ||
			(ins->temp_file_setting)) {
			op.D = WCL::read_web_or_halt(ins->temp_path_setting, ins->temp_file_setting);
			op.W = WebStructure::read_fully(op.D, enumerating, weaving, verbose_mode);
		}
	}

@ The most notable thing here is that we make an attempt (no more than that) to
reconcile things in the case where the user has not specified a colony or member,
only a web, but where there is a colony file nearby which we have auto-detected.
Is the web a member of that colony or not? If it seems to be, we'll fill in |op.CM|.
But it's probably not wise to rely too much on this.

@<Tidy up our findings@> =	
	if (op.W == NULL) {
		op.F = ins->temp_file_setting;
		op.P = ins->temp_path_setting;
	}
	if ((op.C) && (op.W) && (op.CM == NULL)) {
		TEMPORARY_TEXT(candidate)
		if (op.W->single_file)
			Filenames::write_unextended_leafname(candidate, op.W->single_file);
		else if (op.W->path_to_web)
			WRITE_TO(candidate, "%S", Pathnames::directory_name(op.W->path_to_web));
		colony_member *CM;
		LOOP_OVER_LINKED_LIST(CM, colony_member, op.C->members) {
			if (Str::eq_insensitive(CM->name, candidate)) {
				op.CM = CM; break;
			}
		}
	}

@h Range operand.
Some subcommands take a further operand called a "range", usually after a |-only|
setting. These are in addition to a main operand, not instead of it, and indeed
make sense only in the context of the main operand specifying a web.

Subsets of a web are represented by short pieces of text called "ranges". This
can be a section range like |2/pine|, a chapter number like |12|, an appendix
letter |A| or the preliminaries block |P|, the special chapter |S| for the
"Sections" chapter of an unchaptered web, or the special value |0| to mean the
entire web (which is the default).

=
typedef struct inweb_range_specifier {
	struct text_stream *range; /* which subset of this web we apply to (often, all of it) */
	int chosen_range_actually_chosen; /* rather than being a default choice */
	int swarm_mode; /* relevant to weaving only: one of the |*_SWARM| constants */
} inweb_range_specifier;

inweb_range_specifier Configuration::new_range_specifier(void) {
	inweb_range_specifier irs;
	irs.range = Str::duplicate(I"0");
	irs.chosen_range_actually_chosen = FALSE;
	irs.swarm_mode = SWARM_OFF_SWM;
	return irs;
}

void Configuration::set_range(inweb_range_specifier *irs, text_stream *opt, int swarming) {
	if (irs->chosen_range_actually_chosen) Errors::fatal("-only may be specified just once");
	if (Str::eq_wide_string(opt, U"index")) {
		if (swarming == FALSE)
			Errors::fatal("the -only value 'index' is allowed only for 'inweb weave'");
		irs->swarm_mode = SWARM_INDEX_SWM;
	} else if (Str::eq_wide_string(opt, U"chapters")) {
		if (swarming == FALSE)
			Errors::fatal("the -only value 'chapters' is allowed only for 'inweb weave'");
		irs->swarm_mode = SWARM_CHAPTERS_SWM;
	} else if (Str::eq_wide_string(opt, U"sections")) {
		if (swarming == FALSE)
			Errors::fatal("the -only value 'sections' is allowed only for 'inweb weave'");
		irs->swarm_mode = SWARM_SECTIONS_SWM;
	} else {
		if (Str::eq_wide_string(opt, U"all")) {
			Str::copy(irs->range, I"0");
		} else {
			Str::copy(irs->range, opt);
			LOOP_THROUGH_TEXT(pos, irs->range)
				Str::put(pos, Characters::tolower(Str::get(pos)));
		}
	}
	irs->chosen_range_actually_chosen = TRUE;
}
