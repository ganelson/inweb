[Numbering::] Paragraph Numbering.

To work out paragraph numbers within each section.

@ Traditional LP tools have numbered paragraphs in the obvious way, starting
from 1 and working up to what may be an enormous number. (The web for Knuth's
Metafont runs from 1 to 1215, for example.) Inweb expects to be working on
rather larger programs and therefore numbers independently from 1 within
each section. It also tries to make the numbering more structurally relevant:
thus paragraph 1.1 will be used within paragraph 1, and so on.

It's a little ambiguous how to do this for the best, as we'll see.

We can certainly only do it if we know exactly where macros are used. This
is something we scan for on a weave, but not on a tangle; that's fine, though,
because tangled code doesn't need to know its own paragraph numbers.

=
void Numbering::number_web(web *W) {
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters) {
		LOOP_OVER_LINKED_LIST(S, section, C->sections) {
			@<Scan this section to see where paragraph macros are used@>;
			@<Work out paragraph numbers within this section@>;
		}
	}
}

@<Scan this section to see where paragraph macros are used@> =
	for (source_line *L = S->first_line; L; L = L->next_line) {
		TEMPORARY_TEXT(p)
		Str::copy(p, L->text);
		int mlen, mpos;
		while ((mpos = Regexp::find_expansion(p, '@', '<', '@', '>', &mlen)) != -1) {
			TEMPORARY_TEXT(found_macro)
			Str::substr(found_macro, Str::at(p, mpos+2), Str::at(p, mpos+mlen-2));
			TEMPORARY_TEXT(original_p)
			Str::copy(original_p, p);
			Str::clear(p);
			Str::substr(p, Str::at(original_p, mpos + mlen), Str::end(original_p));
			DISCARD_TEXT(original_p)
			para_macro *pmac = Macros::find_by_name(found_macro, S);
			if (pmac) @<Add a record that the macro is used in this paragraph@>;
			DISCARD_TEXT(found_macro)
		}
		DISCARD_TEXT(p)
	}

@ Each macro comes with a linked list of notes about which paragraphs use
it; necessarily paragraphs within the same section.

This paragraph you're looking at now shows the difficulty involved in
paragraph numbering. It's not a macro, so it's not obviously used by any
other paragraph. Should it be bumped up to paragraph 2? But if we do that,
we end up with numbers out of order, since the one after it would have to
be 1.1.1. Instead this one will be 1.1.1, to place it into the natural
lexicographic sequence.

=
typedef struct macro_usage {
	struct paragraph *used_in_paragraph;
	int multiplicity; /* for example, 2 if it's used twice in this paragraph */
	CLASS_DEFINITION
} macro_usage;

@<Add a record that the macro is used in this paragraph@> =
	macro_usage *mu, *last = NULL;
	LOOP_OVER_LINKED_LIST(mu, macro_usage, pmac->macro_usages) {
		last = mu;
		if (mu->used_in_paragraph == L->owning_paragraph)
			break;
	}
	if (mu == NULL) {
		mu = CREATE(macro_usage);
		mu->used_in_paragraph = L->owning_paragraph;
		mu->multiplicity = 0;
		ADD_TO_LINKED_LIST(mu, macro_usage, pmac->macro_usages);
	}
	mu->multiplicity++;

@ Basically we'll form the paragraphs into a tree, or in fact a forest. If a
paragraph defines a macro then we want it to be a child node of the
paragraph where the macro is first used; it's then a matter of filling in
other nodes a bit speculatively.

@<Work out paragraph numbers within this section@> =
	@<The parent of a macro definition is the place where it's first used@>;
	@<Otherwise share the parent of a following paragraph, provided it precedes us@>;
	@<Create paragraph number texts@>;
	@<Number the still parent-less paragraphs consecutively from 1@>;
	@<Recursively derive the numbers of parented paragraphs from those of their parents@>;

@<The parent of a macro definition is the place where it's first used@> =
	paragraph *P;
	LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
		if (P->defines_macro) {
			macro_usage *mu =
				FIRST_IN_LINKED_LIST(macro_usage, P->defines_macro->macro_usages);
			if (mu) P->parent_paragraph = mu->used_in_paragraph;
		}

@<Otherwise share the parent of a following paragraph, provided it precedes us@> =
	paragraph *P;
	LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
		if (P->parent_paragraph == NULL)
			for (linked_list_item *P2_item = P_item; P2_item; P2_item = NEXT_ITEM_IN_LINKED_LIST(P2_item, paragraph)) {
				paragraph *P2 = CONTENT_IN_ITEM(P2_item, paragraph);
				if (P2->parent_paragraph) {
					if (P2->parent_paragraph->allocation_id < P->allocation_id)
						P->parent_paragraph = P2->parent_paragraph;
					break;
				}
			}

@<Create paragraph number texts@> =
	paragraph *P;
	LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
		P->paragraph_number = Str::new();

@ Now we have our tree, and we number paragraphs accordingly: root notes are
numbered 1, 2, 3, ..., and then children are numbered with suffixes .1, .2, .3,
..., under their parents.

@<Number the still parent-less paragraphs consecutively from 1@> =
	int top_level = 1;
	paragraph *P;
	LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
		if (P->parent_paragraph == NULL) {
			WRITE_TO(P->paragraph_number, "%d", top_level++);
			P->next_child_number = 1;
		} else
			Str::clear(P->paragraph_number);

@<Recursively derive the numbers of parented paragraphs from those of their parents@> =
	paragraph *P;
	LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
		Numbering::settle_paragraph_number(P);

@ The following paragraph shows the deficiencies of the algorithm: it's going
to end up numbered 2, because it isn't used anywhere and doesn't seem to be
in the middle of a wider description. But better to keep it in the sequence
chosen by the author, so 2 it is.

=
void Numbering::settle_paragraph_number(paragraph *P) {
	if (Str::len(P->paragraph_number) > 0) return;
	WRITE_TO(P->paragraph_number, "X"); /* to prevent malformed sections hanging this */
	if (P->parent_paragraph) Numbering::settle_paragraph_number(P->parent_paragraph);
	Str::clear(P->paragraph_number);
	WRITE_TO(P->paragraph_number, "%S.%d", P->parent_paragraph->paragraph_number,
			P->parent_paragraph->next_child_number++);
	P->next_child_number = 1;
}
