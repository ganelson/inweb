[PlainText::] Plain Text Format.

To provide for weaving in plain text format, which is not very
interesting, but ought to be available.

@h Creation.

=
void PlainText::create(void) {
	weave_format *wf = Formats::create_weave_format(I"plain", I".txt");
	METHOD_ADD(wf, RENDER_FOR_MTID, PlainText::render);
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
	if ((N->type == weave_document_node_type) ||
		(N->type == weave_head_node_type) ||
		(N->type == weave_body_node_type) ||
		(N->type == weave_tail_node_type) ||
		(N->type == weave_chapter_title_page_node_type) ||
		(N->type == weave_chapter_footer_node_type) ||
		(N->type == weave_figure_node_type) ||
		(N->type == weave_audio_node_type) ||
		(N->type == weave_material_node_type) ||
		(N->type == weave_chapter_node_type) ||
		(N->type == weave_carousel_slide_node_type) ||
		(N->type == weave_toc_node_type) ||
		(N->type == weave_toc_line_node_type) ||
		(N->type == weave_grammar_index_node_type) ||
		(N->type == weave_inline_node_type)) @<Render nothing@>

	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_chapter_header_node_type) @<Render chapter header@>
	else if (N->type == weave_section_header_node_type) @<Render header@>
	else if (N->type == weave_section_footer_node_type) @<Render footer@>
	else if (N->type == weave_section_purpose_node_type) @<Render purpose@>
	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_bar_node_type) @<Render bar@>
	else if (N->type == weave_pagebreak_node_type) @<Render pagebreak@>
	else if (N->type == weave_linebreak_node_type) @<Render linebreak@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_pmac_node_type) @<Render pmac@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_section_node_type) @<Render section@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_commentary_node_type) @<Render commentary@>
	else if (N->type == weave_defn_node_type) @<Render defn@>
	else if (N->type == weave_source_code_node_type) @<Render source code@>
	else if (N->type == weave_url_node_type) @<Render URL@>
	else if (N->type == weave_footnote_cue_node_type) @<Render footnote cue@>
	else if (N->type == weave_begin_footnote_text_node_type) @<Render footnote text@>
	else if (N->type == weave_display_line_node_type) @<Render display line@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_item_node_type) @<Render item@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_maths_node_type) @<Render maths@>

	else internal_error("unable to render unknown node");
	return TRUE;
}

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	WRITE("%S\n\n", C->chap->md->ch_title);
	section *S;
	LOOP_OVER_LINKED_LIST(S, section, C->chap->sections)
		WRITE("  %S\n    %S\n",
			S->md->sect_title, S->sect_purpose);
	WRITE("\n");

@<Render header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	WRITE("%S\n\n", C->sect->md->sect_title);

@<Render footer@> =
	WRITE("\n\n");

@<Render purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	WRITE("%S\n\n", C->purpose);

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	WRITE("%S\n\n", C->text);

@<Render bar@> =
	WRITE("\n----------------------------------------------------------------------\n\n");

@<Render pagebreak@> =
	;

@<Render linebreak@> =
	WRITE("\n");

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	WRITE("\n");
	WRITE("%S%S", C->para->ornament, C->para->paragraph_number);
	if (Str::len(C->para->heading_text) > 0) WRITE(" %S", C->para->heading_text);
	WRITE(".  ");

@<Render endnote@> =
	@<Recurse tne renderer through children nodes@>;
	WRITE("\n");
	return FALSE;

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render nothing@> =
	;

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	WRITE("[See %S video with ID %S.]\n", C->service, C->ID);

@<Render pmac@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	WRITE("<%S (%S)>%s",
		C->pmac->macro_name, C->pmac->defining_paragraph->paragraph_number,
		(C->defn)?" =":"");

@<Render vskip@> =
	WRITE("\n");

@<Render section@> =
	weave_section_node *C = RETRIEVE_POINTER_weave_section_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render code line@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &PlainText::render_visit, (void *) prs, L+1);
	WRITE("\n");
	return FALSE;

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	WRITE("%S", C->fn->function_name);
	return FALSE;

@<Render commentary@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	if (C->in_code) WRITE(" /* ");
	WRITE("%S", C->text);
	if (C->in_code) WRITE(" */ ");

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	WRITE("%S ", C->keyword);

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	WRITE("%S", C->matter);

@<Render URL@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	WRITE("%S", C->url);

@<Render footnote cue@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	WRITE("[%S]", C->cue_text);

@<Render footnote text@> =
	WRITE("\n");

@<Render display line@> =
	weave_display_line_node *C = RETRIEVE_POINTER_weave_display_line_node(N->content);
	WRITE("    %S\n", C->text);

@<Render function defn@> =
	weave_function_defn_node *C = RETRIEVE_POINTER_weave_function_defn_node(N->content);
	WRITE("%S", C->fn->function_name);
	return TRUE;

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	for (int i=1; i<C->depth; i++) WRITE("  ");
	WRITE("(%S) ", C->label);

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	WRITE("%S%S", C->par1->ornament, C->par1->paragraph_number);
	if (C->par2) WRITE("-%S", C->par2->paragraph_number);

@<Render maths@> =
	weave_maths_node *C = RETRIEVE_POINTER_weave_maths_node(N->content);
	if (C->displayed) WRITE("\n");
	WRITE("%S", C->content);
	if (C->displayed) WRITE("\n\n");

@<Recurse tne renderer through children nodes@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &PlainText::render_visit, (void *) prs, L+1);
