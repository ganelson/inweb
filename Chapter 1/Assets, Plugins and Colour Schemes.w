[Assets::] Assets, Plugins and Colour Schemes.

Mainly for HTML, to add the necessary JavaScript for unusual requirements
such as equations or footnotes.

@h Creation.
At present, plugins are simply their names: Inweb knows as little as possible
about what they do. The model is just that a file being woven either does or
does not need a plugin of a given name.

=
typedef struct weave_plugin {
	struct text_stream *plugin_name;
	int last_included_in_round;
	CLASS_DEFINITION
} weave_plugin;

@ =
weave_plugin *Assets::new(text_stream *name) {
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
	CLASS_DEFINITION
} colour_scheme;

@ =
colour_scheme *Assets::find_colour_scheme(weave_pattern *pattern,
	text_stream *name, text_stream *pre) {
	colour_scheme *cs;
	LOOP_OVER(cs, colour_scheme)
		if (Str::eq_insensitive(cs->scheme_name, name))
			return cs;
	TEMPORARY_TEXT(css)
	WRITE_TO(css, "%S.css", name);
	filename *F = Patterns::find_file_in_subdirectory(pattern, I"Colouring", css);
	if (F == NULL) F = Patterns::find_file_in_subdirectory(pattern, I"Coloring", css);
	DISCARD_TEXT(css)
	if (F == NULL) return NULL;
	cs = CREATE(colour_scheme);
	cs->scheme_name = Str::duplicate(name);
	cs->at = F;
	cs->prefix = Str::duplicate(pre);
	cs->last_included_in_round = 0;
	if (Str::len(pre) > 0) WRITE_TO(cs->prefix, "-");
	return cs;
}

@h Plugin inclusion.
Plugins are included both by the pattern, if they are needed for anything
woven to that pattern, and by the individual weave order, if a particular
need has arisen on a particular file.

=
int current_inclusion_round = 0;
void Assets::include_relevant_plugins(text_stream *OUT, weave_pattern *pattern,
	web *W, weave_order *wv, filename *from) {
	current_inclusion_round++;
	STREAM_INDENT(STDOUT);
	Patterns::include_plugins(OUT, W, pattern, from);
	if (wv) Swarm::include_plugins(OUT, W, wv, from);
	STREAM_OUTDENT(STDOUT);
}

@ Those two functions both repeatedly call the functions //Assets::include_plugin//
and //Assets::include_colour_scheme// as needed, so these are declared next.

A plugin can only be included once in each round, i.e., for each woven file,
no matter how many times this is called.

To include a plugin is by definition to include its assets. These may be held
either in the current pattern, or in the one it is based on, or the one
that in turn is based on, and so forth. The first-discovered asset wins:
i.e., if the current pattern's copy of the asset contains |MyAsset.png| then
this prevails over any |MyAsset.png| held by patterns further down. To do
this, we store the leafnames in a dictionary.

=
void Assets::include_plugin(OUTPUT_STREAM, web *W, weave_plugin *wp,
	weave_pattern *pattern, filename *from) {	
	if (wp->last_included_in_round == current_inclusion_round) return;
	wp->last_included_in_round = current_inclusion_round;
	if (verbose_mode) PRINT("Include plugin '%S'\n", wp->plugin_name);
	int finds = 0;
	dictionary *leaves_gathered = Dictionaries::new(128, TRUE);
	for (weave_pattern *p = pattern; p; p = p->based_on) {
		pathname *P = Pathnames::down(p->pattern_location, wp->plugin_name);
		scan_directory *D = Directories::open(P);
		if (D) {
			TEMPORARY_TEXT(leafname)
			while (Directories::next(D, leafname)) {
				if ((Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) &&
					(Str::get_first_char(leafname) != '.')) {
					if (Dictionaries::find(leaves_gathered, leafname) == NULL) {
						WRITE_TO(Dictionaries::create_text(leaves_gathered, leafname), "y");
						filename *F = Filenames::in(P, leafname);
						Assets::include_asset(OUT, NULL, W, F, NULL, pattern, from);
						finds++;
					}
				}
			}
			DISCARD_TEXT(leafname)
			Directories::close(D);	
		}
	}
	if (finds == 0) {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "The plugin '%S' is not supported", wp->plugin_name);
		Main::error_in_web(err, NULL);
	}
}

@ Colour schemes are CSS files held slightly differently, in the |Colouring|
subdirectory of (presumably) an HTML-based pattern.

A colour scheme can only be included once in each round, i.e., for each woven
file, no matter how many times this is called.

=
void Assets::include_colour_scheme(OUTPUT_STREAM, web *W, colour_scheme *cs,
	weave_pattern *pattern, filename *from) {	
	if (cs->last_included_in_round == current_inclusion_round) return;
	cs->last_included_in_round = current_inclusion_round;
	if (verbose_mode) PRINT("Include colour scheme '%S'\n", cs->scheme_name);
	TEMPORARY_TEXT(css)
	WRITE_TO(css, "%S.css", cs->scheme_name);
	filename *F = Patterns::find_file_in_subdirectory(pattern, I"Colouring", css);
	if (F == NULL) F = Patterns::find_file_in_subdirectory(pattern, I"Coloring", css);
	if (F == NULL) {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "No CSS file for the colour scheme '%S' can be found",
			cs->scheme_name);
		Main::error_in_web(err, NULL);
		DISCARD_TEXT(err)
	} else {
		Assets::include_asset(OUT, NULL, W, F, cs->prefix, pattern, from);
	}
	DISCARD_TEXT(css)
}

@h Asset rules lists.
The practical effect of the two function above, then, is to call
//Assets::include_asset// on each asset needed. What that function does
is highly configurable by the pattern, so we now have to show how. Each
different filename extension, such as |.jpg|, has its own rule for what to do:

@e EMBED_ASSET_METHOD from 1
@e COPY_ASSET_METHOD
@e PRIVATE_COPY_ASSET_METHOD
@e COLLATE_ASSET_METHOD

=
typedef struct asset_rule {
	struct text_stream *applies_to;
	int method; /* one of the |*_ASSET_METHOD| values above */
	struct text_stream *pre;
	struct text_stream *post;
	int transform_names;
	CLASS_DEFINITION
} asset_rule;

@ A pattern has a list of such rules, as follows. In each list, exactly one
rule has the empty text as its |applies_to|: that one is the default, for any
file whose extension does not appear in the rules list.

(The default rule is to copy the file as a binary object, doing nothing fancy.)

=
linked_list *Assets::new_asset_rules_list(void) {
	linked_list *L = NEW_LINKED_LIST(asset_rule);
	Assets::add_asset_rule(L, I"", I"copy", NULL);
	return L;
}

@ This is called by //Patterns// in response to |assets: EXT CMD| commands. The
|CMD| part is in |line|.

=
void Assets::add_asset_rule(linked_list *L, text_stream *ext, text_stream *line,
	text_file_position *tfp) {
	asset_rule *R = Assets::new_rule(L, ext, line, tfp);
	ADD_TO_LINKED_LIST(R, asset_rule, L);
}

asset_rule *Assets::new_rule(linked_list *L, text_stream *ext, text_stream *line,
	text_file_position *tfp) {
	asset_rule *R;
	if (L)
		LOOP_OVER_LINKED_LIST(R, asset_rule, L)
			if (Str::eq_insensitive(R->applies_to, ext)) {
				@<Use this R@>;
				return R;
			}
	R = CREATE(asset_rule);
	R->applies_to = Str::duplicate(ext);
	@<Set R to defaults@>;
 	@<Use this R@>;
 	return R;
}

@<Set R to defaults@> =
	R->method = COPY_ASSET_METHOD;
 	R->pre = Str::new();
 	R->post = Str::new();
 	R->transform_names = FALSE;

@<Use this R@> =
	text_stream *cmd = line;
	text_stream *detail = NULL;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c+?) *= *(%c*)")) {
		cmd = mr.exp[0];
		detail = mr.exp[1];
	}
	if (Str::eq(cmd, I"copy")) {
		@<Set R to defaults@>; R->method = COPY_ASSET_METHOD;
	} else if (Str::eq(cmd, I"private copy")) {
		@<Set R to defaults@>; R->method = PRIVATE_COPY_ASSET_METHOD;
	} else if (Str::eq(cmd, I"embed")) {
		@<Set R to defaults@>; R->method = EMBED_ASSET_METHOD;
	} else if (Str::eq(cmd, I"collate")) {
		@<Set R to defaults@>; R->method = COLLATE_ASSET_METHOD;
	} else if (Str::eq(cmd, I"prefix")) {
		R->pre = Str::duplicate(detail);
	} else if (Str::eq(cmd, I"suffix")) {
		R->post = Str::duplicate(detail);
	} else if (Str::eq(cmd, I"transform names")) {
		R->transform_names = TRUE;
	} else Errors::in_text_file("no such asset command", tfp);
	Regexp::dispose_of(&mr);

@ Given a filename |F| for some asset, which rule applies to it? The answer
is that if the current pattern, or any pattern it is based on, defines a rule,
then the topmost one applies; and otherwise the default rule applies.

=
asset_rule *Assets::applicable_rule(weave_pattern *pattern, filename *F) {
	TEMPORARY_TEXT(ext)
	Filenames::write_extension(ext, F);
	for (weave_pattern *p = pattern; p; p = p->based_on) {
		asset_rule *R;
		LOOP_OVER_LINKED_LIST(R, asset_rule, p->asset_rules)
			if (Str::eq_insensitive(R->applies_to, ext))
				return R;
	}
	asset_rule *R;
	LOOP_OVER_LINKED_LIST(R, asset_rule, pattern->asset_rules)
		if (Str::eq_insensitive(R->applies_to, I""))
			return R;
	internal_error("no default asset rule");
	return NULL;
}

@h Inclusion of assets.
Finally, then, we can include a single asset. This has already been located,
at filename |F|, and we now know how to find the applicable rule.

=
void Assets::include_asset(OUTPUT_STREAM, asset_rule *R, web *W, filename *F,
	text_stream *trans, weave_pattern *pattern, filename *from) {
	if (R == NULL) R = Assets::applicable_rule(pattern, F);
	TEMPORARY_TEXT(url)
	pathname *AP = Colonies::assets_path();
	if (AP) Pathnames::relative_URL(url, Filenames::up(from), AP);
	WRITE_TO(url, "%S", Filenames::get_leafname(F));
	if (R->transform_names == FALSE) trans = NULL;
	if (Str::len(R->pre) > 0) @<Embed the prefix, if any@>;
	switch (R->method) {
		case EMBED_ASSET_METHOD: @<Embed asset@>; break;
		case COPY_ASSET_METHOD: @<Copy asset@>; break;
		case PRIVATE_COPY_ASSET_METHOD: @<Copy asset@>; break;
		case COLLATE_ASSET_METHOD: @<Collate asset@>; break;
	}
	if (Str::len(R->post) > 0) @<Embed the suffix, if any@>;
	DISCARD_TEXT(url)
}

@<Embed the prefix, if any@> =
	for (int i=0; i<Str::len(R->pre); i++) {
		if (Str::includes_at(R->pre, i, I"URL")) {
			WRITE("%S", url);
			i += 2;
		} else PUT(Str::get_at(R->pre, i));
	}
	WRITE("\n");

@<Embed asset@> =
	if (verbose_mode) PRINT("Embed asset %f\n", F);
	Assets::transform(OUT, F, trans);

@<Copy asset@> =
	pathname *H = W->redirect_weaves_to;
	if (H == NULL) H = Reader::woven_folder(W);
	if ((AP) && (R->method != PRIVATE_COPY_ASSET_METHOD)) H = AP;
	if (verbose_mode) PRINT("Copy asset %f -> %p\n", F, H);
	if (Str::len(trans) > 0) {
		text_stream css_S;
		filename *G = Filenames::in(H, Filenames::get_leafname(F));
		if (STREAM_OPEN_TO_FILE(&css_S, G, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write tangled file", F);
		Assets::transform(&css_S, F, trans);
		STREAM_CLOSE(&css_S);
	} else Shell::copy(F, H, "");
	if (W->as_ebook) {
		filename *rel = Filenames::in(NULL, Filenames::get_leafname(F));
		Epub::note_image(W->as_ebook, rel);
	}

@<Collate asset@> =
	if (verbose_mode) PRINT("Collate asset %f\n", F);
	Collater::for_web_and_pattern(OUT, W, pattern, F, from);

@<Embed the suffix, if any@> =
	for (int i=0; i<Str::len(R->post); i++) {
		if (Str::includes_at(R->post, i, I"URL")) {
			WRITE("%S", url);
			i += 2;
		} else PUT(Str::get_at(R->post, i));
	}
	WRITE("\n");

@ "Transforming" is what happens to a CSS file to change the class names of
its |span| and |pre| styling rules, to add a prefix text. This is what changes
the style names for colouring, say, COBOL source code from, e.g.,
|span.identifier-syntax| to |span.ConsoleText-identifier-syntax|.

=
typedef struct css_file_transformation {
	struct text_stream *OUT;
	struct text_stream *trans;
} css_file_transformation;

void Assets::transform(text_stream *OUT, filename *F, text_stream *trans) {
	css_file_transformation cft;
	cft.OUT = OUT;
	cft.trans = trans;
	TextFiles::read(F, FALSE, "can't open file", TRUE,
		Assets::transformer, NULL, (void *) &cft);
}

void Assets::transformer(text_stream *line, text_file_position *tfp, void *X) {
	css_file_transformation *cft = (css_file_transformation *) X;
	text_stream *OUT = cft->OUT;
	match_results mr = Regexp::create_mr();
	TEMPORARY_TEXT(spanned)
	while (Regexp::match(&mr, line, L"(%c*?span.)(%i+)(%c*?)")) {
		WRITE_TO(spanned, "%S%S%S", mr.exp[0], cft->trans, mr.exp[1]);
		Str::clear(line); Str::copy(line, mr.exp[2]);
	}
	WRITE_TO(spanned, "%S\n", line);
	while (Regexp::match(&mr, spanned, L"(%c*?pre.)(%i+)(%c*?)")) {
		WRITE("%S%S%S", mr.exp[0], cft->trans, mr.exp[1]);
		Str::clear(spanned); Str::copy(spanned, mr.exp[2]);
	}
	WRITE("%S", spanned);
	DISCARD_TEXT(spanned)
	Regexp::dispose_of(&mr);
}
