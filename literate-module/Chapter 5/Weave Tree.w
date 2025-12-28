[WeaveTree::] Weave Tree.

The weaver produces a tree of rendering instructions as its main intermediate
representation, and this section defines that tree.

@ The data structure here is a heterogenous tree (unlike the LP source tree),
and this inevitably means an awful lot of tedious stucture declarations and
creator functions. Deep breath now:

=
typedef struct weave_document_node {
	struct weave_order *wv;
	int footnotes_present;
	CLASS_DEFINITION
} weave_document_node;

typedef struct weave_head_node {
	struct text_stream *banner;
	CLASS_DEFINITION
} weave_head_node;

typedef struct weave_body_node {
	CLASS_DEFINITION
} weave_body_node;

typedef struct weave_tail_node {
	struct text_stream *rennab;
	CLASS_DEFINITION
} weave_tail_node;

typedef struct weave_chapter_header_node {
	struct ls_chapter *chap;
	CLASS_DEFINITION
} weave_chapter_header_node;

typedef struct weave_chapter_footer_node {
	struct ls_chapter *chap;
	CLASS_DEFINITION
} weave_chapter_footer_node;

typedef struct weave_section_header_node {
	struct ls_section *sect;
	CLASS_DEFINITION
} weave_section_header_node;

typedef struct weave_section_footer_node {
	struct ls_section *sect;
	CLASS_DEFINITION
} weave_section_footer_node;

typedef struct weave_section_purpose_node {
	struct text_stream *purpose;
	CLASS_DEFINITION
} weave_section_purpose_node;

typedef struct weave_subheading_node {
	struct text_stream *text;
	CLASS_DEFINITION
} weave_subheading_node;

typedef struct weave_subsubheading_node {
	struct text_stream *text;
	CLASS_DEFINITION
} weave_subsubheading_node;

typedef struct weave_bar_node {
	CLASS_DEFINITION
} weave_bar_node;

typedef struct weave_pagebreak_node {
	CLASS_DEFINITION
} weave_pagebreak_node;

typedef struct weave_linebreak_node {
	CLASS_DEFINITION
} weave_linebreak_node;

typedef struct weave_paragraph_heading_node {
	struct ls_paragraph *para;
	int no_skip;
	CLASS_DEFINITION
} weave_paragraph_heading_node;

typedef struct weave_endnote_node {
	CLASS_DEFINITION
} weave_endnote_node;

typedef struct weave_figure_node {
	struct text_stream *figname;
	struct text_stream *alt_text;
	int w;
	int h;
	CLASS_DEFINITION
} weave_figure_node;

typedef struct weave_extract_node {
	struct text_stream *extract;
	CLASS_DEFINITION
} weave_extract_node;

typedef struct weave_audio_node {
	struct text_stream *audio_name;
	int w;
	CLASS_DEFINITION
} weave_audio_node;

typedef struct weave_video_node {
	struct text_stream *video_name;
	int w;
	int h;
	CLASS_DEFINITION
} weave_video_node;

typedef struct weave_download_node {
	struct text_stream *download_name;
	struct text_stream *filetype;
	CLASS_DEFINITION
} weave_download_node;

typedef struct weave_material_node {
	int material_type;
	int plainly;
	struct programming_language *styling;
	struct text_stream *endnote;
	CLASS_DEFINITION
} weave_material_node;

typedef struct weave_embed_node {
	struct text_stream *service;
	struct text_stream *ID;
	int w;
	int h;
	CLASS_DEFINITION
} weave_embed_node;

typedef struct weave_holon_usage_node {
	struct ls_holon *holon;
	struct markdown_variation *variation;
	CLASS_DEFINITION
} weave_holon_usage_node;

typedef struct weave_tangler_command_node {
	struct text_stream *command;
	CLASS_DEFINITION
} weave_tangler_command_node;

typedef struct weave_holon_declaration_node {
	struct ls_holon *holon;
	struct markdown_variation *variation;
	CLASS_DEFINITION
} weave_holon_declaration_node;

typedef struct weave_vskip_node {
	int in_comment;
	CLASS_DEFINITION
} weave_vskip_node;

typedef struct weave_chapter_node {
	struct ls_chapter *chap;
	CLASS_DEFINITION
} weave_chapter_node;

typedef struct weave_section_node {
	struct ls_section *sect;
	CLASS_DEFINITION
} weave_section_node;

typedef struct weave_code_line_node {
	CLASS_DEFINITION
} weave_code_line_node;

typedef struct weave_function_usage_node {
	struct text_stream *url;
	struct language_function *fn;
	CLASS_DEFINITION
} weave_function_usage_node;

typedef struct weave_commentary_node {
	struct text_stream *text;
	int in_code;
	CLASS_DEFINITION
} weave_commentary_node;

typedef struct weave_carousel_slide_node {
	struct text_stream *caption;
	int positioning;
	CLASS_DEFINITION
} weave_carousel_slide_node;

typedef struct weave_toc_node {
	struct text_stream *text1;
	CLASS_DEFINITION
} weave_toc_node;

typedef struct weave_toc_line_node {
	struct text_stream *text1;
	struct text_stream *text2;
	struct ls_paragraph *para;
	CLASS_DEFINITION
} weave_toc_line_node;

typedef struct weave_chapter_title_page_node {
	CLASS_DEFINITION
} weave_chapter_title_page_node;

typedef struct weave_defn_node {
	struct text_stream *keyword;
	CLASS_DEFINITION
} weave_defn_node;

typedef struct weave_inline_node {
	CLASS_DEFINITION
} weave_inline_node;

typedef struct weave_locale_node {
	struct ls_paragraph *par1;
	struct ls_paragraph *par2;
	int distant;
	CLASS_DEFINITION
} weave_locale_node;

typedef struct weave_source_code_node {
	struct text_stream *matter;
	struct text_stream *colouring;
	CLASS_DEFINITION
} weave_source_code_node;

typedef struct weave_comment_in_holon_node {
	struct text_stream *raw;
	struct markdown_item *as_markdown;
	struct markdown_variation *variation;
	CLASS_DEFINITION
} weave_comment_in_holon_node;

typedef struct weave_url_node {
	struct text_stream *url;
	struct text_stream *content;
	int external;
	CLASS_DEFINITION
} weave_url_node;

typedef struct weave_footnote_cue_node {
	struct text_stream *cue_text;
	CLASS_DEFINITION
} weave_footnote_cue_node;

typedef struct weave_begin_footnote_text_node {
	struct text_stream *cue_text;
	CLASS_DEFINITION
} weave_begin_footnote_text_node;

typedef struct weave_display_line_node {
	struct text_stream *text;
	CLASS_DEFINITION
} weave_display_line_node;

typedef struct weave_function_defn_node {
	struct language_function *fn;
	CLASS_DEFINITION
} weave_function_defn_node;

typedef struct weave_item_node {
	int depth;
	struct text_stream *label;
	CLASS_DEFINITION
} weave_item_node;

typedef struct weave_grammar_index_node {
	CLASS_DEFINITION
} weave_grammar_index_node;

typedef struct weave_maths_node {
	struct text_stream *content;
	int displayed;
	CLASS_DEFINITION
} weave_maths_node;

typedef struct weave_markdown_node {
	struct markdown_item *content;
	struct markdown_variation *variation;
	CLASS_DEFINITION
} weave_markdown_node;

typedef struct weave_verbatim_node {
	struct text_stream *content;
	CLASS_DEFINITION
} weave_verbatim_node;

typedef struct weave_index_marker_node {
	struct ls_paragraph *par;
	CLASS_DEFINITION
} weave_index_marker_node;

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
tree_node_type *weave_subsubheading_node_type = NULL;
tree_node_type *weave_bar_node_type = NULL;
tree_node_type *weave_pagebreak_node_type = NULL;
tree_node_type *weave_linebreak_node_type = NULL;
tree_node_type *weave_paragraph_heading_node_type = NULL;
tree_node_type *weave_endnote_node_type = NULL;
tree_node_type *weave_figure_node_type = NULL;
tree_node_type *weave_extract_node_type = NULL;
tree_node_type *weave_audio_node_type = NULL;
tree_node_type *weave_video_node_type = NULL;
tree_node_type *weave_download_node_type = NULL;
tree_node_type *weave_material_node_type = NULL;
tree_node_type *weave_embed_node_type = NULL;
tree_node_type *weave_holon_usage_node_type = NULL;
tree_node_type *weave_tangler_command_node_type = NULL;
tree_node_type *weave_vskip_node_type = NULL;
tree_node_type *weave_chapter_node_type = NULL;
tree_node_type *weave_section_node_type = NULL;
tree_node_type *weave_holon_declaration_node_type = NULL;
tree_node_type *weave_code_line_node_type = NULL;
tree_node_type *weave_function_usage_node_type = NULL;
tree_node_type *weave_commentary_node_type = NULL;
tree_node_type *weave_carousel_slide_node_type = NULL;
tree_node_type *weave_toc_node_type = NULL;
tree_node_type *weave_toc_line_node_type = NULL;
tree_node_type *weave_chapter_title_page_node_type = NULL;
tree_node_type *weave_defn_node_type = NULL;
tree_node_type *weave_source_code_node_type = NULL;
tree_node_type *weave_comment_in_holon_node_type = NULL;
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
tree_node_type *weave_markdown_node_type = NULL;
tree_node_type *weave_index_marker_node_type = NULL;

heterogeneous_tree *WeaveTree::new_tree(weave_order *wv, int footnotes_present) {
	if (weave_tree_type == NULL) {
		weave_tree_type = Trees::new_type(I"weave tree", NULL);
		weave_document_node_type =
			Trees::new_node_type(I"document", weave_document_node_CLASS, NULL);
		weave_head_node_type =
			Trees::new_node_type(I"head", weave_head_node_CLASS, NULL);
		weave_body_node_type =
			Trees::new_node_type(I"body", weave_body_node_CLASS, NULL);
		weave_tail_node_type =
			Trees::new_node_type(I"tail", weave_tail_node_CLASS, NULL);
		weave_chapter_footer_node_type =
			Trees::new_node_type(I"chapter footer", weave_chapter_footer_node_CLASS, NULL);
		weave_chapter_header_node_type =
			Trees::new_node_type(I"chapter header", weave_chapter_header_node_CLASS, NULL);
		weave_section_footer_node_type =
			Trees::new_node_type(I"section footer", weave_section_footer_node_CLASS, NULL);
		weave_section_header_node_type =
			Trees::new_node_type(I"section header", weave_section_header_node_CLASS, NULL);
		weave_section_purpose_node_type =
			Trees::new_node_type(I"section purpose", weave_section_purpose_node_CLASS, NULL);

		weave_subheading_node_type =
			Trees::new_node_type(I"subheading", weave_subheading_node_CLASS, NULL);
		weave_subsubheading_node_type =
			Trees::new_node_type(I"subsubheading", weave_subsubheading_node_CLASS, NULL);
		weave_bar_node_type =
			Trees::new_node_type(I"bar", weave_bar_node_CLASS, NULL);
		weave_pagebreak_node_type =
			Trees::new_node_type(I"pagebreak", weave_pagebreak_node_CLASS, NULL);
		weave_linebreak_node_type =
			Trees::new_node_type(I"linebreak", weave_linebreak_node_CLASS, NULL);
		weave_paragraph_heading_node_type =
			Trees::new_node_type(I"paragraph", weave_paragraph_heading_node_CLASS, NULL);
		weave_endnote_node_type =
			Trees::new_node_type(I"endnote", weave_endnote_node_CLASS, NULL);
		weave_figure_node_type =
			Trees::new_node_type(I"figure", weave_figure_node_CLASS, NULL);
		weave_extract_node_type =
			Trees::new_node_type(I"extract", weave_extract_node_CLASS, NULL);
		weave_audio_node_type =
			Trees::new_node_type(I"audio", weave_audio_node_CLASS, NULL);
		weave_video_node_type =
			Trees::new_node_type(I"video", weave_video_node_CLASS, NULL);
		weave_download_node_type =
			Trees::new_node_type(I"download", weave_download_node_CLASS, NULL);
		weave_material_node_type =
			Trees::new_node_type(I"material", weave_material_node_CLASS, NULL);
		weave_embed_node_type =
			Trees::new_node_type(I"embed", weave_embed_node_CLASS, NULL);
		weave_holon_usage_node_type =
			Trees::new_node_type(I"pmac", weave_holon_usage_node_CLASS, NULL);
		weave_tangler_command_node_type =
			Trees::new_node_type(I"tangler command", weave_tangler_command_node_CLASS, NULL);
		weave_vskip_node_type =
			Trees::new_node_type(I"vskip", weave_vskip_node_CLASS, NULL);
		weave_chapter_node_type =
			Trees::new_node_type(I"chapter", weave_chapter_node_CLASS, NULL);
		weave_section_node_type =
			Trees::new_node_type(I"section", weave_section_node_CLASS, NULL);
		weave_holon_declaration_node_type =
			Trees::new_node_type(I"holon declaration", weave_holon_declaration_node_CLASS, NULL);
		weave_code_line_node_type =
			Trees::new_node_type(I"code line", weave_code_line_node_CLASS, NULL);
		weave_function_usage_node_type =
			Trees::new_node_type(I"function usage", weave_function_usage_node_CLASS, NULL);
		weave_commentary_node_type =
			Trees::new_node_type(I"commentary", weave_commentary_node_CLASS, NULL);
		weave_carousel_slide_node_type =
			Trees::new_node_type(I"carousel slide", weave_carousel_slide_node_CLASS, NULL);
		weave_toc_node_type =
			Trees::new_node_type(I"toc", weave_toc_node_CLASS, NULL);
		weave_toc_line_node_type =
			Trees::new_node_type(I"toc line", weave_toc_line_node_CLASS, NULL);
		weave_chapter_title_page_node_type =
			Trees::new_node_type(I"chapter_title_page", weave_chapter_title_page_node_CLASS, NULL);
		weave_defn_node_type =
			Trees::new_node_type(I"defn", weave_defn_node_CLASS, NULL);
		weave_source_code_node_type =
			Trees::new_node_type(I"source_code", weave_source_code_node_CLASS, NULL);
		weave_comment_in_holon_node_type =
			Trees::new_node_type(I"comment in holon", weave_comment_in_holon_node_CLASS, NULL);
		weave_url_node_type =
			Trees::new_node_type(I"url", weave_url_node_CLASS, NULL);
		weave_footnote_cue_node_type =
			Trees::new_node_type(I"footnote_cue", weave_footnote_cue_node_CLASS, NULL);
		weave_begin_footnote_text_node_type =
			Trees::new_node_type(I"footnote", weave_begin_footnote_text_node_CLASS, NULL);
		weave_display_line_node_type =
			Trees::new_node_type(I"display line", weave_display_line_node_CLASS, NULL);
		weave_function_defn_node_type =
			Trees::new_node_type(I"function defn", weave_function_defn_node_CLASS, NULL);
		weave_item_node_type =
			Trees::new_node_type(I"item", weave_item_node_CLASS, NULL);
		weave_grammar_index_node_type =
			Trees::new_node_type(I"grammar index", weave_grammar_index_node_CLASS, NULL);
		weave_inline_node_type =
			Trees::new_node_type(I"inline", weave_inline_node_CLASS, NULL);
		weave_locale_node_type =
			Trees::new_node_type(I"locale", weave_locale_node_CLASS, NULL);
		weave_maths_node_type =
			Trees::new_node_type(I"mathematics", weave_maths_node_CLASS, NULL);
		weave_markdown_node_type =
			Trees::new_node_type(I"markdown", weave_markdown_node_CLASS, NULL);
		weave_index_marker_node_type =
			Trees::new_node_type(I"index marker", weave_index_marker_node_CLASS, NULL);

		weave_verbatim_node_type =
			Trees::new_node_type(I"verbatim", weave_verbatim_node_CLASS, NULL);
	}
	heterogeneous_tree *tree = Trees::new(weave_tree_type);
	Trees::make_root(tree, WeaveTree::document(tree, wv, footnotes_present));
	return tree;
}

tree_node *WeaveTree::document(heterogeneous_tree *tree, weave_order *wv, int footnotes_present) {
	weave_document_node *doc = CREATE(weave_document_node);
	doc->wv = wv;
	doc->footnotes_present = footnotes_present;
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

tree_node *WeaveTree::section_header(heterogeneous_tree *tree, ls_section *S) {
	weave_section_header_node *C = CREATE(weave_section_header_node);
	C->sect = S;
	return Trees::new_node(tree, weave_section_header_node_type,
		STORE_POINTER_weave_section_header_node(C));
}

tree_node *WeaveTree::section_footer(heterogeneous_tree *tree, ls_section *S) {
	weave_section_footer_node *C = CREATE(weave_section_footer_node);
	C->sect = S;
	return Trees::new_node(tree, weave_section_footer_node_type,
		STORE_POINTER_weave_section_footer_node(C));
}

tree_node *WeaveTree::chapter(heterogeneous_tree *tree, ls_chapter *Ch) {
	weave_chapter_node *C = CREATE(weave_chapter_node);
	C->chap = Ch;
	return Trees::new_node(tree, weave_chapter_node_type, STORE_POINTER_weave_chapter_node(C));
}

tree_node *WeaveTree::chapter_header(heterogeneous_tree *tree, ls_chapter *Ch) {
	weave_chapter_header_node *C = CREATE(weave_chapter_header_node);
	C->chap = Ch;
	return Trees::new_node(tree, weave_chapter_header_node_type,
		STORE_POINTER_weave_chapter_header_node(C));
}

tree_node *WeaveTree::chapter_footer(heterogeneous_tree *tree, ls_chapter *Ch) {
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

tree_node *WeaveTree::subsubheading(heterogeneous_tree *tree, text_stream *P) {
	weave_subsubheading_node *C = CREATE(weave_subsubheading_node);
	C->text = Str::duplicate(P);
	return Trees::new_node(tree, weave_subsubheading_node_type,
		STORE_POINTER_weave_subsubheading_node(C));
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

tree_node *WeaveTree::paragraph_heading(heterogeneous_tree *tree,
	ls_paragraph *par, int no_skip) {
	weave_paragraph_heading_node *C = CREATE(weave_paragraph_heading_node);
	C->para = par;
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
	text_stream *figname, text_stream *alt_text, int w, int h) {
	weave_figure_node *C = CREATE(weave_figure_node);
	C->figname = Str::duplicate(figname);
	C->alt_text = Str::duplicate(alt_text);
	C->w = w;
	C->h = h;
	return Trees::new_node(tree, weave_figure_node_type,
		STORE_POINTER_weave_figure_node(C));
}

tree_node *WeaveTree::raw_extract(heterogeneous_tree *tree, 
	text_stream *extract) {
	weave_extract_node *C = CREATE(weave_extract_node);
	C->extract = Str::duplicate(extract);
	return Trees::new_node(tree, weave_extract_node_type,
		STORE_POINTER_weave_extract_node(C));
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
	programming_language *styling, text_stream *endnote) {
	weave_material_node *C = CREATE(weave_material_node);
	C->material_type = material_type;
	C->plainly = plainly;
	C->styling = styling;
	C->endnote = Str::duplicate(endnote);
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
tree_node *WeaveTree::holon_usage(heterogeneous_tree *tree, ls_holon *holon, markdown_variation *variation) {
	weave_holon_usage_node *C = CREATE(weave_holon_usage_node);
	C->holon = holon;
	C->variation = variation;
	return Trees::new_node(tree, weave_holon_usage_node_type, STORE_POINTER_weave_holon_usage_node(C));
}

@ Similarly, if less often used:

=
tree_node *WeaveTree::tangler_command(heterogeneous_tree *tree, text_stream *cmd) {
	weave_tangler_command_node *C = CREATE(weave_tangler_command_node);
	C->command = Str::duplicate(cmd);
	return Trees::new_node(tree, weave_tangler_command_node_type, STORE_POINTER_weave_tangler_command_node(C));
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

tree_node *WeaveTree::section(heterogeneous_tree *tree, ls_section *sect) {
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

tree_node *WeaveTree::carousel_slide(heterogeneous_tree *tree, text_stream *caption, int positioning) {
	weave_carousel_slide_node *C = CREATE(weave_carousel_slide_node);
	C->caption = Str::duplicate(caption);
	C->positioning = positioning;
	return Trees::new_node(tree, weave_carousel_slide_node_type, STORE_POINTER_weave_carousel_slide_node(C));
}

tree_node *WeaveTree::table_of_contents(heterogeneous_tree *tree, text_stream *text1) {
	weave_toc_node *C = CREATE(weave_toc_node);
	C->text1 = Str::duplicate(text1);
	return Trees::new_node(tree, weave_toc_node_type, STORE_POINTER_weave_toc_node(C));
}

tree_node *WeaveTree::contents_line(heterogeneous_tree *tree,
	text_stream *text1, text_stream *text2, ls_paragraph *par) {
	weave_toc_line_node *C = CREATE(weave_toc_line_node);
	C->text1 = Str::duplicate(text1);
	C->text2 = Str::duplicate(text2);
	C->para = par;
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

tree_node *WeaveTree::holon_declaration(heterogeneous_tree *tree, ls_holon *holon,
	markdown_variation *variation) {
	weave_holon_declaration_node *C = CREATE(weave_holon_declaration_node);
	C->holon = holon;
	C->variation = variation;
	return Trees::new_node(tree, weave_holon_declaration_node_type, STORE_POINTER_weave_holon_declaration_node(C));
}

@ The following node is expected to weave a piece of code, which has already
been syntax-coloured.

We don't want to leak tab characters out into woven code, where they are at
the mercy of web browsers, which render tabs slightly oddly (and not to the
width this author happens to like). So tabs are automatically converted to
spaces sufficient to reach the next tab-stop position, calculated as:

@d SPACES_PER_TAB_IN_WOVEN_CODE 4

=
tree_node *WeaveTree::source_code(heterogeneous_tree *tree,
	text_stream *matter, text_stream *colouring) {
	if (Str::len(colouring) != Str::len(matter)) internal_error("bad source segment");

	for (int i=0; i<Str::len(matter); i++) {
		inchar32_t c = Str::get_at(matter, i);
		if (c == '\t') {
			Str::put_at(matter, i, ' ');
			int extra_spaces =
				SPACES_PER_TAB_IN_WOVEN_CODE - 1 - (i % SPACES_PER_TAB_IN_WOVEN_CODE);
			if (extra_spaces > 0) {
				for (int j=0; j<extra_spaces; j++) {
					PUT_TO(matter, ' '); PUT_TO(colouring, PLAIN_COLOUR);
				}
				for (int j=Str::len(matter)-1; j >= i+extra_spaces; j--) {
					Str::put_at(matter, j, Str::get_at(matter, j-extra_spaces));
					Str::put_at(colouring, j, Str::get_at(colouring, j-extra_spaces));
				}
				for (int j=0; j<extra_spaces; j++) {
					Str::put_at(matter, i+1+j, ' ');
					Str::put_at(colouring, i+1+j, PLAIN_COLOUR);
				}
			}
		}
	}

	weave_source_code_node *C = CREATE(weave_source_code_node);
	C->matter = Str::duplicate(matter);
	C->colouring = Str::duplicate(colouring);
	return Trees::new_node(tree, weave_source_code_node_type, STORE_POINTER_weave_source_code_node(C));
}

tree_node *WeaveTree::comment_in_holon(heterogeneous_tree *tree, text_stream *raw,
	markdown_item *as_markdown, markdown_variation *variation) {
	weave_comment_in_holon_node *C = CREATE(weave_comment_in_holon_node);
	C->raw = Str::duplicate(raw);
	C->as_markdown = as_markdown;
	C->variation = variation;
	return Trees::new_node(tree, weave_comment_in_holon_node_type, STORE_POINTER_weave_comment_in_holon_node(C));
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

tree_node *WeaveTree::locale(heterogeneous_tree *tree, ls_paragraph *par1,
	ls_paragraph *par2, ls_section *from) {
	weave_locale_node *C = CREATE(weave_locale_node);
	C->par1 = par1;
	C->par2 = par2;
	C->distant = FALSE;
	if ((from) && (C->par1->owning_unit->owning_section) && (from != C->par1->owning_unit->owning_section))
		C->distant = TRUE;
	return Trees::new_node(tree, weave_locale_node_type, STORE_POINTER_weave_locale_node(C));
}

tree_node *WeaveTree::mathematics(heterogeneous_tree *tree, text_stream *content, int displayed) {
	weave_maths_node *C = CREATE(weave_maths_node);
	C->content = Str::duplicate(content);
	C->displayed = displayed;
	return Trees::new_node(tree, weave_maths_node_type, STORE_POINTER_weave_maths_node(C));
}

tree_node *WeaveTree::markdown_chunk(heterogeneous_tree *tree, markdown_item *content,
	markdown_variation *variation) {
	weave_markdown_node *C = CREATE(weave_markdown_node);
	C->content = content;
	C->variation = variation;
	return Trees::new_node(tree, weave_markdown_node_type, STORE_POINTER_weave_markdown_node(C));
}

tree_node *WeaveTree::index_marker(heterogeneous_tree *tree, ls_paragraph *par) {
	weave_index_marker_node *C = CREATE(weave_index_marker_node);
	C->par = par;
	return Trees::new_node(tree, weave_index_marker_node_type, STORE_POINTER_weave_index_marker_node(C));
}

void WeaveTree::show(text_stream *OUT, heterogeneous_tree *T) {
	WRITE("%S\n", T->type->name);
	INDENT;
	DebuggingWeaving::render(NULL, OUT, T);
	OUTDENT;
}

void WeaveTree::prune(heterogeneous_tree *T) {
	Trees::prune_tree(T, &WeaveTree::prune_visit, NULL);
}

int WeaveTree::prune_visit(tree_node *N, void *state) {
	if ((N->type->required_CLASS == weave_material_node_CLASS) && (N->child == NULL))
		return TRUE;
	if ((N->type->required_CLASS == weave_vskip_node_CLASS) && (N->next == NULL))
		return TRUE;
	if ((N->type->required_CLASS == weave_vskip_node_CLASS) &&
		(N->next->type->required_CLASS == weave_item_node_CLASS))
		return TRUE;
	return FALSE;
}
