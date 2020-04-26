[Patterns::] Patterns.

Managing weave patterns, which are bundled configuration settings for weaving.

@h Reading in.
Patterns are stored as directories in the file system, and are identified by
names such as |HTML|. On request, we need to find the directory corresponding
to such a name, and to read it in. This structure holds the result:

=
typedef struct weave_pattern {
	struct text_stream *pattern_name; /* such as |HTML| */
	struct pathname *pattern_location; /* the directory */
	struct weave_pattern *based_on; /* inherit from which other pattern? */

	struct weave_format *pattern_format; /* such as |DVI|: the desired final format */
	struct linked_list *plugins; /* of |weave_plugin|: any extras needed */
	struct linked_list *colour_schemes; /* of |colour_scheme|: any extras needed */

	struct text_stream *mathematics_plugin; /* name only, not a |weave_pattern *| */
	struct text_stream *footnotes_plugin; /* name only, not a |weave_pattern *| */

	struct text_stream *initial_extension; /* filename extension, that is */
	struct linked_list *post_commands; /* of |text_stream| */

	struct linked_list *asset_rules; /* of |asset_rule| */
	int show_abbrevs; /* show section range abbreviations in the weave? */
	int number_sections; /* insert section numbers into the weave? */
	struct text_stream *default_range; /* for example, |sections| */

	struct web *patterned_for; /* the web which caused this to be read in */
	
	int commands;
	int name_command_given;
	MEMORY_MANAGEMENT
} weave_pattern;

@ When a given web needs a pattern with a given name, this is where it comes.

=
weave_pattern *Patterns::find(web *W, text_stream *name) {
	filename *pattern_file = NULL;
	weave_pattern *wp = CREATE(weave_pattern);
	@<Initialise the pattern structure@>;
	@<Locate the pattern directory@>;
	@<Read in the pattern.txt file@>;
	return wp;
}

@<Initialise the pattern structure@> =
	wp->pattern_name = Str::duplicate(name);
	wp->pattern_location = NULL;
	wp->plugins = NEW_LINKED_LIST(weave_plugin);
	wp->colour_schemes = NEW_LINKED_LIST(colour_scheme);
	wp->based_on = NULL;
	wp->asset_rules = Assets::new_asset_rules_list();
	wp->patterned_for = W;
	wp->number_sections = FALSE;
	wp->footnotes_plugin = NULL;
	wp->mathematics_plugin = NULL;
	wp->default_range = Str::duplicate(I"0");
	wp->initial_extension = NULL;
	wp->post_commands = NEW_LINKED_LIST(text_stream);
	wp->commands = 0;
	wp->name_command_given = FALSE;

@<Locate the pattern directory@> =
	wp->pattern_location = NULL;
	pathname *CP = Colonies::patterns_path();
	if (CP) {
		wp->pattern_location = Pathnames::down(CP, name);
		pattern_file = Filenames::in(wp->pattern_location, I"pattern.txt");
		if (TextFiles::exists(pattern_file) == FALSE) wp->pattern_location = NULL;
	}
	if (wp->pattern_location == NULL) {
		wp->pattern_location = Pathnames::down(
			Pathnames::down(W->md->path_to_web, I"Patterns"), name);
		pattern_file = Filenames::in(wp->pattern_location, I"pattern.txt");
		if (TextFiles::exists(pattern_file) == FALSE) wp->pattern_location = NULL;
	}
	if (wp->pattern_location == NULL) {
		wp->pattern_location = Pathnames::down(
			path_to_inweb_patterns, name);
		pattern_file = Filenames::in(wp->pattern_location, I"pattern.txt");
		if (TextFiles::exists(pattern_file) == FALSE) wp->pattern_location = NULL;
	}
	if (wp->pattern_location == NULL)
		Errors::fatal_with_text("no such weave pattern as '%S'", name);

@<Read in the pattern.txt file@> =
	if (pattern_file)
		TextFiles::read(pattern_file, FALSE, "can't open pattern.txt file",
			TRUE, Patterns::scan_pattern_line, NULL, wp);
	if (wp->pattern_format == NULL)
		Errors::fatal_with_text("pattern did not specify a format", name);
	if (wp->name_command_given == FALSE)
		Errors::fatal_with_text("pattern did not name itself at the top", name);

@ The Foundation module provides a standard way to scan text files line by
line, and this is used to send each line in the |pattern.txt| file to the
following routine:

=
void Patterns::scan_pattern_line(text_stream *line, text_file_position *tfp, void *X) {
	weave_pattern *wp = (weave_pattern *) X;

	Str::trim_white_space(line); /* ignore trailing space */
	if (Str::len(line) == 0) return; /* ignore blank lines */
	if (Str::get_first_char(line) == '#') return; /* lines opening with |#| are comments */

	wp->commands++;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c+) *: *(%c+?)")) {
		text_stream *key = mr.exp[0], *value = Str::duplicate(mr.exp[1]);
		if ((Str::eq_insensitive(key, I"name")) && (wp->commands == 1)) {
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, value, L"(%c+?) based on (%c+)")) {
				if (Str::ne_insensitive(mr2.exp[0], wp->pattern_name)) {
					Errors::in_text_file("wrong pattern name", tfp);
				}
				wp->based_on = Patterns::find(wp->patterned_for, mr2.exp[1]);
				wp->pattern_format = wp->based_on->pattern_format;
				wp->number_sections = wp->based_on->number_sections;
				wp->default_range = Str::duplicate(wp->based_on->default_range);
				wp->mathematics_plugin = Str::duplicate(wp->based_on->mathematics_plugin);
				wp->footnotes_plugin = Str::duplicate(wp->based_on->footnotes_plugin);
			} else {
				if (Str::ne_insensitive(value, wp->pattern_name)) {
					Errors::in_text_file("wrong pattern name", tfp);
				}
			}
			Regexp::dispose_of(&mr2);
			wp->name_command_given = TRUE;
		} else if (Str::eq_insensitive(key, I"plugin")) {
			text_stream *name = Patterns::plugin_name(value, tfp);
			if (Str::len(name) > 0) {
				weave_plugin *plugin = Assets::new(name);
				ADD_TO_LINKED_LIST(plugin, weave_plugin, wp->plugins);
			}
		} else if (Str::eq_insensitive(key, I"format")) {
			wp->pattern_format = Formats::find_by_name(value);
		} else if (Str::eq_insensitive(key, I"number sections")) {
			wp->number_sections = Patterns::yes_or_no(value, tfp);
		} else if (Str::eq_insensitive(key, I"default range")) {
			wp->default_range = Str::duplicate(value);
		} else if (Str::eq_insensitive(key, I"initial extension")) {
			wp->initial_extension = Str::duplicate(value);
		} else if (Str::eq_insensitive(key, I"mathematics plugin")) {
			wp->mathematics_plugin = Patterns::plugin_name(value, tfp);
		} else if (Str::eq_insensitive(key, I"footnotes plugin")) {
			wp->footnotes_plugin = Patterns::plugin_name(value, tfp);
		} else if (Str::eq_insensitive(key, I"command")) {
			ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, wp->post_commands);
		} else if (Str::eq_insensitive(key, I"bibliographic data")) {
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, value, L"(%c+?) = (%c+)")) {
				Bibliographic::set_datum(wp->patterned_for->md, mr2.exp[0], mr2.exp[1]);
			} else {
				Errors::in_text_file("syntax is 'bibliographic data: X = Y'", tfp);
			}
			Regexp::dispose_of(&mr2);
		} else if (Str::eq_insensitive(key, I"assets")) {
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, value, L"(.%C+?) (%c+)")) {
				Assets::add_asset_rule(wp->asset_rules, mr2.exp[0], mr2.exp[1], tfp);
			} else {
				Errors::in_text_file("syntax is 'assets: .EXT COMMAND'", tfp);
			}
			Regexp::dispose_of(&mr2);
		} else {
			Errors::in_text_file("unrecognised pattern command", tfp);
		}
	} else {
		Errors::in_text_file("unrecognised pattern command", tfp);
	}
	Regexp::dispose_of(&mr);
}

@ =
int Patterns::yes_or_no(text_stream *arg, text_file_position *tfp) {
	if (Str::eq(arg, I"yes")) return TRUE;
	if (Str::eq(arg, I"no")) return FALSE;
	Errors::in_text_file("setting must be 'yes' or 'no'", tfp);
	return FALSE;
}

text_stream *Patterns::plugin_name(text_stream *arg, text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, arg, L"(%i+)")) {
		if (Str::eq_insensitive(arg, I"none")) return NULL;
	} else {
		Errors::in_text_file("plugin names must be single alphanumeric words", tfp);
		arg = NULL;
	}
	Regexp::dispose_of(&mr);
	return Str::duplicate(arg);
}

@h Post-processing.
In effect, a pattern can hold a shell script to run after each weave (subset)
completes.

=
void Patterns::post_process(weave_pattern *pattern, weave_order *wv) {
	text_stream *T;
	LOOP_OVER_LINKED_LIST(T, text_stream, pattern->post_commands) {
		filename *last_F = NULL;
		TEMPORARY_TEXT(cmd);
		for (int i=0; i<Str::len(T); i++) {
			if (Str::includes_at(T, i, I"WOVENPATH")) {
				Shell::quote_path(cmd, Filenames::up(wv->weave_to));
				i += 8;
			} else if (Str::includes_at(T, i, I"WOVEN")) {
				filename *W = wv->weave_to;
				i += 5;
				if (Str::get_at(T, i) == '.') {
					i++;
					TEMPORARY_TEXT(ext);
					while (Characters::isalpha(Str::get_at(T, i)))
						PUT_TO(ext,Str::get_at(T, i++));
					W = Filenames::set_extension(W, ext);
					DISCARD_TEXT(ext);
				}
				Shell::quote_file(cmd, W);
				last_F = W;
				i--;
			} else PUT_TO(cmd, Str::get_at(T, i));
		}
		if ((Str::includes_at(cmd, 0, I"PROCESS ")) && (last_F)) {
			TeXUtilities::post_process_weave(wv, last_F);
		} else {
			if (verbose_mode) PRINT("(%S)\n", cmd);
			int rv = Shell::run(cmd);
			if (rv != 0) Errors::fatal("post-processing command failed");
		}
		DISCARD_TEXT(cmd);
	}
}

@h Obtaining files.
Patterns provide place template files, such as |template-body.html|, in
their root directories.

Note that if you're rash enough to set up a cycle of patterns inheriting
from each other then this routine will lock up into an infinite loop.

=
filename *Patterns::find_template(weave_pattern *pattern, text_stream *leafname) {
	for (weave_pattern *wp = pattern; wp; wp = wp->based_on) {
		filename *F = Filenames::in(wp->pattern_location, leafname);
		if (TextFiles::exists(F)) return F;
	}
	return NULL;
}

@ Similarly, but looking in an intermediate directory:

=
filename *Patterns::find_file_in_subdirectory(weave_pattern *pattern,
	text_stream *dirname, text_stream *leafname) {
	for (weave_pattern *wp = pattern; wp; wp = wp->based_on) {
		pathname *P = Pathnames::down(wp->pattern_location, dirname);
		filename *F = Filenames::in(P, leafname);
		if (TextFiles::exists(F)) return F;
	}
	return NULL;
}

@ =
void Patterns::include_plugins(OUTPUT_STREAM, web *W, weave_pattern *pattern, filename *from) {
	for (weave_pattern *p = pattern; p; p = p->based_on) {
		weave_plugin *wp;
		LOOP_OVER_LINKED_LIST(wp, weave_plugin, p->plugins)
			Assets::include_plugin(OUT, W, wp, pattern, from);
		colour_scheme *cs;
		LOOP_OVER_LINKED_LIST(cs, colour_scheme, p->colour_schemes)
			Assets::include_colour_scheme(OUT, W, cs, pattern, from);
	}
}
