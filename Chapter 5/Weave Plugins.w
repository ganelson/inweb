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
	weave_pattern *pattern) {
	pathname *P1 = Pathnames::down(W->md->path_to_web, I"Plugins");
	pathname *P2 = Pathnames::down(path_to_inweb, I"Plugins");
		
	TEMPORARY_TEXT(embed_leaf);
	TEMPORARY_TEXT(css_leaf);
	WRITE_TO(embed_leaf, "%S.html", wp->plugin_name);
	WRITE_TO(css_leaf, "%S.css", wp->plugin_name);
	filename *F = P1?(Filenames::in(P1, embed_leaf)):NULL;
	if (TextFiles::exists(F) == FALSE) F = P2?(Filenames::in(P2, embed_leaf)):NULL;
	filename *CF = P1?(Filenames::in(P1, css_leaf)):NULL;
	if (TextFiles::exists(CF) == FALSE) CF = P2?(Filenames::in(P2, css_leaf)):NULL;
	DISCARD_TEXT(embed_leaf);
	DISCARD_TEXT(css_leaf);

	if (TextFiles::exists(F) == FALSE) {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "The plugin '%S' is not supported", wp->plugin_name);
		Main::error_in_web(err, NULL);
		return;
	}
	Indexer::incorporate_template_for_web_and_pattern(OUT, W, pattern, F);
	if (TextFiles::exists(CF)) {
		WRITE("<link href=\"%S.css\" rel=\"stylesheet\" rev=\"stylesheet\" type=\"text/css\">\n",
			wp->plugin_name);
		Patterns::copy_file_into_weave(W, CF);
	}
}
