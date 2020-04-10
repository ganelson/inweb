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
	TEMPORARY_TEXT(embed_leaf);
	WRITE_TO(embed_leaf, "%S.html", wp->plugin_name);
	filename *F = Filenames::in_folder(	
		Pathnames::subfolder(W->md->path_to_web, I"Plugins"), embed_leaf);
	if (TextFiles::exists(F) == FALSE)
		F = Filenames::in_folder(	
			Pathnames::subfolder(path_to_inweb, I"Plugins"), embed_leaf);
	DISCARD_TEXT(embed_leaf);

	if (TextFiles::exists(F) == FALSE) {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "The plugin '%S' is not supported", wp->plugin_name);
		Main::error_in_web(err, NULL);
		return;
	}
	Indexer::run(W, I"", F, NULL, OUT, pattern, NULL, NULL, NULL, FALSE, TRUE);
}
