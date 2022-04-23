[Preprocessor::] Preprocessor.

A simple, general-purpose preprocessor for text files, expanding macros and
performing repetitions.

@h State.

@d MAX_PREPROCESSOR_LOOP_DEPTH 8

=
typedef struct preprocessor_loop {
	struct text_stream *loop_var_name;
	struct linked_list *iterations; /* of |text_stream| */
	int repeat_is_block;
	struct text_stream *repeat_saved_dest;
} preprocessor_loop;

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
} preprocessor_state;

void Preprocessor::preprocess(filename *prototype, filename *F, text_stream *header,
	linked_list *special_macros, general_pointer specifics) {
	struct text_stream processed_file;
	if (STREAM_OPEN_TO_FILE(&processed_file, F, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", F);
	text_stream *OUT = &processed_file;
	WRITE("%S", header);

	preprocessor_state PPS;
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
	TextFiles::read(prototype, FALSE, "can't open prototype file",
		TRUE, Preprocessor::scan_line, NULL, &PPS);
	STREAM_CLOSE(OUT);
}

@h Scanner.

=
void Preprocessor::scan_line(text_stream *line, text_file_position *tfp, void *X) {
	preprocessor_state *PPS = (preprocessor_state *) X;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *#%c*")) { Regexp::dispose_of(&mr); return; } // Skip comment lines

	if (Regexp::match(&mr, line, L" *{define: *(%C+) (%c*)} *")) @<Begin a definition@>;
	if (Regexp::match(&mr, line, L" *{end-define} *")) @<End a definition@>;
	if (PPS->defining) @<Continue a definition@>;
	Regexp::dispose_of(&mr);

	Preprocessor::expand(line, tfp, PPS);

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
}

@<Begin a definition@> =
	if (PPS->defining)
		Errors::in_text_file("nested definitions are not allowed", tfp);
	text_stream *name = mr.exp[0];
	text_stream *parameter_specification = mr.exp[1];
	PPS->defining = Preprocessor::new_macro(PPS->known_macros, name, parameter_specification, tfp, Preprocessor::default_expander);
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

@ =
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
		@<Expand a macro@>;
	} else {
		WRITE_TO(PPS->dest, "%S", text);
	}
	DISCARD_TEXT(before_matter)
	DISCARD_TEXT(braced_matter)
	DISCARD_TEXT(after_matter)
}

@<Expand a macro@> =
	text_stream *identifier = braced_matter;
	text_stream *parameter_settings = NULL;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, identifier, L"(%C+) (%c*)")) {
		identifier = mr.exp[0];
		parameter_settings = mr.exp[1];
	}
	preprocessor_macro *loop_mm;
	LOOP_OVER_LINKED_LIST(loop_mm, preprocessor_macro, PPS->known_macros)
		if (Str::len(loop_mm->loop_name) > 0) {
			if (Str::eq(identifier, loop_mm->loop_name)) {
				if (Str::is_whitespace(after_matter)) {
					if ((loop_mm->span == FALSE) && (loop_mm->begins_repeat)) identifier = loop_mm->identifier;
				} else {
					if ((loop_mm->span) && (loop_mm->begins_repeat)) identifier = loop_mm->identifier;
				}
			}
			TEMPORARY_TEXT(end_name)
			WRITE_TO(end_name, "end-%S", loop_mm->loop_name);
			if (Str::eq(identifier, end_name)) {
				if ((PPS->repeat_sp > 0) && (PPS->repeat_data[PPS->repeat_sp-1].repeat_is_block)) {
					if ((loop_mm->span == FALSE) && (loop_mm->ends_repeat)) identifier = loop_mm->identifier;
				} else {
					if ((loop_mm->span) && (loop_mm->ends_repeat)) identifier = loop_mm->identifier;
				}
			}
			DISCARD_TEXT(end_name)
		}

	if (Preprocessor::acceptable_variable_name(identifier)) {
		Preprocessor::expand(before_matter, tfp, PPS);
		if (PPS->repeat_sp > 0) {
			WRITE_TO(PPS->dest, "{%S}", identifier);
		} else {
			preprocessor_variable *var = Preprocessor::find_variable_in(identifier, PPS->stack_frame);
			if (var) {
				WRITE_TO(PPS->dest, "%S", var->value);
			} else {
				TEMPORARY_TEXT(erm)
				WRITE_TO(erm, "unknown variable '%S'", identifier);
				Errors::in_text_file_S(erm, tfp);
				DISCARD_TEXT(erm)
			}
		}
		Preprocessor::expand(after_matter, tfp, PPS);
	} else {
		preprocessor_macro *mm = Preprocessor::find_macro(PPS->known_macros, identifier);
		if (mm == NULL) {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown macro '%S'", identifier);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		} else {
			if (mm->suppress_whitespace_when_expanding) {
				while (Characters::is_whitespace(Str::get_last_char(before_matter)))
					Str::delete_last_character(before_matter);
				while (Characters::is_whitespace(Str::get_first_char(after_matter)))
					Str::delete_first_character(after_matter);
			}
			Preprocessor::expand(before_matter, tfp, PPS);
			int divert_if_repeating = TRUE;
			if ((mm) && (mm->begins_repeat)) {
				PPS->shadow_sp++;
			}
			if ((mm) && (mm->ends_repeat)) {
				PPS->shadow_sp--;
				if (PPS->shadow_sp == 0) divert_if_repeating = FALSE;
			}
			
			if ((divert_if_repeating) && (PPS->repeat_sp > 0)) {
				WRITE_TO(PPS->dest, "{%S}", braced_matter);
			} else {
				Preprocessor::expand_macro(PPS, mm, parameter_settings, tfp);
				if (mm->suppress_newline_after_expanding) PPS->suppress_newline = TRUE;
			}
			Preprocessor::expand(after_matter, tfp, PPS);
		}
	}
	Regexp::dispose_of(&mr);

@h Variables.

=
typedef struct preprocessor_variable {
	struct text_stream *name;
	struct text_stream *value;
	CLASS_DEFINITION
} preprocessor_variable;

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

preprocessor_variable *Preprocessor::find_variable_in_one(text_stream *name, preprocessor_variable_set *set) {
	if (set == NULL) return NULL;
	preprocessor_variable *var;
	LOOP_OVER_LINKED_LIST(var, preprocessor_variable, set->variables)
		if (Str::eq(name, var->name))
			return var;
	return NULL;
}

preprocessor_variable *Preprocessor::find_variable_in(text_stream *name, preprocessor_variable_set *set) {
	while (set) {
		preprocessor_variable *var = Preprocessor::find_variable_in_one(name, set);
		if (var) return var;
		set = set->outer;
	}
	return NULL;
}

preprocessor_variable *Preprocessor::ensure_variable(text_stream *name, preprocessor_variable_set *in_set) {
	if (in_set == NULL) internal_error("variable without set");
	preprocessor_variable *var = Preprocessor::find_variable_in_one(name, in_set);
	if (var == NULL) {
		var = CREATE(preprocessor_variable);
		var->name = Str::duplicate(name);
		var->value = I"";
		ADD_TO_LINKED_LIST(var, preprocessor_variable, in_set->variables);
	}
	return var;
}

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

@h Macros.

@ The above definition has three parameters, one optional, but only one line. There
are (for now, anyway) hard but harmlessly large limits on the number of these:

@d MAX_PP_MACRO_PARAMETERS 8
@d MAX_PP_MACRO_LINES 128

=
typedef struct preprocessor_macro {
	struct text_stream *identifier;
	struct preprocessor_macro_parameter *parameters[MAX_PP_MACRO_PARAMETERS];
	int no_parameters;
	struct text_stream *lines[MAX_PP_MACRO_LINES];
	int no_lines;
	int suppress_newline_after_expanding;
	int suppress_whitespace_when_expanding;
	int begins_repeat;
	int ends_repeat;
	struct text_stream *loop_name;
	int span;
	void (*expander)(struct preprocessor_macro *, struct preprocessor_state *, struct text_stream **, struct preprocessor_loop *, struct text_file_position *);
	CLASS_DEFINITION
} preprocessor_macro;

typedef struct preprocessor_macro_parameter {
	struct text_stream *name;
	struct text_stream *definition_token;
	int optional;
	CLASS_DEFINITION
} preprocessor_macro_parameter;

@ New macro declaration lines are processed here, and added to a list |L| of
valid macros:

=
preprocessor_macro *Preprocessor::new_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification, text_file_position *tfp,
	void (*expander)(preprocessor_macro *, preprocessor_state *, text_stream **, preprocessor_loop *, text_file_position *)) {	
	if (Preprocessor::find_macro(L, name))
		Errors::in_text_file("a macro with this name already exists", tfp);
	
	preprocessor_macro *new_macro = CREATE(preprocessor_macro);
	new_macro->identifier = Str::duplicate(name);
	new_macro->no_parameters = 0;
	new_macro->no_lines = 0;
	new_macro->suppress_newline_after_expanding = TRUE;
	new_macro->suppress_whitespace_when_expanding = TRUE;
	new_macro->begins_repeat = FALSE;
	new_macro->ends_repeat = FALSE;
	new_macro->loop_name = NULL;
	new_macro->span = FALSE;
	new_macro->expander = expander;

	match_results mr2 = Regexp::create_mr();
	while (Regexp::match(&mr2, parameter_specification, L" *(%C+): *(%C+) *(%c*)")) {
		text_stream *par_name = mr2.exp[0];
		text_stream *token_name = mr2.exp[1];
		Str::clear(parameter_specification);
		Str::copy(parameter_specification, mr2.exp[2]);
		if (new_macro->no_parameters >= MAX_PP_MACRO_PARAMETERS) {
			Errors::in_text_file("too many parameters in this definition", tfp);
		} else {
			@<Add parameter to macro@>;
		}
	}
	Regexp::dispose_of(&mr2);
	if (Str::is_whitespace(parameter_specification) == FALSE)
		Errors::in_text_file("parameter list for this definition is malformed", tfp);
	ADD_TO_LINKED_LIST(new_macro, preprocessor_macro, L);
	return new_macro;
}

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

@ We can then add lines to the definition:

=
void Preprocessor::add_line_to_macro(preprocessor_macro *mm, text_stream *line, text_file_position *tfp) {
	if (mm->no_lines >= MAX_PP_MACRO_LINES) {
		Errors::in_text_file("too many lines in this definition", tfp);
	} else {
		mm->lines[mm->no_lines++] = Str::duplicate(line);
	}
}

@ A few macros are "reserved", that is, have built-in meanings and are not
declared by any makescript but by us. (These have no lines, only parameters.)

=
linked_list *Preprocessor::list_of_reserved_macros(linked_list *special_macros) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	Preprocessor::reserve_repeat_macro(L, I"repeat", I"with: WITH in: IN", Preprocessor::repeat_expander);
	Preprocessor::reserve_span_macro(L, I"set", I"name: NAME value: VALUE", Preprocessor::set_expander);

	preprocessor_macro *mm;
	LOOP_OVER_LINKED_LIST(mm, preprocessor_macro, special_macros)
		ADD_TO_LINKED_LIST(mm, preprocessor_macro, L);
	return L;
}

preprocessor_macro *Preprocessor::reserve_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification,
	void (*expander)(preprocessor_macro *, preprocessor_state *, text_stream **, preprocessor_loop *, text_file_position *)) {	
	preprocessor_macro *reserved = Preprocessor::new_macro(L, name,
		Str::duplicate(parameter_specification), NULL, expander);
	return reserved;
}

preprocessor_macro *Preprocessor::reserve_span_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification,
	void (*expander)(preprocessor_macro *, preprocessor_state *, text_stream **, preprocessor_loop *, text_file_position *)) {
	preprocessor_macro *reserved = Preprocessor::reserve_macro(L, name, parameter_specification, expander);
	reserved->suppress_newline_after_expanding = FALSE;
	reserved->suppress_whitespace_when_expanding = FALSE;
	reserved->span = TRUE;
	return reserved;
}

void Preprocessor::reserve_repeat_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification,
	void (*expander)(preprocessor_macro *, preprocessor_state *, text_stream **, preprocessor_loop *, text_file_position *)) {
	TEMPORARY_TEXT(subname)

	WRITE_TO(subname, "%S-block", name);
	preprocessor_macro *mm = Preprocessor::reserve_macro(L, subname, parameter_specification, expander);
	mm->begins_repeat = TRUE;
	mm->loop_name = Str::duplicate(name);

	Str::clear(subname);
	WRITE_TO(subname, "end-%S-block", name);
	mm = Preprocessor::reserve_macro(L, subname, NULL, Preprocessor::end_repeat_expander);
	mm->ends_repeat = TRUE;
	mm->loop_name = Str::duplicate(name);

	Str::clear(subname);
	WRITE_TO(subname, "%S-span", name);
	mm = Preprocessor::reserve_span_macro(L, subname, parameter_specification, expander);
	mm->begins_repeat = TRUE;
	mm->loop_name = Str::duplicate(name);

	Str::clear(subname);
	WRITE_TO(subname, "end-%S-span", name);
	mm = Preprocessor::reserve_span_macro(L, subname, NULL, Preprocessor::end_repeat_expander);
	mm->ends_repeat = TRUE;
	mm->loop_name = Str::duplicate(name);

	DISCARD_TEXT(subname)
}

@ Finding a macro in a list. (We could use a dictionary for efficiency, but really,
it's unlikely there are ever more than a few macros.)

=
preprocessor_macro *Preprocessor::find_macro(linked_list *L, text_stream *name) {
	preprocessor_macro *mm;
	LOOP_OVER_LINKED_LIST(mm, preprocessor_macro, L)
		if (Str::eq(mm->identifier, name))
			return mm;
	return NULL;
}

@ Expanding a macro is the main event, then:

=
void Preprocessor::expand_macro(preprocessor_state *PPS, preprocessor_macro *mm,
	text_stream *parameter_settings, text_file_position *tfp) {
	text_stream *parameter_values[MAX_PP_MACRO_PARAMETERS];
	for (int i=0; i<MAX_PP_MACRO_PARAMETERS; i++) parameter_values[i] = NULL;

	match_results mr2 = Regexp::create_mr();
	while (Regexp::match(&mr2, parameter_settings, L" *(%C+): *(%c*)")) {
		text_stream *setting = mr2.exp[0];
		text_stream *value = mr2.exp[1];
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
			WRITE_TO(erm, "unknown parameter '%S'", setting);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
		Str::clear(parameter_settings);
		Str::copy(parameter_settings, remainder);
		Regexp::dispose_of(&mr3);
	}
	Regexp::dispose_of(&mr2);
	if (Str::is_whitespace(parameter_settings) == FALSE)
		Errors::in_text_file("parameter list is malformed", tfp);
	
	for (int i=0; i<mm->no_parameters; i++)
		if (parameter_values[i] == NULL)
			if (mm->parameters[i]->optional == FALSE) {
				TEMPORARY_TEXT(erm)
				WRITE_TO(erm, "compulsory parameter '%S' not given", mm->parameters[i]->name);
				Errors::in_text_file_S(erm, tfp);
				DISCARD_TEXT(erm)
			}

	preprocessor_loop *rep = NULL;
	if (mm->begins_repeat) {
		if (PPS->repeat_sp >= MAX_PREPROCESSOR_LOOP_DEPTH) {
			Errors::in_text_file("repetition too deep", tfp);
		} else {
			rep = &(PPS->repeat_data[PPS->repeat_sp++]);
			PPS->shadow_sp = 1;
			rep->loop_var_name = I"NAME";
			rep->iterations = NEW_LINKED_LIST(text_stream);	
			rep->repeat_is_block = TRUE;
			if (mm->span) rep->repeat_is_block = FALSE;
			rep->repeat_saved_dest = PPS->dest;
			PPS->dest = Str::new();
		}
	}

	(*(mm->expander))(mm, PPS, parameter_values, rep, tfp);
}

@

=
void Preprocessor::default_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	PPS->stack_frame = Preprocessor::new_variable_set(PPS->stack_frame);
	for (int i=0; i<mm->no_parameters; i++) {
		preprocessor_variable *var =
			Preprocessor::ensure_variable(mm->parameters[i]->definition_token, PPS->stack_frame);
		var->value = parameter_values[i];
	}
	for (int i=0; i<mm->no_lines; i++)
		Preprocessor::scan_line(mm->lines[i], tfp, (void *) PPS);
	PPS->stack_frame = PPS->stack_frame->outer;
}

void Preprocessor::set_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	text_stream *name = parameter_values[0];
	text_stream *value = parameter_values[1];
	
	if (Preprocessor::acceptable_variable_name(name) == FALSE)
		Errors::in_text_file("improper variable name", tfp);
	
	preprocessor_variable *var = Preprocessor::ensure_variable(name, PPS->stack_frame);
	var->value = Str::duplicate(value);
}

void Preprocessor::repeat_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	text_stream *with = parameter_values[0];
	text_stream *in = parameter_values[1];
	rep->loop_var_name = Str::duplicate(with);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, in, L"(%c*?),(%c*)")) {
		text_stream *value = mr.exp[0];
		Str::trim_white_space(value);
		ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, rep->iterations);
		Str::clear(in);
		Str::copy(in, mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
	text_stream *value = in;
	Str::trim_white_space(value);
	ADD_TO_LINKED_LIST(Str::duplicate(value), text_stream, rep->iterations);
}

@ =
void Preprocessor::end_repeat_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	PPS->shadow_sp = 0;
	if (PPS->repeat_sp == 0) Errors::in_text_file("end without repeat", tfp);
	else {
		preprocessor_loop *rep = &(PPS->repeat_data[--(PPS->repeat_sp)]);
		int as_lines = TRUE;
		if (mm->span) as_lines = FALSE;
		text_stream *matter = PPS->dest;
		PPS->dest = rep->repeat_saved_dest;
		PPS->stack_frame = Preprocessor::new_variable_set(PPS->stack_frame);
		preprocessor_variable *loop_var = Preprocessor::ensure_variable(rep->loop_var_name, PPS->stack_frame);
		text_stream *value;
		LOOP_OVER_LINKED_LIST(value, text_stream, rep->iterations)
			@<Iterate with this value@>;
		PPS->stack_frame = PPS->stack_frame->outer;
	}
}

@<Iterate with this value@> =
	loop_var->value = value;
	if (as_lines) {
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
	} else {
		Preprocessor::expand(matter, tfp, PPS);
	}
