[Tags::] Tags.

Thematic tags can be attached to certain paragraphs, some automatically by
Inweb, others manually by the author.

@ A tag really is just a textual name. Each differently-named tag leads
to one of the following being created:

=
typedef struct theme_tag {
	struct text_stream *tag_name;
	int ifdef_positive;
	struct text_stream *ifdef_symbol;
	MEMORY_MANAGEMENT
} theme_tag;

@ Here we find a tag from its name, case-sensitively. On each run of Inweb,
there's just a single namespace of all known tags. There are never very
many differently-named tags in a given web.

=
theme_tag *Tags::find_by_name(text_stream *name, int creating_if_necessary) {
	theme_tag *tag;
	LOOP_OVER(tag, theme_tag)
		if (Str::eq(name, tag->tag_name))
			return tag;
	if (creating_if_necessary) {
		tag = CREATE(theme_tag);
		tag->tag_name = Str::duplicate(name);
		tag->ifdef_positive = NOT_APPLICABLE;
		tag->ifdef_symbol = Str::new();
		if (Str::prefix_eq(name, I"ifdef-", 6)) {
			Str::substr(tag->ifdef_symbol, Str::at(name, 6), Str::end(name));
			tag->ifdef_positive = TRUE;
		} else if (Str::prefix_eq(name, I"ifndef-", 7)) {
			Str::substr(tag->ifdef_symbol, Str::at(name, 7), Str::end(name));
			tag->ifdef_positive = FALSE;
		}
		LanguageMethods::new_tag_declared(tag);
		return tag;
	}
	return NULL;
}

@ A "tagging" occurs when a paragraph is marked with a given tag, and perhaps
also with a contextually relevant caption. The following records those;
they're stored as a linked list within each paragraph.

=
typedef struct paragraph_tagging {
	struct theme_tag *the_tag;
	struct text_stream *caption;
	MEMORY_MANAGEMENT
} paragraph_tagging;

void Tags::add_to_paragraph(paragraph *P, theme_tag *tag, text_stream *caption) {
	if (P) {
		paragraph_tagging *pt = CREATE(paragraph_tagging);
		pt->the_tag = tag;
		if (caption) pt->caption = Str::duplicate(caption);
		else pt->caption = Str::new();
		ADD_TO_LINKED_LIST(pt, paragraph_tagging, P->taggings);
	}
}

@ Tags are created simply by being used in taggings. If the tag notation
|^"History: How tags came about"| is found, the following is called, and
the tag is |History|, the caption "How tags came about".

=
theme_tag *Tags::add_by_name(paragraph *P, text_stream *text) {
	if (Str::len(text) == 0) internal_error("empty tag name");
	TEMPORARY_TEXT(name); Str::copy(name, text);
	TEMPORARY_TEXT(caption);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, name, L"(%c+?): (%c+)")) {
		Str::copy(name, mr.exp[0]);
		Str::copy(caption, mr.exp[1]);
	}
	theme_tag *tag = Tags::find_by_name(name, TRUE);
	if (P) Tags::add_to_paragraph(P, tag, caption);
	DISCARD_TEXT(name);
	DISCARD_TEXT(caption);
	Regexp::dispose_of(&mr);
	return tag;
}

@ If a given line is tagged with a given tag, what caption does it have?

=
text_stream *Tags::retrieve_caption(paragraph *P, theme_tag *tag) {
	if (tag == NULL) return NULL;
	if (P) {
		paragraph_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, paragraph_tagging, P->taggings)
			if (tag == pt->the_tag)
				return pt->caption;
	}
	return NULL;
}

@ Finally, this tests whether a given paragraph falls under a given tag.
(Everything falls under the null non-tag: this ensures that a weave which
doesn't specify a tag.)

=
int Tags::tagged_with(paragraph *P, theme_tag *tag) {
	if (tag == NULL) return TRUE;
	if (P) {
		paragraph_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, paragraph_tagging, P->taggings)
			if (tag == pt->the_tag)
				return TRUE;
	}
	return FALSE;
}

@ =
void Tags::open_ifdefs(OUTPUT_STREAM, paragraph *P) {
	paragraph_tagging *pt;
	LOOP_OVER_LINKED_LIST(pt, paragraph_tagging, P->taggings)
		if (Str::len(pt->the_tag->ifdef_symbol) > 0)
			LanguageMethods::open_ifdef(OUT,
				P->under_section->sect_language, pt->the_tag->ifdef_symbol, pt->the_tag->ifdef_positive);
}

void Tags::close_ifdefs(OUTPUT_STREAM, paragraph *P) {
	paragraph_tagging *pt;
	LOOP_OVER_LINKED_LIST(pt, paragraph_tagging, P->taggings)
		if (Str::len(pt->the_tag->ifdef_symbol) > 0)
			LanguageMethods::close_ifdef(OUT,
				P->under_section->sect_language, pt->the_tag->ifdef_symbol, pt->the_tag->ifdef_positive);
}

void Tags::show_endnote_on_ifdefs(heterogeneous_tree *tree, tree_node *ap, paragraph *P) {
	int d = 0, sense = TRUE;
	@<Show ifdef endnoting@>;
	sense = FALSE;
	@<Show ifdef endnoting@>;
	if (d > 0) TextWeaver::commentary_text(tree, ap, I".");
}

@<Show ifdef endnoting@> =
	int c = 0;
	paragraph_tagging *pt;
	LOOP_OVER_LINKED_LIST(pt, paragraph_tagging, P->taggings)
		if (pt->the_tag->ifdef_positive == sense)
			if (Str::len(pt->the_tag->ifdef_symbol) > 0) {
				if (c++ == 0) {
					if (d++ == 0) {
						tree_node *E = WeaveTree::endnote(tree);
						Trees::make_child(E, ap); ap = E;
						TextWeaver::commentary_text(tree, ap, I"This paragraph is used only if ");
					} else {
						TextWeaver::commentary_text(tree, ap, I" and if ");
					}
				} else {
					TextWeaver::commentary_text(tree, ap, I" and ");
				}
				TextWeaver::commentary_text(tree, ap, pt->the_tag->ifdef_symbol);
			}
	if (c > 0) {
		if (c == 1) TextWeaver::commentary_text(tree, ap, I" is");
		else TextWeaver::commentary_text(tree, ap, I" are");
		if (sense) TextWeaver::commentary_text(tree, ap, I" defined");
		else TextWeaver::commentary_text(tree, ap, I" undefined");
	}
