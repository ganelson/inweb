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

@<Create EPUB@> =
	weave_format *wf = Formats::create_weave_format(I"ePub", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLFormat::render_EPUB);
	METHOD_ADD(wf, BEGIN_WEAVING_FOR_MTID, HTMLFormat::begin_weaving_EPUB);
	METHOD_ADD(wf, END_WEAVING_FOR_MTID, HTMLFormat::end_weaving_EPUB);

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
	struct colour_scheme *colours;
	int EPUB_flag;
	int popup_counter;
	int last_material_seen;
	int carousel_number;
	int slide_number;
	int slide_of;
} HTML_render_state;

void HTMLFormat::render_inner(weave_format *self, text_stream *OUT, heterogeneous_tree *tree, int EPUB_mode) {
	TEMPORARY_TEXT(interior);
	HTML_render_state hrs;
	hrs.OUT = interior;
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	hrs.wv = C->wv;
	hrs.EPUB_flag = EPUB_mode;
	hrs.popup_counter = 1;
	hrs.last_material_seen = -1;
	hrs.carousel_number = 1;
	hrs.slide_number = -1;
	hrs.slide_of = -1;
	Swarm::ensure_plugin(C->wv, I"Base");
	hrs.colours = Swarm::ensure_colour_scheme(C->wv, I"Colours", I"");

	Trees::traverse_from(tree->root, &HTMLFormat::render_visit, (void *) &hrs, 0);
	HTML::declare_as_HTML(OUT, EPUB_mode);
	if (EPUB_mode)
		Epub::note_page(C->wv->weave_web->as_ebook, C->wv->weave_to, C->wv->booklet_title, I"");
	Indexer::cover_sheet_maker(OUT, C->wv->weave_web, I"template", C->wv, WEAVE_FIRST_HALF);
	WRITE("%S", interior);
	HTML::completed(OUT);
	Bibliographic::set_datum(C->wv->weave_web->md, I"Booklet Title", C->wv->booklet_title);
	Indexer::cover_sheet_maker(OUT, C->wv->weave_web, I"template", C->wv, WEAVE_SECOND_HALF);

	DISCARD_TEXT(interior);
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
	else if (N->type == weave_material_node_type) @<Render material@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_pmac_node_type) @<Render pmac@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_apres_defn_node_type) @<Render nothing@>
	else if (N->type == weave_chapter_node_type) @<Render nothing@>
	else if (N->type == weave_section_node_type) @<Render section@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_commentary_node_type) @<Render commentary@>
	else if (N->type == weave_carousel_slide_node_type) @<Render carousel slide@>
	else if (N->type == weave_toc_node_type) @<Render toc@>
	else if (N->type == weave_toc_line_node_type) @<Render toc line@>
	else if (N->type == weave_chapter_title_page_node_type) @<Render weave_chapter_title_page_node@>
	else if (N->type == weave_defn_node_type) @<Render defn@>
	else if (N->type == weave_source_code_node_type) @<Render source code@>
	else if (N->type == weave_url_node_type) @<Render URL@>
	else if (N->type == weave_footnote_cue_node_type) @<Render footnote cue@>
	else if (N->type == weave_begin_footnote_text_node_type) @<Render footnote@>
	else if (N->type == weave_display_line_node_type) @<Render display line@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_item_node_type) @<Render item@>
	else if (N->type == weave_grammar_index_node_type) @<Render nothing@>
	else if (N->type == weave_inline_node_type) @<Render inline@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_maths_node_type) @<Render maths@>
	else internal_error("unable to render unknown node");
	return TRUE;
}

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	HTML::comment(OUT, C->banner);
	html_in_para = HTML_OUT;

@<Render header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	Swarm::ensure_plugin(hrs->wv, I"Breadcrumbs");
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
	HTML_OPEN("li");
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
	HTML_CLOSE("li");
	return FALSE;

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	HTMLFormat::exit_current_paragraph(OUT);
	filename *F = Filenames::in(
		Pathnames::down(hrs->wv->weave_web->md->path_to_web, I"Figures"),
		C->figname);
	filename *RF = Filenames::from_text(C->figname);
	HTML_OPEN("center");
	HTML::image_to_dimensions(OUT, RF, C->w, C->h);
	Patterns::copy_file_into_weave(hrs->wv->weave_web, F, NULL, NULL);
	HTML_CLOSE("center");
	WRITE("\n");

@<Render material@> =
	if (N->child) {
		int first_in_para = FALSE;
		if (N == N->parent->child) first_in_para = TRUE;
		weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
		switch (C->material_type) {
			case CODE_MATERIAL:
				if (first_in_para) {
					HTMLFormat::cp(OUT);
				}
				TEMPORARY_TEXT(csname);
				WRITE_TO(csname, "%S-Colours", C->styling->language_name);
				hrs->colours = Swarm::ensure_colour_scheme(hrs->wv,
					csname, C->styling->language_name);
				DISCARD_TEXT(csname);
				TEMPORARY_TEXT(cl);
				WRITE_TO(cl, "%S", hrs->colours->prefix);
				if (C->plainly) WRITE_TO(cl, "undisplayed-code");
				else WRITE_TO(cl, "displayed-code");
				WRITE("<pre class=\"%S all-displayed-code\">\n", cl);
				DISCARD_TEXT(cl);
				break;
			case REGULAR_MATERIAL:
				if (first_in_para == FALSE) {
					WRITE("\n");
					HTMLFormat::p(OUT,"inwebparagraph");
				}
				break;
			case FOOTNOTES_MATERIAL:
				HTML_OPEN_WITH("ul", "class=\"footnotetexts\"");
				break;
			case ENDNOTES_MATERIAL:
				HTML_OPEN_WITH("ul", "class=\"endnotetexts\"");
				break;
			case MACRO_MATERIAL:
				if (first_in_para == FALSE) {
					WRITE("\n");
					HTMLFormat::p(OUT,"macrodefinition");
				}
				HTML_OPEN_WITH("code", "class=\"display\"");
				WRITE("\n");
				break;
			case DEFINITION_MATERIAL:
				if (first_in_para) {
					HTMLFormat::cp(OUT);
				}
				WRITE("\n");
				HTMLFormat::pre(OUT, "definitions");
				break;
		}
		for (tree_node *M = N->child; M; M = M->next)
			Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
		switch (C->material_type) {
			case CODE_MATERIAL:
				WRITE("</pre>");
				break;
			case REGULAR_MATERIAL:
				HTMLFormat::cp(OUT);
				break;
			case ENDNOTES_MATERIAL:
				HTML_CLOSE("ul");
				break;
			case FOOTNOTES_MATERIAL:
				HTML_CLOSE("ul");
				break;
			case MACRO_MATERIAL:
				HTML_CLOSE("code");
				HTMLFormat::cp(OUT);
				break;
			case DEFINITION_MATERIAL:
				HTMLFormat::cpre(OUT);
				break;
		}
		hrs->last_material_seen = C->material_type;
	}
	return FALSE;

@ This has to embed some Internet-sourced content. |service|
here is something like |YouTube| or |Soundcloud|, and |ID| is whatever code
that service uses to identify the video/audio in question.

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	HTMLFormat::embed(hrs->wv->format, OUT, hrs->wv, C->service, C->ID, C->w, C->h);

@<Render pmac@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	HTMLFormat::para_macro(hrs->wv->format, OUT, hrs->wv, C->pmac, C->defn);

@<Render vskip@> =
	weave_vskip_node *C = RETRIEVE_POINTER_weave_vskip_node(N->content);
	if (C->in_comment) {
		HTMLFormat::exit_current_paragraph(OUT);
		HTMLFormat::p(OUT,"inwebparagraph");
	} else {
		WRITE("\n");
	}

@<Render section@> =
	weave_section_node *C = RETRIEVE_POINTER_weave_section_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render code line@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
	WRITE("\n");
	return FALSE;

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	HTML::begin_link_with_class(OUT, I"function-link", C->url);
	HTMLFormat::change_colour(NULL, OUT, hrs->wv, FUNCTION_COLOUR, FALSE, hrs->colours);
	WRITE("%S", C->fn->function_name);
	WRITE("</span>");
	HTML::end_link(OUT);

@<Render commentary@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	if (C->in_code) HTML_OPEN_WITH("span", "class=\"comment\"");
	HTMLFormat::commentary_text(hrs->wv->format, OUT, hrs->wv, C->text);
	if (C->in_code) HTML_CLOSE("span");

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	Swarm::ensure_plugin(hrs->wv, I"Carousel");
	TEMPORARY_TEXT(carousel_id)
	TEMPORARY_TEXT(carousel_dots_id)
	text_stream *caption_class = NULL;
	text_stream *slide_count_class = I"carousel-number";
	switch (C->caption_command) {
		case CAROUSEL_CMD: caption_class = I"carousel-caption"; break;
		case CAROUSEL_ABOVE_CMD: caption_class = I"carousel-caption-above"; slide_count_class = I"carousel-number-above"; break;
		case CAROUSEL_BELOW_CMD: caption_class = I"carousel-caption-below"; slide_count_class = I"carousel-number-below"; break;
	}
	WRITE_TO(carousel_id, "carousel-no-%d", hrs->carousel_number);
	WRITE_TO(carousel_dots_id, "carousel-dots-no-%d", hrs->carousel_number);
	if (hrs->slide_number == -1) {
		hrs->slide_number = 1;
		hrs->slide_of = 0;
		for (tree_node *X = N; (X) && (X->type == N->type); X = X->next) hrs->slide_of++;
	} else {
		hrs->slide_number++;
		if (hrs->slide_number > hrs->slide_of) internal_error("miscounted slides");
	}
	if (hrs->slide_number == 1) {
		WRITE("<div class=\"carousel-container\" id=\"%S\">\n", carousel_id);
	}
	WRITE("<div class=\"carousel-slide fading-slide\"");
	if (hrs->slide_number == 1) WRITE(" style=\"display: block;\"");
	else WRITE(" style=\"display: none;\"");
	WRITE(">\n");
	if (C->caption_command == CAROUSEL_ABOVE_CMD) {
		@<Place caption here@>;
		WRITE("<div class=\"%S\">%d / %d</div>\n", slide_count_class, hrs->slide_number, hrs->slide_of);
	} else {
		WRITE("<div class=\"%S\">%d / %d</div>\n", slide_count_class, hrs->slide_number, hrs->slide_of);
	}
	WRITE("<div class=\"carousel-content\">");
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
	WRITE("</div>\n");
	if (C->caption_command != CAROUSEL_ABOVE_CMD) @<Place caption here@>;
	WRITE("</div>\n");
	if (hrs->slide_number == hrs->slide_of) {
		WRITE("<a class=\"carousel-prev-button\" onclick=\"carouselMoveSlide(&quot;%S&quot;, &quot;%S&quot;, -1)\">&#10094;</a>\n", carousel_id, carousel_dots_id);
		WRITE("<a class=\"carousel-next-button\" onclick=\"carouselMoveSlide(&quot;%S&quot;, &quot;%S&quot;, 1)\">&#10095;</a>\n", carousel_id, carousel_dots_id);
		WRITE("</div>\n");
		WRITE("<div class=\"carousel-dots-container\" id=\"%S\">\n", carousel_dots_id);
		for (int i=1; i<=hrs->slide_of; i++) {
			if (i == 1)
				WRITE("<span class=\"carousel-dot carousel-dot-active\" onclick=\"carouselSetSlide(&quot;%S&quot;, &quot;%S&quot;, 0)\"></span>\n", carousel_id, carousel_dots_id);
			else
				WRITE("<span class=\"carousel-dot\" onclick=\"carouselSetSlide(&quot;%S&quot;, &quot;%S&quot;, %d)\"></span>\n", carousel_id, carousel_dots_id, i-1);
		}
		WRITE("</div>\n");
		hrs->slide_number = -1;
		hrs->slide_of = -1;
		hrs->carousel_number++;
	}
	DISCARD_TEXT(carousel_id)
	DISCARD_TEXT(carousel_dots_id)
	return FALSE;

@<Place caption here@> =
	if (C->caption_command != CAROUSEL_UNCAPTIONED_CMD)
		WRITE("<div class=\"%S\">%S</div>\n", caption_class, C->caption);

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

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	HTML_OPEN_WITH("span", "class=\"definition-keyword\"");
	WRITE("%S", C->keyword);
	HTML_CLOSE("span");
	WRITE(" ");

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	int starts = FALSE;
	if (N == N->parent->child) starts = TRUE;
	HTMLFormat::source_code(hrs->wv->format, OUT, hrs->wv,
		C->matter, C->colouring, hrs->colours);
	
@<Render URL@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	HTML::begin_link_with_class(OUT, (C->external)?I"external":I"internal", C->url);
	WRITE("%S", C->content);
	HTML::end_link(OUT);

@<Render footnote cue@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	text_stream *fn_plugin_name =
		Bibliographic::get_datum(hrs->wv->weave_web->md, I"Footnotes Plugin");
	if (Str::ne_insensitive(fn_plugin_name, I"None"))	
		Swarm::ensure_plugin(hrs->wv, fn_plugin_name);
	WRITE("<sup id=\"fnref:%S\"><a href=\"#fn:%S\" rel=\"footnote\">%S</a></sup>",
		C->cue_text, C->cue_text, C->cue_text);

@<Render footnote@> =
	weave_begin_footnote_text_node *C = RETRIEVE_POINTER_weave_begin_footnote_text_node(N->content);
	text_stream *fn_plugin_name =
		Bibliographic::get_datum(hrs->wv->weave_web->md, I"Footnotes Plugin");
	if (Str::ne_insensitive(fn_plugin_name, I"None"))	
		Swarm::ensure_plugin(hrs->wv, fn_plugin_name);
	WRITE("<li class=\"footnote\" id=\"fn:%S\"><p class=\"inwebfootnote\">", C->cue_text);
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
	WRITE("<a href=\"#fnref:%S\" title=\"return to text\"> &#x21A9;</a></p></li>", C->cue_text);
	return FALSE;

@<Render display line@> =
	weave_display_line_node *C = RETRIEVE_POINTER_weave_display_line_node(N->content);
	HTMLFormat::exit_current_paragraph(OUT);
	HTML_OPEN("blockquote"); WRITE("\n"); INDENT;
	HTMLFormat::p(OUT, NULL);
	WRITE("%S", C->text);
	HTMLFormat::cp(OUT);
	OUTDENT; HTML_CLOSE("blockquote"); WRITE("\n");

@<Render function defn@> =
	weave_function_defn_node *C = RETRIEVE_POINTER_weave_function_defn_node(N->content);
	Swarm::ensure_plugin(hrs->wv, I"Popups");
	HTMLFormat::change_colour(NULL, OUT, hrs->wv, FUNCTION_COLOUR, FALSE, hrs->colours);
	WRITE("%S", C->fn->function_name);
	WRITE("</span>");
	WRITE("<button class=\"popup\" onclick=\"togglePopup('usagePopup%d')\">", hrs->popup_counter);
	WRITE("...");
	WRITE("<span class=\"popuptext\" id=\"usagePopup%d\">Usage of <b>%S</b>:<br>",
		hrs->popup_counter, C->fn->function_name);
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
	WRITE("</span>");
	WRITE("</button>");
	hrs->popup_counter++;
	return FALSE;

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	HTMLFormat::go_to_depth(OUT, C->depth);
	if (Str::len(C->label) > 0) WRITE("(%S) ", C->label);
	else WRITE(" ");

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render inline@> =
	HTML_OPEN_WITH("code", "class=\"display\"");
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);	
	HTML_CLOSE("code");
	return FALSE;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, C->par1, hrs->wv->weave_to);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	WRITE("%s%S",
		(Str::get_first_char(C->par1->ornament) == 'S')?"&#167;":"&para;",
		C->par1->paragraph_number);
	if (C->par2) WRITE("-%S", C->par2->paragraph_number);
	HTML::end_link(OUT);

@<Render maths@> =
	weave_maths_node *C = RETRIEVE_POINTER_weave_maths_node(N->content);
	text_stream *plugin_name =
		Bibliographic::get_datum(hrs->wv->weave_web->md, I"TeX Mathematics Plugin");
	if (Str::eq_insensitive(plugin_name, I"None")) {
		TEMPORARY_TEXT(R);
		TeX::remove_math_mode(R, C->content);
		HTMLFormat::escape_text(OUT, R);
		DISCARD_TEXT(R);
	} else {
		Swarm::ensure_plugin(hrs->wv, plugin_name);
		if (C->displayed) WRITE("$$"); else WRITE("\\(");
		HTMLFormat::escape_text(OUT, C->content);
		if (C->displayed) WRITE("$$"); else WRITE("\\)");
	}

@<Render nothing@> =
	;

@ =
void HTMLFormat::subheading(weave_format *self, text_stream *OUT, weave_order *wv,
	int level, text_stream *comment, text_stream *head) {
	HTMLFormat::exit_current_paragraph(OUT);
	switch (level) {
		case 1: HTML::heading(OUT, "h3", comment); break;
		case 2: HTMLFormat::p(OUT, "purpose");
			WRITE("%S", comment);
			if (head)
				WRITE(": "); HTMLFormat::commentary_text(self, OUT, wv, head);
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
void HTMLFormat::source_code(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *matter, text_stream *colouring, colour_scheme *cs) {
	int current_colour = -1, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(matter); i++) {
		colour_wanted = Str::get_at(colouring, i); @<Adjust code colour as necessary@>;
		if (Str::get_at(matter, i) == '<') WRITE("&lt;");
		else if (Str::get_at(matter, i) == '>') WRITE("&gt;");
		else if (Str::get_at(matter, i) == '&') WRITE("&amp;");
		else WRITE("%c", Str::get_at(matter, i));
	}
	if (current_colour >= 0) HTML_CLOSE("span");
	current_colour = -1;
}

@<Adjust code colour as necessary@> =
	if (colour_wanted != current_colour) {
		if (current_colour >= 0) HTML_CLOSE("span");
		HTMLFormat::change_colour(NULL, OUT, wv, colour_wanted, TRUE, cs);
		current_colour = colour_wanted;
	}

@ =
void HTMLFormat::embed(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *service, text_stream *ID, int w, int h) {
	text_stream *CH = I"405";
	text_stream *CW = I"720";
	if (w > 0) { Str::clear(CW); WRITE_TO(CW, "%d", w); }
	if (h > 0) { Str::clear(CH); WRITE_TO(CH, "%d", h); }
	HTMLFormat::exit_current_paragraph(OUT);
	
	TEMPORARY_TEXT(embed_leaf);
	WRITE_TO(embed_leaf, "%S.html", service);
	filename *F = Patterns::find_asset(wv->pattern, I"Embedding", embed_leaf);
	DISCARD_TEXT(embed_leaf);
	if (F == NULL) {
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
}

@ =
void HTMLFormat::para_macro(weave_format *self, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn) {
	paragraph *P = pmac->defining_paragraph;
	WRITE("&lt;");
	HTML_OPEN_WITH("span", "class=\"%s\"", (defn)?"named-paragraph-defn":"named-paragraph");
	WRITE("%S", pmac->macro_name);
	HTML_CLOSE("span");
	WRITE(" ");
	HTML_OPEN_WITH("span", "class=\"named-paragraph-number\"");
	WRITE("%S", P->paragraph_number);
	HTML_CLOSE("span");
	WRITE("&gt;%s", (defn)?" =":"");
}

@ =
void HTMLFormat::change_colour(weave_format *self, text_stream *OUT, weave_order *wv,
	int col, int in_code, colour_scheme *cs) {
	char *cl = "plain";
	switch (col) {
		case DEFINITION_COLOUR: 	cl = "definition-syntax"; break;
		case FUNCTION_COLOUR: 		cl = "function-syntax"; break;
		case IDENTIFIER_COLOUR: 	cl = "identifier-syntax"; break;
		case ELEMENT_COLOUR:		cl = "element-syntax"; break;
		case RESERVED_COLOUR: 		cl = "reserved-syntax"; break;
		case STRING_COLOUR: 		cl = "string-syntax"; break;
		case CHARACTER_COLOUR:      cl = "character-syntax"; break;
		case CONSTANT_COLOUR: 		cl = "constant-syntax"; break;
		case PLAIN_COLOUR: 			cl = "plain-syntax"; break;
		case EXTRACT_COLOUR: 		cl = "extract-syntax"; break;
		case COMMENT_COLOUR: 		cl = "comment-syntax"; break;
		default: PRINT("col: %d\n", col); internal_error("bad colour"); break;
	}
	HTML_OPEN_WITH("span", "class=\"%S%s\"", cs->prefix, cl);
}

@ =
void HTMLFormat::commentary_text(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
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

void HTMLFormat::escape_text(text_stream *OUT, text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
		if (Str::get_at(id, i) == '&') WRITE("&amp;");
		else if (Str::get_at(id, i) == '<') WRITE("&lt;");
		else if (Str::get_at(id, i) == '>') WRITE("&gt;");
		else PUT(Str::get_at(id, i));
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
	filename *CSS = Patterns::find_asset(pattern, I"Base", I"Base.css");
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
