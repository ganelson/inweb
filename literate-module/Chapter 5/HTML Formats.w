[HTMLWeaving::] HTML Formats.

To provide for weaving into HTML and into EPUB books.

@h Creation.
ePub books are basically mini-websites, so they share the same renderer.

=
void HTMLWeaving::create(void) {
	@<Create HTML@>;
	@<Create ePub@>;
}

@<Create HTML@> =
	weave_format *wf = WeavingFormats::create_weave_format(I"HTML", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLWeaving::render);

@<Create ePub@> =
	weave_format *wf = WeavingFormats::create_weave_format(I"ePub", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLWeaving::render_EPUB);
	METHOD_ADD(wf, BEGIN_WEAVING_FOR_MTID, HTMLWeaving::begin_weaving_EPUB);
	METHOD_ADD(wf, END_WEAVING_FOR_MTID, HTMLWeaving::end_weaving_EPUB);

@h Rendering.
To keep track of what we're writing, we store the renderer state in an
instance of this:

=
classdef HTML_render_state {
	struct text_stream *OUT;
	struct filename *into_file;
	struct weave_order *wv;
	struct colour_scheme *colours;
	int EPUB_flag;
	int popup_counter;
	int slide_number;
	int slide_of;
	struct ls_paragraph *para_to_open;
	struct asset_rule *copy_rule;
} HTML_render_state;

@ The initial state is as follows:

=
HTML_render_state HTMLWeaving::initial_state(text_stream *OUT, weave_order *wv,
	int EPUB_mode, filename *into) {
	HTML_render_state hrs;
	hrs.OUT = OUT;
	hrs.into_file = into;
	hrs.wv = wv;
	hrs.EPUB_flag = EPUB_mode;
	hrs.popup_counter = 1;
	hrs.slide_number = -1;
	hrs.slide_of = -1;
	hrs.para_to_open = NULL;
	hrs.copy_rule = Assets::new_rule(NULL, I"", I"privately copy", NULL);

	Swarm::ensure_plugin(wv, I"Base");
	hrs.colours = Swarm::ensure_colour_scheme(wv, I"Colours", I"");

	wv->current_weave_file = into;
	wv->carousel_number = 1;

	return hrs;
}

@ So, then, here are the front-end method functions for rendering to HTML and
ePub respectively:

=
void HTMLWeaving::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	HTML::declare_as_HTML(OUT, FALSE);
	HTML_render_state hrs = HTMLWeaving::initial_state(OUT, C->wv, FALSE, C->wv->weave_to);
	Trees::traverse_from(tree->root, &HTMLWeaving::render_visit, (void *) &hrs, 0);
	HTML::completed(OUT);
	if (C->footnotes_present) {
		text_stream *fn_plugin_name = Patterns::get_footnotes_plugin(C->wv->weave_web, C->wv->pattern);
		if (Str::len(fn_plugin_name) > 0)
			Swarm::ensure_plugin(C->wv, fn_plugin_name);
	}
}
void HTMLWeaving::render_EPUB(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	HTML::declare_as_HTML(OUT, TRUE);
	HTML_render_state hrs = HTMLWeaving::initial_state(OUT, C->wv, TRUE, C->wv->weave_to);
	Trees::traverse_from(tree->root, &HTMLWeaving::render_visit, (void *) &hrs, 0);
	Epub::note_page(WeavingDetails::get_as_ebook(C->wv->weave_web), C->wv->weave_to, C->wv->booklet_title, I"");
	HTML::completed(OUT);
}

@ And in either case, we traverse the weave tree with the following visitor function.

=
int HTMLWeaving::render_visit(tree_node *N, void *state, int L) {
	HTML_render_state *hrs = (HTML_render_state *) state;
	text_stream *OUT = hrs->OUT;
	if ((N->type == weave_document_node_type) ||
		(N->type == weave_body_node_type) ||
		(N->type == weave_chapter_header_node_type) ||
		(N->type == weave_chapter_footer_node_type) ||
		(N->type == weave_pagebreak_node_type) ||
		(N->type == weave_chapter_node_type) ||
		(N->type == weave_chapter_title_page_node_type) ||
		(N->type == weave_grammar_index_node_type)) @<Render nothing@>

	else if (N->type == weave_head_node_type) @<Render head@>
	else if (N->type == weave_tail_node_type) @<Render tail@>
	else if (N->type == weave_verbatim_node_type) @<Render verbatim@>
	else if (N->type == weave_section_header_node_type) @<Render header@>
	else if (N->type == weave_section_footer_node_type) @<Render footer@>
	else if (N->type == weave_section_purpose_node_type) @<Render purpose@>
	else if (N->type == weave_subheading_node_type) @<Render subheading@>
	else if (N->type == weave_subsubheading_node_type) @<Render subsubheading@>
	else if (N->type == weave_bar_node_type) @<Render bar@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
	else if (N->type == weave_extract_node_type) @<Render extract@>
	else if (N->type == weave_audio_node_type) @<Render audio clip@>
	else if (N->type == weave_video_node_type) @<Render video clip@>
	else if (N->type == weave_download_node_type) @<Render download@>
	else if (N->type == weave_material_node_type) @<Render material@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_holon_usage_node_type) @<Render holon usage@>
	else if (N->type == weave_tangler_command_node_type) @<Render tangler command@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_section_node_type) @<Render section@>
	else if (N->type == weave_holon_declaration_node_type) @<Render holon declaration@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_commentary_node_type) @<Render commentary@>
	else if (N->type == weave_carousel_slide_node_type) @<Render carousel slide@>
	else if (N->type == weave_toc_node_type) @<Render toc@>
	else if (N->type == weave_toc_line_node_type) @<Render toc line@>
	else if (N->type == weave_defn_node_type) @<Render defn@>
	else if (N->type == weave_source_code_node_type) @<Render source code@>
	else if (N->type == weave_comment_in_holon_node_type) @<Render comment in holon@>
	else if (N->type == weave_url_node_type) @<Render URL@>
	else if (N->type == weave_footnote_cue_node_type) @<Render footnote cue@>
	else if (N->type == weave_begin_footnote_text_node_type) @<Render footnote@>
	else if (N->type == weave_display_line_node_type) @<Render display line@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_item_node_type) @<Render item@>
	else if (N->type == weave_inline_node_type) @<Render inline@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_maths_node_type) @<Render maths@>
	else if (N->type == weave_markdown_node_type) @<Render Markdown@>
	else if (N->type == weave_linebreak_node_type) @<Render linebreak@>
	else if (N->type == weave_index_marker_node_type) @<Render index@>

	else {
		WRITE_TO(STDERR, "errant node type: %S\n", N->type->node_type_name);
		internal_error("unable to render unknown node");
	}
	return TRUE;
}

@<Render head@> =
	weave_head_node *C = RETRIEVE_POINTER_weave_head_node(N->content);
	HTML::comment(OUT, C->banner);

@<Render header@> =
	if (hrs->EPUB_flag == FALSE) {
		weave_section_header_node *C =
			RETRIEVE_POINTER_weave_section_header_node(N->content);
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
	}

@<Render footer@> =
	weave_section_footer_node *C =
		RETRIEVE_POINTER_weave_section_footer_node(N->content);
	int count = 0;
	ls_chapter *Ch;
	ls_section *next_S = NULL, *prev_S = NULL, *last = NULL;
	LOOP_OVER_LINKED_LIST(Ch, ls_chapter, hrs->wv->weave_web->chapters) {
		if (Ch->imported == FALSE) {
			ls_section *S;
			LOOP_OVER_LINKED_LIST(S, ls_section, Ch->sections) {
				count ++;
				if (S == C->sect) prev_S = last;
				if (last == C->sect) next_S = S;
				last = S;
			}
		}
	}
	if (count >= 2) {
		HTML_OPEN_WITH("nav", "role=\"progress\"");
		HTML_OPEN_WITH("div", "class=\"progresscontainer\"");
		HTML_OPEN_WITH("ul", "class=\"progressbar\"");
		@<Insert previous arrow@>;
		ls_chapter *Ch;
		LOOP_OVER_LINKED_LIST(Ch, ls_chapter, hrs->wv->weave_web->chapters) {
			if (Ch->imported == FALSE) {
				if (Str::ne(Ch->ch_range, I"S")) {
					if (Ch == C->sect->owning_chapter) {
						HTML_OPEN_WITH("li", "class=\"progresscurrentchapter\"");
					} else {
						HTML_OPEN_WITH("li", "class=\"progresschapter\"");
					}
					ls_section *S = FIRST_IN_LINKED_LIST(ls_section, Ch->sections);
					if (S) {
						TEMPORARY_TEXT(TEMP)
						Colonies::section_URL(TEMP, S);
						if (Ch != C->sect->owning_chapter) {
							HTML::begin_link(OUT, TEMP);
						}
						WRITE("%S", Ch->ch_range);
						if (Ch != C->sect->owning_chapter) {
							HTML::end_link(OUT);
						}
						DISCARD_TEXT(TEMP)
					}
					HTML_CLOSE("li");
				}
				if (Ch == C->sect->owning_chapter) {
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
						if (Conventions::get_int(hrs->wv->weave_web, SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION))
							Str::delete_first_character(label);
						if (S == C->sect) {
							HTML_OPEN_WITH("li", "class=\"progresscurrent\"");
							WRITE("%S", label);
							HTML_CLOSE("li");
						} else {
							HTML_OPEN_WITH("li", "class=\"progresssection\"");
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
				}
			}
		}
		@<Insert next arrow@>;
		HTML_CLOSE("ul");
		HTML_CLOSE("div");
		HTML_CLOSE("nav");
	}

@<Insert previous arrow@> =
	if (prev_S) HTML_OPEN_WITH("li", "class=\"progressprev\"")
	else HTML_OPEN_WITH("li", "class=\"progressprevoff\"");
	TEMPORARY_TEXT(TEMP)
	if (prev_S) Colonies::section_URL(TEMP, prev_S);
	if (prev_S) HTML::begin_link(OUT, TEMP);
	WRITE("&#10094;");
	if (prev_S) HTML::end_link(OUT);
	DISCARD_TEXT(TEMP)
	HTML_CLOSE("li");

@<Insert next arrow@> =
	if (next_S) HTML_OPEN_WITH("li", "class=\"progressnext\"")
	else HTML_OPEN_WITH("li", "class=\"progressnextoff\"");
	TEMPORARY_TEXT(TEMP)
	if (next_S) Colonies::section_URL(TEMP, next_S);
	if (next_S) HTML::begin_link(OUT, TEMP);
	WRITE("&#10095;");
	if (next_S) HTML::end_link(OUT);
	DISCARD_TEXT(TEMP)
	HTML_CLOSE("li");

@<Render tail@> =
	weave_tail_node *C = RETRIEVE_POINTER_weave_tail_node(N->content);
	HTML::comment(OUT, C->rennab);

@<Render purpose@> =
	weave_section_purpose_node *C =
		RETRIEVE_POINTER_weave_section_purpose_node(N->content);
	HTML_OPEN_WITH("p", "class=\"purpose\"");
	HTMLWeaving::escape_text(OUT, C->purpose);
	HTML_CLOSE("p"); WRITE("\n");

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	HTML_OPEN("h3");
	HTMLWeaving::escape_text(OUT, C->text);
	HTML_CLOSE("h3"); WRITE("\n");

@<Render subsubheading@> =
	weave_subsubheading_node *C = RETRIEVE_POINTER_weave_subsubheading_node(N->content);
	HTML_OPEN("h4");
	HTMLWeaving::escape_text(OUT, C->text);
	HTML_CLOSE("h4"); WRITE("\n");

@<Render bar@> =
	HTML::hr(OUT, NULL);

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C =
		RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	if (C->para == NULL) internal_error("no para");
	if (N->child == NULL) {
		ls_paragraph *first_in_para = C->para;
		@<If no para number yet, render a p just to hold this@>;
	}

@<Render endnote@> =
	HTML_OPEN("li");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("li");
	return FALSE;

@<Render figure@> =
	weave_figure_node *C = RETRIEVE_POINTER_weave_figure_node(N->content);
	filename *F = Filenames::in(
		Pathnames::down(hrs->wv->weave_web->path_to_web, I"Figures"),
		C->figname);
	filename *RF = Filenames::from_text(C->figname);
	HTML_OPEN_WITH("p", "class=\"center-p\"");
	HTML::image_to_dimensions(OUT, RF, C->alt_text, C->w, C->h);
	Assets::include_asset(OUT, hrs->copy_rule, hrs->wv->weave_web, F, NULL,
		hrs->wv->pattern, hrs->wv->weave_to, hrs->wv->reportage, hrs->wv->weave_colony);
	HTML_CLOSE("p");
	WRITE("\n");

@<Render extract@> =
	weave_extract_node *C = RETRIEVE_POINTER_weave_extract_node(N->content);
	HTMLWeaving::render_HTML_extract(OUT, hrs->wv, C->extract);

@<Render audio clip@> =
	weave_audio_node *C = RETRIEVE_POINTER_weave_audio_node(N->content);
	HTMLWeaving::render_HTML_player(OUT, hrs->wv, C->audio_name, TRUE, 0, 0);

@<Render video clip@> =
	weave_video_node *C = RETRIEVE_POINTER_weave_video_node(N->content);
	HTMLWeaving::render_HTML_player(OUT, hrs->wv, C->video_name, FALSE, C->w, C->h);

@<Render download@> =
	weave_download_node *C = RETRIEVE_POINTER_weave_download_node(N->content);
	HTMLWeaving::render_download(OUT, hrs->wv, C->download_name, C->filetype, hrs->into_file);

@<Render material@> =
	weave_material_node *C = RETRIEVE_POINTER_weave_material_node(N->content);
	ls_paragraph *first_in_para = NULL;
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

@<If no para number yet, render a p just to hold this@> =
	if (first_in_para) {
		HTMLWeaving::paragraph_number(OUT, first_in_para);
		HTML_CLOSE("p"); WRITE("\n");
		first_in_para = NULL;
	} 

@<Deal with a commentary material node@> =
	int item_depth = 0;
	for (tree_node *M = N->child; M; M = M->next) {
		if (M->type == weave_item_node_type) {
			@<If no para number yet, render a p just to hold this@>;
			weave_item_node *C = RETRIEVE_POINTER_weave_item_node(M->content);
			HTMLWeaving::go_to_depth(hrs, item_depth, C->depth);
			item_depth = C->depth;
			Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);
			continue;
		}
		if (HTMLWeaving::interior_material(M)) @<Render a run of interior matter@>;
		@<If no para number yet, render a p just to hold this@>;
		if (item_depth > 0) {
			HTMLWeaving::go_to_depth(hrs, item_depth, 0);
			item_depth = 0;
		}
		if (M->type == weave_vskip_node_type) continue;
		Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);
	}
	if (item_depth > 0) {
		HTMLWeaving::go_to_depth(hrs, item_depth, 0);
		item_depth = 0;
	}

@<Render a run of interior matter@> =
	int closure_needed = TRUE;
	if (M->type != weave_markdown_node_type) {
		if (first_in_para) {
			HTMLWeaving::paragraph_number(OUT, first_in_para);
			first_in_para = NULL;
		} else {
			if (item_depth == 0) HTML_OPEN_WITH("p", "class=\"commentary\"");
		}
	} else {
		hrs->para_to_open = first_in_para;
		first_in_para = NULL; closure_needed = FALSE;
	}
	while (M) {
		Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);
		if (M->type != weave_markdown_node_type) closure_needed = TRUE;
		if ((M->next == NULL) || (HTMLWeaving::interior_material(M->next) == FALSE)) break;
		M = M->next;
	}
	if ((item_depth == 0) && (closure_needed)) { HTML_CLOSE("p"); WRITE("\n"); }
	continue;

@<Deal with a code material node@> =
	@<If no para number yet, render a p just to hold this@>;
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
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("pre"); WRITE("\n");
	if (Str::len(C->endnote) > 0) {
		HTML_OPEN_WITH("ul", "class=\"endnotetexts\"");
		HTML_OPEN("li");
		HTMLWeaving::escape_text(OUT, C->endnote);
		HTML_CLOSE("li");
		HTML_CLOSE("ul"); WRITE("\n");
	}

@<Deal with a footnotes material node@> =
	@<If no para number yet, render a p just to hold this@>;
	HTML_OPEN_WITH("ul", "class=\"footnotetexts\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("ul"); WRITE("\n");

@<Deal with a endnotes material node@> =
	@<If no para number yet, render a p just to hold this@>;
	HTML_OPEN_WITH("ul", "class=\"endnotetexts\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("ul"); WRITE("\n");

@<Deal with a macro material node@> =
	if (first_in_para) {
		HTMLWeaving::paragraph_number(OUT, first_in_para);
	} else {
		HTML_OPEN_WITH("p", "class=\"commentary\"");
	}
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("p"); WRITE("\n");

@<Deal with a definition material node@> =
	@<If no para number yet, render a p just to hold this@>;
	HTML_OPEN_WITH("pre", "class=\"definitions code-font\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("pre"); WRITE("\n");

@ This has to embed some Internet-sourced content. `service`
here is something like `YouTube` or `Soundcloud`, and `ID` is whatever code
that service uses to identify the video/audio in question.

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	HTMLWeaving::render_embedding(OUT, hrs->wv, C->ID, C->service, C->w, C->h, hrs->into_file);

@<Render holon usage@> =
	weave_holon_usage_node *C = RETRIEVE_POINTER_weave_holon_usage_node(N->content);
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	TEMPORARY_TEXT(url)
	Colonies::paragraph_URL(url, C->holon->corresponding_chunk->owner, hrs->wv->weave_to, hrs->wv->weave_colony);
	HTML::begin_link_with_class(OUT, I"named-paragraph-link", url);
	DISCARD_TEXT(url)
	HTML_OPEN_WITH("span", "class=\"named-paragraph\"");
	ls_holon *holon = C->holon;
	if (holon) {
		if (holon->holon_name_as_markdown) {
			HTML_OPEN_WITH("span", "class=\"mathjax_process\"");
			MDRenderer::render_extended(OUT, (void *) hrs->wv, holon->holon_name_as_markdown, C->variation, 0);
			HTML_CLOSE("span");
		} else
			HTMLWeaving::escape_text(OUT, holon->holon_name);
	}
	HTML_CLOSE("span");
	HTML_OPEN_WITH("span", "class=\"named-paragraph-number\"");
	HTMLWeaving::escape_text(OUT, C->holon->corresponding_chunk->owner->paragraph_number);
	HTML_CLOSE("span");
	HTML::end_link(OUT);
	HTML_CLOSE("span");

@<Render tangler command@> =
	weave_tangler_command_node *C = RETRIEVE_POINTER_weave_tangler_command_node(N->content);
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	HTML_OPEN_WITH("span", "class=\"named-paragraph\"");
	HTMLWeaving::escape_text(OUT, I"output from tangler command '");
	HTMLWeaving::escape_text(OUT, C->command);
	HTMLWeaving::escape_text(OUT, I"'");
	HTML_CLOSE("span");
	HTML_CLOSE("span");

@<Render vskip@> =
	WRITE("\n");

@<Render section@> =
	weave_section_node *C = RETRIEVE_POINTER_weave_section_node(N->content);
	LOG("It was %d\n", C->allocation_id);

@<Render code line@> =
	@<Recurse the renderer through children nodes@>;
	WRITE("\n");
	return FALSE;

@<Render function usage@> =
	weave_function_usage_node *C = RETRIEVE_POINTER_weave_function_usage_node(N->content);
	HTML::begin_link_with_class(OUT, I"function-link", C->url);
	HTMLWeaving::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
	WRITE("%S", C->fn->function_name);
	HTMLWeaving::change_colour(OUT, -1, hrs->colours);
	HTML::end_link(OUT);

@<Render commentary@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	if (C->in_code) HTMLWeaving::change_colour(OUT, COMMENT_COLOUR, hrs->colours);
	for (int i=0; i < Str::len(C->text); i++) {
		if (Str::get_at(C->text, i) == '&') WRITE("&amp;");
		else if (Str::get_at(C->text, i) == '<') WRITE("&lt;");
		else if (Str::get_at(C->text, i) == '>') WRITE("&gt;");
		else if ((i == 0) && (Str::get_at(C->text, i) == '-') &&
			(Str::get_at(C->text, i+1) == '-') &&
			((Str::get_at(C->text, i+2) == ' ') || (Str::get_at(C->text, i+2) == 0))) {
			WRITE("&mdash;"); i++;
		} else if ((Str::get_at(C->text, i) == ' ') && (Str::get_at(C->text, i+1) == '-') &&
			(Str::get_at(C->text, i+2) == '-') &&
			((Str::get_at(C->text, i+3) == ' ') || (Str::get_at(C->text, i+3) == '\n') ||
			(Str::get_at(C->text, i+3) == 0))) {
			WRITE(" &mdash;"); i+=2;
		} else PUT(Str::get_at(C->text, i));
	}
	if (C->in_code) HTMLWeaving::change_colour(OUT, -1, hrs->colours);

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	if (hrs->slide_number == -1) {
		hrs->slide_number = 1;
		hrs->slide_of = 0;
		for (tree_node *X = N; (X) && (X->type == N->type); X = X->next) hrs->slide_of++;
	} else {
		hrs->slide_number++;
		if (hrs->slide_number > hrs->slide_of) internal_error("miscounted slides");
	}
	TEMPORARY_TEXT(carousel_id)
	TEMPORARY_TEXT(carousel_dots_id)
	HTMLWeaving::render_carousel_top(OUT, hrs->wv, hrs->slide_number, hrs->slide_of, carousel_id, carousel_dots_id, C->caption, C->positioning);
	@<Recurse the renderer through children nodes@>;
	HTMLWeaving::render_carousel_bottom(OUT, hrs->wv, hrs->slide_number, hrs->slide_of, carousel_id, carousel_dots_id, C->caption, C->positioning);
	DISCARD_TEXT(carousel_id)
	DISCARD_TEXT(carousel_dots_id)
	if (hrs->slide_number == hrs->slide_of) {
		hrs->slide_number = -1;
		hrs->slide_of = -1;
	}
	return FALSE;

@<Render toc@> =
	HTML_OPEN_WITH("ul", "class=\"toc\"");
	for (tree_node *M = N->child; M; M = M->next) {
		HTML_OPEN("li");
		Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);
		HTML_CLOSE("li");
	}
	HTML_CLOSE("ul");
	HTML::hr(OUT, "tocbar");
	WRITE("\n");
	return FALSE;

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, C->para, hrs->wv->weave_to, hrs->wv->weave_colony);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	int depth = LiterateSource::par_depth(C->para);
	if (depth == -1) HTML_OPEN("b");
	if (depth > 0) HTML_OPEN("i");
	WRITE("%s%S", (Str::get_first_char(LiterateSource::par_ornament(C->para)) == 'S')?"&#167;":"&para;",
		C->para->paragraph_number);
	WRITE(". ");
	HTMLWeaving::escape_text(OUT, C->text2);
	if (depth > 0) HTML_CLOSE("i");
	if (depth == -1) HTML_CLOSE("b");
	HTML::end_link(OUT);

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

@<Render holon declaration@> =
	weave_holon_declaration_node *C = RETRIEVE_POINTER_weave_holon_declaration_node(N->content);
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	ls_holon *label_holon = C->holon;
	if (C->holon->addendum_to) {
		label_holon = C->holon->addendum_to;
		TEMPORARY_TEXT(url)
		Colonies::paragraph_URL(url, label_holon->corresponding_chunk->owner, hrs->wv->weave_to, hrs->wv->weave_colony);
		HTML::begin_link_with_class(OUT, I"named-paragraph-link", url);
		DISCARD_TEXT(url)
	}
	HTML_OPEN_WITH("span", "class=\"named-paragraph-defn\"");
	if (label_holon->file_form) { PUT(0x2192); PUT(0x0020); }
	if (label_holon->holon_name_as_markdown)
		MDRenderer::render_extended(OUT, (void *) hrs->wv, label_holon->holon_name_as_markdown, C->variation, 0);
	else
		HTMLWeaving::escape_text(OUT, label_holon->holon_name);
	HTML_CLOSE("span");
	HTML_OPEN_WITH("span", "class=\"named-paragraph-number\"");
	HTMLWeaving::escape_text(OUT, label_holon->corresponding_chunk->owner->paragraph_number);
	HTML_CLOSE("span");
	if (C->holon->addendum_to) HTML::end_link(OUT);
	HTML_CLOSE("span");
	if (C->holon->addendum_to) HTMLWeaving::escape_text(OUT, I" +=");
	else HTMLWeaving::escape_text(OUT, I" =");

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	HTMLWeaving::render_syntax_coloured(OUT, C->matter, C->colouring, hrs->colours);

@<Render comment in holon@> =
	weave_comment_in_holon_node *C = RETRIEVE_POINTER_weave_comment_in_holon_node(N->content);
	if (C->as_markdown) {
		HTML_OPEN_WITH("span", "class=\"comment-syntax\"");
		HTMLWeaving::escape_text(OUT, C->comment_open);
		for (int i=0; ((i<Str::len(C->raw)) && (Characters::is_whitespace(Str::get_at(C->raw, i)))); i++)
			PUT(Str::get_at(C->raw, i));
		MDRenderer::render_extended(OUT, (void *) hrs->wv, C->as_markdown, C->variation, 0);
		for (int i=Str::len(C->raw) - 1; ((i>=0) && (Characters::is_whitespace(Str::get_at(C->raw, i)))); i--)
			PUT(Str::get_at(C->raw, i));
		HTMLWeaving::escape_text(OUT, C->comment_close);
		HTML_CLOSE("span");
	} else
		WRITE("NO-MARKDOWN-AVAILABLE");

@<Render URL@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	HTML::begin_link_with_class(OUT, (C->external)?I"external":I"internal", C->url);
	WRITE("%S", C->content);
	HTML::end_link(OUT);

@<Render footnote cue@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	if (hrs->EPUB_flag) {
		if (N->parent->type != weave_begin_footnote_text_node_type)
			WRITE("<a id=\"fnref%S\"></a>", C->cue_text);
		WRITE("<sup><a href=\"#fn%S\" rel=\"footnote\">%S</a></sup>",
			C->cue_text, C->cue_text);
	} else
		WRITE("<sup id=\"fnref:%S\"><a href=\"#fn:%S\" rel=\"footnote\">%S</a></sup>",
			C->cue_text, C->cue_text, C->cue_text);

@<Render footnote@> =
	weave_begin_footnote_text_node *C =
		RETRIEVE_POINTER_weave_begin_footnote_text_node(N->content);
	if (hrs->EPUB_flag)
		WRITE("<li class=\"footnote\" id=\"fn%S\"><p class=\"inwebfootnote\">",
			C->cue_text);
	else
		WRITE("<li class=\"footnote\" id=\"fn:%S\"><p class=\"inwebfootnote\">",
			C->cue_text);
	@<Recurse the renderer through children nodes@>;
	if (hrs->EPUB_flag)
		WRITE("<a href=\"#fnref%S\"> (return to text)</a></p></li>",
			C->cue_text);
	else
		WRITE("<a href=\"#fnref:%S\" title=\"return to text\"> &#x21A9;</a></p></li>",
			C->cue_text);
	return FALSE;

@<Render display line@> =
	weave_display_line_node *C =
		RETRIEVE_POINTER_weave_display_line_node(N->content);
	HTML_OPEN("blockquote"); WRITE("\n"); INDENT;
	HTML_OPEN("p");
	HTMLWeaving::escape_text(OUT, C->text);
	HTML_CLOSE("p");
	OUTDENT; HTML_CLOSE("blockquote"); WRITE("\n");

@<Render function defn@> =
	weave_function_defn_node *C =
		RETRIEVE_POINTER_weave_function_defn_node(N->content);
	if ((Functions::used_elsewhere(C->fn)) && (hrs->EPUB_flag == FALSE)) {
		Swarm::ensure_plugin(hrs->wv, I"Popups");
		HTMLWeaving::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
		WRITE("%S", C->fn->function_name);
		WRITE("</span>");
		WRITE("<button class=\"popup\" onclick=\"togglePopup('usagePopup%d')\">",
			hrs->popup_counter);
		HTMLWeaving::change_colour(OUT, COMMENT_COLOUR, hrs->colours);
		WRITE("?");
		HTMLWeaving::change_colour(OUT, -1, hrs->colours);
		WRITE("<span class=\"popuptext\" id=\"usagePopup%d\">Usage of ", hrs->popup_counter);
		HTML_OPEN_WITH("span", "class=\"code-font\"");
		HTMLWeaving::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
		WRITE("%S", C->fn->function_name);
		HTMLWeaving::change_colour(OUT, -1, hrs->colours);
		HTML_CLOSE("span");
		WRITE(":<br/>"); 
		@<Recurse the renderer through children nodes@>;
		HTMLWeaving::change_colour(OUT, -1, hrs->colours);
		WRITE("</button>");
		hrs->popup_counter++;
	} else {
		HTMLWeaving::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
		WRITE("%S", C->fn->function_name);
		HTMLWeaving::change_colour(OUT, -1, hrs->colours);
	}
	return FALSE;

@<Render item@> =
	weave_item_node *C = RETRIEVE_POINTER_weave_item_node(N->content);
	if (Str::eq(C->label, I"*")) WRITE("&#9679; ");
	else if (Str::len(C->label) > 0) WRITE("(%S) ", C->label);
	else WRITE(" ");

@<Render verbatim@> =
	weave_verbatim_node *C = RETRIEVE_POINTER_weave_verbatim_node(N->content);
	WRITE("%S", C->content);

@<Render inline@> =
	HTML_OPEN_WITH("span", "class=\"extract\"");
	@<Recurse the renderer through children nodes@>;
	HTML_CLOSE("span");
	return FALSE;

@<Render locale@> =
	weave_locale_node *C = RETRIEVE_POINTER_weave_locale_node(N->content);
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, C->par1, hrs->wv->weave_to, hrs->wv->weave_colony);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	if (C->distant) {
		if (C->par1->owning_unit->owning_section)
			WRITE("%S:", C->par1->owning_unit->owning_section->sect_range);
		else
			WRITE("external:");
	}
	WRITE("%s%S",
		(Str::get_first_char(LiterateSource::par_ornament(C->par1)) == 'S')?"&#167;":"&para;",
		C->par1->paragraph_number);
	if (C->par2) WRITE("-%S", C->par2->paragraph_number);
	HTML::end_link(OUT);

@<Render maths@> =
	weave_maths_node *C = RETRIEVE_POINTER_weave_maths_node(N->content);
	HTMLWeaving::render_maths(OUT, hrs->wv, C->content, hrs->EPUB_flag, C->displayed);

@<Render Markdown@> =
	ls_paragraph *first_in_para = NULL;
	if ((N == N->parent->child) &&
		(N->parent->type == weave_paragraph_heading_node_type)) {
		weave_paragraph_heading_node *PC =
			RETRIEVE_POINTER_weave_paragraph_heading_node(N->parent->content);
		first_in_para = PC->para;
	}
	HTML_OPEN_WITH("div", "class=\"lsmarkdown\"");
	OUTDENT;
	int mode = 0;
	weave_markdown_node *C = RETRIEVE_POINTER_weave_markdown_node(N->content);
	if ((first_in_para) || (hrs->para_to_open)) {
		if (hrs->para_to_open) HTMLWeaving::paragraph_number(OUT, hrs->para_to_open);
		else HTMLWeaving::paragraph_number(OUT, first_in_para);
		hrs->para_to_open = NULL;
		if ((C->content) && (C->content->down) && (C->content->down->type == PARAGRAPH_MIT)) {
			mode = EXISTING_PAR_MDRMODE;
			WRITE(" ");
		} else {
			HTML_CLOSE("p");
		}
	}
	MDRenderer::render_extended(OUT, (void *) hrs->wv, C->content, C->variation, mode);
	INDENT;
	HTML_CLOSE("div");

@<Render linebreak@> =
	WRITE("<br/>");

@<Render index@> =
	HTML_OPEN_WITH("div", "class=\"lsindex\"");
	if ((hrs->wv) && (hrs->wv->weave_web)) {
		ls_index *index = hrs->wv->weave_web->index;
		if (index->lemmas_sorted == NULL) WebIndexing::sort(index, I"0");
		if (index->lemmas_sorted)
			for (int i=0; i<(int) (index->no_lemmas_sorted); i++) {
				ls_index_lemma *lemma = index->lemmas_sorted[i];
				int d = 0;
				for (ls_index_lemma *l2 = lemma->parent; l2; l2 = l2->parent) d++;
				text_stream *pclass = I"lsindexlemma";
				if (d == 1) pclass = I"lsindexsublemma";
				if (d == 2) pclass = I"lsindexsubsublemma";
				if (d >= 3) pclass = I"lsindexsubsubsublemma";
				HTML_OPEN_WITH("p", "class=\"%S\"", pclass);
				switch (lemma->style) {
					case 1: HTML_OPEN_WITH("span", "class=\"lsindextext\""); break;
					case 2: HTML_OPEN_WITH("span", "class=\"lsindextexttt\""); break;
					case 3: HTML_OPEN_WITH("span", "class=\"lsindextextns\""); break;
				}
				HTMLWeaving::escape_text(OUT, lemma->text);
				HTML_CLOSE("span");
				ls_index_mark *mark; int c = 0;
				LOOP_OVER_LINKED_LIST(mark, ls_index_mark, lemma->marks) {
					if (c++ > 0) WRITE(", "); else WRITE("&nbsp;&nbsp;");
					if (mark->important) HTML_OPEN("b");
					HTMLWeaving::escape_text(OUT, mark->at->paragraph_number);
					if (mark->important) HTML_CLOSE("b");
				}
				HTML_CLOSE("p");
			}
	}
	HTML_CLOSE("div");

@<Render nothing@> =
	;

@<Recurse the renderer through children nodes@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLWeaving::render_visit, (void *) hrs, L+1);

@ This is convenient when rendering out Markdown which contains images:

=
void HTMLWeaving::notify_image(weave_order *wv, text_stream *image) {
	if (Str::includes_character(image, '/')) return;
	if (Str::includes_character(image, '\\')) return;
	filename *F = Filenames::in(
		Pathnames::down(wv->weave_web->path_to_web, I"Figures"),
		image);
	Assets::include_asset(NULL, Assets::new_rule(NULL, I"", I"privately copy", NULL),
		wv->weave_web, F, NULL,
		wv->pattern, wv->weave_to, wv->reportage, wv->weave_colony);
}

@ The necessary escapes for the use of the MathJax plugin.

=
void HTMLWeaving::render_maths(OUTPUT_STREAM, weave_order *wv, text_stream *content,
	int plain, int displayed) {
	text_stream *plugin_name = (wv)?(Patterns::get_mathematics_plugin(wv->weave_web, wv->pattern)):NULL;
	if ((Str::len(plugin_name) == 0) || (plain)) {
		TEMPORARY_TEXT(R)
		TeXUtilities::remove_math_mode(R, content);
		HTMLWeaving::escape_text(OUT, R);
		DISCARD_TEXT(R)
	} else {
		Swarm::ensure_plugin(wv, plugin_name);
		if (displayed) WRITE("$$"); else WRITE("\\INWEBMATH(");
		TEMPORARY_TEXT(escaped)
		HTMLWeaving::escape_text(escaped, content);
		for (int i=0; i<Str::len(escaped); i++) {
			if (Str::get_at(escaped, i) == '|') {
				int found = FALSE;
				for (int j=i+1; j<Str::len(escaped); j++) {
					if (Str::get_at(escaped, j) == '|') {
						WRITE("\\hbox{\\tt ");
						for (int k=i+1; k<j; k++) PUT(Str::get_at(escaped, k));
						WRITE("}");
						i = j;
						found = TRUE; break;
					}
				}
				if (found == FALSE) PUT(Str::get_at(escaped, i));
			} else {
				PUT(Str::get_at(escaped, i));
			}
		}
		DISCARD_TEXT(escaped)
		if (displayed) WRITE("$$"); else WRITE("\\INWEBMATH)");
	}
}

@ These are the nodes falling under a commentary material node which we will
amalgamate into a single HTML paragraph:

=
int HTMLWeaving::interior_material(tree_node *N) {
	if (N->type == weave_commentary_node_type) return TRUE;
	if (N->type == weave_markdown_node_type) return TRUE;
	if (N->type == weave_url_node_type) return TRUE;
	if (N->type == weave_inline_node_type) return TRUE;
	if (N->type == weave_locale_node_type) return TRUE;
	if (N->type == weave_maths_node_type) return TRUE;
	if (N->type == weave_footnote_cue_node_type) return TRUE;
	return FALSE;
}

@ Depth 1 means "inside a list entry"; depth 2, "inside an entry of a list
which is itself inside a list entry"; and so on.

=
void HTMLWeaving::go_to_depth(HTML_render_state *hrs, int from_depth, int to_depth) {
	text_stream *OUT = hrs->OUT;
	if (from_depth == to_depth) {
		HTML_CLOSE("li");
	} else {
		while (from_depth < to_depth) {
			HTML_OPEN_WITH("ul", "class=\"items\""); from_depth++;
		}
		while (from_depth > to_depth) {
			HTML_CLOSE("li");
			HTML_CLOSE("ul");
			WRITE("\n"); from_depth--;
		}
	}
	if (to_depth > 0) HTML_OPEN("li");
}

@ =
void HTMLWeaving::paragraph_number(text_stream *OUT, ls_paragraph *par) {
	text_stream *title = LiterateSource::par_title(par);
	int depth = LiterateSource::par_depth(par);
	if (depth == -1) {
		HTML_OPEN("h2");
		HTMLWeaving::escape_text(OUT, title);
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
		HTMLWeaving::escape_text(OUT, title);
		if (Str::len(title) > 0) WRITE(".");
		HTML_CLOSE("b");
		WRITE(" ");
	}
}

@ =
void HTMLWeaving::change_colour(text_stream *OUT, int col, colour_scheme *cs) {
	if (col == -1) {
		HTML_CLOSE("span");
	} else {
		text_stream *cl = Painter::colour_classname(NULL, (inchar32_t) col);
		if (Str::len(cl) == 0) {
			PRINT("col: %d\n", col); internal_error("bad colour");
		} else {
			HTML_OPEN_WITH("span", "class=\"%S%S\"", cs->prefix, cl);
		}
	}
}

@ =
void HTMLWeaving::escape_text(text_stream *OUT, text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
		if (Str::get_at(id, i) == '&') WRITE("&amp;");
		else if (Str::get_at(id, i) == '<') WRITE("&lt;");
		else if (Str::get_at(id, i) == '>') WRITE("&gt;");
		else PUT(Str::get_at(id, i));
	}
}

@

=
void HTMLWeaving::render_code_block(OUTPUT_STREAM, int mode, weave_order *wv, text_stream *code, text_stream *language_rendered) {
	TEMPORARY_TEXT(name)
	WRITE_TO(name, "%S-Colours", language_rendered);
	colour_scheme *colours = Assets::find_colour_scheme(wv->weave_web, wv->pattern,
		name, language_rendered);
	text_stream *prefix = language_rendered;
	if (colours) Swarm::ensure_colour_scheme(wv, name, language_rendered);
	if (colours == NULL) {
		colours = Assets::find_colour_scheme(wv->weave_web, wv->pattern, I"Colours", I"");
		prefix = NULL;
	}
	if (colours == NULL) internal_error("no colour scheme available");
	DISCARD_TEXT(name)

	if (Str::len(prefix) > 0) {
		if (mode & TAGS_MDRMODE)
			HTML_OPEN_WITH("pre", "class=\"%S-displayed-code all-displayed-code code-font\"",
				prefix);
	} else {
		if (mode & TAGS_MDRMODE)
			HTML_OPEN_WITH("pre", "class=\"displayed-code all-displayed-code code-font\"");
	}

	TEMPORARY_TEXT(colouring)
	programming_language *pl = wv->weave_web->web_language;
	if (Str::len(language_rendered) > 0)
		pl = Languages::find(wv->weave_web, language_rendered);
	if (pl == NULL) {
		WRITE_TO(STDERR, "warning: no language definition for '%S'\n", language_rendered);
		pl = Languages::find(wv->weave_web, I"None");
	}
	Painter::reset_syntax_colouring(pl);
	TEMPORARY_TEXT(line)
	TEMPORARY_TEXT(cols)
	int i = 0;
	while (i < Str::len(code)) {
		inchar32_t c = Str::get_at(code, i);
		if ((c == '\n') || (i+1 == Str::len(code))) {
			if (c != '\n') PUT_TO(line, c);
			Painter::syntax_colour(pl, &(pl->built_in_keywords), line, cols, FALSE, TRUE);
			Str::clear(line);
			WRITE_TO(colouring, "%S%c", cols, PLAIN_COLOUR);
			Str::clear(cols);
		} else {
			PUT_TO(line, c);
		}
		i++;
	}
	DISCARD_TEXT(line)
	DISCARD_TEXT(cols)
	HTMLWeaving::render_syntax_coloured(OUT, code, colouring, colours);
	DISCARD_TEXT(colouring)
	if (mode & TAGS_MDRMODE) HTML_CLOSE("pre");
	WRITE("\n");
}

void HTMLWeaving::render_syntax_coloured(OUTPUT_STREAM, text_stream *code,
	text_stream *colouring, colour_scheme *colours) {
	int current_colour = -1, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(code); i++) {
		colour_wanted = (int) Str::get_at(colouring, i);
		if (colour_wanted != current_colour) {
			if (current_colour >= 0) HTML_CLOSE("span");
			HTMLWeaving::change_colour(OUT, colour_wanted, colours);
			current_colour = colour_wanted;
		}
		if (Str::get_at(code, i) == '<') WRITE("&lt;");
		else if (Str::get_at(code, i) == '>') WRITE("&gt;");
		else if (Str::get_at(code, i) == '&') WRITE("&amp;");
		else WRITE("%c", Str::get_at(code, i));
	}
	if (current_colour >= 0) HTMLWeaving::change_colour(OUT, -1, colours);
}

int HTMLWeaving::render_text_as_image(OUTPUT_STREAM, int mode, weave_order *wv,
	text_stream *desc, text_stream *path) {
	match_results mr = Regexp::create_mr();
	text_stream *as = NULL;
	if (Regexp::match(&mr, desc, U"text as (%c+)")) as = mr.exp[0];
	if (Str::eq(desc, I"text")) as = I"None";
	if (as) {
		filename *F = Filenames::from_text_relative(wv->weave_web->path_to_web, path);
		if (TextFiles::exists(F) == FALSE) {
			WRITE_TO(STDERR, "warning: text file at '%S' not found\n", path);
		} else {
			TEMPORARY_TEXT(code)
			TextFiles::write_file_contents(code, F);
			while ((Str::get_last_char(code) == ' ') || 
					(Str::get_last_char(code) == '\t') || 
					(Str::get_last_char(code) == '\n')) Str::delete_last_character(code);
			HTMLWeaving::render_code_block(OUT, mode, wv, code, as);
			DISCARD_TEXT(code)
		}
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, desc, U"download: (%c+)")) {
		HTMLWeaving::render_download(OUT, wv, path, mr.exp[0], wv->current_weave_file);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Str::eq_insensitive(desc, I"HTML")) {
		HTMLWeaving::render_HTML_extract(OUT, wv, path);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Str::eq(desc, I"video")) {
		HTMLWeaving::render_HTML_player(OUT, wv, path, FALSE, 0, 0);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, desc, U"video at (%d+) by (%d+)")) {
		int w = Str::atoi(mr.exp[0], 0), h = Str::atoi(mr.exp[1], 0);
		HTMLWeaving::render_HTML_player(OUT, wv, path, FALSE, w, h);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, desc, U"video at width (%d+)")) {
		int w = Str::atoi(mr.exp[0], 0);
		HTMLWeaving::render_HTML_player(OUT, wv, path, FALSE, w, 0);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Regexp::match(&mr, desc, U"video at height (%d+)")) {
		int h = Str::atoi(mr.exp[0], 0);
		HTMLWeaving::render_HTML_player(OUT, wv, path, FALSE, 0, h);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if ((Regexp::match(&mr, desc, U"embedded (%c+) audio")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video"))) {
 		HTMLWeaving::render_embedding(OUT, wv, path, mr.exp[0], 0, 0, wv->current_weave_file);
 		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if ((Regexp::match(&mr, desc, U"embedded (%c+) audio at (%d+) by (%d+)")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video at (%d+) by (%d+)"))) {
		int w = Str::atoi(mr.exp[1], 0), h = Str::atoi(mr.exp[2], 0);
 		HTMLWeaving::render_embedding(OUT, wv, path, mr.exp[0], w, h, wv->current_weave_file);
 		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if ((Regexp::match(&mr, desc, U"embedded (%c+) audio at height (%d+)")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video at height (%d+)"))) {
		int w = 0, h = Str::atoi(mr.exp[1], 0);
 		HTMLWeaving::render_embedding(OUT, wv, path, mr.exp[0], w, h, wv->current_weave_file);
 		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if ((Regexp::match(&mr, desc, U"embedded (%c+) audio at width (%d+)")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video at width (%d+)"))) {
		int w = Str::atoi(mr.exp[1], 0), h = 0;
 		HTMLWeaving::render_embedding(OUT, wv, path, mr.exp[0], w, h, wv->current_weave_file);
 		Regexp::dispose_of(&mr);
		return TRUE;
	}
	if (Str::eq(desc, I"audio")) {
		HTMLWeaving::render_HTML_player(OUT, wv, path, TRUE, 0, 0);
		Regexp::dispose_of(&mr);
		return TRUE;
	}
	Regexp::dispose_of(&mr);
	return FALSE;
}

void HTMLWeaving::render_download(OUTPUT_STREAM, weave_order *wv, text_stream *download_name,
	text_stream *filetype, filename *into_file) {
	pathname *P = Pathnames::down(wv->weave_web->path_to_web, I"Downloads");
	filename *F = Filenames::in(P, download_name);
	filename *TF = Patterns::find_file_in_subdirectory(wv->weave_web, wv->pattern, I"Embedding",
		I"Download.html");
	if (TF == NULL) {
		WebErrors::issue_at(I"Downloads are not supported", wv->current_weave_line);
	} else {
		Swarm::ensure_plugin(wv, I"Downloads");
		asset_rule *R = Assets::new_rule(NULL, I"", I"privately copy", NULL);
		pathname *TOP =
			Assets::include_asset(OUT, R, wv->weave_web, F, NULL,
				wv->pattern, wv->weave_to, wv->reportage, wv->weave_colony);
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
		Collater::for_web_and_pattern(OUT, wv->weave_web, wv->pattern,
			TF, into_file, wv->weave_colony, wv->reportage);
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

@ =
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
	asset_rule *R = Assets::new_rule(NULL, I"", I"privately copy", NULL);
	Assets::include_asset(OUT, R, wv->weave_web, F, NULL,
		wv->pattern, wv->weave_to, wv->reportage, wv->weave_colony);
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
	text_stream *service, int w, int h, filename *into_file) {
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
		Collater::for_web_and_pattern(OUT, wv->weave_web, wv->pattern,
			F, into_file, wv->weave_colony, wv->reportage);
		HTML_CLOSE("p");
		WRITE("\n");
	}
	DISCARD_TEXT(CW)
	DISCARD_TEXT(CH)
}

int HTMLWeaving::caption(match_results *mr, markdown_item *item, int *pos) {
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel%)"))) {
		if (pos) *pos = 0;
		return TRUE;
	}
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel \"(%c+)\"%)"))) {
		if (pos) *pos = 0;
		return TRUE;
	}
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel \"(%c+)\" captioned below%)"))) {
		if (pos) *pos = -1;
		return TRUE;
	}
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel \"(%c+)\" captioned above%)"))) {
		if (pos) *pos = 1;
		return TRUE;
	}
	return FALSE;
}

int HTMLWeaving::render_ul_as_carousel(OUTPUT_STREAM, int mode, weave_order *wv,
	markdown_item *md, markdown_variation *variation) {
	match_results mr = Regexp::create_mr();
	int not = FALSE, of = 0;
	for (markdown_item *item = md->down; item; item = item->next) {
		if (HTMLWeaving::caption(&mr, item, NULL) == FALSE) {
			not = TRUE;
			break;
		}
		of++;
	}
	if (not) {
		Regexp::dispose_of(&mr);
		return FALSE;
	}
	
	int count = 1;
	for (markdown_item *item = md->down; item; item = item->next) {
		int positioning = 0;
		HTMLWeaving::caption(&mr, item, &positioning);
		TEMPORARY_TEXT(carousel_id)
		TEMPORARY_TEXT(carousel_dots_id)
		HTMLWeaving::render_carousel_top(OUT, wv, count, of, carousel_id, carousel_dots_id, mr.exp[0], positioning);
		int m = mode | LOOSE_MDRMODE;
		for (markdown_item *c = item->down->next; c; c = c->next) {
			MDRenderer::recurse(OUT, (void *) wv, c, m, variation);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
		HTMLWeaving::render_carousel_bottom(OUT, wv, count, of, carousel_id, carousel_dots_id, mr.exp[0], positioning);
		DISCARD_TEXT(carousel_id)
		DISCARD_TEXT(carousel_dots_id)
		count++;
	}
	return TRUE;
}
 
void HTMLWeaving::render_carousel_top(OUTPUT_STREAM, weave_order *wv, int slide_number, int slide_of,
	text_stream *carousel_id, text_stream *carousel_dots_id, text_stream *caption, int positioning) {
	int N = wv->carousel_number;
	Swarm::ensure_plugin(wv, I"Carousel");
	text_stream *caption_class = NULL;
	if ((Str::len(caption) == 0) || (positioning == 0)) caption_class = I"carousel-caption";
	else if (positioning > 0) caption_class = I"carousel-caption-above";
	else if (positioning < 0) caption_class = I"carousel-caption-below";
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
	text_stream *caption_class = NULL;
	if ((Str::len(caption) == 0) || (positioning == 0)) caption_class = I"carousel-caption";
	else if (positioning > 0) caption_class = I"carousel-caption-above";
	else if (positioning < 0) caption_class = I"carousel-caption-below";
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
	if (Str::len(caption) > 0)
		WRITE("<div class=\"%S\">%S</div>\n", caption_class, caption);

@h EPUB-only methods.

=
int HTMLWeaving::begin_weaving_EPUB(weave_format *wf, ls_web *W, ls_pattern *pattern) {
	TEMPORARY_TEXT(T)
	WRITE_TO(T, "%S", Bibliographic::get_datum(W, I"Title"));
	WeavingDetails::set_as_ebook(W, Epub::new(T, "P"));
	filename *CSS = Patterns::find_file_in_subdirectory(W, pattern, I"Base", I"Base.css");
	Epub::use_CSS_throughout(WeavingDetails::get_as_ebook(W), CSS);
	Epub::attach_metadata(WeavingDetails::get_as_ebook(W), U"identifier", T);
	DISCARD_TEXT(T)

	pathname *P = WebStructure::woven_folder(W, 2);
	WeavingDetails::set_redirect_weaves_to(W, Epub::begin_construction(WeavingDetails::get_as_ebook(W), P, NULL));
	Shell::copy(CSS, WeavingDetails::get_redirect_weaves_to(W), "");
	return SWARM_SECTIONS_SWM;
}

void HTMLWeaving::end_weaving_EPUB(weave_format *wf, ls_web *W, ls_pattern *pattern) {
	Epub::end_construction(WeavingDetails::get_as_ebook(W));
}
