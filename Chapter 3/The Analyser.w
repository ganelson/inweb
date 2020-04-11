[Analyser::] The Analyser.

Here we analyse the code in the web, enabling us to see how functions
and data structures are used within the program.

@h Scanning webs.
This scanner is intended for debugging Inweb, and simply shows the main
result of reading in and parsing the web:

=
void Analyser::scan_line_categories(web *W, text_stream *range) {
	PRINT("Scan of source lines for '%S'\n", range);
	int count = 1;
	chapter *C = Reader::get_chapter_for_range(W, range);
	if (C) {
		section *S;
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			for (source_line *L = S->first_line; L; L = L->next_line)
				@<Trace the content and category of this source line@>;
	} else {
		section *S = Reader::get_section_for_range(W, range);
		if (S) {
			for (source_line *L = S->first_line; L; L = L->next_line)
				@<Trace the content and category of this source line@>
		} else {
			LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
				LOOP_OVER_LINKED_LIST(S, section, C->sections)
					for (source_line *L = S->first_line; L; L = L->next_line)
						@<Trace the content and category of this source line@>;
		}
	}
}

@<Trace the content and category of this source line@> =
	TEMPORARY_TEXT(C);
	WRITE_TO(C, "%s", Lines::category_name(L->category));
	while (Str::len(C) < 20) PUT_TO(C, '.');
	PRINT("%07d  %S  %S\n", count++, C, L->text);
	DISCARD_TEXT(C);

@h The section catalogue.
This provides quite a useful overview of the sections. As we'll see frequently
in Chapter 4, we call out to a general routine in Chapter 5 to provide
annotations which are programming-language specific; the aim is to abstract
so that Chapter 4 contains no assumptions about the language.

@enum BASIC_SECTIONCAT from 1
@enum STRUCTURES_SECTIONCAT
@enum FUNCTIONS_SECTIONCAT

=
void Analyser::catalogue_the_sections(web *W, text_stream *range, int form) {
	int max_width = 0, max_range_width = 0;
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections) {
			if (max_range_width < Str::len(S->sect_range)) max_range_width = Str::len(S->sect_range);
			TEMPORARY_TEXT(main_title);
			WRITE_TO(main_title, "%S/%S", C->md->ch_basic_title, S->md->sect_title);
			if (max_width < Str::len(main_title)) max_width = Str::len(main_title);
			DISCARD_TEXT(main_title);
		}
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		if ((Str::eq_wide_string(range, L"0")) || (Str::eq(range, C->md->ch_range))) {
			PRINT("      -----\n");
			LOOP_OVER_LINKED_LIST(S, section, C->sections) {
				TEMPORARY_TEXT(main_title);
				WRITE_TO(main_title, "%S/%S", C->md->ch_basic_title, S->md->sect_title);
				PRINT("%4d  %S", S->sect_extent, S->sect_range);
				for (int i = Str::len(S->sect_range); i<max_range_width+2; i++) PRINT(" ");
				PRINT("%S", main_title);
				for (int i = Str::len(main_title); i<max_width+2; i++) PRINT(" ");
				if (form != BASIC_SECTIONCAT)
					Functions::catalogue(S, (form == FUNCTIONS_SECTIONCAT)?TRUE:FALSE);
				PRINT("\n");
				DISCARD_TEXT(main_title);
			}
		}
}

@h Analysing code.
We can't pretend to a full-scale static analysis of the code -- for one thing,
that would mean knowing more about the syntax of the web's language than we
actually do. So the following provides only a toolkit which other code can
use when looking for certain syntactic patterns: something which looks like
a function call, or a C structure field reference, for example. These are
all essentially based on spotting identifiers in the code, but with
punctuation around them.

Usage codes are used to define a set of allowed contexts in which to spot
these identifiers.

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
void Analyser::analyse_code(web *W) {
	if (W->analysed) return;

	@<Ask language-specific code to identify search targets, and parse the Interfaces@>;

	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		switch (L->category) {
			case BEGIN_DEFINITION_LCAT:
				@<Perform analysis on the body of the definition@>;
				break;
			case CODE_BODY_LCAT:
				@<Perform analysis on a typical line of code@>;
				break;
			case PREFORM_GRAMMAR_LCAT:
				@<Perform analysis on productions in a Preform grammar@>;
				break;
		}

	LanguageMethods::late_preweave_analysis(W->main_language, W);
	W->analysed = TRUE;
}

@ First, we call any language-specific code, whose task is to identify what we
should be looking for: for example, the C-like languages code tells us (see
below) to look for names of particular functions it knows about.

In Version 1 webs, this code is also expected to parse any Interface lines in
a section which it recognises, marking those by setting their
|interface_line_identified| flags. Any that are left must be erroneous.
Version 2 removed Interface altogeter as being cumbersome for no real gain in
practice.

@<Ask language-specific code to identify search targets, and parse the Interfaces@> =
	LanguageMethods::early_preweave_analysis(W->main_language, W);

	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		if ((L->category == INTERFACE_BODY_LCAT) &&
			(L->interface_line_identified == FALSE) &&
			(Regexp::string_is_white_space(L->text) == FALSE))
			Main::error_in_web(I"unrecognised interface line", L);

@<Perform analysis on a typical line of code@> =
	Analyser::analyse_as_code(W, L, L->text, ANY_USAGE, 0);

@<Perform analysis on the body of the definition@> =
	Analyser::analyse_as_code(W, L, L->text_operand2, ANY_USAGE, 0);
	while ((L->next_line) && (L->next_line->category == CONT_DEFINITION_LCAT)) {
		L = L->next_line;
		Analyser::analyse_as_code(W, L, L->text, ANY_USAGE, 0);
	}

@ Lines in a Preform grammar generally take the form of some BNF grammar, where
we want only to identify any nonterminals mentioned, then a |==>| divider,
and then some C code to deal with a match. The code is subjected to analysis
just as any other code would be.

@<Perform analysis on productions in a Preform grammar@> =
	Analyser::analyse_as_code(W, L, L->text_operand2, ANY_USAGE, 0);
	Analyser::analyse_as_code(W, L, L->text_operand, PREFORM_IN_CODE_USAGE, PREFORM_IN_GRAMMAR_USAGE);

@h Identifier searching.
Here's what we actually do, then. We take the code fragment |text|, drawn
from part or all of source line |L| from web |W|, and look for any identifier
names used in one of the contexts in the bitmap |mask|. Any that we find are
passed to |Analyser::analyse_find|, along with the context they were found in (or, if
|transf| is nonzero, with |transf| as their context).

What we do is to look for instances of an identifier, defined as a maximal
string of |%i| characters or hyphens not followed by |>| characters. (Thus
|fish-or-chips| counts, but |fish-| is not an identifier when it occurs in
|fish->bone|.)

=
void Analyser::analyse_as_code(web *W, source_line *L, text_stream *text, int mask, int transf) {
	int start_at = -1, element_follows = FALSE;
	for (int i = 0; i < Str::len(text); i++) {
		if ((Regexp::identifier_char(Str::get_at(text, i))) ||
			((Str::get_at(text, i) == '-') && (Str::get_at(text, i+1) != '>'))) {
			if (start_at == -1) start_at = i;
		} else {
			if (start_at != -1) {
				int u = MISC_USAGE;
				if (element_follows) u = ELEMENT_ACCESS_USAGE;
				else if (Str::get_at(text, i) == '(') u = FCALL_USAGE;
				else if ((Str::get_at(text, i) == '>') && (start_at > 0) && (Str::get_at(text, start_at-1) == '<'))
					u = PREFORM_IN_CODE_USAGE;
				if (u & mask) {
					if (transf) u = transf;
					TEMPORARY_TEXT(identifier_found);
					for (int j = 0; start_at + j < i; j++)
						PUT_TO(identifier_found, Str::get_at(text, start_at + j));
					Analyser::analyse_find(W, L, identifier_found, u);
					DISCARD_TEXT(identifier_found);
				}
				start_at = -1; element_follows = FALSE;
			}
			if (Str::get_at(text, i) == '.') element_follows = TRUE;
			else if ((Str::get_at(text, i) == '-') && (Str::get_at(text, i+1) == '>')) {
				element_follows = TRUE; i++;
			} else element_follows = FALSE;
		}
	}
}

@h The identifier hash table.
We clearly need rapid access to a large symbols table, and we store this as
a hash. Identifiers are hash-coded with the following simple code, which is
simplified from one used by Inform; it's the algorithm called "X 30011"
in Aho, Sethi and Ullman, "Compilers: Principles, Techniques and Tools"
(1986), adapted slightly to separate out literal numbers.

@d HASH_TAB_SIZE 1000 /* the possible hash codes are 0 up to this minus 1 */
@d NUMBER_HASH 0 /* literal decimal integers, and no other words, have this hash code */

=
int Analyser::hash_code_from_word(text_stream *text) {
    unsigned int hash_code = 0;
    string_position p = Str::start(text);
    switch(Str::get(p)) {
    	case '-': if (Str::len(text) == 1) break; /* an isolated minus sign is an ordinary word */
    		/* and otherwise fall into... */
    	case '0': case '1': case '2': case '3': case '4':
    	case '5': case '6': case '7': case '8': case '9': {
    		int numeric = TRUE;
    		/* the first character may prove to be the start of a number: is this true? */
			for (p = Str::forward(p); Str::in_range(p); p = Str::forward(p))
				if (isdigit(Str::get(p)) == FALSE) numeric = FALSE;
			if (numeric) return NUMBER_HASH;
		}
    }
    for (p=Str::start(text); Str::in_range(p); p = Str::forward(p))
    	hash_code = (unsigned int) ((int) (hash_code*30011) + (Str::get(p)));
    return (int) (1+(hash_code % (HASH_TAB_SIZE-1))); /* result of X 30011, plus 1 */
}

@ The actual table is stored here:

=
typedef struct hash_table {
	struct linked_list *analysis_hash[HASH_TAB_SIZE]; /* of |hash_table_entry| */
	int analysis_hash_initialised; /* when we start up, array's contents are undefined */
} hash_table;

@ Where we define:

=
typedef struct hash_table_entry {
	text_stream *hash_key;
	int reserved_word; /* in the language currently being woven, that is */
	struct linked_list *usages; /* of |hash_table_entry_usage| */
	struct source_line *definition_line; /* or null, if it's not a constant, function or type name */
	struct language_function *as_function; /* for function names only */
	MEMORY_MANAGEMENT
} hash_table_entry;

@ A single routine is used both to interrogate the hash and to lodge values
in it, as usual with symbols tables. For example, the code to handle C-like
languages prepares for code analysis by calling this routine on the name
of each C function.

=
hash_table_entry *Analyser::find_hash_entry(hash_table *HT, text_stream *text, int create) {
	int h = Analyser::hash_code_from_word(text);
	if (h == NUMBER_HASH) return NULL;
	if (HT->analysis_hash_initialised == FALSE) {
		for (int i=0; i<HASH_TAB_SIZE; i++) HT->analysis_hash[i] = NULL;
		HT->analysis_hash_initialised = TRUE;
	}
	if (HT->analysis_hash[h] != NULL) {
		hash_table_entry *hte = NULL;
		LOOP_OVER_LINKED_LIST(hte, hash_table_entry, HT->analysis_hash[h])
			if (Str::eq(hte->hash_key, text))
				return hte;
	}
	if (create) {
		hash_table_entry *hte = CREATE(hash_table_entry);
		hte->hash_key = Str::duplicate(text);
		hte->usages = NEW_LINKED_LIST(hash_table_entry_usage);
		if (HT->analysis_hash[h] == NULL)
			HT->analysis_hash[h] = NEW_LINKED_LIST(hash_table_entry);
		ADD_TO_LINKED_LIST(hte, hash_table_entry, HT->analysis_hash[h]);
		return hte;
	}
	return NULL;
}

hash_table_entry *Analyser::find_hash_entry_for_section(section *S, text_stream *text,
	int create) {
	return Analyser::find_hash_entry(&(S->sect_target->symbols), text, create);
}

@ Marking and testing these bits:

=
hash_table_entry *Analyser::mark_reserved_word(hash_table *HT, text_stream *p, int e) {
	hash_table_entry *hte = Analyser::find_hash_entry(HT, p, TRUE);
	hte->reserved_word |= (1 << e);
	hte->definition_line = NULL;
	hte->as_function = NULL;
	return hte;
}

void Analyser::mark_reserved_word_for_section(section *S, text_stream *p, int e) {
	Analyser::mark_reserved_word(&(S->sect_target->symbols), p, e);
}

hash_table_entry *Analyser::mark_reserved_word_at_line(source_line *L, text_stream *p, int e) {
	if (L == NULL) internal_error("no line for rw");
	hash_table_entry *hte = 
		Analyser::mark_reserved_word(&(L->owning_section->sect_target->symbols), p, e);
	hte->definition_line = L;
	return hte;
}

int Analyser::is_reserved_word(hash_table *HT, text_stream *p, int e) {
	hash_table_entry *hte = Analyser::find_hash_entry(HT, p, FALSE);
	if ((hte) && (hte->reserved_word & (1 << e))) return TRUE;
	return FALSE;
}

int Analyser::is_reserved_word_for_section(section *S, text_stream *p, int e) {
	return Analyser::is_reserved_word(&(S->sect_target->symbols), p, e);
}

source_line *Analyser::get_defn_line(section *S, text_stream *p, int e) {
	hash_table_entry *hte = Analyser::find_hash_entry(&(S->sect_target->symbols), p, FALSE);
	if ((hte) && (hte->reserved_word & (1 << e))) return hte->definition_line;
	return NULL;
}

language_function *Analyser::get_function(section *S, text_stream *p, int e) {
	hash_table_entry *hte = Analyser::find_hash_entry(&(S->sect_target->symbols), p, FALSE);
	if ((hte) && (hte->reserved_word & (1 << e))) return hte->as_function;
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
	struct paragraph *usage_recorded_at;
	int form_of_usage; /* bitmap of the |*_USAGE| constants defined above */
	MEMORY_MANAGEMENT
} hash_table_entry_usage;

@ And here's how we create these usages:

=
void Analyser::analyse_find(web *W, source_line *L, text_stream *identifier, int u) {
	hash_table_entry *hte =
		Analyser::find_hash_entry_for_section(L->owning_section, identifier, FALSE);
	if (hte == NULL) return;
	hash_table_entry_usage *hteu = NULL;
	LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages)
		if (L->owning_paragraph == hteu->usage_recorded_at)
			break;
	if (hteu == NULL) {
		hteu = CREATE(hash_table_entry_usage);
		hteu->form_of_usage = 0;
		hteu->usage_recorded_at = L->owning_paragraph;
		ADD_TO_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages);
	}
	hteu->form_of_usage |= u;
}

@h Open-source project support.
The work here is all delegated. In each case we look for a script in the web's
folder: failing that, we fall back on a default script belonging to Inweb.

=
void Analyser::write_makefile(web *W, filename *F, module_search *I) {
	filename *prototype = Filenames::in_folder(W->md->path_to_web, I"makescript.txt");
	if (!(TextFiles::exists(prototype)))
		prototype = Filenames::in_folder(path_to_inweb_materials, I"makescript.txt");
	Makefiles::write(W, prototype, F, I);
}

void Analyser::write_gitignore(web *W, filename *F) {
	filename *prototype = Filenames::in_folder(W->md->path_to_web, I"gitignorescript.txt");
	if (!(TextFiles::exists(prototype)))
		prototype = Filenames::in_folder(path_to_inweb_materials, I"gitignorescript.txt");
	Git::write_gitignore(W, prototype, F);
}
