[WeavePlugins::] Weave Plugins.

Mainly for HTML, to add the necessary JavaScript for unusual requirements
such as equations or footnotes.

@h Creation.

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

void WeavePlugins::include(OUTPUT_STREAM, web *W, weave_plugin *wp,
	weave_pattern *pattern) {
	pathname *P1 = Pathnames::subfolder(W->md->path_to_web, I"Plugins");
	pathname *P2 = Pathnames::subfolder(path_to_inweb, I"Plugins");
		
	TEMPORARY_TEXT(embed_leaf);
	TEMPORARY_TEXT(css_leaf);
	WRITE_TO(embed_leaf, "%S.html", wp->plugin_name);
	WRITE_TO(css_leaf, "%S.css", wp->plugin_name);
	filename *F = P1?(Filenames::in_folder(P1, embed_leaf)):NULL;
	if (TextFiles::exists(F) == FALSE) F = P2?(Filenames::in_folder(P2, embed_leaf)):NULL;
	filename *CF = P1?(Filenames::in_folder(P1, css_leaf)):NULL;
	if (TextFiles::exists(CF) == FALSE) CF = P2?(Filenames::in_folder(P2, css_leaf)):NULL;
	DISCARD_TEXT(embed_leaf);
	DISCARD_TEXT(css_leaf);

	if (TextFiles::exists(F) == FALSE) {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "The plugin '%S' is not supported", wp->plugin_name);
		Main::error_in_web(err, NULL);
		return;
	}
	Indexer::run(W, I"", F, NULL, OUT, pattern, NULL, NULL, NULL, FALSE, TRUE);
	if (TextFiles::exists(CF)) {
		WRITE("<link href=\"%S.css\" rel=\"stylesheet\" rev=\"stylesheet\" type=\"text/css\">\n",
			wp->plugin_name);
		Patterns::copy_file_into_weave(W, CF);
	}
}
