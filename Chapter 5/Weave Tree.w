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

typedef struct weave_paragraph_heading_node {
	struct paragraph *para;
	int no_skip;
	MEMORY_MANAGEMENT
} weave_paragraph_heading_node;

typedef struct weave_endnote_node {
	struct text_stream *text;
	MEMORY_MANAGEMENT
} weave_endnote_node;

typedef struct weave_figure_node {
	struct text_stream *figname;
	int w;
	int h;
	MEMORY_MANAGEMENT
} weave_figure_node;

typedef struct weave_chm_node {
	int old_material;
	int new_material;
	int content;
	int plainly;
	MEMORY_MANAGEMENT
} weave_chm_node;

typedef struct weave_embed_node {
	struct text_stream *service;
	struct text_stream *ID;
	MEMORY_MANAGEMENT
} weave_embed_node;

typedef struct weave_pmac_node {
	MEMORY_MANAGEMENT
} weave_pmac_node;

typedef struct weave_vskip_node {
	int in_comment;
	MEMORY_MANAGEMENT
} weave_vskip_node;

typedef struct weave_apres_defn_node {
	MEMORY_MANAGEMENT
} weave_apres_defn_node;

typedef struct weave_change_colour_node {
	MEMORY_MANAGEMENT
} weave_change_colour_node;

typedef struct weave_text_node {
	MEMORY_MANAGEMENT
} weave_text_node;

typedef struct weave_comment_node {
	MEMORY_MANAGEMENT
} weave_comment_node;

typedef struct weave_link_node {
	MEMORY_MANAGEMENT
} weave_link_node;

typedef struct weave_commentary_node {
	MEMORY_MANAGEMENT
} weave_commentary_node;

typedef struct weave_preform_document_node {
	MEMORY_MANAGEMENT
} weave_preform_document_node;

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

typedef struct weave_source_fragment_node {
	MEMORY_MANAGEMENT
} weave_source_fragment_node;

typedef struct weave_source_code_node {
	MEMORY_MANAGEMENT
} weave_source_code_node;

typedef struct weave_url_node {
	MEMORY_MANAGEMENT
} weave_url_node;

typedef struct weave_footnote_cue_node {
	MEMORY_MANAGEMENT
} weave_footnote_cue_node;

typedef struct weave_begin_footnote_text_node {
	MEMORY_MANAGEMENT
} weave_begin_footnote_text_node;

typedef struct weave_end_footnote_text_node {
	MEMORY_MANAGEMENT
} weave_end_footnote_text_node;

typedef struct weave_display_line_node {
	struct text_stream *text;
	MEMORY_MANAGEMENT
} weave_display_line_node;

typedef struct weave_item_node {
	int depth;
	struct text_stream *label;
	MEMORY_MANAGEMENT
} weave_item_node;

typedef struct weave_grammar_index_node {
	MEMORY_MANAGEMENT
} weave_grammar_index_node;

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
tree_node_type *weave_paragraph_heading_node_type = NULL;
tree_node_type *weave_endnote_node_type = NULL;
tree_node_type *weave_figure_node_type = NULL;
tree_node_type *weave_chm_node_type = NULL;
tree_node_type *weave_embed_node_type = NULL;
tree_node_type *weave_pmac_node_type = NULL;
tree_node_type *weave_vskip_node_type = NULL;
tree_node_type *weave_apres_defn_node_type = NULL;
tree_node_type *weave_change_colour_node_type = NULL;
tree_node_type *weave_text_node_type = NULL;
tree_node_type *weave_comment_node_type = NULL;
tree_node_type *weave_link_node_type = NULL;
tree_node_type *weave_commentary_node_type = NULL;
tree_node_type *weave_preform_document_node_type = NULL;
tree_node_type *weave_toc_node_type = NULL;
tree_node_type *weave_toc_line_node_type = NULL;
tree_node_type *weave_chapter_title_page_node_type = NULL;
tree_node_type *weave_source_fragment_node_type = NULL;
tree_node_type *weave_source_code_node_type = NULL;
tree_node_type *weave_url_node_type = NULL;
tree_node_type *weave_footnote_cue_node_type = NULL;
tree_node_type *weave_begin_footnote_text_node_type = NULL;
tree_node_type *weave_end_footnote_text_node_type = NULL;
tree_node_type *weave_display_line_node_type = NULL;
tree_node_type *weave_item_node_type = NULL;
tree_node_type *weave_grammar_index_node_type = NULL;

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
		weave_paragraph_heading_node_type =
			Trees::new_node_type(I"paragraph", weave_paragraph_heading_node_MT, NULL);
		weave_endnote_node_type =
			Trees::new_node_type(I"endnote", weave_endnote_node_MT, NULL);
		weave_figure_node_type =
			Trees::new_node_type(I"figure", weave_figure_node_MT, NULL);
		weave_chm_node_type =
			Trees::new_node_type(I"chm", weave_chm_node_MT, NULL);
		weave_embed_node_type =
			Trees::new_node_type(I"embed", weave_embed_node_MT, NULL);
		weave_pmac_node_type =
			Trees::new_node_type(I"pmac", weave_pmac_node_MT, NULL);
		weave_vskip_node_type =
			Trees::new_node_type(I"vskip", weave_vskip_node_MT, NULL);
		weave_apres_defn_node_type =
			Trees::new_node_type(I"apres_defn", weave_apres_defn_node_MT, NULL);
		weave_change_colour_node_type =
			Trees::new_node_type(I"change_colour", weave_change_colour_node_MT, NULL);
		weave_text_node_type =
			Trees::new_node_type(I"text", weave_text_node_MT, NULL);
		weave_comment_node_type =
			Trees::new_node_type(I"comment", weave_comment_node_MT, NULL);
		weave_link_node_type =
			Trees::new_node_type(I"link", weave_link_node_MT, NULL);
		weave_commentary_node_type =
			Trees::new_node_type(I"commentary", weave_commentary_node_MT, NULL);
		weave_preform_document_node_type =
			Trees::new_node_type(I"preform_document", weave_preform_document_node_MT, NULL);
		weave_toc_node_type =
			Trees::new_node_type(I"toc", weave_toc_node_MT, NULL);
		weave_toc_line_node_type =
			Trees::new_node_type(I"toc line", weave_toc_line_node_MT, NULL);
		weave_chapter_title_page_node_type =
			Trees::new_node_type(I"chapter_title_page", weave_chapter_title_page_node_MT, NULL);
		weave_source_fragment_node_type =
			Trees::new_node_type(I"source_fragment", weave_source_fragment_node_MT, NULL);
		weave_source_code_node_type =
			Trees::new_node_type(I"source_code", weave_source_code_node_MT, NULL);
		weave_url_node_type =
			Trees::new_node_type(I"url", weave_url_node_MT, NULL);
		weave_footnote_cue_node_type =
			Trees::new_node_type(I"footnote_cue", weave_footnote_cue_node_MT, NULL);
		weave_begin_footnote_text_node_type =
			Trees::new_node_type(I"begin_footnote_text", weave_begin_footnote_text_node_MT, NULL);
		weave_end_footnote_text_node_type =
			Trees::new_node_type(I"end_footnote_text", weave_end_footnote_text_node_MT, NULL);
		weave_display_line_node_type =
			Trees::new_node_type(I"display_line", weave_display_line_node_MT, NULL);
		weave_item_node_type =
			Trees::new_node_type(I"item", weave_item_node_MT, NULL);
		weave_grammar_index_node_type =
			Trees::new_node_type(I"grammar index", weave_grammar_index_node_MT, NULL);

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

tree_node *WeaveTree::endnote(heterogeneous_tree *tree, text_stream *P) {
	weave_endnote_node *C = CREATE(weave_endnote_node);
	C->text = Str::duplicate(P);
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

tree_node *WeaveTree::chm(heterogeneous_tree *tree, 
	int old_material, int new_material, int content, int plainly) {
	weave_chm_node *C = CREATE(weave_chm_node);
	C->old_material = old_material;
	C->new_material = new_material;
	C->content = content;
	C->plainly = plainly;
	return Trees::new_node(tree, weave_chm_node_type, STORE_POINTER_weave_chm_node(C));
}

tree_node *WeaveTree::embed(heterogeneous_tree *tree,
	text_stream *service, text_stream *ID) {
	weave_embed_node *C = CREATE(weave_embed_node);
	C->service = Str::duplicate(service);
	C->ID = Str::duplicate(ID);
	return Trees::new_node(tree, weave_embed_node_type, STORE_POINTER_weave_embed_node(C));
}

tree_node *WeaveTree::weave_pmac_node(heterogeneous_tree *tree) {
	weave_pmac_node *C = CREATE(weave_pmac_node);
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

tree_node *WeaveTree::weave_apres_defn_node(heterogeneous_tree *tree) {
	weave_apres_defn_node *C = CREATE(weave_apres_defn_node);
	return Trees::new_node(tree, weave_apres_defn_node_type, STORE_POINTER_weave_apres_defn_node(C));
}

tree_node *WeaveTree::weave_change_colour_node(heterogeneous_tree *tree) {
	weave_change_colour_node *C = CREATE(weave_change_colour_node);
	return Trees::new_node(tree, weave_change_colour_node_type, STORE_POINTER_weave_change_colour_node(C));
}

tree_node *WeaveTree::weave_text_node(heterogeneous_tree *tree) {
	weave_text_node *C = CREATE(weave_text_node);
	return Trees::new_node(tree, weave_text_node_type, STORE_POINTER_weave_text_node(C));
}

tree_node *WeaveTree::weave_comment_node(heterogeneous_tree *tree) {
	weave_comment_node *C = CREATE(weave_comment_node);
	return Trees::new_node(tree, weave_comment_node_type, STORE_POINTER_weave_comment_node(C));
}

tree_node *WeaveTree::weave_link_node(heterogeneous_tree *tree) {
	weave_link_node *C = CREATE(weave_link_node);
	return Trees::new_node(tree, weave_link_node_type, STORE_POINTER_weave_link_node(C));
}

tree_node *WeaveTree::weave_commentary_node(heterogeneous_tree *tree) {
	weave_commentary_node *C = CREATE(weave_commentary_node);
	return Trees::new_node(tree, weave_commentary_node_type, STORE_POINTER_weave_commentary_node(C));
}

tree_node *WeaveTree::weave_preform_document_node(heterogeneous_tree *tree) {
	weave_preform_document_node *C = CREATE(weave_preform_document_node);
	return Trees::new_node(tree, weave_preform_document_node_type, STORE_POINTER_weave_preform_document_node(C));
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

tree_node *WeaveTree::weave_source_fragment_node(heterogeneous_tree *tree) {
	weave_source_fragment_node *C = CREATE(weave_source_fragment_node);
	return Trees::new_node(tree, weave_source_fragment_node_type, STORE_POINTER_weave_source_fragment_node(C));
}

tree_node *WeaveTree::weave_source_code_node(heterogeneous_tree *tree) {
	weave_source_code_node *C = CREATE(weave_source_code_node);
	return Trees::new_node(tree, weave_source_code_node_type, STORE_POINTER_weave_source_code_node(C));
}

tree_node *WeaveTree::weave_url_node(heterogeneous_tree *tree) {
	weave_url_node *C = CREATE(weave_url_node);
	return Trees::new_node(tree, weave_url_node_type, STORE_POINTER_weave_url_node(C));
}

tree_node *WeaveTree::weave_footnote_cue_node(heterogeneous_tree *tree) {
	weave_footnote_cue_node *C = CREATE(weave_footnote_cue_node);
	return Trees::new_node(tree, weave_footnote_cue_node_type, STORE_POINTER_weave_footnote_cue_node(C));
}

tree_node *WeaveTree::weave_begin_footnote_text_node(heterogeneous_tree *tree) {
	weave_begin_footnote_text_node *C = CREATE(weave_begin_footnote_text_node);
	return Trees::new_node(tree, weave_begin_footnote_text_node_type, STORE_POINTER_weave_begin_footnote_text_node(C));
}

tree_node *WeaveTree::weave_end_footnote_text_node(heterogeneous_tree *tree) {
	weave_end_footnote_text_node *C = CREATE(weave_end_footnote_text_node);
	return Trees::new_node(tree, weave_end_footnote_text_node_type, STORE_POINTER_weave_end_footnote_text_node(C));
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

void WeaveTree::show(text_stream *OUT, heterogeneous_tree *T) {
	WRITE("%S\n", T->type->name);
	INDENT;
	Debugging::render(NULL, OUT, T);
	OUTDENT;
}
