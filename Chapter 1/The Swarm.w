[Swarm::] The Swarm.

To feed multiple output requests to the weaver, and to present
weaver results, and update indexes or contents pages.

@h Swarming.
A "weave" occurs when Inweb takes a portion of the web -- one section, one
chapter, or the whole thing -- and writes it out in a human-readable form (or
in some intermediate state which can be made into one, like a TeX file).
There can be many weaves in a single run of Inweb, in which case we call the
resulting flurry a "swarm", like the glittering cloud of locusts in the title
of Chapter 25 of "On the Banks of Plum Creek".

This routine is called with mode |SWARM_SECTIONS_SWM|, |SWARM_CHAPTERS_SWM| or
|SWARM_INDEX_SWM|, so in a non-swarming run it isn't called at all.

=
weave_order *swarm_leader = NULL; /* the most inclusive one we weave */

void Swarm::weave(web *W, text_stream *range, int swarm_mode, theme_tag *tag,
	weave_pattern *pattern, filename *to, pathname *into,
	linked_list *breadcrumbs, filename *navigation) {
	swarm_leader = NULL;
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		if (C->md->imported == FALSE) {
			if (swarm_mode == SWARM_CHAPTERS_SWM)
				if ((W->md->chaptered == TRUE) && (Reader::range_within(C->md->ch_range, range))) {
					C->ch_weave = Swarm::weave_subset(W,
						C->md->ch_range, FALSE, tag, pattern, to, into,
						breadcrumbs, navigation);
					if (Str::len(range) > 0) swarm_leader = C->ch_weave;
				}
			if (swarm_mode == SWARM_SECTIONS_SWM)
				LOOP_OVER_LINKED_LIST(S, section, C->sections)
					if (Reader::range_within(S->md->sect_range, range))
						S->sect_weave = Swarm::weave_subset(W,
							S->md->sect_range, FALSE, tag, pattern, to, into,
							breadcrumbs, navigation);
		}

	Swarm::weave_index_templates(W, range, pattern, into, navigation, breadcrumbs);
}

@ The following is where an individual weave task begins, whether it comes
from the swarm, or has been specified at the command line (in which case
the call comes from Program Control).

=
weave_order *Swarm::weave_subset(web *W, text_stream *range, int open_afterwards,
	theme_tag *tag, weave_pattern *pattern, filename *to, pathname *into,
	linked_list *breadcrumbs, filename *navigation) {
	weave_order *wv = NULL;
	if (no_inweb_errors == 0) {
		Analyser::analyse_code(W);
		@<Compile a set of instructions for the weaver@>;
		if (Weaver::weave(wv) == 0) /* i.e., the number of lines woven was zero */
			Errors::fatal("empty weave request");
		Formats::post_process_weave(wv, open_afterwards); /* e.g., run through TeX */
		@<Report on the outcome of the weave to the console@>;
	}
	return wv;
}

@ Each individual weave generates one of the following sets of instructions:

=
typedef struct weave_order {
	struct web *weave_web; /* which web we weave */
	struct text_stream *weave_range; /* which parts of the web in this weave */
	struct theme_tag *theme_match; /* pick out only paragraphs with this theme */
	struct text_stream *booklet_title;
	struct weave_pattern *pattern; /* which pattern is to be followed */
	struct filename *weave_to; /* where to put it */
	struct weave_format *format; /* plain text, say, or HTML */
	struct text_stream *cover_sheet_to_use; /* leafname of the copy, or |NULL| for no cover */
	void *post_processing_results; /* optional typesetting diagnostics after running through */
	int self_contained; /* make a self-contained file if possible */
	struct linked_list *breadcrumbs; /* non-standard breadcrumb trail, if any */
	struct filename *navigation; /* navigation links, or |NULL| if not supplied */
	struct linked_list *plugins; /* of |weave_plugin|: these are for HTML extensions */

	/* used for workspace during an actual weave: */
	struct source_line *current_weave_line;
	struct linked_list *footnotes_cued; /* of |text_stream| */
	struct linked_list *footnotes_written; /* of |text_stream| */
	struct text_stream *current_footnote;
	MEMORY_MANAGEMENT
} weave_order;

@<Compile a set of instructions for the weaver@> =
	wv = CREATE(weave_order);
	wv->weave_web = W;
	wv->weave_range = Str::duplicate(range);
	wv->pattern = pattern;
	wv->theme_match = tag;
	wv->booklet_title = Str::new();
	wv->format = pattern->pattern_format;
	wv->post_processing_results = NULL;
	wv->cover_sheet_to_use = Str::new();
	wv->self_contained = FALSE;
	wv->navigation = navigation;
	wv->breadcrumbs = breadcrumbs;
	wv->plugins = NEW_LINKED_LIST(weave_plugin);
	if (Reader::web_has_one_section(W)) wv->self_contained = TRUE;
	Str::copy(wv->cover_sheet_to_use, I"cover-sheet");
	
	wv->current_weave_line = NULL;
	wv->footnotes_cued = NEW_LINKED_LIST(text_stream);
	wv->footnotes_written = NEW_LINKED_LIST(text_stream);
	wv->current_footnote = Str::new();

	int has_content = FALSE;
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			if (Reader::range_within(S->md->sect_range, wv->weave_range))
				has_content = TRUE;
	if (has_content == FALSE)
		Errors::fatal("no sections match that range");

	TEMPORARY_TEXT(leafname);
	@<Translate the subweb range into details of what to weave@>;
	pathname *H = W->redirect_weaves_to;
	if (H == NULL) H = into;
	if (H == NULL) {
		if (W->md->single_file == NULL)
	 		H = Reader::woven_folder(W);
	 	else
	 		H = Filenames::up(W->md->single_file);
	}
	if (to) {
		wv->weave_to = to;
		wv->self_contained = TRUE;
	} else wv->weave_to = Filenames::in(H, leafname);
	DISCARD_TEXT(leafname);

@ From the range and the theme, we work out the weave title, the leafname,
and details of any cover-sheet to use.

@<Translate the subweb range into details of what to weave@> =
	match_results mr = Regexp::create_mr();
	if (Str::eq_wide_string(range, L"0")) {
		wv->booklet_title = Str::new_from_wide_string(L"Complete Program");
		if (W->md->single_file) {
			Filenames::write_unextended_leafname(leafname, W->md->single_file);
		} else {
			WRITE_TO(leafname, "Complete");
		}
		if (wv->theme_match) @<Change the titling and leafname to match the tagged theme@>;
	} else if (Regexp::match(&mr, range, L"%d+")) {
		Str::clear(wv->booklet_title);
		WRITE_TO(wv->booklet_title, "Chapter %S", range);
		Str::copy(leafname, wv->booklet_title);
	} else if (Regexp::match(&mr, range, L"%[A-O]")) {
		Str::clear(wv->booklet_title);
		WRITE_TO(wv->booklet_title, "Appendix %S", range);
		Str::copy(leafname, wv->booklet_title);
	} else if (Str::eq_wide_string(range, L"P")) {
		wv->booklet_title = Str::new_from_wide_string(L"Preliminaries");
		Str::copy(leafname, wv->booklet_title);
	} else if (Str::eq_wide_string(range, L"M")) {
		wv->booklet_title = Str::new_from_wide_string(L"Manual");
		Str::copy(leafname, wv->booklet_title);
	} else {
		section *S = Reader::get_section_for_range(W, range);
		if (S) Str::copy(wv->booklet_title, S->md->sect_title);
		else Str::copy(wv->booklet_title, range);
		Str::copy(leafname, range);
		Str::clear(wv->cover_sheet_to_use);
	}
	Bibliographic::set_datum(W->md, I"Booklet Title", wv->booklet_title);
	LOOP_THROUGH_TEXT(P, leafname)
		if ((Str::get(P) == '/') || (Str::get(P) == ' '))
			Str::put(P, '-');
	WRITE_TO(leafname, "%S", Formats::file_extension(wv->format));
	Regexp::dispose_of(&mr);

@<Change the titling and leafname to match the tagged theme@> =
	Str::clear(wv->booklet_title);
	WRITE_TO(wv->booklet_title, "Extracts: %S", wv->theme_match->tag_name);
	Str::copy(leafname, wv->theme_match->tag_name);

@ Each weave results in a compressed one-line printed report:

@<Report on the outcome of the weave to the console@> =
	PRINT("[%S: %S -> %f", wv->booklet_title, wv->format->format_name, wv->weave_to);
	Formats::report_on_post_processing(wv);
	PRINT("]\n");

@ =
void Swarm::ensure_plugin(weave_order *wv, text_stream *name) {
	weave_plugin *existing;
	LOOP_OVER_LINKED_LIST(existing, weave_plugin, wv->plugins)
		if (Str::eq_insensitive(name, existing->plugin_name))
			return;
	weave_plugin *wp = WeavePlugins::new(name);
	ADD_TO_LINKED_LIST(wp, weave_plugin, wv->plugins);
}

@ After every swarm, we rebuild the index. We first try for a template called
|chaptered-index.html| or |unchaptered-index.html|, then fall back on a
generic |index.html| if those aren't available in the current pattern.

=
void Swarm::weave_index_templates(web *W, text_stream *range, weave_pattern *pattern,
	pathname *into, filename *nav, linked_list *crumbs) {
	if (!(Bibliographic::data_exists(W->md, I"Version Number")))
		Bibliographic::set_datum(W->md, I"Version Number", I" ");
	text_stream *index_leaf = NULL;
	if (W->md->chaptered) index_leaf = I"chaptered-index.html";
	else index_leaf = I"unchaptered-index.html";
	filename *INF = Patterns::obtain_filename(pattern, index_leaf);
	if (INF == NULL) INF = Patterns::obtain_filename(pattern, I"index.html");
	if (INF) {
		pathname *H = W->redirect_weaves_to;
		if (H == NULL) H = Reader::woven_folder(W);
		filename *Contents = Filenames::in(H, I"index.html");
		text_stream TO_struct; text_stream *OUT = &TO_struct;
		if (STREAM_OPEN_TO_FILE(OUT, Contents, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write contents file", Contents);
		if (W->as_ebook)
			Epub::note_page(W->as_ebook, Contents, I"Index", I"index");
		Indexer::set_current_file(Contents);
		PRINT("[Index file: %f]\n", Contents);
		Indexer::incorporate_template(OUT, W, range, INF, pattern, nav, crumbs);
		STREAM_CLOSE(OUT);
	}
	Patterns::copy_payloads_into_weave(W, pattern);
}
