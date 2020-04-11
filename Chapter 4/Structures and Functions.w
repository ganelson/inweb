[Structures::] Structures and Functions.

Basic support for languages to recognise structure and function declarations.

@ For each |typedef struct| we find, we will make one of these:

=
typedef struct c_structure {
	struct text_stream *structure_name;
	int tangled; /* whether the structure definition has been tangled out */
	struct source_line *structure_header_at; /* opening line of |typedef| */
	struct source_line *typedef_ends; /* closing line, where |}| appears */
	struct linked_list *incorporates; /* of |c_structure| */
	struct linked_list *elements; /* of |structure_element| */
	struct c_structure *next_cst_alphabetically;
	MEMORY_MANAGEMENT
} c_structure;

@ =
c_structure *first_cst_alphabetically = NULL;

c_structure *Structures::new_struct(web *W, text_stream *name, source_line *L) {
	c_structure *str = CREATE(c_structure);
	@<Initialise the C structure structure@>;
	Analyser::mark_reserved_word_at_line(L, str->structure_name, RESERVED_COLOUR);
	@<Add this to the lists for its web and its paragraph@>;
	@<Insertion-sort this into the alphabetical list of all structures found@>;
	return str;
}

@<Initialise the C structure structure@> =
	str->structure_name = Str::duplicate(name);
	str->structure_header_at = L;
	str->tangled = FALSE;
	str->typedef_ends = NULL;
	str->incorporates = NEW_LINKED_LIST(c_structure);
	str->elements = NEW_LINKED_LIST(structure_element);

@<Add this to the lists for its web and its paragraph@> =
	Tags::add_by_name(L->owning_paragraph, I"Structures");
	ADD_TO_LINKED_LIST(str, c_structure, W->c_structures);
	ADD_TO_LINKED_LIST(str, c_structure, L->owning_paragraph->structures);

@<Insertion-sort this into the alphabetical list of all structures found@> =
	str->next_cst_alphabetically = NULL;
	if (first_cst_alphabetically == NULL) first_cst_alphabetically = str;
	else {
		int placed = FALSE;
		c_structure *last = NULL;
		for (c_structure *seq = first_cst_alphabetically; seq;
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
	struct source_line *element_created_at;
	int allow_sharing;
	MEMORY_MANAGEMENT
} structure_element;

@ =
structure_element *Structures::new_element(c_structure *str, text_stream *elname,
	source_line *L) {
	Analyser::mark_reserved_word_at_line(L, elname, ELEMENT_COLOUR);
	structure_element *elt = CREATE(structure_element);
	elt->element_name = Str::duplicate(elname);
	elt->allow_sharing = FALSE;
	elt->element_created_at = L;
	if (LanguageMethods::share_element(L->owning_section->sect_language, elname))
		elt->allow_sharing = TRUE;
	ADD_TO_LINKED_LIST(elt, structure_element, str->elements);
	return elt;
}

@ =
c_structure *Structures::find_structure(web *W, text_stream *name) {
	c_structure *str;
	LOOP_OVER_LINKED_LIST(str, c_structure, W->c_structures)
		if (Str::eq(name, str->structure_name))
			return str;
	return NULL;
}

@h Functions.
Each function definition found results in one of these structures being made:

=
typedef struct function {
	struct text_stream *function_name; /* e.g., |"cultivate"| */
	struct text_stream *function_type; /* e.g., |"tree *"| */
	struct text_stream *function_arguments; /* e.g., |"int rainfall)"|: note |)| */
	struct source_line *function_header_at; /* where the first line of the header begins */
	int within_namespace; /* written using InC namespace dividers */
	int called_from_other_sections;
	int call_freely;
	int usage_described;
	int no_conditionals;
	struct source_line *within_conditionals[MAX_CONDITIONAL_COMPILATION_STACK];
	MEMORY_MANAGEMENT
} function;

@ =
function *Structures::new_function(text_stream *fname, source_line *L) {
	hash_table_entry *hte =
		Analyser::mark_reserved_word_at_line(L, fname, FUNCTION_COLOUR);
	function *fn = CREATE(function);
	hte->as_function = fn;
	@<Initialise the function structure@>;
	@<Add the function to its paragraph and line@>;
	if (L->owning_section->sect_language->supports_namespaces)
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
	fn->function_header_at = L;
	fn->usage_described = FALSE;
	fn->no_conditionals = 0;

@<Add the function to its paragraph and line@> =
	paragraph *P = L->owning_paragraph;
	if (P) ADD_TO_LINKED_LIST(fn, function, P->functions);
	L->function_defined = fn;

@<Check that the function has its namespace correctly declared@> =
	text_stream *declared_namespace = NULL;
	text_stream *ambient_namespace = L->owning_section->sect_namespace;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, fname, L"(%c+::)%c*")) {
		declared_namespace = mr.exp[0];
		fn->within_namespace = TRUE;
	} else if ((Str::eq_wide_string(fname, L"main")) &&
		(Str::eq_wide_string(ambient_namespace, L"Main::")))
		declared_namespace = I"Main::";
	if ((Str::ne(declared_namespace, ambient_namespace)) &&
		(L->owning_paragraph->placed_very_early == FALSE)) {
		TEMPORARY_TEXT(err_mess);
		if (Str::len(declared_namespace) == 0)
			WRITE_TO(err_mess, "Function '%S' should have namespace prefix '%S'",
				fname, ambient_namespace);
		else if (Str::len(ambient_namespace) == 0)
			WRITE_TO(err_mess, "Function '%S' declared in a section with no namespace",
				fname);
		else
			WRITE_TO(err_mess, "Function '%S' declared in a section with the wrong namespace '%S'",
				fname, ambient_namespace);
		Main::error_in_web(err_mess, L);
		DISCARD_TEXT(err_mess);
	}
	Regexp::dispose_of(&mr);

@h Cataloguing.
This implements the additional information in the |-structures| and |-functions|
forms of section catalogue.

=
void Structures::catalogue(section *S, int functions_too) {
	c_structure *str;
	LOOP_OVER(str, c_structure)
		if (str->structure_header_at->owning_section == S)
			PRINT(" %S ", str->structure_name);
	if (functions_too) {
		function *fn;
		LOOP_OVER(fn, function)
			if (fn->function_header_at->owning_section == S)
				PRINT("\n                     %S", fn->function_name);
	}
}
