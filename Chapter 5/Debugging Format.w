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
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
	else if (N->type == weave_material_node_type) @<Render material@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_pmac_node_type) @<Render pmac@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_apres_defn_node_type) @<Render apres-defn@>
	else if (N->type == weave_chapter_node_type) @<Render chapter@>
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
	else if (N->type == weave_begin_footnote_text_node_type) @<Render footnote text@>
	else if (N->type == weave_display_line_node_type) @<Render display line@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_item_node_type) @<Render item@>
	else if (N->type == weave_grammar_index_node_type) @<Render grammar index@>
	else if (N->type == weave_inline_node_type) @<Render inline@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_maths_node_type) @<Render maths@>
	else WRITE("Unknown node");
	WRITE("\n");
	return TRUE;
}

@<Render document@> =
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(N->content);
	WRITE(" weave order %d", C->wv->allocation_id);

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	WRITE(" banner <%S>", C->banner);

@<Render body@> =
	;

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	WRITE(" rennab <%S>", C->rennab);

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	Debugging::show_text(OUT, C->content, 80);

@<Render section header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	WRITE(" <%S>", C->sect->md->sect_title);

@<Render section footer@> =
	weave_section_footer_node *C = RETRIEVE_POINTER_weave_section_footer_node(N->content);
	WRITE(" <%S>", C->sect->md->sect_title);

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	WRITE(" <%S>", C->chap->md->ch_title);

@<Render chapter footer@> =
	weave_chapter_footer_node *C = RETRIEVE_POINTER_weave_chapter_footer_node(N->content);
	WRITE(" <%S>", C->chap->md->ch_title);

@<Render purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	WRITE(" <%S>", C->purpose);

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	WRITE(" <%S>", C->text);

@<Render bar@> =
	;

@<Render pagebreak@> =
	;

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	Debugging::show_para(OUT, C->para);
	if (C->no_skip) WRITE(" (no skip)");

@<Render endnote@> =
	;

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	WRITE(" <%S> %d by %d", C->figname, C->w, C->h);

@<Render material@> =
	weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
	WRITE(" ");
	Debugging::show_mat(OUT, C->material_type);
	if (C->material_type == CODE_MATERIAL) WRITE(": %S", C->styling->language_name);
	if (C->plainly) WRITE(" (plainly)");

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	WRITE(" service <%S> ID <%S> %d by %d", C->service, C->ID, C->w, C->h);

@<Render pmac@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	WRITE(" <%S>", C->pmac->macro_name);
	if (C->defn) WRITE(" (definition)");

@<Render vskip@> =
	weave_vskip_node *C = RETRIEVE_POINTER_weave_vskip_node(N->content);
	if (C->in_comment) WRITE(" (in comment)");

@<Render apres-defn@> =
	;

@<Render chapter@> =
	weave_chapter_node *C = RETRIEVE_POINTER_weave_chapter_node(N->content);
	WRITE(" <%S>", C->chap->md->ch_title);

@<Render section@> =
	weave_section_node *C = RETRIEVE_POINTER_weave_section_node(N->content);
	WRITE(" <%S>", C->sect->md->sect_title);

@<Render code line@> =
	;

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	WRITE(" <%S>", C->fn->function_name);

@<Render commentary@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	Debugging::show_text(OUT, C->text, 80);
	if (C->in_code) WRITE(" (code)");

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	WRITE(" caption <%S>", C->caption);

@<Render toc@> =
	weave_toc_node *C = RETRIEVE_POINTER_weave_toc_node(N->content);
	WRITE(" - <%S>", C->text1);

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	WRITE(" - <%S, %S>", C->text1, C->text2);
	if (C->para) Debugging::show_para(OUT, C->para);

@<Render weave_chapter_title_page_node@> =
	weave_chapter_title_page_node *C = RETRIEVE_POINTER_weave_chapter_title_page_node(N->content);
	WRITE(" - something %d", C->allocation_id);

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	WRITE(" <%S>", C->keyword);

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	WRITE(" <%S>\n", C->matter);
	for (int i=0; i<L; i++) WRITE("  ");
	WRITE("           ");
	WRITE(" _%S_", C->colouring);

@<Render URL@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	WRITE(" content <%S> url <%S>", C->content, C->url);

@<Render footnote cue@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	WRITE(" [%S]", C->cue_text);

@<Render footnote text@> =
	weave_begin_footnote_text_node *C = RETRIEVE_POINTER_weave_begin_footnote_text_node(N->content);
	WRITE(" [%S]", C->cue_text);

@<Render display line@> =
	weave_display_line_node *C = RETRIEVE_POINTER_weave_display_line_node(N->content);
	WRITE(" <%S>", C->text);

@<Render function defn@> =
	weave_function_defn_node *C = RETRIEVE_POINTER_weave_function_defn_node(N->content);
	WRITE(" <%S>", C->fn->function_name);

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	WRITE(" depth %d label <%S>", C->depth, C->label);

@<Render grammar index@> =
	;

@<Render inline@> =
	;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	Debugging::show_para(OUT, C->par1);
	if (C->par2) {
		WRITE(" to ");
		Debugging::show_para(OUT, C->par2);
	}

@<Render maths@> =
	weave_maths_node *C = RETRIEVE_POINTER_weave_maths_node(N->content);
	WRITE(" <%S>", C->content);
	if (C->displayed) WRITE(" (displayed)");

@ =
void Debugging::show_text(text_stream *OUT, text_stream *text, int limit) {
	WRITE(" <");
	for (int i=0; (i<limit) && (i<Str::len(text)); i++)
		if (Str::get_at(text, i) == '\n')
			WRITE("\\n");
		else
			PUT(Str::get_at(text, i));
	WRITE(">");
	if (Str::len(text) > limit) WRITE(" ... continues to %d chars", Str::len(text));
}

void Debugging::show_para(text_stream *OUT, paragraph *P) {
	WRITE(" P%S", P->paragraph_number);
	if (Str::len(P->heading_text) > 0) WRITE("'%S'", P->heading_text);
}

void Debugging::show_mat(text_stream *OUT, int m) {
	switch (m) {
		case REGULAR_MATERIAL: WRITE("discussion"); break;
		case MACRO_MATERIAL: WRITE("paragraph macro"); break;
		case DEFINITION_MATERIAL: WRITE("definition"); break;
		case CODE_MATERIAL: WRITE("code"); break;
		case ENDNOTES_MATERIAL: WRITE("endnotes"); break;
		case FOOTNOTES_MATERIAL: WRITE("footnotes"); break;
		default: WRITE("unknown"); break;
	}
}
