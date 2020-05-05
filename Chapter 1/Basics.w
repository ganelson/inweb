[Basics::] Basics.

Some fundamental definitions, mostly declaring object types to the Foundation
module.

@ Every program using //foundation// must define this:

@d PROGRAM_NAME "inweb"

@ We need to itemise the structures we'll want to allocate. For explanations,
see //foundation: A Brief Guide to Foundation//.

@e asset_rule_MT
@e breadcrumb_request_MT
@e chapter_MT
@e colony_MT
@e colony_member_MT
@e colour_scheme_MT
@e colouring_language_block_MT
@e colouring_rule_MT
@e enumeration_set_MT
@e footnote_MT
@e hash_table_entry_MT
@e hash_table_entry_usage_MT
@e language_function_MT
@e language_type_MT
@e macro_MT
@e macro_tokens_MT
@e macro_usage_MT
@e nonterminal_variable_MT
@e para_macro_MT
@e paragraph_MT
@e paragraph_tagging_MT
@e preform_nonterminal_MT
@e programming_language_MT
@e reserved_word_MT
@e section_MT
@e source_line_array_MT
@e structure_element_MT
@e tangle_target_MT
@e tex_results_MT
@e text_literal_MT
@e theme_tag_MT
@e weave_format_MT
@e weave_pattern_MT
@e weave_plugin_MT
@e weave_order_MT
@e web_MT
@e writeme_asset_MT

@e weave_document_node_MT
@e weave_head_node_MT
@e weave_body_node_MT
@e weave_tail_node_MT
@e weave_section_header_node_MT
@e weave_section_footer_node_MT
@e weave_chapter_header_node_MT
@e weave_chapter_footer_node_MT
@e weave_verbatim_node_MT
@e weave_section_purpose_node_MT
@e weave_subheading_node_MT
@e weave_bar_node_MT
@e weave_linebreak_node_MT
@e weave_pagebreak_node_MT
@e weave_paragraph_heading_node_MT
@e weave_endnote_node_MT
@e weave_material_node_MT
@e weave_figure_node_MT
@e weave_audio_node_MT
@e weave_download_node_MT
@e weave_video_node_MT
@e weave_embed_node_MT
@e weave_pmac_node_MT
@e weave_vskip_node_MT
@e weave_chapter_node_MT
@e weave_section_node_MT
@e weave_code_line_node_MT
@e weave_function_usage_node_MT
@e weave_commentary_node_MT
@e weave_carousel_slide_node_MT
@e weave_toc_node_MT
@e weave_toc_line_node_MT
@e weave_chapter_title_page_node_MT
@e weave_defn_node_MT
@e weave_source_code_node_MT
@e weave_url_node_MT
@e weave_footnote_cue_node_MT
@e weave_begin_footnote_text_node_MT
@e weave_display_line_node_MT
@e weave_function_defn_node_MT
@e weave_item_node_MT
@e weave_grammar_index_node_MT
@e weave_inline_node_MT
@e weave_locale_node_MT
@e weave_maths_node_MT

@ And then expand the following macros, all defined in //Memory//.

=
ALLOCATE_IN_ARRAYS(source_line, 1000)
ALLOCATE_INDIVIDUALLY(asset_rule)
ALLOCATE_INDIVIDUALLY(breadcrumb_request)
ALLOCATE_INDIVIDUALLY(chapter)
ALLOCATE_INDIVIDUALLY(colony)
ALLOCATE_INDIVIDUALLY(colony_member)
ALLOCATE_INDIVIDUALLY(colour_scheme)
ALLOCATE_INDIVIDUALLY(colouring_language_block)
ALLOCATE_INDIVIDUALLY(colouring_rule)
ALLOCATE_INDIVIDUALLY(enumeration_set)
ALLOCATE_INDIVIDUALLY(footnote)
ALLOCATE_INDIVIDUALLY(hash_table_entry_usage)
ALLOCATE_INDIVIDUALLY(hash_table_entry)
ALLOCATE_INDIVIDUALLY(language_function)
ALLOCATE_INDIVIDUALLY(language_type)
ALLOCATE_INDIVIDUALLY(macro_tokens)
ALLOCATE_INDIVIDUALLY(macro_usage)
ALLOCATE_INDIVIDUALLY(macro)
ALLOCATE_INDIVIDUALLY(nonterminal_variable)
ALLOCATE_INDIVIDUALLY(para_macro)
ALLOCATE_INDIVIDUALLY(paragraph_tagging)
ALLOCATE_INDIVIDUALLY(paragraph)
ALLOCATE_INDIVIDUALLY(preform_nonterminal)
ALLOCATE_INDIVIDUALLY(programming_language)
ALLOCATE_INDIVIDUALLY(reserved_word)
ALLOCATE_INDIVIDUALLY(section)
ALLOCATE_INDIVIDUALLY(structure_element)
ALLOCATE_INDIVIDUALLY(tangle_target)
ALLOCATE_INDIVIDUALLY(tex_results)
ALLOCATE_INDIVIDUALLY(text_literal)
ALLOCATE_INDIVIDUALLY(theme_tag)
ALLOCATE_INDIVIDUALLY(weave_format)
ALLOCATE_INDIVIDUALLY(weave_pattern)
ALLOCATE_INDIVIDUALLY(weave_plugin)
ALLOCATE_INDIVIDUALLY(weave_order)
ALLOCATE_INDIVIDUALLY(web)
ALLOCATE_INDIVIDUALLY(writeme_asset)

ALLOCATE_INDIVIDUALLY(weave_document_node)
ALLOCATE_INDIVIDUALLY(weave_head_node)
ALLOCATE_INDIVIDUALLY(weave_body_node)
ALLOCATE_INDIVIDUALLY(weave_tail_node)
ALLOCATE_INDIVIDUALLY(weave_section_header_node)
ALLOCATE_INDIVIDUALLY(weave_section_footer_node)
ALLOCATE_INDIVIDUALLY(weave_chapter_header_node)
ALLOCATE_INDIVIDUALLY(weave_chapter_footer_node)
ALLOCATE_INDIVIDUALLY(weave_verbatim_node)
ALLOCATE_INDIVIDUALLY(weave_section_purpose_node)
ALLOCATE_INDIVIDUALLY(weave_subheading_node)
ALLOCATE_INDIVIDUALLY(weave_bar_node)
ALLOCATE_INDIVIDUALLY(weave_linebreak_node)
ALLOCATE_INDIVIDUALLY(weave_pagebreak_node)
ALLOCATE_INDIVIDUALLY(weave_paragraph_heading_node)
ALLOCATE_INDIVIDUALLY(weave_endnote_node)
ALLOCATE_INDIVIDUALLY(weave_material_node)
ALLOCATE_INDIVIDUALLY(weave_figure_node)
ALLOCATE_INDIVIDUALLY(weave_audio_node)
ALLOCATE_INDIVIDUALLY(weave_video_node)
ALLOCATE_INDIVIDUALLY(weave_download_node)
ALLOCATE_INDIVIDUALLY(weave_embed_node)
ALLOCATE_INDIVIDUALLY(weave_pmac_node)
ALLOCATE_INDIVIDUALLY(weave_vskip_node)
ALLOCATE_INDIVIDUALLY(weave_chapter_node)
ALLOCATE_INDIVIDUALLY(weave_section_node)
ALLOCATE_INDIVIDUALLY(weave_code_line_node)
ALLOCATE_INDIVIDUALLY(weave_function_usage_node)
ALLOCATE_INDIVIDUALLY(weave_commentary_node)
ALLOCATE_INDIVIDUALLY(weave_carousel_slide_node)
ALLOCATE_INDIVIDUALLY(weave_toc_node)
ALLOCATE_INDIVIDUALLY(weave_toc_line_node)
ALLOCATE_INDIVIDUALLY(weave_chapter_title_page_node)
ALLOCATE_INDIVIDUALLY(weave_defn_node)
ALLOCATE_INDIVIDUALLY(weave_source_code_node)
ALLOCATE_INDIVIDUALLY(weave_url_node)
ALLOCATE_INDIVIDUALLY(weave_footnote_cue_node)
ALLOCATE_INDIVIDUALLY(weave_begin_footnote_text_node)
ALLOCATE_INDIVIDUALLY(weave_display_line_node)
ALLOCATE_INDIVIDUALLY(weave_item_node)
ALLOCATE_INDIVIDUALLY(weave_grammar_index_node)
ALLOCATE_INDIVIDUALLY(weave_inline_node)
ALLOCATE_INDIVIDUALLY(weave_locale_node)
ALLOCATE_INDIVIDUALLY(weave_maths_node)
ALLOCATE_INDIVIDUALLY(weave_function_defn_node)
