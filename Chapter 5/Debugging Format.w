[Debugging::] Debugging Format.

A format which renders as a plain-text serialisation of the Inweb weave tree,
useful only for testing the weaver.

@h Creation.

=
void Debugging::create(void) {
	weave_format *wf = Formats::create_weave_format(I"debugging", I".txt");
	METHOD_ADD(wf, RENDER_FOR_MTID, Debugging::render);
}

@h Methods.
For documentation, see "Weave Fornats".

=
typedef struct debugging_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
} debugging_render_state;

void Debugging::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	debugging_render_state drs;
	drs.OUT = OUT;
	drs.wv = C->wv;
	Trees::traverse_from(tree->root, &Debugging::render_visit, (void *) &drs, 0);
}

int Debugging::render_visit(tree_node *N, void *state, int L) {
	debugging_render_state *drs = (debugging_render_state *) state;
	text_stream *OUT = drs->OUT;
	for (int i=0; i<L; i++) WRITE("  ");
	WRITE("%S", N->type->node_type_name);
	if (N->type == weave_document_node_type) @<Render document@>
	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_body_node_type) @<Render body@>
	else if (N->type == weave_tail_node_type) @<Render tail@>
	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_chapter_header_node_type) @<Render chapter header@>
	else if (N->type == weave_chapter_footer_node_type) @<Render chapter footer@>
	else if (N->type == weave_section_header_node_type) @<Render section header@>
	else if (N->type == weave_section_footer_node_type) @<Render section footer@>
	else if (N->type == weave_section_purpose_node_type) @<Render purpose@>
	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_bar_node_type) @<Render bar@>
	else if (N->type == weave_pagebreak_node_type) @<Render pagebreak@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraoh heading@>
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
	else if (N->type == weave_grammar_index_node_type) @<Render grammar index@>
	else WRITE("Unknown node");
	WRITE("\n");
	return TRUE;
}

@<Render document@> =
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(N->content);
	WRITE(" - weave order %d", C->wv->allocation_id);

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	WRITE(" - banner <%S>", C->banner);

@<Render body@> =
	;

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	WRITE(" - rennab <%S>", C->rennab);

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE(" - content %d chars", Str::len(C->content));

@<Render section header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	WRITE(" - section %S", C->sect->md->sect_title);

@<Render section footer@> =
	weave_section_footer_node *C = RETRIEVE_POINTER_weave_section_footer_node(N->content);
	WRITE(" - section %S", C->sect->md->sect_title);

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	WRITE(" - chapter %S", C->chap->md->ch_title);

@<Render chapter footer@> =
	weave_chapter_footer_node *C = RETRIEVE_POINTER_weave_chapter_footer_node(N->content);
	WRITE(" - chapter %S", C->chap->md->ch_title);

@<Render purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	WRITE(" - %S", C->purpose);

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	WRITE(" - %S", C->text);

@<Render bar@> =
	;

@<Render pagebreak@> =
	;

@<Render paragraoh heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	if (Str::len(C->para->heading_text) > 0) WRITE(" - title <%S>", C->para->heading_text);
	if (C->no_skip) WRITE(" (no skip)");

@<Render endnote@> =
	weave_endnote_node *C = RETRIEVE_POINTER_weave_endnote_node(N->content);
	WRITE(" <%S>", C->text);

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	WRITE(" <%S> %d by %d", C->figname, C->w, C->h);

@<Render chm@> =
	weave_chm_node *C = RETRIEVE_POINTER_weave_chm_node(N->content);
	WRITE(" %d -> %d", C->old_material, C->new_material);

@<Render weave_embed_node@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_pmac_node@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render vskip@> =
	weave_vskip_node *C = RETRIEVE_POINTER_weave_vskip_node(N->content);
	if (C->in_comment) WRITE(" (in comment)");

@<Render weave_apres_defn_node@> =
	weave_apres_defn_node *C = RETRIEVE_POINTER_weave_apres_defn_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_change_colour_node@> =
	weave_change_colour_node *C = RETRIEVE_POINTER_weave_change_colour_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_text_node@> =
	weave_text_node *C = RETRIEVE_POINTER_weave_text_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_comment_node@> =
	weave_comment_node *C = RETRIEVE_POINTER_weave_comment_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_link_node@> =
	weave_link_node *C = RETRIEVE_POINTER_weave_link_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_commentary_node@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_preform_document_node@> =
	weave_preform_document_node *C = RETRIEVE_POINTER_weave_preform_document_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render toc@> =
	weave_toc_node *C = RETRIEVE_POINTER_weave_toc_node(N->content);
	WRITE(" - <%S>", C->text1);

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	WRITE(" - <%S, %S> para %S", C->text1, C->text2, (C->para)?C->para->paragraph_number:I"NONE");

@<Render weave_chapter_title_page_node@> =
	weave_chapter_title_page_node *C = RETRIEVE_POINTER_weave_chapter_title_page_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_source_fragment_node@> =
	weave_source_fragment_node *C = RETRIEVE_POINTER_weave_source_fragment_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_source_code_node@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_url_node@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_footnote_cue_node@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_begin_footnote_text_node@> =
	weave_begin_footnote_text_node *C = RETRIEVE_POINTER_weave_begin_footnote_text_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render weave_end_footnote_text_node@> =
	weave_end_footnote_text_node *C = RETRIEVE_POINTER_weave_end_footnote_text_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render display line@> =
	weave_display_line_node *C = RETRIEVE_POINTER_weave_display_line_node(N->content);
	WRITE(" <%S>", C->text);

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	WRITE(" depth %d label <%S>", C->depth, C->label);

@<Render grammar index@> =
	;
