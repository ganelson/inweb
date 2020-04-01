[CLike::] C-Like Languages.

To provide special features for the whole C family of languages.

@h Creation.

=
programming_language *CLike::create_C(void) {
	programming_language *pl = Languages::new_language(I"C", I".c");
	CLike::make_c_like(pl);
	return pl;
}

programming_language *CLike::create_CPP(void) {
	programming_language *pl = Languages::new_language(I"C++", I".cpp");
	CLike::make_c_like(pl);
	return pl;
}

@h What makes a language C-like?
This does:

=
void CLike::make_c_like(programming_language *pl) {
	pl->supports_enumerations = TRUE;

	METHOD_ADD(pl, FURTHER_PARSING_PAR_MTID, CLike::further_parsing);
	METHOD_ADD(pl, SUBCATEGORISE_LINE_PAR_MTID, CLike::subcategorise_code);

	METHOD_ADD(pl, SHEBANG_TAN_MTID, CLike::shebang);
	METHOD_ADD(pl, ADDITIONAL_EARLY_MATTER_TAN_MTID, CLike::additional_early_matter);
	METHOD_ADD(pl, START_DEFN_TAN_MTID, CLike::start_definition);
	METHOD_ADD(pl, PROLONG_DEFN_TAN_MTID, CLike::prolong_definition);
	METHOD_ADD(pl, END_DEFN_TAN_MTID, CLike::end_definition);
	METHOD_ADD(pl, ADDITIONAL_PREDECLARATIONS_TAN_MTID, CLike::additional_predeclarations);
	METHOD_ADD(pl, INSERT_LINE_MARKER_TAN_MTID, CLike::insert_line_marker);
	METHOD_ADD(pl, BEFORE_MACRO_EXPANSION_TAN_MTID, CLike::before_macro_expansion);
	METHOD_ADD(pl, AFTER_MACRO_EXPANSION_TAN_MTID, CLike::after_macro_expansion);
	METHOD_ADD(pl, COMMENT_TAN_MTID, CLike::comment);
	METHOD_ADD(pl, OPEN_IFDEF_TAN_MTID, CLike::open_ifdef);
	METHOD_ADD(pl, CLOSE_IFDEF_TAN_MTID, CLike::close_ifdef);
	METHOD_ADD(pl, PARSE_COMMENT_TAN_MTID, CLike::parse_comment);

	METHOD_ADD(pl, BEGIN_WEAVE_WEA_MTID, CLike::begin_weave);
	METHOD_ADD(pl, RESET_SYNTAX_COLOURING_WEA_MTID, CLike::reset_syntax_colouring);
	METHOD_ADD(pl, SYNTAX_COLOUR_WEA_MTID, CLike::syntax_colour);

	METHOD_ADD(pl, CATALOGUE_ANA_MTID, CLike::catalogue);
	METHOD_ADD(pl, EARLY_PREWEAVE_ANALYSIS_ANA_MTID, CLike::analyse_code);
	METHOD_ADD(pl, LATE_PREWEAVE_ANALYSIS_ANA_MTID, CLike::post_analysis);
}

@h Parsing.
After a web has been read in and then parsed, code supporting its language
is then called to do any further parsing it might want to. The code below
is run if the language is "C-like": regular C and InC both qualify.

In scanning the web, we need to keep track of |#ifdef| and |#endif| pairs
in the source. This matters because we will want to predeclare functions;
but if functions are declared in conditional compilation, then their
predeclarations have to be made under the same conditions.

The following stack holds the current set of conditional compilations which the
source line being scanned lies within.

@d MAX_CONDITIONAL_COMPILATION_STACK 8

=
int cc_sp = 0;
source_line *cc_stack[MAX_CONDITIONAL_COMPILATION_STACK];
c_structure *first_cst_alphabetically = NULL;

void CLike::further_parsing(programming_language *self, web *W) {
	@<Find every typedef struct in the tangle@>;
	@<Work out which structs contain which others@>;
	cc_sp = 0;
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		if ((L->category == CODE_BODY_LCAT) ||
			(L->category == BEGIN_DEFINITION_LCAT) ||
			(L->category == CONT_DEFINITION_LCAT)) {
			@<Look for conditional compilation on this line@>;
			@<Look for a function definition on this line@>;
		}
	if (cc_sp > 0)
		Main::error_in_web(I"program ended with conditional compilation open", NULL);
}

@<Look for conditional compilation on this line@> =
	match_results mr = Regexp::create_mr();
	if ((Regexp::match(&mr, L->text, L" *#ifn*def %c+")) ||
		(Regexp::match(&mr, L->text, L" *#IFN*DEF %c+"))) {
		if (cc_sp >= MAX_CONDITIONAL_COMPILATION_STACK)
			Main::error_in_web(I"conditional compilation too deeply nested", L);
		else
			cc_stack[cc_sp++] = L;
	}
	if ((Regexp::match(&mr, L->text, L" *#endif *")) ||
		(Regexp::match(&mr, L->text, L" *#ENDIF *"))) {
		if (cc_sp <= 0)
			Main::error_in_web(I"found #endif without #ifdef or #ifndef", L);
		else
			cc_sp--;
	}

@h Structures.
We're going to assume that the C source code uses structures looking
something like this:

	|typedef struct fruit {|
	|    struct pip the_pips[5];|
	|    struct fruit *often_confused_with;|
	|    struct tree_species *grows_on;|
	|    int typical_weight;|
	|} fruit;|

which adopts the traditional layout conventions of Kernighan and Ritchie.
The structure definitions in this Inweb web all take the required form,
of course, and provide many more examples.

Note that a |fruit| structure contains a |pip| structure (in fact, five of
them), but only contains pointers to |tree_species| structures and itself.
C requires therefore that the structure definition for |pip| must occur
earlier in the code than that for |fruit|. This is a nuisance, so Inweb
takes care of it automatically.

@<Find every typedef struct in the tangle@> =
	c_structure *current_str = NULL;
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W)) {
		match_results mr = Regexp::create_mr();

		if (Regexp::match(&mr, L->text, L"typedef struct (%i+) %c*{%c*")) {
			@<Attach a structure to this source line@>;
			Tags::add_by_name(L->owning_paragraph, I"Structures");
		} else if ((Str::get_first_char(L->text) == '}') && (current_str)) {
			current_str->typedef_ends = L;
			current_str = NULL;
		} else if ((current_str) && (current_str->typedef_ends == NULL)) {
			@<Work through the a line in the structure definition@>;
		} else if ((Regexp::match(&mr, L->text, L"typedef %c+")) &&
			(Regexp::match(&mr, L->text, L"%c+##%c+") == FALSE)) {
			if (L->owning_paragraph->placed_very_early == FALSE)
				L->category = TYPEDEF_LCAT;
		}
		Regexp::dispose_of(&mr);
	}

@ For each |typedef struct| we find, we will make one of these:

=
typedef struct c_structure {
	struct text_stream *structure_name;
	int tangled; /* whether the structure definition has been tangled out */
	struct source_line *typedef_begins; /* opening line of |typedef| */
	struct source_line *typedef_ends; /* closing line, where |}| appears */
	struct linked_list *incorporates; /* of |c_structure| */
	struct linked_list *elements; /* of |structure_element| */
	struct c_structure *next_cst_alphabetically;
	MEMORY_MANAGEMENT
} c_structure;

@<Attach a structure to this source line@> =
	c_structure *str = CREATE(c_structure);
	@<Initialise the C structure structure@>;
	Analyser::mark_reserved_word(L->owning_section, str->structure_name, RESERVED_COLOUR);
	@<Add this to the lists for its web and its paragraph@>;
	@<Insertion-sort this into the alphabetical list of all structures found@>;
	current_str = str;

@<Initialise the C structure structure@> =
	str->structure_name = Str::duplicate(mr.exp[0]);
	str->typedef_begins = L;
	str->tangled = FALSE;
	str->typedef_ends = NULL;
	str->incorporates = NEW_LINKED_LIST(c_structure);
	str->elements = NEW_LINKED_LIST(structure_element);

@<Add this to the lists for its web and its paragraph@> =
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

@ At this point we're reading a line within the structure's definition; for
the sake of an illustrative example, let's suppose that line is:

	|    unsigned long long int *val;|

We need to extract the element name, |val|, and make a note of it.

@<Work through the a line in the structure definition@> =
	TEMPORARY_TEXT(p);
	Str::copy(p, L->text);
	Str::trim_white_space(p);
	@<Remove C type modifiers from the front of p@>;
	string_position pos = Str::start(p);
	if (Str::get(pos) != '/') { /* a slash must introduce a comment here */
		@<Move pos past the type name@>;
		@<Move pos past any typographical type modifiers@>;
		if (Str::in_range(pos)) {
			match_results mr = Regexp::create_mr();
			TEMPORARY_TEXT(elname);
			@<Copy the element name into elname@>;
			@<Record the element@>;
			DISCARD_TEXT(elname);
			Regexp::dispose_of(&mr);
		}
	}
	DISCARD_TEXT(p);

@ The following reduces |unsigned long long int *val;| to just |int *val;|.

@<Remove C type modifiers from the front of p@> =
	wchar_t *modifier_patterns[] = {
		L"(struct )(%C%c*)", L"(signed )(%C%c*)", L"(unsigned )(%C%c*)",
		L"(short )(%C%c*)", L"(long )(%C%c*)", L"(static )(%C%c*)", NULL };
	int seek_modifiers = TRUE;
	while (seek_modifiers) {
		seek_modifiers = FALSE;
		for (int i = 0; modifier_patterns[i]; i++)
			if (Regexp::match(&mr, p, modifier_patterns[i])) {
				Str::copy(p, mr.exp[1]);
				seek_modifiers = TRUE;
				break;
			}
	}

@ At this point |p| has been reduced to |int *val;|, but the following moves
|pos| to point to the |*|:

@<Move pos past the type name@> =
	while ((Str::get(pos)) && (Characters::is_space_or_tab(Str::get(pos)) == FALSE))
		pos = Str::forward(pos);

@ And this moves it past the |*| to point to the |v| in |int *val;|:

@<Move pos past any typographical type modifiers@> =
	while ((Characters::is_space_or_tab(Str::get(pos))) || (Str::get(pos) == '*') ||
		(Str::get(pos) == '(') || (Str::get(pos) == ')')) pos = Str::forward(pos);

@ This then first copies the substring |val;| into |elname|, then cuts that
down to just the identifier characters at the front, i.e., to |val|.

@<Copy the element name into elname@> =
	Str::substr(elname, pos, Str::end(p));
	if (Regexp::match(&mr, elname, L"(%i+)%c*")) Str::copy(elname, mr.exp[0]);

@ Now we create an instance of |structure_element| to record the existence
of the element |val|, and add it to the linked list of elements of the
structure being defined.

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

@<Record the element@> =
	Analyser::mark_reserved_word(L->owning_section, elname, ELEMENT_COLOUR);
	structure_element *elt = CREATE(structure_element);
	elt->element_name = Str::duplicate(elname);
	elt->allow_sharing = FALSE;
	elt->element_created_at = L;
	if (Languages::share_element(W->main_language, elname)) elt->allow_sharing = TRUE;
	ADD_TO_LINKED_LIST(elt, structure_element, current_str->elements);

@h Structure dependency.
We say that S depends on T if |struct S| has an element whose type is
|struct T|. That matters because if so then |struct T| has to be defined
before |struct S| in the tangled output.

It's important to note that |struct S| merely having a member of type
|struct *T| does not create a dependency. In the code below, because |%i|
matches only identifier characters and |*| is not one of those, a line like

	|    struct fruit *often_confused_with;|

will not trip the switch here.

@<Work out which structs contain which others@> =
	c_structure *current_str;
	LOOP_OVER(current_str, c_structure) {
		for (source_line *L = current_str->typedef_begins;
			((L) && (L != current_str->typedef_ends));
			L = L->next_line) {
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, L->text, L" struct (%i+) %i%c*"))
				@<One structure appears to contain a copy of another one@>;
			Regexp::dispose_of(&mr);
		}
	}

@<One structure appears to contain a copy of another one@> =
	text_stream *used_structure = mr.exp[0];
	c_structure *str;
	LOOP_OVER_LINKED_LIST(str, c_structure, W->c_structures)
		if ((str != current_str) &&
			(Str::eq(used_structure, str->structure_name)))
			ADD_TO_LINKED_LIST(str, c_structure, current_str->incorporates);

@h Functions.
Second round: we recognise a C function as being a line which takes the form

	|type identifier(args...|

where we parse |type| only minimally. In InC (only), the identifier can
contain namespace dividers written |::|. Function declarations, we will assume,
always begin on column 1 of their source files, and we expect them to take
modern ANSI C style, not the long-deprecated late 1970s C style.

@<Look for a function definition on this line@> =
	if (!(Characters::is_space_or_tab(Str::get_first_char(L->text)))) {
		TEMPORARY_TEXT(qualifiers);
		TEMPORARY_TEXT(modified);
		Str::copy(modified, L->text);
		@<Parse past any type modifiers@>;
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, modified, L"(%i+) (%**)(%i+)%((%c*)")) {
			TEMPORARY_TEXT(ftype); Str::copy(ftype, mr.exp[0]);
			TEMPORARY_TEXT(asts); Str::copy(asts, mr.exp[1]);
			TEMPORARY_TEXT(fname); Str::copy(fname, mr.exp[2]);
			TEMPORARY_TEXT(arguments); Str::copy(arguments, mr.exp[3]);
			@<A function definition was found@>;
			DISCARD_TEXT(ftype);
			DISCARD_TEXT(asts);
			DISCARD_TEXT(fname);
			DISCARD_TEXT(arguments);
		}
		DISCARD_TEXT(qualifiers);
		DISCARD_TEXT(modified);
		Regexp::dispose_of(&mr);
	}

@ C has a whole soup of reserved words applying to types, but most of them
can't apply to the return type of a function. We do, however, iterate so that
forms like |static long long int| will work.

@<Parse past any type modifiers@> =
	wchar_t *modifier_patterns[] = {
		L"(signed )(%C%c*)", L"(unsigned )(%C%c*)",
		L"(short )(%C%c*)", L"(long )(%C%c*)", L"(static )(%C%c*)", NULL };
	int seek_modifiers = TRUE;
	while (seek_modifiers) {
		seek_modifiers = FALSE;
		match_results mr = Regexp::create_mr();
		for (int i = 0; modifier_patterns[i]; i++)
			if (Regexp::match(&mr, modified, modifier_patterns[i])) {
				Str::concatenate(qualifiers, mr.exp[0]);
				Str::copy(modified, mr.exp[1]);
				seek_modifiers = TRUE; break;
			}
		Regexp::dispose_of(&mr);
	}

@<A function definition was found@> =
	@<Soak up further arguments from continuation lines after the declaration@>;
	Analyser::mark_reserved_word(L->owning_section, fname, FUNCTION_COLOUR);
	function *fn = CREATE(function);
	@<Initialise the function structure@>;
	@<Add the function to its paragraph and line@>;
	if (W->main_language->supports_namespaces)
		@<Check that the function has its namespace correctly declared@>;

@ In some cases the function's declaration runs over several lines:

	|void World::Subjects::make_adj_const_domain(inference_subject *infs,|
	|	instance *nc, property *prn) {|

Having read the first line, |arguments| would contain |inference_subject *infs,|
and would thus be incomplete. We continue across subsequent lines until we
reach an open brace |{|.

@d MAX_ARG_LINES 32 /* maximum number of lines over which a function's header can extend */

@<Soak up further arguments from continuation lines after the declaration@> =
	source_line *AL = L;
	int arg_lc = 1;
	while ((AL) && (arg_lc <= MAX_ARG_LINES) && (Regexp::find_open_brace(arguments) == -1)) {
		if (AL->next_line == NULL) {
			TEMPORARY_TEXT(err_mess);
			WRITE_TO(err_mess, "Function '%S' has a malformed declaration", fname);
			Main::error_in_web(err_mess, L);
			DISCARD_TEXT(err_mess);
			break;
		}
		AL = AL->next_line;
		WRITE_TO(arguments, " %S", AL->text);
		arg_lc++;
	}
	int n = Regexp::find_open_brace(arguments);
	if (n >= 0) Str::truncate(arguments, n);

@ Each function definition found results in one of these structures being made:

=
typedef struct function {
	struct text_stream *function_name; /* e.g., |"cultivate"| */
	struct text_stream *function_type; /* e.g., |"tree *"| */
	struct text_stream *function_arguments; /* e.g., |"int rainfall)"|: note |)| */
	struct source_line *function_header_at; /* where the first line of the header begins */
	int within_namespace; /* written using InC namespace dividers */
	int called_from_other_sections;
	int call_freely;
	int no_conditionals;
	struct source_line *within_conditionals[MAX_CONDITIONAL_COMPILATION_STACK];
	MEMORY_MANAGEMENT
} function;

@ Note that we take a snapshot of the conditional compilation stack as
part of the function structure. We'll need it when predeclaring the function.

@<Initialise the function structure@> =
	fn->function_name = Str::duplicate(fname);
	fn->function_arguments = Str::duplicate(arguments);
	fn->function_type = Str::new();
	WRITE_TO(fn->function_type, "%S%S %S", qualifiers, ftype, asts);
	fn->within_namespace = FALSE;
	fn->called_from_other_sections = FALSE;
	fn->call_freely = FALSE;
	if ((Str::eq_wide_string(fn->function_name, L"isdigit")) &&
		(W->main_language->supports_namespaces))
		fn->call_freely = TRUE;
	fn->function_header_at = L;

	fn->no_conditionals = cc_sp;
	for (int i=0; i<cc_sp; i++) fn->within_conditionals[i] = cc_stack[i];

@<Add the function to its paragraph and line@> =
	paragraph *P = L->owning_paragraph;
	if (P) ADD_TO_LINKED_LIST(fn, function, P->functions);
	L->function_defined = fn;

@<Check that the function has its namespace correctly declared@> =
	text_stream *declared_namespace = NULL;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, fname, L"(%c+::)%c*")) {
		declared_namespace = mr.exp[0];
		fn->within_namespace = TRUE;
	} else if ((Str::eq_wide_string(fname, L"main")) && (Str::eq_wide_string(S->sect_namespace, L"Main::")))
		declared_namespace = I"Main::";
	if ((Str::ne(declared_namespace, S->sect_namespace)) &&
		(L->owning_paragraph->placed_very_early == FALSE)) {
		TEMPORARY_TEXT(err_mess);
		if (Str::len(declared_namespace) == 0)
			WRITE_TO(err_mess, "Function '%S' should have namespace prefix '%S'",
				fname, S->sect_namespace);
		else if (Str::len(S->sect_namespace) == 0)
			WRITE_TO(err_mess, "Function '%S' declared in a section with no namespace",
				fname);
		else
			WRITE_TO(err_mess, "Function '%S' declared in a section with the wrong namespace '%S'",
				fname, S->sect_namespace);
		Main::error_in_web(err_mess, L);
		DISCARD_TEXT(err_mess);
	}
	Regexp::dispose_of(&mr);

@ The following 

=
c_structure *CLike::find_structure(web *W, text_stream *name) {
	c_structure *str;
	LOOP_OVER_LINKED_LIST(str, c_structure, W->c_structures)
		if (Str::eq(name, str->structure_name))
			return str;
	return NULL;
}

@h Subcategorisation.
The following is called after the parser gives every line in the web a
category; we can, if we wish, change that for a more exotic one. We simply
look for a |#include| of one of the ANSI C standard libraries.

=
void CLike::subcategorise_code(programming_language *self, source_line *L) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, L"#include <(%C+)>%c*")) {
		text_stream *library_file = mr.exp[0];
		wchar_t *ansi_libs[] = {
			L"assert.h", L"ctype.h", L"errno.h", L"float.h", L"limits.h",
			L"locale.h", L"math.h", L"setjmp.h", L"signal.h", L"stdarg.h",
			L"stddef.h", L"stdio.h", L"stdlib.h", L"string.h", L"time.h",
			NULL
		};
		for (int j = 0; ansi_libs[j]; j++)
			if (Str::eq_wide_string(library_file, ansi_libs[j]))
				L->category = C_LIBRARY_INCLUDE_LCAT;
	}
	Regexp::dispose_of(&mr);
}

@h Tangling extras.
The "shebang" routine for a language is called to add anything it wants to
at the very top of the tangled code. (For a scripting language such as
Perl or Python, that might be a shebang: hence the name.)

But we will use it to defime the constant |PLATFORM_POSIX| everywhere except
Windows. This needs to happen right at the top, because the "very early
code" may contain material conditional on whether it is defined.

=
void CLike::shebang(programming_language *self, text_stream *OUT, web *W, tangle_target *target) {
	WRITE("#ifndef PLATFORM_WINDOWS\n");
	WRITE("#define PLATFORM_POSIX\n");
	WRITE("#endif\n");
}

@ "Additional early matter" is used for the inclusions of the ANSI library
files. We need to do that early, because otherwise types declared in them
(such as |FILE|) won't exist in time for the structure definitions we will
be tangling next.

It might seem reasonable to move all |#include| files up front this way,
not just the ANSI ones. But that would defeat any conditional compilation
around the inclusions; which Inform (for instance) needs in order to make
platform-specific details to handle directories without POSIX in Windows.

=
void CLike::additional_early_matter(programming_language *self, text_stream *OUT, web *W, tangle_target *target) {
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, target)
		if (L->category == C_LIBRARY_INCLUDE_LCAT) {
			Tags::open_ifdefs(OUT, L->owning_paragraph);
			Tangler::tangle_code(OUT, L->text, S, L);
			WRITE("\n");
			Tags::close_ifdefs(OUT, L->owning_paragraph);
		}
}

@ =
int CLike::start_definition(programming_language *self, text_stream *OUT, text_stream *term, text_stream *start, section *S, source_line *L) {
	WRITE("#define %S ", term);
	Tangler::tangle_code(OUT, start, S, L);
	return TRUE;
}

int CLike::prolong_definition(programming_language *self, text_stream *OUT, text_stream *more, section *S, source_line *L) {
	WRITE("\\\n    ");
	Tangler::tangle_code(OUT, more, S, L);
	return TRUE;
}

int CLike::end_definition(programming_language *self, text_stream *OUT, section *S, source_line *L) {
	WRITE("\n");
	return TRUE;
}

@h Tangling predeclarations.
This is where a language gets the chance to tangle predeclarations, early
on in the file. We use it first for the structures, and then the functions --
in that order since the function types likely involve the typedef names for the
structures.

=
void CLike::additional_predeclarations(programming_language *self, text_stream *OUT, web *W) {
	@<Predeclare the structures in a well-founded order@>;
	@<Predeclare simple typedefs@>;
	@<Predeclare the functions@>;
}

@ A "simple typedef" here means one that is aliasing something other than
a structure: for example |typedef unsigned int uint;| would be a simple typedef.

@<Predeclare simple typedefs@> =
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		if (L->category == TYPEDEF_LCAT) {
			Tags::open_ifdefs(OUT, L->owning_paragraph);
			Languages::tangle_code(OUT, W->main_language, L->text);
			WRITE("\n");
			Tags::close_ifdefs(OUT, L->owning_paragraph);
		}

@ It's easy enough to make sure structures are tangled so that inner ones
precede outer, but we need to be careful to be terminating if the source
code we're given is not well founded because of an error by its programmer:
for example, that structure A contains B contains C contains A. We do this
with the |tangled| flag, which is |FALSE| if a structure hasn't been
started yet, |NOT_APPLICABLE| if it's in progress, and |TRUE| if it's
finished.

@<Predeclare the structures in a well-founded order@> =
	c_structure *str;
	LOOP_OVER_LINKED_LIST(str, c_structure, W->c_structures)
		str->tangled = FALSE;
	LOOP_OVER_LINKED_LIST(str, c_structure, W->c_structures)
		CLike::tangle_structure(OUT, self, str);

@ Using the following recursion, which is therefore terminating:

=
void CLike::tangle_structure(OUTPUT_STREAM, programming_language *self, c_structure *str) {
	if (str->tangled != FALSE) return;
	str->tangled = NOT_APPLICABLE;
	c_structure *embodied = NULL;
	LOOP_OVER_LINKED_LIST(embodied, c_structure, str->incorporates)
		CLike::tangle_structure(OUT, self, embodied);
	str->tangled = TRUE;
	Tags::open_ifdefs(OUT, str->typedef_begins->owning_paragraph);
	Languages::insert_line_marker(OUT, self, str->typedef_begins);
	for (source_line *L = str->typedef_begins; L; L = L->next_line) {
		WRITE("%S\n", L->text);
		L->suppress_tangling = TRUE;
		if (L == str->typedef_ends) break;
	}
	Tags::close_ifdefs(OUT, str->typedef_begins->owning_paragraph);
}

@ Functions are rather easier to deal with. In general, if a function was
defined within some number of nested |#ifdef| or |#ifndef| directives, then
we reproduce those around the predeclaration: except, as a special trick,
if the line contains a particular comment. For example:

	|#ifdef SOLARIS /* inweb: always predeclare */|

That exempts any functions inside this condition from meeting the condition
in order to be predeclared. It's a trick used in the foundation module just
a couple of times: the idea is that although a definition of the functions
is given which only works under SOLARIS, an external piece of code will
provide alternative function definitions which would work without SOLARIS.
The functions therefore need predeclaration regardless, because they will
exist either way.

@<Predeclare the functions@> =
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		if ((L->function_defined) && (L->owning_paragraph->placed_very_early == FALSE)) {
			function *fn = L->function_defined;
			int to_close = 0;
			for (int i=0; i<fn->no_conditionals; i++) {
				match_results mr = Regexp::create_mr();
				if (!(Regexp::match(&mr, fn->within_conditionals[i]->text,
					L"%c*inweb: always predeclare%c*"))) {
					WRITE("%S\n", fn->within_conditionals[i]->text);
					to_close++;
				}
			}
			Tags::open_ifdefs(OUT, L->owning_paragraph);
			Languages::insert_line_marker(OUT, W->main_language, L);
			WRITE("%S ", fn->function_type);
			Languages::tangle_code(OUT, W->main_language, fn->function_name);
			WRITE("(%S;\n", fn->function_arguments);
			Tags::close_ifdefs(OUT, L->owning_paragraph);
			for (int i=0; i<to_close; i++) {
				WRITE("#endif\n");
			}
		}

@h Line markers.
In order for C compilers to report C syntax errors on the correct line,
despite rearranging by automatic tools, C conventionally recognises the
preprocessor directive |#line| to tell it that a contiguous extract follows
from the given file; we generate this automatically.

=
void CLike::insert_line_marker(programming_language *self, text_stream *OUT, source_line *L) {
	WRITE("#line %d \"%/f\"\n",
		L->source.line_count,
		L->source.text_file_filename);
}

@h Comments.
We write comments the old-fashioned way, that is, not using |//|.

=
void CLike::comment(programming_language *self, text_stream *OUT, text_stream *comm) {
	WRITE("/* %S */\n", comm);
}

@ When parsing, we do recognise |//| comments, but we have to be careful not to
react to comment markers inside comments or double-qupted text which is outside
of comments, all of which makes this a little elaborate:

=
int CLike::parse_comment(programming_language *self,
	text_stream *line, text_stream *part_before_comment, text_stream *part_within_comment) {
	int q_mode = FALSE, c_mode = FALSE, non_white_space = FALSE, c_position = -1, c_end = -1;
	for (int i=0; i<Str::len(line); i++) {
		wchar_t c = Str::get_at(line, i);
		if (c_mode) {
			if (c == '*') {
				wchar_t d = Str::get_at(line, i+1);
				if (d == '/') { c_mode = FALSE; c_end = i; i++; }
			}
		} else {
			if (!(Characters::is_whitespace(c))) non_white_space = TRUE;
			if ((c == '\\') && (q_mode)) i += 1;
			if (c == '"') q_mode = q_mode?FALSE:TRUE;
			if ((c == '/') && (!q_mode)) {
				wchar_t d = Str::get_at(line, i+1);
				if (d == '/') { c_mode = TRUE; c_position = i; c_end = Str::len(line); non_white_space = FALSE; break; }
				if (d == '*') { c_mode = TRUE; c_position = i; non_white_space = FALSE; }
			}
		}
	}
	if ((c_position >= 0) && (non_white_space == FALSE)) {
		Str::clear(part_before_comment);
		for (int i=0; i<c_position; i++) PUT_TO(part_before_comment, Str::get_at(line, i));
		Str::clear(part_within_comment);
		for (int i=c_position + 2; i<c_end; i++) PUT_TO(part_within_comment, Str::get_at(line, i));
		Str::trim_white_space(part_within_comment);
		return TRUE;
	}
	return FALSE;
}

@h Ifdefs.

=
void CLike::open_ifdef(programming_language *self, text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) WRITE("#ifdef %S\n", symbol);
	else WRITE("#ifndef %S\n", symbol);
}
void CLike::close_ifdef(programming_language *self, text_stream *OUT, text_stream *symbol, int sense) {
	WRITE("#endif /* %S */\n", symbol);
}

@h Before and after expansion.
Places braces before and after expanded paragraph macros ensures that code like

	|if (x == y) @<Do something dramatic@>;|

tangles to something like this:

	|if (x == y)|
	|{|
	|...|
	|}|

so that the variables defined inside the macro have limited scope, and so that
multi-line macros are treated as a single statement by |if|, |while| and so on.
(The new-line before the opening brace protects us against problems with
Perl comments; Perl shares this code.)

=
void CLike::before_macro_expansion(programming_language *self, OUTPUT_STREAM, para_macro *pmac) {
	WRITE("\n{\n");
}

void CLike::after_macro_expansion(programming_language *self, OUTPUT_STREAM, para_macro *pmac) {
	WRITE("}\n");
}

@h Begin weave.
We use this opportunity only to register C's usual set of reserved words as
being of interest for syntax colouring. |FILE| gets in even though it's not
technically reserved but only a type name, defined in the standard C library.

=
void CLike::begin_weave(programming_language *self, section *S, weave_target *wv) {
	Analyser::mark_reserved_word(S, I"FILE", RESERVED_COLOUR);

	Analyser::mark_reserved_word(S, I"auto", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"break", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"case", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"char", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"const", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"continue", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"default", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"do", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"double", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"else", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"enum", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"extern", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"float", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"for", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"goto", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"if", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"int", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"long", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"register", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"return", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"short", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"signed", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"sizeof", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"static", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"struct", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"switch", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"typedef", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"union", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"unsigned", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"void", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"volatile", RESERVED_COLOUR);
	Analyser::mark_reserved_word(S, I"while", RESERVED_COLOUR);
}

@h Syntax colouring.
This is a very simple syntax colouring algorithm. The state at any given
time is a single variable, the current category of code being looked at:

=
void CLike::reset_syntax_colouring(programming_language *self) {
	colouring_state = PLAIN_COLOUR;
}

@ =
int CLike::syntax_colour(programming_language *self, text_stream *OUT, weave_target *wv,
	web *W, chapter *C, section *S, source_line *L, text_stream *matter,
	text_stream *colouring) {
	for (int i=0; i < Str::len(matter); i++) {
		int skip = FALSE, one_off = -1, will_be = -1;
		switch (colouring_state) {
			case PLAIN_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\"': colouring_state = STRING_COLOUR; break;
					case '\'': colouring_state = CHAR_LITERAL_COLOUR; break;
				}
				if ((Regexp::identifier_char(Str::get_at(matter, i))) &&
					(Str::get_at(matter, i) != ':')) {
					if ((!(isdigit(Str::get_at(matter, i)))) ||
						((i>0) && (Str::get_at(colouring, i-1) == IDENTIFIER_COLOUR)))
						one_off = IDENTIFIER_COLOUR;
				}
				break;
			case CHAR_LITERAL_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\\': skip = TRUE; break;
					case '\'': will_be = PLAIN_COLOUR; break;
				}
				break;
			case STRING_COLOUR:
				switch (Str::get_at(matter, i)) {
					case '\\': skip = TRUE; break;
					case '\"': will_be = PLAIN_COLOUR; break;
				}
				break;
		}
		if (one_off >= 0) Str::put_at(colouring, i, (char) one_off);
		else Str::put_at(colouring, i, (char) colouring_state);
		if (will_be >= 0) colouring_state = (char) will_be;
		if ((skip) && (Str::get_at(matter, i+1))) i++;
	}
	@<Find identifiers and colour them appropriately@>;
	return FALSE;
}

@ Note that an identifier, followed by |::| and then another identifier, is
merged here into one long identifier. Thus in the code |r = X::Y(1);|, the
above routine would identify three identifiers, |r|, |X| and |Y|; but the
code below merges these into |r| and |X::Y|.

@<Find identifiers and colour them appropriately@> =
	int ident_from = -1;
	for (int i=0; i < Str::len(matter); i++) {
		if ((Str::get_at(matter, i) == ':') && (Str::get_at(matter, i+1) == ':') &&
			(Str::get_at(colouring, i-1) == IDENTIFIER_COLOUR) &&
			(Str::get_at(colouring, i+2) == IDENTIFIER_COLOUR)) {
			Str::put_at(colouring, i, IDENTIFIER_COLOUR);
			Str::put_at(colouring, i+1, IDENTIFIER_COLOUR);
		}
		if (Str::get_at(colouring, i) == IDENTIFIER_COLOUR) {
			if (ident_from == -1) ident_from = i;
		} else {
			if (ident_from >= 0)
				CLike::colour_ident(S, matter, colouring, ident_from, i-1);
			ident_from = -1;
		}
	}
	if (ident_from >= 0)
		CLike::colour_ident(S, matter, colouring, ident_from, Str::len(matter)-1);

@ Here we look at a word made up of identifier characters -- such as |int|, |X|,
or |CLike::colour_ident| -- and decide whether to recolour its characters on
the basis of what it means.

=
void CLike::colour_ident(section *S, text_stream *matter, text_stream *colouring, int from, int to) {
	TEMPORARY_TEXT(id);
	Str::substr(id, Str::at(matter, from), Str::at(matter, to+1));

	int override = -1;
	if (Analyser::is_reserved_word(S, id, FUNCTION_COLOUR)) override = FUNCTION_COLOUR;
	if (Analyser::is_reserved_word(S, id, RESERVED_COLOUR)) override = RESERVED_COLOUR;
	if (Analyser::is_reserved_word(S, id, CONSTANT_COLOUR)) override = CONSTANT_COLOUR;
	if (Analyser::is_reserved_word(S, id, ELEMENT_COLOUR)) {
		int at = --from;
		while ((at > 0) && (Characters::is_space_or_tab(Str::get_at(matter, at)))) at--;
		if (((at >= 0) && (Str::get_at(matter, at) == '.')) ||
			((at >= 0) && (Str::get_at(matter, at-1) == '-') && (Str::get_at(matter, at) == '>')))
			override = ELEMENT_COLOUR;
	}

	if (override >= 0)
		for (int i=from; i<=to; i++)
			Str::put_at(colouring, i, override);
	DISCARD_TEXT(id);
}

@h Overriding regular code weaving.
We have the opportunity here to sidestep the regular weaving algorithm, and do
our own thing. We decline.

@h Analysis.
This implements the additional information in the |-structures| and |-functions|
fprms of section catalogue.

=
void CLike::catalogue(programming_language *self, section *S, int functions_too) {
	c_structure *str;
	LOOP_OVER(str, c_structure)
		if (str->typedef_begins->owning_section == S)
			PRINT(" %S ", str->structure_name);
	if (functions_too) {
		function *fn;
		LOOP_OVER(fn, function)
			if (fn->function_header_at->owning_section == S)
				PRINT("\n                     %S", fn->function_name);
	}
}

@ Having found all those functions and structure elements, we make sure they
are all known to Inweb's hash table of interesting identifiers:

=
void CLike::analyse_code(programming_language *self, web *W) {
	function *fn;
	LOOP_OVER(fn, function)
		Analyser::find_hash_entry(fn->function_header_at->owning_section, fn->function_name, TRUE);
	c_structure *str;
	structure_element *elt;
	LOOP_OVER_LINKED_LIST(str, c_structure, W->c_structures)
		LOOP_OVER_LINKED_LIST(elt, structure_element, str->elements)
			if (elt->allow_sharing == FALSE)
				Analyser::find_hash_entry(elt->element_created_at->owning_section,
					elt->element_name, TRUE);
}

@ The following is an opportunity for us to scold the author for any
specifically C-like errors. We're going to look for functions named
|Whatever::name()| whose definitions are not in the |Whatever::| section;
in other words, we police the rule that functions actually are defined in the
namespace which their names imply. This can be turned off with a special
bibliographic variable, but don't do that.

=
void CLike::post_analysis(programming_language *self, web *W) {
	int check_namespaces = FALSE;
	if (Str::eq_wide_string(Bibliographic::get_datum(W->md, I"Namespaces"), L"On")) check_namespaces = TRUE;
	function *fn;
	LOOP_OVER(fn, function) {
		hash_table_entry *hte =
			Analyser::find_hash_entry(fn->function_header_at->owning_section, fn->function_name, FALSE);
		if (hte) {
			hash_table_entry_usage *hteu;
			LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages) {
				if ((hteu->form_of_usage & FCALL_USAGE) || (fn->within_namespace))
					if (hteu->usage_recorded_at->under_section != fn->function_header_at->owning_section)
						fn->called_from_other_sections = TRUE;
			}
		}
		if ((fn->within_namespace != fn->called_from_other_sections)
			&& (check_namespaces)
			&& (fn->call_freely == FALSE)) {
			if (fn->within_namespace)
				Main::error_in_web(
					I"Being internally called, this function mustn't belong to a :: namespace",
					fn->function_header_at);
			else
				Main::error_in_web(
					I"Being externally called, this function must belong to a :: namespace",
					fn->function_header_at);
		}
	}
}
