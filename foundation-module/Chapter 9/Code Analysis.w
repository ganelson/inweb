[CodeAnalysis::] Code Analysis.

Here we analyse the code in the web, enabling us to see how functions
and data structures are used within the program.

@ The ambitious name for this section oversells what it does. We're really
just spotting declarations and uses of functions and the like, and even that
we do with simplistic methods.

This needs some annotation of the web structure, provided by the following
structures. Each |ls_web| has an |ls_web_analysis| attached, and so on.

=
typedef struct ls_web_analysis {
	int analysed; /* has this been scanned for function usage and such? */
	struct linked_list *language_types; /* of |language_type|: used only for C-like languages */
	struct linked_list *defined_constants;  /* of |defined_constant| */
	struct linked_list *language_functions; /* of |language_function| */
	CLASS_DEFINITION
} ls_web_analysis;

typedef struct ls_paragraph_analysis {
	struct linked_list *functions; /* of |function|: those defined in this para */
	struct linked_list *structures; /* of |language_type|: similarly */
	CLASS_DEFINITION
} ls_paragraph_analysis;

typedef struct ls_line_analysis {
	struct language_function *function_defined; /* if any C-like function is defined on this line */
	struct preform_nonterminal *preform_nonterminal_defined; /* similarly */
	int part_of_typedef;
	int preform_grammar;
	int C_inclusion;
} ls_line_analysis;

@ =
void CodeAnalysis::initialise_analysis_details(ls_web *W) {
	@<Give the web analysis details@>;
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) {
		ls_section *S;
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
			for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par) {
				@<Give the paragraph analysis details@>;
				for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
					for (ls_line *lst = chunk->first_line; lst; lst = lst->next_line)
						@<Give the line analysis details@>;
			}
		}
	}
}

@<Give the web analysis details@> =
	ls_web_analysis *analysis = CREATE(ls_web_analysis);
	W->analysis_ref = (void *) analysis;
	analysis->language_types = NEW_LINKED_LIST(language_type);
	analysis->analysed = FALSE;
	analysis->defined_constants = NEW_LINKED_LIST(defined_constant);
	analysis->language_functions = NEW_LINKED_LIST(language_function);

@<Give the paragraph analysis details@> =
	ls_paragraph_analysis *P = CREATE(ls_paragraph_analysis);
	par->analysis_ref = (void *) P;
	P->functions = NEW_LINKED_LIST(function);
	P->structures = NEW_LINKED_LIST(language_type);

	text_stream *tag;
	LOOP_OVER_LINKED_LIST(tag, text_stream, par->titling.tag_list)
		LiterateSource::tag_paragraph(par, tag);
	if (Str::len(S->tag_name) > 0)
		LiterateSource::tag_paragraph_with_caption(par, S->tag_name, NULL);

@<Give the line analysis details@> =
	ls_line_analysis *sl = CREATE(ls_line_analysis);
	sl->function_defined = NULL;
	sl->preform_nonterminal_defined = NULL;
	sl->part_of_typedef = FALSE;
	sl->preform_grammar = FALSE;
	sl->C_inclusion = FALSE;
	lst->analysis_ref = (void *) sl;

@ =
linked_list *CodeAnalysis::language_types_list(ls_web *W) {
	return ((ls_web_analysis *) (W->analysis_ref))->language_types;
}

linked_list *CodeAnalysis::language_functions_list(ls_web *W) {
	return ((ls_web_analysis *) (W->analysis_ref))->language_functions;
}

linked_list *CodeAnalysis::defined_constants_list(ls_web *W) {
	return ((ls_web_analysis *) (W->analysis_ref))->defined_constants;
}

ls_paragraph_analysis *CodeAnalysis::paragraph_details(ls_line *lst) {
	ls_paragraph *par = LiterateSource::par_of_line(lst);
	if (par == NULL) return NULL;
	return (ls_paragraph_analysis *) par->analysis_ref;
}

@h Analysing code.
We can't pretend to a full-scale static analysis of the code -- for one thing,
that would mean knowing more about the syntax of the web's language than we
actually do. So the following provides only a toolkit which other code can
use when looking for certain syntactic patterns: something which looks like
a function call, or a C structure field reference, for example.

=
void CodeAnalysis::analyse_web(ls_web *W, int tangling, int weaving) {
	CodeAnalysis::analyse_definitions(W, tangling);
	LanguageMethods::subcategorise_lines(W);
	LanguageMethods::parse_types(W, W->web_language);
	LanguageMethods::parse_functions(W, W->web_language);
	LanguageMethods::further_parsing(W, W->web_language, weaving);
}

@ Our methods are all essentially based on spotting identifiers in the code, but
with punctuation around them. Usage codes are used to define a set of allowed
contexts in which to spot these identifiers.

@d ELEMENT_ACCESS_USAGE     0x00000001 /* C-like languages: access via |->| or |.| operators to structure element */
@d FCALL_USAGE              0x00000002 /* C-like languages: function call made using brackets, |name(args)| */
@d PREFORM_IN_CODE_USAGE    0x00000004 /* InC only: use of a Preform nonterminal as a C "constant" */
@d PREFORM_IN_GRAMMAR_USAGE 0x00000008 /* InC only: ditto, but within Preform production rather than C code */
@d MISC_USAGE               0x00000010 /* any other appearance as an identifier */
@d ANY_USAGE                0x7fffffff /* any of the above */

@ The main analysis routine goes through a web as follows. Note that we only
perform the search here, we don't comment on the results; any action to be
taken must be handled by |LanguageMethods::late_preweave_analysis| when we're done.

=
void CodeAnalysis::analyse_code(ls_web *W) {
	ls_web_analysis *details = (ls_web_analysis *) (W->analysis_ref);
	if (details->analysed) return;
	details->analysed = TRUE;

	@<Ask language-specific code to identify search targets, and parse the Interfaces@>;

	ls_chapter *C;
	ls_section *S;
	LOOP_WITHIN_CODE_AND_DEFINITIONS(C, S, TangleTargets::primary_target(W)) {
		ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
		if (L->preform_grammar) @<Perform analysis on productions in a Preform grammar@>
		else if ((L_chunk->chunk_type == DEFINITION_LSCT) && (L_chunk->first_line == lst))
			CodeAnalysis::analyse_as_code(W, lst, lst->classification.operand2, ANY_USAGE, 0);
		else
			CodeAnalysis::analyse_as_code(W, lst, lst->text, ANY_USAGE, 0);
	}

	LanguageMethods::late_preweave_analysis(W->web_language, W);
}

@ First, we call any language-specific code, whose task is to identify what we
should be looking for: for example, the C-like languages code tells us (see
below) to look for names of particular functions it knows about.

@<Ask language-specific code to identify search targets, and parse the Interfaces@> =
	LanguageMethods::early_preweave_analysis(W->web_language, W);

@ Lines in a Preform grammar generally take the form of some BNF grammar, where
we want only to identify any nonterminals mentioned, then a |==>| divider,
and then some C code to deal with a match. The code is subjected to analysis
just as any other code would be.

@<Perform analysis on productions in a Preform grammar@> =
	CodeAnalysis::analyse_as_code(W, lst, lst->classification.operand2,
		ANY_USAGE, 0);
	CodeAnalysis::analyse_as_code(W, lst, lst->classification.operand1,
		PREFORM_IN_CODE_USAGE, PREFORM_IN_GRAMMAR_USAGE);

@h Identifier searching.
Here's what we actually do, then. We take the code fragment |text|, drawn
from part or all of source line |L| from web |W|, and look for any identifier
names used in one of the contexts in the bitmap |mask|. Any that we find are
passed to |CodeAnalysis::analyse_find|, along with the context they were found in (or, if
|transf| is nonzero, with |transf| as their context).

What we do is to look for instances of an identifier, defined as a maximal
string of |%i| characters or hyphens not followed by |>| characters. (Thus
|fish-or-chips| counts, but |fish-| is not an identifier when it occurs in
|fish->bone|.)

=
void CodeAnalysis::analyse_as_code(ls_web *W, ls_line *lst, text_stream *text, int mask, int transf) {
	int start_at = -1, element_follows = FALSE;
	for (int i = 0; i < Str::len(text); i++) {
		if ((Regexp::identifier_char(Str::get_at(text, i))) ||
			((Str::get_at(text, i) == '-') && (Str::get_at(text, i+1) != '>'))) {
			if (start_at == -1) start_at = i;
		} else {
			if (start_at != -1) @<Found an identifier@>;
			if (Str::get_at(text, i) == '.') element_follows = TRUE;
			else if ((Str::get_at(text, i) == '-') && (Str::get_at(text, i+1) == '>')) {
				element_follows = TRUE; i++;
			} else element_follows = FALSE;
		}
	}
	if (start_at != -1) {
		int i = Str::len(text);
		@<Found an identifier@>;
	}
}

@<Found an identifier@> =
	int u = MISC_USAGE;
	if (element_follows) u = ELEMENT_ACCESS_USAGE;
	else if (Str::get_at(text, i) == '(') u = FCALL_USAGE;
	else if ((Str::get_at(text, i) == '>') && (start_at > 0) && (Str::get_at(text, start_at-1) == '<'))
		u = PREFORM_IN_CODE_USAGE;
	if (u & mask) {
		if (transf) u = transf;
		TEMPORARY_TEXT(identifier_found)
		for (int j = 0; start_at + j < i; j++)
			PUT_TO(identifier_found, Str::get_at(text, start_at + j));
		CodeAnalysis::analyse_find(W, lst, identifier_found, u);
		DISCARD_TEXT(identifier_found)
	}
	start_at = -1; element_follows = FALSE;

@ Dealing with a hash table of reserved words:

=
hash_table_entry *CodeAnalysis::find_hash_entry_for_section(ls_section *S, text_stream *text,
	int create) {
	return ReservedWords::find_hash_entry(&(S->sect_target->symbols), text, create);
}

void CodeAnalysis::mark_reserved_word_for_section(ls_section *S, text_stream *p, int e) {
	ReservedWords::mark_reserved_word(&(S->sect_target->symbols), p, e);
}

hash_table_entry *CodeAnalysis::mark_reserved_word_at_line(ls_line *lst, text_stream *p, int e) {
	if (lst == NULL) internal_error("no line for rw");
	hash_table_entry *hte = 
		ReservedWords::mark_reserved_word(&(LiterateSource::section_of_line(lst)->sect_target->symbols), p, e);
	hte->definition_line = lst;
	return hte;
}

int CodeAnalysis::is_reserved_word_for_section(ls_section *S, text_stream *p, int e) {
	return ReservedWords::is_reserved_word(&(S->sect_target->symbols), p, e);
}

ls_line *CodeAnalysis::get_defn_line(ls_section *S, text_stream *p, int e) {
	hash_table_entry *hte = ReservedWords::find_hash_entry(&(S->sect_target->symbols), p, FALSE);
	if ((hte) && (hte->language_reserved_word & (1 << (e % 32)))) return hte->definition_line;
	return NULL;
}

language_function *CodeAnalysis::get_function(ls_section *S, text_stream *p, int e) {
	hash_table_entry *hte = ReservedWords::find_hash_entry(&(S->sect_target->symbols), p, FALSE);
	if ((hte) && (hte->language_reserved_word & (1 << (e % 32)))) return hte->as_function;
	return NULL;
}

@ Now we turn back to the actual analysis. When we spot an identifier that
we know, we record its usage with an instance of the following. Note that
each identifier can have at most one of these records per paragraph of code,
but that it can be used in multiple ways within that paragraph: for example,
a function might be both called and used as a constant value within the
same paragraph of code.

=
typedef struct hash_table_entry_usage {
	struct ls_paragraph *usage_recorded_at;
	int form_of_usage; /* bitmap of the |*_USAGE| constants defined above */
	CLASS_DEFINITION
} hash_table_entry_usage;

@ And here's how we create these usages:

=
void CodeAnalysis::analyse_find(ls_web *W, ls_line *lst, text_stream *identifier, int u) {
	hash_table_entry *hte =
		CodeAnalysis::find_hash_entry_for_section(LiterateSource::section_of_line(lst), identifier, FALSE);
	if (hte == NULL) return;
	hash_table_entry_usage *hteu = NULL, *loop = NULL;
	LOOP_OVER_LINKED_LIST(loop, hash_table_entry_usage, hte->usages)
		if (LiterateSource::par_of_line(lst) == loop->usage_recorded_at) {
			hteu = loop; break;
		}
	if (hteu == NULL) {
		hteu = CREATE(hash_table_entry_usage);
		hteu->form_of_usage = 0;
		hteu->usage_recorded_at = LiterateSource::par_of_line(lst);
		ADD_TO_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages);
	}
	hteu->form_of_usage |= u;
}

@h Definitions.
Here we spot defined constants in the source, and mark them appropriately.

=
void CodeAnalysis::analyse_definitions(ls_web *W, int tangling) {
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
				for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
					for (ls_line *lst = chunk->first_line; lst; lst = lst->next_line)
						if (lst->classification.major == DEFINITION_MAJLC)
							@<Deal with a definition@>;
}

@<Deal with a definition@> =
	if (Str::len(chunk->symbol_value) > 0) {
		TEMPORARY_TEXT(before)
		TEMPORARY_TEXT(after)
		if (LanguageMethods::parse_comment(S->sect_language, chunk->symbol_value,
			before, after)) {
			Str::copy(chunk->symbol_value, before);
			Str::trim_white_space(chunk->symbol_value);
		}
		DISCARD_TEXT(before)
		DISCARD_TEXT(after)
	} else {
		TEMPORARY_TEXT(before)
		TEMPORARY_TEXT(after)
		if (LanguageMethods::parse_comment(S->sect_language, chunk->symbol_defined,
			before, after)) {
			Str::copy(chunk->symbol_defined, before);
			Str::trim_white_space(chunk->symbol_defined);
		}
		DISCARD_TEXT(before)
		DISCARD_TEXT(after)
	}
	if ((lst->classification.minor == ENUMERATE_COMMAND_MINLC) && (tangling)) {
		text_stream *from = chunk->symbol_value;
		chunk->symbol_value = Str::new();
		Enumerations::define(chunk->symbol_value, chunk->symbol_defined, from, lst, S);
	}
	CodeAnalysis::mark_reserved_word_at_line(lst, chunk->symbol_defined, CONSTANT_COLOUR);
	Ctags::note_defined_constant(lst, chunk->symbol_defined, W);

@h Open-source project support.
The work here is all delegated. In each case we look for a script in the web's
folder: failing that, we fall back on a default script.

=
void CodeAnalysis::write_makefile(ls_web *W, filename *F, module_search *I, text_stream *platform,
	pathname *path_to_inweb_materials) {
	pathname *P = W->path_to_web;
	text_stream *short_name = Pathnames::directory_name(P);
	if ((Str::len(short_name) == 0) ||
		(Str::eq(short_name, I".")) || (Str::eq(short_name, I"..")))
		short_name = I"web";
	TEMPORARY_TEXT(leafname)
	WRITE_TO(leafname, "%S.mkscript", short_name);
	filename *prototype = Filenames::in(P, leafname);
	DISCARD_TEXT(leafname)
	if (!(TextFiles::exists(prototype)))
		prototype = Filenames::in(path_to_inweb_materials, I"default.mkscript");
	Makefiles::write(W, prototype, F, I, platform);
}

void CodeAnalysis::write_gitignore(ls_web *W, filename *F,
	pathname *path_to_inweb_materials) {
	pathname *P = W->path_to_web;
	text_stream *short_name = Pathnames::directory_name(P);
	if ((Str::len(short_name) == 0) ||
		(Str::eq(short_name, I".")) || (Str::eq(short_name, I"..")))
		short_name = I"web";
	TEMPORARY_TEXT(leafname)
	WRITE_TO(leafname, "%S.giscript", short_name);
	filename *prototype = Filenames::in(P, leafname);
	DISCARD_TEXT(leafname)
	if (!(TextFiles::exists(prototype)))
		prototype = Filenames::in(path_to_inweb_materials, I"default.giscript");
	Git::write_gitignore(W, prototype, F);
}

@h The section catalogue.
This provides quite a useful overview of the sections:

@enum BASIC_SECTIONCAT from 1
@enum STRUCTURES_SECTIONCAT
@enum FUNCTIONS_SECTIONCAT

=
void CodeAnalysis::catalogue_the_sections(ls_web *W, text_stream *range, int form) {
	int max_width = 0, max_range_width = 0;
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
			if (max_range_width < Str::len(WebRanges::of(S))) max_range_width = Str::len(WebRanges::of(S));
			TEMPORARY_TEXT(main_title)
			WRITE_TO(main_title, "%S/%S", C->ch_basic_title, S->sect_title);
			if (max_width < Str::len(main_title)) max_width = Str::len(main_title);
			DISCARD_TEXT(main_title)
		}
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if ((Str::eq_wide_string(range, U"0")) || (Str::eq(range, C->ch_range))) {
			PRINT("      -----\n");
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
				TEMPORARY_TEXT(main_title)
				WRITE_TO(main_title, "%S/%S", C->ch_basic_title, S->sect_title);
				PRINT("%4d  %S", S->sect_extent, WebRanges::of(S));
				for (int i = Str::len(WebRanges::of(S)); i<max_range_width+2; i++) PRINT(" ");
				PRINT("%S", main_title);
				for (int i = Str::len(main_title); i<max_width+2; i++) PRINT(" ");
				if (form != BASIC_SECTIONCAT)
					Functions::catalogue(S, (form == FUNCTIONS_SECTIONCAT)?TRUE:FALSE);
				PRINT("\n");
				DISCARD_TEXT(main_title)
			}
		}
}
