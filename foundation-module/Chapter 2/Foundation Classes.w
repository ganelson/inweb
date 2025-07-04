[FoundationClasses::] Foundation Classes.

To declare the object classes used in the Foundation module.

@ These class declarations would ordinarily go at the front of a module,
by convention, in an early section of its Chapter 1. //foundation// is an
exception because it's the module which defines the memory manager: class
declarations have to come after that point in the tangled code. But now
here we are.

@e ls_chapter_CLASS
@e colouring_language_block_CLASS
@e colouring_rule_CLASS
@e command_line_switch_CLASS
@e debugging_aspect_CLASS
@e dict_entry_CLASS
@e dictionary_CLASS
@e ebook_chapter_CLASS
@e ebook_CLASS
@e ebook_datum_CLASS
@e ebook_image_CLASS
@e ebook_mark_CLASS
@e ebook_page_CLASS
@e ebook_volume_CLASS
@e filename_CLASS
@e hash_table_entry_CLASS
@e heterogeneous_tree_CLASS
@e holon_usage_CLASS
@e HTML_file_state_CLASS
@e HTML_tag_CLASS
@e IFM_example_CLASS
@e JSON_pair_requirement_CLASS
@e JSON_requirement_CLASS
@e JSON_single_requirement_CLASS
@e JSON_type_CLASS
@e JSON_value_CLASS
@e linked_list_CLASS
@e linked_list_item_CLASS
@e ls_chunk_CLASS
@e ls_holon_CLASS
@e ls_holon_scanner_CLASS
@e holon_splice_CLASS
@e ls_error_CLASS
@e ls_footnote_CLASS
@e ls_paragraph_CLASS
@e ls_line_CLASS
@e literate_source_tagging_CLASS
@e ls_unit_CLASS
@e markdown_item_CLASS
@e markdown_feature_CLASS
@e markdown_variation_CLASS
@e match_avinue_CLASS
@e match_trie_CLASS
@e md_link_dictionary_entry_CLASS
@e method_CLASS
@e method_set_CLASS
@e ls_module_CLASS
@e module_search_CLASS
@e pathname_CLASS
@e md_doc_state_CLASS
@e md_links_dictionary_CLASS
@e md_emphasis_delimiter_CLASS
@e open_source_licence_CLASS
@e preprocessor_macro_CLASS
@e preprocessor_macro_parameter_CLASS
@e preprocessor_variable_CLASS
@e preprocessor_variable_set_CLASS
@e programming_language_CLASS
@e reserved_word_CLASS
@e scan_directory_CLASS
@e ls_section_CLASS
@e semantic_version_number_holder_CLASS
@e semver_range_CLASS
@e stopwatch_timer_CLASS
@e string_storage_area_CLASS
@e tangle_target_CLASS
@e text_stream_CLASS
@e tree_node_CLASS
@e tree_node_type_CLASS
@e tree_type_CLASS
@e web_bibliographic_datum_CLASS
@e ls_web_CLASS
@e ls_syntax_CLASS
@e ls_syntax_rule_CLASS
@e finite_state_machine_CLASS
@e fsm_state_CLASS
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
@e colony_CLASS
@e colony_member_CLASS
@e colour_scheme_CLASS
@e macro_usage_CLASS
@e makefile_specifics_CLASS
@e para_macro_CLASS
@e ls_section_weaving_details_CLASS
@e tex_results_CLASS
@e weave_format_CLASS
@e weave_pattern_CLASS
@e weave_plugin_CLASS
@e weave_order_CLASS
@e ls_web_weaving_details_CLASS
@e writeme_asset_CLASS
@e fsm_transition_CLASS

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
@e weave_markdown_node_CLASS

=
DECLARE_CLASS(ls_chapter)
DECLARE_CLASS(colouring_language_block)
DECLARE_CLASS(colouring_rule)
DECLARE_CLASS(command_line_switch)
DECLARE_CLASS(debugging_aspect)
DECLARE_CLASS(dictionary)
DECLARE_CLASS(ebook_chapter)
DECLARE_CLASS(ebook_datum)
DECLARE_CLASS(ebook_image)
DECLARE_CLASS(ebook_mark)
DECLARE_CLASS(ebook_page)
DECLARE_CLASS(ebook_volume)
DECLARE_CLASS(ebook)
DECLARE_CLASS(filename)
DECLARE_CLASS(hash_table_entry)
DECLARE_CLASS(heterogeneous_tree)
DECLARE_CLASS(HTML_file_state)
DECLARE_CLASS(IFM_example)
DECLARE_CLASS(JSON_pair_requirement)
DECLARE_CLASS(JSON_requirement)
DECLARE_CLASS(JSON_single_requirement)
DECLARE_CLASS(JSON_type)
DECLARE_CLASS(JSON_value)
DECLARE_CLASS(linked_list)
DECLARE_CLASS(ls_unit)
DECLARE_CLASS(ls_error)
DECLARE_CLASS(markdown_feature)
DECLARE_CLASS(markdown_variation)
DECLARE_CLASS(md_doc_state)
DECLARE_CLASS(md_links_dictionary)
DECLARE_CLASS(method_set)
DECLARE_CLASS(method)
DECLARE_CLASS(module_search)
DECLARE_CLASS(ls_module)
DECLARE_CLASS(open_source_licence)
DECLARE_CLASS(pathname)
DECLARE_CLASS(preprocessor_macro)
DECLARE_CLASS(preprocessor_macro_parameter)
DECLARE_CLASS(preprocessor_variable)
DECLARE_CLASS(preprocessor_variable_set)
DECLARE_CLASS(programming_language)
DECLARE_CLASS(reserved_word)
DECLARE_CLASS(scan_directory)
DECLARE_CLASS(ls_section)
DECLARE_CLASS(semantic_version_number_holder)
DECLARE_CLASS(semver_range)
DECLARE_CLASS(stopwatch_timer)
DECLARE_CLASS(string_storage_area)
DECLARE_CLASS(tangle_target)
DECLARE_CLASS(tree_node_type)
DECLARE_CLASS(tree_node)
DECLARE_CLASS(tree_type)
DECLARE_CLASS(web_bibliographic_datum)
DECLARE_CLASS(ls_web)
DECLARE_CLASS(ls_syntax)
DECLARE_CLASS(ls_syntax_rule)
DECLARE_CLASS(finite_state_machine)
DECLARE_CLASS(fsm_state)
DECLARE_CLASS(ls_holon_scanner)
DECLARE_CLASS(nonterminal_variable)
DECLARE_CLASS(preform_nonterminal)
DECLARE_CLASS(text_literal)
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
DECLARE_CLASS(colony)
DECLARE_CLASS(colony_member)
DECLARE_CLASS(colour_scheme)
DECLARE_CLASS(makefile_specifics)
DECLARE_CLASS(ls_section_weaving_details)
DECLARE_CLASS(tex_results)
DECLARE_CLASS(weave_format)
DECLARE_CLASS(weave_pattern)
DECLARE_CLASS(weave_plugin)
DECLARE_CLASS(weave_order)
DECLARE_CLASS(ls_web_weaving_details)
DECLARE_CLASS(writeme_asset)
DECLARE_CLASS(fsm_transition)

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
DECLARE_CLASS(weave_markdown_node)
DECLARE_CLASS(weave_function_defn_node)

DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_line_analysis, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(dict_entry, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(holon_usage, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(HTML_tag, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(linked_list_item, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_chunk, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_holon, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(holon_splice, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_paragraph, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_line, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(ls_footnote, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(literate_source_tagging, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(markdown_item, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(match_avinue, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(match_trie, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(md_link_dictionary_entry, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(md_emphasis_delimiter, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(text_stream, 100)
