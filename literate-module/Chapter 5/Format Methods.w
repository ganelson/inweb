[WeavingFormats::] Format Methods.

To characterise the relevant differences in behaviour between the
various weaving formats offered, such as HTML, ePub, or TeX.

@h Formats.
Exactly as in the previous chapter, each format expresses its behaviour
through optional method calls.

=
typedef struct weave_format {
	struct text_stream *format_name;
	struct text_stream *woven_extension;
	struct method_set *methods;
	CLASS_DEFINITION
} weave_format;

weave_format *WeavingFormats::create_weave_format(text_stream *name, text_stream *ext) {
	weave_format *wf = CREATE(weave_format);
	wf->format_name = Str::duplicate(name);
	wf->woven_extension = Str::duplicate(ext);
	wf->methods = Methods::new_set();
	return wf;
}

weave_format *WeavingFormats::find_by_name(text_stream *name) {
	weave_format *wf;
	LOOP_OVER(wf, weave_format)
		if (Str::eq_insensitive(name, wf->format_name))
			return wf;
	return NULL;
}

@ Note that this is the file extension before any post-processing. For
example, PDFs may be made by weaving a TeX file and then running this through
|pdftex|. The extension here would be |.tex| because that's what the weave
stage produces, even though we would later end up with a |.pdf|.

=
text_stream *WeavingFormats::file_extension(weave_format *wf) {
	return wf->woven_extension;
}

@h Creation.
This must be performed very early on, before any weaving takes place.

=
void WeavingFormats::create_weave_formats(void) {
	DebuggingWeaving::create();
	TeXWeaving::create();
	PlainTextWeaving::create();
	HTMLWeaving::create();
}

@h Rendering.
The render process is the final output stage of a weave, and that of course
is when the output format becomes critical. We need to take the "weave tree"
of rendering instructions, then create a file to write its content to. Note
that we are therefore assuming there will be only a single file of output
corresponding to a single weave tree.

=
void WeavingFormats::render(weave_order *wv, heterogeneous_tree *weave_tree) {
	filename *F = wv->weave_to;
	text_stream TO_struct;
	text_stream *OUT = &TO_struct;
	if (STREAM_OPEN_TO_FILE(OUT, F, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write woven file", F);
	WeavingFormats::render_to(OUT, weave_tree, F);
	STREAM_CLOSE(OUT);
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
INT_METHOD_TYPE(BEGIN_WEAVING_FOR_MTID, weave_format *wf, ls_web *W, ls_pattern *pattern)
VOID_METHOD_TYPE(END_WEAVING_FOR_MTID, weave_format *wf, ls_web *W, ls_pattern *pattern)
int WeavingFormats::begin_weaving(ls_web *W, ls_pattern *pattern) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, Patterns::get_format(W, pattern), BEGIN_WEAVING_FOR_MTID, W, pattern);
	if (rv) return rv;
	return SWARM_OFF_SWM;
}
void WeavingFormats::end_weaving(ls_web *W, ls_pattern *pattern) {
	VOID_METHOD_CALL(Patterns::get_format(W, pattern), END_WEAVING_FOR_MTID, W, pattern);
}

@ |RENDER_FOR_MTID| renders the weave tree in the given format: a format must
provide this.

Note the use of an optional "body template" to provide material before and
after the usage of |[[Weave Content]]|; but note also that this content is
generated first, and the fore and aft matter second, so that the fore matter
can include plugin links whose need was only realised when rendering the
actual content.

@e RENDER_FOR_MTID

=
VOID_METHOD_TYPE(RENDER_FOR_MTID, weave_format *wf, text_stream *OUT, heterogeneous_tree *tree)
void WeavingFormats::render_to(text_stream *OUT, heterogeneous_tree *tree, filename *into) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	weave_format *wf = C->wv->format;
	TEMPORARY_TEXT(template)
	WRITE_TO(template, "template-body%S", wf->woven_extension);
	filename *F = Patterns::find_template(C->wv->weave_web, C->wv->pattern, template);
	TEMPORARY_TEXT(interior)
	VOID_METHOD_CALL(wf, RENDER_FOR_MTID, interior, tree);
	Bibliographic::set_datum(C->wv->weave_web, I"Weave Content", interior);
	if (F) Collater::for_order(OUT, C->wv, F, into, C->wv->weave_colony);
	else WRITE("%S", interior);
	DISCARD_TEXT(interior)
	DISCARD_TEXT(template)
}

@ The weaver has special typographical support for the stand-alone Inform
document of Preform grammar, and this is the hook for it. Most formats
should ignore it.

@e PREFORM_DOCUMENT_FOR_MTID

=
INT_METHOD_TYPE(PREFORM_DOCUMENT_FOR_MTID, weave_format *wf, text_stream *OUT,
	weave_order *wv, ls_web *W, ls_chapter *C, ls_section *S, ls_line *lst,
	text_stream *matter, text_stream *concluding_comment)
int WeavingFormats::preform_document(OUTPUT_STREAM, weave_order *wv, ls_web *W,
	ls_chapter *C, ls_section *S, ls_line *lst, text_stream *matter,
	text_stream *concluding_comment) {
	weave_format *wf = wv->format;
	int rv = FALSE;
	INT_METHOD_CALL(rv, wf, PREFORM_DOCUMENT_FOR_MTID, OUT, wv, W, C, S, lst, matter,
		concluding_comment);
	return rv;
}
	
@h Post-processing.
Post-processing is now largely done by commands in the pattern file, rather
than here, but we retain method calls to enable formats to do some idiosyncratic
post-processing.

@e POST_PROCESS_POS_MTID

=
VOID_METHOD_TYPE(POST_PROCESS_POS_MTID, weave_format *wf, weave_order *wv, int open_afterwards)
void WeavingFormats::post_process_weave(weave_order *wv, int open_afterwards) {
	VOID_METHOD_CALL(wv->format, POST_PROCESS_POS_MTID, wv, open_afterwards);
}

@ Optionally, a fancy report can be printed out, to describe what has been
done. Support for TeX console reporting is hard-wired here because it's
handled by //Patterns::post_process// directly.

@e POST_PROCESS_REPORT_POS_MTID

=
VOID_METHOD_TYPE(POST_PROCESS_REPORT_POS_MTID, weave_format *wf, weave_order *wv)
void WeavingFormats::report_on_post_processing(weave_order *wv) {
	TeXUtilities::report_on_post_processing(wv);
	VOID_METHOD_CALL(wv->format, POST_PROCESS_REPORT_POS_MTID, wv);
}

@ For the sake of index files, we may want to substitute in values for
placeholder text in the template file.

@e POST_PROCESS_SUBSTITUTE_POS_MTID

=
INT_METHOD_TYPE(POST_PROCESS_SUBSTITUTE_POS_MTID, weave_format *wf, text_stream *OUT,
	weave_order *wv, text_stream *detail, ls_pattern *pattern)
int WeavingFormats::substitute_post_processing_data(OUTPUT_STREAM, weave_order *wv,
	text_stream *detail, ls_pattern *pattern) {
	int rv = TeXUtilities::substitute_post_processing_data(OUT, wv, detail);
	INT_METHOD_CALL(rv, wv->format, POST_PROCESS_SUBSTITUTE_POS_MTID, OUT, wv, detail, pattern);
	return rv;
}
