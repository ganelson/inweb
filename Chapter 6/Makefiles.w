[Makefiles::] Makefiles.

Constructing a suitable makefile for a simple inweb project.

@h Introduction.
At some point, the material in this section will probably be spun out into an
an independent tool called "inmake". It's a simple utility for constructing makefiles,
but has gradually become less simple over time, as is the way of these things.

The idea is simple enough: the user writes a "makescript", which is really a
makefile but with the possibility of using some higher-level features, and we
translate that it into an actual makefile (which is usually longer and less
easy to read).

@h State.

@d MAX_MAKEFILE_REPEAT_DEPTH 8

=
typedef struct makefile_repeat {
	int repeat_scope; /* during a repeat, either |MAKEFILE_TOOL_MOM| or |MAKEFILE_MODULE_MOM| */
	struct text_stream *repeat_tag;
	struct text_stream *repeat_with;
	struct text_stream *repeat_in;
	int repeat_is_block;
	struct text_stream *repeat_saved_dest;
} makefile_repeat;

typedef struct makefile_state {
	struct web *for_web;
	struct text_stream *dest;
	struct makefile_macro *defining; /* a "define" body being scanned */
	int repeat_sp;
	int shadow_sp;
	struct makefile_repeat repeat_data[MAX_MAKEFILE_REPEAT_DEPTH];
	int suppress_newline; /* at the end of this line */
	int last_line_was_blank; /* used to suppress runs of multiple blank lines */
	struct dictionary *tools_dictionary;
	struct dictionary *webs_dictionary;
	struct dictionary *modules_dictionary;
	struct module_search *search_path;
	struct makefile_variable_set *global_variables;
	struct makefile_variable_set *stack_frame;
	struct linked_list *known_macros; /* of |makefile_macro| */
} makefile_state;

void Makefiles::write(web *W, filename *prototype, filename *F, module_search *I) {
	struct text_stream makefile;
	if (STREAM_OPEN_TO_FILE(&makefile, F, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", F);
	WRITE_TO(STDOUT, "(Read script from %f)\n", prototype);
	text_stream *OUT = &makefile;

	makefile_state MS;
	MS.dest = OUT;
	MS.for_web = W;
	MS.suppress_newline = FALSE;
	MS.last_line_was_blank = TRUE;
	MS.defining = NULL;
	MS.repeat_sp = 0;
	MS.shadow_sp = 0;
	MS.tools_dictionary = Dictionaries::new(16, FALSE);
	MS.webs_dictionary = Dictionaries::new(16, FALSE);
	MS.modules_dictionary = Dictionaries::new(16, FALSE);
	MS.search_path = I;
	MS.global_variables = Makefiles::new_variable_set(NULL);
	MS.stack_frame = MS.global_variables;
	MS.known_macros = Makefiles::list_of_reserved_macros();
	WRITE("# This makefile was automatically written by inweb -makefile\n");
	WRITE("# and is not intended for human editing\n\n");
	TextFiles::read(prototype, FALSE, "can't open prototype file",
		TRUE, Makefiles::scan_makefile_line, NULL, &MS);
	STREAM_CLOSE(OUT);
}

@h Scanner.

=
void Makefiles::scan_makefile_line(text_stream *line, text_file_position *tfp, void *X) {
	makefile_state *MS = (makefile_state *) X;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *#%c*")) { Regexp::dispose_of(&mr); return; } // Skip comment lines

	if (Regexp::match(&mr, line, L" *{define: *(%C+) (%c*)} *")) @<Begin a definition@>;
	if (Regexp::match(&mr, line, L" *{end-define} *")) @<End a definition@>;
	if (MS->defining) @<Continue a definition@>;
	Regexp::dispose_of(&mr);

	Makefiles::expand(line, tfp, MS);

	if (MS->suppress_newline == FALSE) {
		text_stream *OUT = MS->dest;
		if (Str::len(line) == 0) {
			if (MS->last_line_was_blank == FALSE) WRITE("\n");
			MS->last_line_was_blank = TRUE;
		} else {
			MS->last_line_was_blank = FALSE;
			WRITE("\n");
		}
	}
	MS->suppress_newline = FALSE;
}

@<Begin a definition@> =
	if (MS->defining)
		Errors::in_text_file("nested definitions are not allowed", tfp);
	text_stream *name = mr.exp[0];
	text_stream *parameter_specification = mr.exp[1];
	MS->defining = Makefiles::new_macro(MS->known_macros, name, parameter_specification, tfp);
	Regexp::dispose_of(&mr);
	return;

@<Continue a definition@> =
	Makefiles::add_line_to_macro(MS->defining, line, tfp);
	Regexp::dispose_of(&mr);
	return;

@<End a definition@> =
	if (MS->defining == NULL)
		Errors::in_text_file("{end-define} without {define: ...}", tfp);
	MS->defining = NULL;
	Regexp::dispose_of(&mr);
	return;

@ =
void Makefiles::expand(text_stream *text, text_file_position *tfp, makefile_state *MS) {
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
		WRITE_TO(MS->dest, "%S", text);
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
	if (Str::eq(identifier, I"repeat")) {
		if (Str::is_whitespace(after_matter)) identifier = I"repeat-block";
		else identifier = I"repeat-span";
	}
	if (Str::eq(identifier, I"end-repeat")) {
		if ((MS->repeat_sp > 0) && (MS->repeat_data[MS->repeat_sp-1].repeat_is_block))
			identifier = I"end-block";
		else
			identifier = I"end-span";
	}

	if (Makefiles::acceptable_variable_name(identifier)) {
		Makefiles::expand(before_matter, tfp, MS);
		if (MS->repeat_sp > 0) {
			WRITE_TO(MS->dest, "{%S}", identifier);
		} else {
			makefile_variable *var = Makefiles::find_variable_in(identifier, MS->stack_frame);
			if (var) {
				WRITE_TO(MS->dest, "%S", var->value);
			} else {
				TEMPORARY_TEXT(erm)
				WRITE_TO(erm, "unknown variable '%S'", identifier);
				Errors::in_text_file_S(erm, tfp);
				DISCARD_TEXT(erm)
			}
		}
		Makefiles::expand(after_matter, tfp, MS);
	} else {
		makefile_macro *mm = Makefiles::find_macro(MS->known_macros, identifier);
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
			Makefiles::expand(before_matter, tfp, MS);
			int divert_if_repeating = TRUE;
			if ((mm) &&
				((mm->reserved_macro_meaning == REPEAT_BLOCK_RMM) ||
					(mm->reserved_macro_meaning == REPEAT_SPAN_RMM))) {
				MS->shadow_sp++;
			}
			if ((mm) &&
				((mm->reserved_macro_meaning == END_BLOCK_RMM) ||
					(mm->reserved_macro_meaning == END_SPAN_RMM))) {
				MS->shadow_sp--;
				if (MS->shadow_sp == 0) divert_if_repeating = FALSE;
			}
			
			if ((divert_if_repeating) && (MS->repeat_sp > 0)) {
				WRITE_TO(MS->dest, "{%S}", braced_matter);
			} else {
				Makefiles::expand_macro(MS, mm, parameter_settings, tfp);
				if (mm->suppress_newline_after_expanding) MS->suppress_newline = TRUE;
			}
			Makefiles::expand(after_matter, tfp, MS);
		}
	}
	Regexp::dispose_of(&mr);

@ =
void Makefiles::pathname_slashed(OUTPUT_STREAM, pathname *P) {
	TEMPORARY_TEXT(PT)
	WRITE_TO(PT, "%p", P);
	LOOP_THROUGH_TEXT(pos, PT) {
		wchar_t c = Str::get(pos);
		if (c == ' ') WRITE("\\ ");
		else PUT(c);
	}
	DISCARD_TEXT(PT)
}

void Makefiles::pattern(OUTPUT_STREAM, linked_list *L, filename *F) {
	dictionary *patterns_done = Dictionaries::new(16, TRUE);
	if (F) @<Add pattern for file F, if not already given@>;
	section_md *Sm;
	LOOP_OVER_LINKED_LIST(Sm, section_md, L) {
		filename *F = Sm->source_file_for_section;
		@<Add pattern for file F, if not already given@>;
	}
}

@<Add pattern for file F, if not already given@> =
	pathname *P = Filenames::up(F);
	TEMPORARY_TEXT(leaf_pattern)
	WRITE_TO(leaf_pattern, "%S", Pathnames::directory_name(P));
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, leaf_pattern, L"Chapter %d*")) {
		Str::clear(leaf_pattern); WRITE_TO(leaf_pattern, "Chapter*");
	} else if (Regexp::match(&mr, leaf_pattern, L"Appendix %C")) {
		Str::clear(leaf_pattern); WRITE_TO(leaf_pattern, "Appendix*");
	}
	Regexp::dispose_of(&mr);
	TEMPORARY_TEXT(tester)
	WRITE_TO(tester, "%p/%S/*", Pathnames::up(P), leaf_pattern);
	DISCARD_TEXT(leaf_pattern)
	Filenames::write_extension(tester, F);
	if (Dictionaries::find(patterns_done, tester) == NULL) {
		WRITE_TO(Dictionaries::create_text(patterns_done, tester), "got this");
		WRITE(" ");
		LOOP_THROUGH_TEXT(pos, tester) {
			wchar_t c = Str::get(pos);
			if (c == ' ') PUT('\\');
			PUT(c);
		}
	}
	DISCARD_TEXT(tester)

@ And finally, the following handles repetitions both of blocks and of spans:

=
void Makefiles::repeat(text_stream *matter,
	int as_lines, text_file_position *tfp, makefile_repeat *rep, makefile_state *MS) {
	int over = rep->repeat_scope;
	text_stream *tag = rep->repeat_tag;
	MS->stack_frame = Makefiles::new_variable_set(MS->stack_frame);
	text_stream *loop_var_name = I"NAME";
	if (Str::len(rep->repeat_with) > 0) loop_var_name = rep->repeat_with;
	makefile_variable *loop_var = Makefiles::ensure_variable(loop_var_name, MS->stack_frame);
	if (Str::len(rep->repeat_in) > 0) {
		match_results mr = Regexp::create_mr();
		while (Regexp::match(&mr, rep->repeat_in, L"(%c*?),(%c*)")) {
			text_stream *value = mr.exp[0];
			Str::trim_white_space(value);
			@<Iterate with this value@>;
			Str::clear(rep->repeat_in);
			Str::copy(rep->repeat_in, mr.exp[1]);
		}
		Regexp::dispose_of(&mr);
		text_stream *value = rep->repeat_in;
		Str::trim_white_space(value);
		@<Iterate with this value@>;
	} else {
		module *M;
		LOOP_OVER(M, module) {
			if ((M->origin_marker == over) &&
				((Str::eq(tag, I"all")) || (Str::eq(tag, M->module_tag)))) {
				text_stream *value = M->module_name;
				@<Iterate with this value@>;
			}
		}
	}
	MS->stack_frame = MS->stack_frame->outer;
}

@<Iterate with this value@> =
	loop_var->value = value;
	if (as_lines) {
		TEMPORARY_TEXT(line)
		LOOP_THROUGH_TEXT(pos, matter) {
			if (Str::get(pos) == '\n') {
				Makefiles::scan_makefile_line(line, tfp, (void *) MS);
				Str::clear(line);
			} else {
				PUT_TO(line, Str::get(pos));
			}
		}
		DISCARD_TEXT(line)
	} else {
		Makefiles::expand(matter, tfp, MS);
	}

@ This is used to scan the platform settings file for a definition line in the
shape INWEBPLATFORM = PLATFORM, in order to find out what PLATFORM the make file
will be used on.

=
void Makefiles::seek_INWEBPLATFORM(text_stream *line, text_file_position *tfp, void *X) {
	text_stream *OUT = (text_stream *) X;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *INWEBPLATFORM = (%C+) *")) WRITE("%S", mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@h Variables.

=
typedef struct makefile_variable {
	struct text_stream *name;
	struct text_stream *value;
	CLASS_DEFINITION
} makefile_variable;

typedef struct makefile_variable_set {
	struct linked_list *variables; /* of |makefile_variable| */
	struct makefile_variable_set *outer;
	CLASS_DEFINITION
} makefile_variable_set;

makefile_variable_set *Makefiles::new_variable_set(makefile_variable_set *outer) {
	makefile_variable_set *set = CREATE(makefile_variable_set);
	set->variables = NEW_LINKED_LIST(makefile_variable);
	set->outer = outer;
	return set;
}

makefile_variable *Makefiles::find_variable_in_one(text_stream *name, makefile_variable_set *set) {
	if (set == NULL) return NULL;
	makefile_variable *var;
	LOOP_OVER_LINKED_LIST(var, makefile_variable, set->variables)
		if (Str::eq(name, var->name))
			return var;
	return NULL;
}

makefile_variable *Makefiles::find_variable_in(text_stream *name, makefile_variable_set *set) {
	while (set) {
		makefile_variable *var = Makefiles::find_variable_in_one(name, set);
		if (var) return var;
		set = set->outer;
	}
	return NULL;
}

makefile_variable *Makefiles::ensure_variable(text_stream *name, makefile_variable_set *in_set) {
	if (in_set == NULL) internal_error("variable without set");
	makefile_variable *var = Makefiles::find_variable_in_one(name, in_set);
	if (var == NULL) {
		var = CREATE(makefile_variable);
		var->name = Str::duplicate(name);
		var->value = I"";
		ADD_TO_LINKED_LIST(var, makefile_variable, in_set->variables);
	}
	return var;
}

int Makefiles::acceptable_variable_name(text_stream *name) {
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
A typical macro definition looks like this:
= (text)
{define: link to: TO from: FROM ?options: OPTS}
	clang $(CCOPTS) -g -o {TO} {FROM} {OPTS}
{end-define}
=
And here is a usage of it:
= (text)
	{link from: frog.o to: frog.c}
=
This doesn't specify "options: ...", but doesn't have to, because that's optional --
note the question mark in the macro declaration. But it does specify "from: ..."
and "to: ...", which are compulsory. Parameters are always named, as this example
suggests, and can be given in any order so long as all the non-optional ones are
present.

This usage results in the following line in the final makefile:
= (text)
	clang $(CCOPTS) -g -o frog.c frog.o 
=
Note the difference between |$(CCOPTS)|, which is a make variable, and the braced
tokens |{TO}|, |{FROM}| and |{OPTS}|, which are makescript variables. In makescripts,
the only material treated as special is material in braces |{...}|.

@ The above definition has three parameters, one optional, but only one line. There
are (for now, anyway) hard but harmlessly large limits on the number of these:

@d MAX_MAKEFILE_MACRO_PARAMETERS 8
@d MAX_MAKEFILE_MACRO_LINES 128

=
typedef struct makefile_macro {
	struct text_stream *identifier;
	struct makefile_macro_parameter *parameters[MAX_MAKEFILE_MACRO_PARAMETERS];
	int no_parameters;
	struct text_stream *lines[MAX_MAKEFILE_MACRO_LINES];
	int no_lines;
	int reserved_macro_meaning;
	int suppress_newline_after_expanding;
	int suppress_whitespace_when_expanding;
	CLASS_DEFINITION
} makefile_macro;

typedef struct makefile_macro_parameter {
	struct text_stream *name;
	struct text_stream *definition_token;
	int optional;
	CLASS_DEFINITION
} makefile_macro_parameter;

@ New macro declaration lines are processed here, and added to a list |L| of
valid macros:

=
makefile_macro *Makefiles::new_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification, text_file_position *tfp) {	
	if (Makefiles::find_macro(L, name))
		Errors::in_text_file("a macro with this name already exists", tfp);
	
	makefile_macro *new_macro = CREATE(makefile_macro);
	new_macro->identifier = Str::duplicate(name);
	new_macro->no_parameters = 0;
	new_macro->no_lines = 0;
	new_macro->reserved_macro_meaning = UNRESERVED_RMM;
	new_macro->suppress_newline_after_expanding = TRUE;
	new_macro->suppress_whitespace_when_expanding = TRUE;

	match_results mr2 = Regexp::create_mr();
	while (Regexp::match(&mr2, parameter_specification, L" *(%C+): *(%C+) *(%c*)")) {
		text_stream *par_name = mr2.exp[0];
		text_stream *token_name = mr2.exp[1];
		Str::clear(parameter_specification);
		Str::copy(parameter_specification, mr2.exp[2]);
		if (new_macro->no_parameters >= MAX_MAKEFILE_MACRO_PARAMETERS) {
			Errors::in_text_file("too many parameters in this definition", tfp);
		} else {
			@<Add parameter to macro@>;
		}
	}
	Regexp::dispose_of(&mr2);
	if (Str::is_whitespace(parameter_specification) == FALSE)
		Errors::in_text_file("parameter list for this definition is malformed", tfp);
	ADD_TO_LINKED_LIST(new_macro, makefile_macro, L);
	return new_macro;
}

@<Add parameter to macro@> =
	makefile_macro_parameter *new_parameter = CREATE(makefile_macro_parameter);
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
void Makefiles::add_line_to_macro(makefile_macro *mm, text_stream *line, text_file_position *tfp) {
	if (mm->no_lines >= MAX_MAKEFILE_MACRO_LINES) {
		Errors::in_text_file("too many lines in this definition", tfp);
	} else {
		mm->lines[mm->no_lines++] = Str::duplicate(line);
	}
}

@ A few macros are "reserved", that is, have built-in meanings and are not
declared by any makescript but by us. (These have no lines, only parameters.)

@e UNRESERVED_RMM from 0
@e PLATFORM_SETTINGS_RMM
@e IDENTITY_SETTINGS_RMM
@e COMPONENT_RMM
@e DEPENDENT_FILES_RMM
@e REPEAT_BLOCK_RMM
@e END_BLOCK_RMM
@e REPEAT_SPAN_RMM
@e END_SPAN_RMM
@e SET_RMM

=
linked_list *Makefiles::list_of_reserved_macros(void) {
	linked_list *L = NEW_LINKED_LIST(makefile_macro);
	Makefiles::reserve_macro(L, I"platform-settings", NULL, PLATFORM_SETTINGS_RMM);
	Makefiles::reserve_macro(L, I"identity-settings", NULL, IDENTITY_SETTINGS_RMM);
	Makefiles::reserve_macro(L, I"component",
		I"symbol: SYMBOL webname: WEBNAME path: PATH set: SET category: CATEGORY",
		COMPONENT_RMM);
	Makefiles::reserve_macro(L, I"dependent-files",
		I"?tool: TOOL ?module: MODULES ?tool-and-modules: BOTH",
		DEPENDENT_FILES_RMM);
	Makefiles::reserve_macro(L, I"repeat-block",
		I"?over: CATEGORY ?set: SET ?with: WITH ?in: IN", REPEAT_BLOCK_RMM);
	Makefiles::reserve_macro(L, I"end-block", NULL, END_BLOCK_RMM);
	Makefiles::reserve_span_macro(L, I"repeat-span",
		I"?over: CATEGORY ?set: SET ?with: WITH ?in: IN", REPEAT_SPAN_RMM);
	Makefiles::reserve_span_macro(L, I"end-span", NULL, END_SPAN_RMM);
	Makefiles::reserve_span_macro(L, I"set",
		I"name: NAME value: VALUE", SET_RMM);
	return L;
}

void Makefiles::reserve_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification, int rmm) {
	makefile_macro *reserved = Makefiles::new_macro(L, name,
		Str::duplicate(parameter_specification), NULL);
	reserved->reserved_macro_meaning = rmm;
}

void Makefiles::reserve_span_macro(linked_list *L, text_stream *name,
	text_stream *parameter_specification, int rmm) {
	makefile_macro *reserved = Makefiles::new_macro(L, name,
		Str::duplicate(parameter_specification), NULL);
	reserved->reserved_macro_meaning = rmm;
	reserved->suppress_newline_after_expanding = FALSE;
	reserved->suppress_whitespace_when_expanding = FALSE;
}

@ Finding a macro in a list. (We could use a dictionary for efficiency, but really,
it's unlikely there are ever more than a few macros.)

=
makefile_macro *Makefiles::find_macro(linked_list *L, text_stream *name) {
	makefile_macro *mm;
	LOOP_OVER_LINKED_LIST(mm, makefile_macro, L)
		if (Str::eq(mm->identifier, name))
			return mm;
	return NULL;
}

@ Expanding a macro is the main event, then:

=
void Makefiles::expand_macro(makefile_state *MS, makefile_macro *mm,
	text_stream *parameter_settings, text_file_position *tfp) {
	text_stream *OUT = MS->dest;
	text_stream *parameter_values[MAX_MAKEFILE_MACRO_PARAMETERS];
	for (int i=0; i<MAX_MAKEFILE_MACRO_PARAMETERS; i++) parameter_values[i] = NULL;

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
				text_stream *saved = MS->dest;
				MS->dest = parameter_values[i];
				Makefiles::expand(value, tfp, MS);
				MS->dest = saved;
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

	switch (mm->reserved_macro_meaning) {
		case UNRESERVED_RMM: @<Expand a textual definition@>; break;
		case PLATFORM_SETTINGS_RMM: @<Expand platform settings@>; break;
		case IDENTITY_SETTINGS_RMM: @<Expand identity settings@>; break;
		case COMPONENT_RMM: @<Expand component declaration@>; break;
		case DEPENDENT_FILES_RMM: @<Expand dependent-files@>; break;
		case REPEAT_BLOCK_RMM: @<Expand repeat-block@>; break;
		case END_BLOCK_RMM: @<Expand end-block@>; break;
		case REPEAT_SPAN_RMM: @<Expand repeat-block@>; break;
		case END_SPAN_RMM: @<Expand end-block@>; break;
		case SET_RMM: @<Expand set@>; break;
		default: internal_error("unimplemented reserved macro");
	}
}

@<Expand a textual definition@> =
	MS->stack_frame = Makefiles::new_variable_set(MS->stack_frame);
	for (int i=0; i<mm->no_parameters; i++) {
		makefile_variable *var =
			Makefiles::ensure_variable(mm->parameters[i]->definition_token, MS->stack_frame);
		var->value = parameter_values[i];
	}
	for (int i=0; i<mm->no_lines; i++)
		Makefiles::scan_makefile_line(mm->lines[i], tfp, (void *) MS);
	MS->stack_frame = MS->stack_frame->outer;

@<Expand platform settings@> =
	filename *prototype = Filenames::in(path_to_inweb, I"platform-settings.mk");
	text_stream *INWEBPLATFORM = Str::new();
	TextFiles::read(prototype, FALSE, "can't open platform settings file",
		TRUE, Makefiles::seek_INWEBPLATFORM, NULL, INWEBPLATFORM);
	if (Str::len(INWEBPLATFORM) == 0) {
		Errors::in_text_file(
			"found platform settings file, but it does not set INWEBPLATFORM", tfp);
	} else {
		pathname *P = Pathnames::down(path_to_inweb, I"Materials");
		P = Pathnames::down(P, I"platforms");
		WRITE_TO(INWEBPLATFORM, ".mkscript");
		filename *F = Filenames::in(P, INWEBPLATFORM);
		TextFiles::read(F, FALSE, "can't open platform definitions file",
			TRUE, Makefiles::scan_makefile_line, NULL, MS);
		WRITE_TO(STDOUT, "(Read definitions file '%S' from ", INWEBPLATFORM);
		Pathnames::to_text_relative(STDOUT, path_to_inweb, P);
		WRITE_TO(STDOUT, ")\n");
	}

@<Expand identity settings@> =
	WRITE("INWEB = "); Makefiles::pathname_slashed(OUT, path_to_inweb); WRITE("/Tangled/inweb\n");
	pathname *path_to_intest = Pathnames::down(Pathnames::up(path_to_inweb), I"intest");
	WRITE("INTEST = "); Makefiles::pathname_slashed(OUT, path_to_intest); WRITE("/Tangled/intest\n");
	if (MS->for_web) {
		WRITE("MYNAME = %S\n", Pathnames::directory_name(MS->for_web->md->path_to_web));
		WRITE("ME = "); Makefiles::pathname_slashed(OUT, MS->for_web->md->path_to_web);
		WRITE("\n");
		MS->last_line_was_blank = FALSE;
	}

@<Expand component declaration@> =
	text_stream *symbol = parameter_values[0];
	text_stream *webname = parameter_values[1];
	text_stream *path = parameter_values[2];
	text_stream *set = parameter_values[3];
	text_stream *category = parameter_values[4];
	
	int marker = -1;
	dictionary *D = NULL;
	if (Str::eq(category, I"tool")) {
		marker = MAKEFILE_TOOL_MOM;
		D = MS->tools_dictionary;
	} else if (Str::eq(category, I"web")) {
		marker = MAKEFILE_WEB_MOM;
		D = MS->webs_dictionary;
	} else if (Str::eq(category, I"module")) {
		marker = MAKEFILE_MODULE_MOM;
		D = MS->modules_dictionary;
	} else {
		Errors::in_text_file("category should be 'tool', 'module' or 'web'", tfp);
	}
	if (D) {
		WRITE("%SLEAF = %S\n", symbol, webname);
		WRITE("%SWEB = %S\n", symbol, path);
		WRITE("%SMAKER = $(%SWEB)/%S.mk\n", symbol, symbol, webname);
		WRITE("%SX = $(%SWEB)/Tangled/%S\n", symbol, symbol, webname);
		MS->last_line_was_blank = FALSE;
		web_md *Wm = Reader::load_web_md(Pathnames::from_text(path), NULL, MS->search_path, TRUE);
		Wm->as_module->module_name = Str::duplicate(symbol);
		Wm->as_module->module_tag = Str::duplicate(set);
		Wm->as_module->origin_marker = marker;
		Dictionaries::create(D, symbol);
		Dictionaries::write_value(D, symbol, Wm);
	}

@<Expand dependent-files@> =
	text_stream *tool = parameter_values[0];
	text_stream *modules = parameter_values[1];
	text_stream *both = parameter_values[2];
	if (Str::len(tool) > 0) {
		if (Dictionaries::find(MS->tools_dictionary, tool)) {
			web_md *Wm = Dictionaries::read_value(MS->tools_dictionary, tool);
			Makefiles::pattern(OUT, Wm->as_module->sections_md, Wm->contents_filename);
		} else if (Dictionaries::find(MS->webs_dictionary, tool)) {
			web_md *Wm = Dictionaries::read_value(MS->webs_dictionary, tool);
			Makefiles::pattern(OUT, Wm->as_module->sections_md, Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown tool '%S' to find dependencies for", tool);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else if (Str::len(modules) > 0) {
		if (Dictionaries::find(MS->modules_dictionary, modules)) {
			web_md *Wm = Dictionaries::read_value(MS->modules_dictionary, modules);
			Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown module '%S' to find dependencies for", modules);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else if (Str::len(both) > 0) {
		if (Dictionaries::find(MS->tools_dictionary, both)) {
			web_md *Wm = Dictionaries::read_value(MS->tools_dictionary, both);
			Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
		} else if (Dictionaries::find(MS->webs_dictionary, both)) {
			web_md *Wm = Dictionaries::read_value(MS->webs_dictionary, both);
			Makefiles::pattern(OUT, Wm->sections_md, Wm->contents_filename);
		} else {
			TEMPORARY_TEXT(erm)
			WRITE_TO(erm, "unknown tool '%S' to find dependencies for", both);
			Errors::in_text_file_S(erm, tfp);
			DISCARD_TEXT(erm)
		}
	} else {
		Makefiles::pattern(OUT, MS->for_web->md->sections_md, MS->for_web->md->contents_filename);
	}
	WRITE("\n");
	MS->last_line_was_blank = FALSE;

@<Expand repeat-block@> =
	if (MS->repeat_sp >= MAX_MAKEFILE_REPEAT_DEPTH) {
		Errors::in_text_file("repetition too deep", tfp);
	} else {
		text_stream *category = parameter_values[0];
		text_stream *set = parameter_values[1];
		text_stream *with = parameter_values[2];
		text_stream *in = parameter_values[3];
		if (Str::len(set) == 0) set = I"all";
		if (Str::eq(category, I"tool")) {
			int marker = MAKEFILE_TOOL_MOM;
			@<Begin a repeat block@>;
		} else if (Str::eq(category, I"web")) {
			int marker = MAKEFILE_WEB_MOM;
			@<Begin a repeat block@>;
		} else if (Str::eq(category, I"module")) {
			int marker = MAKEFILE_MODULE_MOM;
			@<Begin a repeat block@>;
		} else if (Str::len(category) > 0) {
			Errors::in_text_file("category should be 'tool', 'module' or 'web'", tfp);
		} else {
			if ((Str::len(with) == 0) || (Str::len(in) == 0))
				Errors::in_text_file("should give both with: VAR and in: LIST", tfp);
			@<Begin a repeat with@>;
		}
	}

@<Begin a repeat block@> =
	makefile_repeat *rep = &(MS->repeat_data[MS->repeat_sp++]);
	MS->shadow_sp = 1;
	rep->repeat_scope = marker;
	rep->repeat_tag = Str::duplicate(set);
	rep->repeat_with = NULL;
	rep->repeat_in = NULL;
	rep->repeat_is_block = TRUE;
	if (mm->reserved_macro_meaning == REPEAT_SPAN_RMM) rep->repeat_is_block = FALSE;
	rep->repeat_saved_dest = MS->dest;
	MS->dest = Str::new();

@<Begin a repeat with@> =
	makefile_repeat *rep = &(MS->repeat_data[MS->repeat_sp++]);
	MS->shadow_sp = 1;
	rep->repeat_scope = -1;
	rep->repeat_tag = NULL;
	rep->repeat_with = Str::duplicate(with);
	rep->repeat_in = Str::duplicate(in);
	rep->repeat_is_block = TRUE;
	if (mm->reserved_macro_meaning == REPEAT_SPAN_RMM) rep->repeat_is_block = FALSE;
	rep->repeat_saved_dest = MS->dest;
	MS->dest = Str::new();

@<Expand end-block@> = 
	MS->shadow_sp = 0;
	if (MS->repeat_sp == 0) Errors::in_text_file("end without repeat", tfp);
	else {
		makefile_repeat *rep = &(MS->repeat_data[--(MS->repeat_sp)]);
		int as_lines = TRUE;
		if (mm->reserved_macro_meaning == END_SPAN_RMM) as_lines = FALSE;
		text_stream *matter = MS->dest;
		MS->dest = rep->repeat_saved_dest;
		Makefiles::repeat(matter, as_lines, tfp, rep, MS);
	}

@<Expand set@> =
	text_stream *name = parameter_values[0];
	text_stream *value = parameter_values[1];
	
	if (Makefiles::acceptable_variable_name(name) == FALSE)
		Errors::in_text_file("improper variable name", tfp);
	
	makefile_variable *var = Makefiles::ensure_variable(name, MS->stack_frame);
	var->value = Str::duplicate(value);
