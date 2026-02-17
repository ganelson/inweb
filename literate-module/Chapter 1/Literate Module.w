[LiterateModule::] Literate Module.

Setting up the use of this module.

@ This section simply sets up the module in ways expected by //foundation//, and
contains no code of interest. The following constant exists only in tools
which use this module:

@d LITERATE_MODULE TRUE

@ This module defines the following classes:

@e hash_table_entry_CLASS
@e wcl_declaration_CLASS
@e wcl_error_CLASS
@e ls_chapter_CLASS
@e ls_section_CLASS
@e programming_language_CLASS
@e reserved_word_CLASS
@e tangle_target_CLASS
@e ls_module_CLASS
@e ls_chunk_CLASS
@e ls_holon_CLASS
@e ls_holon_scanner_CLASS
@e holon_splice_CLASS
@e ls_holon_namespace_CLASS
@e ls_error_CLASS
@e ls_footnote_CLASS
@e ls_paragraph_CLASS
@e ls_line_CLASS
@e literate_source_tagging_CLASS
@e ls_unit_CLASS
@e web_bibliographic_datum_CLASS
@e ls_web_CLASS
@e ls_notation_CLASS
@e ls_notation_rule_CLASS
@e nonterminal_variable_CLASS
@e preform_nonterminal_CLASS
@e text_literal_CLASS
@e ls_web_analysis_CLASS
@e ls_line_analysis_CLASS
@e ls_paragraph_analysis_CLASS
@e hash_table_entry_usage_CLASS
@e defined_constant_CLASS
@e enumeration_set_CLASS
@e language_function_CLASS
@e language_type_CLASS
@e structure_element_CLASS
@e asset_rule_CLASS
@e breadcrumb_request_CLASS
@e ls_chapter_weaving_details_CLASS
@e ls_colony_CLASS
@e ls_colony_member_CLASS
@e colour_scheme_CLASS
@e macro_usage_CLASS
@e makefile_specifics_CLASS
@e para_macro_CLASS
@e ls_section_weaving_details_CLASS
@e tex_results_CLASS
@e weave_format_CLASS
@e ls_pattern_CLASS
@e ls_pattern_pair_CLASS
@e weave_plugin_CLASS
@e weave_order_CLASS
@e ls_web_weaving_details_CLASS
@e writeme_asset_CLASS
@e colouring_language_block_CLASS
@e colouring_rule_CLASS
@e weave_copy_record_CLASS
@e ls_conventions_CLASS
@e notation_rewriter_CLASS
@e notation_rewriting_machine_CLASS
@e inweb_reference_data_CLASS
@e tangle_external_file_CLASS
@e ls_index_CLASS
@e ls_index_mark_CLASS
@e ls_index_lemma_CLASS
@e ls_code_excerpt_CLASS
@e ls_classifier_CLASS
@e custom_colour_CLASS
@e pl_regexp_set_CLASS

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
@e weave_subsubheading_node_CLASS
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
@e weave_holon_usage_node_CLASS
@e weave_tangler_command_node_CLASS
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
@e weave_holon_declaration_node_CLASS
@e weave_defn_node_CLASS
@e weave_source_code_node_CLASS
@e weave_comment_in_holon_node_CLASS
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
@e weave_markdown_node_CLASS
@e weave_index_marker_node_CLASS

=
DECLARE_CLASS(hash_table_entry)
DECLARE_CLASS(colouring_language_block)
DECLARE_CLASS(colouring_rule)
DECLARE_CLASS(ls_unit)
DECLARE_CLASS(ls_error)
DECLARE_CLASS(module_search)
DECLARE_CLASS(ls_module)
DECLARE_CLASS(programming_language)
DECLARE_CLASS(reserved_word)
DECLARE_CLASS(ls_chapter)
DECLARE_CLASS(wcl_declaration)
DECLARE_CLASS(wcl_error)
DECLARE_CLASS(tangle_target)
DECLARE_CLASS(web_bibliographic_datum)
DECLARE_CLASS(ls_web)
DECLARE_CLASS(ls_notation)
DECLARE_CLASS(ls_notation_rule)
DECLARE_CLASS(ls_holon_scanner)
DECLARE_CLASS(ls_web_analysis)
DECLARE_CLASS(ls_paragraph_analysis)
DECLARE_CLASS(hash_table_entry_usage)
DECLARE_CLASS(defined_constant)
DECLARE_CLASS(enumeration_set)
DECLARE_CLASS(language_function)
DECLARE_CLASS(language_type)
DECLARE_CLASS(structure_element)
DECLARE_CLASS(asset_rule)
DECLARE_CLASS(breadcrumb_request)
DECLARE_CLASS(ls_chapter_weaving_details)
DECLARE_CLASS(ls_colony)
DECLARE_CLASS(ls_colony_member)
DECLARE_CLASS(ls_section_weaving_details)
DECLARE_CLASS(makefile_specifics)
DECLARE_CLASS(tex_results)
DECLARE_CLASS(weave_format)
DECLARE_CLASS(ls_pattern)
DECLARE_CLASS(ls_pattern_pair)
DECLARE_CLASS(weave_plugin)
DECLARE_CLASS(weave_order)
DECLARE_CLASS(ls_web_weaving_details)
DECLARE_CLASS(writeme_asset)
DECLARE_CLASS(ls_section)
DECLARE_CLASS(colour_scheme)
DECLARE_CLASS(nonterminal_variable)
DECLARE_CLASS(preform_nonterminal)
DECLARE_CLASS(text_literal)
DECLARE_CLASS(weave_copy_record)
DECLARE_CLASS(ls_holon_namespace)
DECLARE_CLASS(ls_conventions)
DECLARE_CLASS(notation_rewriter)
DECLARE_CLASS(notation_rewriting_machine)
DECLARE_CLASS(inweb_reference_data)
DECLARE_CLASS(tangle_external_file)
DECLARE_CLASS(ls_index)
DECLARE_CLASS(ls_index_mark)
DECLARE_CLASS(ls_index_lemma)
DECLARE_CLASS(ls_code_excerpt)
DECLARE_CLASS(ls_classifier)
DECLARE_CLASS(custom_colour)
DECLARE_CLASS(pl_regexp_set)

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
DECLARE_CLASS(weave_subsubheading_node)
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
DECLARE_CLASS(weave_holon_usage_node)
DECLARE_CLASS(weave_tangler_command_node)
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
DECLARE_CLASS(weave_holon_declaration_node)
DECLARE_CLASS(weave_defn_node)
DECLARE_CLASS(weave_source_code_node)
DECLARE_CLASS(weave_comment_in_holon_node)
DECLARE_CLASS(weave_url_node)
DECLARE_CLASS(weave_footnote_cue_node)
DECLARE_CLASS(weave_begin_footnote_text_node)
DECLARE_CLASS(weave_display_line_node)
DECLARE_CLASS(weave_item_node)
DECLARE_CLASS(weave_grammar_index_node)
DECLARE_CLASS(weave_inline_node)
DECLARE_CLASS(weave_locale_node)
DECLARE_CLASS(weave_maths_node)
DECLARE_CLASS(weave_markdown_node)
DECLARE_CLASS(weave_function_defn_node)
DECLARE_CLASS(weave_index_marker_node)

DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_line_analysis, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(holon_usage, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_chunk, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_holon, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(holon_splice, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_paragraph, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_line, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_footnote, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(literate_source_tagging, 100)


@ Like all modules, this one must define a |start| and |end| function:

=
void LiterateModule::start(void) {
}

void LiterateModule::end(void) {
}
