[CLike::] C-Like Languages.

To provide special features for the whole C family of languages.

@h What makes a language C-like?
This does:

=
void CLike::make_c_like(programming_language *pl) {
	METHOD_ADD(pl, PARSE_TYPES_PAR_MTID, CLike::parse_types);
	METHOD_ADD(pl, PARSE_FUNCTIONS_PAR_MTID, CLike::parse_functions);
	METHOD_ADD(pl, SUBCATEGORISE_LINE_PAR_MTID, CLike::subcategorise_code);

	METHOD_ADD(pl, ADDITIONAL_EARLY_MATTER_TAN_MTID, CLike::additional_early_matter);
	METHOD_ADD(pl, ADDITIONAL_PREDECLARATIONS_TAN_MTID, CLike::additional_predeclarations);
}

@h Parsing.
After a web has been read in and then parsed, code supporting its language
is then called to do any further parsing it might want to. The code below
is run if the language is "C-like": regular C and InC both qualify.

=
void CLike::parse_types(programming_language *self, web *W) {
	@<Find every typedef struct in the tangle@>;
	@<Work out which structs contain which others@>;
}

@ We're going to assume that the C source code uses structures looking
something like this:
= (text as C)
	typedef struct fruit {
	    struct pip the_pips[5];
	    struct fruit *often_confused_with;
	    struct tree_species *grows_on;
	    int typical_weight;
	} fruit;
=
which adopts the traditional layout conventions of Kernighan and Ritchie.
The structure definitions in this Inweb web all take the required form,
of course, and provide many more examples.

Note that a |fruit| structure contains a |pip| structure (in fact, five of
them), but only contains pointers to |tree_species| structures and itself.
C requires therefore that the structure definition for |pip| must occur
earlier in the code than that for |fruit|. This is a nuisance, so Inweb
takes care of it automatically.

@<Find every typedef struct in the tangle@> =
	language_type *current_str = NULL;
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W)) {
		if (Str::len(L->extract_to) == 0) {
			match_results mr = Regexp::create_mr();

			if (Regexp::match(&mr, L->text, L"typedef struct (%i+) %c*{%c*")) {
				current_str = Functions::new_struct(W, mr.exp[0], L);
				Tags::add_by_name(L->owning_paragraph, I"Structures");
			} else if ((Str::get_first_char(L->text) == '}') && (current_str)) {
				current_str->typedef_ends = L;
				current_str = NULL;
			} else if ((current_str) && (current_str->typedef_ends == NULL)) {
				@<Work through a line in the structure definition@>;
			} else if ((Regexp::match(&mr, L->text, L"typedef %c+")) &&
				(Regexp::match(&mr, L->text, L"%c+##%c+") == FALSE)) {
				if (L->owning_paragraph->placed_very_early == FALSE)
					L->category = TYPEDEF_LCAT;
			}
			Regexp::dispose_of(&mr);
		}
	}

@ At this point we're reading a line within the structure's definition; for
the sake of an illustrative example, let's suppose that line is:
= (text)
	unsigned long long int *val;
=
We need to extract the element name, |val|, and make a note of it.

@<Work through a line in the structure definition@> =
	TEMPORARY_TEXT(p)
	Str::copy(p, L->text);
	Str::trim_white_space(p);
	@<Remove C type modifiers from the front of p@>;
	string_position pos = Str::start(p);
	if (Str::get(pos) != '/') { /* a slash must introduce a comment here */
		@<Move pos past the type name@>;
		@<Move pos past any typographical type modifiers@>;
		if (Str::in_range(pos)) {
			match_results mr = Regexp::create_mr();
			TEMPORARY_TEXT(elname)
			@<Copy the element name into elname@>;
			Functions::new_element(current_str, elname, L);
			DISCARD_TEXT(elname)
			Regexp::dispose_of(&mr);
		}
	}
	DISCARD_TEXT(p)

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

@h Structure dependency.
We say that S depends on T if |struct S| has an element whose type is
|struct T|. That matters because if so then |struct T| has to be defined
before |struct S| in the tangled output.

It's important to note that |struct S| merely having a member of type
|struct *T| does not create a dependency. In the code below, because |%i|
matches only identifier characters and |*| is not one of those, a line like
= (text)
    struct fruit *often_confused_with;
=
will not trip the switch here.

@<Work out which structs contain which others@> =
	language_type *current_str;
	LOOP_OVER(current_str, language_type) {
		for (source_line *L = current_str->structure_header_at;
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
	language_type *str;
	LOOP_OVER_LINKED_LIST(str, language_type, W->language_types)
		if ((str != current_str) &&
			(Str::eq(used_structure, str->structure_name)))
			ADD_TO_LINKED_LIST(str, language_type, current_str->incorporates);

@h Functions.
This time, we will need to keep track of |#ifdef| and |#endif| pairs
in the source. This matters because we will want to predeclare functions;
but if functions are declared in conditional compilation, then their
predeclarations have to be made under the same conditions.

The following stack holds the current set of conditional compilations which the
source line being scanned lies within.

@d MAX_CONDITIONAL_COMPILATION_STACK 8

=
int cc_sp = 0;
source_line *cc_stack[MAX_CONDITIONAL_COMPILATION_STACK];

void CLike::parse_functions(programming_language *self, web *W) {
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

@ So, then, we recognise a C function as being a line which takes the form
= (text)
	type identifier(args...
=
where we parse |type| only minimally. In InC (only), the identifier can
contain namespace dividers written |::|. Function declarations, we will assume,
always begin on column 1 of their source files, and we expect them to take
modern ANSI C style, not the long-deprecated late 1970s C style.

@<Look for a function definition on this line@> =
	if (!(Characters::is_space_or_tab(Str::get_first_char(L->text)))) {
		TEMPORARY_TEXT(qualifiers)
		TEMPORARY_TEXT(modified)
		Str::copy(modified, L->text);
		@<Parse past any type modifiers@>;
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, modified, L"(%i+) (%**)(%i+)%((%c*)")) {
			TEMPORARY_TEXT(ftype) Str::copy(ftype, mr.exp[0]);
			TEMPORARY_TEXT(asts) Str::copy(asts, mr.exp[1]);
			TEMPORARY_TEXT(fname) Str::copy(fname, mr.exp[2]);
			TEMPORARY_TEXT(arguments) Str::copy(arguments, mr.exp[3]);
			@<A function definition was found@>;
			DISCARD_TEXT(ftype)
			DISCARD_TEXT(asts)
			DISCARD_TEXT(fname)
			DISCARD_TEXT(arguments)
		}
		DISCARD_TEXT(qualifiers)
		DISCARD_TEXT(modified)
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
	language_function *fn = Functions::new_function(fname, L);
	fn->function_arguments = Str::duplicate(arguments);
	WRITE_TO(fn->function_type, "%S%S %S", qualifiers, ftype, asts);
	if (Str::eq_wide_string(fn->function_name, L"isdigit")) fn->call_freely = TRUE;
	fn->no_conditionals = cc_sp;
	for (int i=0; i<cc_sp; i++) fn->within_conditionals[i] = cc_stack[i];

@ In some cases the function's declaration runs over several lines:
= (text as code)
	void World::Subjects::make_adj_const_domain(inference_subject *infs,|
		instance *nc, property *prn) {|
=		
Having read the first line, |arguments| would contain |inference_subject *infs,|
and would thus be incomplete. We continue across subsequent lines until we
reach an open brace |{|.

@d MAX_ARG_LINES 32 /* maximum number of lines over which a function's header can extend */

@<Soak up further arguments from continuation lines after the declaration@> =
	source_line *AL = L;
	int arg_lc = 1;
	while ((AL) && (arg_lc <= MAX_ARG_LINES) && (Regexp::find_open_brace(arguments) == -1)) {
		if (AL->next_line == NULL) {
			TEMPORARY_TEXT(err_mess)
			WRITE_TO(err_mess, "Function '%S' has a malformed declaration", fname);
			Main::error_in_web(err_mess, L);
			DISCARD_TEXT(err_mess)
			break;
		}
		AL = AL->next_line;
		WRITE_TO(arguments, " %S", AL->text);
		arg_lc++;
	}
	int n = Regexp::find_open_brace(arguments);
	if (n >= 0) Str::truncate(arguments, n);

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
"Additional early matter" is used for the inclusions of the ANSI library
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
			Tangler::tangle_line(OUT, L->text, S, L);
			WRITE("\n");
			Tags::close_ifdefs(OUT, L->owning_paragraph);
		}
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
			LanguageMethods::tangle_line(OUT, W->main_language, L->text);
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
	language_type *str;
	LOOP_OVER_LINKED_LIST(str, language_type, W->language_types)
		str->tangled = FALSE;
	LOOP_OVER_LINKED_LIST(str, language_type, W->language_types)
		CLike::tangle_structure(OUT, self, str);

@ Using the following recursion, which is therefore terminating:

=
void CLike::tangle_structure(OUTPUT_STREAM, programming_language *self, language_type *str) {
	if (str->tangled != FALSE) return;
	str->tangled = NOT_APPLICABLE;
	language_type *embodied = NULL;
	LOOP_OVER_LINKED_LIST(embodied, language_type, str->incorporates)
		CLike::tangle_structure(OUT, self, embodied);
	str->tangled = TRUE;
	Tags::open_ifdefs(OUT, str->structure_header_at->owning_paragraph);
	LanguageMethods::insert_line_marker(OUT, self, str->structure_header_at);
	for (source_line *L = str->structure_header_at; L; L = L->next_line) {
		WRITE("%S\n", L->text);
		L->suppress_tangling = TRUE;
		if (L == str->typedef_ends) break;
	}
	Tags::close_ifdefs(OUT, str->structure_header_at->owning_paragraph);
}

@ Functions are rather easier to deal with. In general, if a function was
defined within some number of nested |#ifdef| or |#ifndef| directives, then
we reproduce those around the predeclaration: except, as a special trick,
if the line contains a particular comment. For example:
= (text)
	#ifdef SOLARIS /* inweb: always predeclare */
=
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
		if (L->function_defined) {
			if (L->owning_paragraph == NULL) {
				TEMPORARY_TEXT(err_mess)
				WRITE_TO(err_mess, "Function '%S' seems outside of any paragraph",
					L->function_defined->function_name);
				Main::error_in_web(err_mess, L);
				DISCARD_TEXT(err_mess)
				continue;
			}
			if (L->owning_paragraph->placed_very_early == FALSE) {
				language_function *fn = L->function_defined;
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
				LanguageMethods::insert_line_marker(OUT, W->main_language, L);
				WRITE("%S ", fn->function_type);
				LanguageMethods::tangle_line(OUT, W->main_language, fn->function_name);
				WRITE("(%S;\n", fn->function_arguments);
				Tags::close_ifdefs(OUT, L->owning_paragraph);
				for (int i=0; i<to_close; i++) {
					WRITE("#endif\n");
				}
			}
		}

@h Overriding regular code weaving.
We have the opportunity here to sidestep the regular weaving algorithm, and do
our own thing. We decline.
