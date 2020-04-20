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

@ |RENDER_FOR_MTID| renders the weave tree in the given format: a format must
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
