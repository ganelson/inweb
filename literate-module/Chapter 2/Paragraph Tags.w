[ParagraphTags::] Paragraph Tags.

To mark certain paragraphs in the literate source as having some significance.

@ A "tagging" occurs when a paragraph is marked with a given tag, and perhaps
also with a contextually relevant caption. The following records those;
they're stored as a linked list within each paragraph.

=
typedef struct literate_source_tagging {
	struct text_stream *the_tag;
	struct text_stream *caption;
	CLASS_DEFINITION
} literate_source_tagging;

void ParagraphTags::tag_with_caption(ls_paragraph *par, text_stream *tag, text_stream *caption) {
	if (Str::len(tag) == 0) internal_error("empty tag name");
	if (par) {
		if (par->taggings == NULL) par->taggings = NEW_LINKED_LIST(literate_source_tagging);
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if ((Str::eq(pt->the_tag, tag)) && (Str::eq(pt->caption, caption)))
				return;
		pt = CREATE(literate_source_tagging);
		pt->the_tag = Str::duplicate(tag);
		if (caption) pt->caption = Str::duplicate(caption);
		else pt->caption = Str::new();
		ADD_TO_LINKED_LIST(pt, literate_source_tagging, par->taggings);
	}
}

@ Tags are created simply by being used in taggings. If the tag notation
|^"History: How tags came about"| is found, the following is called, and
the tag is |History|, the caption "How tags came about".

=
void ParagraphTags::tag(ls_paragraph *par, text_stream *text) {
	if (Str::len(text) == 0) internal_error("empty tag name");
	if (par) {
		TEMPORARY_TEXT(name) Str::copy(name, text);
		TEMPORARY_TEXT(caption)
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, name, U"(%c+?): (%c+)")) {
			Str::copy(name, mr.exp[0]);
			Str::copy(caption, mr.exp[1]);
		}
		ParagraphTags::tag_with_caption(par, name, caption);
		DISCARD_TEXT(name)
		DISCARD_TEXT(caption)
		Regexp::dispose_of(&mr);
	}
}

@ If a given line is tagged with a given tag, what caption does it have?

=
text_stream *ParagraphTags::retrieve_caption(ls_paragraph *par, text_stream *tag) {
	if (Str::len(tag) == 0) return NULL;
	if ((par) && (par->taggings)) {
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if (Str::eq(tag, pt->the_tag))
				return pt->caption;
	}
	return NULL;
}

@ And this tests whether a given paragraph falls under a given tag.
(Everything falls under the null non-tag: this ensures that a weave which
doesn't specify a tag will include everything.)

=
int ParagraphTags::is_tagged_with(ls_paragraph *par, text_stream *tag) {
	if (Str::len(tag) == 0) return TRUE; /* see above! */
	if ((par) && (par->taggings)) {
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if (Str::eq(tag, pt->the_tag))
				return TRUE;
	}
	return FALSE;
}

@ So here we are! Splendid, is it not.

=
void ParagraphTags::autotag(weave_order *wv, ls_paragraph *par, markdown_item *md) {
	markdown_variation *variation = MarkdownVariations::Inweb_flavoured_Markdown();
	if (md) {
		switch (md->type) {
			case IMAGE_MIT: ParagraphTags::tag(par, I"Figures"); break;
			case TABLE_MIT: ParagraphTags::tag(par, I"Tables"); break;
			case INWEB_LINK_MIT: {
				TEMPORARY_TEXT(address)
				TEMPORARY_TEXT(URL)
				MDRenderer::recurse(address, NULL, md->down, RAW_MDRMODE, variation);
				if (Colonies::is_reference_external(address, URL))
					ParagraphTags::tag_with_caption(par, I"Outlinks", URL);
				DISCARD_TEXT(URL)
				DISCARD_TEXT(address)
				break;
			}
			case LINK_DEST_MIT: {
				TEMPORARY_TEXT(address)
				MDRenderer::recurse(address, NULL, md, RAW_MDRMODE, variation);
				if (Colonies::is_reference_external(address, NULL))
					ParagraphTags::tag_with_caption(par, I"Outlinks", address);
				DISCARD_TEXT(address)
				break;
			}
		}
		for (markdown_item *c = md->down; c; c = c->next)
			ParagraphTags::autotag(wv, par, c);
	}
}

@ This uses the captions on Outlinks tags to produce a table of external links:

=
void ParagraphTags::tabulate_links(OUTPUT_STREAM, ls_web *W, text_stream *range, int fully) {
	int nx = 0;
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if ((C->owning_module == W->main_module) || (fully)) {
			ls_section *S;
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				if (WebRanges::is_within(WebRanges::of(S), range))
					for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par) {
						literate_source_tagging *pt;
						LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
							if (Str::eq(pt->the_tag, I"Outlinks"))
								nx++;
					}
		}
	if (nx == 0) {
		WRITE("(no external links are present)\n");
		return;
	}

	textual_table *T = TextualTables::new_table();
	WRITE_TO(TextualTables::next_cell(T), "from");
	WRITE_TO(TextualTables::next_cell(T), "external URL");
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if ((C->owning_module == W->main_module) || (fully)) {
			ls_section *S;
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				if (WebRanges::is_within(WebRanges::of(S), range))
					for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par) {
						literate_source_tagging *pt;
						LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
							if (Str::eq(pt->the_tag, I"Outlinks")) {
								TextualTables::begin_row(T);
								text_stream *R = TextualTables::next_cell(T);
								ls_section *S = LiterateSource::section_of_par(par);
								if ((S) && (W->is_page == FALSE)) WRITE_TO(R, "%S:", S->sect_range);
								WRITE_TO(R, "%S", par->paragraph_number);
								WRITE_TO(TextualTables::next_cell(T), "%S", pt->caption);
							}
					}
		}	
	TextualTables::tabulate(OUT, T);
}

@ This can be used to inspect the tags in use:

=
void ParagraphTags::tabulate(OUTPUT_STREAM, ls_web *W, text_stream *range, int fully) {
	dictionary *concordance = Dictionaries::new(32, FALSE);
	linked_list *keys = NEW_LINKED_LIST(text_stream);
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if ((C->owning_module == W->main_module) || (fully)) {
			ls_section *S;
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				if (WebRanges::is_within(WebRanges::of(S), range)) {
					for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
						if ((par->taggings) && (LinkedLists::len(par->taggings) > 0)) {
							literate_source_tagging *pt;
							LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings) {
								dict_entry *de = Dictionaries::find(concordance, pt->the_tag);
								linked_list *L = NULL;
								if (de) {
									L = (linked_list *) Dictionaries::value_for_entry(de);
								} else {
									L = NEW_LINKED_LIST(ls_paragraph);
									Dictionaries::create(concordance, pt->the_tag);
									Dictionaries::write_value(concordance, pt->the_tag, L);
									ADD_TO_LINKED_LIST(pt->the_tag, text_stream, keys);
								}
								ADD_TO_LINKED_LIST(par, ls_paragraph, L);
							}
						}
				}
		}
	if (LinkedLists::len(keys) > 0) {
		textual_table *T = TextualTables::new_table();
		WRITE_TO(TextualTables::next_cell(T), "tag");
		WRITE_TO(TextualTables::next_cell(T), "paragraphs tagged");
		text_stream *tag;
		LOOP_OVER_LINKED_LIST(tag, text_stream, keys) {
			dict_entry *de = Dictionaries::find(concordance, tag);
			if (de == NULL) internal_error("dictionary broken");
			linked_list *L = (linked_list *) Dictionaries::value_for_entry(de);
			TextualTables::begin_row(T);
			WRITE_TO(TextualTables::next_cell(T), "%S", tag);
			text_stream *R = TextualTables::next_cell(T);
			ls_paragraph *par;
			int c = 0;
			LOOP_OVER_LINKED_LIST(par, ls_paragraph, L) {
				if (c++ > 0) WRITE_TO(R, ", ");
				ls_section *S = LiterateSource::section_of_par(par);
				if ((S) && (W->is_page == FALSE)) WRITE_TO(R, "%S:", S->sect_range);
				WRITE_TO(R, "%S", par->paragraph_number);
				if ((c == 8) && (LinkedLists::len(L) > 9)) {
					WRITE_TO(R, "... (%d in all)", LinkedLists::len(L));
					break;
				}
			}
		}
		TextualTables::tabulate_sorted(OUT, T, 0);
	} else {
		WRITE("(no paragraphs are tagged)\n");
	}
}
