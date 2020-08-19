[HTMLFormat::] HTML Formats.

To provide for weaving into HTML and into EPUB books.

@h Creation.
ePub books are basically mini-websites, so they share the same renderer.

=
void HTMLFormat::create(void) {
	@<Create HTML@>;
	@<Create ePub@>;
}

@<Create HTML@> =
	weave_format *wf = Formats::create_weave_format(I"HTML", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLFormat::render);

@<Create ePub@> =
	weave_format *wf = Formats::create_weave_format(I"ePub", I".html");
	METHOD_ADD(wf, RENDER_FOR_MTID, HTMLFormat::render_EPUB);
	METHOD_ADD(wf, BEGIN_WEAVING_FOR_MTID, HTMLFormat::begin_weaving_EPUB);
	METHOD_ADD(wf, END_WEAVING_FOR_MTID, HTMLFormat::end_weaving_EPUB);

@h Rendering.
To keep track of what we're writing, we store the renderer state in an
instance of this:

=
typedef struct HTML_render_state {
	struct text_stream *OUT;
	struct filename *into_file;
	struct weave_order *wv;
	struct colour_scheme *colours;
	int EPUB_flag;
	int popup_counter;
	int carousel_number;
	int slide_number;
	int slide_of;
	struct asset_rule *copy_rule;
} HTML_render_state;

@ The initial state is as follows:

=
HTML_render_state HTMLFormat::initial_state(text_stream *OUT, weave_order *wv,
	int EPUB_mode, filename *into) {
	HTML_render_state hrs;
	hrs.OUT = OUT;
	hrs.into_file = into;
	hrs.wv = wv;
	hrs.EPUB_flag = EPUB_mode;
	hrs.popup_counter = 1;
	hrs.carousel_number = 1;
	hrs.slide_number = -1;
	hrs.slide_of = -1;
	hrs.copy_rule = Assets::new_rule(NULL, I"", I"private copy", NULL);

	Swarm::ensure_plugin(wv, I"Base");
	hrs.colours = Swarm::ensure_colour_scheme(wv, I"Colours", I"");
	return hrs;
}

@ So, then, here are the front-end method functions for rendering to HTML and
ePub respectively:

=
void HTMLFormat::render(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	HTML::declare_as_HTML(OUT, FALSE);
	HTML_render_state hrs = HTMLFormat::initial_state(OUT, C->wv, FALSE, C->wv->weave_to);
	Trees::traverse_from(tree->root, &HTMLFormat::render_visit, (void *) &hrs, 0);
	HTML::completed(OUT);
}
void HTMLFormat::render_EPUB(weave_format *self, text_stream *OUT, heterogeneous_tree *tree) {
	weave_document_node *C = RETRIEVE_POINTER_weave_document_node(tree->root->content);
	HTML::declare_as_HTML(OUT, TRUE);
	HTML_render_state hrs = HTMLFormat::initial_state(OUT, C->wv, TRUE, C->wv->weave_to);
	Trees::traverse_from(tree->root, &HTMLFormat::render_visit, (void *) &hrs, 0);
	Epub::note_page(C->wv->weave_web->as_ebook, C->wv->weave_to, C->wv->booklet_title, I"");
	HTML::completed(OUT);
}

@ And in either case, we traverse the weave tree with the following visitor function.

=
int HTMLFormat::render_visit(tree_node *N, void *state, int L) {
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
	else if (N->type == weave_bar_node_type) @<Render bar@>
	else if (N->type == weave_paragraph_heading_node_type) @<Render paragraph heading@>
	else if (N->type == weave_endnote_node_type) @<Render endnote@>
	else if (N->type == weave_figure_node_type) @<Render figure@>
	else if (N->type == weave_audio_node_type) @<Render audio clip@>
	else if (N->type == weave_video_node_type) @<Render video clip@>
	else if (N->type == weave_download_node_type) @<Render download@>
	else if (N->type == weave_material_node_type) @<Render material@>
	else if (N->type == weave_embed_node_type) @<Render embed@>
	else if (N->type == weave_pmac_node_type) @<Render pmac@>
	else if (N->type == weave_vskip_node_type) @<Render vskip@>
	else if (N->type == weave_section_node_type) @<Render section@>
	else if (N->type == weave_code_line_node_type) @<Render code line@>
	else if (N->type == weave_function_usage_node_type) @<Render function usage@>
	else if (N->type == weave_commentary_node_type) @<Render commentary@>
	else if (N->type == weave_carousel_slide_node_type) @<Render carousel slide@>
	else if (N->type == weave_toc_node_type) @<Render toc@>
	else if (N->type == weave_toc_line_node_type) @<Render toc line@>
	else if (N->type == weave_defn_node_type) @<Render defn@>
	else if (N->type == weave_source_code_node_type) @<Render source code@>
	else if (N->type == weave_url_node_type) @<Render URL@>
	else if (N->type == weave_footnote_cue_node_type) @<Render footnote cue@>
	else if (N->type == weave_begin_footnote_text_node_type) @<Render footnote@>
	else if (N->type == weave_display_line_node_type) @<Render display line@>
	else if (N->type == weave_function_defn_node_type) @<Render function defn@>
	else if (N->type == weave_item_node_type) @<Render item@>
	else if (N->type == weave_inline_node_type) @<Render inline@>
	else if (N->type == weave_locale_node_type) @<Render locale@>
	else if (N->type == weave_maths_node_type) @<Render maths@>
	else if (N->type == weave_linebreak_node_type) @<Render linebreak@>

	else internal_error("unable to render unknown node");
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
		Colonies::drop_initial_breadcrumbs(OUT,
			hrs->wv->weave_to, hrs->wv->breadcrumbs);
		text_stream *bct = Bibliographic::get_datum(hrs->wv->weave_web->md, I"Title");
		if (Str::len(Bibliographic::get_datum(hrs->wv->weave_web->md, I"Short Title")) > 0)
			bct = Bibliographic::get_datum(hrs->wv->weave_web->md, I"Short Title");
		if (hrs->wv->self_contained == FALSE) {
			Colonies::write_breadcrumb(OUT, bct, I"index.html");
			if (hrs->wv->weave_web->md->chaptered) {
				TEMPORARY_TEXT(chapter_link)
				WRITE_TO(chapter_link, "index.html#%s%S",
					(hrs->wv->weave_web->as_ebook)?"C":"",
					C->sect->owning_chapter->md->ch_range);
				Colonies::write_breadcrumb(OUT,
					C->sect->owning_chapter->md->ch_title, chapter_link);
				DISCARD_TEXT(chapter_link)
			}
			Colonies::write_breadcrumb(OUT, C->sect->md->sect_title, NULL);
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
	chapter *Ch;
	section *next_S = NULL, *prev_S = NULL, *last = NULL;
	LOOP_OVER_LINKED_LIST(Ch, chapter, hrs->wv->weave_web->chapters) {
		if (Ch->md->imported == FALSE) {
			section *S;
			LOOP_OVER_LINKED_LIST(S, section, Ch->sections) {
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
		chapter *Ch;
		LOOP_OVER_LINKED_LIST(Ch, chapter, hrs->wv->weave_web->chapters) {
			if (Ch->md->imported == FALSE) {
				if (Str::ne(Ch->md->ch_range, I"S")) {
					if (Ch == C->sect->owning_chapter) {
						HTML_OPEN_WITH("li", "class=\"progresscurrentchapter\"");
					} else {
						HTML_OPEN_WITH("li", "class=\"progresschapter\"");
					}
					TEMPORARY_TEXT(TEMP)
					section *S = FIRST_IN_LINKED_LIST(section, Ch->sections);
					Colonies::section_URL(TEMP, S->md);
					if (Ch != C->sect->owning_chapter) {
						HTML::begin_link(OUT, TEMP);
					}
					WRITE("%S", Ch->md->ch_range);
					if (Ch != C->sect->owning_chapter) {
						HTML::end_link(OUT);
					}
					DISCARD_TEXT(TEMP)
					HTML_CLOSE("li");
				}
				if (Ch == C->sect->owning_chapter) {
					section *S;
					LOOP_OVER_LINKED_LIST(S, section, Ch->sections) {
						TEMPORARY_TEXT(label)
						int on = FALSE;
						LOOP_THROUGH_TEXT(pos, S->md->sect_range) {
							if (Str::get(pos) == '/') on = TRUE;
							else if (on) PUT_TO(label, Str::get(pos));
						}
						if (Str::eq(Bibliographic::get_datum(hrs->wv->weave_web->md,
							I"Sequential Section Ranges"), I"On"))
							Str::delete_first_character(label);
						if (S == C->sect) {
							HTML_OPEN_WITH("li", "class=\"progresscurrent\"");
							WRITE("%S", label);
							HTML_CLOSE("li");
						} else {
							HTML_OPEN_WITH("li", "class=\"progresssection\"");
							TEMPORARY_TEXT(TEMP)
							Colonies::section_URL(TEMP, S->md);
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
	if (prev_S) Colonies::section_URL(TEMP, prev_S->md);
	if (prev_S) HTML::begin_link(OUT, TEMP);
	WRITE("&#10094;");
	if (prev_S) HTML::end_link(OUT);
	DISCARD_TEXT(TEMP)
	HTML_CLOSE("li");

@<Insert next arrow@> =
	if (next_S) HTML_OPEN_WITH("li", "class=\"progressnext\"")
	else HTML_OPEN_WITH("li", "class=\"progressnextoff\"");
	TEMPORARY_TEXT(TEMP)
	if (next_S) Colonies::section_URL(TEMP, next_S->md);
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
	HTMLFormat::escape_text(OUT, C->purpose);
	HTML_CLOSE("p"); WRITE("\n");

@<Render subheading@> =
	weave_subheading_node *C = RETRIEVE_POINTER_weave_subheading_node(N->content);
	HTML_OPEN("h3");
	HTMLFormat::escape_text(OUT, C->text);
	HTML_CLOSE("h3"); WRITE("\n");

@<Render bar@> =
	HTML::hr(OUT, NULL);

@<Render paragraph heading@> =
	weave_paragraph_heading_node *C =
		RETRIEVE_POINTER_weave_paragraph_heading_node(N->content);
	paragraph *P = C->para;
	if (P == NULL) internal_error("no para");
	if (N->child == NULL) {
		paragraph *first_in_para = P;
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
		Pathnames::down(hrs->wv->weave_web->md->path_to_web, I"Figures"),
		C->figname);
	filename *RF = Filenames::from_text(C->figname);
	HTML_OPEN_WITH("p", "class=\"center-p\"");
	HTML::image_to_dimensions(OUT, RF, C->w, C->h);
	Assets::include_asset(OUT, hrs->copy_rule, hrs->wv->weave_web, F, NULL,
		hrs->wv->pattern, hrs->wv->weave_to);
	HTML_CLOSE("p");
	WRITE("\n");

@<Render audio clip@> =
	weave_audio_node *C = RETRIEVE_POINTER_weave_audio_node(N->content);
	filename *F = Filenames::in(
		Pathnames::down(hrs->wv->weave_web->md->path_to_web, I"Audio"),
		C->audio_name);
	Assets::include_asset(OUT, hrs->copy_rule, hrs->wv->weave_web, F, NULL,
		hrs->wv->pattern, hrs->wv->weave_to);
	HTML_OPEN_WITH("p", "class=\"center-p\"");
	WRITE("<audio controls>\n");
	WRITE("<source src=\"%S\" type=\"audio/mpeg\">\n", C->audio_name);
	WRITE("Your browser does not support the audio element.\n");
	WRITE("</audio>\n");
	HTML_CLOSE("p");
	WRITE("\n");

@<Render video clip@> =
	weave_video_node *C = RETRIEVE_POINTER_weave_video_node(N->content);
	filename *F = Filenames::in(
		Pathnames::down(hrs->wv->weave_web->md->path_to_web, I"Video"),
		C->video_name);
	Assets::include_asset(OUT, hrs->copy_rule, hrs->wv->weave_web, F, NULL,
		hrs->wv->pattern, hrs->wv->weave_to);
	HTML_OPEN_WITH("p", "class=\"center-p\"");
	if ((C->w > 0) && (C->h > 0))
		WRITE("<video width=\"%d\" height=\"%d\" controls>", C->w, C->h);
	else if (C->w > 0)
		WRITE("<video width=\"%d\" controls>", C->w);
	else if (C->h > 0)
		WRITE("<video height=\"%d\" controls>", C->h);
	else
		WRITE("<video controls>");
	WRITE("<source src=\"%S\" type=\"video/mp4\">\n", C->video_name);
	WRITE("Your browser does not support the video tag.\n");
	WRITE("</video>\n");
	HTML_CLOSE("p");
	WRITE("\n");

@<Render download@> =
	weave_download_node *C = RETRIEVE_POINTER_weave_download_node(N->content);
	filename *F = Filenames::in(
		Pathnames::down(hrs->wv->weave_web->md->path_to_web, I"Downloads"),
		C->download_name);
	filename *TF = Patterns::find_file_in_subdirectory(hrs->wv->pattern, I"Embedding",
		I"Download.html");
	if (TF == NULL) {
		Main::error_in_web(I"Downloads are not supported", hrs->wv->current_weave_line);
	} else {
		Swarm::ensure_plugin(hrs->wv, I"Downloads");
		Assets::include_asset(OUT, hrs->copy_rule, hrs->wv->weave_web, F, NULL,
			hrs->wv->pattern, hrs->wv->weave_to);
		TEMPORARY_TEXT(url)
		TEMPORARY_TEXT(size)
		Pathnames::relative_URL(url, Filenames::up(hrs->wv->weave_to), Filenames::up(F));
		WRITE_TO(url, "%S", Filenames::get_leafname(F));
		int N = Filenames::size(F);
		if (N > 0) @<Describe the file size@>
		else Main::error_in_web(I"Download file missing or empty",
				hrs->wv->current_weave_line);
		filename *D = Filenames::from_text(C->download_name);
		Bibliographic::set_datum(hrs->wv->weave_web->md, I"File Name",
			Filenames::get_leafname(D));
		Bibliographic::set_datum(hrs->wv->weave_web->md, I"File URL", url);
		Bibliographic::set_datum(hrs->wv->weave_web->md, I"File Details", size);
		Collater::for_web_and_pattern(OUT, hrs->wv->weave_web, hrs->wv->pattern,
			TF, hrs->into_file);
		WRITE("\n");
		DISCARD_TEXT(url)
		DISCARD_TEXT(size)
	}

@<Describe the file size@> =
	WRITE_TO(size, " (");
	if (Str::len(C->filetype) > 0) WRITE_TO(size, "%S, ", C->filetype);
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

@<If no para number yet, render a p just to hold this@> =
	if (first_in_para) {
		HTML_OPEN_WITH("p", "class=\"commentary firstcommentary\"");
		HTMLFormat::paragraph_number(OUT, first_in_para);
		HTML_CLOSE("p"); WRITE("\n");
		first_in_para = NULL;
	}

@<Deal with a commentary material node@> =
	int item_depth = 0;
	for (tree_node *M = N->child; M; M = M->next) {
		if (M->type == weave_item_node_type) {
			@<If no para number yet, render a p just to hold this@>;
			weave_item_node *C = RETRIEVE_POINTER_weave_item_node(M->content);
			HTMLFormat::go_to_depth(hrs, item_depth, C->depth);
			item_depth = C->depth;
			Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
			continue;
		}
		if (HTMLFormat::interior_material(M)) @<Render a run of interior matter@>;
		@<If no para number yet, render a p just to hold this@>;
		if (item_depth > 0) {
			HTMLFormat::go_to_depth(hrs, item_depth, 0);
			item_depth = 0;
		}
		if (M->type == weave_vskip_node_type) continue;
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
	}
	if (item_depth > 0) {
		HTMLFormat::go_to_depth(hrs, item_depth, 0);
		item_depth = 0;
	}

@<Render a run of interior matter@> =
	if (first_in_para) {
		HTML_OPEN_WITH("p", "class=\"commentary firstcommentary\"");
		HTMLFormat::paragraph_number(OUT, first_in_para);
		first_in_para = NULL;
	} else {
		if (item_depth == 0) HTML_OPEN_WITH("p", "class=\"commentary\"");
	}
	while (M) {
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
		if ((M->next == NULL) || (HTMLFormat::interior_material(M->next) == FALSE)) break;
		M = M->next;
	}
	if (item_depth == 0) { HTML_CLOSE("p"); WRITE("\n"); }
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
		HTML_OPEN_WITH("p", "class=\"commentary firstcommentary\"");
		HTMLFormat::paragraph_number(OUT, first_in_para);
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

@ This has to embed some Internet-sourced content. |service|
here is something like |YouTube| or |Soundcloud|, and |ID| is whatever code
that service uses to identify the video/audio in question.

@<Render embed@> =
	weave_embed_node *C = RETRIEVE_POINTER_weave_embed_node(N->content);
	text_stream *CH = I"405";
	text_stream *CW = I"720";
	if (C->w > 0) { Str::clear(CW); WRITE_TO(CW, "%d", C->w); }
	if (C->h > 0) { Str::clear(CH); WRITE_TO(CH, "%d", C->h); }
	TEMPORARY_TEXT(embed_leaf)
	WRITE_TO(embed_leaf, "%S.html", C->service);
	filename *F = Patterns::find_file_in_subdirectory(hrs->wv->pattern, I"Embedding", embed_leaf);
	DISCARD_TEXT(embed_leaf)
	if (F == NULL) {
		Main::error_in_web(I"This is not a supported service", hrs->wv->current_weave_line);
	} else {
		Bibliographic::set_datum(hrs->wv->weave_web->md, I"Content ID", C->ID);
		Bibliographic::set_datum(hrs->wv->weave_web->md, I"Content Width", CW);
		Bibliographic::set_datum(hrs->wv->weave_web->md, I"Content Height", CH);
		HTML_OPEN_WITH("p", "class=\"center-p\"");
		Collater::for_web_and_pattern(OUT, hrs->wv->weave_web, hrs->wv->pattern,
			F, hrs->into_file);
		HTML_CLOSE("p");
		WRITE("\n");
	}

@<Render pmac@> =
	weave_pmac_node *C = RETRIEVE_POINTER_weave_pmac_node(N->content);
	paragraph *P = C->pmac->defining_paragraph;
	HTML_OPEN_WITH("span", "class=\"named-paragraph-container code-font\"");
	if (C->defn == FALSE) {
		TEMPORARY_TEXT(url)
		Colonies::paragraph_URL(url, P, hrs->wv->weave_to);
		HTML::begin_link_with_class(OUT, I"named-paragraph-link", url);
		DISCARD_TEXT(url)
	}
	HTML_OPEN_WITH("span", "class=\"%s\"",
		(C->defn)?"named-paragraph-defn":"named-paragraph");
	HTMLFormat::escape_text(OUT, C->pmac->macro_name);
	HTML_CLOSE("span");
	HTML_OPEN_WITH("span", "class=\"named-paragraph-number\"");
	HTMLFormat::escape_text(OUT, P->paragraph_number);
	HTML_CLOSE("span");
	if (C->defn == FALSE) HTML::end_link(OUT);
	HTML_CLOSE("span");
	if (C->defn) {
		HTMLFormat::change_colour(OUT, COMMENT_COLOUR, hrs->colours);
		WRITE(" =");
		HTMLFormat::change_colour(OUT, -1, hrs->colours);
	}

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
	HTMLFormat::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
	WRITE("%S", C->fn->function_name);
	HTMLFormat::change_colour(OUT, -1, hrs->colours);
	HTML::end_link(OUT);

@<Render commentary@> =
	weave_commentary_node *C = RETRIEVE_POINTER_weave_commentary_node(N->content);
	if (C->in_code) HTMLFormat::change_colour(OUT, COMMENT_COLOUR, hrs->colours);
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
	if (C->in_code) HTMLFormat::change_colour(OUT, -1, hrs->colours);

@<Render carousel slide@> =
	weave_carousel_slide_node *C = RETRIEVE_POINTER_weave_carousel_slide_node(N->content);
	Swarm::ensure_plugin(hrs->wv, I"Carousel");
	TEMPORARY_TEXT(carousel_id)
	TEMPORARY_TEXT(carousel_dots_id)
	text_stream *caption_class = NULL;
	text_stream *slide_count_class = I"carousel-number";
	switch (C->caption_command) {
		case CAROUSEL_CMD: caption_class = I"carousel-caption"; break;
		case CAROUSEL_ABOVE_CMD: caption_class = I"carousel-caption-above";
			slide_count_class = I"carousel-number-above"; break;
		case CAROUSEL_BELOW_CMD: caption_class = I"carousel-caption-below";
			slide_count_class = I"carousel-number-below"; break;
	}
	WRITE_TO(carousel_id, "carousel-no-%d", hrs->carousel_number);
	WRITE_TO(carousel_dots_id, "carousel-dots-no-%d", hrs->carousel_number);
	if (hrs->slide_number == -1) {
		hrs->slide_number = 1;
		hrs->slide_of = 0;
		for (tree_node *X = N; (X) && (X->type == N->type); X = X->next) hrs->slide_of++;
	} else {
		hrs->slide_number++;
		if (hrs->slide_number > hrs->slide_of) internal_error("miscounted slides");
	}
	if (hrs->slide_number == 1) {
		WRITE("<div class=\"carousel-container\" id=\"%S\">\n", carousel_id);
	}
	WRITE("<div class=\"carousel-slide fading-slide\"");
	if (hrs->slide_number == 1) WRITE(" style=\"display: block;\"");
	else WRITE(" style=\"display: none;\"");
	WRITE(">\n");
	if (C->caption_command == CAROUSEL_ABOVE_CMD) {
		@<Place caption here@>;
		WRITE("<div class=\"%S\">%d / %d</div>\n",
			slide_count_class, hrs->slide_number, hrs->slide_of);
	} else {
		WRITE("<div class=\"%S\">%d / %d</div>\n",
			slide_count_class, hrs->slide_number, hrs->slide_of);
	}
	WRITE("<div class=\"carousel-content\">");
	@<Recurse the renderer through children nodes@>;
	WRITE("</div>\n");
	if (C->caption_command != CAROUSEL_ABOVE_CMD) @<Place caption here@>;
	WRITE("</div>\n");
	if (hrs->slide_number == hrs->slide_of) {
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
		for (int i=1; i<=hrs->slide_of; i++) {
			if (i == 1)
				WRITE("<span class=\"carousel-dot carousel-dot-active\" ");
			else
				WRITE("<span class=\"carousel-dot\" ");
			WRITE("onclick=\"carouselSetSlide(&quot;%S&quot;, &quot;%S&quot;, %d)\"",
				carousel_id, carousel_dots_id, i-1);
			WRITE("></span>\n");
		}
		WRITE("</div>\n");
		hrs->slide_number = -1;
		hrs->slide_of = -1;
		hrs->carousel_number++;
	}
	DISCARD_TEXT(carousel_id)
	DISCARD_TEXT(carousel_dots_id)
	return FALSE;

@<Place caption here@> =
	if (C->caption_command != CAROUSEL_UNCAPTIONED_CMD)
		WRITE("<div class=\"%S\">%S</div>\n", caption_class, C->caption);

@<Render toc@> =
	HTML_OPEN_WITH("ul", "class=\"toc\"");
	for (tree_node *M = N->child; M; M = M->next) {
		HTML_OPEN("li");
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);
		HTML_CLOSE("li");
	}
	HTML_CLOSE("ul");
	HTML::hr(OUT, "tocbar");
	WRITE("\n");
	return FALSE;

@<Render toc line@> =
	weave_toc_line_node *C = RETRIEVE_POINTER_weave_toc_line_node(N->content);
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_URL(TEMP, C->para, hrs->wv->weave_to);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	WRITE("%s%S", (Str::get_first_char(C->para->ornament) == 'S')?"&#167;":"&para;",
		C->para->paragraph_number);
	WRITE(". %S", C->text2);
	HTML::end_link(OUT);

@<Render defn@> =
	weave_defn_node *C = RETRIEVE_POINTER_weave_defn_node(N->content);
	HTML_OPEN_WITH("span", "class=\"definition-keyword\"");
	WRITE("%S", C->keyword);
	HTML_CLOSE("span");
	WRITE(" ");

@<Render source code@> =
	weave_source_code_node *C = RETRIEVE_POINTER_weave_source_code_node(N->content);
	int starts = FALSE;
	if (N == N->parent->child) starts = TRUE;
		int current_colour = -1, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(C->matter); i++) {
		colour_wanted = Str::get_at(C->colouring, i);
		if (colour_wanted != current_colour) {
			if (current_colour >= 0) HTML_CLOSE("span");
			HTMLFormat::change_colour(OUT, colour_wanted, hrs->colours);
			current_colour = colour_wanted;
		}
		if (Str::get_at(C->matter, i) == '<') WRITE("&lt;");
		else if (Str::get_at(C->matter, i) == '>') WRITE("&gt;");
		else if (Str::get_at(C->matter, i) == '&') WRITE("&amp;");
		else WRITE("%c", Str::get_at(C->matter, i));
	}
	if (current_colour >= 0) HTMLFormat::change_colour(OUT, -1, hrs->colours);

@<Render URL@> =
	weave_url_node *C = RETRIEVE_POINTER_weave_url_node(N->content);
	HTML::begin_link_with_class(OUT, (C->external)?I"external":I"internal", C->url);
	WRITE("%S", C->content);
	HTML::end_link(OUT);

@<Render footnote cue@> =
	weave_footnote_cue_node *C = RETRIEVE_POINTER_weave_footnote_cue_node(N->content);
	text_stream *fn_plugin_name = hrs->wv->pattern->footnotes_plugin;
	if (Str::len(fn_plugin_name) > 0)
		Swarm::ensure_plugin(hrs->wv, fn_plugin_name);
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
	text_stream *fn_plugin_name = hrs->wv->pattern->footnotes_plugin;
	if ((Str::len(fn_plugin_name) > 0) && (hrs->EPUB_flag == FALSE))
		Swarm::ensure_plugin(hrs->wv, fn_plugin_name);
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
	HTMLFormat::escape_text(OUT, C->text);
	HTML_CLOSE("p");
	OUTDENT; HTML_CLOSE("blockquote"); WRITE("\n");

@<Render function defn@> =
	weave_function_defn_node *C =
		RETRIEVE_POINTER_weave_function_defn_node(N->content);
	if ((Functions::used_elsewhere(C->fn)) && (hrs->EPUB_flag == FALSE)) {
		Swarm::ensure_plugin(hrs->wv, I"Popups");
		HTMLFormat::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
		WRITE("%S", C->fn->function_name);
		WRITE("</span>");
		WRITE("<button class=\"popup\" onclick=\"togglePopup('usagePopup%d')\">",
			hrs->popup_counter);
		HTMLFormat::change_colour(OUT, COMMENT_COLOUR, hrs->colours);
		WRITE("?");
		HTMLFormat::change_colour(OUT, -1, hrs->colours);
		WRITE("<span class=\"popuptext\" id=\"usagePopup%d\">Usage of ", hrs->popup_counter);
		HTML_OPEN_WITH("span", "class=\"code-font\"");
		HTMLFormat::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
		WRITE("%S", C->fn->function_name);
		HTMLFormat::change_colour(OUT, -1, hrs->colours);
		HTML_CLOSE("span");
		WRITE(":<br/>"); 
		@<Recurse the renderer through children nodes@>;
		HTMLFormat::change_colour(OUT, -1, hrs->colours);
		WRITE("</button>");
		hrs->popup_counter++;
	} else {
		HTMLFormat::change_colour(OUT, FUNCTION_COLOUR, hrs->colours);
		WRITE("%S", C->fn->function_name);
		HTMLFormat::change_colour(OUT, -1, hrs->colours);
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
	Colonies::paragraph_URL(TEMP, C->par1, hrs->wv->weave_to);
	HTML::begin_link(OUT, TEMP);
	DISCARD_TEXT(TEMP)
	WRITE("%s%S",
		(Str::get_first_char(C->par1->ornament) == 'S')?"&#167;":"&para;",
		C->par1->paragraph_number);
	if (C->par2) WRITE("-%S", C->par2->paragraph_number);
	HTML::end_link(OUT);

@<Render maths@> =
	weave_maths_node *C = RETRIEVE_POINTER_weave_maths_node(N->content);
	text_stream *plugin_name = hrs->wv->pattern->mathematics_plugin;
	if ((Str::len(plugin_name) == 0) || (hrs->EPUB_flag)) {
		TEMPORARY_TEXT(R)
		TeXUtilities::remove_math_mode(R, C->content);
		HTMLFormat::escape_text(OUT, R);
		DISCARD_TEXT(R)
	} else {
		Swarm::ensure_plugin(hrs->wv, plugin_name);
		if (C->displayed) WRITE("$$"); else WRITE("\\(");
		HTMLFormat::escape_text(OUT, C->content);
		if (C->displayed) WRITE("$$"); else WRITE("\\)");
	}
	
@<Render linebreak@> =
	WRITE("<br/>");

@<Render nothing@> =
	;

@<Recurse the renderer through children nodes@> =
	for (tree_node *M = N->child; M; M = M->next)
		Trees::traverse_from(M, &HTMLFormat::render_visit, (void *) hrs, L+1);

@ These are the nodes falling under a commentary material node which we will
amalgamate into a single HTML paragraph:

=
int HTMLFormat::interior_material(tree_node *N) {
	if (N->type == weave_commentary_node_type) return TRUE;
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
void HTMLFormat::go_to_depth(HTML_render_state *hrs, int from_depth, int to_depth) {
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
void HTMLFormat::paragraph_number(text_stream *OUT, paragraph *P) {
	TEMPORARY_TEXT(TEMP)
	Colonies::paragraph_anchor(TEMP, P);
	HTML::anchor_with_class(OUT, TEMP, I"paragraph-anchor");
	DISCARD_TEXT(TEMP)
	if (P->invisible == FALSE) {
		HTML_OPEN("b");
		WRITE("%s%S", (Str::get_first_char(P->ornament) == 'S')?"&#167;":"&para;",
			P->paragraph_number);
		WRITE(". %S%s ", P->heading_text, (Str::len(P->heading_text) > 0)?".":"");
		HTML_CLOSE("b");
	}
}

@ =
void HTMLFormat::change_colour(text_stream *OUT, int col, colour_scheme *cs) {
	if (col == -1) {
		HTML_CLOSE("span");
	} else {
		char *cl = "plain";
		switch (col) {
			case DEFINITION_COLOUR: 	cl = "definition-syntax"; break;
			case FUNCTION_COLOUR: 		cl = "function-syntax"; break;
			case IDENTIFIER_COLOUR: 	cl = "identifier-syntax"; break;
			case ELEMENT_COLOUR:		cl = "element-syntax"; break;
			case RESERVED_COLOUR: 		cl = "reserved-syntax"; break;
			case STRING_COLOUR: 		cl = "string-syntax"; break;
			case CHARACTER_COLOUR:      cl = "character-syntax"; break;
			case CONSTANT_COLOUR: 		cl = "constant-syntax"; break;
			case PLAIN_COLOUR: 			cl = "plain-syntax"; break;
			case EXTRACT_COLOUR: 		cl = "extract-syntax"; break;
			case COMMENT_COLOUR: 		cl = "comment-syntax"; break;
			default: PRINT("col: %d\n", col); internal_error("bad colour"); break;
		}
		HTML_OPEN_WITH("span", "class=\"%S%s\"", cs->prefix, cl);
	}
}

@ =
void HTMLFormat::escape_text(text_stream *OUT, text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
		if (Str::get_at(id, i) == '&') WRITE("&amp;");
		else if (Str::get_at(id, i) == '<') WRITE("&lt;");
		else if (Str::get_at(id, i) == '>') WRITE("&gt;");
		else PUT(Str::get_at(id, i));
	}
}

@h EPUB-only methods.

=
int HTMLFormat::begin_weaving_EPUB(weave_format *wf, web *W, weave_pattern *pattern) {
	TEMPORARY_TEXT(T)
	WRITE_TO(T, "%S", Bibliographic::get_datum(W->md, I"Title"));
	W->as_ebook = Epub::new(T, "P");
	filename *CSS = Patterns::find_file_in_subdirectory(pattern, I"Base", I"Base.css");
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
