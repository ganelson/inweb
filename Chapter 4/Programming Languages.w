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
	pathname *P = Languages::default_directory();
	TEMPORARY_TEXT(leaf);
	WRITE_TO(leaf, "%S.ildf", lname);
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

void Languages::show(OUTPUT_STREAM) {
	WRITE("Inweb can see the following programming language definitions:\n\n");
	programming_language *pl;
	LOOP_OVER(pl, programming_language)
		WRITE("%S: %S\n", pl->language_name, pl->language_details);
}

@ We can read every language in a directory:

=
void Languages::read_definitions(pathname *P) {
	if (P == NULL) P = Languages::default_directory();
	scan_directory *D = Directories::open(P);
	TEMPORARY_TEXT(leafname);
	while (Directories::next(D, leafname)) {
		if (Str::get_last_char(leafname) != FOLDER_SEPARATOR) {
			filename *F = Filenames::in_folder(P, leafname);
			Languages::read_definition(F);
		}
	}
	DISCARD_TEXT(leafname);
	Directories::close(D);
}

pathname *Languages::default_directory(void) {
	return Pathnames::subfolder(path_to_inweb, I"Languages");
}

@ So, then, languages are defined by files which are read in, and parsed
into the following structure (one per language):

=
typedef struct programming_language {
	text_stream *language_name; /* identifies it: see above */
	
	/* then a great many fields set directly in the definition file: */
	text_stream *file_extension; /* by default output to a file whose name has this extension */
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
	text_stream *before_macro_expansion;
	text_stream *after_macro_expansion;
	text_stream *start_definition;
	text_stream *prolong_definition;
	text_stream *end_definition;
	text_stream *start_ifdef;
	text_stream *end_ifdef;
	text_stream *start_ifndef;
	text_stream *end_ifndef;
	int suppress_disclaimer;
	int C_like; /* languages with this set have access to extra features */

	struct linked_list *reserved_words; /* of |reserved_word| */
	struct hash_table built_in_keywords;
	struct colouring_language_block *program; /* algorithm for syntax colouring */
	METHOD_CALLS
	MEMORY_MANAGEMENT
} programming_language;

@ This is a simple one-pass compiler. The |language_reader_state| provides
the only state preserved as we work through line by line, except of course
that we are also working on the programming language it is |defining|. The
|current_block| is the braced block of colouring instructions we are
currently inside.

=
typedef struct language_reader_state {
	struct programming_language *defining;
	struct colouring_language_block *current_block;
} language_reader_state;

programming_language *Languages::read_definition(filename *F) {
	programming_language *pl = CREATE(programming_language);
	@<Initialise the language to a plain-text state@>;
	language_reader_state lrs;
	lrs.defining = pl;
	lrs.current_block = NULL;
	TextFiles::read(F, FALSE, "can't open programming language definition file",
		TRUE, Languages::read_definition_line, NULL, (void *) &lrs);
	@<Add method calls to the language@>;
	return pl;
}

@<Initialise the language to a plain-text state@> =
	pl->language_name = NULL;
	pl->file_extension = NULL;
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
	pl->built_in_keywords.analysis_hash_initialised = FALSE;
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
	if (Regexp::match(&mr, line, L"colouring {")) {
		if (pl->program) Errors::in_text_file("duplicate colouring program", tfp);
		pl->program = Languages::new_block(NULL, WHOLE_LINE_CRULE_RUN);
		state->current_block = pl->program;
	} else if (Regexp::match(&mr, line, L"keyword (%C+) of (%c+?)")) {
		Languages::reserved(pl, mr.exp[0], Languages::colour(mr.exp[1], tfp), tfp);
	} else if (Regexp::match(&mr, line, L"keyword (%C+)")) {
		Languages::reserved(pl, mr.exp[0], RESERVED_COLOUR, tfp);
	} else if (Regexp::match(&mr, line, L"(%c+) *: *(%c+?)")) {
		text_stream *key = mr.exp[0], *value = Str::duplicate(mr.exp[1]);
		if (Str::eq(key, I"Name")) pl->language_name = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Details"))
			pl->language_details = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Extension"))
			pl->file_extension = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Line Comment"))
			pl->line_comment = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Whole Line Comment"))
			pl->whole_line_comment = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Multiline Comment Open"))
			pl->multiline_comment_open = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Multiline Comment Close"))
			pl->multiline_comment_close = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"String Literal"))
			pl->string_literal = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"String Literal Escape"))
			pl->string_literal_escape = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Character Literal"))
			pl->character_literal = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Character Literal Escape"))
			pl->character_literal_escape = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Binary Literal Prefix"))
			pl->binary_literal_prefix = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Octal Literal Prefix"))
			pl->octal_literal_prefix = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Hexadecimal Literal Prefix"))
			pl->hexadecimal_literal_prefix = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Negative Literal Prefix"))
			pl->negative_literal_prefix = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Shebang"))
			pl->shebang = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Line Marker"))
			pl->line_marker = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Before Named Paragraph Expansion"))
			pl->before_macro_expansion = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"After Named Paragraph Expansion"))
			pl->after_macro_expansion = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Start Definition"))
			pl->start_definition = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Prolong Definition"))
			pl->prolong_definition = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"End Definition"))
			pl->end_definition = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Start Ifdef"))
			pl->start_ifdef = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"Start Ifndef"))
			pl->start_ifndef = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"End Ifdef"))
			pl->end_ifdef = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"End Ifndef"))
			pl->end_ifndef = Languages::text(value, tfp, TRUE);
		else if (Str::eq(key, I"C-Like"))
			pl->C_like = Languages::boolean(value, tfp);
		else if (Str::eq(key, I"Suppress Disclaimer"))
			pl->suppress_disclaimer = Languages::boolean(value, tfp);
		else if (Str::eq(key, I"Supports Namespaces"))
			pl->supports_namespaces = Languages::boolean(value, tfp);
		else {
			Errors::in_text_file("unknown property name before ':'", tfp);
		}
	} else {
		Errors::in_text_file("line in language definition illegible", tfp);
	}

@ Inside a colouring program, you can close the current block (which may be
the entire program), open a new block to apply to each character or to
runs of a given colour, or give an if-X-then-Y rule:

@<Syntax inside a colouring program@> =
	if (Str::eq(line, I"}")) {
		state->current_block = state->current_block->parent;
	} else if (Regexp::match(&mr, line, L"characters {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block =
			Languages::new_block(state->current_block, CHARACTERS_CRULE_RUN);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, L"runs of (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		int r = UNQUOTED_COLOUR;
		if (Str::ne(mr.exp[0], I"unquoted")) r = Languages::colour(mr.exp[0], tfp);
		rule->execute_block = Languages::new_block(state->current_block, r);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, line, L"instances of (%c+) {")) {
		colouring_rule *rule = Languages::new_rule(state->current_block);
		rule->execute_block = Languages::new_block(state->current_block, INSTANCES_CRULE_RUN);
		rule->execute_block->run_instance = Languages::text(mr.exp[0], tfp, FALSE);
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
			TEMPORARY_TEXT(premiss);
			TEMPORARY_TEXT(conclusion);
			Str::substr(premiss, Str::start(line), Str::at(line, at));
			Str::substr(conclusion, Str::at(line, at+2), Str::end(line));
			Languages::parse_rule(state, premiss, conclusion, tfp);
			DISCARD_TEXT(conclusion);
			DISCARD_TEXT(premiss);
		} else {
			Errors::in_text_file("line in colouring block illegible", tfp);
		}
	}

@h Blocks.
These are code blocks of colouring instructions. A block whose |parent| is |NULL|
represents a complete program.

@d WHOLE_LINE_CRULE_RUN -1 /* This block applies to the whole snippet being coloured */
@d CHARACTERS_CRULE_RUN -2 /* This block applies to each character in turn */
@d INSTANCES_CRULE_RUN -3 /* This block applies to each instance in turn */

=
typedef struct colouring_language_block {
	struct linked_list *rules; /* of |colouring_rule| */
	struct colouring_language_block *parent; /* or |NULL| for the topmost one */
	int run; /* one of the |*_CRULE_RUN| values, or else a colour */
	struct text_stream *run_instance; /* used only for |INSTANCES_CRULE_RUN| */
	MEMORY_MANAGEMENT
} colouring_language_block;

@ =
colouring_language_block *Languages::new_block(colouring_language_block *within, int r) {
	colouring_language_block *block = CREATE(colouring_language_block);
	block->rules = NEW_LINKED_LIST(colouring_rule);
	block->parent = within;
	block->run = r;
	block->run_instance = NULL;
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
	int match_colour; /* for |colour C|, or else |NOT_A_COLOUR| */
	int match_keyword_of_colour; /* for |keyword C|, or else |NOT_A_COLOUR| */
	struct text_stream *match_text; /* or length 0 to mean "anything" */
	int match_prefix; /* one of the |*_RULE_PREFIX| values above */

	/* the conclusion: */
	struct colouring_language_block *execute_block; /* or |NULL|, in which case... */
	int set_to_colour; /* ...paint the snippet in this colour */
	int set_prefix_to_colour; /* ...also paint this (same for suffix) */
	int debug; /* ...or print debugging text to console */
	
	/* workspace during painting */
	int fix_position; /* where the prefix or suffix started */
	MEMORY_MANAGEMENT
} colouring_rule;

@ =
colouring_rule *Languages::new_rule(colouring_language_block *within) {
	if (within == NULL) internal_error("rule outside block");
	colouring_rule *rule = CREATE(colouring_rule);
	ADD_TO_LINKED_LIST(rule, colouring_rule, within->rules);
	rule->match_colour = NOT_A_COLOUR;
	rule->match_text = NULL;
	rule->match_prefix = NOT_A_RULE_PREFIX;
	rule->match_keyword_of_colour = NOT_A_COLOUR;

	rule->set_to_colour = NOT_A_COLOUR;
	rule->set_prefix_to_colour = NOT_A_COLOUR;
	rule->execute_block = NULL;
	rule->debug = FALSE;
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
	if (Regexp::match(&mr, premiss, L"keyword of (%c+)")) {
		rule->match_keyword_of_colour = Languages::colour(mr.exp[0], tfp);
	} else if (Regexp::match(&mr, premiss, L"keyword")) {
		Errors::in_text_file("ambiguous: make it keyword of !reserved or \"keyword\"", tfp);
	} else if (Regexp::match(&mr, premiss, L"prefix (%c+)")) {
		rule->match_prefix = UNSPACED_RULE_PREFIX;
		rule->match_text = Languages::text(mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, L"spaced prefix (%c+)")) {
		rule->match_prefix = SPACED_RULE_PREFIX;
		rule->match_text = Languages::text(mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, L"optionally spaced prefix (%c+)")) {
		rule->match_prefix = OPTIONALLY_SPACED_RULE_PREFIX;
		rule->match_text = Languages::text(mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, L"suffix (%c+)")) {
		rule->match_prefix = UNSPACED_RULE_SUFFIX;
		rule->match_text = Languages::text(mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, L"spaced suffix (%c+)")) {
		rule->match_prefix = SPACED_RULE_SUFFIX;
		rule->match_text = Languages::text(mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, L"optionally spaced suffix (%c+)")) {
		rule->match_prefix = OPTIONALLY_SPACED_RULE_SUFFIX;
		rule->match_text = Languages::text(mr.exp[0], tfp, FALSE);
	} else if (Regexp::match(&mr, premiss, L"colou*r (%c+)")) {
		rule->match_colour = Languages::colour(mr.exp[0], tfp);
	} else if (Str::len(premiss) > 0) {
		rule->match_text = Languages::text(premiss, tfp, FALSE);
	}

@<Parse the conclusion@> =
	if (Str::eq(action, I"{")) {
		rule->execute_block =
			Languages::new_block(state->current_block, WHOLE_LINE_CRULE_RUN);
		state->current_block = rule->execute_block;
	} else if (Regexp::match(&mr, action, L"(!%c+) on prefix")) {
		rule->set_prefix_to_colour = Languages::colour(mr.exp[0], tfp);
	} else if (Regexp::match(&mr, action, L"(!%c+) on suffix")) {
		rule->set_prefix_to_colour = Languages::colour(mr.exp[0], tfp);
	} else if (Regexp::match(&mr, action, L"(!%c+) on both")) {
		rule->set_to_colour = Languages::colour(mr.exp[0], tfp);
		rule->set_prefix_to_colour = rule->set_to_colour;
	} else if (Str::get_first_char(action) == '!') {
		rule->set_to_colour = Languages::colour(action, tfp);
	} else if (Str::eq(action, I"debug")) {
		rule->debug = TRUE;
	} else {
		Errors::in_text_file("action after '=>' illegible", tfp);
	}

@h Reserved words.
Note that these can come in any colour, though usually it's |!reserved|.

=
typedef struct reserved_word {
	struct text_stream *word;
	int colour;
	MEMORY_MANAGEMENT
} reserved_word;

reserved_word *Languages::reserved(programming_language *pl, text_stream *W, int C,
	text_file_position *tfp) {
	reserved_word *rw;
	LOOP_OVER_LINKED_LIST(rw, reserved_word, pl->reserved_words)
		if (Str::eq(rw->word, W)) {
			Errors::in_text_file("duplicate reserved word", tfp);
		}
	rw = CREATE(reserved_word);
	rw->word = Str::duplicate(W);
	rw->colour = C;
	ADD_TO_LINKED_LIST(rw, reserved_word, pl->reserved_words);
	Analyser::mark_reserved_word(&(pl->built_in_keywords), rw->word, C);
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
@d CHAR_LITERAL_COLOUR	'c'
@d CONSTANT_COLOUR		'n'
@d STRING_COLOUR		's'
@d PLAIN_COLOUR			'p'
@d EXTRACT_COLOUR		'x'
@d COMMENT_COLOUR		'!'

@d NOT_A_COLOUR ' '
@d UNQUOTED_COLOUR '_'

=
int Languages::colour(text_stream *T, text_file_position *tfp) {
	if (Str::get_first_char(T) != '!') {
		Errors::in_text_file("colour names must begin with !", tfp);
		return PLAIN_COLOUR;
	}
	if (Str::eq(T, I"!string")) return STRING_COLOUR;
	else if (Str::eq(T, I"!function")) return FUNCTION_COLOUR;
	else if (Str::eq(T, I"!definition")) return DEFINITION_COLOUR;
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

@ A boolean must be written as |true| or |false|.

=
int Languages::boolean(text_stream *T, text_file_position *tfp) {
	if (Str::eq(T, I"true")) return TRUE;
	else if (Str::eq(T, I"false")) return FALSE;
	else {
		Errors::in_text_file("must be true or false", tfp);
		return FALSE;
	}
}

@ In text, |\n| represents a newline, |\s| a space and |\t| a tab. Spaces
can be given in the ordinary way inside a text in any case. |\\| is a
literal backslash.

=
text_stream *Languages::text(text_stream *T, text_file_position *tfp, int allow) {
	text_stream *V = Str::new();
	if (Str::len(T) > 0) {
		int bareword = TRUE, spaced = FALSE, from = 0, to = Str::len(T)-1;
		if ((to > from) &&
			(Str::get_at(T, from) == '"') && (Str::get_at(T, to) == '"')) {
			bareword = FALSE; from++; to--;
		}
		for (int i=from; i<=to; i++) {
			wchar_t c = Str::get_at(T, i);
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
				Errors::in_text_file(
					"backslash needed before internal double-quotation mark", tfp);
			} else if ((bareword) && (c == '"')) {
				Errors::in_text_file(
					"double-quotation marks can only be used in quoted strings", tfp);
			} else {
				PUT_TO(V, c);
			}
		}
		if ((bareword) && (spaced) && (allow == FALSE)) {
			TEMPORARY_TEXT(err);
			WRITE_TO(err, "'%S' seems to be literal text, but if so it needs double-quotation marks", T);
			Errors::in_text_file_S(err, tfp);
			DISCARD_TEXT(err);			
		}
	}
	return V;
}
