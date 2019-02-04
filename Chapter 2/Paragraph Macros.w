[Macros::] Paragraph Macros.

To manage the set of named paragraph macros in a section.

@ We store these like so:

=
typedef struct para_macro {
	struct text_stream *macro_name; /* usually long, like "Create a paragraph macro here" */
	struct paragraph *defining_paragraph; /* as printed in small type after the name in any usage */
	struct source_line *defn_start; /* it ends at the end of its defining paragraph */
	struct linked_list *macro_usages; /* of |macro_usage|: only computed for weaves */
	MEMORY_MANAGEMENT
} para_macro;

@ Each section has its own linked list of paragraph macros, since the scope for
the usage of these is always a single section.

=
para_macro *Macros::create(section *S, paragraph *P, source_line *L, text_stream *name) {
	para_macro *pmac = CREATE(para_macro);
	pmac->macro_name = Str::duplicate(name);
	pmac->defining_paragraph = P;
	P->defines_macro = pmac;
	pmac->defn_start = L->next_line;
	pmac->macro_usages = NEW_LINKED_LIST(macro_usage);
	ADD_TO_LINKED_LIST(pmac, para_macro, S->macros);
	return pmac;
}

@h Paragraph macro search.
The scope for looking up paragraph macro names is a single section, not the
entire web. So you can't expand a macro from another section, but then again,
you can use the same macro name twice in different sections; and lookup is
much faster.

=
para_macro *Macros::find_by_name(text_stream *name, section *scope) {
	para_macro *pmac;
	LOOP_OVER_LINKED_LIST(pmac, para_macro, scope->macros)
		if (Str::eq(name, pmac->macro_name))
			return pmac;
	return NULL;
}
