[TeX::] TeX Format.

To provide for weaving in the standard maths and science typesetting
software, TeX.

@h Creation.

=
void TeX::create(void) {
	@<Create TeX format@>;
	@<Create DVI format@>;
	@<Create PDF format@>;
}

@<Create TeX format@> =
	weave_format *wf = Formats::create_weave_format(I"TeX", I".tex");
	METHOD_ADD(wf, RENDER_FOR_MTID, TeX::render_TeX);
	METHOD_ADD(wf, CHAPTER_TP_FOR_MTID, TeX::chapter_title_page);
	METHOD_ADD(wf, PREFORM_DOCUMENT_FOR_MTID, TeX::preform_document);

@<Create DVI format@> =
	weave_format *wf = Formats::create_weave_format(I"DVI", I".tex");
	METHOD_ADD(wf, RENDER_FOR_MTID, TeX::render_DVI);
	METHOD_ADD(wf, CHAPTER_TP_FOR_MTID, TeX::chapter_title_page);
	METHOD_ADD(wf, PREFORM_DOCUMENT_FOR_MTID, TeX::preform_document);

@<Create PDF format@> =
	weave_format *wf = Formats::create_weave_format(I"PDF", I".tex");
	METHOD_ADD(wf, RENDER_FOR_MTID, TeX::render_PDF);
	METHOD_ADD(wf, CHAPTER_TP_FOR_MTID, TeX::chapter_title_page);
	METHOD_ADD(wf, PREFORM_DOCUMENT_FOR_MTID, TeX::preform_document);

@h Methods.
For documentation, see "Weave Fornats".

=
typedef struct TeX_render_state {
	struct text_stream *OUT;
	struct weave_order *wv;
	int as_DVI;
	int as_PDF;
} TeX_render_state;

void TeX::render_TeX(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	TeX::render_inner(self, OUT, tree, FALSE, FALSE);
}
void TeX::render_DVI(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	TeX::render_inner(self, OUT, tree, TRUE, FALSE);
}
void TeX::render_PDF(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	TeX::render_inner(self, OUT, tree, FALSE, TRUE);
}

void TeX::render_inner(weave_format *self, text_stream *OUT, heterogeneous_tree *tree, int as_dvi, int as_pdf) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	TeX_render_state trs;
	trs.OUT = OUT;
	trs.wv = C->wv;
	trs.as_DVI = as_dvi;
	trs.as_PDF = as_pdf;
	Trees::traverse_from(tree->root, &TeX::render_visit, (void *) &trs, 0);
}

int TeX::render_visit(tree_node *N, void *state, int L) {
	TeX_render_state *trs = (TeX_render_state *) state;
	text_stream *OUT = trs->OUT;
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
	else if (N->type == weave_linebreak_node_type) @<Render linebreak@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
	else if (N->type == weave_audio_node_type) @<Render nothing@>
	else if (N->type == weave_material_node_type) @<Render material@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_pmac_node_type) @<Render pmac@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_chapter_node_type) @<Render nothing@>
	else if (N->type == weave_section_node_type) @<Render section@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_commentary_node_type) @<Render commentary@>
	else if (N->type == weave_carousel_slide_node_type) @<Render nothing@>
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
	else internal_error("unable to render unknown node");
	return TRUE;
}

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	WRITE("%% %S\n", C->banner);

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	WRITE("%% %S\n", C->rennab);
	WRITE("\\end\n");

@<Render chapter header@> =
	weave_chapter_header_node *C = RETRIEVE_POINTER_weave_chapter_header_node(N->content);
	if (Str::ne(C->chap->md->ch_range, I"S"))
		TeX::paragraph_heading(trs->wv->format, OUT, trs->wv, FIRST_IN_LINKED_LIST(section, C->chap->sections), NULL, C->chap->md->ch_title, 3, FALSE);

@<Render header@> =
	weave_section_header_node *C = RETRIEVE_POINTER_weave_section_header_node(N->content);
	TeX::paragraph_heading(trs->wv->format, OUT, trs->wv, C->sect, NULL, C->sect->md->sect_title, 2, FALSE);

@<Render purpose@> =
	weave_section_purpose_node *C = RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	TeX::subheading(trs->wv->format, OUT, trs->wv, 2, C->purpose, NULL);

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	TeX::subheading(trs->wv->format, OUT, trs->wv, 1, C->text, NULL);

@<Render bar@> =
	WRITE("\\par\\medskip\\noindent\\hrule\\medskip\\noindent\n");

@<Render pagebreak@> =
	WRITE("\\vfill\\eject\n");

@<Render linebreak@> =
	WRITE("\n");

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C = RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	TeX::paragraph_heading(trs->wv->format, OUT, trs->wv, C->para->under_section, C->para, I"Dunno", 0, FALSE);

@<Render endnote@> =
	WRITE("\\par\\noindent\\penalty10000\n");
	WRITE("{\\usagefont ");
	@<Recurse tne renderer through children nodes@>;
	WRITE("}\\smallskip\n");
	return FALSE;

@ TeX itself has an almost defiant lack of support for anything pictorial,
which is one reason it didn't live up to its hope of being the definitive basis
for typography; even today the loose confederation of TeX-like programs and
extensions lack standard approaches. Here we're going to use |pdftex| features,
having nothing better. All we're trying for is to insert a picture, scaled
to a given width, into the text at the current position.

@<Render figure@> =
	if (trs->as_PDF) {
		weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
		WRITE("\\pdfximage");
		if (C->w >= 0)
			WRITE(" width %d cm{../Figures/%S}\n", C->w, C->figname);
		else if (C->h >= 0)
			WRITE(" height %d cm{../Figures/%S}\n", C->h, C->figname);
		else
			WRITE("{../Figures/%S}\n", C->figname);
		WRITE("\\smallskip\\noindent"
			"\\hbox to\\hsize{\\hfill\\pdfrefximage \\pdflastximage\\hfill}"
			"\\smallskip\n");
	}

@<Render material@> =
	weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
	paragraph *first_in_para = NULL;
	if ((N == N->parent->child) &&
		(N->parent->type == weave_paragraph_heading_node_type)) {
		weave_paragraph_heading_node *PC =
			RETRIEVE_POINTER_weave_paragraph_heading_node(N->parent->content);
		first_in_para = PC->para;
	}
	if (C->material_type == COMMENTARY_MATERIAL)
		@<Deal with a commentary material node@>
	else if (C->material_type == CODE_MATERIAL)
		@<Deal with a code material node@>
	else if (C->material_type == FOOTNOTES_MATERIAL)
		@<Deal with a footnotes material node@>
	else if (C->material_type == ENDNOTES_MATERIAL)
		@<Deal with a endnotes material node@>
	else if (C->material_type == MACRO_MATERIAL)
		@<Deal with a macro material node@>
	else if (C->material_type == DEFINITION_MATERIAL)
		@<Deal with a definition material node@>;
	return FALSE;

@<Deal with a commentary material node@> =
	@<Recurse tne renderer through children nodes@>;
	WRITE("\n");

@<Deal with a code material node@> =
	WRITE("\\beginlines\n");
	@<Recurse tne renderer through children nodes@>;
	WRITE("\\endlines\n");

@<Deal with a footnotes material node@> =
	@<Recurse tne renderer through children nodes@>;

@<Deal with a endnotes material node@> =
	@<Recurse tne renderer through children nodes@>;

@<Deal with a macro material node@> =
	@<Recurse tne renderer through children nodes@>;
	WRITE("\n");

@<Deal with a definition material node@> =
	WRITE("\\beginlines\n");
	@<Recurse tne renderer through children nodes@>;
	WRITE("\\endlines\n");

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render nothing@> =
	;

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render pmac@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	if (trs->as_PDF)
		TeX::para_macro_PDF_1(trs->wv->format, OUT, trs->wv, C->pmac, C->defn);
	TeX::para_macro(trs->wv->format, OUT, trs->wv, C->pmac, C->defn);
	if (trs->as_PDF)
		TeX::para_macro_PDF_2(trs->wv->format, OUT, trs->wv, C->pmac, C->defn);

@<Render vskip@> =
	weave_vskip_node *C = RETRIEVE_POINTER_weave_vskip_node(N->content);
	if (C->in_comment) WRITE("\\smallskip\\par\\noindent%%\n");
	else WRITE("\\smallskip\n");

@<Render section@> =
	weave_section_node *C = RETRIEVE_POINTER_weave_section_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render code line@> =
	WRITE("\\smallskip\\par\\noindent ");
	WRITE("|");
	@<Recurse tne renderer through children nodes@>;
	WRITE("|");
	WRITE("\n");
	return FALSE;

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	WRITE("%S", C->fn->function_name);
	return FALSE;

@<Render commentary@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	if (C->in_code) WRITE(" |\\hfill{\\ttninepoint\\it ");
	TeX::commentary_text(NULL, OUT, trs->wv, C->text);
	if (C->in_code) WRITE("}|");

@<Render toc@> =
	WRITE("\\medskip\\hrule\\smallskip\\par\\noindent{\\usagefont ");
	for (tree_node *M = N->child; M; M = M->next) {
		Trees::traverse_from(M, &TeX::render_visit, (void *) trs, L+1);
		if (M->next) WRITE("; ");
	}
	WRITE("}\\par\\medskip\\hrule\\bigskip\n");
	return FALSE;

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	WRITE("%S~%S", C->text1, C->text2);

@<Render weave_chapter_title_page_node@> =
	weave_chapter_title_page_node *C = RETRIEVE_POINTER_weave_chapter_title_page_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	WRITE("|{\\ninebf %S} |", C->keyword);

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	int starts = FALSE;
	if (N == N->parent->child) starts = TRUE;
	TeX::source_code(trs->wv->format, OUT, trs->wv,
		C->matter, C->colouring, starts);

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
	WRITE("\\quotesource{%S}\n", C->text);

@<Render function defn@> =
	weave_function_defn_node *C = RETRIEVE_POINTER_weave_function_defn_node(N->content);
	TeX::change_colour_PDF(OUT, FUNCTION_COLOUR, TRUE);
	WRITE("%S", C->fn->function_name);
	TeX::change_colour_PDF(OUT, PLAIN_COLOUR, TRUE);
	return FALSE;

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	if (Str::len(C->label) > 0) {
		if (C->depth == 1) WRITE("\\item{(%S)}", C->label);
		else WRITE("\\itemitem{(%S)}", C->label);
	} else {
		if (C->depth == 1) WRITE("\\item{}");
		else WRITE("\\itemitem{}");
	}

@<Render grammar index@> =
	InCSupport::weave_grammar_index(OUT);

@<Render inline@> =
	WRITE("|");
	@<Recurse tne renderer through children nodes@>;
	WRITE("|");
	return FALSE;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	WRITE("$\\%S$%S", C->par1->ornament, C->par1->paragraph_number);
	if (C->par2) WRITE("-%S", C->par2->paragraph_number);

@<Render maths@> =
	weave_maths_node *C = RETRIEVE_POINTER_weave_maths_node(N->content);
	if (C->displayed) WRITE("$$"); else WRITE("$");
	WRITE("%S", C->content);
	if (C->displayed) WRITE("$$"); else WRITE("$");

@<Recurse tne renderer through children nodes@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &TeX::render_visit, (void *) trs, L+1);

@ =
int TeX::yes(weave_format *self, weave_order *wv) {
	return TRUE;
}

@ =
void TeX::subheading(weave_format *self, text_stream *OUT, weave_order *wv,
	int level, text_stream *comment, text_stream *head) {
	switch (level) {
		case 1:
			WRITE("\\par\\noindent{\\bf %S}\\mark{%S}\\medskip\n",
				comment, head);
			break;
		case 2:
			WRITE("\\smallskip\\par\\noindent{\\it %S}\\smallskip\\noindent\n",
				comment);
			if (head) TeX::commentary_text(self, OUT, wv, head);
			break;
	}
}

@ =
void TeX::toc(weave_format *self, text_stream *OUT, weave_order *wv, int stage,
	text_stream *text1, text_stream *text2, paragraph *P) {
	switch (stage) {
		case 1:
			WRITE("\\medskip\\hrule\\smallskip\\par\\noindent{\\usagefont ");
			break;
		case 2:
			WRITE("; ");
			break;
		case 3:
			WRITE("%S~%S", text1, text2);
			break;
		case 4:
			WRITE("}\\par\\medskip\\hrule\\bigskip\n");
			break;
	}
}

@ =
void TeX::chapter_title_page(weave_format *self, text_stream *OUT, weave_order *wv,
	chapter *C) {
	WRITE("%S\\medskip\n", C->md->rubric);
	section *S;
	LOOP_OVER_LINKED_LIST(S, section, C->sections) {
		WRITE("\\smallskip\\noindent ");
		if (wv->pattern->number_sections) WRITE("%d. ", S->printed_number);
		WRITE("{\\it %S}\\qquad\n%S", S->md->sect_title, S->sect_purpose);
	}
}

@ =
text_stream *P_literal = NULL;
void TeX::paragraph_heading(weave_format *self, text_stream *OUT, weave_order *wv,
	section *S, paragraph *P, text_stream *heading_text, int weight, int no_skip) {
	text_stream *TeX_macro = NULL;
	@<Choose which TeX macro to use in order to typeset the new paragraph heading@>;
	
	if (P_literal == NULL) P_literal = Str::new_from_wide_string(L"P");
	text_stream *orn = (P)?(P->ornament):P_literal;
	text_stream *N = (P)?(P->paragraph_number):NULL;
	TEMPORARY_TEXT(mark);
	@<Work out the next mark to place into the TeX vertical list@>;
	TEMPORARY_TEXT(modified);
	Str::copy(modified, heading_text);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, modified, L"(%c*?): (%c*)")) {
		Str::clear(modified);
		WRITE_TO(modified, "{\\sinchhigh %S}\\quad %S", mr.exp[0], mr.exp[1]);
	}
	if (weight == 2)
		WRITE("\\%S{%S}{%S}{%S}{\\%S}{%S}%%\n",
			TeX_macro, N, modified, mark, orn, NULL);
	else
		WRITE("\\%S{%S}{%S}{%S}{\\%S}{%S}%%\n",
			TeX_macro, N, modified, mark, orn, S->md->sect_range);
	DISCARD_TEXT(mark);
	DISCARD_TEXT(modified);
	Regexp::dispose_of(&mr);
}

@ We want to have different heading styles for different weights, and TeX is
horrible at using macro parameters as function arguments, so we don't want
to pass the weight that way. Instead we use
= (text)
	\weavesection
	\weavesections
	\weavesectionss
	\weavesectionsss
=
where the weight is the number of terminal |s|s, 0 to 3. (TeX macros,
lamentably, are not allowed digits in their name.) In the cases 0 and 1, we
also have variants |\nsweavesection| and |\nsweavesections| which are
the same, but with the initial vertical spacing removed; these allow us to
prevent unsightly excess white space in certain configurations of a section.

@<Choose which TeX macro to use in order to typeset the new paragraph heading@> =
	switch (weight) {
		case 0: TeX_macro = I"weavesection"; break;
		case 1: TeX_macro = I"weavesections"; break;
		case 2: TeX_macro = I"weavesectionss"; break;
		default: TeX_macro = I"weavesectionsss"; break;
	}
	if (wv->theme_match) {
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

The ornament has to be set in math mode, even in the mark. |\S| and |\P|,
making a section sign and a pilcrow respectively, only work in math mode
because they abbreviate characters found in math fonts but not regular ones,
in TeX's deeply peculiar font encoding system.

@<Work out the next mark to place into the TeX vertical list@> =
	text_stream *chaptermark = Str::new();
	text_stream *sectionmark = Str::new();
	if (weight == 3) {
		Str::copy(chaptermark, S->owning_chapter->md->ch_title);
		Str::clear(sectionmark);
	}
	if (weight == 2) {
		Str::copy(sectionmark, S->md->sect_title);
		Str::clear(chaptermark);
		if (Str::len(chaptermark) > 0) {
			Str::clear(sectionmark);
			WRITE_TO(sectionmark, " - %S", S->md->sect_title);
		}
	}
	WRITE_TO(mark, "%S%S\\quad$\\%S$%S", chaptermark, sectionmark, orn, N);

@ Code is typeset by TeX within vertical strokes; these switch a sort of
typewriter-type verbatim mode on and off. To get an actual stroke, we must
escape from code mode, escape it using a backslash, then re-enter code
mode once again:

=
void TeX::source_code(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *matter, text_stream *colouring, int starts) {
	int current_colour = PLAIN_COLOUR, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(matter); i++) {
		colour_wanted = Str::get_at(colouring, i); @<Adjust code colour as necessary@>;
		if (Str::get_at(matter, i) == '|') WRITE("|\\||");
		else WRITE("%c", Str::get_at(matter, i));
	}
	colour_wanted = PLAIN_COLOUR; @<Adjust code colour as necessary@>;
}

@ We actually use |\qquad| horizontal spaces rather than risk using TeX's
messy alignment system:

@<Weave a suitable horizontal advance for that many tab stops@> =
	int tab_stops_of_indentation = Str::remove_indentation(matter, 4);
	for (int i=0; i<tab_stops_of_indentation; i++) WRITE("\\qquad");

@<Adjust code colour as necessary@> =
	if (colour_wanted != current_colour) {
		TeX::change_colour_PDF(OUT, colour_wanted, TRUE);
		current_colour = colour_wanted;
	}

@ =
void TeX::change_colour_PDF(text_stream *OUT, int col, int in_code) {
	char *inout = "";
	if (in_code) inout = "|";
	switch (col) {
		case DEFINITION_COLOUR:
			WRITE("%s\\pdfliteral direct{1 1 0 0 k}%s", inout, inout); break;
		case FUNCTION_COLOUR:
			WRITE("%s\\pdfliteral direct{0 1 1 0 k}%s", inout, inout); break;
		case PLAIN_COLOUR:
			WRITE("%s\\special{PDF:0 g}%s", inout, inout); break;
		case EXTRACT_COLOUR:
			WRITE("%s\\special{PDF:0 g}%s", inout, inout); break;
	}
}

@ Any usage of angle-macros is highlighted in several cute ways: first,
we make use of colour and we drop in the paragraph number of the definition
of the macro in small type; and second, we use cross-reference links.

In the PDF format, these three are all called, in sequence below; in TeX
or DVI, only the middle one is.

=
void TeX::para_macro_PDF_1(weave_format *self, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn) {
}
void TeX::para_macro(weave_format *self, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn) {
	if (defn)
		WRITE("|\\pdfdest num %d fit ",
			pmac->allocation_id + 100);
	else
		WRITE("|\\pdfstartlink attr{/C [0.9 0 0] /Border [0 0 0]} goto num %d ",
			pmac->allocation_id + 100);
	WRITE("$\\langle${\\xreffont");
	TeX::change_colour_PDF(OUT, DEFINITION_COLOUR, FALSE);
	WRITE("%S ", pmac->macro_name);
	WRITE("{\\sevenss %S}}", pmac->defining_paragraph->paragraph_number);
	TeX::change_colour_PDF(OUT, PLAIN_COLOUR, FALSE);
	WRITE("$\\rangle$ ");
	if (defn)
		WRITE("$\\equiv$|");
	else
		WRITE("\\pdfendlink|");
}
void TeX::para_macro_PDF_2(weave_format *self, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn) {
}

@ =
void TeX::after_definitions(weave_format *self, text_stream *OUT, weave_order *wv) {
	WRITE("\\smallskip\n");
}

@ =
void TeX::commentary_text(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *id) {
	int math_mode = FALSE;
	for (int i=0; i < Str::len(id); i++) {
		switch (Str::get_at(id, i)) {
			case '$': math_mode = (math_mode)?FALSE:TRUE;
				WRITE("%c", Str::get_at(id, i)); break;
			case '_': if (math_mode) WRITE("_"); else WRITE("\\_"); break;
			case '"':
				if ((Str::get_at(id, i) == '"') &&
					((i==0) || (Str::get_at(id, i-1) == ' ') ||
						(Str::get_at(id, i-1) == '(')))
					WRITE("``");
				else
					WRITE("''");
				break;
			default: WRITE("%c", Str::get_at(id, i));
				break;
		}
	}
}

@ =
void TeX::locale(weave_format *self, text_stream *OUT, weave_order *wv,
	paragraph *par1, paragraph *par2) {
	WRITE("$\\%S$%S", par1->ornament, par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
}

@ =
void TeX::tail(weave_format *self, text_stream *OUT, weave_order *wv,
	text_stream *comment, section *S) {
	WRITE("%% %S\n", comment);
	WRITE("\\end\n");
}

@ The following is called only when the language is InC, and the weave is of
the special Preform grammar document.

=
int TeX::preform_document(weave_format *self, text_stream *OUT, web *W, weave_order *wv,
	chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *concluding_comment) {
	if (L->preform_nonterminal_defined) {
		preform_production_count = 0;
		@<Weave the opening line of the nonterminal definition@>;
		return TRUE;
	} else {
		if (L->category == PREFORM_GRAMMAR_LCAT) {
			@<Weave a line from the body of the nonterminal definition@>;
			return TRUE;
		}
	}
	return FALSE;
}

@<Weave the opening line of the nonterminal definition@> =
	WRITE("\\nonterminal{%S} |::=|",
		L->preform_nonterminal_defined->unangled_name);
	if (L->preform_nonterminal_defined->as_function) {
		WRITE("\\quad{\\it internal definition");
		if (L->preform_nonterminal_defined->voracious)
			WRITE(" (voracious)");
		else if (L->preform_nonterminal_defined->min_word_count ==
			L->preform_nonterminal_defined->min_word_count)
			WRITE(" (%d word%s)",
				L->preform_nonterminal_defined->min_word_count,
				(L->preform_nonterminal_defined->min_word_count != 1)?"s":"");
		WRITE("}");
	}
	WRITE("\n");

@<Weave a line from the body of the nonterminal definition@> =
	TEMPORARY_TEXT(problem);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, matter, L"Issue (%c*?) problem")) Str::copy(problem, mr.exp[0]);
	else if (Regexp::match(&mr, matter, L"FAIL_NONTERMINAL %+")) WRITE_TO(problem, "fail and skip");
	else if (Regexp::match(&mr, matter, L"FAIL_NONTERMINAL")) WRITE_TO(problem, "fail");
	preform_production_count++;
	WRITE_TO(matter, "|%S|", L->text_operand);
	while (Regexp::match(&mr, matter, L"(%c+?)|(%c+)")) {
		Str::clear(matter);
		WRITE_TO(matter, "%S___stroke___%S", mr.exp[0], mr.exp[1]);
	}
	while (Regexp::match(&mr, matter, L"(%c*?)___stroke___(%c*)")) {
		Str::clear(matter);
		WRITE_TO(matter, "%S|\\||%S", mr.exp[0], mr.exp[1]);
	}
	while (Regexp::match(&mr, matter, L"(%c*)<(%c*?)>(%c*)")) {
		Str::clear(matter);
		WRITE_TO(matter, "%S|\\nonterminal{%S}|%S",
			mr.exp[0], mr.exp[1], mr.exp[2]);
	}
	TEMPORARY_TEXT(label);
	int N = preform_production_count;
	int L = ((N-1)%26) + 1;
	if (N <= 26) WRITE_TO(label, "%c", 'a'+L-1);
	else if (N <= 52) WRITE_TO(label, "%c%c", 'a'+L-1, 'a'+L-1);
	else if (N <= 78) WRITE_TO(label, "%c%c%c", 'a'+L-1, 'a'+L-1, 'a'+L-1);
	else {
		int n = (N-1)/26;
		WRITE_TO(label, "%c${}^{%d}$", 'a'+L-1, n);
	}
	WRITE("\\qquad {\\hbox to 0.4in{\\it %S\\hfil}}%S", label, matter);
	if (Str::len(problem) > 0)
		WRITE("\\hfill$\\longrightarrow$ {\\ttninepoint\\it %S}", problem);
	else if (Str::len(concluding_comment) > 0) {
		WRITE(" \\hfill{\\ttninepoint\\it ");
		if (Str::len(concluding_comment) > 0)
			TeX::commentary_text(NULL, OUT, wv, concluding_comment);
//			Formats::text_comment(OUT, wv, concluding_comment);
		WRITE("}");
	}
	WRITE("\n");
	DISCARD_TEXT(label);
	DISCARD_TEXT(problem);
	Regexp::dispose_of(&mr);

@h Post-processing.

=
void TeX::post_process_report(weave_format *self, weave_order *wv) {
	RunningTeX::report_on_post_processing(wv);
}

@ =
int TeX::post_process_substitute(weave_format *self, text_stream *OUT,
	weave_order *wv, text_stream *detail, weave_pattern *pattern) {
	return RunningTeX::substitute_post_processing_data(OUT, wv, detail);
}

@h Removing math mode.
"Math mode", in TeX jargon, is what happens when a mathematical formula
is written inside dollar signs: in |Answer is $x+y^2$|, the math mode
content is |x+y^2|. But since math mode doesn't (easily) exist in HTML,
for example, we want to strip it out if the format is not TeX-related.
To do this, the weaver calls the following.

=
void TeX::remove_math_mode(OUTPUT_STREAM, text_stream *text) {
	TEMPORARY_TEXT(math_matter);
	TeX::remove_math_mode_range(math_matter, text, 0, Str::len(text)-1);
	WRITE("%S", math_matter);
	DISCARD_TEXT(math_matter);
}

void TeX::remove_math_mode_range(OUTPUT_STREAM, text_stream *text, int from, int to) {
	for (int i=from; i <= to; i++) {
		@<Remove the over construction@>;
	}
	for (int i=from; i <= to; i++) {
		@<Remove the rm and it constructions@>;
		@<Remove the sqrt constructions@>;
	}
	int math_mode = FALSE;
	for (int i=from; i <= to; i++) {
		switch (Str::get_at(text, i)) {
			case '$':
				if (Str::get_at(text, i+1) == '$') i++;
				math_mode = (math_mode)?FALSE:TRUE; break;
			case '~': if (math_mode) WRITE(" "); else WRITE("~"); break;
			case '\\': @<Do something to strip out a TeX macro@>; break;
			default: PUT(Str::get_at(text, i)); break;
		}
	}
}

@ Here we remove |{{top}\over{bottom}}|, converting it to |((top) / (bottom))|.

@<Remove the over construction@> =
	if ((Str::get_at(text, i) == '\\') &&
		(Str::get_at(text, i+1) == 'o') && (Str::get_at(text, i+2) == 'v') &&
		(Str::get_at(text, i+3) == 'e') && (Str::get_at(text, i+4) == 'r') &&
		(Str::get_at(text, i+5) == '{')) {
		int bl = 1;
		int j = i-1;
		for (; j >= from; j--) {
			wchar_t c = Str::get_at(text, j);
			if (c == '{') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '}') bl++;
		}
		TeX::remove_math_mode_range(OUT, text, from, j-1);
		WRITE("((");
		TeX::remove_math_mode_range(OUT, text, j+2, i-2);
		WRITE(") / (");
		j=i+6; bl = 1;
		for (; j <= to; j++) {
			wchar_t c = Str::get_at(text, j);
			if (c == '}') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '{') bl++;
		}
		TeX::remove_math_mode_range(OUT, text, i+6, j-1);
		WRITE("))");
		TeX::remove_math_mode_range(OUT, text, j+2, to);
		return;
	}

@ Here we remove |{\rm text}|, converting it to |text|, and similarly |\it|.

@<Remove the rm and it constructions@> =
	if ((Str::get_at(text, i) == '{') && (Str::get_at(text, i+1) == '\\') &&
		(((Str::get_at(text, i+2) == 'r') && (Str::get_at(text, i+3) == 'm')) ||
			((Str::get_at(text, i+2) == 'i') && (Str::get_at(text, i+3) == 't'))) &&
		(Str::get_at(text, i+4) == ' ')) {
		TeX::remove_math_mode_range(OUT, text, from, i-1);
		int j=i+5;
		for (; j <= to; j++)
			if (Str::get_at(text, j) == '}')
				break;
		TeX::remove_math_mode_range(OUT, text, i+5, j-1);
		TeX::remove_math_mode_range(OUT, text, j+1, to);
		return;
	}

@ Here we remove |\sqrt{N}|, converting it to |sqrt(N)|. As a special case,
we also look out for |{}^3\sqrt{N}| for cube root.

@<Remove the sqrt constructions@> =
	if ((Str::get_at(text, i) == '\\') &&
		(Str::get_at(text, i+1) == 's') && (Str::get_at(text, i+2) == 'q') &&
		(Str::get_at(text, i+3) == 'r') && (Str::get_at(text, i+4) == 't') &&
		(Str::get_at(text, i+5) == '{')) {
		if ((Str::get_at(text, i-4) == '{') &&
			(Str::get_at(text, i-3) == '}') &&
			(Str::get_at(text, i-2) == '^') &&
			(Str::get_at(text, i-1) == '3')) {
			TeX::remove_math_mode_range(OUT, text, from, i-5);
			WRITE(" curt(");				
		} else {
			TeX::remove_math_mode_range(OUT, text, from, i-1);
			WRITE(" sqrt(");
		}
		int j=i+6, bl = 1;
		for (; j <= to; j++) {
			wchar_t c = Str::get_at(text, j);
			if (c == '}') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '{') bl++;
		}
		TeX::remove_math_mode_range(OUT, text, i+6, j-1);
		WRITE(")");
		TeX::remove_math_mode_range(OUT, text, j+1, to);
		return;
	}

@<Do something to strip out a TeX macro@> =
	TEMPORARY_TEXT(macro);
	i++;
	while ((i < Str::len(text)) && (Characters::isalpha(Str::get_at(text, i))))
		PUT_TO(macro, Str::get_at(text, i++));
	if (Str::eq(macro, I"not")) @<Remove the not prefix@>
	else @<Remove a general macro@>;
	DISCARD_TEXT(macro);
	i--;

@<Remove a general macro@> =
	if (Str::eq(macro, I"leq")) WRITE("<=");
	else if (Str::eq(macro, I"geq")) WRITE(">=");
	else if (Str::eq(macro, I"sim")) WRITE("~");
	else if (Str::eq(macro, I"hbox")) WRITE("");
	else if (Str::eq(macro, I"left")) WRITE("");
	else if (Str::eq(macro, I"right")) WRITE("");
	else if (Str::eq(macro, I"Rightarrow")) WRITE("=>");
	else if (Str::eq(macro, I"Leftrightarrow")) WRITE("<=>");
	else if (Str::eq(macro, I"to")) WRITE("-->");
	else if (Str::eq(macro, I"rightarrow")) WRITE("-->");
	else if (Str::eq(macro, I"longrightarrow")) WRITE("-->");
	else if (Str::eq(macro, I"leftarrow")) WRITE("<--");
	else if (Str::eq(macro, I"longleftarrow")) WRITE("<--");
	else if (Str::eq(macro, I"lbrace")) WRITE("{");
	else if (Str::eq(macro, I"mid")) WRITE("|");
	else if (Str::eq(macro, I"rbrace")) WRITE("}");
	else if (Str::eq(macro, I"cdot")) WRITE(".");
	else if (Str::eq(macro, I"cdots")) WRITE("...");
	else if (Str::eq(macro, I"dots")) WRITE("...");
	else if (Str::eq(macro, I"times")) WRITE("*");
	else if (Str::eq(macro, I"quad")) WRITE("  ");
	else if (Str::eq(macro, I"qquad")) WRITE("    ");
	else if (Str::eq(macro, I"TeX")) WRITE("TeX");
	else if (Str::eq(macro, I"neq")) WRITE("!=");
	else if (Str::eq(macro, I"noteq")) WRITE("!=");
	else if (Str::eq(macro, I"ell")) WRITE("l");
	else if (Str::eq(macro, I"log")) WRITE("log");
	else if (Str::eq(macro, I"exp")) WRITE("exp");
	else if (Str::eq(macro, I"sin")) WRITE("sin");
	else if (Str::eq(macro, I"cos")) WRITE("cos");
	else if (Str::eq(macro, I"tan")) WRITE("tan");
	else if (Str::eq(macro, I"top")) WRITE("T");
	else if (Str::eq(macro, I"Alpha")) PUT((wchar_t) 0x0391);
	else if (Str::eq(macro, I"Beta")) PUT((wchar_t) 0x0392);
	else if (Str::eq(macro, I"Gamma")) PUT((wchar_t) 0x0393);
	else if (Str::eq(macro, I"Delta")) PUT((wchar_t) 0x0394);
	else if (Str::eq(macro, I"Epsilon")) PUT((wchar_t) 0x0395);
	else if (Str::eq(macro, I"Zeta")) PUT((wchar_t) 0x0396);
	else if (Str::eq(macro, I"Eta")) PUT((wchar_t) 0x0397);
	else if (Str::eq(macro, I"Theta")) PUT((wchar_t) 0x0398);
	else if (Str::eq(macro, I"Iota")) PUT((wchar_t) 0x0399);
	else if (Str::eq(macro, I"Kappa")) PUT((wchar_t) 0x039A);
	else if (Str::eq(macro, I"Lambda")) PUT((wchar_t) 0x039B);
	else if (Str::eq(macro, I"Mu")) PUT((wchar_t) 0x039C);
	else if (Str::eq(macro, I"Nu")) PUT((wchar_t) 0x039D);
	else if (Str::eq(macro, I"Xi")) PUT((wchar_t) 0x039E);
	else if (Str::eq(macro, I"Omicron")) PUT((wchar_t) 0x039F);
	else if (Str::eq(macro, I"Pi")) PUT((wchar_t) 0x03A0);
	else if (Str::eq(macro, I"Rho")) PUT((wchar_t) 0x03A1);
	else if (Str::eq(macro, I"Varsigma")) PUT((wchar_t) 0x03A2);
	else if (Str::eq(macro, I"Sigma")) PUT((wchar_t) 0x03A3);
	else if (Str::eq(macro, I"Tau")) PUT((wchar_t) 0x03A4);
	else if (Str::eq(macro, I"Upsilon")) PUT((wchar_t) 0x03A5);
	else if (Str::eq(macro, I"Phi")) PUT((wchar_t) 0x03A6);
	else if (Str::eq(macro, I"Chi")) PUT((wchar_t) 0x03A7);
	else if (Str::eq(macro, I"Psi")) PUT((wchar_t) 0x03A8);
	else if (Str::eq(macro, I"Omega")) PUT((wchar_t) 0x03A9);
	else if (Str::eq(macro, I"alpha")) PUT((wchar_t) 0x03B1);
	else if (Str::eq(macro, I"beta")) PUT((wchar_t) 0x03B2);
	else if (Str::eq(macro, I"gamma")) PUT((wchar_t) 0x03B3);
	else if (Str::eq(macro, I"delta")) PUT((wchar_t) 0x03B4);
	else if (Str::eq(macro, I"epsilon")) PUT((wchar_t) 0x03B5);
	else if (Str::eq(macro, I"zeta")) PUT((wchar_t) 0x03B6);
	else if (Str::eq(macro, I"eta")) PUT((wchar_t) 0x03B7);
	else if (Str::eq(macro, I"theta")) PUT((wchar_t) 0x03B8);
	else if (Str::eq(macro, I"iota")) PUT((wchar_t) 0x03B9);
	else if (Str::eq(macro, I"kappa")) PUT((wchar_t) 0x03BA);
	else if (Str::eq(macro, I"lambda")) PUT((wchar_t) 0x03BB);
	else if (Str::eq(macro, I"mu")) PUT((wchar_t) 0x03BC);
	else if (Str::eq(macro, I"nu")) PUT((wchar_t) 0x03BD);
	else if (Str::eq(macro, I"xi")) PUT((wchar_t) 0x03BE);
	else if (Str::eq(macro, I"omicron")) PUT((wchar_t) 0x03BF);
	else if (Str::eq(macro, I"pi")) PUT((wchar_t) 0x03C0);
	else if (Str::eq(macro, I"rho")) PUT((wchar_t) 0x03C1);
	else if (Str::eq(macro, I"varsigma")) PUT((wchar_t) 0x03C2);
	else if (Str::eq(macro, I"sigma")) PUT((wchar_t) 0x03C3);
	else if (Str::eq(macro, I"tau")) PUT((wchar_t) 0x03C4);
	else if (Str::eq(macro, I"upsilon")) PUT((wchar_t) 0x03C5);
	else if (Str::eq(macro, I"phi")) PUT((wchar_t) 0x03C6);
	else if (Str::eq(macro, I"chi")) PUT((wchar_t) 0x03C7);
	else if (Str::eq(macro, I"psi")) PUT((wchar_t) 0x03C8);
	else if (Str::eq(macro, I"omega")) PUT((wchar_t) 0x03C9);
	else if (Str::eq(macro, I"exists")) PUT((wchar_t) 0x2203);
	else if (Str::eq(macro, I"in")) PUT((wchar_t) 0x2208);
	else if (Str::eq(macro, I"forall")) PUT((wchar_t) 0x2200);
	else if (Str::eq(macro, I"cap")) PUT((wchar_t) 0x2229);
	else if (Str::eq(macro, I"emptyset")) PUT((wchar_t) 0x2205);
	else if (Str::eq(macro, I"subseteq")) PUT((wchar_t) 0x2286);
	else if (Str::eq(macro, I"land")) PUT((wchar_t) 0x2227);
	else if (Str::eq(macro, I"lor")) PUT((wchar_t) 0x2228);
	else if (Str::eq(macro, I"lnot")) PUT((wchar_t) 0x00AC);
	else if (Str::eq(macro, I"sum")) PUT((wchar_t) 0x03A3);
	else if (Str::eq(macro, I"prod")) PUT((wchar_t) 0x03A0);
	else {
		if (Str::len(macro) > 0) {
			int suspect = TRUE;
			LOOP_THROUGH_TEXT(pos, macro) {
				wchar_t c = Str::get(pos);
				if ((c >= 'A') && (c <= 'Z')) continue;
				if ((c >= 'a') && (c <= 'z')) continue;
				suspect = FALSE;
			}
			if (Str::eq(macro, I"n")) suspect = FALSE;
			if (Str::eq(macro, I"t")) suspect = FALSE;
			if (suspect)
				PRINT("[Passing through unknown TeX macro \\%S:\n  %S\n", macro, text);
		}
		WRITE("\\%S", macro);
	}

@ For Inform's purposes, we need to deal with just |\not\exists| and |\not\forall|.

@<Remove the not prefix@> =
	if (Str::get_at(text, i) == '\\') {
		Str::clear(macro);
		i++;
		while ((i < Str::len(text)) && (Characters::isalpha(Str::get_at(text, i))))
			PUT_TO(macro, Str::get_at(text, i++));
		if (Str::eq(macro, I"exists")) PUT((wchar_t) 0x2204);
		else if (Str::eq(macro, I"forall")) { PUT((wchar_t) 0x00AC); PUT((wchar_t) 0x2200); }
		else {
			PRINT("Don't know how to apply '\\not' to '\\%S'\n", macro);
		}
	} else {
		PRINT("Don't know how to apply '\\not' here\n");
	}
