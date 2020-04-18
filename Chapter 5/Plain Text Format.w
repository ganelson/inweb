[PlainText::] Plain Text Format.

To provide for weaving in plain text format, which is not very
interesting, but ought to be available.

@h Creation.

=
void PlainText::create(void) {
	weave_format *wf = Formats::create_weave_format(I"plain", I".txt");
	METHOD_ADD(wf, RENDER_FOR_MTID, PlainText::render);
	METHOD_ADD(wf, CHAPTER_TP_FOR_MTID, PlainText::chapter_title_page);
	METHOD_ADD(wf, SOURCE_CODE_FOR_MTID, PlainText::source_code);
	METHOD_ADD(wf, PARA_MACRO_FOR_MTID, PlainText::para_macro);
	METHOD_ADD(wf, COMMENTARY_TEXT_FOR_MTID, PlainText::commentary_text);
	METHOD_ADD(wf, LOCALE_FOR_MTID, PlainText::locale);
}

@h Methods.
For documentation, see "Weave Fornats".

=
typedef struct PlainText_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
} PlainText_render_state;

void PlainText::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	PlainText_render_state prs;
	prs.OUT = OUT;
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	prs.wv = C->wv;
	Trees::traverse_from(tree->root, &PlainText::render_visit, (void *) &prs, 0);
}

int PlainText::render_visit(tree_node *N, void *state, int L) {
	PlainText_render_state *prs = (PlainText_render_state *) state;
	text_stream *OUT = prs->OUT;
	if (N->type == weave_document_node_type) @<Render nothing@>
	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_body_node_type) @<Render nothing@>
	else if (N->type == weave_tail_node_type) @<Render tail@>
	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_chapter_header_node_type) @<Render chapter header@>
	else if (N->type == weave_chapter_footer_node_type) @<Render nothing@>
	else if (N->type == weave_section_header_node_type) @<Render header@>
	else if (N->type == weave_section_footer_node_type) @<Render nothing@>
	else if (N->type == weave_section_purpose_node_type) @<Render purpose@>
	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_bar_node_type) @<Render bar@>
	else if (N->type == weave_pagebreak_node_type) @<Render pagebreak@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_figure_node_type) @<Render nothing@>
	else if (N->type == weave_chm_node_type) @<Render nothing@>
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
	WRITE("[%S]\n", C->banner);

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	WRITE("[%S]\n", C->rennab);

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	WRITE("%S\n\n", C->chap->md->ch_title);

@<Render header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	WRITE("%S\n\n", C->sect->md->sect_title);

@<Render purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	PlainText::subheading(prs->wv->format, OUT, prs->wv, 2, C->purpose, NULL);

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	PlainText::subheading(prs->wv->format, OUT, prs->wv, 1, C->text, NULL);

@<Render bar@> =
	WRITE("\n----------------------------------------------------------------------\n\n");

@<Render pagebreak@> =
	;

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	WRITE("\n");
	PlainText::locale(prs->wv->format, OUT, prs->wv, C->para, NULL);
	WRITE(". %S    ", C->para->heading_text);

@<Render endnote@> =
	weave_endnote_node *C = RETRIEVE_POINTER_weave_endnote_node(N->content);
	WRITE("\n%S\n", C->text);

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render nothing@> =
	;

@<Render weave_embed_node@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	WRITE("[See %S video with ID %S.]\n", C->service, C->ID);

@<Render weave_pmac_node@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render vskip@> =
	WRITE("\n");

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
	weave_toc_node *C = RETRIEVE_POINTER_weave_toc_node(N->content);
	WRITE("%S.", C->text1);
	for (tree_node *M = N->child; M; M = M->next) {
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) prs, L+1);
		if (M->next) WRITE("; ");
	}
	WRITE("\n\n");
	return FALSE;

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	WRITE("%S %S", C->text1, C->text2);

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
	WRITE("    %S\n", C->text);

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	if (C->depth == 1) WRITE("%-4s  ", C->label);
	else WRITE("%-8s  ", C->label);

@ =
void PlainText::subheading(weave_format *self, text_stream *OUT, weave_order *wv,
	int level, text_stream *comment, text_stream *head) {
	WRITE("%S:\n", comment);
	if ((level == 2) && (head)) { Formats::text(OUT, wv, head); WRITE("\n\n"); }
}

@ =
void PlainText::toc(weave_format *self, text_stream *OUT, weave_order *wv, int stage,
	text_stream *text1, text_stream *text2, paragraph *P) {
	switch (stage) {
		case 1: WRITE("%S.", text1); break;
		case 2: WRITE("; "); break;
		case 3: WRITE("%S %S", text1, text2); break;
		case 4: WRITE("\n\n"); break;
	}
}

@ =
void PlainText::chapter_title_page(weave_format *self, text_stream *OUT,
	weave_order *wv, chapter *C) {
	WRITE("%S\n\n", C->md->rubric);
	section *S;
	LOOP_OVER_LINKED_LIST(S, section, C->sections)
		WRITE("    %S: %S\n        %S\n",
			S->md->sect_range, S->md->sect_title, S->sect_purpose);
}

@ =
void PlainText::source_code(weave_format *self, text_stream *OUT, weave_order *wv,
	int tab_stops_of_indentation, text_stream *prefatory, text_stream *matter,
	text_stream *colouring, text_stream *concluding_comment, int starts,
	int finishes, int code_mode, int linked) {
	if (starts) {
		for (int i=0; i<tab_stops_of_indentation; i++)
			WRITE("    ");
		if (Str::len(prefatory) > 0) WRITE("%S ", prefatory);
	}
	WRITE("%S", matter);
	if (finishes) {
		if (Str::len(concluding_comment) > 0) WRITE("[%S]", concluding_comment);
		WRITE("\n");
	}
}

@ =
void PlainText::para_macro(weave_format *self, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn) {
	WRITE("<%S (%S)>%s",
		pmac->macro_name, pmac->defining_paragraph->paragraph_number,
		(defn)?" =":"");
}

@ =
void PlainText::blank_line(weave_format *self, text_stream *OUT, weave_order *wv,
	int in_comment) {
	WRITE("\n");
}

@ =
void PlainText::endnote(weave_format *self, text_stream *OUT, weave_order *wv,
	int end) {
	WRITE("\n");
}

@ =
void PlainText::commentary_text(weave_format *self, text_stream *OUT,
	weave_order *wv, text_stream *id) {
	WRITE("%S", id);
}

@ =
void PlainText::locale(weave_format *self, text_stream *OUT, weave_order *wv,
	paragraph *par1, paragraph *par2) {
	WRITE("%S%S", par1->ornament, par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
}
