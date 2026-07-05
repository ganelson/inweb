[Assets::] Assets, Plugins and Colour Schemes.

Mainly for HTML, to add the necessary JavaScript for unusual requirements
such as equations or footnotes.

@h Creation.
At present, plugins are simply their names: we know as little as possible
about what they do. The model is just that a file being woven either does or
does not need a plugin of a given name.

=
classdef weave_plugin {
	struct text_stream *plugin_name;
	int last_included_in_round;
}

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
classdef colour_scheme {
	struct text_stream *scheme_name;
	struct text_stream *prefix;
	struct filename *at;
	int last_included_in_round;
}

@ =
colour_scheme *Assets::find_colour_scheme(ls_web *W, ls_pattern *pattern,
	text_stream *name, text_stream *pre) {
	colour_scheme *cs;
	LOOP_OVER(cs, colour_scheme)
		if (Str::eq_insensitive(cs->scheme_name, name))
			return cs;
	TEMPORARY_TEXT(css)
	WRITE_TO(css, "%S.css", name);
	filename *F = Patterns::find_file_in_subdirectory(W, pattern, I"Colouring", css);
	if (F == NULL) F = Patterns::find_file_in_subdirectory(W, pattern, I"Coloring", css);
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
void Assets::include_relevant_plugins(text_stream *OUT, weave_order *wv) {
	if (wv == NULL) internal_error("relevant plugin inclusion without weave order");
	current_inclusion_round++;
	STREAM_INDENT(OUT);
	Patterns::include_plugins(OUT, wv);
	Swarm::include_plugins(OUT, wv);
	STREAM_OUTDENT(OUT);
}

@ Those two functions both repeatedly call the functions //Assets::include_plugin//
and //Assets::include_colour_scheme// as needed, so these are declared next.

A plugin can only be included once in each round, i.e., for each woven file,
no matter how many times this is called.

To include a plugin is by definition to include its assets. These may be held
either in the current pattern, or in the one it is based on, or the one
that in turn is based on, and so forth. The first-discovered asset wins:
i.e., if the current pattern's copy of the asset contains `MyAsset.png` then
this prevails over any `MyAsset.png` held by patterns further down. To do
this, we store the leafnames in a dictionary.

=
void Assets::include_plugin(OUTPUT_STREAM, weave_plugin *wp, weave_order *wv) {	
	if (wv == NULL) internal_error("plugin inclusion without weave order");
	ls_web *W = wv->weave_web;
	if (wp->last_included_in_round == current_inclusion_round) return;
	wp->last_included_in_round = current_inclusion_round;
	Swarm::report_plugin(wv->reportage, wp);
	int finds = 0;
	dictionary *leaves_gathered = Dictionaries::new(128, TRUE);
	for (ls_pattern *p = wv->pattern; p; p = Patterns::basis(W->declaration, p)) {
		pathname *P = Pathnames::down(p->pattern_location, wp->plugin_name);
		linked_list *L = Directories::listing(P);
		text_stream *leafname;
		LOOP_OVER_LINKED_LIST(leafname, text_stream, L) {
			if ((Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) &&
				(Str::get_first_char(leafname) != '.')) {
				if (Dictionaries::find(leaves_gathered, leafname) == NULL) {
					WRITE_TO(Dictionaries::create_text(leaves_gathered, leafname), "y");
					filename *F = Filenames::in(P, leafname);
					Assets::include_asset(OUT, NULL, F, NULL, wv);
					finds++;
				}
			}
		}
	}
	if (finds == 0) {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "The plugin '%S' is not supported", wp->plugin_name);
		WebErrors::issue_at(err, NULL);
	}
}

@ Colour schemes are CSS files held slightly differently, in the `Colouring`
subdirectory of (presumably) an HTML-based pattern.

A colour scheme can only be included once in each round, i.e., for each woven
file, no matter how many times this is called.

=
void Assets::include_colour_scheme(OUTPUT_STREAM, colour_scheme *cs, weave_order *wv) {	
	if (wv == NULL) internal_error("colour scheme inclusion without weave order");
	if (cs->last_included_in_round == current_inclusion_round) return;
	cs->last_included_in_round = current_inclusion_round;
	Swarm::report_colour_scheme(wv->reportage, cs);
	TEMPORARY_TEXT(css)
	WRITE_TO(css, "%S.css", cs->scheme_name);
	filename *F = Patterns::find_file_in_subdirectory(wv->weave_web, wv->pattern, I"Colouring", css);
	if (F == NULL) F = Patterns::find_file_in_subdirectory(wv->weave_web, wv->pattern, I"Coloring", css);
	if (F == NULL) {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "No CSS file for the colour scheme '%S' can be found",
			cs->scheme_name);
		WebErrors::issue_at(err, NULL);
		DISCARD_TEXT(err)
	} else {
		Assets::include_asset(OUT, NULL, F, cs->prefix, wv);
	}
	DISCARD_TEXT(css)
}

@h Asset rules lists.
The practical effect of the two function above, then, is to call
//Assets::include_asset// on each asset needed. What that function does
is highly configurable by the pattern, so we now have to show how. Each
different filename extension, such as `.jpg`, has its own rule for what to do:

@e IGNORE_ASSET_METHOD from 1
@e EMBED_ASSET_METHOD
@e COPY_ASSET_METHOD
@e PRIVATE_COPY_ASSET_METHOD
@e COLLATE_ASSET_METHOD

=
classdef asset_selector {
	struct text_stream *any_with_extension;
	struct text_stream *specific_leafname;
	struct text_stream *owning_plugin; /* or if blank, applies to all plugins */
	struct text_stream *textual;
}

asset_selector *Assets::anything(void) {
	asset_selector *any = CREATE(asset_selector);
	any->any_with_extension = NULL;
	any->specific_leafname = NULL;
	any->owning_plugin = NULL;
	any->textual = I"all files";
	return any;
}

asset_selector *Assets::parse_selector(text_stream *desc, text_file_position *tfp) {
	text_stream *textual_form = Str::duplicate(desc);
	text_stream *plugin = NULL, *ext = NULL, *leaf = NULL;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, desc, U"(%c+) in (%C+)")) { desc = mr.exp[0]; plugin = mr.exp[1]; }
	match_results mr2 = Regexp::create_mr();
	if (Regexp::match(&mr2, desc, U"all files")) ;
	else if (Regexp::match(&mr2, desc, U"(.%C+) files")) ext = mr2.exp[0];
	else if (Regexp::match(&mr2, desc, U"(%c+) file")) leaf = mr2.exp[0];
	else {
		Errors::in_text_file("bad selector", tfp);
		WRITE_TO(STDERR, "unrecognised: %S\n", desc);
		return NULL;
	}
	asset_selector *any = Assets::anything();
	any->any_with_extension = Str::duplicate(ext);
	any->specific_leafname = Str::duplicate(leaf);
	any->owning_plugin = Str::duplicate(plugin);
	any->textual = textual_form;
	return any;
}

int Assets::selected(asset_selector *selector, filename *F) {
	if (Str::len(selector->any_with_extension) > 0) {
		TEMPORARY_TEXT(ext)
		Filenames::write_final_extension(ext, F);
		int rv = Str::eq_insensitive(selector->any_with_extension, ext);
		DISCARD_TEXT(ext)
		if (rv == FALSE) return FALSE;
	}
	if (Str::len(selector->specific_leafname) > 0)
		if (Str::eq_insensitive(selector->specific_leafname, Filenames::get_leafname(F)) == FALSE)
			return FALSE;
	if (Str::len(selector->owning_plugin) > 0) {
		text_stream *owner = Pathnames::directory_name(Filenames::up(F));
		if (Str::eq_insensitive(selector->owning_plugin, owner) == FALSE)
			return FALSE;
	}
	return TRUE;
}

int Assets::same(asset_selector *A, asset_selector *B) {
	if (Str::ne_insensitive(A->any_with_extension, B->any_with_extension)) return FALSE;
	if (Str::ne_insensitive(A->specific_leafname, B->specific_leafname)) return FALSE;
	if (Str::ne_insensitive(A->owning_plugin, B->owning_plugin)) return FALSE;
	return TRUE;
}

@ This tests: is every file selected by `A` also selected by `B`? This means
testing that every requirement of `B` is also a requirement of `A`, and that's
only difficult with filename extensions. For example, if `A` requires the file
`example.jpg`, and `B` requires the extension `.jpg`, then that's okay. So before
testing we work out the effective extension requirements `exta` and `extb`.

=
int Assets::subset(asset_selector *A, asset_selector *B) {
	int rv = TRUE;

	TEMPORARY_TEXT(exta)
	TEMPORARY_TEXT(extb)
	if (Str::len(A->any_with_extension) > 0) WRITE_TO(exta, "%S", A->any_with_extension);
	else
		for (int i=0; i<Str::len(A->specific_leafname); i++) {
			inchar32_t c = Str::get_at(A->specific_leafname, i);
			if (c == '.') Str::clear(exta);
			PUT_TO(exta, c);
		}
	if (Str::len(B->any_with_extension) > 0) WRITE_TO(extb, "%S", B->any_with_extension);
	else
		for (int i=0; i<Str::len(B->specific_leafname); i++) {
			inchar32_t c = Str::get_at(B->specific_leafname, i);
			if (c == '.') Str::clear(extb);
			PUT_TO(extb, c);
		}

	if ((Str::len(extb) > 0) && (Str::ne_insensitive(exta, extb))) rv = FALSE;
	if ((Str::len(B->specific_leafname) > 0) && (Str::ne_insensitive(A->specific_leafname, B->specific_leafname))) rv = FALSE;
	if ((Str::len(B->owning_plugin) > 0) && (Str::ne_insensitive(A->owning_plugin, B->owning_plugin))) rv = FALSE;
	DISCARD_TEXT(exta)
	DISCARD_TEXT(extb)

	return rv;
}

classdef asset_disposition {
	int method; /* one of the `*_ASSET_METHOD` values above */
	struct text_stream *prefix_text;
	struct text_stream *suffix_text;
	int next_is_pre;
	int transform_names; /* CSS style name mangling */
	int add_search_data; /* SeekLocateDisplay search index incorporation */
	int collate_to;	/* One of the `*_WEAVEINSCRIPTION` values */
}

asset_disposition *Assets::new_disposition(void) {
	asset_disposition *D = CREATE(asset_disposition);
	D->method = COPY_ASSET_METHOD;
 	D->prefix_text = Str::new();
 	D->suffix_text = Str::new();
 	D->next_is_pre = NOT_APPLICABLE;
 	D->transform_names = FALSE;
 	D->add_search_data = FALSE;
 	D->collate_to = HEAD_WEAVEINSCRIPTION;
	return D;
}

asset_disposition *Assets::private_copy(void) {
	asset_disposition *D = Assets::new_disposition();
	D->method = PRIVATE_COPY_ASSET_METHOD;
	return D;
}

void Assets::parse_disposition(asset_disposition *D, text_stream *cmd, text_file_position *tfp) {
	D->next_is_pre = NOT_APPLICABLE;
	if (Str::eq(cmd, I"copy")) {
		D->method = COPY_ASSET_METHOD;
	} else if (Str::eq(cmd, I"privately copy")) {
		D->method = PRIVATE_COPY_ASSET_METHOD;
	} else if (Str::eq(cmd, I"embed file")) {
		D->method = EMBED_ASSET_METHOD;
	} else if (Str::eq(cmd, I"ignore")) {
		D->method = IGNORE_ASSET_METHOD;
	} else if (Str::eq(cmd, I"collate")) {
		D->method = COLLATE_ASSET_METHOD;
	} else if (Str::eq(cmd, I"collate to head")) {
		D->method = COLLATE_ASSET_METHOD;
		D->collate_to = HEAD_WEAVEINSCRIPTION;
	} else if (Str::eq(cmd, I"collate to body")) {
		D->method = COLLATE_ASSET_METHOD;
		D->collate_to = BODY_WEAVEINSCRIPTION;
	} else if (Str::eq(cmd, I"collate to search box")) {
		D->method = COLLATE_ASSET_METHOD;
		D->collate_to = SEARCH_BOX_WEAVEINSCRIPTION;
	} else if (Str::eq(cmd, I"embed")) {
		D->next_is_pre = TRUE;
	} else if (Str::eq(cmd, I"prefix")) {
		D->next_is_pre = TRUE;
	} else if (Str::eq(cmd, I"suffix")) {
		D->next_is_pre = FALSE;
	} else if (Str::eq(cmd, I"transform names")) {
		D->transform_names = TRUE;
	} else if (Str::eq(cmd, I"add data")) {
		D->add_search_data = TRUE;
	} else {
		Errors::in_text_file("no such asset disposition", tfp);
		WRITE_TO(STDERR, "erroneous command: %S\n", cmd);
	}
}

classdef asset_rule {
	struct asset_selector *selector;
	struct asset_disposition *disposition;
}

asset_rule *Assets::new_rule(asset_selector *S, asset_disposition *D) {
	asset_rule *R = CREATE(asset_rule);
	R->selector = S;
	R->disposition = D;
	return R;
}

asset_rule *Assets::simple_private_copy(void) {
	return Assets::new_rule(Assets::anything(), Assets::private_copy());
}

int Assets::add_text_to_rule(asset_rule *R, text_stream *text) {
	if (R->disposition->next_is_pre) {
		R->disposition->prefix_text = Str::duplicate(text);
	} else if (R->disposition->next_is_pre == FALSE) {
		R->disposition->suffix_text = Str::duplicate(text);
	} else return FALSE;
	return TRUE;
}

@ "Inscriptions" are fragments of HTML copied by templates into different
locations in the woven output:

@e HEAD_WEAVEINSCRIPTION from 0
@e BODY_WEAVEINSCRIPTION
@e SEARCH_BOX_WEAVEINSCRIPTION

@ This is called by //Patterns// in response to `assets: EXT CMD` commands. The
`CMD` part is in `line`.

=
void Assets::add_asset_rule(linked_list *L, asset_rule *R, text_file_position *tfp) {
	asset_rule *E;
	LOOP_OVER_LINKED_LIST(E, asset_rule, L)
		if (Assets::subset(R->selector, E->selector)) {
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "new rule with selector '%S' is pre-empted by existing '%S' rule",
				R->selector->textual, E->selector->textual);
			Errors::in_text_file_S(err, tfp);
			DISCARD_TEXT(err)
			return;
		}	
	ADD_TO_LINKED_LIST(R, asset_rule, L);
}

@ Given a filename `F` for some asset, which rule applies to it? The answer
is that if the current pattern, or any pattern it is based on, defines a rule
which selects for it, then it's the first such. Failing that, we return a
default which matches anything, and disposes of it with a simple copy.

=
asset_rule *Assets::applicable_rule(wcl_declaration *D, ls_pattern *pattern, filename *F) {
	asset_rule *R;
	for (ls_pattern *p = pattern; p; p = Patterns::basis(D, p))
		LOOP_OVER_LINKED_LIST(R, asset_rule, p->asset_rules)
			if (Assets::selected(R->selector, F))
				return R;
	static asset_rule *default_rule = NULL;
	if (default_rule == NULL)
		default_rule = Assets::new_rule(Assets::anything(), Assets::new_disposition());
	return default_rule;
}

@h Inclusion of assets.
Finally, then, we can include a single asset. This has already been located,
at filename `F`, and we now know how to find the applicable rule.

=
pathname *Assets::include_asset(OUTPUT_STREAM, asset_rule *R, filename *F,
	text_stream *trans, weave_order *wv) {
	if (wv == NULL) internal_error("asset inclusion without weave order");
	if (R == NULL) R = Assets::applicable_rule(wv->weave_web->declaration, wv->pattern, F);
	if (R == NULL) internal_error("no applicable rule");
	return Assets::dispose_of_asset(OUT, R->disposition, F, trans, wv);
}

pathname *Assets::dispose_of_asset(OUTPUT_STREAM, asset_disposition *D, filename *F,
	text_stream *trans, weave_order *wv) {
	filename *from = wv->current_weave_file;
	TEMPORARY_TEXT(url)
	pathname *AP = Colonies::assets_path(wv->weave_colony, wv->weave_web);
	if (D->method == PRIVATE_COPY_ASSET_METHOD) AP = Filenames::up(wv->current_weave_file);
	if (AP) Pathnames::relative_URL(url, Filenames::up(from), AP);
	WRITE_TO(url, "%S", Filenames::get_leafname(F));
	if (D->transform_names == FALSE) trans = NULL;
	pathname *result = NULL;
	@<Embed the prefix, if any@>;
	switch (D->method) {
		case IGNORE_ASSET_METHOD: break;
		case EMBED_ASSET_METHOD: @<Embed asset@>; break;
		case COPY_ASSET_METHOD: @<Copy asset@>; break;
		case PRIVATE_COPY_ASSET_METHOD: @<Copy asset@>; break;
		case COLLATE_ASSET_METHOD: @<Collate asset@>; break;
	}
	@<Embed the suffix, if any@>;
	DISCARD_TEXT(url)
	return result;
}

@<Embed the prefix, if any@> =
	for (int i=0; i<Str::len(D->prefix_text); i++) {
		if (Str::includes_at(D->prefix_text, i, I"URL")) {
			WRITE("%S", url);
			i += 2;
		} else PUT(Str::get_at(D->prefix_text, i));
	}
	if (Str::len(D->prefix_text) > 0) WRITE("\n");

@<Embed asset@> =
	Swarm::report_embedding(wv->reportage, F);
	Assets::transform(OUT, F, trans);

@<Copy asset@> =
	pathname *H = WeavingDetails::get_redirect_weaves_to(wv->weave_web);
	if ((H == NULL) && (wv->weave_web->single_file == FALSE)) H = WebStructure::woven_folder(wv->weave_web, 1);
	if ((AP) && (D->method != PRIVATE_COPY_ASSET_METHOD)) H = AP;
	int creating = FALSE;
	if ((H) && (Directories::exists(H) == FALSE)) {
		Errors::fatal_with_path("directory to copy assets into does not exist", H);
	}
	if (Swarm::report_copy(wv->reportage, F, H, creating) == TRUE) {
		if (Str::len(trans) > 0) {
			text_stream css_S;
			filename *G = Filenames::in(H, Filenames::get_leafname(F));
			if (STREAM_OPEN_TO_FILE(&css_S, G, ISO_ENC) == FALSE)
				Errors::fatal_with_file("unable to write tangled file", F);
			Assets::transform(&css_S, F, trans);
			STREAM_CLOSE(&css_S);
		} else if (D->add_search_data) {
			text_stream sd_S;
			filename *G = Filenames::in(H, Filenames::get_leafname(F));
			if (STREAM_OPEN_TO_FILE(&sd_S, G, ISO_ENC) == FALSE)
				Errors::fatal_with_file("unable to write tangled file", F);
			Assets::incorporate_search_data(&sd_S, F, wv->weave_web);
			STREAM_CLOSE(&sd_S);
			result = H;
		} else {
			Shell::copy(F, H, "");
			result = H;
		}
	}
	if (WeavingDetails::get_as_ebook(wv->weave_web)) {
		filename *rel = Filenames::in(NULL, Filenames::get_leafname(F));
		Epub::note_image(WeavingDetails::get_as_ebook(wv->weave_web), rel);
	}

@<Collate asset@> =
	Swarm::report_collation(wv->reportage, F);
	text_stream *TO = OUT;
	if (D->collate_to > 0) TO = wv->current_inscriptions[D->collate_to];
	Collater::collate(TO, wv, F);

@<Embed the suffix, if any@> =
	for (int i=0; i<Str::len(D->suffix_text); i++) {
		if (Str::includes_at(D->suffix_text, i, I"URL")) {
			WRITE("%S", url);
			i += 2;
		} else PUT(Str::get_at(D->suffix_text, i));
	}
	if (Str::len(D->suffix_text) > 0) WRITE("\n");

@ "Transforming" is what happens to a CSS file to change the class names of
its `span` and `pre` styling rules, to add a prefix text. This is what changes
the style names for colouring, say, COBOL source code from, e.g.,
`span.identifier-syntax` to `span.COBOL-identifier-syntax`.

=
classdef css_file_transformation {
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
	while (Regexp::match(&mr, line, U"(%c*?span.)(%i+)(%c*?)")) {
		WRITE_TO(spanned, "%S%S%S", mr.exp[0], cft->trans, mr.exp[1]);
		Str::clear(line); Str::copy(line, mr.exp[2]);
	}
	WRITE_TO(spanned, "%S\n", line);
	while (Regexp::match(&mr, spanned, U"(%c*?pre.)(%i+)(%c*?)")) {
		WRITE("%S%S%S", mr.exp[0], cft->trans, mr.exp[1]);
		Str::clear(spanned); Str::copy(spanned, mr.exp[2]);
	}
	WRITE("%S", spanned);
	DISCARD_TEXT(spanned)
	Regexp::dispose_of(&mr);
}

classdef sd_file_transformation {
	struct text_stream *OUT;
	struct ls_web *W;
} sd_file_transformation;

void Assets::incorporate_search_data(text_stream *OUT, filename *F, ls_web *W) {
	sd_file_transformation sd;
	sd.OUT = OUT;
	sd.W = W;
	TextFiles::read(F, FALSE, "can't open file", TRUE,
		Assets::incorporater, NULL, (void *) &sd);
}

void Assets::incorporater(text_stream *line, text_file_position *tfp, void *X) {
	sd_file_transformation *sd = (sd_file_transformation *) X;
	text_stream *OUT = sd->OUT;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%c*?)%[%[Search Data%]%](%c*?)")) {
		WRITE("%S\n", mr.exp[0]);
		@<Splice in search data@>;
		WRITE("%S\n", mr.exp[1]);
	} else if (Regexp::match(&mr, line, U"(%c*?)%[%[Search Text%]%](%c*?)")) {
		WRITE("%S", mr.exp[0]);
		WRITE("Search %S...", Bibliographic::get_datum(sd->W, I"Title"));
		WRITE("%S\n", mr.exp[1]);
	} else {
		WRITE("%S\n", line);
	}
}

@<Splice in search data@> =
	JSON_value *pages = JSON::new_array();
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, sd->W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
			JSON_value *subhead_list = JSON::new_array();
			text_stream *nh = NULL;
			for (ls_paragraph *P = S->literate_source->first_par; P; P = P->next_par) {
				if (Str::len(P->titling.operand1) > 0) nh = P->titling.operand1;
				JSON_value *subhead = JSON::new_object();
				@<The ID field is the anchor@>;
				@<The HEADING field is taken from the paragraph titling, if any@>;
				@<The TEXT field is a sort of crude weave to plain text@>;
				JSON::add_to_array(subhead_list, subhead);
			}
			JSON_value *entry = JSON::new_object();
			TEMPORARY_TEXT(url)
			Colonies::section_URL(url, S);
			DISCARD_TEXT(url)
			JSON::add_to_object(entry, I"url", JSON::new_string(url));
			if (sd->W->is_page)
				JSON::add_to_object(entry, I"title", JSON::new_string(Bibliographic::get_datum(sd->W, I"Title")));
			else
				JSON::add_to_object(entry, I"title", JSON::new_string(S->sect_title));
			JSON::add_to_object(entry, I"sections", subhead_list);			
			JSON::add_to_array(pages, entry);
		}
	
	JSON::encode_to_ASCII(OUT, pages);

@<The ID field is the anchor@> =
	TEMPORARY_TEXT(id)
	Colonies::paragraph_anchor(id, P);
	JSON::add_to_object(subhead, I"id", JSON::new_string(id));
	DISCARD_TEXT(id)

@<The HEADING field is taken from the paragraph titling, if any@> =
	TEMPORARY_TEXT(sht)
	WRITE_TO(sht, "%S%S", LiterateSource::par_ornament(P), P->paragraph_number);
	if (Str::len(P->titling.operand1) > 0) WRITE_TO(sht, ". %S", P->titling.operand1);
	else if (Str::len(nh) > 0) WRITE_TO(sht, " (under %S)", nh);
	JSON::add_to_object(subhead, I"heading", JSON::new_string(sht));
	DISCARD_TEXT(sht)

@<The TEXT field is a sort of crude weave to plain text@> =
	TEMPORARY_TEXT(text)
	text_stream *OUT = text;
	for (ls_chunk *chunk = P->first_chunk; chunk; chunk = chunk->next_chunk) {
		if (chunk->holon)
			@<Crudely weave a holon@>
		else if (chunk->chunk_type == EXTRACT_LSCT)
			@<Crudely weave an extract chunk@>
		else if ((chunk->chunk_type == COMMENTARY_LSCT) && (chunk->as_markdown))
			@<Crudely weave a Markdown commentary chunk@>
		else
			@<Crudely weave some other sort of chunk@>;
	}
	JSON::add_to_object(subhead, I"text", JSON::new_string(text));
	DISCARD_TEXT(text)

@<Crudely weave a Markdown commentary chunk@> =
	MDRenderer::recurse(OUT, NULL, chunk->as_markdown, SUPERPLAIN_MDRMODE, WebNotation::commentary_variation(sd->W));
	WRITE("\n");

@<Crudely weave a holon@> =
	holon_splice *hs;
	LOOP_OVER_CODE_EXCERPT(hs, chunk->code_excerpt) {
		switch (hs->type) {
			case CODE_LSHST: @<Crudely weave a splice of raw content@>; break;
			case EXPANSION_LSHST: @<Crudely weave a named holon usage@>; break;
			case COMMAND_LSHST: @<Crudely weave a tangler command@>; break;
			case VERBATIM_LSHST: @<Crudely weave a verbatim@>; break;
			case COMMENT_LSHST: @<Crudely weave a comment@>; break;
			default: internal_error("unimplemented holon splice type");
		}
		WRITE("\n");
	}

@<Crudely weave a named holon usage@> =
	WRITE("{{");
	MDRenderer::recurse(OUT, NULL, hs->expansion->holon_name_as_markdown, SUPERPLAIN_MDRMODE, WebNotation::commentary_variation(sd->W));
	WRITE("}}");

@<Crudely weave a tangler command@> =
	;

@<Crudely weave a verbatim@> =
	WRITE("%S", hs->texts[0]);

@<Crudely weave a splice of raw content@> =
	WRITE("%S", hs->texts[0]);

@<Crudely weave a comment@> =
	if (hs->comment_as_markdown) {
		MDRenderer::recurse(OUT, NULL, hs->comment_as_markdown, SUPERPLAIN_MDRMODE, WebNotation::commentary_variation(sd->W));
	} else {
		WRITE("%S%S%S", hs->texts[1], hs->texts[0], hs->texts[2]);
	}

@<Crudely weave an extract chunk@> =
	;

@<Crudely weave some other sort of chunk@> =
	;
	