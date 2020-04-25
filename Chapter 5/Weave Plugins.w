[WeavePlugins::] Weave Plugins.

Mainly for HTML, to add the necessary JavaScript for unusual requirements
such as equations or footnotes.

@h Creation.
At present, plugins are simply their names: Inweb knows as little as possible
about how they work. The model is just that a file being woven either does or
does not need a plugin of a given name: for example, if it uses maths notation,
it will likely need the |MathJax3| plugin.

=
typedef struct weave_plugin {
	struct text_stream *plugin_name;
	int last_included_in_round;
	MEMORY_MANAGEMENT
} weave_plugin;

@ =
weave_plugin *WeavePlugins::new(text_stream *name) {
	weave_plugin *wp;
	LOOP_OVER(wp, weave_plugin)
		if (Str::eq_insensitive(wp->plugin_name, name))
			return wp;
	wp = CREATE(weave_plugin);
	wp->plugin_name = Str::duplicate(name);
	wp->last_included_in_round = 0;
	return wp;
}

@ And almost the same can be said about colour schemes, except that these we
actually look for: they will be available to some patterns and not others.

=
typedef struct colour_scheme {
	struct text_stream *scheme_name;
	struct text_stream *prefix;
	struct filename *at;
	int last_included_in_round;
	MEMORY_MANAGEMENT
} colour_scheme;

@ =
colour_scheme *WeavePlugins::find_colour_scheme(weave_pattern *pattern,
	text_stream *name, text_stream *pre) {
	colour_scheme *cs;
	LOOP_OVER(cs, colour_scheme)
		if (Str::eq_insensitive(cs->scheme_name, name))
			return cs;
	TEMPORARY_TEXT(css);
	WRITE_TO(css, "%S.css", name);
	filename *F = Patterns::find_asset(pattern, I"Colouring", css);
	if (F == NULL) F = Patterns::find_asset(pattern, I"Coloring", css);
	DISCARD_TEXT(css);
	if (F == NULL) return NULL;
	cs = CREATE(colour_scheme);
	cs->scheme_name = Str::duplicate(name);
	cs->at = F;
	cs->prefix = Str::duplicate(pre);
	cs->last_included_in_round = 0;
	if (Str::len(pre) > 0) WRITE_TO(cs->prefix, "-");
	return cs;
}

int current_inclusion_round = 0;
void WeavePlugins::begin_inclusions(void) {
	current_inclusion_round++;
}

@ When a file is woven, then, the following function can add the plugins
necessary. If a plugin is called |X|, then we try to find |X.html| and
weave that into the page header; and we try to find |X.css|, weave an
inclusion of that, and also copy the file into the weave destination.

The fragment of HTML is compulsory; the CSS file, optional.

=
void WeavePlugins::include_plugin(OUTPUT_STREAM, web *W, weave_plugin *wp,
	weave_pattern *pattern, filename *from) {	
	if (wp->last_included_in_round == current_inclusion_round) return;
	wp->last_included_in_round = current_inclusion_round;
	pathname *AP = Colonies::assets_path();
	int html_mode = FALSE;
	if (Str::eq(pattern->pattern_format->format_name, I"HTML")) html_mode = TRUE;
	int finds = 0;
	TEMPORARY_TEXT(required);
	WRITE_TO(required, "%S.html", wp->plugin_name);
	dictionary *leaves_gathered = Dictionaries::new(128, TRUE);
	for (weave_pattern *p = pattern; p; p = p->based_on) {
		pathname *P = Pathnames::down(p->pattern_location, wp->plugin_name);
		scan_directory *D = Directories::open(P);
		if (D) {
			TEMPORARY_TEXT(leafname);
			while (Directories::next(D, leafname)) {
				if ((Str::get_last_char(leafname) != FOLDER_SEPARATOR) &&
					(Str::get_first_char(leafname) != '.')) {
					if (Dictionaries::find(leaves_gathered, leafname) == NULL) {
						WRITE_TO(Dictionaries::create_text(leaves_gathered, leafname), "got this");
						filename *F = Filenames::in(P, leafname);
						if (Str::eq_insensitive(leafname, required)) {
							if (html_mode) {
								Collater::for_web_and_pattern(OUT,
									W, pattern, F, from);
							} else {
								@<Use shell scripting to copy the file over@>;
							}
						} else {
							if (html_mode) {
								TEMPORARY_TEXT(ext);
								Filenames::write_extension(ext, F);
								if (Str::eq_insensitive(ext, I".css")) {
									WeavePlugins::include_CSS_file(OUT, W, F, leafname, NULL, pattern, from);
								} else if (Str::eq_insensitive(ext, I".js")) {
									TEMPORARY_TEXT(url);
									if (AP) Pathnames::relative_URL(url, Filenames::up(from), AP);
									WRITE_TO(url, "%S", leafname);
									WRITE("<script src=\"%S\"></script>\n", url);
									DISCARD_TEXT(url);
									@<Use shell scripting to copy the file over@>;
								} else {
									@<Use shell scripting to copy the file over@>;
								}
								DISCARD_TEXT(ext);
							} else {
								TEMPORARY_TEXT(ext);
								Filenames::write_extension(ext, F);
								if (Str::eq_insensitive(ext, I".tex")) {
									WeavePlugins::include_TeX_macros(OUT, W, F, leafname, NULL, pattern, from);
								} else {
									@<Use shell scripting to copy the file over@>;
								}
								DISCARD_TEXT(ext);
							}
						}
						finds++;
					}
				}
			}
			DISCARD_TEXT(leafname);
			Directories::close(D);	
		}
	}
	if (finds == 0) {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "The plugin '%S' is not supported", wp->plugin_name);
		Main::error_in_web(err, NULL);
	}
	DISCARD_TEXT(required);
}

@<Use shell scripting to copy the file over@> =
	Patterns::copy_file_into_weave(W, F, AP, NULL);
	if (W->as_ebook) {
		filename *rel = Filenames::in(NULL, leafname);
		Epub::note_image(W->as_ebook, rel);
	}

@ =
void WeavePlugins::include_colour_scheme(OUTPUT_STREAM, web *W, colour_scheme *cs,
	weave_pattern *pattern, filename *from) {	
	if (cs->last_included_in_round == current_inclusion_round) return;
	cs->last_included_in_round = current_inclusion_round;
	if (Str::eq(pattern->pattern_format->format_name, I"HTML")) {
		TEMPORARY_TEXT(css);
		WRITE_TO(css, "%S.css", cs->scheme_name);
		filename *F = Patterns::find_asset(pattern, I"Colouring", css);
		if (F == NULL) F = Patterns::find_asset(pattern, I"Coloring", css);
		if (F == NULL) {
			TEMPORARY_TEXT(err);
			WRITE_TO(err, "No CSS file for the colour scheme '%S' can be found",
				cs->scheme_name);
			Main::error_in_web(err, NULL);
			DISCARD_TEXT(err);
		} else {
			WeavePlugins::include_CSS_file(OUT, W, F, css, cs->prefix, pattern, from);
		}
		DISCARD_TEXT(css);
	}
}

void WeavePlugins::include_CSS_file(OUTPUT_STREAM, web *W, filename *F, text_stream *css,
	text_stream *trans, weave_pattern *pattern, filename *from) {
	if (pattern->embed_CSS) {
		WRITE("<style type=\"text/css\">\n");
		css_file_transformation cft;
		cft.OUT = OUT;
		cft.trans = trans;
		TextFiles::read(F, FALSE, "can't open CSS file", TRUE,
		Patterns::transform_CSS, NULL, (void *) &cft);
		WRITE("</style>\n");
	} else {
		pathname *AP = Colonies::assets_path();
		TEMPORARY_TEXT(url);
		if (AP) Pathnames::relative_URL(url, Filenames::up(from), AP);
		WRITE_TO(url, "%S", css);
		WRITE("<link href=\"%S\" rel=\"stylesheet\" rev=\"stylesheet\" type=\"text/css\">\n", url);
		DISCARD_TEXT(url);
		Patterns::copy_file_into_weave(W, F, AP, trans);
		if (W->as_ebook) {
			filename *rel = Filenames::in(NULL, css);
			Epub::note_image(W->as_ebook, rel);
		}
	}
}

void WeavePlugins::include_TeX_macros(OUTPUT_STREAM, web *W, filename *F, text_stream *css,
	text_stream *trans, weave_pattern *pattern, filename *from) {
	css_file_transformation cft;
	cft.OUT = OUT;
	cft.trans = NULL;
	TextFiles::read(F, FALSE, "can't open TeX file", TRUE,
	Patterns::transform_CSS, NULL, (void *) &cft);
}
