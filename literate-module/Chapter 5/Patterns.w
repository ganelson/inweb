[Patterns::] Patterns.

Managing weave patterns, which are bundled configuration settings for weaving.

@h Reading in.
Patterns are stored as directories in the file system, and are identified by
names such as |HTML|. Within those directories, though, the file |pattern.inweb|
contains a WCL file which is parsed to give details, and those details are
stored in instances of the following:

=
typedef struct ls_pattern {
	struct wcl_declaration *declaration;
	struct text_stream *pattern_name; /* such as |HTML| */
	struct pathname *pattern_location; /* the directory */
	struct text_stream *based_on_name; /* inherit from which other pattern? */

	struct weave_format *pattern_format; /* such as |DVI|: the desired final format */
	struct linked_list *plugins; /* of |weave_plugin|: any extras needed */
	struct linked_list *colour_schemes; /* of |colour_scheme|: any extras needed */

	struct text_stream *mathematics_plugin; /* name only, not a |ls_pattern *| */
	struct text_stream *footnotes_plugin; /* name only, not a |ls_pattern *| */

	struct text_stream *initial_extension; /* filename extension, that is */
	struct linked_list *post_commands; /* of |text_stream| */
	struct linked_list *blocked_templates; /* of |text_stream| */

	struct linked_list *asset_rules; /* of |asset_rule| */
	int show_abbrevs; /* show section range abbreviations in the weave? */
	int number_sections; /* insert section numbers into the weave? */
	struct text_stream *default_range; /* for example, |sections| */

	struct linked_list *bibliographic_settings; /* of |ls_pattern_pair| */
	
	int commands;
	int name_command_given;
	CLASS_DEFINITION
} ls_pattern;

typedef struct ls_pattern_pair {
	struct text_stream *key;
	struct text_stream *value;
	CLASS_DEFINITION
} ls_pattern_pair;

@ When a given web needs a pattern with a given name, this is where it comes.

=
ls_pattern *Patterns::find(wcl_declaration *D, text_stream *name) {
	wcl_declaration *R = WCL::resolve_resource(D, PATTERN_WCLTYPE, name);
	if (R == NULL) Errors::fatal_with_text("could not find weave pattern '%S'", name);
	return RETRIEVE_POINTER_ls_pattern(R->object_declared);
}

void Patterns::impose(ls_web *W, ls_pattern *wp) {
	ls_pattern *basis = Patterns::basis(W->declaration, wp);
	if (basis) Patterns::impose(W, basis);
	ls_pattern_pair *pair;
	LOOP_OVER_LINKED_LIST(pair, ls_pattern_pair, wp->bibliographic_settings) {
		Bibliographic::set_datum(W, pair->key, pair->value);
	}
}

@

=
wcl_declaration *Patterns::parse_directory(pathname *P) {
	wcl_declaration *M = WCL::new(MISCELLANY_WCLTYPE);
	M->associated_path = P;
	scan_directory *D = Directories::open(P);
	if (D) {
		TEMPORARY_TEXT(leafname)
		while (Directories::next(D, leafname)) {
			if (Platform::is_folder_separator(Str::get_last_char(leafname))) {
				TEMPORARY_TEXT(name)
				WRITE_TO(name, "%S", leafname);
				Str::delete_last_character(name);
				pathname *Q = Pathnames::down(P, name);
				filename *pattern_file = Filenames::in(Q, I"pattern.inweb");
				if (TextFiles::exists(pattern_file) == FALSE) {
					pattern_file = Filenames::in(Q, I"pattern.txt");
					if (TextFiles::exists(pattern_file) == FALSE)
						continue;
				}
				wcl_declaration *D = WCL::read_just_one(pattern_file, PATTERN_WCLTYPE);
				if (D) WCL::place_within(D, M);
				DISCARD_TEXT(name)
			}
		}
		DISCARD_TEXT(leafname)
		Directories::close(D);
	}
	return M;
}

@ Pattern files are WCL:

=
void Patterns::parse_declaration(wcl_declaration *D) {
	ls_pattern *wp = CREATE(ls_pattern);
	@<Initialise the pattern structure@>;
	@<Read in the pattern file@>;
}

@<Initialise the pattern structure@> =
	wp->declaration = D;
	wp->pattern_format = NULL;
	wp->pattern_name = NULL;
	wp->pattern_location = NULL;
	wp->plugins = NEW_LINKED_LIST(weave_plugin);
	wp->colour_schemes = NEW_LINKED_LIST(colour_scheme);
	wp->based_on_name = NULL;
	wp->asset_rules = Assets::new_asset_rules_list();
	wp->footnotes_plugin = NULL;
	wp->mathematics_plugin = NULL;
	wp->default_range = NULL;
	wp->initial_extension = NULL;
	wp->post_commands = NEW_LINKED_LIST(text_stream);
	wp->blocked_templates = NEW_LINKED_LIST(text_stream);
	wp->bibliographic_settings = NEW_LINKED_LIST(ls_pattern_pair);
	wp->commands = 0;
	wp->name_command_given = FALSE;

@<Read in the pattern file@> =
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		Patterns::scan_pattern_line(line, &tfp, (void *) wp);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	D->object_declared = STORE_POINTER_ls_pattern(wp);
	if (wp->name_command_given == FALSE)
		Errors::fatal("pattern did not name itself at the top");
	wp->pattern_location = Filenames::up(D->associated_file);
	if (WCL::check_name(D, wp->pattern_name) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "pattern has two different names, '%S' and '%S'",
			D->name, wp->pattern_name);
		WCL::error(D, &(D->declaration_position), msg);
		DISCARD_TEXT(msg)
	}
	TEMPORARY_TEXT(name)
	WRITE_TO(name, "%S", Pathnames::directory_name(wp->pattern_location));
	if (Str::ne_insensitive(name, wp->pattern_name)) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "pattern has two different names, '%S' and '%S'",
			name, wp->pattern_name);
		WCL::error(D, &(D->declaration_position), msg);
		DISCARD_TEXT(msg)
	}
	DISCARD_TEXT(name)

@ =
int Patterns::html_based(wcl_declaration *D, ls_pattern *wp) {
	while (wp) {
		if (Str::eq_insensitive(wp->pattern_name, I"HTML")) return TRUE;
		wp = Patterns::basis(D, wp);
	}
	return FALSE;
}

void Patterns::resolve_declaration(wcl_declaration *D) {
}

weave_format *Patterns::get_format(ls_web *W, ls_pattern *wp) {
	if (wp == NULL) return NULL;
	if (wp->pattern_format == NULL) {
		ls_pattern *basis = Patterns::basis(W->declaration, wp);
		if (basis) return Patterns::get_format(W, basis);
	}
	return wp->pattern_format;
}

text_stream *Patterns::get_default_range(ls_web *W, ls_pattern *wp) {
	if (wp == NULL) return I"0";
	if (Str::len(wp->default_range) == 0) {
		ls_pattern *basis = Patterns::basis(W->declaration, wp);
		if (basis) return Patterns::get_default_range(W, basis);
		return I"0";
	}
	return wp->default_range;
}

text_stream *Patterns::get_mathematics_plugin(ls_web *W, ls_pattern *wp) {
	if (wp == NULL) return NULL;
	if (Str::len(wp->mathematics_plugin) == 0) {
		ls_pattern *basis = Patterns::basis(W->declaration, wp);
		if (basis) return Patterns::get_mathematics_plugin(W, basis);
	}
	return wp->mathematics_plugin;
}

text_stream *Patterns::get_footnotes_plugin(ls_web *W, ls_pattern *wp) {
	if (wp == NULL) return NULL;
	if (Str::len(wp->footnotes_plugin) == 0) {
		ls_pattern *basis = Patterns::basis(W->declaration, wp);
		if (basis) return Patterns::get_footnotes_plugin(W, basis);
	}
	return wp->footnotes_plugin;
}

ls_pattern *Patterns::basis(wcl_declaration *D, ls_pattern *wp) {
	if ((wp) && (Str::len(wp->based_on_name) > 0))
		return Patterns::find(D, wp->based_on_name);
	return NULL;
}

@ The Foundation module provides a standard way to scan text files line by
line, and this is used to send each line in the |pattern.txt| file to the
following routine:

=
void Patterns::scan_pattern_line(text_stream *line, text_file_position *tfp, void *X) {
	ls_pattern *wp = (ls_pattern *) X;

	Str::trim_white_space(line); /* ignore trailing space */
	if (Str::len(line) == 0) return; /* ignore blank lines */
	if (Str::get_first_char(line) == '#') return; /* lines opening with |#| are comments */

	wp->commands++;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%c+) *: *(%c+?)")) {
		text_stream *key = mr.exp[0], *value = Str::duplicate(mr.exp[1]);
		if ((Str::eq_insensitive(key, I"name")) && (wp->commands == 1)) {
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, value, U"(%c+?) based on (%c+)")) {
				wp->pattern_name = Str::duplicate(mr2.exp[0]);
				wp->based_on_name = Str::duplicate(mr2.exp[1]);
			} else {
				wp->pattern_name = Str::duplicate(value);
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
			wp->pattern_format = WeavingFormats::find_by_name(value);
		} else if (Str::eq_insensitive(key, I"default range")) {
			wp->default_range = Str::duplicate(value);
		} else if (Str::eq_insensitive(key, I"initial extension")) {
			wp->initial_extension = Str::duplicate(value);
		} else if (Str::eq_insensitive(key, I"mathematics plugin")) {
			wp->mathematics_plugin = Patterns::plugin_name(value, tfp);
		} else if (Str::eq_insensitive(key, I"footnotes plugin")) {
			wp->footnotes_plugin = Patterns::plugin_name(value, tfp);
		} else if (Str::eq_insensitive(key, I"block template")) {
			ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, wp->blocked_templates);
		} else if (Str::eq_insensitive(key, I"command")) {
			ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, wp->post_commands);
		} else if (Str::eq_insensitive(key, I"bibliographic data")) {
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, value, U"(%c+?) = (%c+)")) {
				ls_pattern_pair *pair = CREATE(ls_pattern_pair);
				pair->key = Str::duplicate(mr2.exp[0]);
				pair->value = Str::duplicate(mr2.exp[1]);
				ADD_TO_LINKED_LIST(pair, ls_pattern_pair, wp->bibliographic_settings);
			} else {
				Errors::in_text_file("syntax is 'bibliographic data: X = Y'", tfp);
			}
			Regexp::dispose_of(&mr2);
		} else if (Str::eq_insensitive(key, I"assets")) {
			match_results mr2 = Regexp::create_mr();
			if (Regexp::match(&mr2, value, U"(.%C+?) (%c+)")) {
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
	if (Regexp::match(&mr, arg, U"(%i+)")) {
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
void Patterns::post_process(ls_pattern *pattern, weave_order *wv) {
	text_stream *T;
	LOOP_OVER_LINKED_LIST(T, text_stream, pattern->post_commands) {
		filename *last_F = NULL;
		TEMPORARY_TEXT(cmd)
		for (int i=0; i<Str::len(T); i++) {
			if (Str::includes_at(T, i, I"WOVENPATH")) {
				Shell::quote_path(cmd, Filenames::up(wv->weave_to));
				i += 8;
			} else if (Str::includes_at(T, i, I"WOVEN")) {
				filename *W = wv->weave_to;
				i += 5;
				if (Str::get_at(T, i) == '.') {
					i++;
					TEMPORARY_TEXT(ext)
					while (Characters::isalpha(Str::get_at(T, i)))
						PUT_TO(ext,Str::get_at(T, i++));
					W = Filenames::set_extension(W, ext);
					DISCARD_TEXT(ext)
				}
				Shell::quote_file(cmd, W);
				last_F = W;
				i--;
			} else PUT_TO(cmd, Str::get_at(T, i));
		}
		if ((Str::includes_at(cmd, 0, I"PROCESS ")) && (last_F)) {
			TeXUtilities::post_process_weave(wv, last_F);
		} else {
			if (wv->reportage) PRINT("(%S)\n", cmd);
			int rv = Shell::run(cmd);
			if (rv != 0) WRITE_TO(STDERR, "warning: post-processing command failed\n");
		}
		DISCARD_TEXT(cmd)
	}
}

@h Obtaining files.
Patterns provide place template files, such as |template-body.html|, in
their root directories.

Note that if you're rash enough to set up a cycle of patterns inheriting
from each other then this routine will lock up into an infinite loop.

=
filename *Patterns::find_template(ls_web *W, ls_pattern *pattern, text_stream *leafname) {
	for (ls_pattern *wp = pattern; wp; wp = Patterns::basis(W->declaration, wp)) {
		text_stream *T;
		LOOP_OVER_LINKED_LIST(T, text_stream, pattern->blocked_templates)
			if (Str::eq_insensitive(T, leafname))
				return NULL;
		filename *F = Filenames::in(wp->pattern_location, leafname);
		if (TextFiles::exists(F)) return F;
	}
	return NULL;
}

@ Similarly, but looking in an intermediate directory:

=
filename *Patterns::find_file_in_subdirectory(ls_web *W, ls_pattern *pattern,
	text_stream *dirname, text_stream *leafname) {
	for (ls_pattern *wp = pattern; wp; wp = Patterns::basis(W->declaration, wp)) {
		pathname *P = Pathnames::down(wp->pattern_location, dirname);
		filename *F = Filenames::in(P, leafname);
		if (TextFiles::exists(F)) return F;
	}
	return NULL;
}

@ =
void Patterns::include_plugins(OUTPUT_STREAM, ls_web *W, ls_pattern *pattern,
	filename *from, weave_reporting *R, ls_colony *context) {
	for (ls_pattern *p = pattern; p; p = Patterns::basis(W->declaration, p)) {
		weave_plugin *wp;
		LOOP_OVER_LINKED_LIST(wp, weave_plugin, p->plugins)
			Assets::include_plugin(OUT, W, wp, pattern, from, R, context);
		colour_scheme *cs;
		LOOP_OVER_LINKED_LIST(cs, colour_scheme, p->colour_schemes)
			Assets::include_colour_scheme(OUT, W, cs, pattern, from, R, context);
	}
}
