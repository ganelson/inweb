[FoundationClasses::] Foundation Classes.

To declare the object classes used in the Foundation module.

@ These class declarations would ordinarily go at the front of a module,
by convention, in an early section of its Chapter 1. //foundation// is an
exception because it's the module which defines the memory manager: class
declarations have to come after that point in the tangled code. But now
here we are.

@e chapter_md_CLASS
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
@e HTML_file_state_CLASS
@e HTML_tag_CLASS
@e JSON_pair_requirement_CLASS
@e JSON_requirement_CLASS
@e JSON_single_requirement_CLASS
@e JSON_type_CLASS
@e JSON_value_CLASS
@e linked_list_CLASS
@e linked_list_item_CLASS
@e markdown_item_CLASS
@e match_avinue_CLASS
@e match_trie_CLASS
@e md_doc_reference_CLASS
@e method_CLASS
@e method_set_CLASS
@e module_CLASS
@e module_search_CLASS
@e pathname_CLASS
@e md_emphasis_delimiter_CLASS
@e preprocessor_macro_CLASS
@e preprocessor_macro_parameter_CLASS
@e preprocessor_variable_CLASS
@e preprocessor_variable_set_CLASS
@e programming_language_CLASS
@e reserved_word_CLASS
@e scan_directory_CLASS
@e section_md_CLASS
@e semantic_version_number_holder_CLASS
@e semver_range_CLASS
@e stopwatch_timer_CLASS
@e string_storage_area_CLASS
@e text_stream_CLASS
@e tree_node_CLASS
@e tree_node_type_CLASS
@e tree_type_CLASS
@e web_bibliographic_datum_CLASS
@e web_md_CLASS

=
DECLARE_CLASS(chapter_md)
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
DECLARE_CLASS(JSON_pair_requirement)
DECLARE_CLASS(JSON_requirement)
DECLARE_CLASS(JSON_single_requirement)
DECLARE_CLASS(JSON_type)
DECLARE_CLASS(JSON_value)
DECLARE_CLASS(linked_list)
DECLARE_CLASS(method_set)
DECLARE_CLASS(method)
DECLARE_CLASS(module_search)
DECLARE_CLASS(module)
DECLARE_CLASS(pathname)
DECLARE_CLASS(preprocessor_macro)
DECLARE_CLASS(preprocessor_macro_parameter)
DECLARE_CLASS(preprocessor_variable)
DECLARE_CLASS(preprocessor_variable_set)
DECLARE_CLASS(programming_language)
DECLARE_CLASS(reserved_word)
DECLARE_CLASS(scan_directory)
DECLARE_CLASS(section_md)
DECLARE_CLASS(semantic_version_number_holder)
DECLARE_CLASS(semver_range)
DECLARE_CLASS(stopwatch_timer)
DECLARE_CLASS(string_storage_area)
DECLARE_CLASS(tree_node_type)
DECLARE_CLASS(tree_node)
DECLARE_CLASS(tree_type)
DECLARE_CLASS(web_bibliographic_datum)
DECLARE_CLASS(web_md)

DECLARE_CLASS_ALLOCATED_IN_ARRAYS(dict_entry, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(HTML_tag, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(linked_list_item, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(markdown_item, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(match_avinue, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(match_trie, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(md_doc_reference, 100)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(md_emphasis_delimiter, 1000)
DECLARE_CLASS_ALLOCATED_IN_ARRAYS(text_stream, 100)
