[HTMLWeaving::] HTML Format.

To provide for weaving into HTML.

@h Creation.

=
void HTMLWeaving::create(void) {
	weave_format *wf = WeavingFormats::create_weave_format(I"HTML", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLWeaving::render);
}

@h Markdown rendering instructions.
While the code in this section renders the weave tree, the actual commentary
(along with other fragments, such as comments in code, depending on the
conventions used) is stored in Markdown, and needs to be handed over to the
code in //foundation: Markdown to HTML//.

That needs a set of instructions, to say what kind of Markdown, how we want it
rendered, and so on.

=
markdown_render HTMLWeaving::Markdown_instructions(weave_order *wv) {
	markdown_render rdr = MDRender::contextual_HTML(
		WebNotation::commentary_variation(wv->weave_web), STORE_POINTER_weave_order(wv));
	markdown_render *prdr = &rdr;
	METHOD_ADD(prdr, NAME_COLOUR_MTID, WeavingFormats::name_colour);
	METHOD_ADD(prdr, NAME_COLOUR_SCHEME_MTID, WeavingFormats::name_colour_scheme);
	METHOD_ADD(prdr, BEGIN_COLOURING_MTID, HTMLWeaving::begin_colouring);
	METHOD_ADD(prdr, COLOUR_LINE_MTID, WeavingFormats::colour_line);
	METHOD_ADD(prdr, RESOLVE_LINK_MTID, WeavingFormats::resolve_link);
	METHOD_ADD(prdr, NOTIFY_IMAGE_MTID, HTMLWeaving::notify_image);
	METHOD_ADD(prdr, RENDER_GADGET_MTID, HTMLWeaving::render_gadget);
	METHOD_ADD(prdr, RENDER_UL_AS_CAROUSEL_MTID, HTMLWeaving::render_ul_as_carousel);
	METHOD_ADD(prdr, VETO_MATHEMATICS_MTID, HTMLWeaving::veto_mathematics);
	return rdr;
}

@h Rendering.
The weave tree will be rendered by traversing it, and rendering each node in its
turn. Everything else in this function is just book-keeping.

=
void HTMLWeaving::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	Swarm::begin_file(C->wv, C->wv->weave_to);
	HTML::declare_as_HTML(OUT, FALSE);
	C->wv->current_insertion_points[BODY_WEAVEINSCRIPTION] = Str::len(OUT);

	Swarm::ensure_plugin(C->wv, I"Base");

	HTML_render_state hrs;
	@<Initialise the render state@>;

	Trees::traverse_from(tree->root, &HTMLWeaving::render_visit, (void *) &hrs, 0);

	HTML::completed(OUT);
	if (C->footnotes_present) {
		text_stream *fn_plugin_name = Patterns::get_footnotes_plugin(C->wv->weave_web, C->wv->pattern);
		if (Str::len(fn_plugin_name) > 0) Swarm::ensure_plugin(C->wv, fn_plugin_name);
	}
}

@ The following state will be carried through the traverse. The top half
basically collates the instructions on what to do; the bottom half is a set
of tallies of how far we've got.

=
classdef HTML_render_state {
	/* these never change during the traverse */
	struct text_stream *OUT;
	struct weave_order *wv;
	struct asset_rule *copy_rule;
	struct markdown_render rdr;

	/* these, on the other hand, do change */
	int popup_counter;
	int max_label_width;
	struct ls_paragraph *para_to_open;
	int HTML_para_is_open;
	struct colour_scheme *colours;
}

@<Initialise the render state@> =
	hrs.OUT = OUT;
	hrs.wv = C->wv;
	hrs.copy_rule = Assets::simple_private_copy();
	hrs.rdr = HTMLWeaving::Markdown_instructions(C->wv);

	hrs.popup_counter = 1;
	hrs.max_label_width = 0;
	hrs.para_to_open = NULL;
	hrs.HTML_para_is_open = FALSE;
	hrs.colours = Swarm::ensure_colour_scheme(C->wv, I"Colours", I"");

@ So, then, the visiting function, called on each node. C does not allow
switch statements whose cases are not literal constants, so there's a
big contrived `if` instead. But it is morally a `switch`.

=
int HTMLWeaving::render_visit(tree_node *N, void *state, int L) {
	HTML_render_state *hrs = (HTML_render_state *) state;
	text_stream *OUT = hrs->OUT;

	/* Document superstructure */

	     if (N->type == weave_document_node_type) @<Skip@>
	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_body_node_type) @<Skip@>
	else if (N->type == weave_tail_node_type) @<Render tail@>

	/* Large-scale structure */

	else if (N->type == weave_chapter_node_type) @<Skip@>
	else if (N->type == weave_chapter_header_node_type) @<Skip@>
	else if (N->type == weave_chapter_footer_node_type) @<Skip@>
	else if (N->type == weave_section_node_type) @<Skip@>
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
		Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);

@h Document superstructure renderers.
These are just comments.

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	HTML::comment(OUT, C->banner);

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	HTML::comment(OUT, C->rennab);

@h Large-scale structure renderers.
Note that we don't compile code for the search box here: we only mark the
place where that code should be inserted later (if a search box is required).
It goes underneath the breadcrumbs.

@<Render section header@> =
	weave_section_header_node *C =
		RETRIEVE_POINTER_weave_section_header_node(N->content);
	@<Render breadcrumb trail@>;
	hrs->wv->current_insertion_points[SEARCH_BOX_WEAVEINSCRIPTION] = Str::len(OUT);

@<Render breadcrumb trail@> =
	Swarm::ensure_plugin(hrs->wv, I"Breadcrumbs");
	HTML_OPEN_WITH("div", "class=\"breadcrumbs\"");
	HTML_OPEN_WITH("ul", "class=\"crumbs\"");
	Colonies::drop_initial_breadcrumbs(OUT, hrs->wv->weave_colony,
		hrs->wv->weave_to, hrs->wv->breadcrumbs);
	text_stream *bct = Bibliographic::get_datum(hrs->wv->weave_web, I"Title");
	if (Str::len(Bibliographic::get_datum(hrs->wv->weave_web, I"Short Title")) > 0)
		bct = Bibliographic::get_datum(hrs->wv->weave_web, I"Short Title");
	if (hrs->wv->self_contained == FALSE) {
		Colonies::write_breadcrumb(OUT, bct, hrs->wv->home_leaf);
		if (hrs->wv->weave_web->chaptered) {
			TEMPORARY_TEXT(chapter_link)
			WRITE_TO(chapter_link, "%S#%s%S",
				hrs->wv->home_leaf,
				(WeavingDetails::get_as_ebook(hrs->wv->weave_web))?"C":"",
				C->sect->owning_chapter->ch_range);
			Colonies::write_breadcrumb(OUT,
				C->sect->owning_chapter->ch_title, chapter_link);
			DISCARD_TEXT(chapter_link)
		}
		Colonies::write_breadcrumb(OUT, C->sect->sect_title, NULL);
	} else {
		Colonies::write_breadcrumb(OUT, bct, NULL);
	}
	HTML_CLOSE("ul");
	HTML_CLOSE("div");

@<Render section footer@> =
	weave_section_footer_node *C =
		RETRIEVE_POINTER_weave_section_footer_node(N->content);
	ls_section *next_S = NULL, *prev_S = NULL;
	@<Find the previous and next sections in the web@>;
	if ((next_S) || (prev_S)) @<Render the section-selector@>;

@ Note that these are the previous and next sections within the whole _web_,
not within this particular _weave_. Material from those sections may well not
be in the tree we are currently rendering.

@<Find the previous and next sections in the web@> =
	ls_chapter *Ch;
	ls_section *last = NULL;
	LOOP_OVER_LINKED_LIST(Ch, ls_chapter, hrs->wv->weave_web->chapters) {
		if (Ch->imported == FALSE) {
			ls_section *S;
			LOOP_OVER_LINKED_LIST(S, ls_section, Ch->sections) {
				if (S == C->sect) prev_S = last;
				if (last == C->sect) next_S = S;
				last = S;
			}
		}
	}

@ The chapter range `S` means that the web doesn't really have chapters, only
a collection of sections in an invisible omnibus chapter called "Sections".

@<Render the section-selector@> =
	HTML_OPEN_WITH("nav", "role=\"progress\"");
	HTML_OPEN_WITH("div", "class=\"progresscontainer\"");
	HTML_OPEN_WITH("ul", "class=\"progressbar\"");
	@<Insert previous arrow@>;
	ls_chapter *Ch;
	LOOP_OVER_LINKED_LIST(Ch, ls_chapter, hrs->wv->weave_web->chapters) {
		if (Ch->imported == FALSE) {
			if (Str::ne(Ch->ch_range, I"S")) @<Place a chapter cell@>;
			if (Ch == C->sect->owning_chapter) @<Place cells for each section in this chapter@>;
		}
	}
	@<Insert next arrow@>;
	HTML_CLOSE("ul");
	HTML_CLOSE("div");
	HTML_CLOSE("nav");

@ Each cell is single list item. There is a popup (hidden by CSS until needed)
with its full title; then a linked text of its range (or abbreviated title).
Ranges for chapters are normally numbers, so `3` for Chapter 3, for example,
but can also be letters for appendices or `P` for Preliminaries.

The link for a chapter goes to its opening section.

@<Place a chapter cell@> =
	if (Ch == C->sect->owning_chapter) {
		HTML_OPEN_WITH("li", "class=\"progresscurrentchapter\"");
		HTMLWeaving::selector_popup(OUT, I"current-c-fullname-popup", Ch->ch_title);
	} else {
		HTML_OPEN_WITH("li", "class=\"progresschapter\"");
		HTMLWeaving::selector_popup(OUT, I"c-fullname-popup", Ch->ch_title);
	}
	ls_section *S = FIRST_IN_LINKED_LIST(ls_section, Ch->sections);
	if (S) {
		TEMPORARY_TEXT(TEMP)
		Colonies::section_URL(TEMP, S);
		if (Ch != C->sect->owning_chapter) HTML::begin_link(OUT, TEMP);
		WRITE("%S", Ch->ch_range);
		if (Ch != C->sect->owning_chapter) HTML::end_link(OUT);
		DISCARD_TEXT(TEMP)
	}
	HTML_CLOSE("li");

@ Just to get this out of the way:

=
void HTMLWeaving::selector_popup(OUTPUT_STREAM, text_stream *cl, text_stream *content) {
	HTML_OPEN_WITH("span", "class=\"%S\"", cl);
	MDRenderHTML::escape_text(OUT, content);
	HTML_CLOSE("span");
}

@ If sections are sequentially numbered then they have ranges like `S3`, and
we get rid of the spurious `S` on each. Otherwise, this is similar.

@<Place cells for each section in this chapter@> =
	ls_section *S;
	LOOP_OVER_LINKED_LIST(S, ls_section, Ch->sections) {
		TEMPORARY_TEXT(label)
		int on = FALSE;
		text_stream *range = WebRanges::of(S);
		LOOP_THROUGH_TEXT(pos, range) {
			if (Str::get(pos) == '/') on = TRUE;
			else if (on) PUT_TO(label, Str::get(pos));
		}
		if (on == FALSE) Str::copy(label, range);
		if (Conventions::get_int(hrs->wv->weave_web,
			SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION))
			Str::delete_first_character(label);
		if (S == C->sect) {
			HTML_OPEN_WITH("li", "class=\"progresscurrent\"");
			HTMLWeaving::selector_popup(OUT, I"current-fullname-popup", S->sect_title);
			WRITE("%S", label);
			HTML_CLOSE("li");
		} else {
			HTML_OPEN_WITH("li", "class=\"progresssection\"");
			HTMLWeaving::selector_popup(OUT, I"fullname-popup", S->sect_title);
			TEMPORARY_TEXT(TEMP)
			Colonies::section_URL(TEMP, S);
			HTML::begin_link(OUT, TEMP);
			WRITE("%S", label);
			HTML::end_link(OUT);
			DISCARD_TEXT(TEMP)
			HTML_CLOSE("li");		
		}
		DISCARD_TEXT(label)
	}

@ A special cell at the beginning is the "immediately previous section" arrow;
and similarly at the end.

@<Insert previous arrow@> =
	if (prev_S) {
		HTML_OPEN_WITH("li", "class=\"progressprev\"");
		HTMLWeaving::selector_popup(OUT, I"nav-popup", prev_S->sect_title);
	} else HTML_OPEN_WITH("li", "class=\"progressprevoff\"");
	TEMPORARY_TEXT(TEMP)
	if (prev_S) Colonies::section_URL(TEMP, prev_S);
	if (prev_S) HTML::begin_link(OUT, TEMP);
	WRITE("&#10094;");
	if (prev_S) HTML::end_link(OUT);
	DISCARD_TEXT(TEMP)
	HTML_CLOSE("li");

@<Insert next arrow@> =
	if (next_S) {
		HTML_OPEN_WITH("li", "class=\"progressnext\"");
		HTMLWeaving::selector_popup(OUT, I"nav-popup", next_S->sect_title);
	} else HTML_OPEN_WITH("li", "class=\"progressnextoff\"");
	TEMPORARY_TEXT(TEMP)
	if (next_S) Colonies::section_URL(TEMP, next_S);
	if (next_S) HTML::begin_link(OUT, TEMP);
	WRITE("&#10095;");
	if (next_S) HTML::end_link(OUT);
	DISCARD_TEXT(TEMP)
	HTML_CLOSE("li");

@<Render section purpose@> =
	weave_section_purpose_node *C =
		RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	HTML_OPEN_WITH("p", "class=\"purpose\"");
	MDRenderHTML::escape_text(OUT, C->purpose);
	HTML_CLOSE("p"); WRITE("\n");

@ The table of contents. Note that this time we return `FALSE`, which signals
that we don't want to traverse the child nodes of this node: we don't need
to, because we've done so already in the middle of handling this one. This is
a tactic which will often be used below. (By default, this visitor function
would otherwise have returned `TRUE`; that's what happens on all the cases
not explicitly saying to return `FALSE`.)

@<Render toc@> =
	HTML_OPEN_WITH("ul", "class=\"toc\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("ul");
	HTML::hr(OUT, "tocbar");
	WRITE("\n");
	return FALSE;

@ This could in principle use `HTMLWeaving::locale`, but we want to give it
a tweak by rendering sub-entries like 2.3.2 less emphatically than main entries
like 2.

@<Render toc line@> =
	HTML_OPEN("li");
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, C->para, NULL, hrs->wv->weave_to, hrs->wv->weave_colony);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	int depth = LiterateSource::par_depth(C->para);
	if (depth == -1) HTML_OPEN("b");
	if (depth > 0) HTML_OPEN("i");
	WRITE("%s%S", (Str::get_first_char(LiterateSource::par_ornament(C->para)) == 'S')?"&#167;":"&para;",
		C->para->paragraph_number);
	WRITE(". ");
	MDRenderHTML::escape_text(OUT, C->text2);
	if (depth > 0) HTML_CLOSE("i");
	if (depth == -1) HTML_CLOSE("b");
	HTML::end_link(OUT);
	HTML_CLOSE("li");

@h Small-scale structure renderers.
These two forms of subheading are little used in HTML: only where the weave
places multiple sections or chapters in a single HTML file.

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	HTML_OPEN("h3");
	MDRenderHTML::escape_text(OUT, C->text);
	HTML_CLOSE("h3"); WRITE("\n");

@<Render subsubheading@> =
	weave_subsubheading_node *C = RETRIEVE_POINTER_weave_subsubheading_node(N->content);
	HTML_OPEN("h4");
	MDRenderHTML::escape_text(OUT, C->text);
	HTML_CLOSE("h4"); WRITE("\n");

@ An Inweb paragraph is rendered as a run of HTML paragraphs and other tags.
It always needs to begin with an HTML paragraph, and its title (if any) in bold.
But there's a snag. If, as is very often the case, the first content is then
some commentary, we want that commentary to continue in the same HTML para.
That is, we want (simplifying a bit):

``` none
	<div class="lsmarkdown">
	<p>13. <b>Disposal of memory</b>. This is where we need to free up
	all those arrays [...] </p>
	</div>
```

rather than

``` none
	<p>13. <b>Disposal of memory</b>.</p>
	<div class="lsmarkdown">
	<p>This is where we need to free up
	all those arrays [...] </p>
	</div>
```

Because of that, we render the Inweb paragraph opening `<p>13. <b>Disposal of memory</b>.`
only _on demand_. We stash the paragraph waiting to be opened in `hrs->para_to_open`.

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C =
		RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	if (C->para == NULL) internal_error("no para");
	hrs->para_to_open = C->para;
	hrs->HTML_para_is_open = FALSE;
	@<Recurse the renderer through children nodes@>;
	@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@>;
	return FALSE;

@<If Inweb para not yet opened, open it@> =
	if (hrs->para_to_open) {
		ls_paragraph *par = hrs->para_to_open;
		text_stream *title = LiterateSource::par_title(par);
		int depth = LiterateSource::par_depth(par);
		if (depth == -1) {
			HTML_OPEN("h2");
			MDRenderHTML::escape_text(OUT, title);
			HTML_CLOSE("h2");
		}
		HTML_OPEN_WITH("p", "class=\"commentary firstcommentary\"");
		TEMPORARY_TEXT(TEMP)
		Colonies::paragraph_anchor(TEMP, par);
		HTML::anchor_with_class(OUT, TEMP, I"paragraph-anchor");
		DISCARD_TEXT(TEMP)
		if (LiterateSource::par_has_visible_number(par)) {
			HTML_OPEN("b");
			WRITE("%s%S", (Str::get_first_char(LiterateSource::par_ornament(par)) == 'S')?"&#167;":"&para;",
				par->paragraph_number);
			WRITE(". ");
			MDRenderHTML::escape_text(OUT, title);
			inchar32_t c = LiterateSource::par_title_punctuation(par);
			if (c != 0) WRITE("%c", c);
			HTML_CLOSE("b");
			WRITE(" ");
		}
		hrs->para_to_open = NULL;
		hrs->HTML_para_is_open = TRUE;
	}

@<If HTML para is open, close it@> =
	if (hrs->HTML_para_is_open) { HTML_CLOSE("p"); hrs->HTML_para_is_open = FALSE; }

@ Well, so far, so good. Two maneouvres turn out to be worth naming: one is for
use when we definitely want an HTML `p` to be open now:

@<Open an HTML paragraph within the Inweb one@> =
	@<If HTML para is open, close it@>;
	if (hrs->para_to_open) @<If Inweb para not yet opened, open it@>
	else HTML_OPEN_WITH("p", "class=\"commentary\"");
	hrs->HTML_para_is_open = TRUE;

@ And the other when we need an HTML `p` _not_ to be open, but also need to make
sure that the Inweb paragraph heading has definitely appeared, even if that
means it is immediately closed again. For example, this would happen if
rendering an Inweb paragraph with no commentary, only a code block.

@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@> =
	@<If Inweb para not yet opened, open it@>;
	@<If HTML para is open, close it@>;

@ Okay, so now we can look at the recursion beneath the paragraph node. Its
child nodes are all material nodes, so take us here:

@<Render material@> =
	weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
	if (C->material_type == COMMENTARY_MATERIAL)
		@<Deal with a commentary material node@>
	else if (C->material_type == DEFINITION_MATERIAL)
		@<Deal with a definition material node@>
	else if (C->material_type == HOLON_DECLARATION_MATERIAL)
		@<Deal with a holon declaration material node@>
	else if (C->material_type == CODE_MATERIAL)
		@<Deal with a code material node@>
	else if (C->material_type == ENDNOTES_MATERIAL)
		@<Deal with a endnotes material node@>
	else if (C->material_type == FOOTNOTES_MATERIAL)
		@<Deal with a footnotes material node@>;
	return FALSE;

@ A commentary material node can contain insertions as well as fragments of
Markdown. These need to be dealt with differently because the Markdown needs
to sit inside its own `div`, as noted above:

@<Deal with a commentary material node@> =
	for (tree_node *M = N->child; M; M = M->next) {
		if (M->type == weave_markdown_node_type) {
			@<If HTML para is open, close it@>;
			HTML_OPEN_WITH("div", "class=\"lsmarkdown\"");
			@<Open an HTML paragraph within the Inweb one@>;
			while ((M) && (M->type == weave_markdown_node_type)) {
				Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);
				M = M->next;
			}
			HTML_CLOSE("div");
		}
		if (M == NULL) break;
		@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@>;
		Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);
	}

@<Deal with a definition material node@> =
	@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@>;
	HTML_OPEN_WITH("pre", "class=\"definitions code-font\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("pre"); WRITE("\n");

@ This node contains no code: only the cartouche naming the holon. Some code
will follow, but that will be in a code material node which will be the next
child after this one of the paragraph node.

@<Deal with a holon declaration material node@> =
	@<Open an HTML paragraph within the Inweb one@>;
	@<Recurse the renderer through children nodes@>;

@<Deal with a code material node@> =
	@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@>;
	colour_scheme *save_cs = hrs->colours;
	if (C->styling) {
		TEMPORARY_TEXT(csname)
		WRITE_TO(csname, "%S-Colours", C->styling->language_name);
		hrs->colours = Swarm::ensure_colour_scheme(hrs->wv,
			csname, C->styling->language_name);
		DISCARD_TEXT(csname)
	}
	TEMPORARY_TEXT(cl)
	WRITE_TO(cl, "%S", hrs->colours->prefix);
	if (C->plainly) WRITE_TO(cl, "undisplayed-code");
	else WRITE_TO(cl, "displayed-code");
	WRITE("<pre class=\"%S all-displayed-code code-font\">\n", cl);
	DISCARD_TEXT(cl)
	@<Compute the maximum label width in this code block@>;
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("pre"); WRITE("\n");
	if (Str::len(C->endnote) > 0) {
		HTML_OPEN_WITH("ul", "class=\"endnotetexts\"");
		HTML_OPEN("li");
		MDRenderHTML::escape_text(OUT, C->endnote);
		HTML_CLOSE("li");
		HTML_CLOSE("ul"); WRITE("\n");
	}
	hrs->colours = save_cs;
	hrs->max_label_width = 0;

@ Some lines in the code block may have labels. If so, we want to know how
long the longest one is, in character width:

@<Compute the maximum label width in this code block@> =
	hrs->max_label_width = 0;
	for (tree_node *M = N->child; M; M = M->next)
		if (M->type == weave_code_line_node_type) {
			weave_code_line_node *MC = RETRIEVE_POINTER_weave_code_line_node(M->content);
			if ((MC->line) && (LineLabels::label_width(MC->line) > hrs->max_label_width))
				hrs->max_label_width = LineLabels::label_width(MC->line);
		}

@<Deal with a endnotes material node@> =
	@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@>;
	HTML_OPEN_WITH("ul", "class=\"endnotetexts\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("ul"); WRITE("\n");

@<Deal with a footnotes material node@> =
	@<If the Inweb para has not yet been opened, do so as a stand-alone HTML para@>;
	HTML_OPEN_WITH("ul", "class=\"footnotetexts\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("ul"); WRITE("\n");

@h Code-like material renderers.
We start with the cartouche around the name of a named holon:

@<Render holon declaration@> =
	weave_holon_declaration_node *C = RETRIEVE_POINTER_weave_holon_declaration_node(N->content);
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	ls_holon *label_holon = C->holon;
	if (C->holon->addendum_to) {
		label_holon = C->holon->addendum_to;
		TEMPORARY_TEXT(url)
		Colonies::paragraph_URL(url, label_holon->corresponding_chunk->owner, NULL,
			hrs->wv->weave_to, hrs->wv->weave_colony);
		HTML::begin_link_with_class(OUT, I"named-paragraph-link", url);
		DISCARD_TEXT(url)
	}
	HTML_OPEN_WITH("span", "class=\"named-paragraph-defn\"");
	if (label_holon->file_form) { PUT(0x2192); PUT(0x0020); }
	if (label_holon->holon_name_as_markdown)
		MDRender::render(OUT, &(hrs->rdr), label_holon->holon_name_as_markdown);
	else
		MDRenderHTML::escape_text(OUT, label_holon->holon_name);
	HTML_CLOSE("span");
	HTML_OPEN_WITH("span", "class=\"named-paragraph-number\"");
	MDRenderHTML::escape_text(OUT, label_holon->corresponding_chunk->owner->paragraph_number);
	HTML_CLOSE("span");
	if (C->holon->addendum_to) HTML::end_link(OUT);
	HTML_CLOSE("span");
	if (C->holon->addendum_to) MDRenderHTML::escape_text(OUT, I" +=");
	else MDRenderHTML::escape_text(OUT, I" =");

@ Lines in a code block only have a left margin to contain labels if at least
one of the lines actually has a label (so that the maximum width is positive).

@<Render code line@> =
	weave_code_line_node *C = RETRIEVE_POINTER_weave_code_line_node(N->content);
	if (hrs->max_label_width > 0) @<Begin with the label margin@>;
	@<Insert an anchor to make it possible to link to this line@>;
	@<Recurse the renderer through children nodes@>;
	WRITE("\n");
	return FALSE;

@ There are very likely better ways to do this, but the idea is that the margin
has equal width for all lines in the block, whether or not they contain labels.

Note that labels hyperlink to themselves, that is, to an anchor on the same
line as the label. This is intentional: it means you can left-click on a
label and copy its link.

@<Begin with the label margin@> =
	WRITE("<span class=\"labelmargin\">");
	int n = 0;
	if (LineLabels::labelled(C->line)) {
		WRITE("<a id=\"");
		LineLabels::anchor(OUT, C->line);
		WRITE("\" class=\"labelanchor\"></a><span class=\"linelabel\"><a href=\"#");
		LineLabels::anchor(OUT, C->line);
		WRITE("\">%S</a></span>",
			LineLabels::label_text(C->line));
		n = LineLabels::label_width(C->line);
	} else {
		WRITE("<span class=\"nolinelabel\"> </span>");
		n = 1;
	}
	WRITE("<span class=\"nolinelabel\">");
	while (n++ < hrs->max_label_width+1) WRITE(" ");
	WRITE("</span>");
	WRITE("</span>");

@<Insert an anchor to make it possible to link to this line@> =
	ls_paragraph *par = LiterateSource::par_of_line(C->line);
	if (par == NULL) internal_error("line adrift");
	WRITE("<a id=\"");
	Colonies::paragraph_anchor(OUT, par);
	WRITE("LN%d\" class=\"lineanchor\"></a>", C->line->sequence_number_in_paragraph);

@ We're looking within a code line now. One of the items which can make this up
is a usage of a holon, and this sits in a cartouche:

@<Render holon usage@> =
	weave_holon_usage_node *C = RETRIEVE_POINTER_weave_holon_usage_node(N->content);
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	TEMPORARY_TEXT(url)
	Colonies::paragraph_URL(url, C->holon->corresponding_chunk->owner, NULL,
		hrs->wv->weave_to, hrs->wv->weave_colony);
	HTML::begin_link_with_class(OUT, I"named-paragraph-link", url);
	DISCARD_TEXT(url)
	HTML_OPEN_WITH("span", "class=\"named-paragraph\"");
	ls_holon *holon = C->holon;
	if (holon) {
		if (holon->holon_name_as_markdown) {
			HTML_OPEN_WITH("span", "class=\"mathjax_process\"");
			MDRender::render(OUT, &(hrs->rdr), holon->holon_name_as_markdown);
			HTML_CLOSE("span");
		} else
			MDRenderHTML::escape_text(OUT, holon->holon_name);
	}
	HTML_CLOSE("span");
	HTML_OPEN_WITH("span", "class=\"named-paragraph-number\"");
	MDRenderHTML::escape_text(OUT, C->holon->corresponding_chunk->owner->paragraph_number);
	HTML_CLOSE("span");
	HTML::end_link(OUT);
	HTML_CLOSE("span");

@ Another is a marker saying that tangler command output appears here, though
in practice we no longer use such commands.

@<Render tangler command@> =
	weave_tangler_command_node *C = RETRIEVE_POINTER_weave_tangler_command_node(N->content);
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	HTML_OPEN_WITH("span", "class=\"named-paragraph\"");
	MDRenderHTML::escape_text(OUT, I"output from tangler command '");
	MDRenderHTML::escape_text(OUT, C->command);
	MDRenderHTML::escape_text(OUT, I"'");
	HTML_CLOSE("span");
	HTML_CLOSE("span");

@ Still another is material marked to be passed raw out into HTML at this point.

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@ But most of what is on a code line is, in fact, code:

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	MDRenderHTML::render_syntax_coloured(OUT, &(hrs->rdr), C->matter, C->colouring, hrs->colours);

@<Render function defn@> =
	weave_function_defn_node *C =
		RETRIEVE_POINTER_weave_function_defn_node(N->content);

	MDRenderHTML::change_colour(OUT, &(hrs->rdr), FUNCTION_COLOUR, hrs->colours);
	WRITE("%S", C->fn->function_name);
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), -1, hrs->colours);

	int tot = C->local_usages + C->section_usages + C->external_usages;
	if (tot > 0) {
		if ((tot > 1) || (C->external_usages == 1)) @<Render a button with a popup of usages@>
		else @<Render a simplified link button to the single point of usage@>;
	}
	return FALSE;

@ This is the easier case: the function is used in just one place, either above
or below us in the current HTML file.

At one time the Unicode characters `0x2190` (a left arrow), `0x2199` (arrow
pointing in and down), `0x2196` (ditto but up) were used for the look of these
simplified buttons, but it's now done with SVG images encoded in the CSS.

@<Render a simplified link button to the single point of usage@> =
	HTML_OPEN_WITH("span", "class=\"button-slot\"");
	WRITE("<a href=\"");
	Colonies::paragraph_URL(OUT, C->hteu->usage_recorded_at, C->hteu->finer_positioning,
		hrs->wv->weave_to, hrs->wv->weave_colony);
	WRITE("\">");
	if (C->local_direction == -1) WRITE("<button class=\"popup arrow-from-above-button\">");
	else WRITE("<button class=\"popup arrow-from-below-button\">");
	WRITE("&nbsp;</button>");
	WRITE("</a>");
	HTML_CLOSE("span");

@ The trickier case is when the function is used multiple times, or from different
HTML files.

@<Render a button with a popup of usages@> =
	HTML_OPEN_WITH("span", "class=\"button-slot\"");
	Swarm::ensure_plugin(hrs->wv, I"Popups");
	WRITE("<button class=\"popup arrow-short-button\" onclick=\"togglePopup('usagePopup%d')\">",
		hrs->popup_counter);
	@<Visible button text@>;
	WRITE("<span class=\"popuptext\" id=\"usagePopup%d\">", hrs->popup_counter);
	@<Contents of popup@>;
	HTML_CLOSE("span");
	WRITE("</button>");
	HTML_CLOSE("span");
	hrs->popup_counter++;

@<Visible button text@> =
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), COMMENT_COLOUR, hrs->colours);
	if ((C->external_usages == 0) && (tot <= 3)) {
		hash_table_entry *hte =
			CodeAnalysis::find_hash_entry_for_section(C->fn->function_section,
				C->fn->function_name, FALSE);
		hash_table_entry_usage *hteu = NULL;
		int n = 0, counter = 0;
		ls_paragraph *cp = NULL;
		LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages) {
			if (hteu->finer_positioning != C->fn->function_header_at) {
				if (cp == hteu->usage_recorded_at) counter++;
				else {
					if (counter > 1) WRITE("&#215;%d", counter);
					if (n++ > 0) WRITE(",");
					inchar32_t c = Str::get_first_char(LiterateSource::par_ornament(hteu->usage_recorded_at));
					WRITE("%s%S", (c == 'S')?"&#167;":"&para;",
						hteu->usage_recorded_at->paragraph_number);
					counter = 1;
					cp = hteu->usage_recorded_at;
				}
			}
		}
		if (counter > 1) WRITE("&#215;%d", counter);
	} else {
		WRITE("%d", tot);
	}
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), -1, hrs->colours);

@ Details of the usages are in the child nodes to this one, which is why
we recurse downwards to produce the list inside the popup:

@<Contents of popup@> =
	WRITE("Usage of ");
	HTML_OPEN_WITH("span", "class=\"code-font\"");
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), FUNCTION_COLOUR, hrs->colours);
	WRITE("%S", C->fn->function_name);
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), -1, hrs->colours);
	HTML_CLOSE("span");
	WRITE(":<br/>"); 
	@<Recurse the renderer through children nodes@>;

@ And this is where those child nodes are rendered:

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	HTML::begin_link_with_class(OUT, I"function-link", C->url);
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), FUNCTION_COLOUR, hrs->colours);
	WRITE("%S", C->fn->function_name);
	MDRenderHTML::change_colour(OUT, &(hrs->rdr), -1, hrs->colours);
	HTML::end_link(OUT);

@ Comments inside holons are not always rendered using Markdown: but these nodes
are only produced if they are. 

@<Render comment in holon@> =
	weave_comment_in_holon_node *C = RETRIEVE_POINTER_weave_comment_in_holon_node(N->content);
	HTML_OPEN_WITH("span", "class=\"comment-syntax\"");
	MDRenderHTML::escape_text(OUT, C->comment_open);
	for (int i=0; ((i<Str::len(C->raw)) && (Characters::is_whitespace(Str::get_at(C->raw, i)))); i++)
		PUT(Str::get_at(C->raw, i));
	MDRender::render(OUT, &(hrs->rdr), C->as_markdown);
	for (int i=Str::len(C->raw) - 1; ((i>=0) && (Characters::is_whitespace(Str::get_at(C->raw, i)))); i--)
		PUT(Str::get_at(C->raw, i));
	MDRenderHTML::escape_text(OUT, C->comment_close);
	HTML_CLOSE("span");

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	HTML_OPEN_WITH("span", "class=\"definition-keyword\"");
	WRITE("%S", C->keyword);
	HTML_CLOSE("span");
	WRITE(" ");
	if (Str::len(C->symbol) > 0) {
		HTML_OPEN_WITH("span", "class=\"identifier-syntax\"");
		WRITE("%S", C->symbol);
		HTML_CLOSE("span");
		WRITE(" ");
	}

@h Commentary and gadget material renderers.
Note that we enter the HTML Markdown renderer here in `EXISTING_PAR_MDRMODE`
because an HTML `p` paragraph was definitely entered by the commentary
material node which is our parent: see above.

@<Render Markdown@> =
	weave_markdown_node *C = RETRIEVE_POINTER_weave_markdown_node(N->content);
	hrs->wv->current_weave_line = C->nearby_line;
	MDRender::render_in_mode(OUT, &(hrs->rdr), C->content,
		MDRender::entry_mode(&(hrs->rdr)) | EXISTING_PAR_MDRMODE);
	hrs->HTML_para_is_open = FALSE;

@<Render audio@> =
	weave_audio_node *C = RETRIEVE_POINTER_weave_audio_node(N->content);
	HTMLWeaving::render_gadget(&(hrs->rdr), OUT, AUDIO_INWEBGADGET, NULL, 0, 0, 0, C->audio_name);

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	TEMPORARY_TEXT(carousel_id)
	TEMPORARY_TEXT(carousel_dots_id)
	HTMLWeaving::render_carousel_top(OUT, hrs->wv, C->slide_number, C->slide_of,
		carousel_id, carousel_dots_id, C->caption, C->positioning);
	@<Recurse the renderer through children nodes@>;
	HTMLWeaving::render_carousel_bottom(OUT, hrs->wv, C->slide_number, C->slide_of,
		carousel_id, carousel_dots_id, C->caption, C->positioning);
	DISCARD_TEXT(carousel_id)
	DISCARD_TEXT(carousel_dots_id)
	return FALSE;

@<Render download@> =
	weave_download_node *C = RETRIEVE_POINTER_weave_download_node(N->content);
	HTMLWeaving::render_gadget(&(hrs->rdr), OUT, DOWNLOAD_INWEBGADGET, C->filetype, 0, 0, 0, C->download_name);

@ This has to embed some Internet-sourced content. `service`
here is something like `YouTube` or `Soundcloud`, and `ID` is whatever code
that service uses to identify the video/audio in question.

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	HTMLWeaving::render_gadget(&(hrs->rdr), OUT, EMBED_INWEBGADGET, C->service, C->w, C->h, 0, C->ID);

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	filename *F = Filenames::in(
		Pathnames::down(hrs->wv->weave_web->path_to_web, I"Figures"),
		C->figname);
	filename *RF = Filenames::from_text(C->figname);
	HTML_OPEN_WITH("p", "class=\"center-p\"");
	HTML::image_to_dimensions(OUT, RF, C->alt_text, C->w, C->h);
	Assets::include_asset(OUT, hrs->copy_rule, F, NULL, hrs->wv);
	HTML_CLOSE("p");
	WRITE("\n");

@<Render raw HTML@> =
	weave_raw_HTML_node *C = RETRIEVE_POINTER_weave_raw_HTML_node(N->content);
	HTMLWeaving::render_gadget(&(hrs->rdr), OUT, HTML_INWEBGADGET, NULL, 0, 0, 0, C->extract);

@<Render video@> =
	weave_video_node *C = RETRIEVE_POINTER_weave_video_node(N->content);
	HTMLWeaving::render_gadget(&(hrs->rdr), OUT, VIDEO_INWEBGADGET, NULL, C->w, C->h, 0, C->video_name);

@h Paragraph tail material renderers.

@<Render index begins@> =
	HTML_OPEN_WITH("div", "class=\"lsindex\"");

@<Render index lemma@> =
	weave_index_lemma_node *C = RETRIEVE_POINTER_weave_index_lemma_node(N->content);
	ls_index_lemma *lemma = C->lemma;
	int d = 0;
	for (ls_index_lemma *l2 = lemma->parent; l2; l2 = l2->parent) d++;
	text_stream *pclass = I"lsindexlemma";
	if (d == 1) pclass = I"lsindexsublemma";
	if (d == 2) pclass = I"lsindexsubsublemma";
	if (d >= 3) pclass = I"lsindexsubsubsublemma";
	HTML_OPEN_WITH("p", "class=\"%S\"", pclass);
	switch (lemma->style) {
		case 1: HTML_OPEN_WITH("span", "class=\"lsindextext\""); break;
		case 2: HTML_OPEN_WITH("code", "class=\"lsindextexttt\""); break;
		case 3: HTML_OPEN_WITH("span", "class=\"lsindextextns\""); break;
	}
	MDRenderHTML::escape_text(OUT, lemma->text);
	switch (lemma->style) {
		case 1: HTML_CLOSE("span"); break;
		case 2: HTML_CLOSE("code"); break;
		case 3: HTML_CLOSE("span"); break;
	}
	ls_index_mark *mark; int c = 0;
	LOOP_OVER_LINKED_LIST(mark, ls_index_mark, lemma->marks) {
		if (c++ > 0) WRITE(", "); else WRITE("&nbsp;&nbsp;");
		if (mark->important) HTML_OPEN("b");
		HTMLWeaving::locale(OUT, mark->at, NULL, NULL, hrs->wv->weave_to, hrs->wv->weave_colony, TRUE);
		if (mark->important) HTML_CLOSE("b");
	}
	HTML_CLOSE("p");

@<Render index ends@> =
	HTML_CLOSE("div");

@<Render endnote@> =
	HTML_OPEN("li");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("li");
	return FALSE;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	HTMLWeaving::locale(OUT, C->par1, C->finer, C->par2, hrs->wv->weave_to, hrs->wv->weave_colony, C->distant);

@<Render endnote text@> =
	weave_endnote_text_node *C = RETRIEVE_POINTER_weave_endnote_text_node(N->content);
	for (int i=0; i < Str::len(C->text); i++) {
		inchar32_t c = Str::get_at(C->text, i);
		switch (c) {
			case '&': WRITE("&amp;"); break;
			case '<': WRITE("&lt;"); break;
			case '>': WRITE("&gt;"); break;
			case '\n': WRITE("<br/>"); break;
			default: PUT(c); break;
		}
	}

@h HTML format methods.
That's it for the recursion. Now for some service functions attached to the
HTML format as method calls.

If an image name contains a slash of either persuasion, we consider it a
compound filename, and leave it alone. It's perhaps a reference to an image
stored on an external website.

If not, we take it as a reference to an image which should be in the web's
`Figures` directory, and we copy it into the weave accordingly.

=
void HTMLWeaving::notify_image(markdown_render *rdr, text_stream *image) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	if (Str::includes_character(image, '/')) return;
	if (Str::includes_character(image, '\\')) return;
	filename *F = Filenames::in(
		Pathnames::down(wv->weave_web->path_to_web, I"Figures"),
		image);
	asset_rule *R = Assets::simple_private_copy();
	Assets::include_asset(NULL, R, F, NULL, wv);
}

@ We veto the use of maths if no maths plugin is available (though it really
should be, in the standard Inweb distribution). If it is available, we allow
the maths, and make sure the plugin is included in the weave.

=
int HTMLWeaving::veto_mathematics(markdown_render *rdr, int displayed) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	text_stream *plugin_name = (wv)?(Patterns::get_mathematics_plugin(wv->weave_web, wv->pattern)):NULL;
	if (Str::len(plugin_name) == 0) return TRUE;
	Swarm::ensure_plugin(wv, plugin_name);
	return FALSE;
}

@ Return `TRUE` if we have rendered something (or chosen to silently eliminate
this gadget from the weave); or `FALSE` to refuse because the gadget is
incomprehensible to us.

=
int HTMLWeaving::render_gadget(markdown_render *rdr, OUTPUT_STREAM,
	int gadget, text_stream *text_operand, int w, int h, int mode, text_stream *path) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	switch (gadget) {
		case TEXT_AS_INWEBGADGET: {
			filename *F = Filenames::from_text_relative(wv->weave_web->path_to_web, path);
			if (TextFiles::exists(F) == FALSE) {
				WRITE_TO(STDERR, "warning: text file at '%S' not found\n", path);
			} else {
				TEMPORARY_TEXT(code)
				TextFiles::write_file_contents(code, F);
				while ((Str::get_last_char(code) == ' ') || 
						(Str::get_last_char(code) == '\t') || 
						(Str::get_last_char(code) == '\n')) Str::delete_last_character(code);
				MDRenderHTML::render_code_block(OUT, mode, rdr, code, text_operand);
				DISCARD_TEXT(code)
			}
			return TRUE;
		}
		case DOWNLOAD_INWEBGADGET:
			HTMLWeaving::render_download(OUT, wv, path, text_operand);
			return TRUE;
		case HTML_INWEBGADGET:
			HTMLWeaving::render_HTML_extract(OUT, wv, path);
			return TRUE;
		case VIDEO_INWEBGADGET:
			HTMLWeaving::render_HTML_player(OUT, wv, path, FALSE, w, h);
			return TRUE;
		case EMBED_INWEBGADGET:
 			HTMLWeaving::render_embedding(OUT, wv, path, text_operand, w, h);
			return TRUE;
		case AUDIO_INWEBGADGET:
			HTMLWeaving::render_HTML_player(OUT, wv, path, TRUE, 0, 0);
			return TRUE;
		default:
			return FALSE;
	}
}

@h Gadgetry.
Gadgets such as downloads or embedded videos can be rendered either through a
Markdown extension (which results in a call to `HTMLWeaving::render_gadget`)
or from the main weave tree recursion. We want them to look the same either way,
so we provide functions which each of the above routes can call.

=
void HTMLWeaving::render_download(OUTPUT_STREAM, weave_order *wv, text_stream *download_name,
	text_stream *filetype) {
	pathname *P = Pathnames::down(wv->weave_web->path_to_web, I"Downloads");
	filename *F = Filenames::in(P, download_name);
	filename *TF = Patterns::find_file_in_subdirectory(wv->weave_web, wv->pattern, I"Embedding",
		I"Download.html");
	if (TF == NULL) {
		WebErrors::issue_at(I"Downloads are not supported", wv->current_weave_line);
	} else {
		Swarm::ensure_plugin(wv, I"Downloads");
		asset_rule *R = Assets::simple_private_copy();
		pathname *TOP = Assets::include_asset(OUT, R, F, NULL, wv);
		if (TOP == NULL) TOP = Filenames::up(F);
		TEMPORARY_TEXT(url)
		TEMPORARY_TEXT(size)
		Pathnames::relative_URL(url, Filenames::up(wv->weave_to), TOP);
		WRITE_TO(url, "%S", Filenames::get_leafname(F));
		int N = Filenames::size(F);
		if (N > 0) @<Describe the file size@>
		else WebErrors::issue_at(I"Download file missing or empty",
				wv->current_weave_line);
		filename *D = Filenames::from_text(download_name);
		Bibliographic::set_datum(wv->weave_web, I"File Name",
			Filenames::get_leafname(D));
		Bibliographic::set_datum(wv->weave_web, I"File URL", url);
		Bibliographic::set_datum(wv->weave_web, I"File Details", size);
		Collater::collate(OUT, wv, TF);
		WRITE("\n");
		DISCARD_TEXT(url)
		DISCARD_TEXT(size)
	}
}

@<Describe the file size@> =
	WRITE_TO(size, " (");
	if (Str::len(filetype) > 0) WRITE_TO(size, "%S, ", filetype);
	int x = 0, y = 0;
	text_stream *unit = I" byte"; x = N; y = 0;
	if (N > 1) { unit = I" bytes"; }
	if (N >= 1024) { unit = I"kB"; x = 10*N/1024; y = x%10; x = x/10; }
	if (N >= 1024*1024) { unit = I"MB"; x = 10*N/1024/1024; y = x%10; x = x/10; }
	if (N >= 1024*1024*1024) { unit = I"GB"; x = 10*N/1024/1024/1024; y = x%10; x = x/10; }
	WRITE_TO(size, "%d", x);
	if (y > 0) WRITE_TO(size, ".%d", y);
	WRITE_TO(size, "%S", unit);
	WRITE_TO(size, ")");

@ We transcribe an HTML extract in the rawest way possible, as a binary, not even
a text file.

=
void HTMLWeaving::render_HTML_extract(OUTPUT_STREAM, weave_order *wv, text_stream *leafname) {
	filename *F = Filenames::in(
		Pathnames::down(wv->weave_web->path_to_web, I"HTML"), leafname);
	HTML_OPEN_WITH("div", "class=\"inweb-extract\"");
	FILE *B = BinaryFiles::try_to_open_for_reading(F);
	if (B == NULL) {
		WebErrors::issue_at(I"Unable to find this HTML extract", wv->current_weave_line);
	} else {
		while (TRUE) {
			int c = getc(B);
			if (c == EOF) break;
			PUT((inchar32_t) c);
		}
		BinaryFiles::close(B);
	}
	HTML_CLOSE("div");
	WRITE("\n");
}

void HTMLWeaving::render_HTML_player(OUTPUT_STREAM, weave_order *wv, text_stream *name, int audio, int w, int h) {
	text_stream *subdir = (audio)?I"Audio":I"Video";
	filename *F = Filenames::in(Pathnames::down(wv->weave_web->path_to_web, subdir), name);
	asset_rule *R = Assets::simple_private_copy();
	Assets::include_asset(OUT, R, F, NULL, wv);
	HTML_OPEN_WITH("p", "class=\"center-p\"");
	if (audio) {
		WRITE("<audio controls>\n");
		WRITE("<source src=\"%S\" type=\"audio/mpeg\">\n", name);
		WRITE("Your browser does not support the audio element.\n");
		WRITE("</audio>\n");
	} else {
		if ((w > 0) && (h > 0))
			WRITE("<video width=\"%d\" height=\"%d\" controls>", w, h);
		else if (w > 0)
			WRITE("<video width=\"%d\" controls>", w);
		else if (h > 0)
			WRITE("<video height=\"%d\" controls>", h);
		else
			WRITE("<video controls>");
		WRITE("<source src=\"%S\" type=\"video/mp4\">\n", name);
		WRITE("Your browser does not support the video tag.\n");
		WRITE("</video>\n");
	}
	HTML_CLOSE("p");
	WRITE("\n");
}
	
void HTMLWeaving::render_embedding(OUTPUT_STREAM, weave_order *wv, text_stream *ID,
	text_stream *service, int w, int h) {
	if (w == 0) w = 720;
	if (h == 0) h = 405;
	TEMPORARY_TEXT(CW)
	TEMPORARY_TEXT(CH)
	WRITE_TO(CW, "%d", w); WRITE_TO(CH, "%d", h);
	TEMPORARY_TEXT(embed_leaf)
	WRITE_TO(embed_leaf, "%S.html", service);
	filename *F = Patterns::find_file_in_subdirectory(wv->weave_web, wv->pattern, I"Embedding", embed_leaf);
	DISCARD_TEXT(embed_leaf)
	if (F == NULL) {
		WebErrors::issue_at(I"This is not a supported service", wv->current_weave_line);
	} else {
		Bibliographic::set_datum(wv->weave_web, I"Content ID", ID);
		Bibliographic::set_datum(wv->weave_web, I"Content Width", CW);
		Bibliographic::set_datum(wv->weave_web, I"Content Height", CH);
		HTML_OPEN_WITH("p", "class=\"center-p\"");
		Collater::collate(OUT, wv, F);
		HTML_CLOSE("p");
		WRITE("\n");
	}
	DISCARD_TEXT(CW)
	DISCARD_TEXT(CH)
}

int HTMLWeaving::render_ul_as_carousel(markdown_render *rdr, OUTPUT_STREAM, int mode,
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
		HTMLWeaving::render_carousel_top(OUT, wv, count, of, carousel_id, carousel_dots_id, mr.exp[0], positioning);
		int m = mode | LOOSE_MDRMODE;
		for (markdown_item *c = item->down->next; c; c = c->next) {
			MDRender::render_in_mode(OUT, rdr, c, m);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
		HTMLWeaving::render_carousel_bottom(OUT, wv, count, of, carousel_id, carousel_dots_id, mr.exp[0], positioning);
		DISCARD_TEXT(carousel_id)
		DISCARD_TEXT(carousel_dots_id)
		count++;
	}
	Regexp::dispose_of(&mr);
	return TRUE;
}
 
void HTMLWeaving::render_carousel_top(OUTPUT_STREAM, weave_order *wv, int slide_number, int slide_of,
	text_stream *carousel_id, text_stream *carousel_dots_id, text_stream *caption, int positioning) {
	int N = wv->carousel_number;
	Swarm::ensure_plugin(wv, I"Carousel");
	text_stream *slide_count_class = I"carousel-number";
	WRITE_TO(carousel_id, "carousel-no-%d", N);
	WRITE_TO(carousel_dots_id, "carousel-dots-no-%d", N);
	if (slide_number == 1) {
		WRITE("<div class=\"carousel-container\" id=\"%S\">\n", carousel_id);
	}
	WRITE("<div class=\"carousel-slide fading-slide\"");
	if (slide_number == 1) WRITE(" style=\"display: block;\"");
	else WRITE(" style=\"display: none;\"");
	WRITE(">\n");
	if (positioning > 0) @<Place caption here@>;
	WRITE("<div class=\"%S\">%d / %d</div>\n",
		slide_count_class, slide_number, slide_of);
	WRITE("<div class=\"carousel-content\">");
}

void HTMLWeaving::render_carousel_bottom(OUTPUT_STREAM, weave_order *wv, int slide_number, int slide_of,
	text_stream *carousel_id, text_stream *carousel_dots_id, text_stream *caption, int positioning) {
	WRITE("</div>\n");
	if (positioning <= 0) @<Place caption here@>;
	WRITE("</div>\n");
	if (slide_number == slide_of) {
		WRITE("<a class=\"carousel-prev-button\" ");
		WRITE("onclick=\"carouselMoveSlide(&quot;%S&quot;, &quot;%S&quot;, -1)\"",
			carousel_id, carousel_dots_id);
		WRITE(">&#10094;</a>\n");
		WRITE("<a class=\"carousel-next-button\" ");
		WRITE("onclick=\"carouselMoveSlide(&quot;%S&quot;, &quot;%S&quot;, 1)\"",
			carousel_id, carousel_dots_id);
		WRITE(">&#10095;</a>\n");
		WRITE("</div>\n");
		WRITE("<div class=\"carousel-dots-container\" id=\"%S\">\n", carousel_dots_id);
		for (int i=1; i<=slide_of; i++) {
			if (i == 1)
				WRITE("<span class=\"carousel-dot carousel-dot-active\" ");
			else
				WRITE("<span class=\"carousel-dot\" ");
			WRITE("onclick=\"carouselSetSlide(&quot;%S&quot;, &quot;%S&quot;, %d)\"",
				carousel_id, carousel_dots_id, i-1);
			WRITE("></span>\n");
		}
		WRITE("</div>\n");
		wv->carousel_number++;
	}
}

@<Place caption here@> =
	text_stream *caption_class = NULL;
	if ((Str::len(caption) == 0) || (positioning == 0)) caption_class = I"carousel-caption";
	else if (positioning > 0) caption_class = I"carousel-caption-above";
	else if (positioning < 0) caption_class = I"carousel-caption-below";
	if (Str::len(caption) > 0)
		WRITE("<div class=\"%S\">%S</div>\n", caption_class, caption);

@h Locale links.

=
void HTMLWeaving::locale(OUTPUT_STREAM, ls_paragraph *par1, ls_line *finer,
	ls_paragraph *par2, filename *weave_to, ls_colony *C, int distant) {
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, par1, finer, weave_to, C);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	if (distant) {
		if (par1->owning_unit->owning_section)
			WRITE("%S:", par1->owning_unit->owning_section->sect_range);
		else
			WRITE("external:");
	}
	if (LineLabels::labelled(finer)) HTML_OPEN_WITH("span", "class=\"linelabel\"");
	WRITE("%s%S",
		(Str::get_first_char(LiterateSource::par_ornament(par1)) == 'S')?"&#167;":"&para;",
		par1->paragraph_number);
	if (par2) WRITE("-%S", par2->paragraph_number);
	if (LineLabels::labelled(finer)) WRITE("&nbsp;%S", LineLabels::label_text(finer));
	if (LineLabels::labelled(finer)) HTML_CLOSE("span");
	HTML::end_link(OUT);
}

@h Syntax colouring.
Really just a small tweak here: we want to find any language-specific colour scheme
in order to get out CSS span class names right.

=
void HTMLWeaving::begin_colouring(markdown_render *rdr, text_stream *language_rendered,
	void **token, void **colours) {
	weave_order *wv = RETRIEVE_POINTER_weave_order(rdr->context);
	programming_language *pl = wv->weave_web->web_language;
	if (Str::len(language_rendered) > 0)
		pl = Languages::find(wv->weave_web, language_rendered);
	if (pl == NULL) {
		WRITE_TO(STDERR, "warning: no language definition for '%S'\n", language_rendered);
		if (Str::eq_insensitive(language_rendered, I"plain"))
			WRITE_TO(STDERR, "(note that 'plain' is not normally a language: use 'none' instead)\n");
		pl = Languages::find(wv->weave_web, I"None");
	}
	Painter::reset_syntax_colouring(pl);
	*token = (void *) pl;
	text_stream *prefix = language_rendered;
	TEMPORARY_TEXT(name)
	WRITE_TO(name, "%S-Colours", language_rendered);
	if (*colours) Swarm::ensure_colour_scheme(wv, name, language_rendered);
	if (*colours == NULL) {
		*colours = Assets::find_colour_scheme(wv->weave_web, wv->pattern, I"Colours", I"");
		prefix = NULL;
	}
	if (*colours == NULL) internal_error("no colour scheme available");
	DISCARD_TEXT(name)
}
