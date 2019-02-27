[PlainText::] Plain Text Format.

To provide for weaving in plain text format, which is not very
interesting, but ought to be available.

@h Creation.

=
void PlainText::create(void) {
	weave_format *wf = Formats::create_weave_format(I"plain", I".txt");
	METHOD_ADD(wf, TOP_FOR_MTID, PlainText::top);
	METHOD_ADD(wf, SUBHEADING_FOR_MTID, PlainText::subheading);
	METHOD_ADD(wf, TOC_FOR_MTID, PlainText::toc);
	METHOD_ADD(wf, CHAPTER_TP_FOR_MTID, PlainText::chapter_title_page);
	METHOD_ADD(wf, PARAGRAPH_HEADING_FOR_MTID, PlainText::paragraph_heading);
	METHOD_ADD(wf, SOURCE_CODE_FOR_MTID, PlainText::source_code);
	METHOD_ADD(wf, DISPLAY_LINE_FOR_MTID, PlainText::display_line);
	METHOD_ADD(wf, ITEM_FOR_MTID, PlainText::item);
	METHOD_ADD(wf, BAR_FOR_MTID, PlainText::bar);
	METHOD_ADD(wf, PARA_MACRO_FOR_MTID, PlainText::para_macro);
	METHOD_ADD(wf, BLANK_LINE_FOR_MTID, PlainText::blank_line);
	METHOD_ADD(wf, ENDNOTE_FOR_MTID, PlainText::endnote);
	METHOD_ADD(wf, COMMENTARY_TEXT_FOR_MTID, PlainText::commentary_text);
	METHOD_ADD(wf, LOCALE_FOR_MTID, PlainText::locale);
	METHOD_ADD(wf, TAIL_FOR_MTID, PlainText::tail);
}

@h Methods.
For documentation, see "Weave Fornats".

=
void PlainText::top(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *comment) {
	WRITE("[%S]\n", comment);
}

@ =
void PlainText::subheading(weave_format *self, text_stream *OUT, weave_target *wv,
	int level, text_stream *comment, text_stream *head) {
	WRITE("%S:\n", comment);
	if ((level == 2) && (head)) { Formats::text(OUT, wv, head); WRITE("\n\n"); }
}

@ =
void PlainText::toc(weave_format *self, text_stream *OUT, weave_target *wv, int stage,
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
	weave_target *wv, chapter *C) {
	WRITE("%S\n\n", C->rubric);
	section *S;
	LOOP_OVER_LINKED_LIST(S, section, C->sections)
		WRITE("    %S: %S\n        %S\n",
			S->range, S->sect_title, S->sect_purpose);
}

@ =
void PlainText::paragraph_heading(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *TeX_macro, section *S, paragraph *P, text_stream *heading_text,
	text_stream *chaptermark, text_stream *sectionmark, int weight) {
	if (P) {
		WRITE("\n");
		Formats::locale(OUT, wv, P, NULL);
		WRITE(". %S    ", heading_text);
	} else {
		WRITE("%S\n\n", heading_text);
	}
}

@ =
void PlainText::source_code(weave_format *self, text_stream *OUT, weave_target *wv,
	int tab_stops_of_indentation, text_stream *prefatory, text_stream *matter,
	text_stream *colouring, text_stream *concluding_comment, int starts,
	int finishes, int code_mode) {
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
void PlainText::display_line(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *from) {
	WRITE("    %S\n", from);
}

@ =
void PlainText::item(weave_format *self, text_stream *OUT, weave_target *wv,
	int depth, text_stream *label) {
	if (depth == 1) WRITE("%-4s  ", label);
	else WRITE("%-8s  ", label);
}

@ =
void PlainText::bar(weave_format *self, text_stream *OUT, weave_target *wv) {
	WRITE("\n----------------------------------------------------------------------\n\n");
}

@ =
void PlainText::para_macro(weave_format *self, text_stream *OUT, weave_target *wv,
	para_macro *pmac, int defn) {
	WRITE("<%S (%S)>%s",
		pmac->macro_name, pmac->defining_paragraph->paragraph_number,
		(defn)?" =":"");
}

@ =
void PlainText::blank_line(weave_format *self, text_stream *OUT, weave_target *wv,
	int in_comment) {
	WRITE("\n");
}

@ =
void PlainText::endnote(weave_format *self, text_stream *OUT, weave_target *wv,
	int end) {
	WRITE("\n");
}

@ =
void PlainText::commentary_text(weave_format *self, text_stream *OUT,
	weave_target *wv, text_stream *id) {
	WRITE("%S", id);
}

@ =
void PlainText::locale(weave_format *self, text_stream *OUT, weave_target *wv,
	paragraph *par1, paragraph *par2) {
	WRITE("%S%S", par1->ornament, par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
}

@ =
void PlainText::tail(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *comment, section *S) {
	WRITE("[%S]\n", comment);
}
