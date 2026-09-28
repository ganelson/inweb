[PlainTextWeaving::] Plain Text Format.

To provide for weaving in plain text format, which is not very
interesting, but ought to be available.

@h Creation.

=
void PlainTextWeaving::create(void) {
	weave_format *wf = WeavingFormats::create_weave_format(I"plain", I".txt");
	METHOD_ADD(wf, RENDER_FOR_MTID, PlainTextWeaving::render);
}

@h Markdown rendering instructions.
While the code in this section renders the weave tree, the actual commentary
(along with other fragments, such as comments in code, depending on the
conventions used) is stored in Markdown, and needs to be handed over to the
code in //foundation: Markdown Rendering//.

That needs a set of instructions, to say what kind of Markdown, how we want it
rendered, and so on.

=
markdown_render PlainTextWeaving::Markdown_instructions(weave_order *wv) {
	markdown_render rdr = MDRender::contextual_plain_text(
		WebNotation::commentary_variation(wv->weave_web),
		STORE_POINTER_weave_order(wv));
	return rdr;
}

@h Rendering.
The weave tree will be rendered by traversing it, and rendering each node in its turn.

=
void PlainTextWeaving::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	PlainText_render_state prs;
	@<Initialise the render state@>;
	Trees::traverse_from(tree->root, &PlainTextWeaving::render_visit, (void *) &prs, 0);
}

@ The following state will be carried through the traverse, though it contains
no fluctuating content, just instructions on what to do.

=
classdef PlainText_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
	struct markdown_render rdr;
} PlainText_render_state;

@<Initialise the render state@> =
	prs.OUT = OUT;
	prs.wv = C->wv;
	prs.rdr = PlainTextWeaving::Markdown_instructions(C->wv);

@ So, then, the visiting function, called on each node. C does not allow
switch statements whose cases are not literal constants, so there's a
big contrived `if` instead. But it is morally a `switch`.

=
int PlainTextWeaving::render_visit(tree_node *N, void *state, int L) {
	PlainText_render_state *prs = (PlainText_render_state *) state;
	text_stream *OUT = prs->OUT;

	/* Document superstructure */

	     if (N->type == weave_document_node_type) @<Skip@>
	else if (N->type == weave_head_node_type) @<Skip@>
	else if (N->type == weave_body_node_type) @<Skip@>
	else if (N->type == weave_tail_node_type) @<Skip@>

	/* Large-scale structure */

	else if (N->type == weave_chapter_node_type) @<Skip@>
	else if (N->type == weave_chapter_header_node_type) @<Render chapter header@>
	else if (N->type == weave_chapter_footer_node_type) @<Skip@>
	else if (N->type == weave_section_node_type) @<Skip@>
	else if (N->type == weave_section_header_node_type) @<Render section header@>
	else if (N->type == weave_section_footer_node_type) @<Render section footer@>
	else if (N->type == weave_section_purpose_node_type) @<Render section purpose@>
	else if (N->type == weave_toc_node_type) @<Skip@>
	else if (N->type == weave_toc_line_node_type) @<Skip@>

	/* Small-scale structure */

	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_subsubheading_node_type) @<Render subsubheading@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_material_node_type) @<Skip@>

	/* Code-like material */

	else if (N->type == weave_holon_declaration_node_type) @<Render holon declaration@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_holon_usage_node_type) @<Render holon usage@>
	else if (N->type == weave_tangler_command_node_type) @<Skip@>
	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_source_code_node_type) @<Render source code@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_comment_in_holon_node_type) @<Render comment in holon@>
	else if (N->type == weave_defn_node_type) @<Render defn@>

	/* Commentary and gadget material */

	else if (N->type == weave_markdown_node_type) @<Render Markdown@>
	else if (N->type == weave_audio_node_type) @<Skip@>
	else if (N->type == weave_carousel_slide_node_type) @<Skip@>
	else if (N->type == weave_download_node_type) @<Skip@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_figure_node_type) @<Skip@>
	else if (N->type == weave_raw_HTML_node_type) @<Skip@>
	else if (N->type == weave_video_node_type) @<Skip@>

	/* Paragraph tail material */

	else if (N->type == weave_index_begins_node_type) @<Render index begins@>
	else if (N->type == weave_index_lemma_node_type) @<Render index lemma@>
	else if (N->type == weave_index_ends_node_type) @<Render index ends@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_endnote_text_node_type) @<Render endnote text@>

	else internal_error("no HTML rendering for this node type");
	return TRUE;
}

@<Skip@> =
	;

@ By default, the visitor function returns `TRUE` at each node (see above).
This tells the tree-traversing machinery to continue recursing down through
that node's children _after_ the node itself has been visited.

Some nodes, however, will want to render something, then recurse downwards,
then render something further. They can do this by using the following holon
to perform the recursion, but must then explicitly return `FALSE`, or else the child
nodes will end up being visited a second time.

@<Recurse the renderer through children nodes@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &PlainTextWeaving::render_visit, (void *) prs, L+1);

@h Large-scale structure renderers.

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	WRITE("%S\n\n", C->chap->ch_title);
	ls_section *S;
	LOOP_OVER_LINKED_LIST(S, ls_section, C->chap->sections) {
		WRITE("  %S\n    %S\n", S->sect_title, LiterateSource::unit_purpose(S->literate_source));
		WRITE("\n");
	}
	WRITE("\n");

@<Render section header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	WRITE("%S\n\n", C->sect->sect_title);

@<Render section footer@> =
	WRITE("\n\n");

@<Render section purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	MDRender::stream(OUT, &(prs->rdr), C->purpose, 0);
	WRITE("\n");

@h Small-scale structure renderers.

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	WRITE("%S\n\n", C->text);

@<Render subsubheading@> =
	weave_subsubheading_node *C = RETRIEVE_POINTER_weave_subsubheading_node(N->content);
	WRITE("%S\n\n", C->text);

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	WRITE("\n");
	WRITE("%S%S", LiterateSource::par_ornament(C->para), C->para->paragraph_number);
	text_stream *title = LiterateSource::par_title(C->para);
	if (Str::len(title) > 0) WRITE(" %S", title);
	WRITE(".  ");

@h Code-like material renderers.

@<Render holon declaration@> =
	weave_holon_declaration_node *C = RETRIEVE_POINTER_weave_holon_declaration_node(N->content);
	WRITE("<%S (%S)> =",
		C->holon->holon_name, C->holon->corresponding_chunk->owner->paragraph_number);

@<Render code line@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &PlainTextWeaving::render_visit, (void *) prs, L+1);
	WRITE("\n");
	return FALSE;

@<Render holon usage@> =
	weave_holon_usage_node *C = RETRIEVE_POINTER_weave_holon_usage_node(N->content);
	WRITE("<%S (%S)>",
		(C->holon)?(C->holon->holon_name):NULL, C->holon->corresponding_chunk->owner->paragraph_number);

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	WRITE("%S", C->matter);

@<Render function defn@> =
	weave_function_defn_node *C = RETRIEVE_POINTER_weave_function_defn_node(N->content);
	WRITE("%S", C->fn->function_name);
	return TRUE;

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	WRITE("%S", C->fn->function_name);

@<Render comment in holon@> =
	weave_comment_in_holon_node *C = RETRIEVE_POINTER_weave_comment_in_holon_node(N->content);
	WRITE("%S", C->comment_open);
	WRITE("%S", C->raw);
	WRITE("%S", C->comment_close);

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	WRITE("%S ", C->keyword);

@h Commentary and gadget material renderers.

@<Render Markdown@> =
	weave_markdown_node *C = RETRIEVE_POINTER_weave_markdown_node(N->content);
	MDRender::render(OUT, &(prs->rdr), C->content);

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	WRITE("[See %S video with ID %S.]\n", C->service, C->ID);

@h Paragraph tail material renderers.

@<Render index begins@> =
	WRITE("\nIndex:\n\n");

@<Render index lemma@> =
	weave_index_lemma_node *C = RETRIEVE_POINTER_weave_index_lemma_node(N->content);
	ls_index_lemma *lemma = C->lemma;
	for (ls_index_lemma *l2 = lemma->parent; l2; l2 = l2->parent) WRITE("  ");
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
	WRITE("\n");

@<Render index ends@> =
	WRITE("\n");


@<Render endnote@> =
	@<Recurse the renderer through children nodes@>;
	WRITE("\n");
	return FALSE;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	WRITE("%S%S", LiterateSource::par_ornament(C->par1), C->par1->paragraph_number);
	if (C->par2) WRITE("-%S", C->par2->paragraph_number);

@<Render endnote text@> =
	weave_endnote_text_node *C = RETRIEVE_POINTER_weave_endnote_text_node(N->content);
	WRITE("%S", C->text);
