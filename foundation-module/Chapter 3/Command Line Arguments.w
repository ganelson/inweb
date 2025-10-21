[CommandLine::] Command Line Arguments.

To parse the command line arguments with which inweb was called,
and to handle any errors it needs to issue.

@h Model.
Our scheme is that the command line syntax will contain an optional
series of dashed switches. Some switches appear alone, others must be
followed by an argument. Anything not part of the switches is termed
a "bareword". For example, in
= (text)
	-log no-memory-usage -fixtime jam marmalade
=
there are two switches, |-log| taking an argument (it has valency 2
in the terminology below), |-fixtime| not (valency 1). There are
then two barewords, |jam| and |marmalade|.

@h Subcommands.
In case of a prodigious number of switches (ever tried typing |clang -help|?),
we'll hash the switch names into a dictionary as well as keeping a list.

@e NO_CLSUB from 0
@e NO_COMMAND_CLSUB

=
typedef struct command_line_subcommand {
	int subcommand_id;
	struct text_stream *command_name; /* e.g., |compile| */
	struct text_stream *heading; /* explanatory text */
	struct dictionary *cls_dictionary;
	struct linked_list *cls_list; /* of |command_line_switch| */
	CLASS_DEFINITION
} command_line_subcommand;

command_line_subcommand *current_subcommand = NULL, *empty_subcommand = NULL;

command_line_subcommand *CommandLine::new_subcommand(int id, inchar32_t *name) {
	command_line_subcommand *sub = CREATE(command_line_subcommand);
	sub->subcommand_id = id;
	sub->command_name = Str::new_from_wide_string(name);
	sub->heading = NULL;
	sub->cls_dictionary = Dictionaries::new(32, FALSE);
	sub->cls_list = NEW_LINKED_LIST(command_line_switch);
	return sub;
}

command_line_subcommand *CommandLine::get_empty_subcommand(void) {
	if (empty_subcommand == NULL)
		empty_subcommand = CommandLine::new_subcommand(NO_COMMAND_CLSUB, NULL);
	return empty_subcommand;
}

void CommandLine::begin_subcommand(int id, inchar32_t *name) {
	if ((current_subcommand) &&
		(current_subcommand != CommandLine::get_empty_subcommand()))
		internal_error("must finish declaring one subcommand before starting another");
	current_subcommand = CommandLine::new_subcommand(id, name);
}

command_line_subcommand *CommandLine::current_subcommand(void) {
	if (current_subcommand == NULL)
		current_subcommand = CommandLine::get_empty_subcommand();
	return current_subcommand;
}

void CommandLine::declare_heading(inchar32_t *heading_text_literal) {
	command_line_subcommand *cls = CommandLine::current_subcommand();
	cls->heading = Str::new_from_wide_string(heading_text_literal);
}

void CommandLine::add_to_current_subcommand(command_line_switch *cls) {
	command_line_subcommand *sub = CommandLine::current_subcommand();
	Dictionaries::create(sub->cls_dictionary, cls->switch_name);
	Dictionaries::write_value(sub->cls_dictionary, cls->switch_name, cls);
	ADD_TO_LINKED_LIST(cls, command_line_subcommand, sub->cls_list);
}

command_line_switch *CommandLine::find_cls(command_line_subcommand *context,
	text_stream *opt) {
	if (context == NULL) context = CommandLine::get_empty_subcommand();
	if (Dictionaries::find(context->cls_dictionary, opt) == NULL) return NULL;
	return Dictionaries::read_value(context->cls_dictionary, opt);
}

void CommandLine::end_subcommand(void) {
	CommandLine::end_group();
	current_subcommand = CommandLine::get_empty_subcommand();
}

@h Switches.
Each different switch available is stored in one of these structures.
Switches come in five sorts:

@e ACTION_CLSF from 1 /* does something */
@e BOOLEAN_ON_CLSF /* sets a flag true */
@e BOOLEAN_OFF_CLSF /* sets a flag false */
@e NUMERICAL_CLSF /* sets an integer to the given value */
@e TEXTUAL_CLSF /* sets text to the given value */

@ Switches are also grouped, though this affects only the printout of them
in |-help|. Groups are enumerated thus:

@e NO_CLSG from 0
@e FOUNDATION_CLSG

=
typedef struct command_line_switch {
	int switch_id;
	struct text_stream *switch_name; /* e.g., |no-verbose| */
	struct text_stream *switch_sort_name; /* e.g., |verbose| */
	struct text_stream *help_text;
	int valency; /* 1 for bare, 2 for one argument follows */
	int form; /* one of the |*_CLSF| values above */
	int switch_group; /* one of the |*_CLSG| valyes above */
	int active_by_default; /* relevant only for booleans */
	struct command_line_switch *negates; /* relevant only for booleans */
	CLASS_DEFINITION
} command_line_switch;

@ The client must declare all the switches her program will make use of, not
counting the standard set already declared by Foundation (such as |-help|).
A new |*_CLSW| value should be enumerated to be the ID referring to this
swtich, and then the client should call:

=
int current_switch_group = -1;
text_stream *switch_group_names[NO_DEFINED_CLSG_VALUES+1];
void CommandLine::begin_group(int id, text_stream *name) {
	if (current_switch_group == -1)
		for (int i=0; i<=NO_DEFINED_CLSG_VALUES; i++) switch_group_names[i] = NULL;
	current_switch_group = id;
	switch_group_names[id] = name;
}
void CommandLine::resume_group(int id) {
	if (current_switch_group == -1)
		for (int i=0; i<=NO_DEFINED_CLSG_VALUES; i++) switch_group_names[i] = NULL;
	current_switch_group = id;
}
void CommandLine::end_group(void) {
	if (current_switch_group == -1)
		for (int i=0; i<=NO_DEFINED_CLSG_VALUES; i++) switch_group_names[i] = NULL;
	current_switch_group = NO_CLSG;
}
command_line_switch *CommandLine::declare_switch(int id,
	inchar32_t *name_literal, int val, inchar32_t *help_literal) {
	return CommandLine::declare_switch_p(id,
		Str::new_from_wide_string(name_literal), val,
		Str::new_from_wide_string(help_literal));
}
command_line_switch *CommandLine::declare_switch_p(int id,
	text_stream *name, int val, text_stream *help_literal) {
	if (current_switch_group == -1) {
		current_switch_group = NO_CLSG;
		for (int i=0; i<=NO_DEFINED_CLSG_VALUES; i++) switch_group_names[i] = NULL;
	}
	command_line_switch *cls = CREATE(command_line_switch);
	cls->switch_name = name;
	@<Make the sorting name@>;
	cls->switch_id = id;
	cls->valency = val;
	cls->help_text = help_literal;
	cls->form = ACTION_CLSF;
	cls->active_by_default = FALSE;
	cls->negates = NULL;
	cls->switch_group = current_switch_group;
	CommandLine::add_to_current_subcommand(cls);
	return cls;
}

@ When we alphabetically sort switches for the |-help| output, we want to
file, say, |-no-verbose| immediately after |-verbose|, not back in the N
section. So the sorting version of |no-verbose| is |verbose_|.

@<Make the sorting name@> =
	cls->switch_sort_name = Str::duplicate(name);
	if (Str::begins_with_wide_string(name, U"no-")) {
		Str::delete_n_characters(cls->switch_sort_name, 3);
		WRITE_TO(cls->switch_sort_name, "_");
	}

@ Booleans are automatically created in pairs, e.g., |-destroy-world| and
|-no-destroy-world|:

=
command_line_switch *CommandLine::declare_boolean_switch(int id,
	inchar32_t *name_literal, int val, inchar32_t *help_literal, int active) {
	command_line_switch *cls =
		CommandLine::declare_switch(id, name_literal, val, help_literal);
	text_stream *neg = Str::new();
	WRITE_TO(neg, "no-%w", name_literal);
	text_stream *neg_help = Str::new();
	WRITE_TO(neg_help, "don't %w", help_literal);
	command_line_switch *negated =
		CommandLine::declare_switch_p(id, neg, val, neg_help);

	cls->form = BOOLEAN_ON_CLSF;
	negated->form = BOOLEAN_OFF_CLSF;
	negated->negates = cls;
	
	if (active) cls->active_by_default = TRUE; else negated->active_by_default = TRUE;
	return cls;
}

void CommandLine::declare_numerical_switch(int id,
	inchar32_t *name_literal, int val, inchar32_t *help_literal) {
	command_line_switch *cls =
		CommandLine::declare_switch(id, name_literal, val, help_literal);
	cls->form = NUMERICAL_CLSF;
}

void CommandLine::declare_textual_switch(int id,
	inchar32_t *name_literal, int val, inchar32_t *help_literal) {
	command_line_switch *cls =
		CommandLine::declare_switch(id, name_literal, val, help_literal);
	cls->form = TEXTUAL_CLSF;
}

@h Reading the command line.
Once all the switches are declared, the client calls the following routine
in order to parse the usual C |argc| and |argv| pair, and take action as
appropriate. The client passes a pointer to some structure in |state|:
probably a structure holding its settings variables. When we parse a
switch, we call |f| to say so; when we parse a bareword, we call |g|. In
each case we pass back |state| so that these functions can record whatever
they would like to in the state structure.

The return value is |TRUE| if the command line appeared to contain at least
one non-trivial request, but |FALSE| if it only asked for e.g. |-help|. In
general, the client should then exit with exit code 0 if this happens.

@ Here goes the reader. It works through the command line arguments, then
through the file if one has by that point been provided.

Note that |NO_CLSUB| is 0, and so evaluates to |FALSE|, but that this is
different from |NO_COMMAND_CLSUB|, which means that something substantive
was requested but that no subcommand was issued as part of it.

@d BOGUS_CLSN -12345678 /* bogus because guaranteed not to be a genuine switch ID */

=
typedef struct clf_reader_state {
	void *state;
	struct command_line_subcommand *subcommand_selected;
	void (*f)(int, int, text_stream *, void *);
	void (*g)(int, text_stream *, void *);
	int subs;
	int nrt;
	int counter;
} clf_reader_state;

int CommandLine::read(int argc, char **argv, void *state,
	void (*f)(int, int, text_stream *, void *), void (*g)(int, text_stream *, void *)) {
	clf_reader_state crs;
	crs.state = state; crs.subcommand_selected = CommandLine::get_empty_subcommand();
	crs.f = f; crs.g = g;
	crs.subs = FALSE; crs.nrt = 0; crs.counter = 0;
	CommandLine::read_array(&crs, argc, argv);
	CommandLine::read_file(&crs);
	if ((crs.subcommand_selected) &&
		(crs.subcommand_selected != CommandLine::get_empty_subcommand()))
		return crs.subcommand_selected->subcommand_id;
	if (crs.subs == FALSE) return NO_CLSUB;
	return NO_COMMAND_CLSUB;
}

void CommandLine::set_locale(int argc, char **argv) {
	for (int i=1; i<argc; i++) {
		char *p = argv[i];
		if ((strcmp(p, "-locale") == 0) && (i<argc-1))
			if (Locales::set_locales(argv[i+1]) == FALSE)
				Errors::fatal("unrecognised locale");
	}
}

void CommandLine::read_array(clf_reader_state *crs, int argc, char **argv) {
	for (int i=1; i<argc; i++) {
		int switched = FALSE;
		char *p = argv[i];
		while (p[0] == '-') { p++; switched = TRUE; } /* allow a doubled-dash as a single */
		TEMPORARY_TEXT(opt)
		Streams::write_locale_string(opt, p);
		TEMPORARY_TEXT(arg)
		if (i+1 < argc) Streams::write_locale_string(arg, argv[i+1]);
		if (switched) {
			int N = CommandLine::read_pair(crs, opt, arg);
			if (N == 0)
				Errors::fatal_with_text("unknown command line switch: -%S", opt);
			i += N - 1;
		} else {
			command_line_subcommand *found = NULL;
			if (crs->counter == 0) {
				command_line_subcommand *sub;
				LOOP_OVER(sub, command_line_subcommand)
					if ((Str::len(sub->command_name) > 0) && (Str::eq(opt, sub->command_name)))
						found = sub;
			}
			if (found) crs->subcommand_selected = found;
			else if (Str::eq(opt, I"help")) {
				command_line_subcommand *sub;
				LOOP_OVER(sub, command_line_subcommand)
					if (Str::eq(arg, sub->command_name))
						found = sub;
				if (found == NULL) WRITE_TO(STDOUT, "No such command as '%S'. General help:\n\n", arg);
				else i++;
				CommandLine::write_help(STDOUT, found);
			} else CommandLine::read_one(crs, opt);
		}
		DISCARD_TEXT(opt)
		DISCARD_TEXT(arg)
		crs->counter++;
	}
}

@ We can also read the "command line" from a file. The following variable
holds the filename to read from.

=
filename *command_line_file = NULL;
void CommandLine::also_read_file(filename *F) {
	command_line_file = F;
}

@ It's useful to log some of what we're reading here, so that people can tell
from the debugging log what switches were actually used. But since the log
might not exist as early as now, we have to record any log entries, and play
them back later (i.e., when the debugging log does exist).

=
linked_list *command_line_logs = NULL;
void CommandLine::record_log(text_stream *line) {
	if (command_line_logs == NULL)
		command_line_logs = NEW_LINKED_LIST(text_stream);
	ADD_TO_LINKED_LIST(line, text_stream, command_line_logs);
}

void CommandLine::play_back_log(void) {
	if (command_line_logs) {
		text_stream *line;
		LOOP_OVER_LINKED_LIST(line, text_stream, command_line_logs)
			LOG("%S\n", line);
	}
}

@ White space at start and end of lines is ignored; blank lines and those
beginning with a |#| are ignored (but a # following other content does not
mean a comment, so don't use trailing comments on lines); each line must
either be a single switch like |-no-service| or a pair like |-connect tower11|.
Shell conventions on quoting are not used, but the line |-greet Fred Smith|
is equivalent to |-greet 'Fred Smith'| on the command line, so there's no
problem with internal space characters in arguments.

=
void CommandLine::read_file(clf_reader_state *crs) {
	text_stream *logline = Str::new();
	WRITE_TO(logline, "Reading further switches from file: %f", command_line_file);
	CommandLine::record_log(logline);
	if (command_line_file)
		TextFiles::read(command_line_file, FALSE,
			NULL, FALSE, CommandLine::read_file_helper, NULL, (void *) crs);
	command_line_file = NULL;
	text_stream *lastline = Str::new();
	WRITE_TO(lastline, "Completed expert settings file");
	CommandLine::record_log(lastline);
}
void CommandLine::read_file_helper(text_stream *text, text_file_position *tfp, void *state) {
	clf_reader_state *crs = (clf_reader_state *) state;
	match_results mr = Regexp::create_mr();
	if ((Str::is_whitespace(text)) || (Regexp::match(&mr, text, U" *#%c*"))) {
		;
	} else {
		text_stream *logline = Str::new();
		WRITE_TO(logline, "line %d: %S", tfp->line_count, text);
		CommandLine::record_log(logline);
		if (Regexp::match(&mr, text, U" *-*(%C+) (%c+?) *")) {
			int N = CommandLine::read_pair(crs, mr.exp[0], mr.exp[1]);
			if (N == 0)
				Errors::fatal_with_text("unknown command line switch: -%S", mr.exp[0]);
			if (N == 1)
				Errors::fatal_with_text("command line switch does not take value: -%S", mr.exp[0]);
			crs->counter += 2;
		} else if (Regexp::match(&mr, text, U" *-*(%C+) *")) {
			int N = CommandLine::read_pair(crs, mr.exp[0], NULL);
			if (N == 0)
				Errors::fatal_with_text("unknown command line switch: -%S", mr.exp[0]);
			if (N == 2)
				Errors::fatal_with_text("command line switch requires value: -%S", mr.exp[0]);
		} else {
			Errors::in_text_file("illegible line in expert settings file", tfp);
			WRITE_TO(STDERR, "'%S'\n", text);
			crs->counter += 1;
		}
	}
	Regexp::dispose_of(&mr);
}

void CommandLine::read_one(clf_reader_state *crs, text_stream *opt) {
	(*(crs->g))(crs->nrt++, opt, crs->state);
	crs->subs = TRUE;
}

@ We also allow |-setting=X| as equivalent to |-setting X|.

=
int CommandLine::read_pair(clf_reader_state *crs, text_stream *opt, text_stream *arg) {
	TEMPORARY_TEXT(opt_p)
	TEMPORARY_TEXT(opt_val)
	Str::copy(opt_p, opt);
	int N = BOGUS_CLSN;
	match_results mr = Regexp::create_mr();
	if ((Regexp::match(&mr, opt, U"(%c+)=(%d+)")) ||
		(Regexp::match(&mr, opt, U"(%c+)=(-%d+)"))) {
		N = Str::atoi(mr.exp[1], 0);
		Str::copy(opt_p, mr.exp[0]);
		Str::copy(opt_val, mr.exp[1]);
	} else if (Regexp::match(&mr, opt, U"(%c+)=(%c*)")) {
		Str::copy(opt_p, mr.exp[0]);
		Str::copy(opt_val, mr.exp[1]);
	}
	int rv = CommandLine::read_pair_p(crs->subcommand_selected, opt_p, opt_val, N, arg, crs->state, crs->f, &(crs->subs));
	DISCARD_TEXT(opt_p)
	DISCARD_TEXT(opt_val)
	return rv;
}

@ So at this point we have definitely found what looks like a switch:

=
int CommandLine::read_pair_p(command_line_subcommand *sub, text_stream *opt, text_stream *opt_val, int N,
	text_stream *arg, void *state,
	void (*f)(int, int, text_stream *, void *), int *substantive) {
	command_line_switch *cls = CommandLine::find_cls(sub, opt);
	if (cls == NULL) {
		if (sub) cls = CommandLine::find_cls(NULL, opt);
		if ((cls == NULL) || (cls->switch_group != FOUNDATION_CLSG)) return 0;
	}
	if ((N == BOGUS_CLSN) && (cls->form == NUMERICAL_CLSF)) {
		Errors::fatal_with_text("no value N given for -%S=N", opt);
		return cls->valency;
	}
	if ((N != BOGUS_CLSN) && (cls->form != NUMERICAL_CLSF)) {
		Errors::fatal_with_text("this is not a numerical setting: -%S", opt);
		return cls->valency;
	}
	if (cls->valency > 1) {
		if (Str::len(arg) == 0) {
			Errors::fatal_with_text("no argument X for -%S X", opt);
			return cls->valency;
		}
	}
	int innocuous = FALSE;
	@<Take action on what is now definitely a switch@>;
	if ((innocuous == FALSE) && (substantive)) *substantive = TRUE;
	return cls->valency;
}

@ The common set of switches declared by Foundation are all handled here;
all other switches are delegated to the client's callback function |f|.

@<Take action on what is now definitely a switch@> =
	switch (cls->switch_id) {
		case CRASH_CLSW:
			if (cls->form == BOOLEAN_ON_CLSF) {
				Errors::enter_debugger_mode(); innocuous = TRUE;
			}
			break;
		case LOG_CLSW: @<Parse debugging log inclusion@>; innocuous = TRUE; break;
		case VERSION_CLSW: {
			PRINT("[[Title]]");
			char *svn = "[[Semantic Version Number]]";
			if (svn[0]) PRINT(" version %s", svn);
			char *vname = "[[Version Name]]";
			if (vname[0]) PRINT(" '%s'", vname);
			char *d = "[[Build Date]]";
			if (d[0]) PRINT(" (%s)", d);
			PRINT("\n");
			innocuous = TRUE; break;
		}
		case HELP_CLSW: CommandLine::write_help(STDOUT, NULL); innocuous = TRUE; break;
		case FIXTIME_CLSW: 
			if (cls->form == BOOLEAN_ON_CLSF) Time::fix();
			break;
		case AT_CLSW: Pathnames::set_installation_path(Pathnames::from_text(arg)); break;
		case LOCALE_CLSW: break; /* because it was done earlier */
		default:
			if (f) {
				int par = -1;
				switch (cls->form) {
					case BOOLEAN_ON_CLSF: par = TRUE; break;
					case BOOLEAN_OFF_CLSF: par = FALSE; break;
					case NUMERICAL_CLSF: par = N; break;
					case TEXTUAL_CLSF: arg = opt_val; break;
				}
				if (cls->valency == 1) (*f)(cls->switch_id, par, arg, state);
				else (*f)(cls->switch_id, par, arg, state);
			}
			break;
	}

@<Parse debugging log inclusion@> =
	if (Log::get_debug_log_filename() == NULL) {
		TEMPORARY_TEXT(itn)
		WRITE_TO(itn, "%s", PROGRAM_NAME);
		filename *F = Filenames::in(Pathnames::from_text(itn), I"debug-log.txt");
		DISCARD_TEXT(itn)
		Log::set_debug_log_filename(F);
	}
	Log::open();
	Log::set_aspect_from_command_line(arg, TRUE);

@h Help text.
That just leaves the following, which implements the |-help| switch. It
alphabetically sorts the switches, and prints out a list of them as grouped,
with ungrouped switches as the top paragraph and Foundation switches as the
bottom one. (Those are the dull ones.)

If a header text has been declared, that appears above the list. It's usually
a brief description of the tool's name and purpose.

=
void CommandLine::write_help(OUTPUT_STREAM, command_line_subcommand *help_on) {
	if (help_on == NULL) help_on = CommandLine::get_empty_subcommand();
	if (help_on != CommandLine::get_empty_subcommand())
		WRITE("%s %S\n\n", PROGRAM_NAME, help_on->command_name);
	if (Str::len(help_on->heading) > 0)
		WRITE("%S\n\n", help_on->heading);
	if (help_on == CommandLine::get_empty_subcommand())
		@<List the subcommands@>
	@<Help on available switches@>;
}

@<List the subcommands@> =
	int NS = 0;
	command_line_subcommand *sub;
	LOOP_OVER(sub, command_line_subcommand)
		if (sub != CommandLine::get_empty_subcommand()) {
			NS++;
			if (NS == 1) {
				WRITE("The following subcommands are available:\n\n");
				INDENT;
			}
			WRITE("%s %S\n", PROGRAM_NAME, sub->command_name);
		}
	if (NS > 0) {
		OUTDENT;
		WRITE("\n");
		WRITE("Use '%s help COMMAND' for more on each command.\n\n", PROGRAM_NAME);
		WRITE("The following options are always available:\n\n");
	}

@<Help on available switches@> =
	command_line_switch *cls;
	int max = 0, N = 0;
	LOOP_OVER_LINKED_LIST(cls, command_line_switch, help_on->cls_list) {
		int L = Str::len(cls->switch_name);
		if (L > max) max = L;
		N++;
	}
	if (help_on != CommandLine::get_empty_subcommand())
		LOOP_OVER_LINKED_LIST(cls, command_line_switch, CommandLine::get_empty_subcommand()->cls_list)
			if (cls->switch_group == FOUNDATION_CLSG) {
				int L = Str::len(cls->switch_name);
				if (L > max) max = L;
				N++;
			}
	if (N > 0) {
		command_line_switch **sorted_table =
			Memory::calloc(N, (int) sizeof(command_line_switch *), ARRAY_SORTING_MREASON);
		int i=0;
		LOOP_OVER_LINKED_LIST(cls, command_line_switch, help_on->cls_list)
			sorted_table[i++] = cls;
		if (help_on != CommandLine::get_empty_subcommand())
			LOOP_OVER_LINKED_LIST(cls, command_line_switch, CommandLine::get_empty_subcommand()->cls_list)
				if (cls->switch_group == FOUNDATION_CLSG)
					sorted_table[i++] = cls;
		qsort(sorted_table, (size_t) N, sizeof(command_line_switch *), CommandLine::compare_names);
	
		int filter = NO_CLSG, new_para_needed = FALSE;
		@<Show options in alphabetical order@>;
		for (filter = NO_CLSG; filter<NO_DEFINED_CLSG_VALUES; filter++)
			if ((filter != NO_CLSG) && (filter != FOUNDATION_CLSG))
				@<Show options in alphabetical order@>;
		filter = FOUNDATION_CLSG;
		@<Show options in alphabetical order@>;	
	
		Memory::I7_free(sorted_table, ARRAY_SORTING_MREASON, N*((int) sizeof(command_line_switch *)));
	}

@<Show options in alphabetical order@> =
	if (new_para_needed) {
		WRITE("\n");
		new_para_needed = FALSE;
	}
	for (int i=0; i<N; i++) {
		command_line_switch *cls = sorted_table[i];
		if (cls->switch_group != filter) continue;
		if ((cls->form == BOOLEAN_OFF_CLSF) || (cls->form == BOOLEAN_ON_CLSF)) {
			if (cls->active_by_default) continue;
		}
		text_stream *label = switch_group_names[filter];
		if (new_para_needed == FALSE) {
			if (Str::len(label) > 0) WRITE("%S:\n", label);
			new_para_needed = TRUE;
		}
		TEMPORARY_TEXT(line)
		if (Str::len(label) > 0) WRITE_TO(line, "  ");
		WRITE_TO(line, "-%S", cls->switch_name);
		if (cls->form == NUMERICAL_CLSF) WRITE_TO(line, "=N");
		if (cls->form == TEXTUAL_CLSF) WRITE_TO(line, "=X");
		if (cls->valency > 1) WRITE_TO(line, " X");
		while (Str::len(line) < max+7) WRITE_TO(line, " ");
		WRITE_TO(line, "%S", cls->help_text);
		if (cls->form == BOOLEAN_ON_CLSF)
			WRITE_TO(line, " (default is -no-%S)", cls->switch_name);
		if (cls->form == BOOLEAN_OFF_CLSF)
			WRITE_TO(line, " (default is -%S)", cls->negates->switch_name);
		WRITE("%S\n", line);
		DISCARD_TEXT(line)
	}

@ =
int CommandLine::compare_names(const void *ent1, const void *ent2) {
	text_stream *tx1 = (*((const command_line_switch **) ent1))->switch_sort_name;
	text_stream *tx2 = (*((const command_line_switch **) ent2))->switch_sort_name;
	return Str::cmp_insensitive(tx1, tx2);
}
