[WeaveTree::] Weave Tree.

An abstraction of the weaver output.

@ =
typedef struct weave_document_node {
	struct weave_order *wv;
	MEMORY_MANAGEMENT
} weave_document_node;

typedef struct weave_head_node {
	struct text_stream *banner;
	MEMORY_MANAGEMENT
} weave_head_node;

typedef struct weave_body_node {
	MEMORY_MANAGEMENT
} weave_body_node;

typedef struct weave_tail_node {
	struct text_stream *rennab;
	MEMORY_MANAGEMENT
} weave_tail_node;

typedef struct weave_chapter_header_node {
	struct chapter *chap;
	MEMORY_MANAGEMENT
} weave_chapter_header_node;

typedef struct weave_chapter_footer_node {
	struct chapter *chap;
	MEMORY_MANAGEMENT
} weave_chapter_footer_node;

typedef struct weave_section_header_node {
	struct section *sect;
	MEMORY_MANAGEMENT
} weave_section_header_node;

typedef struct weave_section_footer_node {
	struct section *sect;
	MEMORY_MANAGEMENT
} weave_section_footer_node;

typedef struct weave_section_purpose_node {
	struct text_stream *purpose;
	MEMORY_MANAGEMENT
} weave_section_purpose_node;

typedef struct weave_subheading_node {
	struct text_stream *text;
	MEMORY_MANAGEMENT
} weave_subheading_node;

typedef struct weave_bar_node {
	MEMORY_MANAGEMENT
} weave_bar_node;

typedef struct weave_pagebreak_node {
	MEMORY_MANAGEMENT
} weave_pagebreak_node;

typedef struct weave_linebreak_node {
	MEMORY_MANAGEMENT
} weave_linebreak_node;

typedef struct weave_paragraph_heading_node {
	struct paragraph *para;
	int no_skip;
	MEMORY_MANAGEMENT
} weave_paragraph_heading_node;

typedef struct weave_endnote_node {
	MEMORY_MANAGEMENT
} weave_endnote_node;

typedef struct weave_figure_node {
	struct text_stream *figname;
	int w;
	int h;
	MEMORY_MANAGEMENT
} weave_figure_node;

typedef struct weave_audio_node {
	struct text_stream *audio_name;
	int w;
	MEMORY_MANAGEMENT
} weave_audio_node;

typedef struct weave_video_node {
	struct text_stream *video_name;
	int w;
	int h;
	MEMORY_MANAGEMENT
} weave_video_node;

typedef struct weave_download_node {
	struct text_stream *download_name;
	struct text_stream *filetype;
	MEMORY_MANAGEMENT
} weave_download_node;

typedef struct weave_material_node {
	int material_type;
	int plainly;
	struct programming_language *styling;
	MEMORY_MANAGEMENT
} weave_material_node;

typedef struct weave_embed_node {
	struct text_stream *service;
	struct text_stream *ID;
	int w;
	int h;
	MEMORY_MANAGEMENT
} weave_embed_node;

typedef struct weave_pmac_node {
	struct para_macro *pmac;
	int defn;
	MEMORY_MANAGEMENT
} weave_pmac_node;

typedef struct weave_vskip_node {
	int in_comment;
	MEMORY_MANAGEMENT
} weave_vskip_node;

typedef struct weave_chapter_node {
	struct chapter *chap;
	MEMORY_MANAGEMENT
} weave_chapter_node;

typedef struct weave_section_node {
	struct section *sect;
	MEMORY_MANAGEMENT
} weave_section_node;

typedef struct weave_code_line_node {
	MEMORY_MANAGEMENT
} weave_code_line_node;

typedef struct weave_function_usage_node {
	struct text_stream *url;
	struct language_function *fn;
	MEMORY_MANAGEMENT
} weave_function_usage_node;

typedef struct weave_commentary_node {
	struct text_stream *text;
	int in_code;
	MEMORY_MANAGEMENT
} weave_commentary_node;

typedef struct weave_carousel_slide_node {
	struct text_stream *caption;
	int caption_command;
	MEMORY_MANAGEMENT
} weave_carousel_slide_node;

typedef struct weave_toc_node {
	struct text_stream *text1;
	MEMORY_MANAGEMENT
} weave_toc_node;

typedef struct weave_toc_line_node {
	struct text_stream *text1;
	struct text_stream *text2;
	struct paragraph *para;
	MEMORY_MANAGEMENT
} weave_toc_line_node;

typedef struct weave_chapter_title_page_node {
	MEMORY_MANAGEMENT
} weave_chapter_title_page_node;

typedef struct weave_defn_node {
	struct text_stream *keyword;
	MEMORY_MANAGEMENT
} weave_defn_node;

typedef struct weave_inline_node {
	MEMORY_MANAGEMENT
} weave_inline_node;

typedef struct weave_locale_node {
	struct paragraph *par1;
	struct paragraph *par2;
	MEMORY_MANAGEMENT
} weave_locale_node;

typedef struct weave_source_code_node {
	struct text_stream *matter;
	struct text_stream *colouring;
	MEMORY_MANAGEMENT
} weave_source_code_node;

typedef struct weave_url_node {
	struct text_stream *url;
	struct text_stream *content;
	int external;
	MEMORY_MANAGEMENT
} weave_url_node;

typedef struct weave_footnote_cue_node {
	struct text_stream *cue_text;
	MEMORY_MANAGEMENT
} weave_footnote_cue_node;

typedef struct weave_begin_footnote_text_node {
	struct text_stream *cue_text;
	MEMORY_MANAGEMENT
} weave_begin_footnote_text_node;

typedef struct weave_display_line_node {
	struct text_stream *text;
	MEMORY_MANAGEMENT
} weave_display_line_node;

typedef struct weave_function_defn_node {
	struct language_function *fn;
	MEMORY_MANAGEMENT
} weave_function_defn_node;

typedef struct weave_item_node {
	int depth;
	struct text_stream *label;
	MEMORY_MANAGEMENT
} weave_item_node;

typedef struct weave_grammar_index_node {
	MEMORY_MANAGEMENT
} weave_grammar_index_node;

typedef struct weave_maths_node {
	struct text_stream *content;
	int displayed;
	MEMORY_MANAGEMENT
} weave_maths_node;

typedef struct weave_verbatim_node {
	struct text_stream *content;
	MEMORY_MANAGEMENT
} weave_verbatim_node;

@ =
tree_type *weave_tree_type = NULL;
tree_node_type *weave_document_node_type = NULL;
tree_node_type *weave_head_node_type = NULL;
tree_node_type *weave_body_node_type = NULL;
tree_node_type *weave_tail_node_type = NULL;
tree_node_type *weave_chapter_header_node_type = NULL;
tree_node_type *weave_chapter_footer_node_type = NULL;
tree_node_type *weave_section_header_node_type = NULL;
tree_node_type *weave_section_footer_node_type = NULL;
tree_node_type *weave_section_purpose_node_type = NULL;
tree_node_type *weave_verbatim_node_type = NULL;
tree_node_type *weave_subheading_node_type = NULL;
tree_node_type *weave_bar_node_type = NULL;
tree_node_type *weave_pagebreak_node_type = NULL;
tree_node_type *weave_linebreak_node_type = NULL;
tree_node_type *weave_paragraph_heading_node_type = NULL;
tree_node_type *weave_endnote_node_type = NULL;
tree_node_type *weave_figure_node_type = NULL;
tree_node_type *weave_audio_node_type = NULL;
tree_node_type *weave_video_node_type = NULL;
tree_node_type *weave_download_node_type = NULL;
tree_node_type *weave_material_node_type = NULL;
tree_node_type *weave_embed_node_type = NULL;
tree_node_type *weave_pmac_node_type = NULL;
tree_node_type *weave_vskip_node_type = NULL;
tree_node_type *weave_chapter_node_type = NULL;
tree_node_type *weave_section_node_type = NULL;
tree_node_type *weave_code_line_node_type = NULL;
tree_node_type *weave_function_usage_node_type = NULL;
tree_node_type *weave_commentary_node_type = NULL;
tree_node_type *weave_carousel_slide_node_type = NULL;
tree_node_type *weave_toc_node_type = NULL;
tree_node_type *weave_toc_line_node_type = NULL;
tree_node_type *weave_chapter_title_page_node_type = NULL;
tree_node_type *weave_defn_node_type = NULL;
tree_node_type *weave_source_code_node_type = NULL;
tree_node_type *weave_url_node_type = NULL;
tree_node_type *weave_footnote_cue_node_type = NULL;
tree_node_type *weave_begin_footnote_text_node_type = NULL;
tree_node_type *weave_display_line_node_type = NULL;
tree_node_type *weave_function_defn_node_type = NULL;
tree_node_type *weave_item_node_type = NULL;
tree_node_type *weave_grammar_index_node_type = NULL;
tree_node_type *weave_inline_node_type = NULL;
tree_node_type *weave_locale_node_type = NULL;
tree_node_type *weave_maths_node_type = NULL;

heterogeneous_tree *WeaveTree::new_tree(weave_order *wv) {
	if (weave_tree_type == NULL) {
		weave_tree_type = Trees::new_type(I"weave tree", NULL);
		weave_document_node_type =
			Trees::new_node_type(I"document", weave_document_node_MT, NULL);
		weave_head_node_type =
			Trees::new_node_type(I"head", weave_head_node_MT, NULL);
		weave_body_node_type =
			Trees::new_node_type(I"body", weave_body_node_MT, NULL);
		weave_tail_node_type =
			Trees::new_node_type(I"tail", weave_tail_node_MT, NULL);
		weave_chapter_footer_node_type =
			Trees::new_node_type(I"chapter footer", weave_chapter_footer_node_MT, NULL);
		weave_chapter_header_node_type =
			Trees::new_node_type(I"chapter header", weave_chapter_header_node_MT, NULL);
		weave_section_footer_node_type =
			Trees::new_node_type(I"section footer", weave_section_footer_node_MT, NULL);
		weave_section_header_node_type =
			Trees::new_node_type(I"section header", weave_section_header_node_MT, NULL);
		weave_section_purpose_node_type =
			Trees::new_node_type(I"section purpose", weave_section_purpose_node_MT, NULL);

		weave_subheading_node_type =
			Trees::new_node_type(I"subheading", weave_subheading_node_MT, NULL);
		weave_bar_node_type =
			Trees::new_node_type(I"bar", weave_bar_node_MT, NULL);
		weave_pagebreak_node_type =
			Trees::new_node_type(I"pagebreak", weave_pagebreak_node_MT, NULL);
		weave_linebreak_node_type =
			Trees::new_node_type(I"linebreak", weave_linebreak_node_MT, NULL);
		weave_paragraph_heading_node_type =
			Trees::new_node_type(I"paragraph", weave_paragraph_heading_node_MT, NULL);
		weave_endnote_node_type =
			Trees::new_node_type(I"endnote", weave_endnote_node_MT, NULL);
		weave_figure_node_type =
			Trees::new_node_type(I"figure", weave_figure_node_MT, NULL);
		weave_audio_node_type =
			Trees::new_node_type(I"audio", weave_audio_node_MT, NULL);
		weave_video_node_type =
			Trees::new_node_type(I"video", weave_video_node_MT, NULL);
		weave_download_node_type =
			Trees::new_node_type(I"download", weave_download_node_MT, NULL);
		weave_material_node_type =
			Trees::new_node_type(I"material", weave_material_node_MT, NULL);
		weave_embed_node_type =
			Trees::new_node_type(I"embed", weave_embed_node_MT, NULL);
		weave_pmac_node_type =
			Trees::new_node_type(I"pmac", weave_pmac_node_MT, NULL);
		weave_vskip_node_type =
			Trees::new_node_type(I"vskip", weave_vskip_node_MT, NULL);
		weave_chapter_node_type =
			Trees::new_node_type(I"chapter", weave_chapter_node_MT, NULL);
		weave_section_node_type =
			Trees::new_node_type(I"section", weave_section_node_MT, NULL);
		weave_code_line_node_type =
			Trees::new_node_type(I"code line", weave_code_line_node_MT, NULL);
		weave_function_usage_node_type =
			Trees::new_node_type(I"function usage", weave_function_usage_node_MT, NULL);
		weave_commentary_node_type =
			Trees::new_node_type(I"commentary", weave_commentary_node_MT, NULL);
		weave_carousel_slide_node_type =
			Trees::new_node_type(I"carousel slide", weave_carousel_slide_node_MT, NULL);
		weave_toc_node_type =
			Trees::new_node_type(I"toc", weave_toc_node_MT, NULL);
		weave_toc_line_node_type =
			Trees::new_node_type(I"toc line", weave_toc_line_node_MT, NULL);
		weave_chapter_title_page_node_type =
			Trees::new_node_type(I"chapter_title_page", weave_chapter_title_page_node_MT, NULL);
		weave_defn_node_type =
			Trees::new_node_type(I"defn", weave_defn_node_MT, NULL);
		weave_source_code_node_type =
			Trees::new_node_type(I"source_code", weave_source_code_node_MT, NULL);
		weave_url_node_type =
			Trees::new_node_type(I"url", weave_url_node_MT, NULL);
		weave_footnote_cue_node_type =
			Trees::new_node_type(I"footnote_cue", weave_footnote_cue_node_MT, NULL);
		weave_begin_footnote_text_node_type =
			Trees::new_node_type(I"footnote", weave_begin_footnote_text_node_MT, NULL);
		weave_display_line_node_type =
			Trees::new_node_type(I"display line", weave_display_line_node_MT, NULL);
		weave_function_defn_node_type =
			Trees::new_node_type(I"function defn", weave_function_defn_node_MT, NULL);
		weave_item_node_type =
			Trees::new_node_type(I"item", weave_item_node_MT, NULL);
		weave_grammar_index_node_type =
			Trees::new_node_type(I"grammar index", weave_grammar_index_node_MT, NULL);
		weave_inline_node_type =
			Trees::new_node_type(I"inline", weave_inline_node_MT, NULL);
		weave_locale_node_type =
			Trees::new_node_type(I"locale", weave_locale_node_MT, NULL);
		weave_maths_node_type =
			Trees::new_node_type(I"mathematics", weave_maths_node_MT, NULL);

		weave_verbatim_node_type =
			Trees::new_node_type(I"verbatim", weave_verbatim_node_MT, NULL);
	}
	heterogeneous_tree *tree = Trees::new(weave_tree_type);
	Trees::make_root(tree, WeaveTree::document(tree, wv));
	return tree;
}

tree_node *WeaveTree::document(heterogeneous_tree *tree, weave_order *wv) {
	weave_document_node *doc = CREATE(weave_document_node);
	doc->wv = wv;
	return Trees::new_node(tree, weave_document_node_type,
		STORE_POINTER_weave_document_node(doc));
}

tree_node *WeaveTree::head(heterogeneous_tree *tree, text_stream *banner) {
	weave_head_node *head = CREATE(weave_head_node);
	head->banner = Str::duplicate(banner);
	return Trees::new_node(tree, weave_head_node_type,
		STORE_POINTER_weave_head_node(head));
}

tree_node *WeaveTree::body(heterogeneous_tree *tree) {
	weave_body_node *body = CREATE(weave_body_node);
	return Trees::new_node(tree, weave_body_node_type,
		STORE_POINTER_weave_body_node(body));
}

tree_node *WeaveTree::tail(heterogeneous_tree *tree, text_stream *rennab) {
	weave_tail_node *tail = CREATE(weave_tail_node);
	tail->rennab = Str::duplicate(rennab);
	return Trees::new_node(tree, weave_tail_node_type,
		STORE_POINTER_weave_tail_node(tail));
}

tree_node *WeaveTree::verbatim(heterogeneous_tree *tree, text_stream *content) {
	weave_verbatim_node *C = CREATE(weave_verbatim_node);
	C->content = Str::duplicate(content);
	return Trees::new_node(tree, weave_verbatim_node_type,
		STORE_POINTER_weave_verbatim_node(C));
}

tree_node *WeaveTree::section_header(heterogeneous_tree *tree, section *S) {
	weave_section_header_node *C = CREATE(weave_section_header_node);
	C->sect = S;
	return Trees::new_node(tree, weave_section_header_node_type,
		STORE_POINTER_weave_section_header_node(C));
}

tree_node *WeaveTree::section_footer(heterogeneous_tree *tree, section *S) {
	weave_section_footer_node *C = CREATE(weave_section_footer_node);
	C->sect = S;
	return Trees::new_node(tree, weave_section_footer_node_type,
		STORE_POINTER_weave_section_footer_node(C));
}

tree_node *WeaveTree::chapter(heterogeneous_tree *tree, chapter *Ch) {
	weave_chapter_node *C = CREATE(weave_chapter_node);
	C->chap = Ch;
	return Trees::new_node(tree, weave_chapter_node_type, STORE_POINTER_weave_chapter_node(C));
}

tree_node *WeaveTree::chapter_header(heterogeneous_tree *tree, chapter *Ch) {
	weave_chapter_header_node *C = CREATE(weave_chapter_header_node);
	C->chap = Ch;
	return Trees::new_node(tree, weave_chapter_header_node_type,
		STORE_POINTER_weave_chapter_header_node(C));
}

tree_node *WeaveTree::chapter_footer(heterogeneous_tree *tree, chapter *Ch) {
	weave_chapter_footer_node *C = CREATE(weave_chapter_footer_node);
	C->chap = Ch;
	return Trees::new_node(tree, weave_chapter_footer_node_type,
		STORE_POINTER_weave_chapter_footer_node(C));
}

tree_node *WeaveTree::purpose(heterogeneous_tree *tree, text_stream *P) {
	weave_section_purpose_node *C = CREATE(weave_section_purpose_node);
	C->purpose = Str::duplicate(P);
	return Trees::new_node(tree, weave_section_purpose_node_type,
		STORE_POINTER_weave_section_purpose_node(C));
}

tree_node *WeaveTree::subheading(heterogeneous_tree *tree, text_stream *P) {
	weave_subheading_node *C = CREATE(weave_subheading_node);
	C->text = Str::duplicate(P);
	return Trees::new_node(tree, weave_subheading_node_type,
		STORE_POINTER_weave_subheading_node(C));
}

tree_node *WeaveTree::pagebreak(heterogeneous_tree *tree) {
	weave_pagebreak_node *C = CREATE(weave_pagebreak_node);
	return Trees::new_node(tree, weave_pagebreak_node_type,
		STORE_POINTER_weave_pagebreak_node(C));
}

tree_node *WeaveTree::linebreak(heterogeneous_tree *tree) {
	weave_linebreak_node *C = CREATE(weave_linebreak_node);
	return Trees::new_node(tree, weave_linebreak_node_type,
		STORE_POINTER_weave_linebreak_node(C));
}

tree_node *WeaveTree::bar(heterogeneous_tree *tree) {
	weave_bar_node *C = CREATE(weave_bar_node);
	return Trees::new_node(tree, weave_bar_node_type,
		STORE_POINTER_weave_bar_node(C));
}

tree_node *WeaveTree::paragraph_heading(heterogeneous_tree *tree, paragraph *P, int no_skip) {
	weave_paragraph_heading_node *C = CREATE(weave_paragraph_heading_node);
	C->para = P;
	C->no_skip = no_skip;
	return Trees::new_node(tree, weave_paragraph_heading_node_type,
		STORE_POINTER_weave_paragraph_heading_node(C));
}

tree_node *WeaveTree::endnote(heterogeneous_tree *tree) {
	weave_endnote_node *C = CREATE(weave_endnote_node);
	return Trees::new_node(tree, weave_endnote_node_type,
		STORE_POINTER_weave_endnote_node(C));
}

tree_node *WeaveTree::figure(heterogeneous_tree *tree, 
	text_stream *figname, int w, int h) {
	weave_figure_node *C = CREATE(weave_figure_node);
	C->figname = Str::duplicate(figname);
	C->w = w;
	C->h = h;
	return Trees::new_node(tree, weave_figure_node_type,
		STORE_POINTER_weave_figure_node(C));
}

tree_node *WeaveTree::audio(heterogeneous_tree *tree, 
	text_stream *audio_name, int w) {
	weave_audio_node *C = CREATE(weave_audio_node);
	C->audio_name = Str::duplicate(audio_name);
	C->w = w;
	return Trees::new_node(tree, weave_audio_node_type,
		STORE_POINTER_weave_audio_node(C));
}

tree_node *WeaveTree::video(heterogeneous_tree *tree, 
	text_stream *video_name, int w, int h) {
	weave_video_node *C = CREATE(weave_video_node);
	C->video_name = Str::duplicate(video_name);
	C->w = w;
	return Trees::new_node(tree, weave_video_node_type,
		STORE_POINTER_weave_video_node(C));
}

tree_node *WeaveTree::download(heterogeneous_tree *tree, 
	text_stream *download_name, text_stream *filetype) {
	weave_download_node *C = CREATE(weave_download_node);
	C->download_name = Str::duplicate(download_name);
	C->filetype = Str::duplicate(filetype);
	return Trees::new_node(tree, weave_download_node_type,
		STORE_POINTER_weave_download_node(C));
}

tree_node *WeaveTree::material(heterogeneous_tree *tree, int material_type, int plainly,
	programming_language *styling) {
	weave_material_node *C = CREATE(weave_material_node);
	C->material_type = material_type;
	C->plainly = plainly;
	C->styling = styling;
	return Trees::new_node(tree, weave_material_node_type, STORE_POINTER_weave_material_node(C));
}

tree_node *WeaveTree::embed(heterogeneous_tree *tree,
	text_stream *service, text_stream *ID, int w, int h) {
	weave_embed_node *C = CREATE(weave_embed_node);
	C->service = Str::duplicate(service);
	C->ID = Str::duplicate(ID);
	C->w = w;
	C->h = h;
	return Trees::new_node(tree, weave_embed_node_type, STORE_POINTER_weave_embed_node(C));
}

@ This node weaves an angle-bracketed paragraph macro name. |defn| is set
if and only if this is the place where the macro is defined -- the usual
thing is to render some sort of equals sign after it, if so.

=
tree_node *WeaveTree::pmac(heterogeneous_tree *tree, para_macro *pmac, int defn) {
	weave_pmac_node *C = CREATE(weave_pmac_node);
	C->pmac = pmac;
	C->defn = defn;
	return Trees::new_node(tree, weave_pmac_node_type, STORE_POINTER_weave_pmac_node(C));
}

@ The following should render some kind of skip, and may want to take note of
whether this happens in commentary or in code: the |in_comment| flag provides this
information.

=
tree_node *WeaveTree::vskip(heterogeneous_tree *tree, int in_comment) {
	weave_vskip_node *C = CREATE(weave_vskip_node);
	C->in_comment = in_comment;
	return Trees::new_node(tree, weave_vskip_node_type, STORE_POINTER_weave_vskip_node(C));
}

tree_node *WeaveTree::section(heterogeneous_tree *tree, section *sect) {
	weave_section_node *C = CREATE(weave_section_node);
	C->sect = sect;
	return Trees::new_node(tree, weave_section_node_type, STORE_POINTER_weave_section_node(C));
}

tree_node *WeaveTree::code_line(heterogeneous_tree *tree) {
	weave_code_line_node *C = CREATE(weave_code_line_node);
	return Trees::new_node(tree, weave_code_line_node_type, STORE_POINTER_weave_code_line_node(C));
}

tree_node *WeaveTree::function_usage(heterogeneous_tree *tree,
	text_stream *url, language_function *fn) {
	weave_function_usage_node *C = CREATE(weave_function_usage_node);
	C->url = Str::duplicate(url);
	C->fn = fn;
	return Trees::new_node(tree, weave_function_usage_node_type, STORE_POINTER_weave_function_usage_node(C));
}

tree_node *WeaveTree::commentary(heterogeneous_tree *tree, text_stream *text, int in_code) {
	weave_commentary_node *C = CREATE(weave_commentary_node);
	C->text = Str::duplicate(text);
	C->in_code = in_code;
	return Trees::new_node(tree, weave_commentary_node_type, STORE_POINTER_weave_commentary_node(C));
}

tree_node *WeaveTree::carousel_slide(heterogeneous_tree *tree, text_stream *caption, int c) {
	weave_carousel_slide_node *C = CREATE(weave_carousel_slide_node);
	C->caption = Str::duplicate(caption);
	C->caption_command = c;
	return Trees::new_node(tree, weave_carousel_slide_node_type, STORE_POINTER_weave_carousel_slide_node(C));
}

tree_node *WeaveTree::table_of_contents(heterogeneous_tree *tree, text_stream *text1) {
	weave_toc_node *C = CREATE(weave_toc_node);
	C->text1 = Str::duplicate(text1);
	return Trees::new_node(tree, weave_toc_node_type, STORE_POINTER_weave_toc_node(C));
}

tree_node *WeaveTree::contents_line(heterogeneous_tree *tree,
	text_stream *text1, text_stream *text2, paragraph *P) {
	weave_toc_line_node *C = CREATE(weave_toc_line_node);
	C->text1 = Str::duplicate(text1);
	C->text2 = Str::duplicate(text2);
	C->para = P;
	return Trees::new_node(tree, weave_toc_line_node_type, STORE_POINTER_weave_toc_line_node(C));
}

tree_node *WeaveTree::weave_chapter_title_page_node(heterogeneous_tree *tree) {
	weave_chapter_title_page_node *C = CREATE(weave_chapter_title_page_node);
	return Trees::new_node(tree, weave_chapter_title_page_node_type, STORE_POINTER_weave_chapter_title_page_node(C));
}

tree_node *WeaveTree::weave_defn_node(heterogeneous_tree *tree, text_stream *keyword) {
	weave_defn_node *C = CREATE(weave_defn_node);
	C->keyword = Str::duplicate(keyword);
	return Trees::new_node(tree, weave_defn_node_type, STORE_POINTER_weave_defn_node(C));
}

@ The following node is expected to weave a piece of code, which has already
been syntax-coloured.

=
tree_node *WeaveTree::source_code(heterogeneous_tree *tree,
	text_stream *matter, text_stream *colouring) {
	if (Str::len(colouring) != Str::len(matter)) internal_error("bad source segment");
	for (int i=0; i<Str::len(colouring); i++)
		if (Str::get_at(colouring, i) == 0) internal_error("scorb");
	weave_source_code_node *C = CREATE(weave_source_code_node);
	C->matter = Str::duplicate(matter);
	C->colouring = Str::duplicate(colouring);
	return Trees::new_node(tree, weave_source_code_node_type, STORE_POINTER_weave_source_code_node(C));
}

tree_node *WeaveTree::url(heterogeneous_tree *tree, text_stream *url,
	text_stream *content, int external) {
	weave_url_node *C = CREATE(weave_url_node);
	C->url = Str::duplicate(url);
	C->content = Str::duplicate(content);
	C->external = external;
	return Trees::new_node(tree, weave_url_node_type, STORE_POINTER_weave_url_node(C));
}

tree_node *WeaveTree::footnote_cue(heterogeneous_tree *tree, text_stream *cue) {
	weave_footnote_cue_node *C = CREATE(weave_footnote_cue_node);
	C->cue_text = Str::duplicate(cue);
	return Trees::new_node(tree, weave_footnote_cue_node_type, STORE_POINTER_weave_footnote_cue_node(C));
}

tree_node *WeaveTree::footnote(heterogeneous_tree *tree, text_stream *cue) {
	weave_begin_footnote_text_node *C = CREATE(weave_begin_footnote_text_node);
	C->cue_text = Str::duplicate(cue);
	return Trees::new_node(tree, weave_begin_footnote_text_node_type, STORE_POINTER_weave_begin_footnote_text_node(C));
}

@ This node need not do anything; it simply alerts the renderer that a function
definition has just occurred.

=
tree_node *WeaveTree::function_defn(heterogeneous_tree *tree, language_function *fn) {
	weave_function_defn_node *C = CREATE(weave_function_defn_node);
	C->fn = fn;
	return Trees::new_node(tree, weave_function_defn_node_type, STORE_POINTER_weave_function_defn_node(C));
}

@ This node produces the |>> Example| bits of example source text, really
a convenience for Inform 7 code commentary.

=
tree_node *WeaveTree::display_line(heterogeneous_tree *tree, text_stream *text) {
	weave_display_line_node *C = CREATE(weave_display_line_node);
	C->text = Str::duplicate(text);
	return Trees::new_node(tree, weave_display_line_node_type, STORE_POINTER_weave_display_line_node(C));
}

@ An item node produces an item marker in a typical (a), (b), (c), ... sort
of list. |depth| can be 1 or 2: you can have lists in lists, but not lists in
lists in lists. |label| is the marker text, e.g., |a|, |b|, |c|, ...; it can
also be empty, in which case the method should move to the matching level of
indentation but not weave any bracketed marker.

(a) This was produced by |depth| equal to 1, |label| equal to |a|.
(-i) This was produced by |depth| equal to 2, |label| equal to |i|.
(-ii) This was produced by |depth| equal to 2, |label| equal to |ii|.
(...) This was produced by |depth| equal to 1, |label| empty.
(b) This was produced by |depth| equal to 1, |label| equal to |b|.

=
tree_node *WeaveTree::weave_item_node(heterogeneous_tree *tree, int depth, text_stream *label) {
	weave_item_node *C = CREATE(weave_item_node);
	C->depth = depth;
	C->label = Str::duplicate(label);
	return Trees::new_node(tree, weave_item_node_type, STORE_POINTER_weave_item_node(C));
}

tree_node *WeaveTree::grammar_index(heterogeneous_tree *tree) {
	weave_grammar_index_node *C = CREATE(weave_grammar_index_node);
	return Trees::new_node(tree, weave_grammar_index_node_type, STORE_POINTER_weave_grammar_index_node(C));
}

tree_node *WeaveTree::inline(heterogeneous_tree *tree) {
	weave_inline_node *C = CREATE(weave_inline_node);
	return Trees::new_node(tree, weave_inline_node_type, STORE_POINTER_weave_inline_node(C));
}

tree_node *WeaveTree::locale(heterogeneous_tree *tree, paragraph *par1, paragraph *par2) {
	weave_locale_node *C = CREATE(weave_locale_node);
	C->par1 = par1;
	C->par2 = par2;
	return Trees::new_node(tree, weave_locale_node_type, STORE_POINTER_weave_locale_node(C));
}

tree_node *WeaveTree::mathematics(heterogeneous_tree *tree, text_stream *content, int displayed) {
	weave_maths_node *C = CREATE(weave_maths_node);
	C->content = Str::duplicate(content);
	C->displayed = displayed;
	return Trees::new_node(tree, weave_maths_node_type, STORE_POINTER_weave_maths_node(C));
}

void WeaveTree::show(text_stream *OUT, heterogeneous_tree *T) {
	WRITE("%S\n", T->type->name);
	INDENT;
	Debugging::render(NULL, OUT, T);
	OUTDENT;
}

void WeaveTree::prune(heterogeneous_tree *T) {
	Trees::prune_tree(T, &WeaveTree::prune_visit, NULL);
}

int WeaveTree::prune_visit(tree_node *N, void *state) {
	if ((N->type->required_MT == weave_material_node_MT) && (N->child == NULL))
		return TRUE;
	if ((N->type->required_MT == weave_vskip_node_MT) && (N->next == NULL))
		return TRUE;
	if ((N->type->required_MT == weave_vskip_node_MT) &&
		(N->next->type->required_MT == weave_item_node_MT))
		return TRUE;
	return FALSE;
}
