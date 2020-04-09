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
weave_target *swarm_leader = NULL; /* the most inclusive one we weave */

void Swarm::weave(web *W, text_stream *range, int swarm_mode, theme_tag *tag,
	weave_pattern *pattern, filename *to, pathname *into, int docs_mode,
	linked_list *breadcrumbs, filename *navigation) {
	swarm_leader = NULL;
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		if (C->md->imported == FALSE) {
			if (swarm_mode == SWARM_CHAPTERS_SWM)
				if ((W->md->chaptered == TRUE) && (Reader::range_within(C->md->ch_range, range))) {
					C->ch_weave = Swarm::weave_subset(W,
						C->md->ch_range, FALSE, tag, pattern, to, into, docs_mode,
						breadcrumbs, navigation);
					if (Str::len(range) > 0) swarm_leader = C->ch_weave;
				}
			if (swarm_mode == SWARM_SECTIONS_SWM)
				LOOP_OVER_LINKED_LIST(S, section, C->sections)
					if (Reader::range_within(S->sect_range, range))
						S->sect_weave = Swarm::weave_subset(W,
							S->sect_range, FALSE, tag, pattern, to, into, docs_mode,
							breadcrumbs, navigation);
		}

	Swarm::weave_index_templates(W, range, pattern, (to)?TRUE:FALSE, into, navigation,
		breadcrumbs, docs_mode);
}

@ The following is where an individual weave task begins, whether it comes
from the swarm, or has been specified at the command line (in which case
the call comes from Program Control).

=
weave_target *Swarm::weave_subset(web *W, text_stream *range, int open_afterwards,
	theme_tag *tag, weave_pattern *pattern, filename *to, pathname *into, int docs_mode,
	linked_list *breadcrumbs, filename *navigation) {
	weave_target *wt = NULL;
	if (no_inweb_errors == 0) {
		Analyser::analyse_code(W);
		@<Compile a set of instructions for the weaver@>;
		if (Weaver::weave_source(W, wt) == 0) /* i.e., the number of lines woven was zero */
			Errors::fatal("empty weave request");
		Formats::post_process_weave(wt, open_afterwards); /* e.g., run through TeX */
		@<Report on the outcome of the weave to the console@>;
	}
	return wt;
}

@ Each individual weave generates one of the following sets of instructions:

=
typedef struct weave_target {
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
	int docs_mode; /* make as part of a |-weave-docs| run */
	struct linked_list *breadcrumbs; /* non-standard breadcrumb trail, if any */
	struct filename *navigation; /* navigation links, or |NULL| if not supplied */
	MEMORY_MANAGEMENT
} weave_target;

@<Compile a set of instructions for the weaver@> =
	wt = CREATE(weave_target);
	wt->weave_web = W;
	wt->weave_range = Str::duplicate(range);
	wt->pattern = pattern;
	wt->theme_match = tag;
	wt->booklet_title = Str::new();
	wt->format = pattern->pattern_format;
	wt->post_processing_results = NULL;
	wt->cover_sheet_to_use = Str::new();
	wt->self_contained = FALSE;
	wt->docs_mode = docs_mode;
	wt->navigation = navigation;
	wt->breadcrumbs = breadcrumbs;
	if (Reader::web_has_one_section(W)) wt->self_contained = TRUE;
	Str::copy(wt->cover_sheet_to_use, I"cover-sheet");

	int has_content = FALSE;
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			if (Reader::range_within(S->sect_range, wt->weave_range))
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
	 		H = Filenames::get_path_to(W->md->single_file);
	}
	if (to) {
		wt->weave_to = to;
		wt->self_contained = TRUE;
	} else wt->weave_to = Filenames::in_folder(H, leafname);
	DISCARD_TEXT(leafname);

@ From the range and the theme, we work out the weave title, the leafname,
and details of any cover-sheet to use.

@<Translate the subweb range into details of what to weave@> =
	match_results mr = Regexp::create_mr();
	if (Str::eq_wide_string(range, L"0")) {
		wt->booklet_title = Str::new_from_wide_string(L"Complete Program");
		if (W->md->single_file) {
			Filenames::write_unextended_leafname(leafname, W->md->single_file);
		} else {
			WRITE_TO(leafname, "Complete");
		}
		if (wt->theme_match) @<Change the titling and leafname to match the tagged theme@>;
	} else if (Regexp::match(&mr, range, L"%d+")) {
		Str::clear(wt->booklet_title);
		WRITE_TO(wt->booklet_title, "Chapter %S", range);
		Str::copy(leafname, wt->booklet_title);
	} else if (Regexp::match(&mr, range, L"%[A-O]")) {
		Str::clear(wt->booklet_title);
		WRITE_TO(wt->booklet_title, "Appendix %S", range);
		Str::copy(leafname, wt->booklet_title);
	} else if (Str::eq_wide_string(range, L"P")) {
		wt->booklet_title = Str::new_from_wide_string(L"Preliminaries");
		Str::copy(leafname, wt->booklet_title);
	} else if (Str::eq_wide_string(range, L"M")) {
		wt->booklet_title = Str::new_from_wide_string(L"Manual");
		Str::copy(leafname, wt->booklet_title);
	} else {
		section *S = Reader::get_section_for_range(W, range);
		if (S) Str::copy(wt->booklet_title, S->md->sect_title);
		else Str::copy(wt->booklet_title, range);
		Str::copy(leafname, range);
		Str::clear(wt->cover_sheet_to_use);
	}
	Bibliographic::set_datum(W->md, I"Booklet Title", wt->booklet_title);
	LOOP_THROUGH_TEXT(P, leafname)
		if ((Str::get(P) == '/') || (Str::get(P) == ' '))
			Str::put(P, '-');
	WRITE_TO(leafname, "%S", Formats::file_extension(wt->format));
	Regexp::dispose_of(&mr);

@<Change the titling and leafname to match the tagged theme@> =
	Str::clear(wt->booklet_title);
	WRITE_TO(wt->booklet_title, "Extracts: %S", wt->theme_match->tag_name);
	Str::copy(leafname, wt->theme_match->tag_name);

@ Each weave results in a compressed one-line printed report:

@<Report on the outcome of the weave to the console@> =
	PRINT("[%S: %S -> %f", wt->booklet_title, wt->format->format_name, wt->weave_to);
	Formats::report_on_post_processing(wt);
	PRINT("]\n");

@ After every swarm, we rebuild the index. We first try for a template called
|chaptered-index.html| or |unchaptered-index.html|, then fall back on a
generic |index.html| if those aren't available in the current pattern.

=
void Swarm::weave_index_templates(web *W, text_stream *range, weave_pattern *pattern,
	int self_contained, pathname *into, filename *F, linked_list *crumbs, int docs) {
	if (!(Bibliographic::data_exists(W->md, I"Version Number")))
		Bibliographic::set_datum(W->md, I"Version Number", I" ");
	text_stream *index_leaf = NULL;
	if (W->md->chaptered) index_leaf = I"chaptered-index.html";
	else index_leaf = I"unchaptered-index.html";
	filename *OUT = Patterns::obtain_filename(pattern, index_leaf);
	if (OUT == NULL) OUT = Patterns::obtain_filename(pattern, I"index.html");
	if (OUT) Indexer::run(W, range, OUT, I"index.html", NULL, pattern, into, F, crumbs, docs, TRUE);
	if (self_contained == FALSE) Patterns::copy_payloads_into_weave(W, pattern);
}
