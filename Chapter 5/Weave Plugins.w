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
	MEMORY_MANAGEMENT
} weave_plugin;

@ =
weave_plugin *WeavePlugins::new(text_stream *name) {
	weave_plugin *wp = CREATE(weave_plugin);
	wp->plugin_name = Str::duplicate(name);
	return wp;
}

@ When a file is woven, then, the following function can add the plugins
necessary. If a plugin is called |X|, then we try to find |X.html| and
weave that into the page header; and we try to find |X.css|, weave an
inclusion of that, and also copy the file into the weave destination.

The fragment of HTML is compulsory; the CSS file, optional.

=
void WeavePlugins::include(OUTPUT_STREAM, web *W, weave_plugin *wp,
	weave_pattern *pattern, filename *from) {	
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
								Indexer::incorporate_template_for_web_and_pattern(OUT,
									W, pattern, F);
							} else {
								Patterns::copy_file_into_weave(W, F, AP);
							}
						} else {
							if (html_mode) {
								TEMPORARY_TEXT(ext);
								Filenames::write_extension(ext, F);
								if (Str::eq_insensitive(ext, I".css")) {
									TEMPORARY_TEXT(url);
									if (AP) Pathnames::relative_URL(url, Filenames::up(from), AP);
									WRITE_TO(url, "%S", leafname);
									WRITE("<link href=\"%S\" rel=\"stylesheet\" rev=\"stylesheet\" type=\"text/css\">\n", url);
									DISCARD_TEXT(url);
								}
							}
							Patterns::copy_file_into_weave(W, F, AP);
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

void WeavePlugins::include_from_pattern(OUTPUT_STREAM, web *W, weave_pattern *pattern, filename *from) {
	for (weave_pattern *p = pattern; p; p = p->based_on) {
		weave_plugin *wp;
		LOOP_OVER_LINKED_LIST(wp, weave_plugin, p->plugins)
			WeavePlugins::include(OUT, W, wp, pattern, from);
	}
}

void WeavePlugins::include_from_target(OUTPUT_STREAM, web *W, weave_order *target, filename *from) {
	weave_plugin *wp;
	LOOP_OVER_LINKED_LIST(wp, weave_plugin, target->plugins)
		WeavePlugins::include(OUT, W, wp, target->pattern, from);
}

filename *WeavePlugins::find_asset(weave_pattern *pattern, text_stream *name,
	text_stream *leafname) {
	for (weave_pattern *wp = pattern; wp; wp = wp->based_on) {
		pathname *P = Pathnames::down(wp->pattern_location, name);
		filename *F = P?(Filenames::in(P, leafname)):NULL;
		if (TextFiles::exists(F)) return F;
	}
	return NULL;
}
