[CLike::] C-Like Languages.

To provide special features for the whole C family of languages.

@h What makes a language C-like.
This does:

=
void CLike::make_c_like(programming_language *pl) {
	METHOD_ADD(pl, PARSE_TYPES_PAR_MTID, CLike::parse_types);
	METHOD_ADD(pl, PARSE_FUNCTIONS_PAR_MTID, CLike::parse_functions);
	METHOD_ADD(pl, SUBCATEGORISE_LINE_PAR_MTID, CLike::subcategorise_line);

	METHOD_ADD(pl, ADDITIONAL_EARLY_MATTER_TAN_MTID, CLike::additional_early_matter);
	METHOD_ADD(pl, ADDITIONAL_PREDECLARATIONS_TAN_MTID, CLike::additional_predeclarations);
}

@h Parsing.
After a web has been read in and then parsed, code supporting its language
is then called to do any further parsing it might want to. The code below
is run if the language is "C-like": regular C and InC both qualify.

=
void CLike::parse_types(programming_language *self, ls_web *W) {
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

Note that a |fruit| structure contains a |pip| structure (in fact, five of
them), but only contains pointers to |tree_species| structures and itself.
C requires therefore that the structure definition for |pip| must occur
earlier in the code than that for |fruit|. This is a nuisance, so we
takes care of it automatically.

@<Find every typedef struct in the tangle@> =
	language_type *current_str = NULL;
	ls_chapter *C;
	ls_section *S;
	LOOP_WITHIN_CODE(C, S, TangleTargets::primary_target(W)) {
		ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
		text_stream *line = lst->text;
		if (Str::len(L_chunk->extract_to) == 0) {
			match_results mr = Regexp::create_mr();

			if (Regexp::match(&mr, line, U"typedef struct (%i+) %c*{%c*")) {
				current_str = Functions::new_struct(W, mr.exp[0], S, L_par, lst);
				LiterateSource::tag_paragraph(L_par, I"Structures");
			} else if ((Str::get_first_char(line) == '}') && (current_str)) {
				current_str->typedef_ends = lst;
				current_str = NULL;
			} else if ((current_str) && (current_str->typedef_ends == NULL)) {
				@<Work through a line in the structure definition@>;
			} else if ((Regexp::match(&mr, line, U"typedef %c+")) &&
				(Regexp::match(&mr, line, U"%c+##%c+") == FALSE)) {
				if (LiterateSource::par_contains_very_early_code(L_par) == FALSE)
					L->part_of_typedef = TRUE;
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
	Str::copy(p, lst->text);
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
			Functions::new_element(current_str, elname, lst, S);
			DISCARD_TEXT(elname)
			Regexp::dispose_of(&mr);
		}
	}
	DISCARD_TEXT(p)

@ The following reduces |unsigned long long int *val;| to just |int *val;|.

@<Remove C type modifiers from the front of p@> =
	inchar32_t *modifier_patterns[] = {
		U"(struct )(%C%c*)", U"(signed )(%C%c*)", U"(unsigned )(%C%c*)",
		U"(short )(%C%c*)", U"(long )(%C%c*)", U"(static )(%C%c*)", NULL };
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
	if (Regexp::match(&mr, elname, U"(%i+)%c*")) Str::copy(elname, mr.exp[0]);

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
	LOOP_OVER_LINKED_LIST(current_str, language_type, CodeAnalysis::language_types_list(W)) {
		for (ls_line *lst = current_str->structure_header_at;
			((lst) && (lst != current_str->typedef_ends));
			lst = lst->next_line) {
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, lst->text, U" struct (%i+) %i%c*"))
				@<One structure appears to contain a copy of another one@>;
			Regexp::dispose_of(&mr);
		}
	}

@<One structure appears to contain a copy of another one@> =
	text_stream *used_structure = mr.exp[0];
	language_type *str;
	LOOP_OVER_LINKED_LIST(str, language_type, CodeAnalysis::language_types_list(W))
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
ls_line *cc_stack[MAX_CONDITIONAL_COMPILATION_STACK];

void CLike::parse_functions(programming_language *self, ls_web *W) {
	cc_sp = 0;
	ls_chapter *C;
	ls_section *S;
	LOOP_WITHIN_CODE(C, S, TangleTargets::primary_target(W)) {
		text_stream *line = lst->text;
		@<Look for conditional compilation on this line@>;
		@<Look for a function definition on this line@>;
	}
	if (cc_sp > 0)
		WebErrors::issue_at(I"program ended with conditional compilation open", NULL);
}

@<Look for conditional compilation on this line@> =
	match_results mr = Regexp::create_mr();
	if ((Regexp::match(&mr, line, U" *#ifn*def %c+")) ||
		(Regexp::match(&mr, line, U" *#IFN*DEF %c+"))) {
		if (cc_sp >= MAX_CONDITIONAL_COMPILATION_STACK)
			WebErrors::issue_at(I"conditional compilation too deeply nested", lst);
		else
			cc_stack[cc_sp++] = lst;
	}
	if ((Regexp::match(&mr, line, U" *#endif *")) ||
		(Regexp::match(&mr, line, U" *#ENDIF *"))) {
		if (cc_sp <= 0)
			WebErrors::issue_at(I"found #endif without #ifdef or #ifndef", lst);
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
	if (!(Characters::is_space_or_tab(Str::get_first_char(line)))) {
		TEMPORARY_TEXT(qualifiers)
		TEMPORARY_TEXT(modified)
		Str::copy(modified, line);
		@<Parse past any type modifiers@>;
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, modified, U"(%i+) (%**)(%i+)%((%c*)")) {
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
	inchar32_t *modifier_patterns[] = {
		U"(signed )(%C%c*)", U"(unsigned )(%C%c*)",
		U"(short )(%C%c*)", U"(long )(%C%c*)", U"(static )(%C%c*)", NULL };
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
	language_function *fn = Functions::new_function(fname, lst, S);
	fn->function_arguments = Str::duplicate(arguments);
	WRITE_TO(fn->function_type, "%S%S %S", qualifiers, ftype, asts);
	if (Str::eq_wide_string(fn->function_name, U"isdigit")) fn->call_freely = TRUE;
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
	ls_line *A_lst = lst;
	int arg_lc = 1;
	while ((A_lst) && (arg_lc <= MAX_ARG_LINES) && (Regexp::find_open_brace(arguments) == -1)) {
		ls_line_analysis *AL = (ls_line_analysis *) A_lst->analysis_ref;
		if (A_lst->next_line == NULL) {
			TEMPORARY_TEXT(err_mess)
			WRITE_TO(err_mess, "Function '%S' has a malformed declaration", fname);
			WebErrors::issue_at(err_mess, lst);
			DISCARD_TEXT(err_mess)
			break;
		}
		A_lst = A_lst->next_line; AL = (ls_line_analysis *) A_lst->analysis_ref;
		WRITE_TO(arguments, " %S", A_lst->text);
		arg_lc++;
	}
	int n = Regexp::find_open_brace(arguments);
	if (n >= 0) Str::truncate(arguments, n);

@h Subcategorisation.
The following is called after the parser gives every line in the web a
category; we can, if we wish, change that for a more exotic one. We simply
look for a |#include| of one of the ANSI C standard libraries.

=
void CLike::subcategorise_line(programming_language *self, ls_line *lst) {
	ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, lst->text, U"#include <(%C+)>%c*")) {
		text_stream *library_file = mr.exp[0];
		inchar32_t *ansi_libs[] = {
			U"assert.h", U"ctype.h", U"errno.h", U"float.h", U"limits.h",
			U"locale.h", U"math.h", U"setjmp.h", U"signal.h", U"stdarg.h",
			U"stddef.h", U"stdio.h", U"stdlib.h", U"string.h", U"time.h",
			NULL
		};
		for (int j = 0; ansi_libs[j]; j++)
			if (Str::eq_wide_string(library_file, ansi_libs[j])) {
				L->C_inclusion = TRUE;
				lst->suppress_tangling = TRUE;
			}
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
void CLike::additional_early_matter(programming_language *self, text_stream *OUT, ls_web *W, tangle_target *target, tangle_docket *docket) {
	ls_chapter *C;
	ls_section *S;
	LOOP_WITHIN_CODE(C, S, target) {
		ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
		if (L->C_inclusion) {
			IfdefTags::open_ifdefs(OUT, LiterateSource::par_of_line(lst));
			Tangler::tangle_line(OUT, lst, docket);
			WRITE("\n");
			IfdefTags::close_ifdefs(OUT, LiterateSource::par_of_line(lst));
		}
	}
}

@h Tangling predeclarations.
This is where a language gets the chance to tangle predeclarations, early
on in the file. We use it first for the structures, and then the functions --
in that order since the function types likely involve the typedef names for the
structures.

=
void CLike::additional_predeclarations(programming_language *self, text_stream *OUT, ls_web *W) {
	@<Predeclare the structures in a well-founded order@>;
	@<Predeclare simple typedefs@>;
	@<Predeclare the functions@>;
}

@ A "simple typedef" here means one that is aliasing something other than
a structure: for example |typedef unsigned int uint;| would be a simple typedef.

@<Predeclare simple typedefs@> =
	ls_chapter *C;
	ls_section *S;
	LOOP_WITHIN_CODE(C, S, TangleTargets::primary_target(W)) {
		ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
		text_stream *line = lst->text;
		if (L->part_of_typedef) {
			IfdefTags::open_ifdefs(OUT, LiterateSource::par_of_line(lst));
			LanguageMethods::tangle_line(OUT, W->web_language, line);
			WRITE("\n");
			IfdefTags::close_ifdefs(OUT, LiterateSource::par_of_line(lst));
		}
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
	LOOP_OVER_LINKED_LIST(str, language_type, CodeAnalysis::language_types_list(W))
		str->tangled = FALSE;
	LOOP_OVER_LINKED_LIST(str, language_type, CodeAnalysis::language_types_list(W))
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
	IfdefTags::open_ifdefs(OUT, LiterateSource::par_of_line(str->structure_header_at));
	LanguageMethods::insert_line_marker(OUT, self, str->structure_header_at);
	for (ls_line *lst = str->structure_header_at; lst; lst = lst->next_line) {
		WRITE("%S\n", lst->text);
		lst->suppress_tangling = TRUE;
		if (lst == str->typedef_ends) break;
	}
	IfdefTags::close_ifdefs(OUT, LiterateSource::par_of_line(str->structure_header_at));
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
	ls_chapter *C;
	ls_section *S;
	LOOP_WITHIN_CODE(C, S, TangleTargets::primary_target(W)) {
		ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
		if (L->function_defined) {
			if (LiterateSource::par_of_line(lst) == NULL) {
				TEMPORARY_TEXT(err_mess)
				WRITE_TO(err_mess, "Function '%S' seems outside of any paragraph",
					L->function_defined->function_name);
				WebErrors::issue_at(err_mess, lst);
				DISCARD_TEXT(err_mess)
				continue;
			}
			if (LiterateSource::par_contains_very_early_code(L_par) == FALSE) {
				language_function *fn = L->function_defined;
				int to_close = 0;
				for (int i=0; i<fn->no_conditionals; i++) {
					match_results mr = Regexp::create_mr();
					if (!(Regexp::match(&mr, fn->within_conditionals[i]->text,
						U"%c*inweb: always predeclare%c*"))) {
						WRITE("%S\n", fn->within_conditionals[i]->text);
						to_close++;
					}
				}
				IfdefTags::open_ifdefs(OUT, LiterateSource::par_of_line(lst));
				LanguageMethods::insert_line_marker(OUT, W->web_language, lst);
				WRITE("%S ", fn->function_type);
				LanguageMethods::tangle_line(OUT, W->web_language, fn->function_name);
				WRITE("(%S;\n", fn->function_arguments);
				IfdefTags::close_ifdefs(OUT, LiterateSource::par_of_line(lst));
				for (int i=0; i<to_close; i++) {
					WRITE("#endif\n");
				}
			}
		}
	}

@h Overriding regular code weaving.
We have the opportunity here to sidestep the regular weaving algorithm, and do
our own thing. We decline.
