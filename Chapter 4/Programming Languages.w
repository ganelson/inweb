[Languages::] Programming Languages.

Defining the programming languages supported by Inweb, loading in their
definitions from files.

@h Languages.
Programming languages are identified by name: for example, |C++| or |Perl|.

@ =
programming_language *Languages::find_by_name(text_stream *lname) {
	programming_language *pl;
	@<If this is the name of a language already known, return that@>;
	@<Read the language definition file with this name@>;
	if (Str::ne(pl->language_name, lname))
		Errors::fatal_with_text(
			"definition of programming language '%S' is for something else", lname);
	return pl;
}

@<If this is the name of a language already known, return that@> =
	LOOP_OVER(pl, programming_language)
		if (Str::eq(lname, pl->language_name))
			return pl;

@<Read the language definition file with this name@> =
	pathname *P = Pathnames::subfolder(path_to_inweb, I"Languages");
	TEMPORARY_TEXT(leaf);
	WRITE_TO(leaf, "%S.txt", lname);
	filename *F = Filenames::in_folder(P, leaf);
	DISCARD_TEXT(leaf);
	if (TextFiles::exists(F) == FALSE)
		Errors::fatal_with_text(
			"unsupported programming language '%S'", lname);
	pl = Languages::read_definition(F);

@ I'm probably showing my age here.

=
programming_language *Languages::default(void) {
	return Languages::find_by_name(I"C");
}

@ Each different programming language supported by Inweb has an instance of the following structure:

=
typedef struct programming_language {
	text_stream *language_name;
	text_stream *file_extension; /* by default output to a file whose name has this extension */
	text_stream *language_details; /* brief explanation of what language is */
	int supports_enumerations; /* as it will, if it belongs to the C family of languages */
	int supports_namespaces; /* really just for InC */
	text_stream *line_comment;
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
	text_stream *before_macro_expansion;
	text_stream *after_macro_expansion;
	text_stream *start_definition;
	text_stream *prolong_definition;
	text_stream *end_definition;
	text_stream *start_ifdef;
	text_stream *end_ifdef;
	text_stream *start_ifndef;
	text_stream *end_ifndef;
	int C_like;
	struct linked_list *reserved_words; /* of |reserved_word| */
	int suppress_disclaimer;
	struct language_block *program; /* algorithm for syntax colouring */
	METHOD_CALLS
	MEMORY_MANAGEMENT
} programming_language;

typedef struct reserved_word {
	struct text_stream *word;
	int colour;
	MEMORY_MANAGEMENT
} reserved_word;

@h New creation.

@d NOT_A_RULE_PREFIX 1
@d UNSPACED_RULE_PREFIX 2
@d SPACED_RULE_PREFIX 3
@d OPTIONALLY_SPACED_RULE_PREFIX 4

=
typedef struct colouring_rule {
	int colour_match;
	int run;
	struct text_stream *on;
	int colour;
	int prefix;
	int keyword_colour;
	struct language_block *block;
	MEMORY_MANAGEMENT
} colouring_rule;

typedef struct language_block {
	struct linked_list *rules; /* of |colouring_rule| */
	struct language_block *parent;
	MEMORY_MANAGEMENT
} language_block;

typedef struct language_reader_state {
	struct programming_language *defining;
	struct language_block *current_block;
} language_reader_state;

programming_language *Languages::read_definition(filename *F) {
	programming_language *pl = CREATE(programming_language);
	pl->language_name = NULL;
	pl->file_extension = NULL;
	pl->supports_enumerations = FALSE;
	pl->methods = Methods::new_set();
	pl->supports_namespaces = FALSE;
	pl->line_comment = NULL;
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
	pl->before_macro_expansion = NULL;
	pl->after_macro_expansion = NULL;
	pl->start_definition = NULL;
	pl->prolong_definition = NULL;
	pl->end_definition = NULL;
	pl->start_ifdef = NULL;
	pl->end_ifdef = NULL;
	pl->start_ifndef = NULL;
	pl->end_ifndef = NULL;
	pl->C_like = FALSE;
	pl->suppress_disclaimer = FALSE;
	pl->reserved_words = NEW_LINKED_LIST(reserved_word);
	language_reader_state lrs;
	lrs.defining = pl;
	lrs.current_block = NULL;
	TextFiles::read(F, FALSE, "can't open cover sheet file", TRUE,
		Languages::read_definition_line, NULL, (void *) &lrs);
	if (pl->C_like) CLike::make_c_like(pl);
	if (Str::eq(pl->language_name, I"InC")) InCSupport::add_features(pl);
	ACMESupport::add_fallbacks(pl);
	return pl;
}

@

@d WHOLE_LINE_CRULE_RUN -1
@d CHARACTERS_CRULE_RUN -2

@d NOT_A_COLOUR ' '
@d UNQUOTED_COLOUR '_'

=
colouring_rule *Languages::new_rule(language_block *within) {
	if (within == NULL) internal_error("rule outside block");
	colouring_rule *rule = CREATE(colouring_rule);
	ADD_TO_LINKED_LIST(rule, colouring_rule, within->rules);
	rule->colour_match = PLAIN_COLOUR;
	rule->run = WHOLE_LINE_CRULE_RUN;
	rule->on = NULL;
	rule->colour = PLAIN_COLOUR;
	rule->block = NULL;
	rule->prefix = NOT_A_RULE_PREFIX;
	rule->keyword_colour = NOT_A_COLOUR;
	return rule;
}

language_block *Languages::new_block(language_block *within) {
	language_block *block = CREATE(language_block);
	block->rules = NEW_LINKED_LIST(colouring_rule);
	block->parent = within;
	return block;
}

void Languages::read_definition_line(text_stream *line, text_file_position *tfp, void *v_state) {
	language_reader_state *state = (language_reader_state *) v_state;
	programming_language *pl = state->defining;
	Str::trim_white_space(line);
	if (Str::len(line) == 0) return;
	if (Str::get_first_char(line) == '#') return;
	match_results mr = Regexp::create_mr(), mr2 = Regexp::create_mr();
	if (state->current_block) {
		if (Str::eq(line, I"}")) {
			state->current_block = state->current_block->parent;
		} else if (Regexp::match(&mr, line, L"characters {")) {
			colouring_rule *rule = Languages::new_rule(state->current_block);
			rule->block = Languages::new_block(state->current_block);
			rule->run = CHARACTERS_CRULE_RUN;
			state->current_block = rule->block;
		} else if (Regexp::match(&mr, line, L"runs of (%c+) {")) {
			colouring_rule *rule = Languages::new_rule(state->current_block);
			rule->block = Languages::new_block(state->current_block);
			if (Str::eq(mr.exp[0], I"unquoted")) rule->run = UNQUOTED_COLOUR;
			else rule->run = Languages::colour(mr.exp[0], tfp);
			state->current_block = rule->block;
		} else if (Regexp::match(&mr, line, L"(%c+?) => (%c+)")) {
			@<Parse single rule@>;
		} else {
			Errors::in_text_file("line in colouring block illegible", tfp);
		}
	} else {
		if (Regexp::match(&mr, line, L"colouring {")) {
			if (pl->program) {
				Errors::in_text_file("duplicate colouring block", tfp);
			}
			pl->program = Languages::new_block(NULL);
			state->current_block = pl->program;
		} else if (Regexp::match(&mr, line, L"keyword (%C+) *=> *(%c+?)")) {
			reserved_word *rw;
			LOOP_OVER_LINKED_LIST(rw, reserved_word, pl->reserved_words)
				if (Str::eq(rw->word, mr.exp[0])) {
					Errors::in_text_file("duplicate reserved word", tfp);
				}
			rw = CREATE(reserved_word);
			rw->word = Str::duplicate(mr.exp[0]);
			rw->colour = Languages::colour(mr.exp[1], tfp);
			ADD_TO_LINKED_LIST(rw, reserved_word, pl->reserved_words);
		} else if (Regexp::match(&mr, line, L"(%c+) *: *(%c+?)")) {
			text_stream *key = mr.exp[0], *value = Str::duplicate(mr.exp[1]);
			if (Str::eq(key, I"Name")) pl->language_name = Languages::text(value, tfp);
			else if (Str::eq(key, I"Details")) pl->language_details = Languages::text(value, tfp);
			else if (Str::eq(key, I"Extension")) pl->file_extension = Languages::text(value, tfp);
			else if (Str::eq(key, I"Line Comment")) pl->line_comment = Languages::text(value, tfp);
			else if (Str::eq(key, I"Multiline Comment Open")) pl->multiline_comment_open = Languages::text(value, tfp);
			else if (Str::eq(key, I"Multiline Comment Close")) pl->multiline_comment_close = Languages::text(value, tfp);
			else if (Str::eq(key, I"String Literal")) pl->string_literal = Languages::text(value, tfp);
			else if (Str::eq(key, I"String Literal Escape")) pl->string_literal_escape = Languages::text(value, tfp);
			else if (Str::eq(key, I"Character Literal")) pl->character_literal = Languages::text(value, tfp);
			else if (Str::eq(key, I"Character Literal Escape")) pl->character_literal_escape = Languages::text(value, tfp);
			else if (Str::eq(key, I"Binary Literal Prefix")) pl->binary_literal_prefix = Languages::text(value, tfp);
			else if (Str::eq(key, I"Octal Literal Prefix")) pl->octal_literal_prefix = Languages::text(value, tfp);
			else if (Str::eq(key, I"Hexadecimal Literal Prefix")) pl->hexadecimal_literal_prefix = Languages::text(value, tfp);
			else if (Str::eq(key, I"Negative Literal Prefix")) pl->negative_literal_prefix = Languages::text(value, tfp);
			else if (Str::eq(key, I"Shebang")) pl->shebang = Languages::text(value, tfp);
			else if (Str::eq(key, I"Line Marker")) pl->line_marker = Languages::text(value, tfp);
			else if (Str::eq(key, I"Before Macro Expansion")) pl->before_macro_expansion = Languages::text(value, tfp);
			else if (Str::eq(key, I"After Macro Expansion")) pl->after_macro_expansion = Languages::text(value, tfp);
			else if (Str::eq(key, I"Supports Enumerations")) pl->supports_enumerations = Languages::boolean(value, tfp);
			else if (Str::eq(key, I"Start Definition")) pl->start_definition = Languages::text(value, tfp);
			else if (Str::eq(key, I"Prolong Definition")) pl->prolong_definition = Languages::text(value, tfp);
			else if (Str::eq(key, I"End Definition")) pl->end_definition = Languages::text(value, tfp);
			else if (Str::eq(key, I"Start Ifdef")) pl->start_ifdef = Languages::text(value, tfp);
			else if (Str::eq(key, I"Start Ifndef")) pl->start_ifndef = Languages::text(value, tfp);
			else if (Str::eq(key, I"End Ifdef")) pl->end_ifdef = Languages::text(value, tfp);
			else if (Str::eq(key, I"End Ifndef")) pl->end_ifndef = Languages::text(value, tfp);
			else if (Str::eq(key, I"C-Like"))
				pl->C_like = Languages::boolean(value, tfp);
			else if (Str::eq(key, I"Suppress Disclaimer"))
				pl->suppress_disclaimer = Languages::boolean(value, tfp);
			else if (Str::eq(key, I"Supports Namespaces"))
				pl->supports_namespaces = Languages::boolean(value, tfp);
			else {
				Errors::in_text_file("unknown property in list of language properties", tfp);
			}
		} else {
			Errors::in_text_file("line in language definition illegible", tfp);
		}
	}
	Regexp::dispose_of(&mr); Regexp::dispose_of(&mr2);
}

@<Parse single rule@> =
	text_stream *premiss = mr.exp[0], *action = Str::duplicate(mr.exp[1]);

	colouring_rule *rule = Languages::new_rule(state->current_block);
	Str::trim_white_space(premiss); Str::trim_white_space(action);
	if (Regexp::match(&mr2, premiss, L"keyword (%c+)")) {
		rule->keyword_colour = Languages::colour(mr2.exp[0], tfp);
	} else if (Regexp::match(&mr2, premiss, L"prefix (%c+)")) {
		rule->prefix = UNSPACED_RULE_PREFIX;
		rule->on = Str::duplicate(mr2.exp[0]);
	} else if (Regexp::match(&mr2, premiss, L"spaced prefix (%c+)")) {
		rule->prefix = SPACED_RULE_PREFIX;
		rule->on = Str::duplicate(mr2.exp[0]);
	} else if (Regexp::match(&mr2, premiss, L"optionally spaced prefix (%c+)")) {
		rule->prefix = OPTIONALLY_SPACED_RULE_PREFIX;
		rule->on = Str::duplicate(mr2.exp[0]);
	} else if (Str::ne(premiss, I"(all)")) {
		rule->on = Str::duplicate(premiss);
	}
	if (Str::eq(action, I"{")) {
		language_block *block = CREATE(language_block);
		block->rules = NEW_LINKED_LIST(colouring_rule);
		block->parent = state->current_block;
		rule->block = block;
		state->current_block = block;
	} else if (Str::get_first_char(action) == '!') {
		rule->colour = Languages::colour(action, tfp);
	} else {
		Errors::in_text_file("action after '=>' illegible", tfp);
	}

@ 

@d MACRO_COLOUR 		'm'
@d FUNCTION_COLOUR		'f'
@d RESERVED_COLOUR		'r'
@d ELEMENT_COLOUR		'e'
@d IDENTIFIER_COLOUR	'i'
@d CHAR_LITERAL_COLOUR	'c'
@d CONSTANT_COLOUR		'n'
@d STRING_COLOUR		's'
@d PLAIN_COLOUR			'p'
@d EXTRACT_COLOUR		'x'
@d COMMENT_COLOUR		'!'

=
int Languages::colour(text_stream *T, text_file_position *tfp) {
	if (Str::get_first_char(T) != '!') {
		Errors::in_text_file("colour names must begin with !", tfp);
		return PLAIN_COLOUR;
	}
	if (Str::eq(T, I"!string")) return STRING_COLOUR;
	else if (Str::eq(T, I"!function")) return FUNCTION_COLOUR;
	else if (Str::eq(T, I"!macro")) return MACRO_COLOUR;
	else if (Str::eq(T, I"!reserved")) return RESERVED_COLOUR;
	else if (Str::eq(T, I"!element")) return ELEMENT_COLOUR;
	else if (Str::eq(T, I"!identifier")) return IDENTIFIER_COLOUR;
	else if (Str::eq(T, I"!character")) return CHAR_LITERAL_COLOUR;
	else if (Str::eq(T, I"!constant")) return CONSTANT_COLOUR;
	else if (Str::eq(T, I"!plain")) return PLAIN_COLOUR;
	else if (Str::eq(T, I"!extract")) return EXTRACT_COLOUR;
	else if (Str::eq(T, I"!comment")) return COMMENT_COLOUR;
	else {
		Errors::in_text_file("no such !colour", tfp);
		return PLAIN_COLOUR;
	}
}

int Languages::boolean(text_stream *T, text_file_position *tfp) {
	if (Str::eq(T, I"true")) return TRUE;
	else if (Str::eq(T, I"false")) return FALSE;
	else {
		Errors::in_text_file("must be true or false", tfp);
		return FALSE;
	}
}

text_stream *Languages::text(text_stream *T, text_file_position *tfp) {
	text_stream *V = Str::new();
	for (int i=0; i<Str::len(T); i++) {
		wchar_t c = Str::get_at(T, i);
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
		} else {
			PUT_TO(V, c);
		}
	}
	return V;
}
