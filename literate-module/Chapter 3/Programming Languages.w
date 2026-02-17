[Languages::] Programming Languages.

Defining the programming languages supported by our LP system, loading in their
definitions from files.

@ Each different programming language is represented by an instance of
|programming_language|. Some webs specify their language by name, and others
imply it with filename extensions.

=
typedef struct programming_language {
	struct wcl_declaration *declaration;
	text_stream *language_name; /* identifies it */
	text_stream *language_details; /* brief explanation of what language is */
	
	linked_list *recognised_filename_extensions; /* of |text_stream| */

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
	text_stream *decimal_point_infix;
	text_stream *exponent_infix;
	text_stream *shebang;
	text_stream *line_marker;
	int indent_holon_expansion;
	text_stream *start_definition;
	text_stream *prolong_definition;
	text_stream *end_definition;
	text_stream *start_ifdef;
	text_stream *end_ifdef;
	text_stream *start_ifndef;
	text_stream *end_ifndef;

	struct pl_regexp_set *type_notation;
	struct pl_regexp_set *function_notation;

	int C_like; /* languages with this set have access to extra features */

	struct linked_list *reserved_words; /* of |reserved_word| */
	struct hash_table built_in_keywords;
	struct colouring_language_block *program; /* algorithm for syntax colouring */
	struct linked_list *custom_colours; /* of |custom_colour| */
	struct method_set *methods;
	CLASS_DEFINITION
} programming_language;

programming_language *Languages::new(void) {
	programming_language *pl = CREATE(programming_language);
	pl->declaration = NULL;
	pl->language_name = NULL;
	pl->language_details = NULL;

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
	pl->decimal_point_infix = NULL;
	pl->exponent_infix = NULL;
	pl->shebang = NULL;
	pl->line_marker = NULL;
	pl->indent_holon_expansion = FALSE;
	pl->start_definition = NULL;
	pl->prolong_definition = NULL;
	pl->end_definition = NULL;
	pl->start_ifdef = NULL;
	pl->end_ifdef = NULL;
	pl->start_ifndef = NULL;
	pl->end_ifndef = NULL;
	pl->C_like = FALSE;
	pl->type_notation = Languages::new_regexp_set();
	pl->function_notation = Languages::new_regexp_set();

	pl->reserved_words = NEW_LINKED_LIST(reserved_word);
	ReservedWords::initialise_hash_table(&(pl->built_in_keywords));
	pl->custom_colours = NEW_LINKED_LIST(custom_colour);
	pl->program = NULL;
	pl->methods = Methods::new_set();
	return pl;
}

@h Identification.
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

@ A little crudely, this writes out what we have in memory, sorted alphabetically
for tidiness:

=
void Languages::show(OUTPUT_STREAM, ls_web *W) {
	WRITE("I can see the following programming language definitions:\n\n");
	WCL::write_sorted_list_of_resources(OUT, W, LANGUAGE_WCLTYPE);
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

@h Reading language definitions.
We can read in a whole directory of these...

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

@ ...or just a single file:

=
programming_language *Languages::read_definition(filename *F) {
	wcl_declaration *D = WCL::read_just_one(F, LANGUAGE_WCLTYPE);
	if (D == NULL) return NULL;
	WCL::make_global(D);
	return RETRIEVE_POINTER_programming_language(D->object_declared);
}

@ And languages can also arise as resources nested inside other WCL resources,
such as webs or colonies. In all these cases, though, we end up having to
parse the lines of a WCL declaration, as follows.

=
programming_language *Languages::parse_declaration(wcl_declaration *D) {
	programming_language *pl = Languages::new();
	pl->declaration = D;
	D->object_declared = STORE_POINTER_programming_language(pl);
	@<Parse the declaration@>;
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

@ This is a simple one-pass compiler. The |language_reader_state| provides
the only state preserved as we work through line by line, except of course
that we are also working on the programming language it is |defining|. The
|current_block| is the braced block of colouring instructions we are
currently inside.

=
typedef struct language_reader_state {
	struct programming_language *defining;
	struct colouring_language_block *current_block;
	inchar32_t keywords_block_colour;
	int properties_block;
} language_reader_state;

void Languages::error(language_reader_state *state, text_stream *msg,
	text_file_position *tfp) {
	WCL::error(state->defining->declaration, tfp, msg);
}

@<Parse the declaration@> =
	language_reader_state lrs;
	lrs.defining = pl;
	lrs.current_block = NULL;
	lrs.keywords_block_colour = NOT_A_COLOUR;
	lrs.properties_block = FALSE;
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		Languages::read_definition_line(line, &tfp, (void *) &lrs);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	if (lrs.keywords_block_colour != NOT_A_COLOUR)
		Languages::error(&lrs, I"language definition ended in keywords list: 'end' line forgotten?", &tfp);
	if (lrs.current_block)
		Languages::error(&lrs, I"language definition ended in colouring: 'end' line forgotten?", &tfp);
	if (lrs.properties_block)
		Languages::error(&lrs, I"language definition ended in properties: 'end' line forgotten?", &tfp);

@ So, then, the above reads the file and feeds it line by line to this:

=
void Languages::read_definition_line(text_stream *line, text_file_position *tfp, void *v_state) {
	language_reader_state *state = (language_reader_state *) v_state;
	programming_language *pl = state->defining;

	Str::trim_white_space(line); /* ignore trailing space */
	if (Str::len(line) == 0) return; /* ignore blank lines */

	match_results mr = Regexp::create_mr();
	if (state->properties_block) @<Syntax in a properties block@>
	else if (state->keywords_block_colour != NOT_A_COLOUR) @<Syntax in a keywords block@>
	else if (state->current_block) @<Syntax in a colouring program@>
	else @<Top-level syntax@>;
	Regexp::dispose_of(&mr);
}

@ Outside a colouring program, you can do three things: start a program,
declare a reserved keyword, or set a key to a value.

@<Top-level syntax@> =
	if ((Str::eq(line, I"colouring")) || (Str::eq(line, I"coloring"))) {
		if (pl->program) Languages::error(state, I"duplicate colouring program", tfp);
		pl->program = Languages::new_block(NULL, WHOLE_LINE_CRULE_RUN);
		state->current_block = pl->program;
	} else if (Regexp::match(&mr, line, U"recognise (%C+)")) {
		text_stream *ext = Languages::text(state, mr.exp[0], tfp, TRUE);
		ADD_TO_LINKED_LIST(ext, text_stream, pl->recognised_filename_extensions);
	} else if (Regexp::match(&mr, line, U"colour (%C+) like (%C+)")) {
		if (Str::get_first_char(mr.exp[0]) != '!') {
			Languages::error(state, I"colour names must begin with !", tfp);
		} else {
			inchar32_t nc = Painter::colour(pl->custom_colours, mr.exp[0]);
			if (nc != NOT_A_COLOUR) {
				Languages::error(state, I"colour already exists", tfp);
			} else {
				inchar32_t oc = Languages::colour(state, mr.exp[1], tfp);
				custom_colour *cc = Painter::custom(mr.exp[0], oc, pl->custom_colours);
				if (cc->value == NOT_A_COLOUR)
					Languages::error(state, I"too many colours", tfp);
			}
		}
	} else if (Regexp::match(&mr, line, U"keywords")) {
		state->keywords_block_colour = RESERVED_COLOUR;
	} else if (Regexp::match(&mr, line, U"keywords of (%C+)")) {
		state->keywords_block_colour = Languages::colour(state, mr.exp[0], tfp);
	} else if (Str::eq(line, I"properties")) {
		state->properties_block = TRUE;
	} else if (Regexp::match(&mr, line, U"keyword (%C+) of (%c+?)")) {
		Languages::reserved(state, pl, Languages::text(state, mr.exp[0], tfp, FALSE),
			Languages::colour(state, mr.exp[1], tfp), tfp);
	} else if (Regexp::match(&mr, line, U"keyword (%C+)")) {
		Languages::reserved(state, pl, Languages::text(state, mr.exp[0], tfp, FALSE), RESERVED_COLOUR, tfp);
	} else {
		Languages::error(state, I"line in language definition illegible", tfp);
	}

@<Syntax in a properties block@> =
	if (Str::eq(line, I"end")) {
		state->properties_block = FALSE;
	} else if (Regexp::match(&mr, line, U"(%c+) *: *(%c+?)")) {
		text_stream *key = mr.exp[0], *value = Str::duplicate(mr.exp[1]);
		@<Set property@>;
	} else {
		Languages::error(state, I"lines in a properties block should have the form 'property: value'", tfp);
	}

@<Set property@> =
	if (Str::eq(key, I"Name")) pl->language_name = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Details"))
		pl->language_details = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Line Comment"))
		pl->line_comment = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Whole Line Comment"))
		pl->whole_line_comment = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Multiline Comment Open"))
		pl->multiline_comment_open = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Multiline Comment Close"))
		pl->multiline_comment_close = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"String Literal"))
		pl->string_literal = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"String Literal Escape"))
		pl->string_literal_escape = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Character Literal"))
		pl->character_literal = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Character Literal Escape"))
		pl->character_literal_escape = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Binary Literal Prefix"))
		pl->binary_literal_prefix = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Octal Literal Prefix"))
		pl->octal_literal_prefix = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Hexadecimal Literal Prefix"))
		pl->hexadecimal_literal_prefix = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Negative Literal Prefix"))
		pl->negative_literal_prefix = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Decimal Point Infix"))
		pl->decimal_point_infix = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Exponent Infix"))
		pl->exponent_infix = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Shebang"))
		pl->shebang = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Line Marker"))
		pl->line_marker = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Indent Named Holon Expansion"))
		pl->indent_holon_expansion = Languages::boolean(state, value, tfp);
	else if (Str::eq(key, I"Start Definition"))
		pl->start_definition = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Prolong Definition"))
		pl->prolong_definition = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"End Definition"))
		pl->end_definition = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Start Ifdef"))
		pl->start_ifdef = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"Start Ifndef"))
		pl->start_ifndef = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"End Ifdef"))
		pl->end_ifdef = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"End Ifndef"))
		pl->end_ifndef = Languages::text_oq(state, value, tfp);
	else if (Str::eq(key, I"C-Like"))
		pl->C_like = Languages::boolean(state, value, tfp);
	else if (Str::eq(key, I"Supports Namespaces"))
		pl->supports_namespaces = Languages::boolean(state, value, tfp);
	else if (Str::eq(key, I"Function Declaration"))
		Languages::regexp_to(state, pl->function_notation, value, tfp);
	else if (Str::eq(key, I"Type Declaration"))
		Languages::regexp_to(state, pl->type_notation, value, tfp);
	else {
		Languages::error(state, I"unknown property name before ':'", tfp);
	}

@ Inside a colouring program, you can close the current block (which may be
the entire program), open a new block to apply to each character or to
runs of a given colour, or give an if-X-then-Y rule:

@<Syntax in a colouring program@> =
	if (Str::eq(line, I"end")) {
		state->current_block = state->current_block->parent;
	} else if (Str::eq(line, I"}")) {
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
		Languages::regexp_to(state, rule->execute_block->match_regexp_text, mr.exp[0], tfp);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, U"brackets in (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block = Languages::new_block(state->current_block, BRACKETS_CRULE_RUN);
		Languages::regexp_to(state, rule->execute_block->match_regexp_text, mr.exp[0], tfp);
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

@<Syntax in a keywords block@> =
	if (Str::eq(line, I"end")) {
		state->keywords_block_colour = NOT_A_COLOUR;
	} else {
		TEMPORARY_TEXT(keywords)
		Str::copy(keywords, line);
		while (Regexp::match(&mr, keywords, U" *(%C+) *(%c*)")) {
			Str::clear(keywords);
			Str::copy(keywords, mr.exp[1]);
			Languages::reserved(state, pl, Languages::text(state, mr.exp[0], tfp, FALSE), 
				state->keywords_block_colour, tfp);
		}
	}

@ All WCL declarations are first parsed and then "resolved". There's actually
nothing to do at the resolution stage except to tell the conventions system
how important our choices are (relative to notations, webs, etc.):

=
void Languages::resolve_declaration(wcl_declaration *D) {
	Conventions::set_level(D, LANGUAGE_LSCONVENTIONLEVEL);
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
	struct pl_regexp_set *match_regexp_text; /* used for |MATCHES_CRULE_RUN|, |BRACKETS_CRULE_RUN| */
	
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
	block->match_regexp_text = Languages::new_regexp_set();
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

=
typedef struct colouring_rule {
	/* the premiss: */
	int sense; /* |FALSE| to negate the condition */
	inchar32_t match_colour; /* for |coloured C|, or else |NOT_A_COLOUR| */
	inchar32_t match_keyword_of_colour; /* for |keyword C|, or else |NOT_A_COLOUR| */
	struct text_stream *match_text; /* or length 0 to mean "anything" */
	int match_prefix; /* one of the |*_RULE_PREFIX| values above */
	struct pl_regexp_set *match_regexp_text;
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
	rule->match_regexp_text = Languages::new_regexp_set();
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
		Languages::regexp_to(state, rule->match_regexp_text, mr.exp[0], tfp);
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
	} else if (Regexp::match(&mr, premiss, U"colored (%c+)")) {
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
Note that these can come in any colour, though usually it's |RESERVED_COLOUR|.

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

@h Literal values in language declarations.
We will use have three types of data: colours, booleans, and text. Colour names
like |!constant| are those used by the Painter:

=
inchar32_t Languages::colour(language_reader_state *state, text_stream *T, text_file_position *tfp) {
	inchar32_t C = Painter::colour(state->defining->custom_colours, T);
	if (C == NOT_A_COLOUR) {
		if (Str::get_first_char(T) != '!')
			Languages::error(state, I"colour names must begin with !", tfp);
		else
			Languages::error(state, I"no such !colour", tfp);
		C = PLAIN_COLOUR;
	}
	return C;
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
text_stream *Languages::text_oq(language_reader_state *state, text_stream *T, text_file_position *tfp) {
	if ((Str::len(T) > 1) && (Str::get_first_char(T) == '"') && (Str::get_last_char(T) == '"'))
		return Languages::text(state, T, tfp, TRUE);
	return Str::duplicate(T);
}

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
	}
	return V;
}

@ And regular expressions.

@d MAX_ILDF_REGEXP_LENGTH 64

=
typedef struct pl_regexp_set {
	inchar32_t expression[MAX_ILDF_REGEXP_LENGTH + 1];
	struct pl_regexp_set *alternate;
	CLASS_DEFINITION
} pl_regexp_set;

pl_regexp_set *Languages::new_regexp_set(void) {
	pl_regexp_set *rs = CREATE(pl_regexp_set);
	rs->expression[0] = 0;
	rs->alternate = NULL;
	return rs;
}

int Languages::match_regexp_set(match_results *mr, text_stream *text, pl_regexp_set *rs) {
	while (rs) {
		if ((rs->expression[0]) && (Regexp::match(mr, text, rs->expression))) {
			return TRUE;
		}
		rs = rs->alternate;
	}
	return FALSE;
}

int Languages::match_regexp_set_from(match_results *mr, text_stream *text, pl_regexp_set *rs, int i) {
	while (rs) {
		if (rs->expression[0]) {
			int rv = Regexp::match_from(mr, text, rs->expression, i, TRUE);
			if (rv > 0) return rv;
		}
		rs = rs->alternate;
	}
	return 0;
}

int Languages::nonempty_regexp_set(pl_regexp_set *rs) {
	if ((rs) && (rs->expression[0])) return TRUE;
	return FALSE;
}

void Languages::add_to_regexp_set(pl_regexp_set *rs, inchar32_t expression[]) {
	while ((rs->expression[0]) && (rs->alternate)) rs = rs->alternate;
	if (rs->expression[0]) {
		rs->alternate = Languages::new_regexp_set(); rs = rs->alternate;
	}
	for (int i=0; ((expression[i]) && (i<MAX_ILDF_REGEXP_LENGTH)); i++) {
		rs->expression[i] = expression[i];
		rs->expression[i+1] = 0;
	}
}

void Languages::regexp_to(language_reader_state *state, pl_regexp_set *rs, text_stream *T, text_file_position *tfp) {
	inchar32_t write_to[MAX_ILDF_REGEXP_LENGTH];
	Languages::regexp(state, write_to, T, tfp);
	Languages::add_to_regexp_set(rs, write_to);
}

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
		if (x >= MAX_ILDF_REGEXP_LENGTH) {
			Languages::error(state,
				I"the expression to match is too long", tfp);
			x = MAX_ILDF_REGEXP_LENGTH - 1;
		}
		write_to[x] = 0;
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
