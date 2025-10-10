[TangleTargets::] Tangle Targets.

Most webs tangle to just one program, but we do support multiple targets,
which can be in different programming languages.

@ In Knuth's original conception of literate programming, a web produces
just one piece of tangled output -- the program for compilation. But this
assumes that the underlying program is so simple that it won't require
ancillary files, configuration data, and such; and this is often just as
complex and worth explaining as the program itself. So here we will allow a
web to contain multiple tangle targets, each of which contains a union of
sections. Each section belongs to exactly one tangle target; by default
a web contains just one target, which contains all of the sections.

=
typedef struct tangle_target {
	struct programming_language *tangle_language; /* common to the entire contents */
	struct hash_table symbols; /* a table of identifiable names in this program */
	CLASS_DEFINITION
} tangle_target;

@ =
tangle_target *TangleTargets::add(ls_web *W, programming_language *language) {
	tangle_target *tt = CREATE(tangle_target);
	tt->tangle_language = language;
	ReservedWords::initialise_hash_table(&(tt->symbols));
	ADD_TO_LINKED_LIST(tt, tangle_target, W->tangle_targets);
	return tt;
}

@ The first target in a web is always the one for the main program.

=
tangle_target *TangleTargets::primary_target(ls_web *W) {
	if (W == NULL) internal_error("no such web");
	if (LinkedLists::len(W->tangle_targets) == 0)
		TangleTargets::add(W, WebStructure::web_language(W));
	return FIRST_IN_LINKED_LIST(tangle_target, W->tangle_targets);
}

tangle_target *TangleTargets::ad_hoc_target(programming_language *language) {
	tangle_target *tt = CREATE(tangle_target);
	tt->tangle_language = language;
	ReservedWords::initialise_hash_table(&(tt->symbols));
	return tt;
}

tangle_target *TangleTargets::of_section(ls_section *S) {
	if (S->sect_target == NULL) {
		ls_web *W = S->owning_chapter->owning_web;
		if (S->is_independent_target)
			S->sect_target = TangleTargets::add(W, WebStructure::section_language(S));
		else
			S->sect_target = TangleTargets::primary_target(W);
	}
	return S->sect_target;
}

@ And the following provides a way to iterate through the lines in a tangle,
while keeping the variables |C|, |S| and |L| pointing to the current chapter,
section and line.


@d LOOP_OVER_TARGET_SECTIONS(C, S, T)
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if ((T == NULL) || (TangleTargets::of_section(S) == T))

@d LOOP_OVER_TARGET_CHUNKS(C, S, T)
	LOOP_OVER_TARGET_SECTIONS(C, S, T)
		for (ls_paragraph *L_par = S->literate_source->first_par; L_par; L_par = L_par->next_par)
			for (ls_chunk *L_chunk = L_par->first_chunk; L_chunk; L_chunk = L_chunk->next_chunk)

@d LOOP_WITHIN_CODE(C, S, T)
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if ((T == NULL) || (TangleTargets::of_section(S) == T))
				for (ls_paragraph *L_par = S->literate_source->first_par; L_par; L_par = L_par->next_par)
					for (ls_chunk *L_chunk = L_par->first_chunk; L_chunk; L_chunk = L_chunk->next_chunk)
						if (LiterateSource::is_code_chunk(L_chunk))
							for (ls_line *lst = L_chunk->first_line; lst; lst = lst->next_line)

@d LOOP_WITHIN_CODE_AND_DEFINITIONS(C, S, T)
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if ((T == NULL) || (TangleTargets::of_section(S) == T))
				for (ls_paragraph *L_par = S->literate_source->first_par; L_par; L_par = L_par->next_par)
					for (ls_chunk *L_chunk = L_par->first_chunk; L_chunk; L_chunk = L_chunk->next_chunk)
						if ((LiterateSource::is_code_chunk(L_chunk)) ||
							(L_chunk->chunk_type == DEFINITION_LSCT))
							for (ls_line *lst = L_chunk->first_line; lst; lst = lst->next_line)
