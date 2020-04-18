[Formats::] Format Methods.

To characterise the relevant differences in behaviour between the
various weaving formats offered, such as HTML, ePub, or TeX.

@h Formats.
Exactly as in the previous chapter, each format expresses its behaviour
through optional method calls.

=
typedef struct weave_format {
	struct text_stream *format_name;
	struct text_stream *woven_extension;
	METHOD_CALLS
	MEMORY_MANAGEMENT
} weave_format;

weave_format *Formats::create_weave_format(text_stream *name, text_stream *ext) {
	weave_format *wf = CREATE(weave_format);
	wf->format_name = Str::duplicate(name);
	wf->woven_extension = Str::duplicate(ext);
	ENABLE_METHOD_CALLS(wf);
	return wf;
}

weave_format *Formats::find_by_name(text_stream *name) {
	weave_format *wf;
	LOOP_OVER(wf, weave_format)
		if (Str::eq_insensitive(name, wf->format_name))
			return wf;
	return NULL;
}

@ Note that this is the file extension before any post-processing. For
example, PDFs are made by weaving a TeX file and then running this through
|pdftex|. The extension here will be |.tex| because that's what the weave
stage produces, even though we will later end up with a |.pdf|.

=
text_stream *Formats::file_extension(weave_format *wf) {
	return wf->woven_extension;
}

@h Creation.
This must be performed very early in Inweb's run.

=
void Formats::create_weave_formats(void) {
	Debugging::create();
	TeX::create();
	PlainText::create();
	HTMLFormat::create();
}

@h Methods.
These two don't allow output to be produced: they're for any setting up and
putting away that needs tp be done.

|BEGIN_WEAVING_FOR_MTID| is called before any output is generated, indeed,
before even the filename(s) for the output are worked out. Note that it
can return a |*_SWM| code to change the swarm behaviour of the weave to come;
this is helpful for EPUB weaving.

More simply, |END_WEAVING_FOR_MTID| is called when all weaving is done.

@e BEGIN_WEAVING_FOR_MTID
@e END_WEAVING_FOR_MTID

=
IMETHOD_TYPE(BEGIN_WEAVING_FOR_MTID, weave_format *wf, web *W, weave_pattern *pattern)
VMETHOD_TYPE(END_WEAVING_FOR_MTID, weave_format *wf, web *W, weave_pattern *pattern)
int Formats::begin_weaving(web *W, weave_pattern *pattern) {
	int rv = FALSE;
	IMETHOD_CALL(rv, pattern->pattern_format, BEGIN_WEAVING_FOR_MTID, W, pattern);
	if (rv) return rv;
	return SWARM_OFF_SWM;
}
void Formats::end_weaving(web *W, weave_pattern *pattern) {
	VMETHOD_CALL(pattern->pattern_format, END_WEAVING_FOR_MTID, W, pattern);
}

@ Now the weave output, roughly in order from top to bottom.

|RENDER_FOR_MTID| renders the weave tree in the given format: a format must
provide this.

@e RENDER_FOR_MTID

=
VMETHOD_TYPE(RENDER_FOR_MTID, weave_format *wf, text_stream *OUT, heterogeneous_tree *tree)
void Formats::render(text_stream *OUT, heterogeneous_tree *tree) {
	tree_node *doc_node = tree->root;
	weave_document_node *doc = RETRIEVE_POINTER_weave_document_node(doc_node->content);
	weave_format *wf = doc->wv->format;
	VMETHOD_CALL(wf, RENDER_FOR_MTID, OUT, tree);
}

@ When whole chapters are wovem, or all-in-one weaves include multiple
chapters, the format can add a table of chapter contents, or some similar
interstitial material. This is how:

@e CHAPTER_TP_FOR_MTID

=
VMETHOD_TYPE(CHAPTER_TP_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv, chapter *C)
void Formats::chapter_title_page(OUTPUT_STREAM, weave_order *wv, chapter *C) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, CHAPTER_TP_FOR_MTID, OUT, wv, C);
}

@ The following method is expected to weave a piece of code, which has already
been syntax-coloured; there can also be some indentation, and perhaps even some
|prefatory| text before the line of code, and also potentially a
|concluding_comment| at the end of the line.

@e SOURCE_CODE_FOR_MTID

=
VMETHOD_TYPE(SOURCE_CODE_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	int tab_stops_of_indentation, text_stream *prefatory, text_stream *matter,
	text_stream *colouring, text_stream *concluding_comment, int starts, int finishes,
	int code_mode, int linked)

void Formats::source_code(OUTPUT_STREAM, weave_order *wv, int tab_stops_of_indentation,
	text_stream *prefatory, text_stream *matter, text_stream *colouring,
	text_stream *concluding_comment, int starts, int finishes, int code_mode, int linked) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, SOURCE_CODE_FOR_MTID, OUT, wv, tab_stops_of_indentation,
		prefatory, matter, colouring, concluding_comment, starts, finishes, code_mode, linked);
}

@ More primitively, this method weaves a piece of code which has been coloured
drably in a uniform |EXTRACT_COLOUR| colour. This is used for weaving words like
|these_ones| of code given inside commentary.

@e INLINE_CODE_FOR_MTID

=
VMETHOD_TYPE(INLINE_CODE_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv, int pre)
void Formats::source_fragment(OUTPUT_STREAM, weave_order *wv, text_stream *fragment) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, INLINE_CODE_FOR_MTID, OUT, wv, TRUE);
	TEMPORARY_TEXT(colouring);
	for (int i=0; i< Str::len(fragment); i++) PUT_TO(colouring, EXTRACT_COLOUR);
	Formats::source_code(OUT, wv, 0, I"", fragment, colouring, I"", FALSE, FALSE, TRUE, FALSE);
	DISCARD_TEXT(colouring);
	VMETHOD_CALL(wf, INLINE_CODE_FOR_MTID, OUT, wv, FALSE);
}

@ And this weaves a URL, hyperlinking it where possible.

@e URL_FOR_MTID

=
VMETHOD_TYPE(URL_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	text_stream *url, text_stream *content, int external)
void Formats::url(OUTPUT_STREAM, weave_order *wv, text_stream *url,
	text_stream *content, int external) {
	weave_format *wf = wv->format;
	if (Methods::provided(wf->methods, URL_FOR_MTID)) {
		VMETHOD_CALL(wf, URL_FOR_MTID, OUT, wv, url, content, external);
	} else {
		WRITE("%S", content);
	}
}

@ And this weaves a footnote cue.

@e FOOTNOTE_CUE_FOR_MTID

=
VMETHOD_TYPE(FOOTNOTE_CUE_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	text_stream *cue)
void Formats::footnote_cue(OUTPUT_STREAM, weave_order *wv, text_stream *cue) {
	weave_format *wf = wv->format;
	if (Methods::provided(wf->methods, FOOTNOTE_CUE_FOR_MTID)) {
		VMETHOD_CALL(wf, FOOTNOTE_CUE_FOR_MTID, OUT, wv, cue);
	} else {
		WRITE("[%S]", cue);
	}
}

@ And this weaves a footnote text opening...

@e BEGIN_FOOTNOTE_TEXT_FOR_MTID

=
VMETHOD_TYPE(BEGIN_FOOTNOTE_TEXT_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	text_stream *cue)
void Formats::begin_footnote_text(OUTPUT_STREAM, weave_order *wv, text_stream *cue) {
	weave_format *wf = wv->format;
	if (Methods::provided(wf->methods, BEGIN_FOOTNOTE_TEXT_FOR_MTID)) {
		VMETHOD_CALL(wf, BEGIN_FOOTNOTE_TEXT_FOR_MTID, OUT, wv, cue);
	} else {
		WRITE("[%S]. ", cue);
	}
}

@ ...bookended by a footnote text closing. The weaver ensures that these occur
in pairs and do not nest.

@e END_FOOTNOTE_TEXT_FOR_MTID

=
VMETHOD_TYPE(END_FOOTNOTE_TEXT_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	text_stream *cue)
void Formats::end_footnote_text(OUTPUT_STREAM, weave_order *wv, text_stream *cue) {
	weave_format *wf = wv->format;
	if (Methods::provided(wf->methods, END_FOOTNOTE_TEXT_FOR_MTID)) {
		VMETHOD_CALL(wf, END_FOOTNOTE_TEXT_FOR_MTID, OUT, wv, cue);
	} else {
		WRITE("\n");
	}
}

@ This method weaves an angle-bracketed paragraph macro name. |defn| is set
if and only if this is the place where the macro is defined -- the usual
thing is to render some sort of equals sign after it, if so.

@e PARA_MACRO_FOR_MTID

=
VMETHOD_TYPE(PARA_MACRO_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	para_macro *pmac, int defn)
void Formats::para_macro(OUTPUT_STREAM, weave_order *wv, para_macro *pmac, int defn) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, PARA_MACRO_FOR_MTID, OUT, wv, pmac, defn);
}

@ Another opportunity for vertical tidying-up. At the beginning of a code
line which occurs after a run of |@d| or |@e| definitions, this method is
called. It can then insert a little vertical gap to separate the code from
the definitions.

@e AFTER_DEFINITIONS_FOR_MTID

=
VMETHOD_TYPE(AFTER_DEFINITIONS_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv)
void Formats::after_definitions(OUTPUT_STREAM, weave_order *wv) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, AFTER_DEFINITIONS_FOR_MTID, OUT, wv);
}

@ This is called on a change of colour. "Colour" is really a shorthand way
of saying something more like "style", but seemed less ambiguous. In HTML,
this might trigger a change of CSS span style; in plain text, it would do
nothing.

@e CHANGE_COLOUR_FOR_MTID

=
VMETHOD_TYPE(CHANGE_COLOUR_FOR_MTID, weave_format *wf, text_stream *OUT,
	weave_order *wv, int col, int in_code)
void Formats::change_colour(OUTPUT_STREAM, weave_order *wv, int col, int in_code) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, CHANGE_COLOUR_FOR_MTID, OUT, wv, col, in_code);
}

@ The following takes text, divides it up at stroke-mark boundaries --
that is, |this is inside|, this is outside -- and sends contiguous pieces
of it either to |Formats::source_fragment| or |Formats::text_fragment|
as appropriate.

=
void Formats::text(OUTPUT_STREAM, weave_order *wv, text_stream *id) {
	Formats::text_r(OUT, wv, id, FALSE, FALSE);
}
void Formats::text_comment(OUTPUT_STREAM, weave_order *wv, text_stream *id) {
	Formats::text_r(OUT, wv, id, FALSE, TRUE);
}

void Formats::text_r(OUTPUT_STREAM, weave_order *wv, text_stream *id,
	int within, int comments) {
	text_stream *code_in_comments_notation =
		Bibliographic::get_datum(wv->weave_web->md,
		(comments)?(I"Code In Code Comments Notation"):(I"Code In Commentary Notation"));
	if (Str::ne(code_in_comments_notation, I"Off")) @<Split text and code extracts@>;

	if (within == FALSE) @<Recognose hyperlinks@>;

	text_stream *xref_notation = Bibliographic::get_datum(wv->weave_web->md,
		I"Cross-References Notation");
	if (Str::ne(xref_notation, I"Off")) @<Recognise cross-references@>;

	if (within) {
		Formats::source_fragment(OUT, wv, id);
	} else {
		@<Detect use of footnotes@>;
		Formats::text_fragment(OUT, wv, id);
	}
}

@<Split text and code extracts@> =
	for (int i=0; i < Str::len(id); i++) {
		if (Str::get_at(id, i) == '\\') i += Str::len(code_in_comments_notation) - 1;
		else if (Str::includes_at(id, i, code_in_comments_notation)) {
			TEMPORARY_TEXT(before);
			Str::copy(before, id); Str::truncate(before, i);
			TEMPORARY_TEXT(after);
			Str::substr(after, Str::at(id,
				i + Str::len(code_in_comments_notation)), Str::end(id));
			Formats::text_r(OUT, wv, before, within, comments);
			Formats::text_r(OUT, wv, after, (within)?FALSE:TRUE, comments);
			DISCARD_TEXT(before);
			DISCARD_TEXT(after);
			return;
		}
	}

@<Recognose hyperlinks@> =
	for (int i=0; i < Str::len(id); i++) {
		if ((Str::includes_at(id, i, I"http://")) ||
				(Str::includes_at(id, i, I"https://"))) {
			TEMPORARY_TEXT(before);
			Str::copy(before, id); Str::truncate(before, i);
			TEMPORARY_TEXT(after);
			Str::substr(after, Str::at(id, i), Str::end(id));
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, after, L"(https*://%C+)(%c*)")) {
				Formats::text_r(OUT, wv, before, within, comments);
				Formats::url(OUT, wv, mr.exp[0], mr.exp[0], TRUE);
				Formats::text_r(OUT, wv, mr.exp[1], within, comments);
				Regexp::dispose_of(&mr);
				return;
			}
			Regexp::dispose_of(&mr);
			DISCARD_TEXT(before);
			DISCARD_TEXT(after);
		}
	}

@<Detect use of footnotes@> =
	TEMPORARY_TEXT(before);
	TEMPORARY_TEXT(cue);
	TEMPORARY_TEXT(after);
	int allow = FALSE;
	if (Parser::detect_footnote(wv->weave_web, id, before, cue, after)) {
		footnote *F = Parser::find_footnote_in_para(
			wv->current_weave_line->owning_paragraph, cue);
		if (F) {
			F->cued_already = TRUE;
			allow = TRUE;
			Formats::text_r(OUT, wv, before, within, comments);
			Formats::footnote_cue(OUT, wv, F->cue_text);
			Formats::text_r(OUT, wv, after, within, comments);
		} else {
			Main::error_in_web(I"this is a cue for a missing note", wv->current_weave_line);
		}
	}
	DISCARD_TEXT(before);
	DISCARD_TEXT(cue);
	DISCARD_TEXT(after);
	if (allow) return;

@<Recognise cross-references@> =
	int N = Str::len(xref_notation);
	for (int i=0; i < Str::len(id); i++) {
		if ((within == FALSE) && (Str::includes_at(id, i, xref_notation))) {
			int j = i + N+1;
			while (j < Str::len(id)) {
				if (Str::includes_at(id, j, xref_notation)) {
					int allow = FALSE;
					TEMPORARY_TEXT(before);
					TEMPORARY_TEXT(reference);
					TEMPORARY_TEXT(after);
					Str::substr(before, Str::start(id), Str::at(id, i));
					Str::substr(reference, Str::at(id, i + N), Str::at(id, j));
					Str::substr(after, Str::at(id, j + N), Str::end(id));
					@<Attempt to resolve the cross-reference@>;
					DISCARD_TEXT(before);
					DISCARD_TEXT(reference);
					DISCARD_TEXT(after);
					if (allow) return;
				}
				j++;
			}
		}
	}

@<Attempt to resolve the cross-reference@> =
	TEMPORARY_TEXT(url);
	TEMPORARY_TEXT(title);
	if (Colonies::resolve_reference_in_weave(url, title, wv->weave_to, reference,
		wv->weave_web->md, wv->current_weave_line)) {
		Formats::text_r(OUT, wv, before, within, comments);
		Formats::url(OUT, wv, url, title, FALSE);
		Formats::text_r(OUT, wv, after, within, comments);
		allow = TRUE;
	}
	DISCARD_TEXT(url);
	DISCARD_TEXT(title);

@ |COMMENTARY_TEXT_FOR_MTID| straightforwardly weaves out a run of contiguous
text. Ordinarily, any formulae written in TeX notation (i.e., in dollar signs
used as brackets) will be transmogrified into a plain text paraphrase, but
the |PRESERVE_MATH_MODE_FOR_MTID| can prevent this. (And of course the TeX
format does, because it wants to keep the formulae in all their glory.)

@e COMMENTARY_TEXT_FOR_MTID
@e PRESERVE_MATH_MODE_FOR_MTID

=
IMETHOD_TYPE(PRESERVE_MATH_MODE_FOR_MTID, weave_format *wf, weave_order *wv,
	text_stream *matter, text_stream *id)
VMETHOD_TYPE(COMMENTARY_TEXT_FOR_MTID, weave_format *wf, text_stream *OUT,
	weave_order *wv, text_stream *matter)

void Formats::text_fragment(OUTPUT_STREAM, weave_order *wv, text_stream *fragment) {
	weave_format *wf = wv->format;
	TEMPORARY_TEXT(matter);
	int rv = TRUE;
	if (Str::eq_wide_string(
		Bibliographic::get_datum(wv->weave_web->md, I"TeX Mathematics Notation"), L"On")) {
		rv = FALSE;
		IMETHOD_CALL(rv, wf, PRESERVE_MATH_MODE_FOR_MTID, wv, matter, fragment);
	}
	if (rv == FALSE) TeX::remove_math_mode(matter, fragment);
	else if (Str::len(matter) == 0) Str::copy(matter, fragment);
	VMETHOD_CALL(wf, COMMENTARY_TEXT_FOR_MTID, OUT, wv, matter);
	DISCARD_TEXT(matter);
}

@ The weaver has special typographical support for the stand-alone Inform
document of Preform grammar, and this is the hook for it. Most formats
should ignore it.

@e PREFORM_DOCUMENT_FOR_MTID

=
IMETHOD_TYPE(PREFORM_DOCUMENT_FOR_MTID, weave_format *wf, text_stream *OUT,
	weave_order *wv, web *W, chapter *C, section *S, source_line *L,
	text_stream *matter, text_stream *concluding_comment)
int Formats::preform_document(OUTPUT_STREAM, weave_order *wv, web *W,
	chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *concluding_comment) {
	weave_format *wf = wv->format;
	int rv = FALSE;
	IMETHOD_CALL(rv, wf, PREFORM_DOCUMENT_FOR_MTID, OUT, wv, W, C, S, L, matter,
		concluding_comment);
	return rv;
}
	
@ "Locale" here isn't used in the Unix sense. It means text which describes
a range of numbered paragraphs, from |par1| to |par2|, though |par2| can
instead be null, in which case the description is of just one para. (This
is often used in endnotes.)

@e LOCALE_FOR_MTID

=
VMETHOD_TYPE(LOCALE_FOR_MTID, weave_format *wf, text_stream *OUT, weave_order *wv,
	paragraph *par1, paragraph *par2)
void Formats::locale(OUTPUT_STREAM, weave_order *wv, paragraph *par1, paragraph *par2) {
	weave_format *wf = wv->format;
	VMETHOD_CALL(wf, LOCALE_FOR_MTID, OUT, wv, par1, par2);
}

@h Post-processing.
Consider what happens when Inweb makes a PDF, via TeX. The initial weave is
to a TeX file; it's then "post-processing" which will turn this into a PDF.
The following method calls allow such two-stage formats to function; in
this case, it would be the PDF format which provides the necessary methods
to turn TeX into PDF. The important method is this one:

@e POST_PROCESS_POS_MTID

=
VMETHOD_TYPE(POST_PROCESS_POS_MTID, weave_format *wf, weave_order *wv, int open_afterwards)
void Formats::post_process_weave(weave_order *wv, int open_afterwards) {
	VMETHOD_CALL(wv->format, POST_PROCESS_POS_MTID, wv, open_afterwards);
}

@ Optionally, a fancy report can be printed out, to describe what has been
done:

@e POST_PROCESS_REPORT_POS_MTID

=
VMETHOD_TYPE(POST_PROCESS_REPORT_POS_MTID, weave_format *wf, weave_order *wv)
void Formats::report_on_post_processing(weave_order *wv) {
	VMETHOD_CALL(wv->format, POST_PROCESS_REPORT_POS_MTID, wv);
}

@ After post-processing, an index file is sometimes needed. For example, if a
big web is woven to a swarm of PDFs, one for each section, then we also want
to make an index page in HTML which provides annotated links to those PDFs.

@e INDEX_PDFS_POS_MTID

=
IMETHOD_TYPE(INDEX_PDFS_POS_MTID, weave_format *wf)
int Formats::index_pdfs(text_stream *format) {
	weave_format *wf = Formats::find_by_name(format);
	if (wf == NULL) return FALSE;
	int rv = FALSE;
	IMETHOD_CALLV(rv, wf, INDEX_PDFS_POS_MTID);
	return rv;
}

@ And in that index file, we may want to substitute in values for placeholder
text like |[[PDF Size]]| in the template file. This is the |detail|.

@e POST_PROCESS_SUBSTITUTE_POS_MTID

=
IMETHOD_TYPE(POST_PROCESS_SUBSTITUTE_POS_MTID, weave_format *wf, text_stream *OUT,
	weave_order *wv, text_stream *detail, weave_pattern *pattern)
int Formats::substitute_post_processing_data(OUTPUT_STREAM, weave_order *wv,
	text_stream *detail, weave_pattern *pattern) {
	int rv = FALSE;
	IMETHOD_CALL(rv, wv->format, POST_PROCESS_SUBSTITUTE_POS_MTID, OUT, wv, detail, pattern);
	return rv;
}
