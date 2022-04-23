[Basics::] Basics.

Some fundamental definitions, mostly declaring object types to the Foundation
module.

@ Every program using //foundation// must define this:

@d PROGRAM_NAME "inweb"

@ We need to itemise the structures we'll want to allocate. For explanations,
see //foundation: A Brief Guide to Foundation//.

@e asset_rule_CLASS
@e breadcrumb_request_CLASS
@e chapter_CLASS
@e colony_CLASS
@e colony_member_CLASS
@e colour_scheme_CLASS
@e colouring_language_block_CLASS
@e colouring_rule_CLASS
@e defined_constant_CLASS
@e enumeration_set_CLASS
@e footnote_CLASS
@e hash_table_entry_CLASS
@e hash_table_entry_usage_CLASS
@e language_function_CLASS
@e language_type_CLASS
@e macro_CLASS
@e macro_tokens_CLASS
@e macro_usage_CLASS
@e makefile_specifics_CLASS
@e nonterminal_variable_CLASS
@e para_macro_CLASS
@e paragraph_CLASS
@e paragraph_tagging_CLASS
@e preform_nonterminal_CLASS
@e programming_language_CLASS
@e reserved_word_CLASS
@e section_CLASS
@e source_line_CLASS
@e structure_element_CLASS
@e tangle_target_CLASS
@e tex_results_CLASS
@e text_literal_CLASS
@e theme_tag_CLASS
@e weave_format_CLASS
@e weave_pattern_CLASS
@e weave_plugin_CLASS
@e weave_order_CLASS
@e web_CLASS
@e writeme_asset_CLASS

@e weave_document_node_CLASS
@e weave_head_node_CLASS
@e weave_body_node_CLASS
@e weave_tail_node_CLASS
@e weave_section_header_node_CLASS
@e weave_section_footer_node_CLASS
@e weave_chapter_header_node_CLASS
@e weave_chapter_footer_node_CLASS
@e weave_verbatim_node_CLASS
@e weave_section_purpose_node_CLASS
@e weave_subheading_node_CLASS
@e weave_bar_node_CLASS
@e weave_linebreak_node_CLASS
@e weave_pagebreak_node_CLASS
@e weave_paragraph_heading_node_CLASS
@e weave_endnote_node_CLASS
@e weave_material_node_CLASS
@e weave_figure_node_CLASS
@e weave_extract_node_CLASS
@e weave_audio_node_CLASS
@e weave_download_node_CLASS
@e weave_video_node_CLASS
@e weave_embed_node_CLASS
@e weave_pmac_node_CLASS
@e weave_vskip_node_CLASS
@e weave_chapter_node_CLASS
@e weave_section_node_CLASS
@e weave_code_line_node_CLASS
@e weave_function_usage_node_CLASS
@e weave_commentary_node_CLASS
@e weave_carousel_slide_node_CLASS
@e weave_toc_node_CLASS
@e weave_toc_line_node_CLASS
@e weave_chapter_title_page_node_CLASS
@e weave_defn_node_CLASS
@e weave_source_code_node_CLASS
@e weave_url_node_CLASS
@e weave_footnote_cue_node_CLASS
@e weave_begin_footnote_text_node_CLASS
@e weave_display_line_node_CLASS
@e weave_function_defn_node_CLASS
@e weave_item_node_CLASS
@e weave_grammar_index_node_CLASS
@e weave_inline_node_CLASS
@e weave_locale_node_CLASS
@e weave_maths_node_CLASS

@ And then expand the following macros, all defined in //Memory//.

=
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(source_line, 1000)
DECLARE_CLASS(asset_rule)
DECLARE_CLASS(breadcrumb_request)
DECLARE_CLASS(chapter)
DECLARE_CLASS(colony)
DECLARE_CLASS(colony_member)
DECLARE_CLASS(colour_scheme)
DECLARE_CLASS(colouring_language_block)
DECLARE_CLASS(colouring_rule)
DECLARE_CLASS(defined_constant)
DECLARE_CLASS(enumeration_set)
DECLARE_CLASS(footnote)
DECLARE_CLASS(hash_table_entry_usage)
DECLARE_CLASS(hash_table_entry)
DECLARE_CLASS(language_function)
DECLARE_CLASS(language_type)
DECLARE_CLASS(macro_tokens)
DECLARE_CLASS(macro_usage)
DECLARE_CLASS(macro)
DECLARE_CLASS(makefile_specifics)
DECLARE_CLASS(nonterminal_variable)
DECLARE_CLASS(para_macro)
DECLARE_CLASS(paragraph_tagging)
DECLARE_CLASS(paragraph)
DECLARE_CLASS(preform_nonterminal)
DECLARE_CLASS(programming_language)
DECLARE_CLASS(reserved_word)
DECLARE_CLASS(section)
DECLARE_CLASS(structure_element)
DECLARE_CLASS(tangle_target)
DECLARE_CLASS(tex_results)
DECLARE_CLASS(text_literal)
DECLARE_CLASS(theme_tag)
DECLARE_CLASS(weave_format)
DECLARE_CLASS(weave_pattern)
DECLARE_CLASS(weave_plugin)
DECLARE_CLASS(weave_order)
DECLARE_CLASS(web)
DECLARE_CLASS(writeme_asset)

DECLARE_CLASS(weave_document_node)
DECLARE_CLASS(weave_head_node)
DECLARE_CLASS(weave_body_node)
DECLARE_CLASS(weave_tail_node)
DECLARE_CLASS(weave_section_header_node)
DECLARE_CLASS(weave_section_footer_node)
DECLARE_CLASS(weave_chapter_header_node)
DECLARE_CLASS(weave_chapter_footer_node)
DECLARE_CLASS(weave_verbatim_node)
DECLARE_CLASS(weave_section_purpose_node)
DECLARE_CLASS(weave_subheading_node)
DECLARE_CLASS(weave_bar_node)
DECLARE_CLASS(weave_linebreak_node)
DECLARE_CLASS(weave_pagebreak_node)
DECLARE_CLASS(weave_paragraph_heading_node)
DECLARE_CLASS(weave_endnote_node)
DECLARE_CLASS(weave_material_node)
DECLARE_CLASS(weave_figure_node)
DECLARE_CLASS(weave_extract_node)
DECLARE_CLASS(weave_audio_node)
DECLARE_CLASS(weave_video_node)
DECLARE_CLASS(weave_download_node)
DECLARE_CLASS(weave_embed_node)
DECLARE_CLASS(weave_pmac_node)
DECLARE_CLASS(weave_vskip_node)
DECLARE_CLASS(weave_chapter_node)
DECLARE_CLASS(weave_section_node)
DECLARE_CLASS(weave_code_line_node)
DECLARE_CLASS(weave_function_usage_node)
DECLARE_CLASS(weave_commentary_node)
DECLARE_CLASS(weave_carousel_slide_node)
DECLARE_CLASS(weave_toc_node)
DECLARE_CLASS(weave_toc_line_node)
DECLARE_CLASS(weave_chapter_title_page_node)
DECLARE_CLASS(weave_defn_node)
DECLARE_CLASS(weave_source_code_node)
DECLARE_CLASS(weave_url_node)
DECLARE_CLASS(weave_footnote_cue_node)
DECLARE_CLASS(weave_begin_footnote_text_node)
DECLARE_CLASS(weave_display_line_node)
DECLARE_CLASS(weave_item_node)
DECLARE_CLASS(weave_grammar_index_node)
DECLARE_CLASS(weave_inline_node)
DECLARE_CLASS(weave_locale_node)
DECLARE_CLASS(weave_maths_node)
DECLARE_CLASS(weave_function_defn_node)
