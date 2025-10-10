[Functions::] Types and Functions.

Basic support for languages to recognise structure and function declarations.

@ For each |typedef struct| we find, we will make one of these:

=
typedef struct language_type {
	struct text_stream *structure_name;
	int tangled; /* whether the structure definition has been tangled out */
	struct ls_section *structure_header_in;
	struct ls_line *structure_header_at; /* opening line of |typedef| */
	struct ls_line *typedef_ends; /* closing line, where |}| appears */
	struct linked_list *incorporates; /* of |language_type| */
	struct linked_list *elements; /* of |structure_element| */
	struct language_type *next_cst_alphabetically;
	CLASS_DEFINITION
} language_type;

@ =
language_type *first_cst_alphabetically = NULL;

language_type *Functions::new_struct(ls_web *W, text_stream *name, ls_section *S,
	ls_paragraph *par, ls_line *lst) {
	language_type *str = CREATE(language_type);
	@<Initialise the language type structure@>;
	CodeAnalysis::mark_reserved_word_at_line(lst, str->structure_name, RESERVED_COLOUR);
	@<Add this to the lists for its web and its paragraph@>;
	@<Insertion-sort this into the alphabetical list of all structures found@>;
	return str;
}

@<Initialise the language type structure@> =
	str->structure_name = Str::duplicate(name);
	str->structure_header_at = lst;
	str->structure_header_in = S;
	str->tangled = FALSE;
	str->typedef_ends = NULL;
	str->incorporates = NEW_LINKED_LIST(language_type);
	str->elements = NEW_LINKED_LIST(structure_element);

@<Add this to the lists for its web and its paragraph@> =
	LiterateSource::tag_paragraph(par, I"Structures");
	ADD_TO_LINKED_LIST(str, language_type, CodeAnalysis::language_types_list(W));
	ls_paragraph_analysis *P = CodeAnalysis::paragraph_details(lst);
	ADD_TO_LINKED_LIST(str, language_type, P->structures);

@<Insertion-sort this into the alphabetical list of all structures found@> =
	str->next_cst_alphabetically = NULL;
	if (first_cst_alphabetically == NULL) first_cst_alphabetically = str;
	else {
		int placed = FALSE;
		language_type *last = NULL;
		for (language_type *seq = first_cst_alphabetically; seq;
			seq = seq->next_cst_alphabetically) {
			if (Str::cmp(str->structure_name, seq->structure_name) < 0) {
				if (seq == first_cst_alphabetically) {
					str->next_cst_alphabetically = first_cst_alphabetically;
					first_cst_alphabetically = str;
				} else {
					last->next_cst_alphabetically = str;
					str->next_cst_alphabetically = seq;
				}
				placed = TRUE;
				break;
			}
			last = seq;
		}
		if (placed == FALSE) last->next_cst_alphabetically = str;
	}

@ A language can also create an instance of |structure_element| to record the
existence of the element |val|, and add it to the linked list of elements of
the structure being defined.

In InC, only, certain element names used often in Inform's source code are
given mildly special treatment. This doesn't amount to much. |allow_sharing|
has no effect on tangling, so it doesn't change the program. It simply
affects the reports in the woven code about where structures are used.

=
typedef struct structure_element {
	struct text_stream *element_name;
	struct ls_section *element_created_at;
	int allow_sharing;
	CLASS_DEFINITION
} structure_element;

@ =
structure_element *Functions::new_element(language_type *str, text_stream *elname,
	ls_line *lst, ls_section *S) {
	CodeAnalysis::mark_reserved_word_at_line(lst, elname, ELEMENT_COLOUR);
	structure_element *elt = CREATE(structure_element);
	elt->element_name = Str::duplicate(elname);
	elt->allow_sharing = FALSE;
	elt->element_created_at = S;
	if (LanguageMethods::share_element(WebStructure::section_language(S), elname))
		elt->allow_sharing = TRUE;
	ADD_TO_LINKED_LIST(elt, structure_element, str->elements);
	return elt;
}

@ =
language_type *Functions::find_structure(ls_web *W, text_stream *name) {
	language_type *str;
	LOOP_OVER_LINKED_LIST(str, language_type, CodeAnalysis::language_types_list(W))
		if (Str::eq(name, str->structure_name))
			return str;
	return NULL;
}

@h Functions.
Each function definition found results in one of these structures being made:

=
typedef struct language_function {
	struct text_stream *function_name; /* e.g., |"cultivate"| */
	struct text_stream *function_type; /* e.g., |"tree *"| */
	struct text_stream *function_arguments; /* e.g., |"int rainfall)"|: note |)| */
	struct ls_section *function_section; /* which section it's defined in */
	struct ls_line *function_header_at; /* where the first line of the header begins */
	int within_namespace; /* written using InC namespace dividers */
	int called_from_other_sections;
	int call_freely;
	int usage_described;
	int no_conditionals;
	struct ls_line *within_conditionals[MAX_CONDITIONAL_COMPILATION_STACK];
	CLASS_DEFINITION
} language_function;

@ =
language_function *Functions::new_function(text_stream *fname, ls_line *lst,
	ls_section *S) {
	ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
	@<Check the function is not a duplicate definition within the same paragraph@>;
	hash_table_entry *hte =
		CodeAnalysis::mark_reserved_word_at_line(lst, fname, FUNCTION_COLOUR);
	language_function *fn = CREATE(language_function);
	hte->as_function = fn;
	@<Initialise the function structure@>;
	@<Add the function to its paragraph and line@>;
	if (WebStructure::section_language(S)->supports_namespaces)
		@<Check that the function has its namespace correctly declared@>;
	return fn;
}

@ Note that we take a snapshot of the conditional compilation stack as
part of the function structure. We'll need it when predeclaring the function.

@<Initialise the function structure@> =
	fn->function_name = Str::duplicate(fname);
	fn->function_arguments = Str::new();
	fn->function_type = Str::new();
	fn->within_namespace = FALSE;
	fn->called_from_other_sections = FALSE;
	fn->call_freely = FALSE;
	fn->function_section = S;
	fn->function_header_at = lst;
	fn->usage_described = FALSE;
	if ((Str::eq_wide_string(fname, U"main")) &&
		(WebStructure::section_language(S)->C_like))
		fn->usage_described = TRUE;
	fn->no_conditionals = 0;

@ The following would become inefficient if there were enormous numbers of
functions defined in the same paragraph, but for now the overhead of creating
a dictionary with hash-lookup seems greater than the plausible saving of time.
The point of this check is to handle situations where the code in the web is
offering alternative definitions of the same function, within some form of
conditional compilation preprocessing -- if this, define |f| as this; otherwise,
define |f| as that -- which can otherwise be read as two declarations of |f|,
leading to spurious extra text at the weaving stage.

@<Check the function is not a duplicate definition within the same paragraph@> =
	ls_paragraph_analysis *P = CodeAnalysis::paragraph_details(lst);
	language_function *fn;
	LOOP_OVER_LINKED_LIST(fn, language_function, P->functions)
		if (Str::eq(fname, fn->function_name))
			return fn;

@<Add the function to its paragraph and line@> =
	ls_paragraph_analysis *P = CodeAnalysis::paragraph_details(lst);
	if (P) ADD_TO_LINKED_LIST(fn, language_function, P->functions);
	L->function_defined = fn;
	ls_web *W = S->owning_chapter->owning_web;
	ADD_TO_LINKED_LIST(fn, language_function, CodeAnalysis::language_functions_list(W));

@<Check that the function has its namespace correctly declared@> =
	text_stream *declared_namespace = NULL;
	text_stream *ambient_namespace = LiterateSource::unit_namespace(S->literate_source);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, fname, U"(%c+::)%c*")) {
		declared_namespace = mr.exp[0];
		fn->within_namespace = TRUE;
	} else if ((Str::eq_wide_string(fname, U"main")) &&
		(Str::eq_wide_string(ambient_namespace, U"Main::")))
		declared_namespace = I"Main::";
	if ((Str::ne(declared_namespace, ambient_namespace)) &&
		(LiterateSource::par_contains_very_early_code(LiterateSource::par_of_line(lst)) == FALSE)) {
		TEMPORARY_TEXT(err_mess)
		if (Str::len(declared_namespace) == 0)
			WRITE_TO(err_mess, "Function '%S' should have namespace prefix '%S'",
				fname, ambient_namespace);
		else if (Str::len(ambient_namespace) == 0)
			WRITE_TO(err_mess, "Function '%S' declared in a section with no namespace",
				fname);
		else
			WRITE_TO(err_mess, "Function '%S' declared in a section with the wrong namespace '%S'",
				fname, ambient_namespace);
		WebErrors::issue_at(err_mess, lst);
		DISCARD_TEXT(err_mess)
	}
	Regexp::dispose_of(&mr);

@

=
ls_paragraph *Functions::declaration_lsparagraph(language_function *fn) {
	return LiterateSource::par_of_line(fn->function_header_at);
}

@ "Elsewhere" here means "in a paragraph of code other than the one in which the
function's definition appears".

=
int Functions::used_elsewhere(language_function *fn) {
	ls_paragraph *par = Functions::declaration_lsparagraph(fn);
	ls_section *S = LiterateSource::section_of_par(par);
	hash_table_entry *hte =
		CodeAnalysis::find_hash_entry_for_section(fn->function_section,
			fn->function_name, FALSE);
	hash_table_entry_usage *hteu = NULL;
	LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages)
		if ((Functions::declaration_lsparagraph(fn) != hteu->usage_recorded_at) &&
			(S == LiterateSource::section_of_par(hteu->usage_recorded_at)))
			return TRUE;
	LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages)
		if (S != LiterateSource::section_of_par(hteu->usage_recorded_at))
			return TRUE;
	return FALSE;
}

@h Cataloguing.
This implements the additional information in the |-structures| and |-functions|
forms of section catalogue.

=
void Functions::catalogue(ls_section *S, int functions_too) {
	ls_web *W = S->owning_chapter->owning_web;
	language_type *str;
	LOOP_OVER_LINKED_LIST(str, language_type, CodeAnalysis::language_types_list(W))
		if (str->structure_header_in == S)
			PRINT(" %S ", str->structure_name);
	if (functions_too) {
		language_function *fn;
		LOOP_OVER_LINKED_LIST(fn, language_function, CodeAnalysis::language_functions_list(W))
			if (fn->function_section == S)
				PRINT("\n                     %S", fn->function_name);
	}
}
