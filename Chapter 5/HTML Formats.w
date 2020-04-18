[HTMLFormat::] HTML Formats.

To provide for weaving into HTML and into EPUB books.

@ =
void HTMLFormat::create(void) {
	@<Create HTML@>;
	@<Create EPUB@>;
}

@<Create HTML@> =
	weave_format *wf = Formats::create_weave_format(I"HTML", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLFormat::render);
	METHOD_ADD(wf, PRESERVE_MATH_MODE_FOR_MTID, HTMLFormat::preserve_math_mode);
	@<Make this format basically HTML@>;

@<Create EPUB@> =
	weave_format *wf = Formats::create_weave_format(I"ePub", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLFormat::render_EPUB);
	@<Make this format basically HTML@>;
	METHOD_ADD(wf, BEGIN_WEAVING_FOR_MTID, HTMLFormat::begin_weaving_EPUB);
	METHOD_ADD(wf, END_WEAVING_FOR_MTID, HTMLFormat::end_weaving_EPUB);

@<Make this format basically HTML@> =
	METHOD_ADD(wf, SOURCE_CODE_FOR_MTID, HTMLFormat::source_code);
	METHOD_ADD(wf, INLINE_CODE_FOR_MTID, HTMLFormat::inline_code);
	METHOD_ADD(wf, URL_FOR_MTID, HTMLFormat::url);
	METHOD_ADD(wf, FOOTNOTE_CUE_FOR_MTID, HTMLFormat::footnote_cue);
	METHOD_ADD(wf, BEGIN_FOOTNOTE_TEXT_FOR_MTID, HTMLFormat::begin_footnote_text);
	METHOD_ADD(wf, END_FOOTNOTE_TEXT_FOR_MTID, HTMLFormat::end_footnote_text);
	METHOD_ADD(wf, PARA_MACRO_FOR_MTID, HTMLFormat::para_macro);
	METHOD_ADD(wf, CHANGE_COLOUR_FOR_MTID, HTMLFormat::change_colour);
	METHOD_ADD(wf, COMMENTARY_TEXT_FOR_MTID, HTMLFormat::commentary_text);
	METHOD_ADD(wf, LOCALE_FOR_MTID, HTMLFormat::locale);

@h Current state.
To keep track of what we're writing, across many intermittent calls to the
routines below, we store a crude sort of state in two global variables.
(This isn't thread-safe and means we can only write one file at a time,
but in fact that's fine here.)

@d HTML_OUT 0 /* write position in HTML file is currently outside of p, pre, li */
@d HTML_IN_P 1 /* write position in HTML file is currently outside p */
@d HTML_IN_PRE 2 /* write position in HTML file is currently outside pre */
@d HTML_IN_LI 3 /* write position in HTML file is currently outside li */

=
int html_in_para = HTML_OUT; /* one of the above */
int item_depth = 0; /* for |HTML_IN_LI| only: how many lists we're nested inside */
int crumbs_dropped = FALSE;

void HTMLFormat::p(OUTPUT_STREAM, char *class) {
	if (class) HTML_OPEN_WITH("p", "class=\"%s\"", class)
	else HTML_OPEN("p");
	html_in_para = HTML_IN_P;
}

void HTMLFormat::cp(OUTPUT_STREAM) {
	HTML_CLOSE("p"); WRITE("\n");
	html_in_para = HTML_OUT;
}

void HTMLFormat::pre(OUTPUT_STREAM, char *class) {
	if (class) HTML_OPEN_WITH("pre", "class=\"%s\"", class)
	else HTML_OPEN("pre");
	WRITE("\n"); INDENT;
	html_in_para = HTML_IN_PRE;
}

void HTMLFormat::cpre(OUTPUT_STREAM) {
	OUTDENT; HTML_CLOSE("pre"); WRITE("\n");
	html_in_para = HTML_OUT;
}

@ Depth 1 means "inside a list entry"; depth 2, "inside an entry of a list
which is itself inside a list entry"; and so on.

=
void HTMLFormat::go_to_depth(OUTPUT_STREAM, int depth) {
	if (html_in_para != HTML_IN_LI) HTMLFormat::exit_current_paragraph(OUT);
	if (item_depth == depth) {
		HTML_CLOSE("li");
	} else {
		while (item_depth < depth) {
			HTML_OPEN_WITH("ul", "class=\"items\""); item_depth++;
		}
		while (item_depth > depth) {
			HTML_CLOSE("li");
			HTML_CLOSE("ul");
			WRITE("\n"); item_depth--;
		}
	}
	if (depth > 0) {
		HTML_OPEN("li");
		html_in_para = HTML_IN_LI;
	} else {
		html_in_para = HTML_OUT;
	}
}

@ The following generically gets us out of whatever we're currently into:

=
void HTMLFormat::exit_current_paragraph(OUTPUT_STREAM) {
	switch (html_in_para) {
		case HTML_IN_P: HTMLFormat::cp(OUT); break;
		case HTML_IN_PRE: HTMLFormat::cpre(OUT); break;
		case HTML_IN_LI: HTMLFormat::go_to_depth(OUT, 0); break;
	}
}

@h Methods.
For documentation, see "Weave Fornats".

=
void HTMLFormat::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	HTMLFormat::render_inner(self, OUT, tree, FALSE);
}

void HTMLFormat::render_EPUB(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	HTMLFormat::render_inner(self, OUT, tree, TRUE);
}

typedef struct HTML_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
	int EPUB_flag;
} HTML_render_state;

void HTMLFormat::render_inner(weave_format *self, text_stream *OUT, heterogeneous_tree *tree, int EPUB_mode) {
	HTML_render_state hrs;
	hrs.OUT = OUT;
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	hrs.wv = C->wv;
	hrs.EPUB_flag = EPUB_mode;
	Trees::traverse_from(tree->root, &HTMLFormat::render_visit, (void *) &hrs, 0);
}

int HTMLFormat::render_visit(tree_node *N, void *state, int L) {
	HTML_render_state *hrs = (HTML_render_state *) state;
	text_stream *OUT = hrs->OUT;
	if (N->type == weave_document_node_type) @<Render nothing@>
	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_body_node_type) @<Render nothing@>
	else if (N->type == weave_tail_node_type) @<Render tail@>
	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_chapter_header_node_type) @<Render nothing@>
	else if (N->type == weave_chapter_footer_node_type) @<Render nothing@>
	else if (N->type == weave_section_header_node_type) @<Render header@>
	else if (N->type == weave_section_footer_node_type) @<Render footer@>
	else if (N->type == weave_section_purpose_node_type) @<Render purpose@>
	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_bar_node_type) @<Render bar@>
	else if (N->type == weave_pagebreak_node_type) @<Render pagebreak@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
	else if (N->type == weave_chm_node_type) @<Render chm@>
	else if (N->type == weave_embed_node_type) @<Render weave_embed_node@>
	else if (N->type == weave_pmac_node_type) @<Render weave_pmac_node@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_apres_defn_node_type) @<Render weave_apres_defn_node@>
	else if (N->type == weave_change_colour_node_type) @<Render weave_change_colour_node@>
	else if (N->type == weave_text_node_type) @<Render weave_text_node@>
	else if (N->type == weave_comment_node_type) @<Render weave_comment_node@>
	else if (N->type == weave_link_node_type) @<Render weave_link_node@>
	else if (N->type == weave_commentary_node_type) @<Render weave_commentary_node@>
	else if (N->type == weave_preform_document_node_type) @<Render weave_preform_document_node@>
	else if (N->type == weave_toc_node_type) @<Render toc@>
	else if (N->type == weave_toc_line_node_type) @<Render toc line@>
	else if (N->type == weave_chapter_title_page_node_type) @<Render weave_chapter_title_page_node@>
	else if (N->type == weave_source_fragment_node_type) @<Render weave_source_fragment_node@>
	else if (N->type == weave_source_code_node_type) @<Render weave_source_code_node@>
	else if (N->type == weave_url_node_type) @<Render weave_url_node@>
	else if (N->type == weave_footnote_cue_node_type) @<Render weave_footnote_cue_node@>
	else if (N->type == weave_begin_footnote_text_node_type) @<Render weave_begin_footnote_text_node@>
	else if (N->type == weave_end_footnote_text_node_type) @<Render weave_end_footnote_text_node@>
	else if (N->type == weave_display_line_node_type) @<Render display line@>
	else if (N->type == weave_item_node_type) @<Render item@>
	else if (N->type == weave_grammar_index_node_type) @<Render nothing@>
	else internal_error("unable to render unknown node");
	return TRUE;
}

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	HTML::declare_as_HTML(OUT, hrs->EPUB_flag);
	if (hrs->EPUB_flag)
		Epub::note_page(hrs->wv->weave_web->as_ebook, hrs->wv->weave_to, hrs->wv->booklet_title, I"");
	Indexer::cover_sheet_maker(OUT, hrs->wv->weave_web, I"template", hrs->wv, WEAVE_FIRST_HALF);
	if (hrs->EPUB_flag == FALSE) {
		filename *CSS = Patterns::obtain_filename(hrs->wv->pattern, I"inweb.css");
		if (hrs->wv->pattern->hierarchical)
			Patterns::copy_up_file_into_weave(hrs->wv->weave_web, CSS);
		else
			Patterns::copy_file_into_weave(hrs->wv->weave_web, CSS);
	}
	HTML::comment(OUT, C->banner);
	html_in_para = HTML_OUT;

@<Render header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	if (crumbs_dropped == FALSE) {
		filename *Cr = Patterns::obtain_filename(hrs->wv->pattern, I"crumbs.gif");
		if (hrs->wv->pattern->hierarchical)
			Patterns::copy_up_file_into_weave(hrs->wv->weave_web, Cr);
		else
			Patterns::copy_file_into_weave(hrs->wv->weave_web, Cr);
		crumbs_dropped = TRUE;
	}
	HTML_OPEN_WITH("ul", "class=\"crumbs\"");
	Colonies::drop_initial_breadcrumbs(OUT,
		hrs->wv->weave_to, hrs->wv->breadcrumbs);
	text_stream *bct = Bibliographic::get_datum(hrs->wv->weave_web->md, I"Title");
	if (Str::len(Bibliographic::get_datum(hrs->wv->weave_web->md, I"Short Title")) > 0) {
		bct = Bibliographic::get_datum(hrs->wv->weave_web->md, I"Short Title");
	}
	if (hrs->wv->self_contained == FALSE) {
		Colonies::write_breadcrumb(OUT, bct, I"index.html");
		if (hrs->wv->weave_web->md->chaptered) {
			TEMPORARY_TEXT(chapter_link);
			WRITE_TO(chapter_link, "index.html#%s%S", (hrs->wv->weave_web->as_ebook)?"C":"",
				C->sect->owning_chapter->md->ch_range);
			Colonies::write_breadcrumb(OUT, C->sect->owning_chapter->md->ch_title, chapter_link);
			DISCARD_TEXT(chapter_link);
		}
		Colonies::write_breadcrumb(OUT, C->sect->md->sect_title, NULL);
	} else {
		Colonies::write_breadcrumb(OUT, bct, NULL);
	}
	HTML_CLOSE("ul");

@<Render footer@> =
	weave_section_footer_node *C = RETRIEVE_POINTER_weave_section_footer_node(N->content);
	HTMLFormat::tail(hrs->wv->format, OUT, hrs->wv, C->sect);

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	HTML::comment(OUT, C->rennab);
	HTML::completed(OUT);
	Bibliographic::set_datum(hrs->wv->weave_web->md, I"Booklet Title", hrs->wv->booklet_title);
	Indexer::cover_sheet_maker(OUT, hrs->wv->weave_web, I"template", hrs->wv, WEAVE_SECOND_HALF);

@<Render purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	HTMLFormat::subheading(hrs->wv->format, OUT, hrs->wv, 2, C->purpose, NULL);

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	HTMLFormat::subheading(hrs->wv->format, OUT, hrs->wv, 1, C->text, NULL);

@<Render bar@> =
	HTMLFormat::exit_current_paragraph(OUT);
	HTML::hr(OUT, NULL);

@<Render pagebreak@> =
	;

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	paragraph *P = C->para;
	HTMLFormat::exit_current_paragraph(OUT);
	if (P == NULL) internal_error("no para");
	HTMLFormat::p(OUT, "inwebparagraph");
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_anchor(TEMP, P);
	HTML::anchor(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	HTML_OPEN("b");
	WRITE("%s%S", (Str::get_first_char(P->ornament) == 'S')?"&#167;":"&para;",
		P->paragraph_number);
	WRITE(". %S%s ", P->heading_text, (Str::len(P->heading_text) > 0)?".":"");
	HTML_CLOSE("b");

@<Render endnote@> =
	weave_endnote_node *C = RETRIEVE_POINTER_weave_endnote_node(N->content);
	HTMLFormat::exit_current_paragraph(OUT);
	HTMLFormat::p(OUT, "endnote");
	WRITE("%S", C->text);
	HTMLFormat::cp(OUT);

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	HTMLFormat::figure(hrs->wv->format, OUT, hrs->wv, C->figname, C->w, C->h);

@<Render chm@> =
	weave_chm_node *C = RETRIEVE_POINTER_weave_chm_node(N->content);
	HTMLFormat::change_material(hrs->wv->format, OUT, hrs->wv, C->old_material, C->new_material,
		C->content, C->plainly);

@ This has to embed some Internet-sourced content. |service|
here is something like |YouTube| or |Soundcloud|, and |ID| is whatever code
that service uses to identify the video/audio in question.

@<Render weave_embed_node@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	HTMLFormat::embed(hrs->wv->format, OUT, hrs->wv, C->service, C->ID);

@<Render weave_pmac_node@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render vskip@> =
	if (html_in_para == HTML_IN_PRE) {
		WRITE("\n");
	} else {
		int old_state = html_in_para, old_depth = item_depth;
		HTMLFormat::exit_current_paragraph(OUT);
		if ((old_state == HTML_IN_P) || ((old_state == HTML_IN_LI) && (old_depth > 1)))
			HTMLFormat::p(OUT,"inwebparagraph");
	}

@<Render weave_apres_defn_node@> =
	weave_apres_defn_node *C = RETRIEVE_POINTER_weave_apres_defn_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_change_colour_node@> =
	weave_change_colour_node *C = RETRIEVE_POINTER_weave_change_colour_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_text_node@> =
	weave_text_node *C = RETRIEVE_POINTER_weave_text_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_comment_node@> =
	weave_comment_node *C = RETRIEVE_POINTER_weave_comment_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_link_node@> =
	weave_link_node *C = RETRIEVE_POINTER_weave_link_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_commentary_node@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_preform_document_node@> =
	weave_preform_document_node *C = RETRIEVE_POINTER_weave_preform_document_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render toc@> =
	HTMLFormat::exit_current_paragraph(OUT);
	HTML_OPEN_WITH("ul", "class=\"toc\"");
	for (tree_node *M = N->child; M; M = M->next) {
		HTML_OPEN("li");
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
		HTML_CLOSE("li");
	}
	HTML_CLOSE("ul");
	HTML::hr(OUT, "tocbar");
	WRITE("\n");
	return FALSE;

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, C->para, hrs->wv->weave_to);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	WRITE("%s%S", (Str::get_first_char(C->para->ornament) == 'S')?"&#167;":"&para;",
		C->para->paragraph_number);
	WRITE(". %S", C->text2);
	HTML::end_link(OUT);

@<Render weave_chapter_title_page_node@> =
	weave_chapter_title_page_node *C = RETRIEVE_POINTER_weave_chapter_title_page_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_source_fragment_node@> =
	weave_source_fragment_node *C = RETRIEVE_POINTER_weave_source_fragment_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_source_code_node@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_url_node@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_footnote_cue_node@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_begin_footnote_text_node@> =
	weave_begin_footnote_text_node *C = RETRIEVE_POINTER_weave_begin_footnote_text_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render weave_end_footnote_text_node@> =
	weave_end_footnote_text_node *C = RETRIEVE_POINTER_weave_end_footnote_text_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render display line@> =
	weave_display_line_node *C = RETRIEVE_POINTER_weave_display_line_node(N->content);
	HTMLFormat::exit_current_paragraph(OUT);
	HTML_OPEN("blockquote"); WRITE("\n"); INDENT;
	HTMLFormat::p(OUT, NULL);
	WRITE("%S", C->text);
	HTMLFormat::cp(OUT);
	OUTDENT; HTML_CLOSE("blockquote"); WRITE("\n");

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	HTMLFormat::go_to_depth(OUT, C->depth);
	if (Str::len(C->label) > 0) WRITE("(%S) ", C->label);
	else WRITE(" ");

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render nothing@> =
	;

@ =
int HTMLFormat::preserve_math_mode(weave_format *self, weave_order *wv,
	text_stream *matter, text_stream *text) {
	text_stream *plugin_name =
		Bibliographic::get_datum(wv->weave_web->md, I"TeX Mathematics Plugin");
	if (Str::eq_insensitive(plugin_name, I"None")) return FALSE;
	int math_mode = FALSE, mode_exists = FALSE;
	for (int i=0; i<Str::len(text); i++) {
		switch (Str::get_at(text, i)) {
			case '$':
				mode_exists = TRUE;
				if (Str::get_at(text, i+1) == '$') {
					WRITE_TO(matter, "$$");
					i++; continue;
				}
				math_mode = (math_mode)?FALSE:TRUE;
				if (math_mode) WRITE_TO(matter, "\\(");
				else WRITE_TO(matter, "\\)");
				break;
			default:
				PUT_TO(matter, Str::get_at(text, i));
		}
	}
	if (mode_exists) Swarm::ensure_plugin(wv, plugin_name);
	return TRUE;
}

@ =
void HTMLFormat::subheading(weave_format *self, text_stream *OUT, weave_order *wv,
	int level, text_stream *comment, text_stream *head) {
	HTMLFormat::exit_current_paragraph(OUT);
	switch (level) {
		case 1: HTML::heading(OUT, "h3", comment); break;
		case 2: HTMLFormat::p(OUT, "purpose");
			WRITE("%S", comment);
			if (head) {
				WRITE(": ");
				Formats::text(OUT, wv, head);
			}
			HTMLFormat::cp(OUT);
			break;
	}
}

@ =
section *page_section = NULL;

void HTMLFormat::paragraph_heading(weave_format *self, text_stream *OUT,
	weave_order *wv, section *S, paragraph *P, text_stream *heading_text,
	int weight, int no_skip) {
	page_section = S;
	if (weight == 2) return; /* Skip section headings */
	if (weight == 3) return; /* Skip chapter headings */
	HTMLFormat::exit_current_paragraph(OUT);
	if (P == NULL) internal_error("no para");
	HTMLFormat::p(OUT, "inwebparagraph");
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_anchor(TEMP, P);
	HTML::anchor(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	HTML_OPEN("b");
	WRITE("%s%S", (Str::get_first_char(P->ornament) == 'S')?"&#167;":"&para;",
		P->paragraph_number);
	WRITE(". %S%s ", heading_text, (Str::len(heading_text) > 0)?".":"");
	HTML_CLOSE("b");
}

@ =
int popup_counter = 0;

void HTMLFormat::source_code(weave_format *self, text_stream *OUT, weave_order *wv,
	int tab_stops_of_indentation, text_stream *prefatory, text_stream *matter,
	text_stream *colouring, text_stream *concluding_comment,
	int starts, int finishes, int code_mode, int linked) {
	if (starts) {
		if (Str::len(prefatory) > 0) {
			HTML_OPEN_WITH("span", "class=\"definitionkeyword\"");
			WRITE("%S", prefatory);
			HTML_CLOSE("span");
			WRITE(" ");
			if (Str::eq(prefatory, I"enum")) {
				match_results mr = Regexp::create_mr();
				if (Regexp::match(&mr, matter, L"(%c*) from (%C+) *")) {
					HTMLFormat::source_code(self, OUT, wv, 0, NULL, mr.exp[0], colouring,
						concluding_comment, starts, FALSE, code_mode, linked);
					HTML_OPEN_WITH("span", "class=\"definitionkeyword\"");
					WRITE(" from ");
					HTML_CLOSE("span");
					HTMLFormat::source_code(self, OUT, wv, 0, NULL, mr.exp[1], colouring,
						concluding_comment, FALSE, finishes, code_mode, linked);
					Regexp::dispose_of(&mr);
					return;
				}
				Regexp::dispose_of(&mr);
			}
		} else
			for (int i=0; i<tab_stops_of_indentation; i++)
				WRITE("    ");
	}
	int current_colour = -1, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(matter); i++) {
		colour_wanted = Str::get_at(colouring, i); @<Adjust code colour as necessary@>;
		if (linked) {
			@<Pick up hyperlinking at the eleventh hour@>;
			text_stream *xref_notation = Bibliographic::get_datum(wv->weave_web->md,
				I"Cross-References Notation");
			if (Str::ne(xref_notation, I"Off"))
				@<Pick up cross-references at the eleventh hour@>;
		}
		if (Str::get_at(matter, i) == '<') WRITE("&lt;");
		else if (Str::get_at(matter, i) == '>') WRITE("&gt;");
		else if (Str::get_at(matter, i) == '&') WRITE("&amp;");
		else WRITE("%c", Str::get_at(matter, i));
	}
	if (current_colour >= 0) HTML_CLOSE("span");
	current_colour = -1;
	if (finishes) {
		if (Str::len(concluding_comment) > 0) {
			if (!starts) WRITE("    ");
			HTML_OPEN_WITH("span", "class=\"comment\"");
			Formats::text_comment(OUT, wv, concluding_comment);
			HTML_CLOSE("span");
		}
		WRITE("\n");
	}
}

@<Pick up hyperlinking at the eleventh hour@> =
	if ((Str::includes_at(matter, i, I"http://")) ||
		(Str::includes_at(matter, i, I"https://"))) {
		TEMPORARY_TEXT(before);
		Str::copy(before, matter); Str::truncate(before, i);
		TEMPORARY_TEXT(after);
		Str::substr(after, Str::at(matter, i), Str::end(matter));
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, after, L"(https*://%C+)(%c*)")) {
			Formats::url(OUT, wv, mr.exp[0], mr.exp[0], TRUE);
			i += Str::len(mr.exp[0]);
		}
		DISCARD_TEXT(before);
		DISCARD_TEXT(after);
	}

@<Pick up cross-references at the eleventh hour@> =
	int N = Str::len(xref_notation);
	if ((Str::includes_at(matter, i, xref_notation))) {
		int j = i + N+1;
		while (j < Str::len(matter)) {
			if (Str::includes_at(matter, j, xref_notation)) {
				TEMPORARY_TEXT(reference);
				Str::substr(reference, Str::at(matter, i + N), Str::at(matter, j));
				@<Attempt to resolve the cross-reference@>;
				DISCARD_TEXT(reference);
				break;
			}
			j++;
		}
	}

@<Attempt to resolve the cross-reference@> =
	TEMPORARY_TEXT(url);
	TEMPORARY_TEXT(title);
	if (Colonies::resolve_reference_in_weave(url, title, wv->weave_to, reference,
		wv->weave_web->md, wv->current_weave_line)) {
		Formats::url(OUT, wv, url, title, FALSE);
		i = j + N;
	}
	DISCARD_TEXT(url);
	DISCARD_TEXT(title);

@<Adjust code colour as necessary@> =
	if (colour_wanted != current_colour) {
		if (current_colour >= 0) HTML_CLOSE("span");
		Formats::change_colour(OUT, wv, colour_wanted, TRUE);
		current_colour = colour_wanted;
		if ((colour_wanted == FUNCTION_COLOUR) && (wv->current_weave_line) &&
			(wv->current_weave_line->category != TEXT_EXTRACT_LCAT)) {
			TEMPORARY_TEXT(fname);
			int j = i;
			while (Str::get_at(colouring, j) == FUNCTION_COLOUR)
				PUT_TO(fname, Str::get_at(matter, j++));
			if (Analyser::is_reserved_word_for_section(
				wv->current_weave_line->owning_section, fname, FUNCTION_COLOUR)) {
				source_line *defn_line = Analyser::get_defn_line(
					wv->current_weave_line->owning_section, fname, FUNCTION_COLOUR);
				if (wv->current_weave_line == defn_line) {
					language_function *fn = Analyser::get_function(
						wv->current_weave_line->owning_section, fname, FUNCTION_COLOUR);
					if ((defn_line) && (fn)	&& (fn->usage_described == FALSE)) {
						Swarm::ensure_plugin(wv, I"Popups");
						WRITE("%S", fname);
						WRITE("<button class=\"popup\" onclick=\"togglePopup('usagePopup%d')\">", popup_counter);
						WRITE("...");
						WRITE("<span class=\"popuptext\" id=\"usagePopup%d\">Usage of <b>%S</b>:<br>",
							popup_counter, fname);
						Weaver::show_function_usage(OUT, wv,
							defn_line->owning_paragraph, fn, TRUE);
						WRITE("</span>", popup_counter, fname);
						WRITE("</button>");
						i += Str::len(fname) - 1;
						popup_counter++;
						continue;
					}
				} else {
					if ((defn_line) && (defn_line->owning_paragraph)) {
						TEMPORARY_TEXT(TEMP)
						Colonies::paragraph_URL(TEMP, defn_line->owning_paragraph,
							wv->weave_to);
						HTML::begin_link(OUT, TEMP);
						DISCARD_TEXT(TEMP)
						WRITE("%S", fname);
						HTML::end_link(OUT);
						i += Str::len(fname) - 1;
						continue;
					}
				}
			}
			DISCARD_TEXT(fname);
		}
	}

@ =
void HTMLFormat::inline_code(weave_format *self, text_stream *OUT, weave_order *wv,
	int enter) {
	if (enter) {
		if (html_in_para == HTML_OUT) HTMLFormat::p(OUT, "inwebparagraph");
		HTML_OPEN_WITH("code", "class=\"display\"");
	} else {
		HTML_CLOSE("code");
	}
}

@ =
void HTMLFormat::url(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *url, text_stream *content, int external) {
	HTML::begin_link_with_class(OUT, (external)?I"external":I"internal", url);
	WRITE("%S", content);
	HTML::end_link(OUT);
}

@=
void HTMLFormat::footnote_cue(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *cue) {
	text_stream *fn_plugin_name =
		Bibliographic::get_datum(wv->weave_web->md, I"Footnotes Plugin");
	if (Str::ne_insensitive(fn_plugin_name, I"None"))	
		Swarm::ensure_plugin(wv, fn_plugin_name);
	WRITE("<sup id=\"fnref:%S\"><a href=\"#fn:%S\" rel=\"footnote\">%S</a></sup>",
		cue, cue, cue);
}

@=
void HTMLFormat::begin_footnote_text(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *cue) {
	text_stream *fn_plugin_name =
		Bibliographic::get_datum(wv->weave_web->md, I"Footnotes Plugin");
	if (Str::ne_insensitive(fn_plugin_name, I"None"))	
		Swarm::ensure_plugin(wv, fn_plugin_name);
	WRITE("<li class=\"footnote\" id=\"fn:%S\"><p class=\"inwebfootnote\">", cue);	
}

@=
void HTMLFormat::end_footnote_text(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *cue) {
	text_stream *fn_plugin_name =
		Bibliographic::get_datum(wv->weave_web->md, I"Footnotes Plugin");
	if (Str::ne_insensitive(fn_plugin_name, I"None"))	
		Swarm::ensure_plugin(wv, fn_plugin_name);
	WRITE("<a href=\"#fnref:%S\" title=\"return to text\"> &#x21A9;</a></p></li>", cue);
}

@ =
void HTMLFormat::display_line(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *from) {
	HTMLFormat::exit_current_paragraph(OUT);
	HTML_OPEN("blockquote"); WRITE("\n"); INDENT;
	HTMLFormat::p(OUT, NULL);
	WRITE("%S", from);
	HTMLFormat::cp(OUT);
	OUTDENT; HTML_CLOSE("blockquote"); WRITE("\n");
}

@ =
void HTMLFormat::figure(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *figname, int w, int h) {
	HTMLFormat::exit_current_paragraph(OUT);
	filename *F = Filenames::in(
		Pathnames::down(wv->weave_web->md->path_to_web, I"Figures"),
		figname);
	filename *RF = Filenames::from_text(figname);
	HTML_OPEN("center");
	HTML::image(OUT, RF);
	Patterns::copy_file_into_weave(wv->weave_web, F);
	HTML_CLOSE("center");
	WRITE("\n");
}

@ =
void HTMLFormat::embed(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *service, text_stream *ID) {
	text_stream *CH = I"405";
	text_stream *CW = I"720";
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, ID, L"(%c+) at (%c+) by (%c+)")) {
		CW = Str::duplicate(mr.exp[1]);
		CH = Str::duplicate(mr.exp[2]);
		ID = mr.exp[0];
	} else if (Regexp::match(&mr, ID, L"(%c+) at (%c+)")) {
		CH = Str::duplicate(mr.exp[1]);
		ID = mr.exp[0];
	}
	HTMLFormat::exit_current_paragraph(OUT);
	TEMPORARY_TEXT(embed_leaf);
	WRITE_TO(embed_leaf, "%S.html", service);
	filename *F = Filenames::in(	
		Pathnames::down(wv->weave_web->md->path_to_web, I"Embedding"), embed_leaf);
	if (TextFiles::exists(F) == FALSE)
		F = Filenames::in(	
			Pathnames::down(path_to_inweb, I"Embedding"), embed_leaf);
	DISCARD_TEXT(embed_leaf);

	if (TextFiles::exists(F) == FALSE) {
		Main::error_in_web(I"This is not a supported service", wv->current_weave_line);
		return;
	}

	Bibliographic::set_datum(wv->weave_web->md, I"Content ID", ID);
	Bibliographic::set_datum(wv->weave_web->md, I"Content Width", CW);
	Bibliographic::set_datum(wv->weave_web->md, I"Content Height", CH);
	HTML_OPEN("center");
	Indexer::incorporate_template_for_web_and_pattern(OUT, wv->weave_web, wv->pattern, F);
	HTML_CLOSE("center");
	WRITE("\n");
	Regexp::dispose_of(&mr);
}

@ =
void HTMLFormat::para_macro(weave_format *self, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn) {
	paragraph *P = pmac->defining_paragraph;
	WRITE("&lt;");
	HTML_OPEN_WITH("span", "class=\"%s\"", (defn)?"cwebmacrodefn":"cwebmacro");
	WRITE("%S", pmac->macro_name);
	HTML_CLOSE("span");
	WRITE(" ");
	HTML_OPEN_WITH("span", "class=\"cwebmacronumber\"");
	WRITE("%S", P->paragraph_number);
	HTML_CLOSE("span");
	WRITE("&gt;%s", (defn)?" =":"");
}

@ =
void HTMLFormat::blank_line(weave_format *self, text_stream *OUT, weave_order *wv,
	int in_comment) {
	if (html_in_para == HTML_IN_PRE) {
		WRITE("\n");
	} else {
		int old_state = html_in_para, old_depth = item_depth;
		HTMLFormat::exit_current_paragraph(OUT);
		if ((old_state == HTML_IN_P) || ((old_state == HTML_IN_LI) && (old_depth > 1)))
			HTMLFormat::p(OUT,"inwebparagraph");
	}
}

@ =
void HTMLFormat::change_material(weave_format *self, text_stream *OUT, weave_order *wv,
	int old_material, int new_material, int content, int plainly) {
	if (old_material != new_material) {
		if (old_material == MACRO_MATERIAL) HTML_CLOSE("code");
		if ((content) || (new_material != MACRO_MATERIAL))
			HTMLFormat::exit_current_paragraph(OUT);
		switch (old_material) {
			case CODE_MATERIAL:
			case REGULAR_MATERIAL:
				switch (new_material) {
					case CODE_MATERIAL:
						if (plainly) HTMLFormat::pre(OUT, "undisplay");
						else HTMLFormat::pre(OUT, "display");
						break;
					case DEFINITION_MATERIAL:
						WRITE("\n");
						HTMLFormat::pre(OUT, "definitions");
						break;
					case MACRO_MATERIAL:
						if (content) {
							WRITE("\n");
							HTMLFormat::p(OUT,"macrodefinition");
						}
						HTML_OPEN_WITH("code", "class=\"display\"");
						WRITE("\n");
						break;
					case REGULAR_MATERIAL:
						if (content) {
							WRITE("\n");
							HTMLFormat::p(OUT,"inwebparagraph");
						}
						break;
				}
				break;
			case MACRO_MATERIAL:
				switch (new_material) {
					case CODE_MATERIAL:
						WRITE("\n");
						HTMLFormat::pre(OUT, "displaydefn");
						break;
					case DEFINITION_MATERIAL:
						WRITE("\n");
						HTMLFormat::pre(OUT, "definitions");
						break;
				}
				break;
			case DEFINITION_MATERIAL:
				switch (new_material) {
					case CODE_MATERIAL:
						WRITE("\n");
						if (plainly) HTMLFormat::pre(OUT, "undisplay");
						else HTMLFormat::pre(OUT, "display");
						break;
					case MACRO_MATERIAL:
						WRITE("\n");
						HTMLFormat::p(OUT, "macrodefinition");
						HTML_OPEN_WITH("code", "class=\"display\"");
						WRITE("\n");
						break;
				}
				break;
			default:
				HTMLFormat::cpre(OUT);
				break;
		}
	}
}

@ =
void HTMLFormat::change_colour(weave_format *self, text_stream *OUT, weave_order *wv,
	int col, int in_code) {
	char *cl = "plain";
	switch (col) {
		case DEFINITION_COLOUR: 	cl = "cwebmacrotext"; break;
		case FUNCTION_COLOUR: 		cl = "functiontext"; break;
		case IDENTIFIER_COLOUR: 	cl = "identifier"; break;
		case ELEMENT_COLOUR:		cl = "element"; break;
		case RESERVED_COLOUR: 		cl = "reserved"; break;
		case STRING_COLOUR: 		cl = "string"; break;
		case CHAR_LITERAL_COLOUR:	cl = "character"; break;
		case CONSTANT_COLOUR: 		cl = "constant"; break;
		case PLAIN_COLOUR: 			cl = "plain"; break;
		case EXTRACT_COLOUR: 		cl = "extract"; break;
		case COMMENT_COLOUR: 		cl = "comment"; break;
		default: PRINT("col: %d\n", col); internal_error("bad colour"); break;
	}
	HTML_OPEN_WITH("span", "class=\"%s\"", cl);
}

@ =
void HTMLFormat::endnote(weave_format *self, text_stream *OUT, weave_order *wv, int end) {
	if (end == 1) {
		HTMLFormat::exit_current_paragraph(OUT);
		HTMLFormat::p(OUT, "endnote");
	} else {
		HTMLFormat::cp(OUT);
	}
}

@ =
void HTMLFormat::commentary_text(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
		if (html_in_para == HTML_OUT) HTMLFormat::p(OUT, "inwebparagraph");
		if (Str::get_at(id, i) == '&') WRITE("&amp;");
		else if (Str::get_at(id, i) == '<') WRITE("&lt;");
		else if (Str::get_at(id, i) == '>') WRITE("&gt;");
		else if ((i == 0) && (Str::get_at(id, i) == '-') &&
			(Str::get_at(id, i+1) == '-') &&
			((Str::get_at(id, i+2) == ' ') || (Str::get_at(id, i+2) == 0))) {
			WRITE("&mdash;"); i++;
		} else if ((Str::get_at(id, i) == ' ') && (Str::get_at(id, i+1) == '-') &&
			(Str::get_at(id, i+2) == '-') &&
			((Str::get_at(id, i+3) == ' ') || (Str::get_at(id, i+3) == '\n') ||
			(Str::get_at(id, i+3) == 0))) {
			WRITE(" &mdash;"); i+=2;
		} else PUT(Str::get_at(id, i));
	}
}

@ =
void HTMLFormat::locale(weave_format *self, text_stream *OUT, weave_order *wv,
	paragraph *par1, paragraph *par2) {
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, par1, wv->weave_to);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	WRITE("%s%S",
		(Str::get_first_char(par1->ornament) == 'S')?"&#167;":"&para;",
		par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
	HTML::end_link(OUT);
}

@ =
void HTMLFormat::tail(weave_format *self, text_stream *OUT, weave_order *wv, section *this_S) {
	HTMLFormat::exit_current_paragraph(OUT);
	chapter *C = this_S->owning_chapter;
	section *S, *last_S = NULL, *prev_S = NULL, *next_S = NULL;
	LOOP_OVER_LINKED_LIST(S, section, C->sections) {
		if (S == this_S) prev_S = last_S;
		if (last_S == this_S) next_S = S;
		last_S = S;
	}
	if ((prev_S) || (next_S)) {
		HTML::hr(OUT, "tocbar");
		HTML_OPEN_WITH("ul", "class=\"toc\"");
		HTML_OPEN("li");
		if (prev_S == NULL) WRITE("<i>(This section begins %S.)</i>", C->md->ch_title);
		else {
			TEMPORARY_TEXT(TEMP);
			Colonies::section_URL(TEMP, prev_S->md);
			HTML::begin_link(OUT, TEMP);
			WRITE("Back to '%S'", prev_S->md->sect_title);
			HTML::end_link(OUT);
			DISCARD_TEXT(TEMP);
		}
		HTML_CLOSE("li");
		HTML_OPEN("li");
		if (next_S == NULL) WRITE("<i>(This section ends %S.)</i>", C->md->ch_title);
		else {
			TEMPORARY_TEXT(TEMP);
			Colonies::section_URL(TEMP, next_S->md);
			HTML::begin_link(OUT, TEMP);
			WRITE("Continue with '%S'", next_S->md->sect_title);
			HTML::end_link(OUT);
			DISCARD_TEXT(TEMP);
		}
		HTML_CLOSE("li");
		HTML_CLOSE("ul");
		HTML::hr(OUT, "tocbar");
	}
}

@h EPUB-only methods.

=
int HTMLFormat::begin_weaving_EPUB(weave_format *wf, web *W, weave_pattern *pattern) {
	TEMPORARY_TEXT(T)
	WRITE_TO(T, "%S", Bibliographic::get_datum(W->md, I"Title"));
	W->as_ebook = Epub::new(T, "P");
	filename *CSS = Patterns::obtain_filename(pattern, I"inweb.css");
	Epub::use_CSS_throughout(W->as_ebook, CSS);
	Epub::attach_metadata(W->as_ebook, L"identifier", T);
	DISCARD_TEXT(T)

	pathname *P = Reader::woven_folder(W);
	W->redirect_weaves_to = Epub::begin_construction(W->as_ebook, P, NULL);
	Shell::copy(CSS, W->redirect_weaves_to, "");
	return SWARM_SECTIONS_SWM;
}

void HTMLFormat::end_weaving_EPUB(weave_format *wf, web *W, weave_pattern *pattern) {
	Epub::end_construction(W->as_ebook);
}
