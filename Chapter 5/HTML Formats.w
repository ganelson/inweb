[HTMLFormat::] HTML Formats.

To provide for weaving into HTML and into EPUB books.

@ =
void HTMLFormat::create(void) {
	@<Create HTML@>;
	@<Create EPUB@>;
}

@<Create HTML@> =
	weave_format *wf = Formats::create_weave_format(I"HTML", I".html");
	METHOD_ADD(wf, TOP_FOR_MTID, HTMLFormat::top);
	@<Make this format basically HTML@>;

@<Create EPUB@> =
	weave_format *wf = Formats::create_weave_format(I"ePub", I".html");
	METHOD_ADD(wf, TOP_FOR_MTID, HTMLFormat::top_EPUB);
	@<Make this format basically HTML@>;
	METHOD_ADD(wf, BEGIN_WEAVING_FOR_MTID, HTMLFormat::begin_weaving_EPUB);
	METHOD_ADD(wf, END_WEAVING_FOR_MTID, HTMLFormat::end_weaving_EPUB);

@<Make this format basically HTML@> =
	METHOD_ADD(wf, SUBHEADING_FOR_MTID, HTMLFormat::subheading);
	METHOD_ADD(wf, TOC_FOR_MTID, HTMLFormat::toc);
	METHOD_ADD(wf, PARAGRAPH_HEADING_FOR_MTID, HTMLFormat::paragraph_heading);
	METHOD_ADD(wf, SOURCE_CODE_FOR_MTID, HTMLFormat::source_code);
	METHOD_ADD(wf, INLINE_CODE_FOR_MTID, HTMLFormat::inline_code);
	METHOD_ADD(wf, URL_FOR_MTID, HTMLFormat::url);
	METHOD_ADD(wf, DISPLAY_LINE_FOR_MTID, HTMLFormat::display_line);
	METHOD_ADD(wf, ITEM_FOR_MTID, HTMLFormat::item);
	METHOD_ADD(wf, BAR_FOR_MTID, HTMLFormat::bar);
	METHOD_ADD(wf, FIGURE_FOR_MTID, HTMLFormat::figure);
	METHOD_ADD(wf, PARA_MACRO_FOR_MTID, HTMLFormat::para_macro);
	METHOD_ADD(wf, PAGEBREAK_FOR_MTID, HTMLFormat::pagebreak);
	METHOD_ADD(wf, BLANK_LINE_FOR_MTID, HTMLFormat::blank_line);
	METHOD_ADD(wf, CHANGE_MATERIAL_FOR_MTID, HTMLFormat::change_material);
	METHOD_ADD(wf, CHANGE_COLOUR_FOR_MTID, HTMLFormat::change_colour);
	METHOD_ADD(wf, ENDNOTE_FOR_MTID, HTMLFormat::endnote);
	METHOD_ADD(wf, COMMENTARY_TEXT_FOR_MTID, HTMLFormat::commentary_text);
	METHOD_ADD(wf, LOCALE_FOR_MTID, HTMLFormat::locale);
	METHOD_ADD(wf, TAIL_FOR_MTID, HTMLFormat::tail);

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

@ "Breadcrumbs" are the chain of links in a horizontal list at the top of
the page, and this drops one.

=
void HTMLFormat::breadcrumb(OUTPUT_STREAM, text_stream *text, text_stream *link) {
	if (link) {
		HTML_OPEN("li");
		HTML::begin_link(OUT, link);
		WRITE("%S", text);
		HTML::end_link(OUT);
		HTML_CLOSE("li");
	} else {
		HTML_OPEN("li");
		HTML_OPEN("b");
		WRITE("%S", text);
		HTML_CLOSE("b");
		HTML_CLOSE("li");
	}
}

@h Methods.
For documentation, see "Weave Fornats".

=
void HTMLFormat::top(weave_format *self, text_stream *OUT, weave_target *wv, text_stream *comment) {
	HTML::declare_as_HTML(OUT, FALSE);
	Indexer::cover_sheet_maker(OUT, wv->weave_web, I"template", wv, WEAVE_FIRST_HALF);
	if (wv->self_contained == FALSE) {
		filename *CSS = Patterns::obtain_filename(wv->pattern, I"inweb.css");
		if (wv->pattern->hierarchical)
			Patterns::copy_up_file_into_weave(wv->weave_web, CSS);
		else
			Patterns::copy_file_into_weave(wv->weave_web, CSS);
	}
	HTML::comment(OUT, comment);
	html_in_para = HTML_OUT;
}

void HTMLFormat::top_EPUB(weave_format *self, text_stream *OUT, weave_target *wv, text_stream *comment) {
	HTML::declare_as_HTML(OUT, TRUE);
	Epub::note_page(wv->weave_web->as_ebook, wv->weave_to, wv->booklet_title, I"");
	Indexer::cover_sheet_maker(OUT, wv->weave_web, I"template", wv, WEAVE_FIRST_HALF);
	HTML::comment(OUT, comment);
	html_in_para = HTML_OUT;
}

@ =
void HTMLFormat::subheading(weave_format *self, text_stream *OUT, weave_target *wv,
	int level, text_stream *comment, text_stream *head) {
	HTMLFormat::exit_current_paragraph(OUT);
	switch (level) {
		case 1: HTML::heading(OUT, "h3", comment); break;
		case 2: HTMLFormat::p(OUT, "purpose");
			WRITE("%S", comment);
			if (head) {
				WRITE(": ");
				Formats::text(OUT, wv, head);
			}
			HTMLFormat::cp(OUT);
			break;
	}
}

@ =
void HTMLFormat::toc(weave_format *self, text_stream *OUT, weave_target *wv,
	int stage, text_stream *text1, text_stream *text2, paragraph *P) {
	HTMLFormat::exit_current_paragraph(OUT);
	switch (stage) {
		case 1:
			HTML_OPEN_WITH("ul", "class=\"toc\"");
			HTML_OPEN("li");
			break;
		case 2:
			HTML_CLOSE("li");
			HTML_OPEN("li");
			break;
		case 3: {
			TEMPORARY_TEXT(TEMP)
			HTMLFormat::xref(TEMP, wv, P, NULL, TRUE);
			HTML::begin_link(OUT, TEMP);
			DISCARD_TEXT(TEMP)
			WRITE("%s%S", (Str::get_first_char(P->ornament) == 'S')?"&#167;":"&para;",
				P->paragraph_number);
			WRITE(". %S", text2);
			HTML::end_link(OUT);
			break;
		}
		case 4:
			HTML_CLOSE("li");
			HTML_CLOSE("ul");
			HTML::hr(OUT, "tocbar");
			WRITE("\n"); break;
	}
}

@ =
section *page_section = NULL;
int crumbs_dropped = FALSE;

void HTMLFormat::paragraph_heading(weave_format *self, text_stream *OUT,
	weave_target *wv, text_stream *TeX_macro, section *S, paragraph *P,
	text_stream *heading_text, text_stream *chaptermark, text_stream *sectionmark,
	int weight) {
	page_section = S;
	if (weight == 3) return; /* Skip chapter headings */
	HTMLFormat::exit_current_paragraph(OUT);
	if (P) {
		HTMLFormat::p(OUT, "inwebparagraph");
		TEMPORARY_TEXT(TEMP)
		HTMLFormat::xref(TEMP, wv, P, NULL, FALSE);
		HTML::anchor(OUT, TEMP);
		DISCARD_TEXT(TEMP)
		HTML_OPEN("b");
		WRITE("%s%S", (Str::get_first_char(P->ornament) == 'S')?"&#167;":"&para;",
			P->paragraph_number);
		WRITE(". %S%s ", heading_text, (Str::len(heading_text) > 0)?".":"");
		HTML_CLOSE("b");
	} else {
		if (wv->self_contained == FALSE) {
			if (crumbs_dropped == FALSE) {
				filename *C = Patterns::obtain_filename(wv->pattern, I"crumbs.gif");
				if (wv->pattern->hierarchical)
					Patterns::copy_up_file_into_weave(wv->weave_web, C);
				else
					Patterns::copy_file_into_weave(wv->weave_web, C);
				crumbs_dropped = TRUE;
			}
			HTML_OPEN_WITH("ul", "class=\"crumbs\"");
			HTMLFormat::drop_initial_breadcrumbs(OUT, wv->breadcrumbs, wv->docs_mode);
			text_stream *bct = Bibliographic::get_datum(wv->weave_web->md, I"Title");
			if (Str::len(Bibliographic::get_datum(wv->weave_web->md, I"Short Title")) > 0) {
				bct = Bibliographic::get_datum(wv->weave_web->md, I"Short Title");
			}
			HTMLFormat::breadcrumb(OUT, bct, I"index.html");

			if (wv->weave_web->md->chaptered) {
				TEMPORARY_TEXT(chapter_link);
				WRITE_TO(chapter_link, "index.html#%s%S", (wv->weave_web->as_ebook)?"C":"",
					S->owning_chapter->md->ch_range);
				HTMLFormat::breadcrumb(OUT, S->owning_chapter->md->ch_title, chapter_link);
				DISCARD_TEXT(chapter_link);
			}

			HTMLFormat::breadcrumb(OUT, heading_text, NULL);
			HTML_CLOSE("ul");
		} else {
			HTML_OPEN_WITH("ul", "class=\"crumbs\"");
			HTMLFormat::breadcrumb(OUT, heading_text, NULL);
			HTML_CLOSE("ul");
		}
	}
}

void HTMLFormat::drop_initial_breadcrumbs(OUTPUT_STREAM, linked_list *crumbs, int docs_mode) {
	if (LinkedLists::len(crumbs) > 0) {
		breadcrumb_request *BR;
		LOOP_OVER_LINKED_LIST(BR, breadcrumb_request, crumbs) {
			HTMLFormat::breadcrumb(OUT, BR->breadcrumb_text, BR->breadcrumb_link);
		}
	} else if (docs_mode)
		HTMLFormat::breadcrumb(OUT, I"&#9733;", I"../webs.html");
}

@ =
void HTMLFormat::source_code(weave_format *self, text_stream *OUT, weave_target *wv,
	int tab_stops_of_indentation, text_stream *prefatory, text_stream *matter,
	text_stream *colouring, text_stream *concluding_comment,
	int starts, int finishes, int code_mode, int linked) {
	if (starts) {
		if (Str::len(prefatory) > 0) {
			HTML_OPEN_WITH("span", "class=\"definitionkeyword\"");
			WRITE("%S", prefatory);
			HTML_CLOSE("span");
			WRITE(" ");
			if (Str::eq(prefatory, I"enum")) {
				match_results mr = Regexp::create_mr();
				if (Regexp::match(&mr, matter, L"(%c*) from (%C+) *")) {
					HTMLFormat::source_code(self, OUT, wv, 0, NULL, mr.exp[0], colouring,
						concluding_comment, starts, FALSE, code_mode, linked);
					HTML_OPEN_WITH("span", "class=\"definitionkeyword\"");
					WRITE(" from ");
					HTML_CLOSE("span");
					HTMLFormat::source_code(self, OUT, wv, 0, NULL, mr.exp[1], colouring,
						concluding_comment, FALSE, finishes, code_mode, linked);
					Regexp::dispose_of(&mr);
					return;
				}
				Regexp::dispose_of(&mr);
			}
		} else
			for (int i=0; i<tab_stops_of_indentation; i++)
				WRITE("    ");
	}
	int current_colour = -1, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(matter); i++) {
		colour_wanted = Str::get_at(colouring, i); @<Adjust code colour as necessary@>;
		if ((linked) &&
			((ACMESupport::text_at(matter, i, I"http://")) ||
				(ACMESupport::text_at(matter, i, I"https://")))) {
				TEMPORARY_TEXT(before);
				Str::copy(before, matter); Str::truncate(before, i);
				TEMPORARY_TEXT(after);
				Str::substr(after, Str::at(matter, i), Str::end(matter));
				match_results mr = Regexp::create_mr();
				if (Regexp::match(&mr, after, L"(https*://%C+)(%c*)")) {
					Formats::url(OUT, wv, mr.exp[0], mr.exp[0], TRUE);
					i += Str::len(mr.exp[0]);
				}
				DISCARD_TEXT(before);
				DISCARD_TEXT(after);
			}
		if (Str::get_at(matter, i) == '<') WRITE("&lt;");
		else if (Str::get_at(matter, i) == '>') WRITE("&gt;");
		else if (Str::get_at(matter, i) == '&') WRITE("&amp;");
		else WRITE("%c", Str::get_at(matter, i));
	}
	if (current_colour >= 0) HTML_CLOSE("span");
	current_colour = -1;
	if (finishes) {
		if (Str::len(concluding_comment) > 0) {
			if (!starts) WRITE("    ");
			HTML_OPEN_WITH("span", "class=\"comment\"");
			Formats::text_comment(OUT, wv, concluding_comment);
			HTML_CLOSE("span");
		}
		WRITE("\n");
	}
}

@<Adjust code colour as necessary@> =
	if (colour_wanted != current_colour) {
		if (current_colour >= 0) HTML_CLOSE("span");
		Formats::change_colour(OUT, wv, colour_wanted, TRUE);
		current_colour = colour_wanted;
	}

@ =
void HTMLFormat::inline_code(weave_format *self, text_stream *OUT, weave_target *wv,
	int enter) {
	if (enter) {
		if (html_in_para == HTML_OUT) HTMLFormat::p(OUT, "inwebparagraph");
		HTML_OPEN_WITH("code", "class=\"display\"");
	} else {
		HTML_CLOSE("code");
	}
}

@ =
void HTMLFormat::url(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *url, text_stream *content, int external) {
	HTML::begin_link_with_class(OUT, (external)?I"external":I"internal", url);
	WRITE("%S", content);
	HTML::end_link(OUT);
}

@ =
void HTMLFormat::display_line(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *from) {
	HTMLFormat::exit_current_paragraph(OUT);
	HTML_OPEN("blockquote"); WRITE("\n"); INDENT;
	HTMLFormat::p(OUT, NULL);
	WRITE("%S", from);
	HTMLFormat::cp(OUT);
	OUTDENT; HTML_CLOSE("blockquote"); WRITE("\n");
}

@ =
void HTMLFormat::item(weave_format *self, text_stream *OUT, weave_target *wv, int depth,
	text_stream *label) {
	HTMLFormat::go_to_depth(OUT, depth);
	if (Str::len(label) > 0) WRITE("(%S) ", label);
	else WRITE(" ");

}

@ =
void HTMLFormat::bar(weave_format *self, text_stream *OUT, weave_target *wv) {
	HTMLFormat::exit_current_paragraph(OUT);
	HTML::hr(OUT, NULL);
}

@ =
void HTMLFormat::figure(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *figname, int w, int h, programming_language *pl) {
	HTMLFormat::exit_current_paragraph(OUT);
	filename *F = Filenames::in_folder(
		Pathnames::subfolder(wv->weave_web->md->path_to_web, I"Figures"),
		figname);
	filename *RF = Filenames::from_text(figname);
	HTML_OPEN("center");
	HTML::image(OUT, RF);
	Patterns::copy_file_into_weave(wv->weave_web, F);
	HTML_CLOSE("center");
	WRITE("\n");
}

@ =
void HTMLFormat::para_macro(weave_format *self, text_stream *OUT, weave_target *wv,
	para_macro *pmac, int defn) {
	paragraph *P = pmac->defining_paragraph;
	WRITE("&lt;");
	HTML_OPEN_WITH("span", "class=\"%s\"", (defn)?"cwebmacrodefn":"cwebmacro");
	WRITE("%S", pmac->macro_name);
	HTML_CLOSE("span");
	WRITE(" ");
	HTML_OPEN_WITH("span", "class=\"cwebmacronumber\"");
	WRITE("%S", P->paragraph_number);
	HTML_CLOSE("span");
	WRITE("&gt;%s", (defn)?" =":"");
}

@ =
void HTMLFormat::pagebreak(weave_format *self, text_stream *OUT, weave_target *wv) {
	HTMLFormat::exit_current_paragraph(OUT);
}

@ =
void HTMLFormat::blank_line(weave_format *self, text_stream *OUT, weave_target *wv,
	int in_comment) {
	if (html_in_para == HTML_IN_PRE) {
		WRITE("\n");
	} else {
		int old_state = html_in_para, old_depth = item_depth;
		HTMLFormat::exit_current_paragraph(OUT);
		if ((old_state == HTML_IN_P) || ((old_state == HTML_IN_LI) && (old_depth > 1)))
			HTMLFormat::p(OUT,"inwebparagraph");
	}
}

@ =
void HTMLFormat::change_material(weave_format *self, text_stream *OUT, weave_target *wv,
	int old_material, int new_material, int content, int plainly) {
	if (old_material != new_material) {
		if (old_material == MACRO_MATERIAL) HTML_CLOSE("code");
		if ((content) || (new_material != MACRO_MATERIAL))
			HTMLFormat::exit_current_paragraph(OUT);
		switch (old_material) {
			case CODE_MATERIAL:
			case REGULAR_MATERIAL:
				switch (new_material) {
					case CODE_MATERIAL:
						if (plainly) HTMLFormat::pre(OUT, "undisplay");
						else HTMLFormat::pre(OUT, "display");
						break;
					case DEFINITION_MATERIAL:
						WRITE("\n");
						HTMLFormat::pre(OUT, "definitions");
						break;
					case MACRO_MATERIAL:
						if (content) {
							WRITE("\n");
							HTMLFormat::p(OUT,"macrodefinition");
						}
						HTML_OPEN_WITH("code", "class=\"display\"");
						WRITE("\n");
						break;
					case REGULAR_MATERIAL:
						if (content) {
							WRITE("\n");
							HTMLFormat::p(OUT,"inwebparagraph");
						}
						break;
				}
				break;
			case MACRO_MATERIAL:
				switch (new_material) {
					case CODE_MATERIAL:
						WRITE("\n");
						HTMLFormat::pre(OUT, "displaydefn");
						break;
					case DEFINITION_MATERIAL:
						WRITE("\n");
						HTMLFormat::pre(OUT, "definitions");
						break;
				}
				break;
			case DEFINITION_MATERIAL:
				switch (new_material) {
					case CODE_MATERIAL:
						WRITE("\n");
						if (plainly) HTMLFormat::pre(OUT, "undisplay");
						else HTMLFormat::pre(OUT, "display");
						break;
					case MACRO_MATERIAL:
						WRITE("\n");
						HTMLFormat::p(OUT, "macrodefinition");
						HTML_OPEN_WITH("code", "class=\"display\"");
						WRITE("\n");
						break;
				}
				break;
			default:
				HTMLFormat::cpre(OUT);
				break;
		}
	}
}

@ =
void HTMLFormat::change_colour(weave_format *self, text_stream *OUT, weave_target *wv,
	int col, int in_code) {
	char *cl = "plain";
	switch (col) {
		case DEFINITION_COLOUR: 			cl = "cwebmacrotext"; break;
		case FUNCTION_COLOUR: 		cl = "functiontext"; break;
		case IDENTIFIER_COLOUR: 	cl = "identifier"; break;
		case ELEMENT_COLOUR:		cl = "element"; break;
		case RESERVED_COLOUR: 		cl = "reserved"; break;
		case STRING_COLOUR: 		cl = "string"; break;
		case CHAR_LITERAL_COLOUR:	cl = "character"; break;
		case CONSTANT_COLOUR: 		cl = "constant"; break;
		case PLAIN_COLOUR: 			cl = "plain"; break;
		case EXTRACT_COLOUR: 		cl = "extract"; break;
		case COMMENT_COLOUR: 		cl = "comment"; break;
		default: PRINT("col: %d\n", col); internal_error("bad colour"); break;
	}
	HTML_OPEN_WITH("span", "class=\"%s\"", cl);
}

@ =
void HTMLFormat::endnote(weave_format *self, text_stream *OUT, weave_target *wv, int end) {
	if (end == 1) {
		HTMLFormat::exit_current_paragraph(OUT);
		HTMLFormat::p(OUT, "endnote");
	} else {
		HTMLFormat::cp(OUT);
	}
}

@ =
void HTMLFormat::commentary_text(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
		if (html_in_para == HTML_OUT) HTMLFormat::p(OUT, "inwebparagraph");
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

@ =
void HTMLFormat::locale(weave_format *self, text_stream *OUT, weave_target *wv,
	paragraph *par1, paragraph *par2) {
	TEMPORARY_TEXT(TEMP)
	HTMLFormat::xref(TEMP, wv, par1, page_section, TRUE);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	WRITE("%s%S",
		(Str::get_first_char(par1->ornament) == 'S')?"&#167;":"&para;",
		par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
	HTML::end_link(OUT);
}

@ =
void HTMLFormat::xref(OUTPUT_STREAM, weave_target *wv, paragraph *P, section *from,
	int a_link) {
	TEMPORARY_TEXT(linkto);
	if ((from) && (P->under_section != from)) {
		Str::copy(linkto, P->under_section->sect_range);
		LOOP_THROUGH_TEXT(pos, linkto)
			if ((Str::get(pos) == '/') || (Str::get(pos) == ' '))
				Str::put(pos, '-');
		WRITE_TO(linkto, ".html");
	}
	WRITE("%S%s%S", linkto, (a_link)?"#":"", P->ornament);
	DISCARD_TEXT(linkto);

	WRITE("P");
	text_stream *N = P->paragraph_number;
	LOOP_THROUGH_TEXT(pos, N)
		if (Str::get(pos) == '.') WRITE("_");
		else PUT(Str::get(pos));
}

@ =
void HTMLFormat::tail(weave_format *self, text_stream *OUT, weave_target *wv,
	text_stream *comment, section *this_S) {
	HTMLFormat::exit_current_paragraph(OUT);
	if (wv->docs_mode) {
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
				HTMLFormat::sref(TEMP, wv, prev_S);
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
				HTMLFormat::sref(TEMP, wv, next_S);
				HTML::begin_link(OUT, TEMP);
				WRITE("Continue with '%S'", next_S->md->sect_title);
				HTML::end_link(OUT);
				DISCARD_TEXT(TEMP);
			}
			HTML_CLOSE("li");
			HTML_CLOSE("ul");
		}
		HTML::hr(OUT, "tocbar");
	}
	HTML::comment(OUT, comment);
	HTML::completed(OUT);
	Bibliographic::set_datum(wv->weave_web->md, I"Booklet Title", wv->booklet_title);
	Indexer::cover_sheet_maker(OUT, wv->weave_web, I"template", wv, WEAVE_SECOND_HALF);
}

@ =
void HTMLFormat::sref(OUTPUT_STREAM, weave_target *wv, section *S) {
	if (S == NULL) internal_error("unwoven section");
	LOOP_THROUGH_TEXT(pos, S->sect_range)
		if (Str::get(pos) == '/')
			PUT('-');
		else
			PUT(Str::get(pos));
	WRITE(".html");
}

@h EPUB-only methods.

=
int HTMLFormat::begin_weaving_EPUB(weave_format *wf, web *W, weave_pattern *pattern) {
	TEMPORARY_TEXT(T)
	WRITE_TO(T, "%S", Bibliographic::get_datum(W->md, I"Title"));
	W->as_ebook = Epub::new(T, "P");
	filename *CSS = Patterns::obtain_filename(pattern, I"inweb.css");
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
