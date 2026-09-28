[WeaveTree::] Weave Tree.

The weaver produces a tree of rendering instructions as its main intermediate
representation, and this section defines that tree.

@h Tree and node type declarations.
The data structure here is a heterogenous tree — see //foundation: Trees// for
more on this, but the idea is that a weave tree can have as its nodes structures
of any of some 39 classes.

This inevitably means an awful lot of tedious structure declarations and
creator functions. This section contains nothing else, and will have succeeded
if it is perfectly boring from beginning to end.

To begin, we need to declare the types of node which can occur in the tree.
These will be presented in the same standardised order wherever we deal with
them.

Document superstructure:

=
tree_node_type *weave_document_node_type = NULL;
tree_node_type *weave_head_node_type = NULL;
tree_node_type *weave_body_node_type = NULL;
tree_node_type *weave_tail_node_type = NULL;

@ Large-scale structure:

=
tree_node_type *weave_chapter_node_type = NULL;
tree_node_type *weave_chapter_header_node_type = NULL;
tree_node_type *weave_chapter_footer_node_type = NULL;
tree_node_type *weave_section_node_type = NULL;
tree_node_type *weave_section_header_node_type = NULL;
tree_node_type *weave_section_footer_node_type = NULL;
tree_node_type *weave_section_purpose_node_type = NULL;
tree_node_type *weave_toc_node_type = NULL;
tree_node_type *weave_toc_line_node_type = NULL;

@ Small-scale structure:

=
tree_node_type *weave_subheading_node_type = NULL;
tree_node_type *weave_subsubheading_node_type = NULL;
tree_node_type *weave_paragraph_heading_node_type = NULL;
tree_node_type *weave_material_node_type = NULL;

@ Code-like material:

=
tree_node_type *weave_holon_declaration_node_type = NULL;
tree_node_type *weave_code_line_node_type = NULL;
tree_node_type *weave_holon_usage_node_type = NULL;
tree_node_type *weave_tangler_command_node_type = NULL;
tree_node_type *weave_verbatim_node_type = NULL;
tree_node_type *weave_source_code_node_type = NULL;
tree_node_type *weave_function_defn_node_type = NULL;
tree_node_type *weave_function_usage_node_type = NULL;
tree_node_type *weave_comment_in_holon_node_type = NULL;
tree_node_type *weave_defn_node_type = NULL;

@ Commentary and gadget material:

=
tree_node_type *weave_markdown_node_type = NULL;
tree_node_type *weave_audio_node_type = NULL;
tree_node_type *weave_carousel_slide_node_type = NULL;
tree_node_type *weave_download_node_type = NULL;
tree_node_type *weave_embed_node_type = NULL;
tree_node_type *weave_figure_node_type = NULL;
tree_node_type *weave_raw_HTML_node_type = NULL;
tree_node_type *weave_video_node_type = NULL;

@ Paragraph tail material:

=
tree_node_type *weave_index_begins_node_type = NULL;
tree_node_type *weave_index_lemma_node_type = NULL;
tree_node_type *weave_index_ends_node_type = NULL;
tree_node_type *weave_endnote_node_type = NULL;
tree_node_type *weave_locale_node_type = NULL;
tree_node_type *weave_endnote_text_node_type = NULL;

@ Now the function to create a heterogeneous weave tree: it begins with a
single (root) node, of type `weave_document_node_type`.

On first being called, this function declares the tree type, and with it all
of the above node types, so that the many `tree_node_type *` pointers above
are no longer `NULL`.

@d DECLARE_WEAVENODE(T, DESC) T##_type = Trees::new_node_type(DESC, T##_CLASS, NULL);

=
tree_type *weave_tree_type = NULL;

heterogeneous_tree *WeaveTree::new_tree(weave_order *wv, int footnotes_present) {
	if (weave_tree_type == NULL) {
		weave_tree_type = Trees::new_type(I"weave tree", NULL);

		/* Document superstructure */
		DECLARE_WEAVENODE(weave_document_node, I"document");
		DECLARE_WEAVENODE(weave_head_node, I"head");
		DECLARE_WEAVENODE(weave_body_node, I"body");
		DECLARE_WEAVENODE(weave_tail_node, I"tail");

		/* Large-scale structure */
		DECLARE_WEAVENODE(weave_chapter_node, I"chapter");
		DECLARE_WEAVENODE(weave_chapter_header_node, I"chapter header");
		DECLARE_WEAVENODE(weave_chapter_footer_node, I"chapter footer");
		DECLARE_WEAVENODE(weave_section_node, I"section");
		DECLARE_WEAVENODE(weave_section_header_node, I"section header");
		DECLARE_WEAVENODE(weave_section_footer_node, I"section footer");
		DECLARE_WEAVENODE(weave_section_purpose_node, I"section purpose");
		DECLARE_WEAVENODE(weave_toc_node, I"toc");
		DECLARE_WEAVENODE(weave_toc_line_node, I"toc line");

		/* Small-scale structure */
		DECLARE_WEAVENODE(weave_subheading_node, I"subheading");
		DECLARE_WEAVENODE(weave_subsubheading_node, I"subsubheading");
		DECLARE_WEAVENODE(weave_paragraph_heading_node, I"paragraph heading");
		DECLARE_WEAVENODE(weave_material_node, I"material");

		/* Code-like material */
		DECLARE_WEAVENODE(weave_holon_declaration_node, I"holon declaration");
		DECLARE_WEAVENODE(weave_code_line_node, I"code line");
		DECLARE_WEAVENODE(weave_holon_usage_node, I"holon usage");
		DECLARE_WEAVENODE(weave_tangler_command_node, I"tangler command");
		DECLARE_WEAVENODE(weave_verbatim_node, I"verbatim");
		DECLARE_WEAVENODE(weave_source_code_node, I"source code");
		DECLARE_WEAVENODE(weave_function_defn_node, I"function defn");
		DECLARE_WEAVENODE(weave_function_usage_node, I"function usage");
		DECLARE_WEAVENODE(weave_comment_in_holon_node, I"comment in holon");
		DECLARE_WEAVENODE(weave_defn_node, I"defn");

		/* Commentary and gadget material */
		DECLARE_WEAVENODE(weave_markdown_node, I"markdown");
		DECLARE_WEAVENODE(weave_audio_node, I"audio");
		DECLARE_WEAVENODE(weave_carousel_slide_node, I"carousel slide");
		DECLARE_WEAVENODE(weave_download_node, I"download");
		DECLARE_WEAVENODE(weave_embed_node, I"embed");
		DECLARE_WEAVENODE(weave_figure_node, I"figure");
		DECLARE_WEAVENODE(weave_raw_HTML_node, I"raw HTML");
		DECLARE_WEAVENODE(weave_video_node, I"video");

		/* Paragraph tail material */
		DECLARE_WEAVENODE(weave_index_begins_node, I"index begins");
		DECLARE_WEAVENODE(weave_index_lemma_node, I"index lemma");
		DECLARE_WEAVENODE(weave_index_ends_node, I"index ends");
		DECLARE_WEAVENODE(weave_endnote_node, I"endnote");
		DECLARE_WEAVENODE(weave_locale_node, I"locale");
		DECLARE_WEAVENODE(weave_endnote_text_node, I"endnote text");
	}
	heterogeneous_tree *tree = Trees::new(weave_tree_type);
	Trees::make_root(tree, WeaveTree::document(tree, wv, footnotes_present));
	return tree;
}

@h Document superstructure creators.
The weave tree always contains just one of these, as its root node.

@d CREATE_WEAVENODE(T) T *N = CREATE(T);
@d RETURN_WEAVENODE(T) return Trees::new_node(tree, T##_type, STORE_POINTER_##T(N));

=
classdef weave_document_node {
	struct weave_order *wv;
	int footnotes_present;
}
tree_node *WeaveTree::document(heterogeneous_tree *tree, weave_order *wv,
	int footnotes_present) {
	CREATE_WEAVENODE(weave_document_node);
	N->wv = wv;
	N->footnotes_present = footnotes_present;
	RETURN_WEAVENODE(weave_document_node);
}

classdef weave_head_node {
	struct text_stream *banner;
}
tree_node *WeaveTree::head(heterogeneous_tree *tree, text_stream *banner) {
	CREATE_WEAVENODE(weave_head_node);
	N->banner = Str::duplicate(banner);
	RETURN_WEAVENODE(weave_head_node);
}

classdef weave_body_node {
}
tree_node *WeaveTree::body(heterogeneous_tree *tree) {
	CREATE_WEAVENODE(weave_body_node);
	RETURN_WEAVENODE(weave_body_node);
}

classdef weave_tail_node {
	struct text_stream *rennab;
}
tree_node *WeaveTree::tail(heterogeneous_tree *tree, text_stream *rennab) {
	CREATE_WEAVENODE(weave_tail_node);
	N->rennab = Str::duplicate(rennab);
	RETURN_WEAVENODE(weave_tail_node);
}

@h Large-scale structure creators.

=
classdef weave_chapter_node {
	struct ls_chapter *chap;
}
tree_node *WeaveTree::chapter(heterogeneous_tree *tree, ls_chapter *Ch) {
	CREATE_WEAVENODE(weave_chapter_node);
	N->chap = Ch;
	RETURN_WEAVENODE(weave_chapter_node);
}

classdef weave_chapter_header_node {
	struct ls_chapter *chap;
}
tree_node *WeaveTree::chapter_header(heterogeneous_tree *tree, ls_chapter *Ch) {
	CREATE_WEAVENODE(weave_chapter_header_node);
	N->chap = Ch;
	RETURN_WEAVENODE(weave_chapter_header_node);
}

classdef weave_chapter_footer_node {
	struct ls_chapter *chap;
}
tree_node *WeaveTree::chapter_footer(heterogeneous_tree *tree, ls_chapter *Ch) {
	CREATE_WEAVENODE(weave_chapter_footer_node);
	N->chap = Ch;
	RETURN_WEAVENODE(weave_chapter_footer_node);
}

classdef weave_section_node {
	struct ls_section *sect;
}
tree_node *WeaveTree::section(heterogeneous_tree *tree, ls_section *sect) {
	CREATE_WEAVENODE(weave_section_node);
	N->sect = sect;
	RETURN_WEAVENODE(weave_section_node);
}

classdef weave_section_header_node {
	struct ls_section *sect;
}
tree_node *WeaveTree::section_header(heterogeneous_tree *tree, ls_section *S) {
	CREATE_WEAVENODE(weave_section_header_node);
	N->sect = S;
	RETURN_WEAVENODE(weave_section_header_node);
}

classdef weave_section_footer_node {
	struct ls_section *sect;
}
tree_node *WeaveTree::section_footer(heterogeneous_tree *tree, ls_section *S) {
	CREATE_WEAVENODE(weave_section_footer_node);
	N->sect = S;
	RETURN_WEAVENODE(weave_section_footer_node);
}

classdef weave_section_purpose_node {
	struct text_stream *purpose;
}
tree_node *WeaveTree::purpose(heterogeneous_tree *tree, text_stream *P) {
	CREATE_WEAVENODE(weave_section_purpose_node);
	N->purpose = Str::duplicate(P);
	RETURN_WEAVENODE(weave_section_purpose_node);
}

classdef weave_toc_node {
	struct text_stream *text1;
}
tree_node *WeaveTree::table_of_contents(heterogeneous_tree *tree, text_stream *text1) {
	CREATE_WEAVENODE(weave_toc_node);
	N->text1 = Str::duplicate(text1);
	RETURN_WEAVENODE(weave_toc_node);
}

classdef weave_toc_line_node {
	struct text_stream *text1;
	struct text_stream *text2;
	struct ls_paragraph *para;
}
tree_node *WeaveTree::contents_line(heterogeneous_tree *tree,
	text_stream *text1, text_stream *text2, ls_paragraph *par) {
	CREATE_WEAVENODE(weave_toc_line_node);
	N->text1 = Str::duplicate(text1);
	N->text2 = Str::duplicate(text2);
	N->para = par;
	RETURN_WEAVENODE(weave_toc_line_node);
}

@h Small-scale structure creators.

=
classdef weave_subheading_node {
	struct text_stream *text;
}
tree_node *WeaveTree::subheading(heterogeneous_tree *tree, text_stream *P) {
	CREATE_WEAVENODE(weave_subheading_node);
	N->text = Str::duplicate(P);
	RETURN_WEAVENODE(weave_subheading_node);
}

classdef weave_subsubheading_node {
	struct text_stream *text;
}
tree_node *WeaveTree::subsubheading(heterogeneous_tree *tree, text_stream *P) {
	CREATE_WEAVENODE(weave_subsubheading_node);
	N->text = Str::duplicate(P);
	RETURN_WEAVENODE(weave_subsubheading_node);
}

classdef weave_paragraph_heading_node {
	struct ls_paragraph *para;
	int no_skip;
}
tree_node *WeaveTree::paragraph_heading(heterogeneous_tree *tree,
	ls_paragraph *par, int no_skip) {
	CREATE_WEAVENODE(weave_paragraph_heading_node);
	N->para = par;
	N->no_skip = no_skip;
	RETURN_WEAVENODE(weave_paragraph_heading_node);
}

classdef weave_material_node {
	int material_type;
	int plainly;
	struct programming_language *styling;
	struct text_stream *endnote;
}
tree_node *WeaveTree::material(heterogeneous_tree *tree, int material_type, int plainly,
	programming_language *styling, text_stream *endnote) {
	CREATE_WEAVENODE(weave_material_node);
	N->material_type = material_type;
	N->plainly = plainly;
	N->styling = styling;
	N->endnote = Str::duplicate(endnote);
	RETURN_WEAVENODE(weave_material_node);
}

@h Code-like material creators.

=
classdef weave_holon_declaration_node {
	struct ls_holon *holon;
	struct markdown_variation *variation;
}
tree_node *WeaveTree::holon_declaration(heterogeneous_tree *tree, ls_holon *holon,
	markdown_variation *variation) {
	CREATE_WEAVENODE(weave_holon_declaration_node);
	N->holon = holon;
	N->variation = variation;
	RETURN_WEAVENODE(weave_holon_declaration_node);
}

classdef weave_code_line_node {
	struct ls_line *line;
}
tree_node *WeaveTree::code_line(heterogeneous_tree *tree, ls_line *line) {
	CREATE_WEAVENODE(weave_code_line_node);
	N->line = line;
	RETURN_WEAVENODE(weave_code_line_node);
}

classdef weave_holon_usage_node {
	struct ls_holon *holon;
	struct markdown_variation *variation;
}
tree_node *WeaveTree::holon_usage(heterogeneous_tree *tree, ls_holon *holon,
	markdown_variation *variation) {
	CREATE_WEAVENODE(weave_holon_usage_node);
	N->holon = holon;
	N->variation = variation;
	RETURN_WEAVENODE(weave_holon_usage_node);
}

classdef weave_tangler_command_node {
	struct text_stream *command;
}
tree_node *WeaveTree::tangler_command(heterogeneous_tree *tree, text_stream *cmd) {
	CREATE_WEAVENODE(weave_tangler_command_node);
	N->command = Str::duplicate(cmd);
	RETURN_WEAVENODE(weave_tangler_command_node);
}

classdef weave_verbatim_node {
	struct text_stream *content;
}
tree_node *WeaveTree::verbatim(heterogeneous_tree *tree, text_stream *content) {
	CREATE_WEAVENODE(weave_verbatim_node);
	N->content = Str::duplicate(content);
	RETURN_WEAVENODE(weave_verbatim_node);
}

classdef weave_source_code_node {
	struct text_stream *matter;
	struct text_stream *colouring;
}
tree_node *WeaveTree::source_code(heterogeneous_tree *tree,
	text_stream *matter, text_stream *colouring) {
	CREATE_WEAVENODE(weave_source_code_node);
	N->matter = Str::duplicate(matter);
	N->colouring = Str::duplicate(colouring);
	RETURN_WEAVENODE(weave_source_code_node);
}

classdef weave_function_defn_node {
	struct language_function *fn;
	int local_usages;
	int local_direction;
	int section_usages;
	int external_usages;
	struct hash_table_entry_usage *hteu;
}
tree_node *WeaveTree::function_defn(heterogeneous_tree *tree, language_function *fn,
	int local_usages, int local_direction, int section_usages, int external_usages,
	hash_table_entry_usage *hteu) {
	CREATE_WEAVENODE(weave_function_defn_node);
	N->fn = fn;
	N->local_usages = local_usages; N->local_direction = local_direction;
	N->section_usages = section_usages; N->external_usages = external_usages;
	N->hteu = hteu;
	RETURN_WEAVENODE(weave_function_defn_node);
}

classdef weave_function_usage_node {
	struct text_stream *url;
	struct language_function *fn;
}
tree_node *WeaveTree::function_usage(heterogeneous_tree *tree,
	text_stream *url, language_function *fn) {
	CREATE_WEAVENODE(weave_function_usage_node);
	N->url = Str::duplicate(url);
	N->fn = fn;
	RETURN_WEAVENODE(weave_function_usage_node);
}

classdef weave_comment_in_holon_node {
	struct text_stream *raw;
	struct text_stream *comment_open;
	struct text_stream *comment_close;
	struct markdown_item *as_markdown;
	struct markdown_variation *variation;
}
tree_node *WeaveTree::comment_in_holon(heterogeneous_tree *tree, text_stream *raw,
	text_stream *open, text_stream *close, markdown_item *as_markdown,
	markdown_variation *variation) {
	CREATE_WEAVENODE(weave_comment_in_holon_node);
	N->raw = Str::duplicate(raw);
	N->comment_open = Str::duplicate(open);
	N->comment_close = Str::duplicate(close);
	N->as_markdown = as_markdown;
	N->variation = variation;
	RETURN_WEAVENODE(weave_comment_in_holon_node);
}

classdef weave_defn_node {
	struct text_stream *keyword;
	struct text_stream *symbol;
}
tree_node *WeaveTree::weave_defn_node(heterogeneous_tree *tree, text_stream *keyword,
	text_stream *symbol) {
	CREATE_WEAVENODE(weave_defn_node);
	N->keyword = Str::duplicate(keyword);
	N->symbol = Str::duplicate(symbol);
	RETURN_WEAVENODE(weave_defn_node);
}

@h Commentary and gadget material creators.

=
classdef weave_markdown_node {
	struct markdown_item *content;
	struct ls_line *nearby_line;
	struct markdown_variation *variation;
}
tree_node *WeaveTree::Markdown_commentary(heterogeneous_tree *tree,
	markdown_item *content, ls_line *nearby_line, markdown_variation *variation) {
	CREATE_WEAVENODE(weave_markdown_node);
	N->content = content;
	N->nearby_line = nearby_line;
	N->variation = variation;
	RETURN_WEAVENODE(weave_markdown_node);
}

classdef weave_audio_node {
	struct text_stream *audio_name;
	int w;
}
tree_node *WeaveTree::audio(heterogeneous_tree *tree, 
	text_stream *audio_name, int w) {
	CREATE_WEAVENODE(weave_audio_node);
	N->audio_name = Str::duplicate(audio_name);
	N->w = w;
	RETURN_WEAVENODE(weave_audio_node);
}

classdef weave_carousel_slide_node {
	struct text_stream *caption;
	int positioning;
	int slide_number;
	int slide_of;
}
tree_node *WeaveTree::carousel_slide(heterogeneous_tree *tree, text_stream *caption,
	int positioning, int slide_number, int slide_of) {
	CREATE_WEAVENODE(weave_carousel_slide_node);
	N->caption = Str::duplicate(caption);
	N->positioning = positioning;
	N->slide_number = slide_number;
	N->slide_of = slide_of;
	RETURN_WEAVENODE(weave_carousel_slide_node);
}

classdef weave_download_node {
	struct text_stream *download_name;
	struct text_stream *filetype;
}
tree_node *WeaveTree::download(heterogeneous_tree *tree, 
	text_stream *download_name, text_stream *filetype) {
	CREATE_WEAVENODE(weave_download_node);
	N->download_name = Str::duplicate(download_name);
	N->filetype = Str::duplicate(filetype);
	RETURN_WEAVENODE(weave_download_node);
}

classdef weave_embed_node {
	struct text_stream *service;
	struct text_stream *ID;
	int w;
	int h;
}
tree_node *WeaveTree::embed(heterogeneous_tree *tree,
	text_stream *service, text_stream *ID, int w, int h) {
	CREATE_WEAVENODE(weave_embed_node);
	N->service = Str::duplicate(service);
	N->ID = Str::duplicate(ID);
	N->w = w;
	N->h = h;
	RETURN_WEAVENODE(weave_embed_node);
}

classdef weave_figure_node {
	struct text_stream *figname;
	struct text_stream *alt_text;
	int w;
	int h;
}
tree_node *WeaveTree::figure(heterogeneous_tree *tree, 
	text_stream *figname, text_stream *alt_text, int w, int h) {
	CREATE_WEAVENODE(weave_figure_node);
	N->figname = Str::duplicate(figname);
	N->alt_text = Str::duplicate(alt_text);
	N->w = w;
	N->h = h;
	RETURN_WEAVENODE(weave_figure_node);
}

classdef weave_raw_HTML_node {
	struct text_stream *extract;
}
tree_node *WeaveTree::raw_HTML(heterogeneous_tree *tree, 
	text_stream *extract) {
	CREATE_WEAVENODE(weave_raw_HTML_node);
	N->extract = Str::duplicate(extract);
	RETURN_WEAVENODE(weave_raw_HTML_node);
}

classdef weave_video_node {
	struct text_stream *video_name;
	int w;
	int h;
}
tree_node *WeaveTree::video(heterogeneous_tree *tree, 
	text_stream *video_name, int w, int h) {
	CREATE_WEAVENODE(weave_video_node);
	N->video_name = Str::duplicate(video_name);
	N->w = w;
	RETURN_WEAVENODE(weave_video_node);
}

@h Paragraph tail material creators.

=
classdef weave_index_begins_node {
	struct ls_paragraph *par;
}
tree_node *WeaveTree::index_begins(heterogeneous_tree *tree, ls_paragraph *par) {
	CREATE_WEAVENODE(weave_index_begins_node);
	N->par = par;
	RETURN_WEAVENODE(weave_index_begins_node);
}

classdef weave_index_lemma_node {
	struct ls_paragraph *par;
	struct ls_index_lemma *lemma;
}
tree_node *WeaveTree::index_lemma(heterogeneous_tree *tree, ls_paragraph *par,
	ls_index_lemma *lemma) {
	CREATE_WEAVENODE(weave_index_lemma_node);
	N->par = par;
	N->lemma = lemma;
	RETURN_WEAVENODE(weave_index_lemma_node);
}

classdef weave_index_ends_node {
	struct ls_paragraph *par;
}
tree_node *WeaveTree::index_ends(heterogeneous_tree *tree, ls_paragraph *par) {
	CREATE_WEAVENODE(weave_index_ends_node);
	N->par = par;
	RETURN_WEAVENODE(weave_index_ends_node);
}

classdef weave_endnote_node {
}
tree_node *WeaveTree::endnote(heterogeneous_tree *tree) {
	CREATE_WEAVENODE(weave_endnote_node);
	RETURN_WEAVENODE(weave_endnote_node);
}

classdef weave_locale_node {
	struct ls_paragraph *par1;
	struct ls_line *finer;
	struct ls_paragraph *par2;
	int distant;
}
tree_node *WeaveTree::locale(heterogeneous_tree *tree, ls_paragraph *par1,
	ls_line *finer, ls_paragraph *par2, int distant) {
	CREATE_WEAVENODE(weave_locale_node);
	N->par1 = par1;
	N->finer = finer;
	N->par2 = par2;
	N->distant = distant;
	RETURN_WEAVENODE(weave_locale_node);
}

classdef weave_endnote_text_node {
	struct text_stream *text;
}
tree_node *WeaveTree::endnote_text(heterogeneous_tree *tree, text_stream *text) {
	CREATE_WEAVENODE(weave_endnote_text_node);
	N->text = Str::duplicate(text);
	RETURN_WEAVENODE(weave_endnote_text_node);
}
