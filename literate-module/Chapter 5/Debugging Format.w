[DebuggingWeaving::] Debugging Format.

A format which renders as a plain-text serialisation of the weave tree,
useful only for testing the weaver.

@h Creation.

=
void DebuggingWeaving::create(void) {
	weave_format *wf = WeavingFormats::create_weave_format(I"TestingInweb", I".debug.txt");
	METHOD_ADD(wf, RENDER_FOR_MTID, DebuggingWeaving::render);
}

@h Rendering.
The weave tree will be rendered by traversing it, and rendering each node in its turn.

=
void DebuggingWeaving::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	debugging_render_state drs;
	@<Initialise the render state@>;
	Trees::traverse_from(tree->root, &DebuggingWeaving::render_visit, (void *) &drs, 0);
	@<Append the Markdown traces@>;
}

@ The following instructions will be carried through the traverse:

=
classdef debugging_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
	struct linked_list *fragments; /* of `markdown_item` */
	int observed[100];
} debugging_render_state;

@<Initialise the render state@> =
	drs.OUT = OUT;
	drs.wv = C->wv;
	drs.fragments = NEW_LINKED_LIST(markdown_item);
	for (int i=0; i<100; i++) drs.observed[i] = 0;

@<Append the Markdown traces@> =
	markdown_item *md;
	int f = 1;
	LOOP_OVER_LINKED_LIST(md, markdown_item, drs.fragments) {
		WRITE("\nMarkdown fragment (%d)\n", f++);
		INDENT;
		Markdown::debug_subtree(OUT, md);
		OUTDENT;
	}
	WRITE("\n");
	tree_node_type *tnt;
	LOOP_OVER(tnt, tree_node_type) {
		int id = tnt->allocation_id;
		if (id < 100)
			WRITE("%S: %d node%s\n",
				tnt->node_type_name, drs.observed[id], (drs.observed[id]==1)?"":"s");
	}

@ So, then, the visiting function, called on each node. C does not allow
switch statements whose cases are not literal constants, so there's a
big contrived `if` instead. But it is morally a `switch`.

=
int DebuggingWeaving::render_visit(tree_node *N, void *state, int L) {
	debugging_render_state *drs = (debugging_render_state *) state;
	text_stream *OUT = drs->OUT;
	for (int i=0; i<L; i++) WRITE("    ");
	WRITE("%S: ", N->type->node_type_name);
	int id = N->type->allocation_id;
	if (id < 100) drs->observed[id]++;

	/* Document superstructure */

	     if (N->type == weave_document_node_type) @<Render document@>
	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_body_node_type) @<Render body@>
	else if (N->type == weave_tail_node_type) @<Render tail@>

	/* Large-scale structure */

	else if (N->type == weave_chapter_node_type) @<Render chapter@>
	else if (N->type == weave_chapter_header_node_type) @<Render chapter header@>
	else if (N->type == weave_chapter_footer_node_type) @<Render chapter footer@>
	else if (N->type == weave_section_node_type) @<Render section@>
	else if (N->type == weave_section_header_node_type) @<Render section header@>
	else if (N->type == weave_section_footer_node_type) @<Render section footer@>
	else if (N->type == weave_section_purpose_node_type) @<Render section purpose@>
	else if (N->type == weave_toc_node_type) @<Render toc@>
	else if (N->type == weave_toc_line_node_type) @<Render toc line@>

	/* Small-scale structure */

	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_subsubheading_node_type) @<Render subsubheading@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_material_node_type) @<Render material@>

	/* Code-like material */

	else if (N->type == weave_holon_declaration_node_type) @<Render holon declaration@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_holon_usage_node_type) @<Render holon usage@>
	else if (N->type == weave_tangler_command_node_type) @<Render tangler command@>
	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_source_code_node_type) @<Render source code@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_comment_in_holon_node_type) @<Render comment in holon@>
	else if (N->type == weave_defn_node_type) @<Render defn@>

	/* Commentary and gadget material */

	else if (N->type == weave_markdown_node_type) @<Render Markdown@>
	else if (N->type == weave_audio_node_type) @<Render audio@>
	else if (N->type == weave_carousel_slide_node_type) @<Render carousel slide@>
	else if (N->type == weave_download_node_type) @<Render download@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
	else if (N->type == weave_raw_HTML_node_type) @<Render raw HTML@>
	else if (N->type == weave_video_node_type) @<Render video@>

	/* Paragraph tail material */

	else if (N->type == weave_index_begins_node_type) @<Render index begins@>
	else if (N->type == weave_index_lemma_node_type) @<Render index lemma@>
	else if (N->type == weave_index_ends_node_type) @<Render index ends@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_endnote_text_node_type) @<Render endnote text@>

	else internal_error("no HTML rendering for this node type");
	
	WRITE("\n");
	return TRUE;
}

@h Document superstructure renderers.

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

@h Large-scale structure renderers.

@<Render chapter@> =
	weave_chapter_node *C = RETRIEVE_POINTER_weave_chapter_node(N->content);
	WRITE(" <%S>", C->chap->ch_title);

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	WRITE(" <%S>", C->chap->ch_title);

@<Render chapter footer@> =
	weave_chapter_footer_node *C = RETRIEVE_POINTER_weave_chapter_footer_node(N->content);
	WRITE(" <%S>", C->chap->ch_title);

@<Render section@> =
	weave_section_node *C = RETRIEVE_POINTER_weave_section_node(N->content);
	WRITE(" <%S>", C->sect->sect_title);

@<Render section header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	WRITE(" <%S>", C->sect->sect_title);

@<Render section footer@> =
	weave_section_footer_node *C = RETRIEVE_POINTER_weave_section_footer_node(N->content);
	WRITE(" <%S>", C->sect->sect_title);

@<Render section purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	WRITE(" <%S>", C->purpose);

@<Render toc@> =
	weave_toc_node *C = RETRIEVE_POINTER_weave_toc_node(N->content);
	WRITE(" - <%S>", C->text1);

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	WRITE(" - <%S, %S>", C->text1, C->text2);
	if (C->para) DebuggingWeaving::show_para(OUT, C->para);

@h Small-scale structure renderers.

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	WRITE(" <%S>", C->text);

@<Render subsubheading@> =
	weave_subsubheading_node *C = RETRIEVE_POINTER_weave_subsubheading_node(N->content);
	WRITE(" <%S>", C->text);

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	DebuggingWeaving::show_para(OUT, C->para);
	if (C->no_skip) WRITE(" (no skip)");

@<Render material@> =
	weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
	WRITE(" ");
	switch (C->material_type) {
		case COMMENTARY_MATERIAL:        WRITE("discussion"); break;
		case HOLON_DECLARATION_MATERIAL: WRITE("named holon"); break;
		case DEFINITION_MATERIAL:        WRITE("definition"); break;
		case CODE_MATERIAL:              WRITE("code"); break;
		case ENDNOTES_MATERIAL:          WRITE("endnotes"); break;
		case FOOTNOTES_MATERIAL:         WRITE("footnotes"); break;
		default:                         WRITE("unknown"); break;
	}
	if (C->material_type == CODE_MATERIAL) WRITE(": %S", C->styling->language_name);
	if (C->plainly) WRITE(" (plainly)");

@h Code-like material renderers.

@<Render holon declaration@> =
	weave_holon_declaration_node *C = RETRIEVE_POINTER_weave_holon_declaration_node(N->content);
	WRITE(" <%S> (definition)", C->holon->holon_name);

@<Render code line@> =
	;

@<Render holon usage@> =
	weave_holon_usage_node *C = RETRIEVE_POINTER_weave_holon_usage_node(N->content);
	WRITE(" <%S>", (C->holon)?(C->holon->holon_name):NULL);

@<Render tangler command@> =
	weave_tangler_command_node *C = RETRIEVE_POINTER_weave_tangler_command_node(N->content);
	WRITE("command: %S", C->command);

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	DebuggingWeaving::show_text(OUT, C->content, 80);

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	WRITE(" <%S>\n", C->matter);
	for (int i=0; i<L; i++) WRITE("  ");
	WRITE("           ");
	WRITE(" _%S_", C->colouring);

@<Render function defn@> =
	weave_function_defn_node *C = RETRIEVE_POINTER_weave_function_defn_node(N->content);
	WRITE(" <%S>", C->fn->function_name);

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	WRITE(" <%S>", C->fn->function_name);

@<Render comment in holon@> =
	weave_comment_in_holon_node *C = RETRIEVE_POINTER_weave_comment_in_holon_node(N->content);
	WRITE("comment %S", C->comment_open);
	WRITE("%S", C->raw);
	WRITE("%S", C->comment_close);

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	WRITE(" <%S>", C->keyword);

@h Commentary and gadget material renderers.

@<Render Markdown@> =
	weave_markdown_node *C = RETRIEVE_POINTER_weave_markdown_node(N->content);
	ADD_TO_LINKED_LIST(C->content, markdown_item, drs->fragments);
	WRITE("fragment (%d)", LinkedLists::len(drs->fragments));

@<Render audio@> =
	weave_audio_node *C = RETRIEVE_POINTER_weave_audio_node(N->content);
	WRITE(" <%S> %d", C->audio_name, C->w);

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	WRITE(" %d/%d caption <%S> position %d", C->slide_number, C->slide_of, C->caption, C->positioning);

@<Render download@> =
	weave_download_node *C = RETRIEVE_POINTER_weave_download_node(N->content);
	WRITE(" <%S> %S", C->download_name, C->filetype);

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	WRITE(" service <%S> ID <%S> %d by %d", C->service, C->ID, C->w, C->h);

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	WRITE(" <%S> %d by %d", C->figname, C->w, C->h);

@<Render raw HTML@> =
	weave_raw_HTML_node *C = RETRIEVE_POINTER_weave_raw_HTML_node(N->content);
	WRITE(" <%S>", C->extract);

@<Render video@> =
	weave_video_node *C = RETRIEVE_POINTER_weave_video_node(N->content);
	WRITE(" <%S> %d", C->video_name, C->w);

@h Paragraph tail material renderers.

@<Render index begins@> =
	WRITE("index begins");

@<Render index lemma@> =
	weave_index_lemma_node *C = RETRIEVE_POINTER_weave_index_lemma_node(N->content);
	ls_index_lemma *lemma = C->lemma;
	for (ls_index_lemma *l2 = lemma->parent; l2; l2 = l2->parent) WRITE("> ");
	if (lemma->style == 2) WRITE("`");
	if (lemma->style == 3) WRITE("/");
	WRITE("%S", lemma->text);
	if (lemma->style == 2) WRITE("`");
	if (lemma->style == 3) WRITE("/");
	ls_index_mark *mark; int c = 0;
	LOOP_OVER_LINKED_LIST(mark, ls_index_mark, lemma->marks) {
		if (c++ > 0) WRITE(", "); else WRITE("  ");
		if (mark->important) WRITE("_");
		WRITE("%S", mark->at->paragraph_number);
		if (mark->important) WRITE("_");
	}

@<Render index ends@> =
	WRITE("index ends");

@<Render endnote@> =
	;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	DebuggingWeaving::show_para(OUT, C->par1);
	if (C->par2) {
		WRITE(" to ");
		DebuggingWeaving::show_para(OUT, C->par2);
	}

@<Render endnote text@> =
	weave_endnote_text_node *C = RETRIEVE_POINTER_weave_endnote_text_node(N->content);
	DebuggingWeaving::show_text(OUT, C->text, 80);

@ And the above make liberal use of these helpers:

=
void DebuggingWeaving::show_text(text_stream *OUT, text_stream *text, int limit) {
	WRITE(" <");
	for (int i=0; (i<limit) && (i<Str::len(text)); i++)
		if (Str::get_at(text, i) == '\n')
			WRITE("\\n");
		else
			PUT(Str::get_at(text, i));
	WRITE(">");
	if (Str::len(text) > limit) WRITE(" ... continues to %d chars", Str::len(text));
}

void DebuggingWeaving::show_para(text_stream *OUT, ls_paragraph *par) {
	WRITE(" P%S", par->paragraph_number);
	text_stream *title = LiterateSource::par_title(par);
	if (Str::len(title) > 0) WRITE("'%S'", title);
}
