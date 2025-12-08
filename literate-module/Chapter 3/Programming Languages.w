[Languages::] Programming Languages.

Defining the programming languages supported by our LP system, loading in their
definitions from files.

@h Global definitions.
These calls rather crudely put any languages whose definitions they find into
the global resources we're holding, thus making them available to anything that
wants them. Inweb uses these only in response to direct command-line requests.

We can read every language in a directory, all at once:

=
void Languages::read_definitions(pathname *P) {
	scan_directory *D = Directories::open(P);
	TEMPORARY_TEXT(leafname)
	while (Directories::next(D, leafname)) {
		if (Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) {
			filename *F = Filenames::in(P, leafname);
			Languages::read_definition(F);
		}
	}
	DISCARD_TEXT(leafname)
	Directories::close(D);
}

@ Or just a single file:

=
programming_language *Languages::read_definition(filename *F) {
	wcl_declaration *D = WCL::read_just_one(F, LANGUAGE_WCLTYPE);
	if (D == NULL) return NULL;
	WCL::make_global(D);
	return RETRIEVE_POINTER_programming_language(D->object_declared);
}

@ Similarly crudely, this writes out what we have in memory, sorted alphabetically
for tidiness:

=
void Languages::show(OUTPUT_STREAM, ls_web *W) {
	WRITE("I can see the following programming language definitions:\n\n");
	WCL::write_sorted_list_of_resources(OUT, W, LANGUAGE_WCLTYPE);
}

@h Finding as resources.
Programming languages are WCL resources of type |LANGUAGE_WCLTYPE|, so we
find them by looking for a suitable resource.

Like all resources they are identified by name: for example, |C++| or |Perl|.
A nuisance too is that we have to decide what to recognise when it comes to
names for Inform: Inform, Inform 6, Inform6, I6, Inform 7, Inform7 and I7.
We're just going to pragmatically convert the unspaced versions into the spaced
ones and leave it at that.

=
programming_language *Languages::find(ls_web *W, text_stream *language_name) {
	if (Str::eq_insensitive(language_name, I"Inform6")) language_name = I"Inform 6";
	if (Str::eq_insensitive(language_name, I"Inform")) language_name = I"Inform 7";
	if (Str::eq_insensitive(language_name, I"Inform7")) language_name = I"Inform 7";
	wcl_declaration *D = W?(W->declaration):NULL;
	wcl_declaration *X = WCL::resolve_resource(D, LANGUAGE_WCLTYPE, language_name);
	if (X == NULL) return NULL;
	programming_language *pl = RETRIEVE_POINTER_programming_language(X->object_declared);
	return pl;
}

programming_language *Languages::find_without_context(text_stream *language_name) {
	return Languages::find(NULL, language_name);
}

programming_language *Languages::find_or_fail(ls_web *W, text_stream *language_name) {
	programming_language *pl = Languages::find(W, language_name);
	if (pl == NULL) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "web needs a language called '%S', but I can't find any declaration of this",
			language_name);
		if (W) WCL::error(W->declaration, &(W->declaration->declaration_position), msg);
		else Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
		return NULL;
	}
	return pl;
}

@ Here we take a guess from a filename in the form |leaf.language.notation|:

=
programming_language *Languages::guess_from_filename(ls_web *W, filename *F) {
	if ((F == NULL) || (W->single_file == NULL)) return NULL;
	TEMPORARY_TEXT(extension)
	Filenames::write_penultimate_extension(extension, F);
//	PRINT("Guessing L from '%S' (%f)\n", extension, F);

	programming_language *result = NULL;
	linked_list *L = WCL::list_resources(W?(W->declaration):NULL, LANGUAGE_WCLTYPE, NULL);
	wcl_declaration *D;
	LOOP_OVER_LINKED_LIST(D, wcl_declaration, L) {
		programming_language *pl = RETRIEVE_POINTER_programming_language(D->object_declared);
		text_stream *ext;
		LOOP_OVER_LINKED_LIST(ext, text_stream, pl->recognised_filename_extensions)
			if (Str::eq_insensitive(ext, extension)) {
				result = pl;
				goto DoubleBreak;
			}
	}	
	DoubleBreak: ;
	DISCARD_TEXT(extension)
	return result;
}

@ We support multiple file extensions, but the first is preferred:

=
text_stream *Languages::canonical_file_extension(programming_language *pl) {
	text_stream *ext;
	LOOP_OVER_LINKED_LIST(ext, text_stream, pl->recognised_filename_extensions)
		return ext;
	return NULL;
}

@ Once initially read in, language declarations are parsed into the following
structure (one per language):

=
typedef struct programming_language {
	struct wcl_declaration *declaration;
	text_stream *language_name; /* identifies it: see above */
	
	/* then a great many fields set directly in the definition file: */
	linked_list *recognised_filename_extensions; /* of |text_stream| */
	text_stream *language_details; /* brief explanation of what language is */
	int supports_namespaces;
	text_stream *line_comment;
	text_stream *whole_line_comment;
	text_stream *multiline_comment_open;
	text_stream *multiline_comment_close;
	text_stream *string_literal;
	text_stream *string_literal_escape;
	text_stream *character_literal;
	text_stream *character_literal_escape;
	text_stream *binary_literal_prefix;
	text_stream *octal_literal_prefix;
	text_stream *hexadecimal_literal_prefix;
	text_stream *negative_literal_prefix;
	text_stream *shebang;
	text_stream *line_marker;
	text_stream *before_holon_expansion;
	text_stream *after_holon_expansion;
	int indent_holon_expansion;
	text_stream *start_definition;
	text_stream *prolong_definition;
	text_stream *end_definition;
	text_stream *start_ifdef;
	text_stream *end_ifdef;
	text_stream *start_ifndef;
	text_stream *end_ifndef;
	inchar32_t type_notation[MAX_ILDF_REGEXP_LENGTH];
	inchar32_t function_notation[MAX_ILDF_REGEXP_LENGTH];

	int suppress_disclaimer;
	int C_like; /* languages with this set have access to extra features */

	struct linked_list *reserved_words; /* of |reserved_word| */
	struct hash_table built_in_keywords;
	struct colouring_language_block *program; /* algorithm for syntax colouring */
	struct method_set *methods;
	CLASS_DEFINITION
} programming_language;

@ This is a simple one-pass compiler. The |language_reader_state| provides
the only state preserved as we work through line by line, except of course
that we are also working on the programming language it is |defining|. The
|current_block| is the braced block of colouring instructions we are
currently inside.

=
typedef struct language_reader_state {
	struct wcl_declaration *D;
	struct programming_language *defining;
	struct colouring_language_block *current_block;
} language_reader_state;


void Languages::error(language_reader_state *state, text_stream *msg, text_file_position *tfp) {
	WCL::error(state->D, tfp, msg);
}

programming_language *Languages::parse_declaration(wcl_declaration *D) {
	programming_language *pl = CREATE(programming_language);
	@<Initialise the language to a plain-text state@>;
	language_reader_state lrs;
	lrs.D = D;
	lrs.defining = pl;
	lrs.current_block = NULL;
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		Languages::read_definition_line(line, &tfp, (void *) &lrs);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	D->object_declared = STORE_POINTER_programming_language(pl);
	if (Str::len(pl->language_name) == 0)
		pl->language_name = Str::duplicate(D->name);
	else if (WCL::check_name(D, pl->language_name) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "language has two different names, '%S' and '%S'",
			D->name, pl->language_name);
		WCL::error(D, &(D->declaration_position), msg);
		DISCARD_TEXT(msg)
	}
	/* This must be done last, because it depends on the naming: */
	@<Add method calls to the language@>;
	return pl;
}

void Languages::resolve_declaration(wcl_declaration *D) {
	Conventions::set_level(D, LANGUAGE_LSCONVENTIONLEVEL);
}

@<Initialise the language to a plain-text state@> =
	pl->declaration = D;
	pl->language_name = NULL;
	pl->recognised_filename_extensions = NEW_LINKED_LIST(text_stream);
	pl->supports_namespaces = FALSE;
	pl->line_comment = NULL;
	pl->whole_line_comment = NULL;
	pl->multiline_comment_open = NULL;
	pl->multiline_comment_close = NULL;
	pl->string_literal = NULL;
	pl->string_literal_escape = NULL;
	pl->character_literal = NULL;
	pl->character_literal_escape = NULL;
	pl->binary_literal_prefix = NULL;
	pl->octal_literal_prefix = NULL;
	pl->hexadecimal_literal_prefix = NULL;
	pl->negative_literal_prefix = NULL;
	pl->shebang = NULL;
	pl->line_marker = NULL;
	pl->before_holon_expansion = NULL;
	pl->indent_holon_expansion = FALSE;
	pl->after_holon_expansion = NULL;
	pl->start_definition = NULL;
	pl->prolong_definition = NULL;
	pl->end_definition = NULL;
	pl->start_ifdef = NULL;
	pl->end_ifdef = NULL;
	pl->start_ifndef = NULL;
	pl->end_ifndef = NULL;
	pl->C_like = FALSE;
	pl->suppress_disclaimer = FALSE;
	pl->type_notation[0] = 0;
	pl->function_notation[0] = 0;

	pl->reserved_words = NEW_LINKED_LIST(reserved_word);
	ReservedWords::initialise_hash_table(&(pl->built_in_keywords));
	pl->program = NULL;
	pl->methods = Methods::new_set();

@ Note that there are two levels of extra privilege: any language calling
itself C-like has functionality for function and structure definitions;
the language whose name is InC gets even more, without having to ask.

Languages have effect through their method calls, which is how those
extra features are provided. The call to |ACMESupport::add_fallbacks|
adds generic method calls to give effect to the settings in the definition.

@<Add method calls to the language@> =
	if (pl->C_like) CLike::make_c_like(pl);
	if (Str::eq(pl->language_name, I"InC")) InCSupport::add_features(pl);
	ACMESupport::add_fallbacks(pl);

@ So, then, the above reads the file and feeds it line by line to this:

=
void Languages::read_definition_line(text_stream *line, text_file_position *tfp, void *v_state) {
	language_reader_state *state = (language_reader_state *) v_state;
	programming_language *pl = state->defining;

	Str::trim_white_space(line); /* ignore trailing space */
	if (Str::len(line) == 0) return; /* ignore blank lines */
	if (Str::get_first_char(line) == '#') return; /* lines opening with |#| are comments */

	match_results mr = Regexp::create_mr();
	if (state->current_block) @<Syntax inside a colouring program@>
	else @<Syntax outside a colouring program@>;
	Regexp::dispose_of(&mr);
}

@ Outside a colouring program, you can do three things: start a program,
declare a reserved keyword, or set a key to a value.

@<Syntax outside a colouring program@> =
	if (Regexp::match(&mr, line, U"colouring {")) {
		if (pl->program) Languages::error(state, I"duplicate colouring program", tfp);
		pl->program = Languages::new_block(NULL, WHOLE_LINE_CRULE_RUN);
		state->current_block = pl->program;
	} else if (Regexp::match(&mr, line, U"keyword (%C+) of (%c+?)")) {
		Languages::reserved(state, pl, Languages::text(state, mr.exp[0], tfp, FALSE), Languages::colour(state, mr.exp[1], tfp), tfp);
	} else if (Regexp::match(&mr, line, U"keyword (%C+)")) {
		Languages::reserved(state, pl, Languages::text(state, mr.exp[0], tfp, FALSE), RESERVED_COLOUR, tfp);
	} else if (Regexp::match(&mr, line, U"(%c+) *: *(%c+?)")) {
		text_stream *key = mr.exp[0], *value = Str::duplicate(mr.exp[1]);
		if (Str::eq(key, I"Name")) pl->language_name = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Details"))
			pl->language_details = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Extension")) {
			text_stream *ext = Languages::text(state, value, tfp, TRUE);
			ADD_TO_LINKED_LIST(ext, text_stream, pl->recognised_filename_extensions);
		}
		else if (Str::eq(key, I"Line Comment"))
			pl->line_comment = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Whole Line Comment"))
			pl->whole_line_comment = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Multiline Comment Open"))
			pl->multiline_comment_open = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Multiline Comment Close"))
			pl->multiline_comment_close = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"String Literal"))
			pl->string_literal = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"String Literal Escape"))
			pl->string_literal_escape = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Character Literal"))
			pl->character_literal = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Character Literal Escape"))
			pl->character_literal_escape = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Binary Literal Prefix"))
			pl->binary_literal_prefix = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Octal Literal Prefix"))
			pl->octal_literal_prefix = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Hexadecimal Literal Prefix"))
			pl->hexadecimal_literal_prefix = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Negative Literal Prefix"))
			pl->negative_literal_prefix = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Shebang"))
			pl->shebang = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Line Marker"))
			pl->line_marker = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Before Named Paragraph Expansion"))
			pl->before_holon_expansion = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Indent Named Paragraph Expansion"))
			pl->indent_holon_expansion = Languages::boolean(state, value, tfp);
		else if (Str::eq(key, I"After Named Paragraph Expansion"))
			pl->after_holon_expansion = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Start Definition"))
			pl->start_definition = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Prolong Definition"))
			pl->prolong_definition = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"End Definition"))
			pl->end_definition = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Start Ifdef"))
			pl->start_ifdef = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"Start Ifndef"))
			pl->start_ifndef = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"End Ifdef"))
			pl->end_ifdef = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"End Ifndef"))
			pl->end_ifndef = Languages::text(state, value, tfp, TRUE);
		else if (Str::eq(key, I"C-Like"))
			pl->C_like = Languages::boolean(state, value, tfp);
		else if (Str::eq(key, I"Suppress Disclaimer"))
			pl->suppress_disclaimer = Languages::boolean(state, value, tfp);
		else if (Str::eq(key, I"Supports Namespaces"))
			pl->supports_namespaces = Languages::boolean(state, value, tfp);
		else if (Str::eq(key, I"Function Declaration Notation"))
			Languages::regexp(state, pl->function_notation, value, tfp);
		else if (Str::eq(key, I"Type Declaration Notation"))
			Languages::regexp(state, pl->type_notation, value, tfp);
		else {
			Languages::error(state, I"unknown property name before ':'", tfp);
		}
	} else {
		Languages::error(state, I"line in language definition illegible", tfp);
	}

@ Inside a colouring program, you can close the current block (which may be
the entire program), open a new block to apply to each character or to
runs of a given colour, or give an if-X-then-Y rule:

@<Syntax inside a colouring program@> =
	if (Str::eq(line, I"}")) {
		state->current_block = state->current_block->parent;
	} else if (Regexp::match(&mr, line, U"characters {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block =
			Languages::new_block(state->current_block, CHARACTERS_CRULE_RUN);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, U"characters in (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block =
			Languages::new_block(state->current_block, CHARACTERS_IN_CRULE_RUN);
		rule->execute_block->char_set = Languages::text(state, mr.exp[0], tfp, FALSE);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, U"runs of (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		inchar32_t r = UNQUOTED_COLOUR;
		if (Str::ne(mr.exp[0], I"unquoted")) r = Languages::colour(state, mr.exp[0], tfp);
		rule->execute_block = Languages::new_block(state->current_block, (int) r);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, U"instances of (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block = Languages::new_block(state->current_block, INSTANCES_CRULE_RUN);
		rule->execute_block->run_instance = Languages::text(state, mr.exp[0], tfp, FALSE);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, U"matches of (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block = Languages::new_block(state->current_block, MATCHES_CRULE_RUN);
		Languages::regexp(state, rule->execute_block->match_regexp_text, mr.exp[0], tfp);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, U"brackets in (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block = Languages::new_block(state->current_block, BRACKETS_CRULE_RUN);
		Languages::regexp(state, rule->execute_block->match_regexp_text, mr.exp[0], tfp);
		state->current_block = rule->execute_block;
	} else {
		int at = -1, quoted = FALSE;
		for (int i=0; i<Str::len(line)-1; i++) {
			if (Str::get_at(line, i) == '"') quoted = quoted?FALSE:TRUE;
			if ((quoted) && (Str::get_at(line, i) == '\\')) i++;
			if ((quoted == FALSE) &&
				(Str::get_at(line, i) == '=') && (Str::get_at(line, i+1) == '>')) at = i;
		}
		if (at >= 0) {
			TEMPORARY_TEXT(premiss)
			TEMPORARY_TEXT(conclusion)
			Str::substr(premiss, Str::start(line), Str::at(line, at));
			Str::substr(conclusion, Str::at(line, at+2), Str::end(line));
			Languages::parse_rule(state, premiss, conclusion, tfp);
			DISCARD_TEXT(conclusion)
			DISCARD_TEXT(premiss)
		} else {
			Languages::error(state, I"line in colouring block illegible", tfp);
		}
	}

@h Blocks.
These are code blocks of colouring instructions. A block whose |parent| is |NULL|
represents a complete program.

@d WHOLE_LINE_CRULE_RUN -1 /* This block applies to the whole snippet being coloured */
@d CHARACTERS_CRULE_RUN -2 /* This block applies to each character in turn */
@d CHARACTERS_IN_CRULE_RUN -3 /* This block applies to each character from a set in turn */
@d INSTANCES_CRULE_RUN -4 /* This block applies to each instance in turn */
@d MATCHES_CRULE_RUN -5 /* This block applies to each match against a regexp in turn */
@d BRACKETS_CRULE_RUN -6 /* This block applies to bracketed subexpressions in a regexp */

=
typedef struct colouring_language_block {
	struct linked_list *rules; /* of |colouring_rule| */
	struct colouring_language_block *parent; /* or |NULL| for the topmost one */
	int run; /* one of the |*_CRULE_RUN| values, or else a colour */
	struct text_stream *run_instance; /* used only for |INSTANCES_CRULE_RUN| */
	struct text_stream *char_set; /* used only for |CHARACTERS_IN_CRULE_RUN| */
	inchar32_t match_regexp_text[MAX_ILDF_REGEXP_LENGTH]; /* used for |MATCHES_CRULE_RUN|, |BRACKETS_CRULE_RUN| */
	
	/* workspace during painting */
	struct match_results mr; /* of a regular expression */
	CLASS_DEFINITION
} colouring_language_block;

@ =
colouring_language_block *Languages::new_block(colouring_language_block *within, int r) {
	colouring_language_block *block = CREATE(colouring_language_block);
	block->rules = NEW_LINKED_LIST(colouring_rule);
	block->parent = within;
	block->run = r;
	block->run_instance = NULL;
	block->char_set = NULL;
	block->match_regexp_text[0] = 0;
	block->mr = Regexp::create_mr();
	return block;
}

@h Colouring Rules.
Each individual rule has the form: if a premiss, then a conclusion. It will be
applied to a snippet of text, and the premiss can test that, together with a
little context before it (where available).

Note that rules can be unconditional, in that the premiss always passes.

@d NOT_A_RULE_PREFIX 1 /* this isn't a prefix rule */
@d UNSPACED_RULE_PREFIX 2 /* for |prefix P| */
@d SPACED_RULE_PREFIX 3 /* for |spaced prefix P| */
@d OPTIONALLY_SPACED_RULE_PREFIX 4 /* for |optionally spaced prefix P| */
@d UNSPACED_RULE_SUFFIX 5 /* for |suffix P| */
@d SPACED_RULE_SUFFIX 6 /* for |spaced suffix P| */
@d OPTIONALLY_SPACED_RULE_SUFFIX 7 /* for |optionally spaced suffix P| */

@d MAX_ILDF_REGEXP_LENGTH 64

=
typedef struct colouring_rule {
	/* the premiss: */
	int sense; /* |FALSE| to negate the condition */
	inchar32_t match_colour; /* for |coloured C|, or else |NOT_A_COLOUR| */
	inchar32_t match_keyword_of_colour; /* for |keyword C|, or else |NOT_A_COLOUR| */
	struct text_stream *match_text; /* or length 0 to mean "anything" */
	int match_prefix; /* one of the |*_RULE_PREFIX| values above */
	inchar32_t match_regexp_text[MAX_ILDF_REGEXP_LENGTH];
	int number; /* for |number N| rules; 0 for others */
	int number_of; /* for |number N of M| rules; 0 for others */

	/* the conclusion: */
	struct colouring_language_block *execute_block; /* or |NULL|, in which case... */
	inchar32_t set_to_colour; /* ...paint the snippet in this colour */
	inchar32_t set_prefix_to_colour; /* ...also paint this (same for suffix) */
	int debug; /* ...or print debugging text to console */
	
	/* workspace during painting */
	int fix_position; /* where the prefix or suffix started */
	struct match_results mr; /* of a regular expression */
	CLASS_DEFINITION
} colouring_rule;

@ =
colouring_rule *Languages::new_rule(colouring_language_block *within) {
	if (within == NULL) internal_error("rule outside block");
	colouring_rule *rule = CREATE(colouring_rule);
	ADD_TO_LINKED_LIST(rule, colouring_rule, within->rules);
	rule->sense = TRUE;
	rule->match_colour = NOT_A_COLOUR;
	rule->match_text = NULL;
	rule->match_prefix = NOT_A_RULE_PREFIX;
	rule->match_keyword_of_colour = NOT_A_COLOUR;
	rule->match_regexp_text[0] = 0;
	rule->number = 0;
	rule->number_of = 0;

	rule->set_to_colour = NOT_A_COLOUR;
	rule->set_prefix_to_colour = NOT_A_COLOUR;
	rule->execute_block = NULL;
	rule->debug = FALSE;
	
	rule->fix_position = 0;
	rule->mr = Regexp::create_mr();
	return rule;
}

@ =
void Languages::parse_rule(language_reader_state *state, text_stream *premiss,
	text_stream *action, text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	colouring_rule *rule = Languages::new_rule(state->current_block);
	Str::trim_white_space(premiss); Str::trim_white_space(action);
	@<Parse the premiss@>;
	@<Parse the conclusion@>;
	Regexp::dispose_of(&mr);
}

@<Parse the premiss@> =
	while (Regexp::match(&mr, premiss, U"not (%c+)")) {
		rule->sense = (rule->sense)?FALSE:TRUE;
		Str::clear(premiss); Str::copy(premiss, mr.exp[0]);
	}
	if (Regexp::match(&mr, premiss, U"number (%d+)")) {
		rule->number = Str::atoi(mr.exp[0], 0);
	} else if (Regexp::match(&mr, premiss, U"number (%d+) of (%d+)")) {
		rule->number = Str::atoi(mr.exp[0], 0);
		rule->number_of = Str::atoi(mr.exp[1], 0);
	} else if (Regexp::match(&mr, premiss, U"keyword of (%c+)")) {
		rule->match_keyword_of_colour = Languages::colour(state, mr.exp[0], tfp);
	} else if (Regexp::match(&mr, premiss, U"keyword")) {
		Languages::error(state, I"ambiguous: make it keyword of !reserved or quote keyword", tfp);
	} else if (Regexp::match(&mr, premiss, U"prefix (%c+)")) {
		rule->match_prefix = UNSPACED_RULE_PREFIX;
		rule->match_text = Languages::text(state, mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, U"matching (%c+)")) {
		Languages::regexp(state, rule->match_regexp_text, mr.exp[0], tfp);
	} else if (Regexp::match(&mr, premiss, U"spaced prefix (%c+)")) {
		rule->match_prefix = SPACED_RULE_PREFIX;
		rule->match_text = Languages::text(state, mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, U"optionally spaced prefix (%c+)")) {
		rule->match_prefix = OPTIONALLY_SPACED_RULE_PREFIX;
		rule->match_text = Languages::text(state, mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, U"suffix (%c+)")) {
		rule->match_prefix = UNSPACED_RULE_SUFFIX;
		rule->match_text = Languages::text(state, mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, U"spaced suffix (%c+)")) {
		rule->match_prefix = SPACED_RULE_SUFFIX;
		rule->match_text = Languages::text(state, mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, U"optionally spaced suffix (%c+)")) {
		rule->match_prefix = OPTIONALLY_SPACED_RULE_SUFFIX;
		rule->match_text = Languages::text(state, mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, U"coloured (%c+)")) {
		rule->match_colour = Languages::colour(state, mr.exp[0], tfp);
	} else if (Str::len(premiss) > 0) {
		rule->match_text = Languages::text(state, premiss, tfp, FALSE);
	}

@<Parse the conclusion@> =
	if (Str::eq(action, I"{")) {
		rule->execute_block =
			Languages::new_block(state->current_block, WHOLE_LINE_CRULE_RUN);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, action, U"(!%c+) on prefix")) {
		rule->set_prefix_to_colour = Languages::colour(state, mr.exp[0], tfp);
	} else if (Regexp::match(&mr, action, U"(!%c+) on suffix")) {
		rule->set_prefix_to_colour = Languages::colour(state, mr.exp[0], tfp);
	} else if (Regexp::match(&mr, action, U"(!%c+) on both")) {
		rule->set_to_colour = Languages::colour(state, mr.exp[0], tfp);
		rule->set_prefix_to_colour = rule->set_to_colour;
	} else if (Str::get_first_char(action) == '!') {
		rule->set_to_colour = Languages::colour(state, action, tfp);
	} else if (Str::eq(action, I"debug")) {
		rule->debug = TRUE;
	} else {
		Languages::error(state, I"action after '=>' illegible", tfp);
	}

@h Reserved words.
Note that these can come in any colour, though usually it's |!reserved|.

=
typedef struct reserved_word {
	struct text_stream *word;
	int colour;
	CLASS_DEFINITION
} reserved_word;

reserved_word *Languages::reserved(language_reader_state *state,
	programming_language *pl, text_stream *W, inchar32_t C,
	text_file_position *tfp) {
	reserved_word *rw;
	LOOP_OVER_LINKED_LIST(rw, reserved_word, pl->reserved_words)
		if (Str::eq(rw->word, W)) {
			Languages::error(state, I"duplicate reserved word", tfp);
		}
	rw = CREATE(reserved_word);
	rw->word = Str::duplicate(W);
	rw->colour = (int) C;
	ADD_TO_LINKED_LIST(rw, reserved_word, pl->reserved_words);
	ReservedWords::mark_reserved_word(&(pl->built_in_keywords), rw->word, (int) C);
	return rw;
}

@h Expressions.
Language definition files have three types of data: colours, booleans, and
text. Colours first. Note that there are two pseudo-colours used above,
but which are not expressible in the syntax of this file.

@d DEFINITION_COLOUR 	'd'
@d FUNCTION_COLOUR		'f'
@d RESERVED_COLOUR		'r'
@d ELEMENT_COLOUR		'e'
@d IDENTIFIER_COLOUR	'i'
@d CHARACTER_COLOUR     'c'
@d CONSTANT_COLOUR		'n'
@d STRING_COLOUR		's'
@d PLAIN_COLOUR			'p'
@d EXTRACT_COLOUR		'x'
@d HEADING_COLOUR		'h'
@d COMMENT_COLOUR		'!'
@d NEWLINE_COLOUR		'\n'

@d NOT_A_COLOUR ' '
@d UNQUOTED_COLOUR '_'

=
inchar32_t Languages::colour(language_reader_state *state, text_stream *T, text_file_position *tfp) {
	if (Str::get_first_char(T) != '!') {
		Languages::error(state, I"colour names must begin with !", tfp);
		return PLAIN_COLOUR;
	}
	if (Str::eq(T, I"!string")) return STRING_COLOUR;
	else if (Str::eq(T, I"!function")) return FUNCTION_COLOUR;
	else if (Str::eq(T, I"!definition")) return DEFINITION_COLOUR;
	else if (Str::eq(T, I"!reserved")) return RESERVED_COLOUR;
	else if (Str::eq(T, I"!element")) return ELEMENT_COLOUR;
	else if (Str::eq(T, I"!identifier")) return IDENTIFIER_COLOUR;
	else if (Str::eq(T, I"!character")) return CHARACTER_COLOUR;
	else if (Str::eq(T, I"!constant")) return CONSTANT_COLOUR;
	else if (Str::eq(T, I"!plain")) return PLAIN_COLOUR;
	else if (Str::eq(T, I"!extract")) return EXTRACT_COLOUR;
	else if (Str::eq(T, I"!heading")) return HEADING_COLOUR;
	else if (Str::eq(T, I"!comment")) return COMMENT_COLOUR;
	else {
		Languages::error(state, I"no such !colour", tfp);
		return PLAIN_COLOUR;
	}
}

text_stream *Languages::colour_classname(inchar32_t col) {
	text_stream *span_class = NULL;
	switch (col) {
		case DEFINITION_COLOUR: span_class = I"syntaxdefinition"; break;
		case FUNCTION_COLOUR:   span_class = I"syntaxfunction"; break;
		case RESERVED_COLOUR:   span_class = I"syntaxreserved"; break;
		case ELEMENT_COLOUR:    span_class = I"syntaxelement"; break;
		case IDENTIFIER_COLOUR: span_class = I"syntaxidentifier"; break;
		case HEADING_COLOUR:    span_class = I"syntaxheading"; break;
		case CHARACTER_COLOUR:  span_class = I"syntaxcharacter"; break;
		case CONSTANT_COLOUR:   span_class = I"syntaxconstant"; break;
		case STRING_COLOUR:     span_class = I"syntaxstring"; break;
		case PLAIN_COLOUR:      span_class = I"syntaxplain"; break;
		case EXTRACT_COLOUR:    span_class = I"syntaxextract"; break;
		case COMMENT_COLOUR:    span_class = I"syntaxcomment"; break;
	}
	return span_class;
}

@ A boolean must be written as |true| or |false|.

=
int Languages::boolean(language_reader_state *state, text_stream *T, text_file_position *tfp) {
	if (Str::eq(T, I"true")) return TRUE;
	else if (Str::eq(T, I"false")) return FALSE;
	else {
		Languages::error(state, I"must be true or false", tfp);
		return FALSE;
	}
}

@ In text, |\n| represents a newline, |\s| a space and |\t| a tab. Spaces
can be given in the ordinary way inside a text in any case. |\\| is a
literal backslash.

=
text_stream *Languages::text(language_reader_state *state, text_stream *T, text_file_position *tfp, int allow) {
	text_stream *V = Str::new();
	if (Str::len(T) > 0) {
		int bareword = TRUE, spaced = FALSE, from = 0, to = Str::len(T)-1;
		if ((to > from) &&
			(Str::get_at(T, from) == '"') && (Str::get_at(T, to) == '"')) {
			bareword = FALSE; from++; to--;
		}
		for (int i=from; i<=to; i++) {
			inchar32_t c = Str::get_at(T, i);
			if (c == ' ') spaced = TRUE;
			if ((c == '\\') && (Str::get_at(T, i+1) == 'n')) {
				PUT_TO(V, '\n');
				i++;
			} else if ((c == '\\') && (Str::get_at(T, i+1) == 's')) {
				PUT_TO(V, ' ');
				i++;
			} else if ((c == '\\') && (Str::get_at(T, i+1) == 't')) {
				PUT_TO(V, '\t');
				i++;
			} else if ((c == '\\') && (Str::get_at(T, i+1) == '\\')) {
				PUT_TO(V, '\\');
				i++;
			} else if ((bareword == FALSE) && (c == '\\') && (Str::get_at(T, i+1) == '"')) {
				PUT_TO(V, '"');
				i++;
			} else if ((bareword == FALSE) && (c == '"')) {
				Languages::error(state,
					I"backslash needed before internal double-quotation mark", tfp);
			} else if ((bareword) && (c == '!') && (i == from)) {
				Languages::error(state,
					I"a literal starting with ! must be in double-quotation marks", tfp);
			} else if ((bareword) && (c == '/')) {
				Languages::error(state,
					I"forward slashes can only be used in quoted strings", tfp);
			} else if ((bareword) && (c == '"')) {
				Languages::error(state,
					I"double-quotation marks can only be used in quoted strings", tfp);
			} else {
				PUT_TO(V, c);
			}
		}
		if ((bareword) && (spaced) && (allow == FALSE)) {
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "'%S' seems to be literal text, but if so it needs double-quotation marks", T);
			Errors::in_text_file_S(err, tfp);
			DISCARD_TEXT(err)			
		}
		if (bareword) {
			int rw = FALSE;
			if (Str::eq(V, I"both")) rw = TRUE;
			if (Str::eq(V, I"brackets")) rw = TRUE;
			if (Str::eq(V, I"characters")) rw = TRUE;
			if (Str::eq(V, I"coloured")) rw = TRUE;
			if (Str::eq(V, I"colouring")) rw = TRUE;
			if (Str::eq(V, I"debug")) rw = TRUE;
			if (Str::eq(V, I"false")) rw = TRUE;
			if (Str::eq(V, I"in")) rw = TRUE;
			if (Str::eq(V, I"instances")) rw = TRUE;
			if (Str::eq(V, I"keyword")) rw = TRUE;
			if (Str::eq(V, I"matches")) rw = TRUE;
			if (Str::eq(V, I"matching")) rw = TRUE;
			if (Str::eq(V, I"not")) rw = TRUE;
			if (Str::eq(V, I"of")) rw = TRUE;
			if (Str::eq(V, I"on")) rw = TRUE;
			if (Str::eq(V, I"optionally")) rw = TRUE;
			if (Str::eq(V, I"prefix")) rw = TRUE;
			if (Str::eq(V, I"runs")) rw = TRUE;
			if (Str::eq(V, I"spaced")) rw = TRUE;
			if (Str::eq(V, I"suffix")) rw = TRUE;
			if (Str::eq(V, I"true")) rw = TRUE;
			if (Str::eq(V, I"unquoted")) rw = TRUE;

			if (rw) {
				TEMPORARY_TEXT(err)
				WRITE_TO(err, "'%S' is a reserved word, so you should put it in double-quotation marks", V);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err)			
			}
		}
	}
	return V;
}

@ And regular expressions.

=
void Languages::regexp(language_reader_state *state, inchar32_t *write_to, text_stream *T, text_file_position *tfp) {
	if (write_to == NULL) internal_error("no buffer");
	write_to[0] = 0;
	if (Str::len(T) > 0) {
		int from = 0, to = Str::len(T)-1, x = 0;
		if ((to > from) &&
			(Str::get_at(T, from) == '/') && (Str::get_at(T, to) == '/')) {
			from++; to--;
			for (int i=from; i<=to; i++) {
				inchar32_t c = Str::get_at(T, i);
				if (c == '\\') {
					inchar32_t w = Str::get_at(T, i+1);
					if (w == '\\') {
						x = Languages::add_to_regexp(write_to, x, w);
					} else if (w == 'a') {
						x = Languages::add_escape_to_regexp(write_to, x, 'a');
					} else if (w == 'z') {
						x = Languages::add_escape_to_regexp(write_to, x, 'z');
					} else if (w == 'd') {
						x = Languages::add_escape_to_regexp(write_to, x, 'd');
					} else if (w == 't') {
						x = Languages::add_escape_to_regexp(write_to, x, 't');
					} else if (w == 'r') {
						x = Languages::add_escape_to_regexp(write_to, x, 'r');
					} else if (w == 's') {
						x = Languages::add_to_regexp(write_to, x, ' ');
					} else if (w == 'S') {
						x = Languages::add_escape_to_regexp(write_to, x, 'C');
					} else if (w == '"') {
						x = Languages::add_escape_to_regexp(write_to, x, 'q');
					} else {
						x = Languages::add_escape_to_regexp(write_to, x, w);
					}
					i++;
					continue;
				}
				if (c == '.') {
					x = Languages::add_escape_to_regexp(write_to, x, 'c');
					continue;
				}
				if (c == '%') {
					x = Languages::add_escape_to_regexp(write_to, x, '%');
					continue;
				}
				x = Languages::add_to_regexp(write_to, x, c);
			}
		} else {
			Languages::error(state,
				I"the expression to match must be in slashes '/'", tfp);
		}
		if (x >= MAX_ILDF_REGEXP_LENGTH)
			Languages::error(state,
				I"the expression to match is too long", tfp);
	}
}

int Languages::add_to_regexp(inchar32_t *write_to, int i, inchar32_t c) {
	if (i < MAX_ILDF_REGEXP_LENGTH) write_to[i++] = c;
	return i;
}

int Languages::add_escape_to_regexp(inchar32_t *write_to, int i, inchar32_t c) {
	i = Languages::add_to_regexp(write_to, i, '%');
	i = Languages::add_to_regexp(write_to, i, c);
	return i;
}
