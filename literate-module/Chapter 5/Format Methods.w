[WeavingFormats::] Format Methods.

To characterise the relevant differences in behaviour between the
various weaving formats offered, such as HTML, ePub, or TeX.

@h Formats.
Exactly as in the previous chapter, each format expresses its behaviour
through optional method calls.

=
classdef weave_format {
	struct text_stream *format_name;
	struct text_stream *woven_extension;
	struct method_set *methods;
}

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
`pdftex`. The extension here would be `.tex` because that's what the weave
stage produces, even though we would later end up with a `.pdf`.

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
	LaTeXWeaving::create();
	PlainTextWeaving::create();
	HTMLWeaving::create();
}

@h Rendering.
The render process is the final output stage of a weave, and that of course
is when the output format becomes critical. We need to take the "weave tree"
of rendering instructions, then create a file to write its content to. Note
that we are therefore assuming there will be only a single file of output
corresponding to a single weave tree.

This is also where we finally merge material into its insertion points. That
material is placed at character positions, where position $n$ means "before
the $n$-th character". Those positions are set during the process of expanding
the "Weave Content" placeholder in the collater, which means they are relative
not to the start of the file, but to the material in that placeholder; and so
we add `wv->weave_content_position` to the positions to make them absolute.

=
void WeavingFormats::render(weave_order *wv, heterogeneous_tree *weave_tree) {
	filename *F = wv->weave_to;
	text_stream TO_struct;
	text_stream *OUT = &TO_struct;
	if (STREAM_OPEN_TO_FILE(OUT, F, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to write woven file", F);
	TEMPORARY_TEXT(buffer)
	Swarm::begin_file(wv, F);
	WeavingFormats::render_to(buffer, weave_tree, F);
	for (int p=0; p<NO_DEFINED_WEAVEINSCRIPTION_VALUES; p++)
		if (wv->current_insertion_points[p] >= 0)
			wv->current_insertion_points[p] += wv->weave_content_position;
	for (int i=0; i<Str::len(buffer); i++) {
		for (int p=0; p<NO_DEFINED_WEAVEINSCRIPTION_VALUES; p++)
			if (wv->current_insertion_points[p] == i)
				WRITE("%S", wv->current_inscriptions[p]);
		PUT(Str::get_at(buffer, i));				
	}
	for (int p=0; p<NO_DEFINED_WEAVEINSCRIPTION_VALUES; p++)
		if (wv->current_insertion_points[p] == Str::len(buffer))
			WRITE("%S", wv->current_inscriptions[p]);
	DISCARD_TEXT(buffer)
	STREAM_CLOSE(OUT);
}

@h Methods.
These two don't allow output to be produced: they're for any setting up and
putting away that needs tp be done.

`BEGIN_WEAVING_FOR_MTID` is called before any output is generated, indeed,
before even the filename(s) for the output are worked out. Note that it
can return a `*_SWM` code to change the swarm behaviour of the weave to come;
this is helpful for EPUB weaving.

More simply, `END_WEAVING_FOR_MTID` is called when all weaving is done.

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

@ `RENDER_FOR_MTID` renders the weave tree in the given format: a format must
provide this.

Note the use of an optional "body template" to provide material before and
after the usage of `[[Weave Content]]`; but note also that this content is
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
	if (F) Collater::collate(OUT, C->wv, F);
	else WRITE("%S", interior);
	DISCARD_TEXT(interior)
	DISCARD_TEXT(template)
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
	TeXPost::report_on_post_processing(wv);
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
	if (wv) {
		int rv = TeXPost::substitute_post_processing_data(OUT, wv, detail);
		INT_METHOD_CALL(rv, wv->format, POST_PROCESS_SUBSTITUTE_POS_MTID, OUT, wv, detail, pattern);
		return rv;
	}
	return FALSE;
}

@h Standard colour scheme.
The Markdown code in //foundation// allows any rendering format to use its own
idiosyncratic set of colours in syntax colouring, but we want to use a standard
set, as provided by //The Painter//:

=
void WeavingFormats::name_colour(markdown_render *rdr, text_stream *OUT, int col) {
	WRITE("%S", Painter::colour_classname(NULL, (inchar32_t) col));
}

void WeavingFormats::name_colour_scheme(markdown_render *rdr, text_stream *OUT, void *csv) {
	colour_scheme *cs = (colour_scheme *) csv;
	WRITE("%S", cs->prefix);
}

@ And this is then a plain-vanilla way to use them:

=
void WeavingFormats::begin_colouring(markdown_render *rdr, text_stream *language_rendered,
	void **token, void **colours) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	programming_language *pl = wv->weave_web->web_language;
	if (Str::len(language_rendered) > 0)
		pl = Languages::find(wv->weave_web, language_rendered);
	if (pl == NULL) {
		WRITE_TO(STDERR, "warning: no language definition for '%S'\n", language_rendered);
		if (Str::eq_insensitive(language_rendered, I"plain"))
			WRITE_TO(STDERR,
				"(note that 'plain' is not normally a language: use 'none' instead)\n");
		pl = Languages::find(wv->weave_web, I"None");
	}
	Painter::reset_syntax_colouring(pl);
	*token = (void *) pl;
	*colours = NULL;
}

void WeavingFormats::colour_line(markdown_render *rdr, void *token, text_stream *code_line,
	text_stream *cols) {
	programming_language *pl = (programming_language *) token;
	Painter::syntax_colour(pl, &(pl->built_in_keywords), code_line, cols, FALSE, TRUE);
}

@h Standard way to resolve links.
Similarly, all our formats which can have links at all should use the following
way of resolving them:

=
void WeavingFormats::resolve_link(markdown_render *rdr, text_stream *link_text, query_results *qr) {
	if (qr == NULL) internal_error("no query results structure");
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	if (wv)
		Colonies::resolve_reference(qr, link_text,
			wv->weave_colony, wv->weave_web, wv->current_weave_line, wv->weave_to);
	else
		Colonies::resolve_reference(qr, link_text, NULL, NULL, NULL, NULL);
}
