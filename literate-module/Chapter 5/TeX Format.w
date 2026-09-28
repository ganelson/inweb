[TeXWeaving::] TeX Format.

To provide for weaving in the standard maths and science typesetting
software, TeX, and its numerous variants.

@h Creation.

=
void TeXWeaving::create(void) {
	weave_format *wf = WeavingFormats::create_weave_format(I"TeX", I".tex");
	METHOD_ADD(wf, RENDER_FOR_MTID, TeXWeaving::render_TeX);
}

@h Markdown rendering instructions.
While the code in this section renders the weave tree, the actual commentary
(along with other fragments, such as comments in code, depending on the
conventions used) is stored in Markdown, and needs to be handed over to the
code in //foundation: Markdown to TeX//.

That needs a set of instructions, to say what kind of Markdown, how we want it
rendered, and so on.

=
markdown_render TeXWeaving::Markdown_instructions(weave_order *wv) {
	markdown_render rdr = MDRender::contextual_TeX(
		WebNotation::commentary_variation(wv->weave_web),
		STORE_POINTER_weave_order(wv));
	markdown_render *prdr = &rdr;
	METHOD_ADD(prdr, NAME_COLOUR_MTID, WeavingFormats::name_colour);
	METHOD_ADD(prdr, NAME_COLOUR_SCHEME_MTID, WeavingFormats::name_colour_scheme);
	METHOD_ADD(prdr, BEGIN_COLOURING_MTID, WeavingFormats::begin_colouring);
	METHOD_ADD(prdr, COLOUR_LINE_MTID, WeavingFormats::colour_line);
	METHOD_ADD(prdr, RESOLVE_LINK_MTID, WeavingFormats::resolve_link);
	METHOD_ADD(prdr, NAME_ANCHOR_MTID, TeXWeaving::name_anchor);
	METHOD_ADD(prdr, NOTIFY_IMAGE_MTID, TeXWeaving::notify_image);
	METHOD_ADD(prdr, RENDER_GADGET_MTID, TeXWeaving::render_gadget);
	METHOD_ADD(prdr, RENDER_UL_AS_CAROUSEL_MTID, TeXWeaving::render_ul_as_carousel);
	return rdr;
}

void TeXWeaving::name_anchor(markdown_render *rdr, text_stream *OUT, void *clabel) {
	ls_line_label *label = (ls_line_label *) clabel;
	ls_line *line = LineLabels::destination(label);
	TeXWeaving::line_anchor(OUT, line);
}

void TeXWeaving::line_anchor(text_stream *OUT, ls_line *line) {
	ls_section *S = LiterateSource::section_of_line(line);
	if (S) WRITE("s%d", S->allocation_id);
	WRITE("line%d", line->sequence_number_in_section);
}

@h Rendering.

=
void TeXWeaving::render_TeX(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	TeX_render_state trs;
	@<Initialise the render state@>;
	Trees::traverse_from(tree->root, &TeXWeaving::render_visit, (void *) &trs, 0);
}

@ The following state will be carried through the traverse.

=
classdef TeX_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
	struct colour_scheme *colours;
	struct markdown_render rdr;
	int max_label_width;
	int holon_defined;
	int commentary_rendered;
	ls_paragraph *current_par;
} TeX_render_state;

@<Initialise the render state@> =
	trs.OUT = OUT;
	trs.wv = C->wv;
	trs.colours = Swarm::ensure_colour_scheme(C->wv, I"Colours", I"");
	trs.rdr = TeXWeaving::Markdown_instructions(C->wv);
	trs.max_label_width = 0;
	trs.holon_defined = FALSE;
	trs.commentary_rendered = FALSE;
	trs.current_par = NULL;

@ So, then, the visiting function, called on each node. C does not allow
switch statements whose cases are not literal constants, so there's a
big contrived `if` instead. But it is morally a `switch`.

=
int TeXWeaving::render_visit(tree_node *N, void *state, int L) {
	TeX_render_state *trs = (TeX_render_state *) state;
	text_stream *OUT = trs->OUT;

	/* Document superstructure */

	     if (N->type == weave_document_node_type) @<Skip@>
	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_body_node_type) @<Skip@>
	else if (N->type == weave_tail_node_type) @<Render tail@>

	/* Large-scale structure */

	else if (N->type == weave_chapter_node_type) @<Skip@>
	else if (N->type == weave_chapter_header_node_type) @<Render chapter header@>
	else if (N->type == weave_chapter_footer_node_type) @<Skip@>
	else if (N->type == weave_section_node_type) @<Skip@>
	else if (N->type == weave_section_header_node_type) @<Render section header@>
	else if (N->type == weave_section_footer_node_type) @<Skip@>
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
	else if (N->type == weave_carousel_slide_node_type) @<Render carousel slide@>
	else if (N->type == weave_download_node_type) @<Skip@>
	else if (N->type == weave_embed_node_type) @<Skip@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
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
		Trees::traverse_from(M, &TeXWeaving::render_visit, (void *) trs, L+1);

@h Document superstructure renderers.
These are just comments.

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	WRITE("%% %S\n", C->banner);

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	WRITE("%% %S\n", C->rennab);
	WRITE("\\end\n");

@h Large-scale structure renderers.

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	if (Str::ne(C->chap->ch_range, I"S")) {
		TeXWeaving::general_heading(OUT, &(trs->rdr), trs->wv,
			FIRST_IN_LINKED_LIST(ls_section, C->chap->sections), NULL, C->chap->ch_title,
			3, FALSE);
		WRITE("%S\\medskip\n", C->chap->rubric);
		ls_section *S;
		LOOP_OVER_LINKED_LIST(S, ls_section, C->chap->sections) {
			WRITE("\\smallskip\\noindent ");
			WRITE("{\\bf ");
			MDRender::stream(OUT, &(trs->rdr), S->sect_title, 0);
			WRITE("}\\qquad\n");
			MDRender::stream(OUT, &(trs->rdr), LiterateSource::unit_purpose(S->literate_source), 0);
		}
	}

@<Render section header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	TeXWeaving::general_heading(OUT, &(trs->rdr), trs->wv, C->sect, NULL,
		C->sect->sect_title, 2, FALSE);

@<Render section purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	WRITE("\\smallskip\\par\\noindent{\\it ");
	MDRender::stream(OUT, &(trs->rdr), C->purpose, 0);
	WRITE("}\\smallskip\\noindent\n");

@ The Table of Contents at the top of a section:

@<Render toc@> =
	WRITE("\\medskip\\hrule\\smallskip\\par\\noindent\\usagefont ");
	for (tree_node *M = N->child; M; M = M->next) {
		Trees::traverse_from(M, &TeXWeaving::render_visit, (void *) trs, L+1);
		if (M->next) WRITE("; ");
	}
	WRITE("}\\par\\medskip\\hrule\\bigskip\n");
	return FALSE;

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	TeXWeaving::locale(OUT, &(trs->rdr), C->para, NULL, C->para);
	WRITE("~");
	MDRender::stream(OUT, &(trs->rdr), C->text2, 0);

@h Small-scale structure renderers.

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	WRITE("\\par\\noindent{\\bf ");
	MDRender::stream(OUT, &(trs->rdr), C->text, 0);
	WRITE("}\\medskip\n");

@<Render subsubheading@> =
	weave_subsubheading_node *C = RETRIEVE_POINTER_weave_subsubheading_node(N->content);
	WRITE("\\par\\noindent{\\bf ");
	MDRender::stream(OUT, &(trs->rdr), C->text, 0);
	WRITE("}\\medskip\n");

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C =
		RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	if (LiterateSource::par_has_visible_number(C->para)) {
		text_stream *titling = LiterateSource::par_title(C->para);
		if (Str::len(titling) == 0)
			TeXWeaving::general_heading(OUT, &(trs->rdr), trs->wv, LiterateSource::section_of_par(C->para),
				C->para, I"", 0, FALSE);
		else
			TeXWeaving::general_heading(OUT, &(trs->rdr), trs->wv, LiterateSource::section_of_par(C->para),
				C->para, titling, 1, FALSE);
	}
	trs->holon_defined = FALSE;
	trs->commentary_rendered = FALSE;
	trs->current_par = C->para;
	WRITE("\\inwebanchor{");
	TeXWeaving::paragraph_link(OUT, C->para);
	WRITE("}");

@<Render material@> =
	weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
	if (C->material_type == COMMENTARY_MATERIAL)
		@<Deal with a commentary material node@>
	else if (C->material_type == CODE_MATERIAL)
		@<Deal with a code material node@>
	else if (C->material_type == FOOTNOTES_MATERIAL)
		@<Deal with a footnotes material node@>
	else if (C->material_type == ENDNOTES_MATERIAL)
		@<Deal with a endnotes material node@>
	else if (C->material_type == HOLON_DECLARATION_MATERIAL)
		@<Deal with a holon material node@>
	else if (C->material_type == DEFINITION_MATERIAL)
		@<Deal with a definition material node@>;
	return FALSE;

@<Deal with a commentary material node@> =
	@<Recurse the renderer through children nodes@>;
	WRITE("\n");
	trs->commentary_rendered = TRUE;

@<Deal with a code material node@> =
	if (C->styling) {
		TEMPORARY_TEXT(csname)
		WRITE_TO(csname, "%S-Colours", C->styling->language_name);
		trs->colours = Swarm::ensure_colour_scheme(trs->wv,
			csname, C->styling->language_name);
		DISCARD_TEXT(csname)
	}
	if (trs->holon_defined) WRITE("\\beginlinestighter\n");
	else WRITE("\\beginlines\n");
	trs->max_label_width = 0;
	for (tree_node *M = N->child; M; M = M->next)
		if (M->type == weave_code_line_node_type) {
			weave_code_line_node *MC = RETRIEVE_POINTER_weave_code_line_node(M->content);
			if ((MC->line) && (LineLabels::label_width(MC->line) > trs->max_label_width))
				trs->max_label_width = LineLabels::label_width(MC->line);
		}
	@<Recurse the renderer through children nodes@>;
	trs->max_label_width = 0;
	WRITE("\\endlines\n");

@<Deal with a footnotes material node@> =
	return FALSE;

@<Deal with a endnotes material node@> =
	@<Recurse the renderer through children nodes@>;

@<Deal with a holon material node@> =
	@<Recurse the renderer through children nodes@>;
	WRITE("\n");

@<Deal with a definition material node@> =
	WRITE("\\beginlinestighter\n");
	@<Recurse the renderer through children nodes@>;
	WRITE("\\endlines\n");

@h Code-like material renderers.

@<Render holon declaration@> =
	if (trs->commentary_rendered) WRITE("\\par\\smallskip\\noindent\n");
	weave_holon_declaration_node *C = RETRIEVE_POINTER_weave_holon_declaration_node(N->content);
	TeXWeaving::holon_name(OUT, &(trs->rdr), C->holon, TRUE);
	trs->holon_defined = TRUE;

@<Render code line@> =
	weave_code_line_node *C = RETRIEVE_POINTER_weave_code_line_node(N->content);
	WRITE("\\hskip1em ");
	if (trs->max_label_width > 0) {
		if (LineLabels::labelled(C->line)) {
			WRITE("\\inwebanchor{");
			TeXWeaving::line_anchor(OUT, C->line);
			WRITE("}");
			WRITE("|");
			int n = trs->max_label_width - Str::len(LineLabels::label_text(C->line));
			while (n > 0) { WRITE(" "); n--; }
			WRITE("%S |{$\\Rightarrow$}", LineLabels::label_text(C->line));
		} else {
			WRITE("|");
			int n = trs->max_label_width + 1;
			while (n > 0) { WRITE(" "); n--; }
			WRITE("|\\phantom{$\\Rightarrow$}");
		}
		WRITE("\\hskip1em ");
	}
	@<Recurse the renderer through children nodes@>;
	WRITE("\n");
	return FALSE;

@<Render holon usage@> =
	weave_holon_usage_node *C = RETRIEVE_POINTER_weave_holon_usage_node(N->content);
	TeXWeaving::holon_name(OUT, &(trs->rdr), C->holon, FALSE);

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	TEMPORARY_TEXT(colouring)
	for (int i=0; i<Str::len(C->content); i++) PUT_TO(colouring, CHARACTER_COLOUR);
	MDRenderTeX::render_syntax_coloured(OUT, &(trs->rdr), C->content, colouring, NULL);
	DISCARD_TEXT(colouring)

@<Render source code@> =
	weave_source_code_node *C =
		RETRIEVE_POINTER_weave_source_code_node(N->content);
	MDRenderTeX::render_syntax_coloured(OUT, &(trs->rdr), C->matter, C->colouring, NULL);

@<Render function defn@> =
	weave_function_defn_node *C =
		RETRIEVE_POINTER_weave_function_defn_node(N->content);
	WRITE("|");
	MDRenderTeX::change_colour(OUT, &(trs->rdr), FUNCTION_COLOUR, NULL);
	WRITE("%S", C->fn->function_name);
	MDRenderTeX::change_colour(OUT, &(trs->rdr), PLAIN_COLOUR, NULL);
	WRITE("|");
	return FALSE;

@<Render function usage@> =
	weave_function_usage_node *C =
		RETRIEVE_POINTER_weave_function_usage_node(N->content);
	TEMPORARY_TEXT(colouring)
	for (int i=0; i<Str::len(C->fn->function_name); i++) PUT_TO(colouring, FUNCTION_COLOUR);
	MDRenderTeX::render_syntax_coloured(OUT, &(trs->rdr), C->fn->function_name, colouring, NULL);
	DISCARD_TEXT(colouring)
	return FALSE;

@<Render comment in holon@> =
	weave_comment_in_holon_node *C = RETRIEVE_POINTER_weave_comment_in_holon_node(N->content);
	TEMPORARY_TEXT(cm)
	TEMPORARY_TEXT(col)
	WRITE_TO(cm, "%S", C->comment_open);
	WRITE_TO(cm, "%S", C->raw);
	WRITE_TO(cm, "%S", C->comment_close);
	for (int i=0; i<Str::len(cm); i++) PUT_TO(col, COMMENT_COLOUR);
	int starts = FALSE;
	if (N == N->parent->child) starts = TRUE;
	WRITE("|");
	TeXWeaving::source_code(OUT, &(trs->rdr), trs->wv, cm, col, starts);
	WRITE("|");
	DISCARD_TEXT(cm)
	DISCARD_TEXT(col)

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	WRITE("\\noindent ");
	if (Str::eq(C->keyword, I"enumerate")) WRITE("{\\defnannotationfont enum} ");
	WRITE("\\constantsyntaxcolouring{}|%S|\\plainsyntaxcolouring{} ", C->symbol);
	if (Str::eq(C->keyword, I"default")) WRITE("$\\equiv_{\\hbox{\\defnannotationfont def}}$ ");
	else if (Str::ne(C->keyword, I"enumerate")) WRITE("$\\equiv$ ");
	else WRITE(" ");

@h Commentary and gadget material renderers.

@<Render Markdown@> =
	weave_markdown_node *C = RETRIEVE_POINTER_weave_markdown_node(N->content);
	MDRender::render(OUT, &(trs->rdr), C->content);

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	TEMPORARY_TEXT(carousel_id)
	TEMPORARY_TEXT(carousel_dots_id)
	TeXWeaving::render_carousel_top(OUT, &(trs->rdr), trs->wv, C->slide_number, C->slide_of, carousel_id, carousel_dots_id, C->caption, C->positioning);
	@<Recurse the renderer through children nodes@>;
	TeXWeaving::render_carousel_bottom(OUT, &(trs->rdr), trs->wv, C->slide_number, C->slide_of, carousel_id, carousel_dots_id, C->caption, C->positioning);
	DISCARD_TEXT(carousel_id)
	DISCARD_TEXT(carousel_dots_id)
	return FALSE;
	
@ TeX itself has an almost defiant lack of support for anything pictorial,
which is one reason it didn't live up to its hope of being the definitive basis
for typography; even today the loose confederation of TeX-like programs and
extensions lack standard approaches. Because of that, we will assume that the
pattern has provided suitable macros. All we're trying for is to insert a picture,
scaled to a given width, into the text at the current position.

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	filename *F = Filenames::in(
		Pathnames::down(trs->wv->weave_web->path_to_web, I"Figures"),
		C->figname);
	int w = C->w, h = C->h;
	if ((w <= 0) && (h <= 0)) w = INWEB_POINTS_PER_CM*15;
	if ((w > 0) && (h > 0)) WRITE("\\inwebimagewidthheight{%f}{%d}{%d}\n",
		F, w/INWEB_POINTS_PER_CM, h/INWEB_POINTS_PER_CM);
	else if (w > 0) WRITE("\\inwebimagewidth{%f}{%d}\n", F, w/INWEB_POINTS_PER_CM);
	else if (h > 0) WRITE("\\inwebimageheight{%f}{%d}\n", F, h/INWEB_POINTS_PER_CM);
	else WRITE("\\inwebimage{%f}\n", F);

@h Paragraph tail material renderers.

@<Render index begins@> =
	WRITE("\n\\beginlines\n");

@<Render index lemma@> =
	weave_index_lemma_node *C = RETRIEVE_POINTER_weave_index_lemma_node(N->content);
	ls_index_lemma *lemma = C->lemma;
	for (ls_index_lemma *l2 = lemma->parent; l2; l2 = l2->parent) WRITE("\\quad ");
	if (lemma->style == 2) WRITE("|");
	if (lemma->style == 3) WRITE("/");
	if (lemma->style == 2) WRITE("%S", lemma->text);
	else MDRender::stream(OUT, &(trs->rdr), lemma->text, 0);
	if (lemma->style == 2) WRITE("|");
	if (lemma->style == 3) WRITE("/");
	ls_index_mark *mark; int c = 0;
	LOOP_OVER_LINKED_LIST(mark, ls_index_mark, lemma->marks) {
		if (c++ > 0) WRITE(", "); else WRITE("\\hskip1em ");
		if (mark->important) WRITE("{\\bf ");
		TeXWeaving::locale(OUT, &(trs->rdr), mark->at, NULL, trs->current_par);
		if (mark->important) WRITE("}");
	}
	WRITE("\n");

@<Render index ends@> =
	WRITE("\\endlines\n\n");

@<Render endnote@> =
	WRITE("\\par\\noindent\\penalty10000\n");
	WRITE("\\endnotetext{");
	@<Recurse the renderer through children nodes@>;
	WRITE("}\\smallskip\n");
	return FALSE;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	TeXWeaving::locale(OUT, &(trs->rdr), C->par1, C->par2, trs->current_par);

@<Render endnote text@> =
	weave_endnote_text_node *C =
		RETRIEVE_POINTER_weave_endnote_text_node(N->content);
	MDRender::stream(OUT, &(trs->rdr), C->text, 0);

@h TeX code for headings.

=
void TeXWeaving::general_heading(text_stream *OUT, markdown_render *rdr, weave_order *wv,
	ls_section *S, ls_paragraph *par, text_stream *heading_text, int weight, int no_skip) {
	text_stream *TeX_macro = NULL;
	@<Choose which TeX macro to use in order to typeset the new paragraph heading@>;
	
	text_stream *orn = (par)?(LiterateSource::par_ornament(par)):I"P";
	text_stream *N = (par)?(par->paragraph_number):NULL;
	TEMPORARY_TEXT(mark)
	if (weight < 2)
		@<Work out the next mark to place into the TeX vertical list@>;
	TEMPORARY_TEXT(modified)
	MDRender::stream(modified, rdr, heading_text, 0);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, modified, U"(%c*?): (%c*)")) {
		Str::clear(modified);
		WRITE_TO(modified, "%S\\quad %S", mr.exp[0], mr.exp[1]);
	}
	if (weight == 2)
		WRITE("\\%S{%S}{%S}{%S}{\\%S}{%S}%%\n",
			TeX_macro, N, modified, mark, orn, NULL);
	else
		WRITE("\\%S{%S}{%S}{%S}{\\%S}{%S}%%\n",
			TeX_macro, N, modified, mark, orn, WebRanges::of(S));
	DISCARD_TEXT(mark)
	DISCARD_TEXT(modified)
	Regexp::dispose_of(&mr);
}

@ We want to have different heading styles for different weights, and TeX is
horrible at using macro parameters as function arguments, so we don't want
to pass the weight that way. Instead we use

``` None
	\weavesection
	\weavesections
	\weavesectionss
	\weavesectionsss
```

where the weight is the number of terminal `s`s, 0 to 3. (TeX macros,
lamentably, are not allowed digits in their name.) In the cases 0 and 1, we
also have variants `\nsweavesection` and `\nsweavesections` which are
the same, but with the initial vertical spacing removed; these allow us to
prevent unsightly excess white space in certain configurations of a section.

@<Choose which TeX macro to use in order to typeset the new paragraph heading@> =
	switch (weight) {
		case 0: TeX_macro = I"weavesection"; break;
		case 1: TeX_macro = I"weavesections"; break;
		case 2: TeX_macro = I"weavesectionss"; break;
		default: TeX_macro = I"weavesectionsss"; break;
	}
	if (Str::len(wv->theme_match) > 0) {
		switch (weight) {
			case 0: TeX_macro = I"tweavesection"; break;
			case 1: TeX_macro = I"tweavesections"; break;
			case 2: TeX_macro = I"tweavesectionss"; break;
			default: TeX_macro = I"tweavesectionsss"; break;
		}
	}
	if (no_skip) {
		switch (weight) {
			case 0: TeX_macro = I"nsweavesection"; break;
			case 1: TeX_macro = I"nsweavesections"; break;
		}
	}

@ "Marks" are the contrivance by which TeX produces running heads on pages
which follow the material on those pages: so that the running head for a page
can show the paragraph range for the material which tops it, for instance.

The ornament has to be set in math mode, even in the mark. `\S` and `\P`,
making a section sign and a pilcrow respectively, only work in math mode
because they abbreviate characters found in math fonts but not regular ones,
in TeX's deeply peculiar font encoding system.

@<Work out the next mark to place into the TeX vertical list@> =
	TEMPORARY_TEXT(chaptermark)
	TEMPORARY_TEXT(sectionmark)
	MDRender::stream(chaptermark, rdr, S->owning_chapter->ch_title, 0);
	if (Str::len(chaptermark) > 0) WRITE_TO(sectionmark, " - ");
	MDRender::stream(sectionmark, rdr, S->sect_title, 0);
	WRITE_TO(mark, "%S%S\\quad$\\%S$%S", chaptermark, sectionmark, orn, N);
	DISCARD_TEXT(chaptermark)
	DISCARD_TEXT(sectionmark)

@h Holon names.
Holon names are highlighted in several cute ways: first, we make use of colour
and we drop in the paragraph number of the definition of the macro in small
type; and second, we use cross-reference links.

=
void TeXWeaving::holon_name(text_stream *OUT, markdown_render *rdr, ls_holon *holon, int defn) {
	ls_paragraph *par = holon->corresponding_chunk->owner;
	if (holon->addendum) par = holon->addendum_to->corresponding_chunk->owner;
	if ((defn) && (holon->addendum == FALSE))
		WRITE("\\inwebanchor{para%d}", par->allocation_id + 100);		
	else
		WRITE("\\inweblinktopara{para%d}{", par->allocation_id + 100);
	WRITE("\\definitionsyntaxcolouring{}$\\langle$\\holonnametext{");
	MDRender::stream(OUT, rdr, holon->holon_name, 0);
	WRITE("} \\holonnumbertext{%S}", par->paragraph_number);
	WRITE("\\endcolouring{}");
	WRITE("$\\rangle$ ");
	if (defn) {
		if (holon->addendum) WRITE("$+${}$\\equiv$");
		else WRITE("$\\equiv$");
	}
	if (!((defn) && (holon->addendum == FALSE)))
		WRITE("}");
}

@h Code rendering.
Code is typeset by TeX (with our macros) within vertical strokes; these switch
a sort of typewriter-type verbatim mode on and off. To get an actual stroke, we
must escape from code mode, escape it using a backslash, then re-enter code mode
once again:

=
void TeXWeaving::source_code(text_stream *OUT, markdown_render *rdr,
	weave_order *wv, text_stream *matter, text_stream *colouring, int starts) {
	int current_colour = PLAIN_COLOUR, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(matter); i++) {
		colour_wanted = (int) Str::get_at(colouring, i);
		@<Adjust code colour as necessary@>;
		if (Str::get_at(matter, i) == '|') WRITE("|\\||");
		else WRITE("%c", Str::get_at(matter, i));
	}
	colour_wanted = PLAIN_COLOUR; @<Adjust code colour as necessary@>;
}

@<Adjust code colour as necessary@> =
	if (colour_wanted != current_colour) {
		MDRenderTeX::change_colour(OUT, rdr, colour_wanted, NULL);
		current_colour = colour_wanted;
	}


@h Locale links.

=
void TeXWeaving::locale(OUTPUT_STREAM, markdown_render *rdr, ls_paragraph *par1,
	ls_paragraph *par2, ls_paragraph *from) {
	ls_section *S = LiterateSource::section_of_par(par1);
	ls_section *from_S = LiterateSource::section_of_par(from);
	TEMPORARY_TEXT(nameid)
	TeXWeaving::paragraph_link(nameid, par1);
	MDRenderTeX::link_internal(OUT, nameid, 0);
	DISCARD_TEXT(nameid)
	if ((S) && (S != from_S)) WRITE("%S:", S->sect_range);
	WRITE("$\\%S$%S", LiterateSource::par_ornament(par1), par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
	MDRenderTeX::end_link(OUT, 0);
}

void TeXWeaving::paragraph_link(OUTPUT_STREAM, ls_paragraph *par) {
	ls_section *S = LiterateSource::section_of_par(par);
	WRITE("para");
	if (S)
		for (int i=0; i<Str::len(S->sect_range); i++) {
			inchar32_t c = Str::get_at(S->sect_range, i);
			if (c == '/') WRITE("_");
			else PUT(c);
		}
	WRITE("%S", par->paragraph_number);
}

@h Gadgetry.
This is convenient when rendering out Markdown which contains images. Note that
it actually rewrites the filename, to ensure that the TeX contains a correct
file reference to a locally-stored file.

=
void TeXWeaving::notify_image(markdown_render *rdr, text_stream *image) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	if (Str::includes_character(image, '/')) return;
	if (Str::includes_character(image, '\\')) return;
	filename *F = Filenames::in(
		Pathnames::down(wv->weave_web->path_to_web, I"Figures"),
		image);
	Str::clear(image);
	WRITE_TO(image, "%f", F);
}

@ Return `TRUE` if we have rendered something (or chosen to silently eliminate
this gadget from the weave); or `FALSE` to refuse because the gadget is
incomprehensible to us.

=
int TeXWeaving::render_gadget(markdown_render *rdr, OUTPUT_STREAM,
	int gadget, text_stream *text_operand, int w, int h, int mode, text_stream *path) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);

	switch (gadget) {
		case TEXT_AS_INWEBGADGET:
			@<Render the contents of the named file as code@>;
			return TRUE;
		case DOWNLOAD_INWEBGADGET:
		case HTML_INWEBGADGET:
		case VIDEO_INWEBGADGET:
		case EMBED_INWEBGADGET:
		case AUDIO_INWEBGADGET:
			return TRUE;
		default:
			return FALSE;
	}
}

@<Render the contents of the named file as code@> =
	filename *F = Filenames::from_text_relative(wv->weave_web->path_to_web, path);
	if (TextFiles::exists(F) == FALSE) {
		WRITE_TO(STDERR, "warning: text file at '%S' not found\n", path);
	} else {
		TEMPORARY_TEXT(code)
		TextFiles::write_file_contents(code, F);
		while ((Str::get_last_char(code) == ' ') || 
				(Str::get_last_char(code) == '\t') || 
				(Str::get_last_char(code) == '\n')) Str::delete_last_character(code);
		MDRenderTeX::render_code_block(OUT, mode, rdr, code, text_operand);
		DISCARD_TEXT(code)
	}

@h Carousels.

=
int TeXWeaving::render_ul_as_carousel(markdown_render *rdr, OUTPUT_STREAM, int mode,
	markdown_item *md) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	match_results mr = Regexp::create_mr();
	int count = 1, of = 0;
	for (markdown_item *item = md->down; item; item = item->next) of++;
	for (markdown_item *item = md->down; item; item = item->next) {
		int positioning = 0;
		MDRender::caption(&mr, item, &positioning);
		TEMPORARY_TEXT(carousel_id)
		TEMPORARY_TEXT(carousel_dots_id)
		TeXWeaving::render_carousel_top(OUT, rdr, wv, count, of, carousel_id, carousel_dots_id, mr.exp[0], positioning);
		int m = mode | LOOSE_MDRMODE;
		for (markdown_item *c = item->down->next; c; c = c->next) {
			MDRender::render_in_mode(OUT, rdr, c, m);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
		TeXWeaving::render_carousel_bottom(OUT, rdr, wv, count, of, carousel_id, carousel_dots_id, mr.exp[0], positioning);
		DISCARD_TEXT(carousel_id)
		DISCARD_TEXT(carousel_dots_id)
		count++;
	}
	Regexp::dispose_of(&mr);
	return TRUE;
}
 
void TeXWeaving::render_carousel_top(OUTPUT_STREAM, markdown_render *rdr, weave_order *wv, int slide_number, int slide_of,
	text_stream *carousel_id, text_stream *carousel_dots_id, text_stream *caption, int positioning) {
	WRITE("\n\\medskip\\hrule\\smallskip\n");
	if (positioning > 0) @<Place caption here@>;
}

void TeXWeaving::render_carousel_bottom(OUTPUT_STREAM, markdown_render *rdr, weave_order *wv, int slide_number, int slide_of,
	text_stream *carousel_id, text_stream *carousel_dots_id, text_stream *caption, int positioning) {
	if (positioning <= 0) @<Place caption here@>;
	WRITE("\n\\smallskip\\hrule\\medskip\n");
}

@<Place caption here@> =
	if (Str::len(caption) > 0) {
		WRITE("\\centerline{\\bf %d/%d. ", slide_number, slide_of);
		MDRender::stream(OUT, rdr, caption, 0);
		WRITE("}\n\n");
	}
