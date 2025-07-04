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
	return FIRST_IN_LINKED_LIST(tangle_target, W->tangle_targets);
}

tangle_target *TangleTargets::ad_hoc_target(programming_language *language) {
	tangle_target *tt = CREATE(tangle_target);
	tt->tangle_language = language;
	ReservedWords::initialise_hash_table(&(tt->symbols));
	return tt;
}

void TangleTargets::make_default(ls_web *W, tangle_target *T) {
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if (S->sect_target == NULL)
				S->sect_target = T;
}

@ And the following provides a way to iterate through the lines in a tangle,
while keeping the variables |C|, |S| and |L| pointing to the current chapter,
section and line.


@d LOOP_OVER_TARGET_SECTIONS(C, S, T)
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if ((T == NULL) || (S->sect_target == T))

@d LOOP_OVER_TARGET_CHUNKS(C, S, T)
	LOOP_OVER_TARGET_SECTIONS(C, S, T)
		for (ls_paragraph *L_par = S->literate_source->first_par; L_par; L_par = L_par->next_par)
			for (ls_chunk *L_chunk = L_par->first_chunk; L_chunk; L_chunk = L_chunk->next_chunk)

@d LOOP_WITHIN_CODE(C, S, T)
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if ((T == NULL) || (S->sect_target == T))
				for (ls_paragraph *L_par = S->literate_source->first_par; L_par; L_par = L_par->next_par)
					for (ls_chunk *L_chunk = L_par->first_chunk; L_chunk; L_chunk = L_chunk->next_chunk)
						if (LiterateSource::is_code_chunk(L_chunk))
							for (ls_line *lst = L_chunk->first_line; lst; lst = lst->next_line)

@d LOOP_WITHIN_CODE_AND_DEFINITIONS(C, S, T)
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if ((T == NULL) || (S->sect_target == T))
				for (ls_paragraph *L_par = S->literate_source->first_par; L_par; L_par = L_par->next_par)
					for (ls_chunk *L_chunk = L_par->first_chunk; L_chunk; L_chunk = L_chunk->next_chunk)
						if ((LiterateSource::is_code_chunk(L_chunk)) ||
							(L_chunk->chunk_type == DEFINITION_LSCT))
							for (ls_line *lst = L_chunk->first_line; lst; lst = lst->next_line)

@ I'm probably showing my age here.

=
programming_language *TangleTargets::default_language_of_web(ls_web *W) {
	return TangleTargets::find_language(I"C", NULL, TRUE);
}

programming_language *TangleTargets::find_language(text_stream *lname, ls_web *W,
	int error_if_not_found) {
	pathname *P;
	if ((W) && (W->path_to_web)) {
		P = Pathnames::down(W->path_to_web, I"Dialects");
		programming_language *pl = Languages::find_by_name(lname, P, FALSE);
		if (pl) return pl;
	}
	pathname *R = Pathnames::path_to_LP_resources();
	P = Pathnames::down(R, I"PLs");
	programming_language *pl = Languages::find_by_name(lname, P, FALSE);
	if (pl) return pl;
	P = Pathnames::down(R, I"Languages");
	pl = Languages::find_by_name(lname, P, error_if_not_found);
	return pl;
}

void TangleTargets::set_languages_and_targets(ls_web *W, programming_language *supplied) {
	if (supplied) {
		Bibliographic::set_datum(W, I"Language", supplied->language_name);
		W->web_language = supplied;
	} else {
		text_stream *language_name = Bibliographic::get_datum(W, I"Language");
		if (Str::len(language_name) > 0)
			W->web_language = TangleTargets::find_language(language_name, W, TRUE);
		else
			W->web_language = TangleTargets::default_language_of_web(W);
	}
	tangle_target *main_target = TangleTargets::add(W, W->web_language);
	TangleTargets::make_default(W, main_target);
	ls_chapter *Cm;
	LOOP_OVER_LINKED_LIST(Cm, ls_chapter, W->chapters) {
		Cm->ch_language = W->web_language;
		if (Str::len(Cm->ch_language_name) > 0)
			Cm->ch_language = TangleTargets::find_language(Cm->ch_language_name, W, TRUE);
		ls_section *Sm;
		LOOP_OVER_LINKED_LIST(Sm, ls_section, Cm->sections) {
			Sm->sect_language = Cm->ch_language;
			if (Str::len(Sm->sect_language_name) > 0)
				Sm->sect_language = TangleTargets::find_language(Sm->sect_language_name, W, TRUE);
			if (Str::len(Sm->sect_independent_language) > 0) {
				programming_language *pl =
					TangleTargets::find_language(Sm->sect_independent_language, W, TRUE);
				Sm->sect_language = pl;
				Sm->sect_target = TangleTargets::add(W, pl);
			}
		}
	}
}
