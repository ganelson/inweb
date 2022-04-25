[Preprocessor::] Preprocessor.

A simple, general-purpose preprocessor for text files, expanding macros and
performing repetitions.

@h Scanner.
Writing a general-purpose preprocessor really is coding like it's 1974, but
it turns out to be useful for multiple applications in the Inform project, and
saves us having to have dependencies on behemoths like the mighty |m4|.

For documentation on the markup notation, see //inweb: Webs, Tangling and Weaving//.

To use the preprocessor, call:
= (text as InC)
Preprocessor::preprocess(from, to, header, special_macros, specifics)
=
where |from| and |to| are filenames, |header| is text to place at the top of
the file (if any), |special_macros| is a |linked_list| of |preprocessor_macro|s
set up with special meanings to the situation, and |specifics| is a general
pointer to any data those special meanings need to use.

=
void Preprocessor::preprocess(filename *prototype, filename *F, text_stream *header,
	linked_list *special_macros, general_pointer specifics, wchar_t comment_char) {
	struct text_stream processed_file;
	if (STREAM_OPEN_TO_FILE(&processed_file, F, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", F);
	text_stream *OUT = &processed_file;
	WRITE("%S", header);

	preprocessor_state PPS;
	@<Initialise the preprocessor state@>;
	TextFiles::read(prototype, FALSE, "can't open prototype file",
		TRUE, Preprocessor::scan_line, NULL, &PPS);
	STREAM_CLOSE(OUT);
}

@ The following imposing-looking set of state data is used as we work through
the prototype file line-by-line:

@d MAX_PREPROCESSOR_LOOP_DEPTH 8

=
typedef struct preprocessor_state {
	struct text_stream *dest;
	struct preprocessor_macro *defining; /* a "define" body being scanned */
	int repeat_sp;
	int shadow_sp;
	struct preprocessor_loop repeat_data[MAX_PREPROCESSOR_LOOP_DEPTH];
	int suppress_newline; /* at the end of this line */
	int last_line_was_blank; /* used to suppress runs of multiple blank lines */
	struct preprocessor_variable_set *global_variables;
	struct preprocessor_variable_set *stack_frame;
	struct linked_list *known_macros; /* of |preprocessor_macro| */
	struct general_pointer specifics;
	wchar_t comment_character;
} preprocessor_state;

typedef struct preprocessor_loop {
	struct text_stream *loop_var_name;
	struct linked_list *iterations; /* of |text_stream| */
	int repeat_is_block;
	struct text_stream *repeat_saved_dest;
} preprocessor_loop;

@<Initialise the preprocessor state@> =
	PPS.dest = OUT;
	PPS.suppress_newline = FALSE;
	PPS.last_line_was_blank = TRUE;
	PPS.defining = NULL;
	PPS.repeat_sp = 0;
	PPS.shadow_sp = 0;
	PPS.global_variables = Preprocessor::new_variable_set(NULL);
	PPS.stack_frame = PPS.global_variables;
	PPS.known_macros = Preprocessor::list_of_reserved_macros(special_macros);
	PPS.specifics = specifics;
	PPS.comment_character = comment_char;

@ Conceptually, each loop runs a variable with a given name through a series
of textual values in sequence, and we store that data here:

=
void Preprocessor::set_loop_var_name(preprocessor_loop *loop, text_stream *name) {
	loop->loop_var_name = Str::duplicate(name);
}
void Preprocessor::add_loop_iteration(preprocessor_loop *loop, text_stream *value) {
	ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, loop->iterations);
}

@ Lines from the prototype (or sometimes from files spliced in) are read, one
at a time, by the following.

Note that |define| and |end-define| are not themselves macros, and are handled
directly here. So you cannot use repeat loops to define multiple macros with
parametrised names: but then, nor should you.

=
void Preprocessor::scan_line(text_stream *line, text_file_position *tfp, void *X) {
	preprocessor_state *PPS = (preprocessor_state *) X;
	@<Skip comments@>;
	@<Deal with textual definitions of new macros@>;
	Preprocessor::expand(line, tfp, PPS);
	@<Sometimes, but only sometimes, output a newline@>;
}

@ A line is a comment to the preprocessor if its first non-whitespace character
is the special comment character: often |#|, but not necessarily.

@<Skip comments@> =
	LOOP_THROUGH_TEXT(pos, line) {
		wchar_t c = Str::get(pos);
		if (c == PPS->comment_character) return;
		if (Characters::is_whitespace(c) == FALSE) break;
	}
	
@<Deal with textual definitions of new macros@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *{define: *(%C+) *} *")) @<Begin a bare definition@>;
	if (Regexp::match(&mr, line, L" *{define: *(%C+) (%c*)} *")) @<Begin a definition@>;
	if (Regexp::match(&mr, line, L" *{end-define} *")) @<End a definition@>;
	if (PPS->defining) @<Continue a definition@>;
	Regexp::dispose_of(&mr);

@<Begin a bare definition@> =
	if (PPS->defining)
		Errors::in_text_file("nested definitions are not allowed", tfp);
	text_stream *name = mr.exp[0];
	text_stream *parameter_specification = Str::new();
	PPS->defining = Preprocessor::new_macro(PPS->known_macros, name,
		parameter_specification, Preprocessor::default_expander, tfp);
	Regexp::dispose_of(&mr);
	return;

@<Begin a definition@> =
	if (PPS->defining)
		Errors::in_text_file("nested definitions are not allowed", tfp);
	text_stream *name = mr.exp[0];
	text_stream *parameter_specification = mr.exp[1];
	PPS->defining = Preprocessor::new_macro(PPS->known_macros, name,
		parameter_specification, Preprocessor::default_expander, tfp);
	Regexp::dispose_of(&mr);
	return;

@<Continue a definition@> =
	Preprocessor::add_line_to_macro(PPS->defining, line, tfp);
	Regexp::dispose_of(&mr);
	return;

@<End a definition@> =
	if (PPS->defining == NULL)
		Errors::in_text_file("{end-define} without {define: ...}", tfp);
	PPS->defining = NULL;
	Regexp::dispose_of(&mr);
	return;

@<Sometimes, but only sometimes, output a newline@> =
	if (PPS->suppress_newline == FALSE) {
		text_stream *OUT = PPS->dest;
		if (Str::len(line) == 0) {
			if (PPS->last_line_was_blank == FALSE) WRITE("\n");
			PPS->last_line_was_blank = TRUE;
		} else {
			PPS->last_line_was_blank = FALSE;
			WRITE("\n");
		}
	}
	PPS->suppress_newline = FALSE;

@ The expander works on material fed to it which:

(i) Does not contain any newlines;

(ii) Contains braces |{ ... }| used in nested pairs (unless there is a syntax
error in the prototype, in which case we must complain).

The idea is the pass everything straight through except any braced matter,
which needs special attention.

=
void Preprocessor::expand(text_stream *text, text_file_position *tfp, preprocessor_state *PPS) {
	TEMPORARY_TEXT(before_matter)
	TEMPORARY_TEXT(braced_matter)
	TEMPORARY_TEXT(after_matter)
	int bl = 0, after_times = FALSE;
	for (int i = 0; i < Str::len(text); i++) {
		wchar_t c = Str::get_at(text, i);
		if (after_times) PUT_TO(after_matter, c);
		else if (c == '{') {
			bl++;
			if (bl > 1) PUT_TO(braced_matter, c);
		} else if (c == '}') {
			bl--;
			if (bl == 0) after_times = TRUE;
			else PUT_TO(braced_matter, c);
		} else {
			if (bl < 0) Errors::in_text_file("too many '}'s", tfp);
			if (bl == 0) PUT_TO(before_matter, c);
			else PUT_TO(braced_matter, c);
		}
	}
	if (bl > 0) Errors::in_text_file("too many '{'s", tfp);
	if (after_times) {
		@<Expand braced matter@>;
	} else {
		WRITE_TO(PPS->dest, "%S", text);
	}
	DISCARD_TEXT(before_matter)
	DISCARD_TEXT(braced_matter)
	DISCARD_TEXT(after_matter)
}

@ Suppose we are expanding the text |this {ADJECTIVE} ocean {BEHAVIOUR}|: then
the |before_matter| will be |this |, the |braced_matter| will be |ADJECTIVE|,
and the |after_matter| will be | ocean {BEHAVIOUR}|.

@<Expand braced matter@> =
	if (Preprocessor::acceptable_variable_name(braced_matter)) {
		@<Expand a variable name@>;
	} else {
		text_stream *identifier = braced_matter;
		text_stream *parameter_settings = NULL;
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, identifier, L"(%C+) (%c*)")) {
			identifier = mr.exp[0];
			parameter_settings = mr.exp[1];
		}
		@<Work out which macro identifier is meant by a loop name@>;

		preprocessor_macro *mm = Preprocessor::find_macro(PPS->known_macros, identifier);
		if (mm == NULL) {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown macro '%S'", identifier);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		} else {
			@<Expand a macro@>;
		}
		Regexp::dispose_of(&mr);
	}

@ So, for example, the identifier |repeat| would be changed here either to
|repeat-block| or |repeat-span|: see above for an explanation.

@<Work out which macro identifier is meant by a loop name@> =
	preprocessor_macro *loop_mm;
	LOOP_OVER_LINKED_LIST(loop_mm, preprocessor_macro, PPS->known_macros)
		if (Str::len(loop_mm->loop_name) > 0) {
			if (Str::eq(identifier, loop_mm->loop_name)) {
				if (Str::is_whitespace(after_matter)) {
					if ((loop_mm->span == FALSE) && (loop_mm->begins_loop))
						identifier = loop_mm->identifier;
				} else {
					if ((loop_mm->span) && (loop_mm->begins_loop))
						identifier = loop_mm->identifier;
				}
			}
			TEMPORARY_TEXT(end_name)
			WRITE_TO(end_name, "end-%S", loop_mm->loop_name);
			if (Str::eq(identifier, end_name)) {
				if ((PPS->repeat_sp > 0) &&
					(PPS->repeat_data[PPS->repeat_sp-1].repeat_is_block)) {
					if ((loop_mm->span == FALSE) && (loop_mm->ends_loop))
						identifier = loop_mm->identifier;
				} else {
					if ((loop_mm->span) && (loop_mm->ends_loop))
						identifier = loop_mm->identifier;
				}
			}
			DISCARD_TEXT(end_name)
		}

@ Note that if we are inside a loop, we do not perform expansion on the variable
name, and instead pass it through unchanged -- still as, say, |{NAME}|. This
is because it won't be expanded until later, when the expander reaches the
end of the loop body.

@<Expand a variable name@> =
	Preprocessor::expand(before_matter, tfp, PPS);
	if (PPS->repeat_sp > 0) {
		WRITE_TO(PPS->dest, "{%S}", braced_matter);
	} else {
		@<Definitely expand a variable name@>;
	}
	Preprocessor::expand(after_matter, tfp, PPS);

@ Similarly, we don't expand macros inside the body of a loop, except that we
need to expand the |{end-repeat-block}| (or similar) which closes that loop
body, so that we can escape back into normal mode. Because loop constructs
may be nested, we need to react to (but not expand) loop openings, too.
The "shadow stack pointer" shows how deep we are inside these shadowy,
not-yet-acted-on, loops.

@<Expand a macro@> =
	if (mm->suppress_whitespace_when_expanding) {
		while (Characters::is_whitespace(Str::get_last_char(before_matter)))
			Str::delete_last_character(before_matter);
		while (Characters::is_whitespace(Str::get_first_char(after_matter)))
			Str::delete_first_character(after_matter);
	}
	Preprocessor::expand(before_matter, tfp, PPS);
	int divert_if_repeating = TRUE;
	if ((mm) && (mm->begins_loop)) {
		PPS->shadow_sp++;
	}
	if ((mm) && (mm->ends_loop)) {
		PPS->shadow_sp--;
		if (PPS->shadow_sp == 0) divert_if_repeating = FALSE;
	}
	
	if ((divert_if_repeating) && (PPS->repeat_sp > 0)) {
		WRITE_TO(PPS->dest, "{%S}", braced_matter);
	} else {
		@<Definitely expand a macro@>;
		if (mm->suppress_newline_after_expanding) PPS->suppress_newline = TRUE;
	}
	Preprocessor::expand(after_matter, tfp, PPS);

@ We can now forget about the |before_matter|, the |after_matter|, or whether
we ought not to expand after all: that's all taken care of. A variable expands
to its value:

@<Definitely expand a variable name@> =
	preprocessor_variable *var =
		Preprocessor::find_variable(braced_matter, PPS->stack_frame);
	if (var) {
		WRITE_TO(PPS->dest, "%S", Preprocessor::read_variable(var));
	} else {
		TEMPORARY_TEXT(erm)
		WRITE_TO(erm, "unknown variable '%S'", braced_matter);
		Errors::in_text_file_S(erm, tfp);
		DISCARD_TEXT(erm)
	}

@ This looks fussy, but really it delegates the work by calling a function
attached to the macro, the |expander|.

@<Definitely expand a macro@> =
	text_stream *parameter_values[MAX_PP_MACRO_PARAMETERS];
	for (int i=0; i<MAX_PP_MACRO_PARAMETERS; i++) parameter_values[i] = NULL;
	@<Parse the parameters supplied@>;
	@<Check that all compulsory parameters have been supplied@>;

	preprocessor_loop *loop = NULL;
	if (mm->begins_loop) @<Initialise repetition data for the loop@>;

	(*(mm->expander))(mm, PPS, parameter_values, loop, tfp);

@ Note that textual values of the parameters are themselves expanded before
use: they might contain variables, or even macros. Parameter names are not.
So you can have |in: {WHATEVER}| but not |{WHATEVER}: this|.

@<Parse the parameters supplied@> =
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, parameter_settings, L" *(%C+): *(%c*)")) {
		text_stream *setting = mr.exp[0];
		text_stream *value = mr.exp[1];
		text_stream *remainder = NULL;
		match_results mr3 = Regexp::create_mr();
		if (Regexp::match(&mr3, value, L"(%c+?) *(%C+: *%c*)")) {
			value = mr3.exp[0];
			remainder = mr3.exp[1];
		}
		int found = FALSE;
		for (int i=0; i<mm->no_parameters; i++)
			if (Str::eq(setting, mm->parameters[i]->name)) {
				found = TRUE;
				parameter_values[i] = Str::new();
				text_stream *saved = PPS->dest;
				PPS->dest = parameter_values[i];
				Preprocessor::expand(value, tfp, PPS);
				PPS->dest = saved;
			}
		if (found == FALSE) {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown parameter '%S:'", setting);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
		Str::clear(parameter_settings);
		Str::copy(parameter_settings, remainder);
		Regexp::dispose_of(&mr3);
	}
	Regexp::dispose_of(&mr);
	if (Str::is_whitespace(parameter_settings) == FALSE)
		Errors::in_text_file("parameter list is malformed", tfp);

@<Check that all compulsory parameters have been supplied@> =
	for (int i=0; i<mm->no_parameters; i++)
		if (parameter_values[i] == NULL)
			if (mm->parameters[i]->optional == FALSE) {
				TEMPORARY_TEXT(erm)
				WRITE_TO(erm, "compulsory parameter '%S:' not given", mm->parameters[i]->name);
				Errors::in_text_file_S(erm, tfp);
				DISCARD_TEXT(erm)
			}

@ The following code is a little misleading. At present, |PPS->repeat_sp| is
always either 0 or 1, no matter how deep loop nesting is: but that's just an
artefact of the current scanning algorithm, which might some day change.

@<Initialise repetition data for the loop@> =
	if (PPS->repeat_sp >= MAX_PREPROCESSOR_LOOP_DEPTH) {
		Errors::in_text_file("repetition too deep", tfp);
	} else {
		loop = &(PPS->repeat_data[PPS->repeat_sp++]);
		PPS->shadow_sp = 1;
		Preprocessor::set_loop_var_name(loop, I"NAME");
		loop->iterations = NEW_LINKED_LIST(text_stream);	
		loop->repeat_is_block = TRUE;
		if (mm->span) loop->repeat_is_block = FALSE;
		loop->repeat_saved_dest = PPS->dest;
		PPS->dest = Str::new();
	}

@h Variables.
Names of variables should conform to:

=
int Preprocessor::acceptable_variable_name(text_stream *name) {
	LOOP_THROUGH_TEXT(pos, name) {
		wchar_t c = Str::get(pos);
		if ((c >= '0') && (c <= '9')) continue;
		if ((c >= 'A') && (c <= 'Z')) continue;
		if (c == '_') continue;
		return FALSE;
	}
	return TRUE;
}

@ Variables are all textual:

=
typedef struct preprocessor_variable {
	struct text_stream *name;
	struct text_stream *value;
	CLASS_DEFINITION
} preprocessor_variable;

text_stream *Preprocessor::read_variable(preprocessor_variable *var) {
	if (var == NULL) internal_error("no such pp variable");
	return var->value;
}
void Preprocessor::write_variable(preprocessor_variable *var, text_stream *val) {
	if (var == NULL) internal_error("no such pp variable");
	var->value = Str::duplicate(val);
}

@ Each variable belongs to a single "set". If |EXAMPLE| has one meaning outside a
definition and another insider, that's two variables with a common name, not
one variable belonging to two sets at once.

=
typedef struct preprocessor_variable_set {
	struct linked_list *variables; /* of |preprocessor_variable| */
	struct preprocessor_variable_set *outer;
	CLASS_DEFINITION
} preprocessor_variable_set;

preprocessor_variable_set *Preprocessor::new_variable_set(preprocessor_variable_set *outer) {
	preprocessor_variable_set *set = CREATE(preprocessor_variable_set);
	set->variables = NEW_LINKED_LIST(preprocessor_variable);
	set->outer = outer;
	return set;
}

preprocessor_variable *Preprocessor::find_variable_in_one(text_stream *name,
	preprocessor_variable_set *set) {
	if (set == NULL) return NULL;
	preprocessor_variable *var;
	LOOP_OVER_LINKED_LIST(var, preprocessor_variable, set->variables)
		if (Str::eq(name, var->name))
			return var;
	return NULL;
}

preprocessor_variable *Preprocessor::find_variable(text_stream *name,
	preprocessor_variable_set *set) {
	while (set) {
		preprocessor_variable *var = Preprocessor::find_variable_in_one(name, set);
		if (var) return var;
		set = set->outer;
	}
	return NULL;
}

@ This creates a variable if it doesn't already exist in the given set. (If
it exists in some outer set, that doesn't count.)

=
preprocessor_variable *Preprocessor::ensure_variable(text_stream *name,
	preprocessor_variable_set *in_set) {
	if (in_set == NULL) internal_error("variable without set");
	preprocessor_variable *var = Preprocessor::find_variable_in_one(name, in_set);
	if (var == NULL) {
		var = CREATE(preprocessor_variable);
		var->name = Str::duplicate(name);
		Preprocessor::write_variable(var, I"");
		ADD_TO_LINKED_LIST(var, preprocessor_variable, in_set->variables);
	}
	return var;
}

@h Macros.
For the most part, each macro seen by users corresponds to a single
//preprocessor_macro//, but loop constructs are an exception. When the user
types |{repeat ...}|, this is a reference to |repeat-block| if the body of
what to repeat occupies multiple lines, but to |repeat-span| if only one.

For example, the first |repeat| loop here uses the macros |repeat-block| and
|end-repeat-block|, and the second uses |repeat-span| and |end-repeat-span|.
= (text)
	{repeat with SEA in Black, Caspian}
	Welcome to the SEA Sea.
	{end-repeat}
	...
	Seas available:{repeat with SEA in Sargasso, Libyan} {SEA} Sea;{end-repeat}
=

@ There are (for now, anyway) hard but harmlessly large limits on the number of
parameters and the length of a macro:

@d MAX_PP_MACRO_PARAMETERS 8
@d MAX_PP_MACRO_LINES 128

=
typedef struct preprocessor_macro {
	/* syntax */
	struct text_stream *identifier;
	struct preprocessor_macro_parameter *parameters[MAX_PP_MACRO_PARAMETERS];
	int no_parameters;

	/* meaning */
	struct text_stream *lines[MAX_PP_MACRO_LINES];
	int no_lines;
	void (*expander)(struct preprocessor_macro *, struct preprocessor_state *, struct text_stream **, struct preprocessor_loop *, struct text_file_position *);

	/* loop construct if any */
	int begins_loop;               /* |TRUE| for e.g. |repeat-block| or |repeat-span| */
	int ends_loop;                 /* |TRUE| for e.g. |end-repeat-block| */
	struct text_stream *loop_name; /* e.g. |repeat| */
	int span;                      /* |TRUE| for e.g. |end-repeat-span| or |repeat-span| */

	/* textual behaviour */
	int suppress_newline_after_expanding;
	int suppress_whitespace_when_expanding;

	CLASS_DEFINITION
} preprocessor_macro;

typedef struct preprocessor_macro_parameter {
	struct text_stream *name;
	struct text_stream *definition_token;
	int optional;
	CLASS_DEFINITION
} preprocessor_macro_parameter;

@ The following creates a new macro and adds it to the list |L|. By default, it
has an empty definition (i.e., no lines), but may have a meaning provided by its
|expander| function regardless. The |parameter_specification| is as in the
textual declaration: for example, |in: IN ?towards: WAY| would be valid, with
|in| being compulsory and |towards| optional when the macro is used.

If we expected 10000 macros, a dictionary would be better than a list. But in
fact we expect more like 10.

=
preprocessor_macro *Preprocessor::new_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification,
	void (*expander)(preprocessor_macro *, preprocessor_state *, text_stream **, preprocessor_loop *, text_file_position *),
	text_file_position *tfp) {	
	if (Preprocessor::find_macro(L, name))
		Errors::in_text_file("a macro with this name already exists", tfp);
	preprocessor_macro *new_macro = CREATE(preprocessor_macro);
	@<Initialise the macro@>;
	@<Parse the parameter list@>;
	ADD_TO_LINKED_LIST(new_macro, preprocessor_macro, L);
	return new_macro;
}

@<Initialise the macro@> =
	new_macro->identifier = Str::duplicate(name);
	new_macro->no_parameters = 0;

	new_macro->no_lines = 0;
	new_macro->expander = expander;
	new_macro->begins_loop = FALSE;
	new_macro->ends_loop = FALSE;
	new_macro->loop_name = NULL;
	new_macro->span = FALSE;

	new_macro->suppress_newline_after_expanding = TRUE;
	new_macro->suppress_whitespace_when_expanding = TRUE;

@<Parse the parameter list@> =
	text_stream *spec = Str::duplicate(parameter_specification);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, spec, L" *(%C+): *(%C+) *(%c*)")) {
		text_stream *par_name = mr.exp[0];
		text_stream *token_name = mr.exp[1];
		Str::clear(spec);
		Str::copy(spec, mr.exp[2]);
		if (new_macro->no_parameters >= MAX_PP_MACRO_PARAMETERS) {
			Errors::in_text_file("too many parameters in this definition", tfp);
		} else {
			@<Add parameter to macro@>;
		}
	}
	Regexp::dispose_of(&mr);
	if (Str::is_whitespace(spec) == FALSE)
		Errors::in_text_file("parameter list for this definition is malformed", tfp);

@<Add parameter to macro@> =
	preprocessor_macro_parameter *new_parameter = CREATE(preprocessor_macro_parameter);
	new_parameter->name = Str::duplicate(par_name);
	new_parameter->definition_token = Str::duplicate(token_name);
	new_parameter->optional = FALSE;
	if (Str::get_first_char(new_parameter->name) == '?') {
		new_parameter->optional = TRUE;
		Str::delete_first_character(new_parameter->name);
	}
	new_macro->parameters[new_macro->no_parameters++] = new_parameter;

@ We can then add lines to a macro (though this will only have an effect if its
expander function is //Preprocessor::default_expander//).

=
void Preprocessor::add_line_to_macro(preprocessor_macro *mm, text_stream *line,
	text_file_position *tfp) {
	if (mm->no_lines >= MAX_PP_MACRO_LINES) {
		Errors::in_text_file("too many lines in this definition", tfp);
	} else {
		mm->lines[mm->no_lines++] = Str::duplicate(line);
	}
}

@h Reserved macros.
A few macros are "reserved", that is, have built-in meanings, and use expander
functions other than //Preprocessor::default_expander//.

Some of these, the |special_macros|, are supplied by the code calling the
preprocessor. Those will provide domain-specific functionality. But a few are
built in here and therefore work in every domain:

=
linked_list *Preprocessor::list_of_reserved_macros(linked_list *special_macros) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	Preprocessor::new_loop_macro(L, I"repeat", I"with: WITH in: IN",
		Preprocessor::repeat_expander, NULL);
	Preprocessor::new_macro(L, I"set", I"name: NAME value: VALUE",
		Preprocessor::set_expander, NULL);

	preprocessor_macro *mm;
	LOOP_OVER_LINKED_LIST(mm, preprocessor_macro, special_macros)
		ADD_TO_LINKED_LIST(mm, preprocessor_macro, L);
	return L;
}

void Preprocessor::do_not_suppress_whitespace(preprocessor_macro *mm) {
	mm->suppress_newline_after_expanding = FALSE;
	mm->suppress_whitespace_when_expanding = FALSE;
}

void Preprocessor::new_loop_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification,
	void (*expander)(preprocessor_macro *, preprocessor_state *, text_stream **, preprocessor_loop *, text_file_position *),
	text_file_position *tfp) {
	TEMPORARY_TEXT(subname)

	WRITE_TO(subname, "%S-block", name);
	preprocessor_macro *mm = Preprocessor::new_macro(L, subname, parameter_specification, expander, tfp);
	mm->begins_loop = TRUE;
	mm->loop_name = Str::duplicate(name);

	Str::clear(subname);
	WRITE_TO(subname, "end-%S-block", name);
	mm = Preprocessor::new_macro(L, subname, NULL, Preprocessor::end_loop_expander, tfp);
	mm->ends_loop = TRUE;
	mm->loop_name = Str::duplicate(name);

	Str::clear(subname);
	WRITE_TO(subname, "%S-span", name);
	mm = Preprocessor::new_macro(L, subname, parameter_specification, expander, tfp);
	mm->begins_loop = TRUE;
	mm->loop_name = Str::duplicate(name);
	mm->span = TRUE;
	Preprocessor::do_not_suppress_whitespace(mm);

	Str::clear(subname);
	WRITE_TO(subname, "end-%S-span", name);
	mm = Preprocessor::new_macro(L, subname, NULL, Preprocessor::end_loop_expander, tfp);
	mm->ends_loop = TRUE;
	mm->loop_name = Str::duplicate(name);
	mm->span = TRUE;
	Preprocessor::do_not_suppress_whitespace(mm);

	DISCARD_TEXT(subname)
}

@ Finding a macro in a list:

=
preprocessor_macro *Preprocessor::find_macro(linked_list *L, text_stream *name) {
	preprocessor_macro *mm;
	LOOP_OVER_LINKED_LIST(mm, preprocessor_macro, L)
		if (Str::eq(mm->identifier, name))
			return mm;
	return NULL;
}

@h The expander for user-defined macros.
All macros created by |{define: ...}| are expanded by the following function.
It creates a local "stack frame" making the parameters available as variables,
then runs the definition lines through the scanner, then dismantles the stack
frame again.

=
void Preprocessor::default_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	PPS->stack_frame = Preprocessor::new_variable_set(PPS->stack_frame);
	for (int i=0; i<mm->no_parameters; i++) {
		preprocessor_variable *var =
			Preprocessor::ensure_variable(mm->parameters[i]->definition_token, PPS->stack_frame);
		Preprocessor::write_variable(var, parameter_values[i]);
	}
	for (int i=0; i<mm->no_lines; i++)
		Preprocessor::scan_line(mm->lines[i], tfp, (void *) PPS);
	PPS->stack_frame = PPS->stack_frame->outer;
}

@h The set expander.
An easy one.

=
void Preprocessor::set_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	text_stream *name = parameter_values[0];
	text_stream *value = parameter_values[1];
	
	if (Preprocessor::acceptable_variable_name(name) == FALSE)
		Errors::in_text_file("improper variable name", tfp);
	
	preprocessor_variable *var = Preprocessor::ensure_variable(name, PPS->stack_frame);
	Preprocessor::write_variable(var, value);
}

@h The repeat expander.

=
void Preprocessor::repeat_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	text_stream *with = parameter_values[0];
	text_stream *in = parameter_values[1];
	Preprocessor::set_loop_var_name(loop, with);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, in, L"(%c*?),(%c*)")) {
		text_stream *value = mr.exp[0];
		Str::trim_white_space(value);
		Preprocessor::add_loop_iteration(loop, value);
		Str::clear(in);
		Str::copy(in, mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
	text_stream *value = in;
	Str::trim_white_space(value);
	Preprocessor::add_loop_iteration(loop, value);
}

@h The expander used for all loop ends.
The macros which open a loop just store up the name of the variable and the
range of its values: otherwise, they do nothing. It's only when the end of a
loop is reached that any expansion happens, and this is where.

We create a new stack frame inside the current one, and put the loop variable
into it. Then we run through the iteration values, setting the variable to
each in turn, and expand the material.

=
void Preprocessor::end_loop_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	PPS->shadow_sp = 0;
	if (PPS->repeat_sp == 0) Errors::in_text_file("end without repeat", tfp);
	else {
		preprocessor_loop *loop = &(PPS->repeat_data[--(PPS->repeat_sp)]);
		text_stream *matter = PPS->dest;
		PPS->dest = loop->repeat_saved_dest;
		PPS->stack_frame = Preprocessor::new_variable_set(PPS->stack_frame);
		preprocessor_variable *loop_var =
			Preprocessor::ensure_variable(loop->loop_var_name, PPS->stack_frame);
		text_stream *value;
		LOOP_OVER_LINKED_LIST(value, text_stream, loop->iterations)
			@<Iterate with this value@>;
		PPS->stack_frame = PPS->stack_frame->outer;
	}
}

@<Iterate with this value@> =
	Preprocessor::write_variable(loop_var, value);
	if (mm->span) {
		Preprocessor::expand(matter, tfp, PPS);
	} else {
		TEMPORARY_TEXT(line)
		LOOP_THROUGH_TEXT(pos, matter) {
			if (Str::get(pos) == '\n') {
				Preprocessor::scan_line(line, tfp, (void *) PPS);
				Str::clear(line);
			} else {
				PUT_TO(line, Str::get(pos));
			}
		}
		DISCARD_TEXT(line)
	}
