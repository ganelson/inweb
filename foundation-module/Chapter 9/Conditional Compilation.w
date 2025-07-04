[IfdefTags::] Conditional Compilation.

Thematic tags can be used to mark code as being included in a tangle but
only within markers for conditional compilation.

@h Tag representation.
Paragraph tagging is used to mark that code should be conditional. For
example, a para which should be included only if |WINDOWS| is defined
should be tagged |ifdef-WINDOWS|. The "valency" of that tag is 1, and
the "identifier" is |WINDOWS|.

=
int IfdefTags::ifdef_valency(text_stream *tag) {
	if (Str::begins_with(tag, I"ifdef-")) return 1;
	if (Str::begins_with(tag, I"ifndef-")) return -1;
	return 0;
}

void IfdefTags::conditional_identifier(OUTPUT_STREAM, text_stream *tag) {
	switch (IfdefTags::ifdef_valency(tag)) {
		case 1: Str::substr(OUT, Str::at(tag, 6), Str::end(tag)); break;
		case -1: Str::substr(OUT, Str::at(tag, 7), Str::end(tag)); break;
	}
}

@h Effect on tangling.

=
void IfdefTags::open_ifdefs(OUTPUT_STREAM, ls_paragraph *par) {
	if ((par) && (par->taggings)) {
		TEMPORARY_TEXT(identifier)
		ls_section *S = LiterateSource::section_of_par(par);
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings) {
			switch (IfdefTags::ifdef_valency(pt->the_tag)) {
				case 1:
					Str::clear(identifier);
					IfdefTags::conditional_identifier(identifier, pt->the_tag);
					LanguageMethods::open_ifdef(OUT, S->sect_language, identifier, TRUE);
					break;
				case -1:
					Str::clear(identifier);
					IfdefTags::conditional_identifier(identifier, pt->the_tag);
					LanguageMethods::open_ifdef(OUT, S->sect_language, identifier, FALSE);
					break;
			}
		}
		DISCARD_TEXT(identifier)
	}
}

@ This should arguably close the conditionals in reverse order, but it's a
nuisance to loop backwards through a singly-linked list, and it doesn't really
matter in practice.

=
void IfdefTags::close_ifdefs(OUTPUT_STREAM, ls_paragraph *par) {
	if ((par) && (par->taggings)) {
		TEMPORARY_TEXT(identifier)
		ls_section *S = LiterateSource::section_of_par(par);
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings) {
			switch (IfdefTags::ifdef_valency(pt->the_tag)) {
				case 1:
					Str::clear(identifier);
					IfdefTags::conditional_identifier(identifier, pt->the_tag);
					LanguageMethods::close_ifdef(OUT, S->sect_language, identifier, TRUE);
					break;
				case -1:
					Str::clear(identifier);
					IfdefTags::conditional_identifier(identifier, pt->the_tag);
					LanguageMethods::close_ifdef(OUT, S->sect_language, identifier, FALSE);
					break;
			}
		}
		DISCARD_TEXT(identifier)
	}
}

@h Effect on weaving.

=
void IfdefTags::show_endnote_on_ifdefs(heterogeneous_tree *tree, tree_node *ap, ls_paragraph *par) {
	int d = 0, sense = 1;
	@<Show ifdef endnoting@>;
	sense = -1;
	@<Show ifdef endnoting@>;
	if (d > 0) TextWeaver::commentary_text(tree, ap, I".");
}

@<Show ifdef endnoting@> =
	if ((par) && (par->taggings)) {
		int c = 0;
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if (IfdefTags::ifdef_valency(pt->the_tag) == sense) {
				TEMPORARY_TEXT(identifier)
				IfdefTags::conditional_identifier(identifier, pt->the_tag);
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
				TextWeaver::commentary_text(tree, ap, identifier);
			}
		if (c > 0) {
			if (c == 1) TextWeaver::commentary_text(tree, ap, I" is");
			else TextWeaver::commentary_text(tree, ap, I" are");
			if (sense == 1) TextWeaver::commentary_text(tree, ap, I" defined");
			else TextWeaver::commentary_text(tree, ap, I" undefined");
		}
	}

