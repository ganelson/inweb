[CommandLine::] Command Line Arguments.

To parse the command line arguments with which inweb was called,
and to handle any errors it needs to issue.

@h Model.
Our scheme is that the command line syntax will contain an optional
series of dashed switches. Some switches appear alone, others must be
followed by an argument. Anything not part of the switches is termed
a "bareword". For example, in

	|-log no-memory-usage -fixtime jam marmalade|

there are two switches, |-log| taking an argument (it has valency 2
in the terminology below), |-fixtime| not (valency 1). There are
then two barewords, |jam| and |marmalade|.

For an example of all this in action, see Inweb, or see the basic
command-line switches created by Foundation itself in "Foundation".

@h Switches.
Each different switch available is stored in one of these structures.
Switches come in five sorts:

@e ACTION_CLSF from 1 /* does something */
@e BOOLEAN_ON_CLSF /* sets a flag true */
@e BOOLEAN_OFF_CLSF /* sets a flag false */
@e NUMERICAL_CLSF /* sets an integer to the given value */
@e TEXTUAL_CLSF /* sets text to the given value */

=
typedef struct command_line_switch {
	int switch_id;
	struct text_stream *switch_name; /* e.g., |no-verbose| */
	struct text_stream *switch_sort_name; /* e.g., |verbose| */
	struct text_stream *help_text;
	int valency; /* 1 for bare, 2 for one argument follows */
	int form; /* one of the |*_CLSF| values above */
	int foundation_switch; /* |TRUE| for the ones built in to every tool */
	struct command_line_switch *negates; /* relevant only for booleans */
	MEMORY_MANAGEMENT
} command_line_switch;

@ In case of a prodigious number of switches (ever tried typing |clang -help|?),
we'll hash the switch names into the following:

=
dictionary *cls_dictionary = NULL;

@ The client must declare all the switches her program will make use of, not
counting the standard set already declared by Foundation (such as |-help|).
A new |*_CLSW| value should be enumerated to be the ID referring to this
swtich, and then the client should call:

=
command_line_switch *CommandLine::declare_switch(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal) {
	return CommandLine::declare_switch_p(id,
		Str::new_from_wide_string(name_literal), val,
		Str::new_from_wide_string(help_literal));
}
command_line_switch *CommandLine::declare_switch_f(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal) {
	command_line_switch *cls =
		CommandLine::declare_switch_p(
			id, Str::new_from_wide_string(name_literal), val,
			Str::new_from_wide_string(help_literal));
	cls->foundation_switch = TRUE;
	return cls;
}
command_line_switch *CommandLine::declare_switch_p(int id,
	text_stream *name, int val, text_stream *help_literal) {
	if (cls_dictionary == NULL) cls_dictionary = Dictionaries::new(16, FALSE);
	command_line_switch *cls = CREATE(command_line_switch);
	cls->switch_name = name;
	@<Make the sorting name@>;
	cls->switch_id = id;
	cls->valency = val;
	cls->help_text = help_literal;
	cls->form = ACTION_CLSF;
	cls->negates = NULL;
	cls->foundation_switch = FALSE;
	Dictionaries::create(cls_dictionary, cls->switch_name);
	Dictionaries::write_value(cls_dictionary, cls->switch_name, cls);
	return cls;
}

@ When we alphabetically sort switches for the |-help| output, we want to
file, say, |-no-verbose| immediately after |-verbose|, not back in the N
section. So the sorting version of |no-verbose| is |verbose_|.

@<Make the sorting name@> =
	cls->switch_sort_name = Str::duplicate(name);
	if (Str::begins_with_wide_string(name, L"no-")) {
		Str::delete_n_characters(cls->switch_sort_name, 3);
		WRITE_TO(cls->switch_sort_name, "_");
	}

@ Booleans are automatically created in pairs, e.g., |-destroy-world| and
|-no-destroy-world|:

=
command_line_switch *CommandLine::declare_boolean_switch_p(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal, int fnd) {
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

	cls->foundation_switch = fnd;
	negated->foundation_switch = fnd;

	return cls;
}
command_line_switch *CommandLine::declare_boolean_switch(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal) {
	return CommandLine::declare_boolean_switch_p(id,
		name_literal, val, help_literal, FALSE);
}
command_line_switch *CommandLine::declare_boolean_switch_f(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal) {
	return CommandLine::declare_boolean_switch_p(id,
		name_literal, val, help_literal, TRUE);
}

void CommandLine::declare_numerical_switch(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal) {
	command_line_switch *cls =
		CommandLine::declare_switch(id, name_literal, val, help_literal);
	cls->form = NUMERICAL_CLSF;
}

void CommandLine::declare_textual_switch(int id,
	wchar_t *name_literal, int val, wchar_t *help_literal) {
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

This is all easier to demonstrate than explain. See Inweb for an example.

@d BOGUS_CLSN -12345678 /* bogus because guaranteed not to be a genuine switch ID */

=
int CommandLine::read(int argc, char **argv, void *state,
	void (*f)(int, int, text_stream *, void *), void (*g)(int, text_stream *, void *)) {
	int substantive = FALSE;
	for (int i=1, no_raw_tokens=0; i<argc; i++) {
		int switched = FALSE;
		char *p = argv[i];
		while (p[0] == '-') { p++; switched = TRUE; } /* allow a doubled-dash as a single */
		TEMPORARY_TEXT(opt);
		Streams::write_locale_string(opt, p);
		TEMPORARY_TEXT(arg);
		if (i+1 < argc) Streams::write_locale_string(arg, argv[i+1]);
		if (switched) {
			int N = CommandLine::read_pair(opt, arg, state, f, &substantive);
			if (N == 0)
				Errors::fatal_with_text("unknown command line switch: -%S", opt);
			i += N - 1;
		} else {
			(*g)(no_raw_tokens++, opt, state);
			substantive = TRUE;
		}
		DISCARD_TEXT(opt);
		DISCARD_TEXT(arg);
	}
	return substantive;
}

@ We also allow |-setting=X| as equivalent to |-setting X|.

=
int CommandLine::read_pair(text_stream *opt, text_stream *arg, void *state,
	void (*f)(int, int, text_stream *, void *), int *substantive) {
	TEMPORARY_TEXT(opt_p);
	TEMPORARY_TEXT(opt_val);
	Str::copy(opt_p, opt);
	int N = BOGUS_CLSN;
	match_results mr = Regexp::create_mr();
	if ((Regexp::match(&mr, opt, L"(%c+)=(%d+)")) ||
		(Regexp::match(&mr, opt, L"(%c+)=(-%d+)"))) {
		N = Str::atoi(mr.exp[1], 0);
		Str::copy(opt_p, mr.exp[0]);
		Str::copy(opt_val, mr.exp[1]);
	} else if (Regexp::match(&mr, opt, L"(%c+)=(%c*)")) {
		Str::copy(opt_p, mr.exp[0]);
		Str::copy(opt_val, mr.exp[1]);
	}
	int rv = CommandLine::read_pair_p(opt_p, opt_val, N, arg, state, f, substantive);
	DISCARD_TEXT(opt_p);
	DISCARD_TEXT(opt_val);
	return rv;
}

@ So at this point we have definitely found what looks like a switch:

=
int CommandLine::read_pair_p(text_stream *opt, text_stream *opt_val, int N,
	text_stream *arg, void *state,
	void (*f)(int, int, text_stream *, void *), int *substantive) {
	if (Dictionaries::find(cls_dictionary, opt) == NULL) return 0;
	command_line_switch *cls = Dictionaries::read_value(cls_dictionary, opt);
	if (cls == NULL) return 0;
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
		case CRASH_CLSW: Errors::enter_debugger_mode(); innocuous = TRUE; break;
		case LOG_CLSW: @<Parse debugging log inclusion@>; innocuous = TRUE; break;
		case VERSION_CLSW:
			PRINT("%s [[Version Number]] '[[Version Name]]' (build [[Build Number]] on [[Build Date]])\n", INTOOL_NAME);
			innocuous = TRUE; break;
		case HELP_CLSW: CommandLine::write_help(STDOUT); innocuous = TRUE; break;
		case FIXTIME_CLSW: Time::fix(); break;
		case AT_CLSW: Pathnames::set_installation_path(Pathnames::from_text(arg)); break;
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
		TEMPORARY_TEXT(itn);
		WRITE_TO(itn, "%s", INTOOL_NAME);
		filename *F = Filenames::in_folder(Pathnames::from_text(itn), I"debug-log.txt");
		DISCARD_TEXT(itn);
		Log::set_debug_log_filename(F);
	}
	Log::open();
	Log::set_aspect_from_command_line(arg, TRUE);

@h Help text.
That just leaves the following, which implements the |-help| switch. It
alphabetically sorts the switches, and prints out a list of them, except
that switches created by Foundation are in a separate bunch at the bottom.
(Those are the dull ones.) If a header text has been declared, that appears
at the top of the list. It's usually a brief description of the tool's
name and purpose.

=
text_stream *cls_heading = NULL;

void CommandLine::declare_heading(wchar_t *heading_text_literal) {
	cls_heading = Str::new_from_wide_string(heading_text_literal);
}

void CommandLine::write_help(OUTPUT_STREAM) {
	command_line_switch *cls;
	int max = 0, N = 0;
	LOOP_OVER(cls, command_line_switch) {
		int L = Str::len(cls->switch_name);
		if (L > max) max = L;
		N++;
	}
	command_line_switch **sorted_table =
		Memory::I7_calloc(N, (int) sizeof(command_line_switch *), CLS_SORTING_MREASON);
	int i=0; LOOP_OVER(cls, command_line_switch) sorted_table[i++] = cls;
	qsort(sorted_table, (size_t) N, sizeof(command_line_switch *), CommandLine::compare_names);

	if (Str::len(cls_heading) > 0) WRITE("%S\n", cls_heading);
	int filter = FALSE;
	@<Show options in alphabetical order@>;
	WRITE("\n");
	filter = TRUE;
	@<Show options in alphabetical order@>;
	Memory::I7_free(sorted_table, CLS_SORTING_MREASON, N*((int) sizeof(command_line_switch *)));
}

@<Show options in alphabetical order@> =
	for (int i=0; i<N; i++) {
		command_line_switch *cls = sorted_table[i];
		if (cls->foundation_switch != filter) continue;
		TEMPORARY_TEXT(line);
		WRITE_TO(line, "-%S", cls->switch_name);
		if (cls->form == NUMERICAL_CLSF) WRITE_TO(line, "=N");
		if (cls->form == TEXTUAL_CLSF) WRITE_TO(line, "=X");
		if (cls->valency > 1) WRITE_TO(line, " X");
		while (Str::len(line) < max+5) WRITE_TO(line, " ");
		WRITE_TO(line, "%S\n", cls->help_text);
		WRITE("%S", line);
		DISCARD_TEXT(line);
	}

@ =
int CommandLine::compare_names(const void *ent1, const void *ent2) {
	text_stream *tx1 = (*((const command_line_switch **) ent1))->switch_sort_name;
	text_stream *tx2 = (*((const command_line_switch **) ent2))->switch_sort_name;
	return Str::cmp_insensitive(tx1, tx2);
}
