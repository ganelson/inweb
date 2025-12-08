[WebNotation::] Web Notations.

To manage possible notations for writing programs in web form.

@h Introduction.
We want to provide a literate-programming engine which can handle a wide range
of different possible markup notations for LP. Each such notation is represented
by an |ls_notation| object. These can even be created on the fly, so that a
single-file web can contain instructions defining its own unique notation.

Until 2025, only two fixed notations were supported: version 1 ("old-Inweb"),
used until about 2020; and version 2 ("Inweb"), used since then. Version 1
is gone and unmourned, so we won't complicate the code by supporting it.

=
ls_notation *WebNotation::default(void) {
	static ls_notation *default_ls_notation = NULL;
	if (default_ls_notation == NULL) {
		wcl_declaration *D = WCL::resolve_resource(NULL, NOTATION_WCLTYPE, I"Inweb");
		if (D) default_ls_notation = RETRIEVE_POINTER_ls_notation(D->object_declared);
		if (default_ls_notation == NULL)
			Errors::fatal("Unable to locate notation 'Inweb' for literate programs");
	}
	return default_ls_notation;
}

@ Each syntax is represented by a |ls_notation| object:

=
typedef struct ls_notation {
	struct wcl_declaration *declaration;

	/* for deciding what syntax we should use when reading a given web */
	struct text_stream *name;
	struct text_stream *legacy_name;
	struct linked_list *recognised_filename_extensions; /* of |text_stream| */

	/* what settings of the web this changes (if any) */
	struct linked_list *bibliographic_settings; /* of |text_stream| */

	/* what aspects of LP are allowed under this syntax, with what notations */
	int supports[NO_DEFINED_WSF_VALUES];
	struct text_stream *feature_notation1[NO_DEFINED_WSF_VALUES];
	struct text_stream *feature_notation2[NO_DEFINED_WSF_VALUES];

	/* how input lines are classified when this syntax is used */
	struct linked_list *rules; /* of |ls_notation_rule| */
	struct linked_list *residue_rules[NO_DEFINED_WSRULEOUTCOME_VALUES]; /* ditto */
	struct linked_list *options_rules[NO_DEFINED_WSRULEOUTCOME_VALUES]; /* ditto */
	struct ls_class_parsing (*line_classifier)(struct ls_notation *,
		struct text_stream *, struct ls_class *);

	/* temporarily needed in parsing syntax files */
	struct linked_list *stanza;
	CLASS_DEFINITION
} ls_notation;

@

=
ls_notation *WebNotation::new(text_stream *name) {
	ls_notation *S = CREATE(ls_notation);
	S->declaration = NULL;
	S->name = Str::duplicate(name);
	S->legacy_name = NULL;
	S->recognised_filename_extensions = NEW_LINKED_LIST(text_stream);

	S->bibliographic_settings = NEW_LINKED_LIST(text_stream);

	for (int i=0; i<NO_DEFINED_WSF_VALUES; i++) {
		S->supports[i] = FALSE;
		S->feature_notation1[i] = NULL;
		S->feature_notation2[i] = NULL;
	}

	S->rules = NEW_LINKED_LIST(ls_notation_rule);
	for (int i=0; i<NO_DEFINED_WSRULEOUTCOME_VALUES; i++) {
		S->residue_rules[i] = NEW_LINKED_LIST(ls_notation_rule);
		S->options_rules[i] = NEW_LINKED_LIST(ls_notation_rule);
	}
	S->line_classifier = NULL;
	
	S->stanza = NULL;
	return S;
}

@h Identification.
As we've seen, it's a non-trivial problem, given a web, to decide what syntax
it's using. We might:

(1) Get the answer from a command-line switch telling us explicitly what to use;
(2) See the syntax name in the metadata at the top of a web's contents page,
if it has one;
(3) See a "legacy name" in the same way;
(4) Guess on the basis of the filename extension for a single-file web;
(5) Recognise a typical pattern (a "shebang") on line 1 of a single-file web.

Legacy names are used only so that "2" can be recognised as an alternative
to "Inweb", for the default syntax. (As noted above, this was once version 2.)

=
ls_notation *WebNotation::syntax_by_name(ls_web *W, text_stream *name) {
	wcl_declaration *X = WCL::resolve_resource(W?(W->declaration):NULL, NOTATION_WCLTYPE, name);
	if (X) return RETRIEVE_POINTER_ls_notation(X->object_declared);
	linked_list *L = WCL::list_resources(W?(W->declaration):NULL, NOTATION_WCLTYPE, NULL);
	wcl_declaration *D;
	LOOP_OVER_LINKED_LIST(D, wcl_declaration, L) {
		ls_notation *T = RETRIEVE_POINTER_ls_notation(D->object_declared);
		if (Str::eq_insensitive(name, T->legacy_name))
			return T;
	}
	return NULL;
}

void WebNotation::write_known_syntaxes(OUTPUT_STREAM, ls_web *W) {
	WRITE("I can see the following literate programming notations:\n\n");
	WCL::write_sorted_list_of_resources(OUT, W, NOTATION_WCLTYPE);
}

@ Here we take a guess from a filename:

=
ls_notation *WebNotation::guess_from_filename(ls_web *W, filename *F) {
	TEMPORARY_TEXT(extension)
	TEMPORARY_TEXT(penultimate_extension)
	Filenames::write_final_extension(extension, F);
	Filenames::write_penultimate_extension(penultimate_extension, F);
//	PRINT("Guessing N from '%S' (%f, pen %S)\n", extension, F, penultimate_extension);
	ls_notation *result = NULL;
	linked_list *L = WCL::list_resources(W?(W->declaration):NULL, NOTATION_WCLTYPE, NULL);
	wcl_declaration *D;
	LOOP_OVER_LINKED_LIST(D, wcl_declaration, L) {
		ls_notation *T = RETRIEVE_POINTER_ls_notation(D->object_declared);
		text_stream *ext;
		LOOP_OVER_LINKED_LIST(ext, text_stream, T->recognised_filename_extensions)
			if (Str::begins_with(ext, I".*.")) {
				if ((Str::len(penultimate_extension) > 0) && (Str::ends_with(ext, extension))) {
					result = T;
					goto DoubleBreak;
				}
			} else if (Str::eq_insensitive(ext, extension)) {
				result = T;
				goto DoubleBreak;
			}
	}	
	DoubleBreak: ;
	DISCARD_TEXT(penultimate_extension)
	DISCARD_TEXT(extension)
	return result;
}

@h Adoption.
Suppose, then, that the above methods decide that a given web |W| should be read
with syntax |S|. What happens then?

The answer is that we set some bibliographic data.

=
void WebNotation::declare_for_web(ls_web *W, ls_notation *S) {
	if (W->web_syntax != S) {
		W->web_syntax = S;
		if (S) {
			Bibliographic::set_datum(W, I"Notation", S->name);
			text_file_position tfp = TextFiles::nowhere();
			text_stream *setting;
			LOOP_OVER_LINKED_LIST(setting, text_stream, S->bibliographic_settings)
				Bibliographic::parse_kvp(W, setting, TRUE, &tfp, NULL, TRUE);
		}
	}
}

@h Features.
These can't be set directly, but are deduced when a notation is customised for a
web using its conventions:

@e TRIMMED_HOLONS_ABOVE_WSF from 0  /* when tangling, trim initial blank lines from a holon */
@e TRIMMED_HOLONS_BELOW_WSF         /* when tangling, trim final blank lines from a holon */
@e FOOTNOTES_IN_COMMENTARY_WSF      /* commentary in paragraphs can have footnotes */
@e NAMED_HOLONS_WSF                 /* notation for holon names */
@e METADATA_IN_STRINGS_WSF          /* notation for metadata in strings */
@e PARAGRAPH_TAGS_WSF               /* paragraphs can be tagged */

=
text_stream *WebNotation::feature_name(int n) {
	switch (n) {
		case KEY_VALUE_PAIRS_WSF:           return I"key-value pairs";
	}
	return NULL;
}

int WebNotation::feature_by_name(text_stream *name) {
	for (int i=0; i<NO_DEFINED_WSF_VALUES; i++)
		if (Str::eq_insensitive(name, WebNotation::feature_name(i)))
			return i;
	return -1;
}

@ Besides a name, some features come with up to two notation texts supplied:

=
int WebNotation::feature_notations(int n) {
	switch (n) {
		case NAMED_HOLONS_WSF:              return 2;
		case METADATA_IN_STRINGS_WSF:          return 2;
		default: return 0;
	}
}

@ Does the given syntax support a feature?

=
int WebNotation::supports(ls_notation *S, int feature) {
	if (S == NULL) return FALSE;
	if ((feature < 0) || (feature >= NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	return S->supports[feature];
}

@ If so, what are the associated notation texts?

=
text_stream *WebNotation::notation(ls_notation *S, int feature, int which) {
	if ((feature < 0) || (feature >= NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	if ((which < 1) || (which > WebNotation::feature_notations(feature)))
		internal_error("notation out of range");
	if (which == 1) return S->feature_notation1[feature];
	return S->feature_notation2[feature];
}

@ And these functions are used to declare that we do or don't support a
given feature:

=
void WebNotation::does_support(ls_notation *S, int feature) {
	if (S == NULL) internal_error("no syntax");
	if ((feature < 0) || (feature >= NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	if (WebNotation::feature_notations(feature) != 0)
		internal_error("wrong number of notations");
	S->supports[feature] = TRUE;
}

void WebNotation::does_support1(ls_notation *S, int feature, text_stream *N1) {
	if (S == NULL) internal_error("no syntax");
	if ((feature < 0) || (feature >= NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	if (WebNotation::feature_notations(feature) != 1)
		internal_error("wrong number of notations");
	S->supports[feature] = TRUE;
	S->feature_notation1[feature] = Str::duplicate(N1);
}

void WebNotation::does_support2(ls_notation *S, int feature, text_stream *N1, text_stream *N2) {
	if (S == NULL) internal_error("no syntax");
	if ((feature < 0) || (feature >= NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	if (WebNotation::feature_notations(feature) != 2)
		internal_error("wrong number of notations");
	S->supports[feature] = TRUE;
	S->feature_notation1[feature] = Str::duplicate(N1);
	S->feature_notation2[feature] = Str::duplicate(N2);
}

void WebNotation::does_not_support(ls_notation *S, int feature) {
	if (S == NULL) internal_error("no syntax");
	if ((feature < 0) || (feature >= NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	S->supports[feature] = FALSE;
	S->feature_notation1[feature] = NULL;
	S->feature_notation2[feature] = NULL;
}

@h Reading syntax definitions.
We can read in a whole directory of these...

=
void WebNotation::read_definitions(pathname *P) {
	scan_directory *D = Directories::open(P);
	TEMPORARY_TEXT(leafname)
	while (Directories::next(D, leafname)) {
		if (Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) {
			filename *F = Filenames::in(P, leafname);
			WebNotation::read_definition(F);
		}
	}
	DISCARD_TEXT(leafname)
	Directories::close(D);
}

@ ...or just a single file...

=
int bare_syntaxes = 0;
ls_notation *WebNotation::read_definition(filename *F) {
	wcl_declaration *D = WCL::read_just_one(F, NOTATION_WCLTYPE);
	if (D == NULL) return NULL;
	return RETRIEVE_POINTER_ls_notation(D->object_declared);
}

ls_notation *WebNotation::parse_declaration(wcl_declaration *D) {
	ls_notation *S = WebNotation::new(I"pending_naming_only");
	S->declaration = D;
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		WebNotation::read_definition_line(line, &tfp, (void *) S);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	D->object_declared = STORE_POINTER_ls_notation(S);
	if (Str::eq(S->name, I"pending_naming_only")) {
		S->name = Str::duplicate(D->name);
		if (Str::len(S->name) == 0) {
			bare_syntaxes++;
			Str::clear(S->name);
			WRITE_TO(S->name, "CustomSyntax");
			if (bare_syntaxes > 1) WRITE_TO(S->name, "%d", bare_syntaxes);
		}
	} else if (WCL::check_name(D, S->name) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "language has two different names, '%S' and '%S'",
			D->name, S->name);
		WCL::error(D, &(D->declaration_position), msg);
		DISCARD_TEXT(msg)
	}
	return S;
}

void WebNotation::resolve_declaration(wcl_declaration *D) {
	Conventions::set_level(D, NOTATION_LSCONVENTIONLEVEL);
}

@ ...and here we receive a single line from such a file.

=
void WebNotation::read_definition_line(text_stream *line, text_file_position *tfp, void *v_state) {
	ls_notation *syntax = (ls_notation *) v_state;
	Str::trim_white_space(line);
	text_stream *error = WebNotation::apply_syntax_setting(syntax, line);
	if (Str::len(error) > 0) WCL::error(syntax->declaration, tfp, error);
}

@ In order to be able to apply commands to syntaxes outside of a file-reading
context, we funnel all lines through this function, which can also be called
independently:

=
text_stream *WebNotation::apply_syntax_setting(ls_notation *S, text_stream *cmd) {
	text_stream *error = NULL;
	match_results mr = Regexp::create_mr();
	@<Whitespace and comments@>;
	@<Entering and exiting stanzas@>;
	@<Inside stanzas@>;
	@<Miscellaneous settings@>;
	@<Activating or deactivating features@>;
	error = Str::new();
	WRITE_TO(error, "unknown inweb syntax command '%S'", cmd);
	@<Setting done@>;
}

@ Note that whitespace lines are ignored everywhere, but that comments are allowed
only outside of stanzas: this is to avoid making the comment character untypeable
in grammar.

@<Whitespace and comments@> =
	if (Str::is_whitespace(cmd)) @<Setting done@>;
	if ((Regexp::match(&mr, cmd, U"#(%c*)")) && (S->stanza == NULL)) @<Setting done@>;

@ Stanzas are placed between braces, which cannot be nested. Each stanza refers
to a particular rule list.

@<Entering and exiting stanzas@> =
	if (Regexp::match(&mr, cmd, U"classify {")) {
		if (S->stanza) error = I"cannot nest { ... } blocks"; else S->stanza = S->rules;
		 @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"residue of (%C+) {")) {
		if (S->stanza) { error = I"cannot nest { ... } blocks"; @<Setting done@>; }
		int R = WebNotation::outcome_by_name(mr.exp[0]);
		if (R == NO_WSRULEOUTCOME) {
			error = Str::new();
			WRITE_TO(error, "unknown outcome '%S'", mr.exp[0]);
		} else {
			S->stanza = S->residue_rules[R];
		}
		@<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"options of (%C+) {")) {
		if (S->stanza) { error = I"cannot nest { ... } blocks"; @<Setting done@>; }
		int R = WebNotation::outcome_by_name(mr.exp[0]);
		if (R == NO_WSRULEOUTCOME) {
			error = Str::new();
			WRITE_TO(error, "unknown outcome '%S'", mr.exp[0]);
		} else {
			S->stanza = S->options_rules[R];
		}
		@<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"}")) {
		if (S->stanza) S->stanza = NULL; else error = I"unexpected '}'";
		@<Setting done@>;
	}		

@ Inside a stanza, the only content allowed is a grammar rule.

@<Inside stanzas@> =
	if (S->stanza) {
		if (Regexp::match(&mr, cmd, U"(%c*?) ==> (%c*)")) {
			error = WebNotation::parse_grammar(S, S->stanza, mr.exp[0], mr.exp[1]);
		} else if (Regexp::match(&mr, cmd, U" *==> (%c*)")) {
			error = WebNotation::parse_grammar(S, S->stanza, NULL, mr.exp[0]);
		} else {
			error = Str::new();
			WRITE_TO(error, "not a grammar line: '%S'", cmd);
		}
		@<Setting done@>;
	}

@<Miscellaneous settings@> =
	if (Regexp::match(&mr, cmd, U"name \"(%C+)\"")) {
		S->name = Str::duplicate(mr.exp[0]); @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"legacy name \"(%C+)\"")) {
		S->legacy_name = Str::duplicate(mr.exp[0]); @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"recognise (.%C+)")) {
		text_stream *ext = Str::duplicate(mr.exp[0]);
		ADD_TO_LINKED_LIST(ext, text_stream, S->recognised_filename_extensions);
		@<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"set (%c+)")) {
		text_stream *ext = Str::duplicate(mr.exp[0]);
		ADD_TO_LINKED_LIST(ext, text_stream, S->bibliographic_settings);
		@<Setting done@>;
	}

@<Activating or deactivating features@> =
	if (Regexp::match(&mr, cmd, U"use (%c*) with (%c+) and (%c+)")) {
		int arity = 2; @<Act on a use command@>; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"use (%c*) with (%c+)")) {
		int arity = 1; @<Act on a use command@>; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"use (%c*)")) {
		int arity = 0; @<Act on a use command@>; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"do not use (%c*)")) {
		int U = WebNotation::feature_by_name(mr.exp[0]);
		if (U >= 0) WebNotation::does_not_support(S, U);
		else {
			error = Str::new();
			WRITE_TO(error, "unknown feature '%S'", mr.exp[0]);
		}
		@<Setting done@>;
	}

@<Act on a use command@> =
	int U = WebNotation::feature_by_name(mr.exp[0]);
	if (U < 0) {
		error = Str::new();
		WRITE_TO(error, "unknown feature '%S'", mr.exp[0]);
	} else {
		if (arity != WebNotation::feature_notations(U)) {
			error = Str::new();
			WRITE_TO(error, "feature '%S' should have %d notation(s) not %d",
				mr.exp[0], WebNotation::feature_notations(U), arity);
		} else {
			if (arity == 0) WebNotation::does_support(S, U);
			else if (arity == 1) WebNotation::does_support1(S, U, mr.exp[1]);
			else if (arity == 2) WebNotation::does_support2(S, U, mr.exp[1], mr.exp[2]);
		}
	}

@ And, in all cases, this is where we end up.

@<Setting done@> =
	Regexp::dispose_of(&mr);
	return error;

@ The function above made use of this, which parses an |X ==> Y| pattern
into the given list.

=
text_stream *WebNotation::parse_grammar(ls_notation *S, linked_list *rules_list,
	text_stream *pattern, text_stream *outcome) {
	if (rules_list == NULL) internal_error("no list");
	match_results mr = Regexp::create_mr(), mr2 = Regexp::create_mr();
	text_stream *error = NULL;
	int O = -1, C = ANY_WSRULECONTEXT, negate = FALSE, np = FALSE;
	text_stream *match_error = NULL;
	@<Parse conditions on applicability@>;
	@<Parse outcomes@>;

	linked_list *conventions = NEW_LINKED_LIST(ls_conventions);
	ls_conventions *generic = Conventions::generic();
	ADD_TO_LINKED_LIST(generic, ls_conventions, conventions);

	if (Str::len(error) == 0) {
		ls_notation_rule *R = WebNotation::new_rule(O, negate, C, np, match_error);
		R->parsed_from = Str::duplicate(pattern);
		error = WebNotation::parse_pattern(R, pattern, conventions);
		ADD_TO_LINKED_LIST(R, ls_notation_rule, rules_list);
	}

	Regexp::dispose_of(&mr); Regexp::dispose_of(&mr2);
	return error;
}

@<Parse conditions on applicability@> =
	if (Regexp::match(&mr, outcome, U"(%c+) if not (%c+)")) {
		outcome = mr.exp[0];
		text_stream *condition = mr.exp[1];
		negate = TRUE;
		@<Parse applicability condition@>;
	} else if (Regexp::match(&mr, outcome, U"(%c+) if (%c+)")) {
		outcome = mr.exp[0];
		text_stream *condition = mr.exp[1];
		negate = FALSE;
		@<Parse applicability condition@>;
	}

@<Parse applicability condition@> =
	if (Regexp::match(&mr2, condition, U"in (%c+) context")) {
		C = WebNotation::context_by_name(mr2.exp[0]);
		if (C < 0) {
			error = Str::new();
			WRITE_TO(error, "unknown context '%S'", mr2.exp[0]);
			C = ANY_WSRULECONTEXT;
		}
	} else if (Regexp::match(&mr2, condition, U"on first line")) {
		C = FIRST_LINE_WSRULECONTEXT;
	} else if (Regexp::match(&mr2, condition, U"on first line of only file")) {
		C = FIRST_LINE_SF_WSRULECONTEXT;
	} else if (Regexp::match(&mr2, condition, U"following title")) {
		C = FOLLOWING_TITLE_WSRULECONTEXT;
	} else if (Regexp::match(&mr2, condition, U"indented")) {
		C = INDENTED_WSRULECONTEXT;
	} else {
		error = Str::new();
		WRITE_TO(error, "unknown condition '%S'", condition);
	}

@<Parse outcomes@> =
	if (Regexp::match(&mr2, outcome, U"error \"(%c+)\"")) {
		match_error = Str::duplicate(mr2.exp[0]);
		O = COMMENTARY_WSRULEOUTCOME;
	} else {
		if (Regexp::match(&mr2, outcome, U"(%c+) in new paragraph")) {
			outcome = mr2.exp[0];
			np = TRUE;
		}
		O = WebNotation::outcome_by_name(outcome);
		if (O == NO_WSRULEOUTCOME) {
			error = Str::new();
			WRITE_TO(error, "unknown outcome '%S'", outcome);
			O = COMMENTARY_WSRULEOUTCOME;
		}
	}

@ Sneakily, we will in fact reparse the patterns before every web read, in
case it has conventions which override the notation (for example by changing
the holon notation).

=
void WebNotation::prepare_for(ls_notation *S, ls_web *W) {
	// PRINT("Preparing %S for %S\n", S->name, Bibliographic::get_datum(W, I"Title"));
	S->feature_notation1[NAMED_HOLONS_WSF] =
		Str::duplicate(Conventions::get_textual_from(W->conventions, HOLON_NAME_SYNTAX_LSCONVENTION));
	S->feature_notation2[NAMED_HOLONS_WSF] =
		Str::duplicate(Conventions::get_textual2_from(W->conventions, HOLON_NAME_SYNTAX_LSCONVENTION));
	S->feature_notation1[METADATA_IN_STRINGS_WSF] =
		Str::duplicate(Conventions::get_textual_from(W->conventions, METADATA_IN_STRINGS_SYNTAX_LSCONVENTION));
	S->feature_notation2[METADATA_IN_STRINGS_WSF] =
		Str::duplicate(Conventions::get_textual2_from(W->conventions, METADATA_IN_STRINGS_SYNTAX_LSCONVENTION));
	S->feature_notation1[PARAGRAPH_TAGS_WSF] =
		Str::duplicate(Conventions::get_textual_from(W->conventions, TAGS_SYNTAX_LSCONVENTION));
	S->feature_notation2[PARAGRAPH_TAGS_WSF] =
		Str::duplicate(Conventions::get_textual2_from(W->conventions, TAGS_SYNTAX_LSCONVENTION));
	S->supports[FOOTNOTES_IN_COMMENTARY_WSF] =
		Conventions::get_int_from(W->conventions, FOOTNOTES_LSCONVENTION);

	S->supports[TRIMMED_HOLONS_ABOVE_WSF] =
		Conventions::get_int_from(W->conventions, HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION);
	S->supports[TRIMMED_HOLONS_BELOW_WSF] =
		Conventions::get_int_from(W->conventions, HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION);

	ls_notation_rule *R;
	LOOP_OVER_LINKED_LIST(R, ls_notation_rule, S->rules) {
		text_stream *error = WebNotation::parse_pattern(R, R->parsed_from, W->conventions);
		if (Str::len(error) > 0)
			WebErrors::issue_at(error, NULL);
	}
	for (int i = 0; i < NO_DEFINED_WSRULEOUTCOME_VALUES; i++) {
		if (S->residue_rules[i])
			LOOP_OVER_LINKED_LIST(R, ls_notation_rule, S->residue_rules[i]) {
				text_stream *error = WebNotation::parse_pattern(R, R->parsed_from, W->conventions);
				if (Str::len(error) > 0)
					WebErrors::issue_at(error, NULL);
			}
		if (S->options_rules[i])
			LOOP_OVER_LINKED_LIST(R, ls_notation_rule, S->options_rules[i]) {
				text_stream *error = WebNotation::parse_pattern(R, R->parsed_from, W->conventions);
				if (Str::len(error) > 0)
					WebErrors::issue_at(error, NULL);
			}
	}
}

int WebNotation::supports_named_holons(ls_notation *S) {
	if ((Str::len(S->feature_notation1[NAMED_HOLONS_WSF]) > 0) &&
		(Str::len(S->feature_notation2[NAMED_HOLONS_WSF]) > 0)) return TRUE;
	return FALSE;
}

int WebNotation::supports_metadata_in_strings(ls_notation *S) {
	if ((Str::len(S->feature_notation1[METADATA_IN_STRINGS_WSF]) > 0) &&
		(Str::len(S->feature_notation2[METADATA_IN_STRINGS_WSF]) > 0)) return TRUE;
	return FALSE;
}

int WebNotation::supports_paragraph_tags(ls_notation *S) {
	if ((Str::len(S->feature_notation1[PARAGRAPH_TAGS_WSF]) > 0) &&
		(Str::len(S->feature_notation2[PARAGRAPH_TAGS_WSF]) > 0)) return TRUE;
	return FALSE;
}

int WebNotation::commentary_markup(ls_web *W) {
	if (W == NULL) return SIMPLIFIED_COMMENTARY_MARKUPCHOICE;
	return Conventions::get_int(W, COMMENTARY_MARKUP_LSCONVENTION);
}

markdown_variation *WebNotation::commentary_variation(ls_web *W) {
	int markup = WebNotation::commentary_markup(W);
	if (markup == SIMPLIFIED_COMMENTARY_MARKUPCHOICE)
		return MarkdownVariations::simplified_Inweb_flavoured_Markdown();
	return MarkdownVariations::Inweb_flavoured_Markdown();
}

@ So now we dig into the details of these grammar rules. The model for this is
simple: we try a line against a list of rules, and the first which matches
is the winner. Each rule is like so:

=
typedef struct ls_notation_rule {
	/* non-textual conditions for the rule to be applicable */
	int not; /* if |TRUE|, means we must be not in the given context */
	int context; /* one of the |*_WSRULECONTEXT| values below */

	/* pattern which a line must match */
	int no_tokens;
	struct ls_srtoken tokens[MAX_LSSRTOKENS];
	struct text_stream *parsed_from;
	
	/* result of a match */
	int outcome; /* one of the |*_WSRULEOUTCOME| values below */
	int new_paragraph; /* does this line implicitly begin a new para? */
	struct text_stream *error; /* on a match, in fact throw this error */
	CLASS_DEFINITION
} ls_notation_rule;

ls_notation_rule *WebNotation::new_rule(int outcome, int negate, int context, int new_par,
	text_stream *error) {
	ls_notation_rule *R = CREATE(ls_notation_rule);
	R->not = negate;
	R->outcome = outcome;
	R->no_tokens = 0;
	R->parsed_from = NULL;
	R->context = context;
	R->new_paragraph = new_par;
	R->error = error;
	return R;
}

@ The possible contexts are as follows. Note that every line is in the
|ANY_WSRULECONTEXT| context, even if it is also in one of the others.

@e ANY_WSRULECONTEXT from 0
@e FIRST_LINE_WSRULECONTEXT
@e FIRST_LINE_SF_WSRULECONTEXT
@e FOLLOWING_TITLE_WSRULECONTEXT
@e DEFINITION_WSRULECONTEXT
@e EXTRACT_WSRULECONTEXT
@e INDENTED_WSRULECONTEXT

=
int WebNotation::context_by_name(text_stream *context) {
	if (Str::eq(context, I"general"))    return ANY_WSRULECONTEXT;
	if (Str::eq(context, I"first line")) return FIRST_LINE_WSRULECONTEXT;
	if (Str::eq(context, I"first line of single file")) return FIRST_LINE_SF_WSRULECONTEXT;
	if (Str::eq(context, I"following title")) return FOLLOWING_TITLE_WSRULECONTEXT;
	if (Str::eq(context, I"definition")) return DEFINITION_WSRULECONTEXT;
	if (Str::eq(context, I"extract"))    return EXTRACT_WSRULECONTEXT;
	if (Str::eq(context, I"indented"))   return INDENTED_WSRULECONTEXT;
	return -1;
}

@ Now for the textual pattern. We have a very simple model: the line must,
once trailing whitespace is removed, match a sequence of tokens, each of
which is either fixed wording or a wildcard meaning "one or more characters".
The wildcards on a given line are numbered from 0, and each can only appear
once; but they need not occur in numerical order, and need not all be present.

@e MATERIAL_LSWILDCARD from 0
@e SECOND_LSWILDCARD
@e THIRD_LSWILDCARD
@e OPTIONS_LSWILDCARD
@e RESIDUE_LSWILDCARD

@d MAX_LSSRTOKENS (2*NO_DEFINED_LSWILDCARD_VALUES+1)

=
text_stream *WebNotation::parse_pattern(ls_notation_rule *R, text_stream *pattern,
	linked_list *conventions) {
	R->no_tokens = 0;
	TEMPORARY_TEXT(text)
	for (int i=0; i<Str::len(pattern); i++) {
		if (Str::includes_at(pattern, i, I"<OPENHOLON>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual_from(conventions, HOLON_NAME_SYNTAX_LSCONVENTION));
			i += Str::len(I"<OPENHOLON>") - 1; continue;
		}
		if (Str::includes_at(pattern, i, I"<CLOSEHOLON>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual2_from(conventions, HOLON_NAME_SYNTAX_LSCONVENTION));
			i += Str::len(I"<CLOSEHOLON>") - 1; continue;
		}
		if (Str::includes_at(pattern, i, I"<OPENTAG>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual_from(conventions, TAGS_SYNTAX_LSCONVENTION));
			i += Str::len(I"<OPENTAG>") - 1; continue;
		}
		if (Str::includes_at(pattern, i, I"<CLOSETAG>")) {
			WRITE_TO(text, "%S",
				Conventions::get_textual2_from(conventions, TAGS_SYNTAX_LSCONVENTION));
			i += Str::len(I"<CLOSETAG>") - 1; continue;
		}
		PUT_TO(text, Str::get_at(pattern, i));
	}
	int from = 0;
	for (int i=0; i<Str::len(text); i++) {
		if (R->no_tokens + 2 > MAX_LSSRTOKENS) break;
		if (Str::includes_at(text, i, I"MATERIAL")) {
			if (from < i) R->tokens[R->no_tokens++] = WebNotation::fixed(text, from, i-1);
			R->tokens[R->no_tokens++] = WebNotation::wildcard(MATERIAL_LSWILDCARD);
			from = i + Str::len(I"MATERIAL");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"SECOND")) {
			if (from < i) R->tokens[R->no_tokens++] = WebNotation::fixed(text, from, i-1);
			R->tokens[R->no_tokens++] = WebNotation::wildcard(SECOND_LSWILDCARD);
			from = i + Str::len(I"SECOND");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"THIRD")) {
			if (from < i) R->tokens[R->no_tokens++] = WebNotation::fixed(text, from, i-1);
			R->tokens[R->no_tokens++] = WebNotation::wildcard(THIRD_LSWILDCARD);
			from = i + Str::len(I"THIRD");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"OPTIONS")) {
			if (from < i) R->tokens[R->no_tokens++] = WebNotation::fixed(text, from, i-1);
			R->tokens[R->no_tokens++] = WebNotation::wildcard(OPTIONS_LSWILDCARD);
			from = i + Str::len(I"OPTIONS");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"RESIDUE")) {
			if (from < i) R->tokens[R->no_tokens++] = WebNotation::fixed(text, from, i-1);
			R->tokens[R->no_tokens++] = WebNotation::wildcard(RESIDUE_LSWILDCARD);
			from = i + Str::len(I"RESIDUE");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"(WHITESPACE)")) {
			if ((R->no_tokens == 0) || (R->tokens[R->no_tokens-1].wildcard < 0) || (i != from))
				return I"(WHITESPACE) can be used only immediately after a wildcard";
			R->tokens[R->no_tokens-1].whitespace = TRUE;
			from = i + Str::len(I"(WHITESPACE)");
			i = from - 1; continue;
		}
		if (Str::includes_at(text, i, I"(NONWHITESPACE)")) {
			if ((R->no_tokens == 0) || (R->tokens[R->no_tokens-1].wildcard < 0) || (i != from))
				return I"(NONWHITESPACE) can be used only immediately after a wildcard";
			R->tokens[R->no_tokens-1].nonwhitespace = TRUE;
			from = i + Str::len(I"(NONWHITESPACE)");
			i = from - 1; continue;
		}
	}
	if ((from < Str::len(text)) && (R->no_tokens < MAX_LSSRTOKENS))
		R->tokens[R->no_tokens++] = WebNotation::fixed(text, from, Str::len(text)-1);
	int usages[NO_DEFINED_LSWILDCARD_VALUES];
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++) usages[i] = 0;
	for (int i=0; i<R->no_tokens; i++)
		if (R->tokens[i].wildcard >= 0) {
			usages[R->tokens[i].wildcard]++;
			if ((i < R->no_tokens - 1) && (R->tokens[i+1].wildcard >= 0)) {
				R->no_tokens = 1;
				return I"two consecutive wildcards in pattern";
			}
		}
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++)
		if (usages[i] > 1) {
			R->no_tokens = 1;
			return I"wildcards can be used only once each in a pattern";
		}
	DISCARD_TEXT(text)
	return NULL;
}

typedef struct ls_srtoken {
	struct text_stream *fixed_content;
	int wildcard;
	int whitespace;
	int nonwhitespace;
} ls_srtoken;

ls_srtoken WebNotation::fixed(text_stream *text, int from, int to) {
	ls_srtoken tok;
	tok.fixed_content = Str::new();
	for (int j=from; j<=to; j++) PUT_TO(tok.fixed_content, Str::get_at(text, j));
	tok.wildcard = -1;
	tok.whitespace = FALSE;
	tok.nonwhitespace = FALSE;
	return tok;
}

ls_srtoken WebNotation::wildcard(int n) {
	if ((n < MATERIAL_LSWILDCARD) || (n >= NO_DEFINED_LSWILDCARD_VALUES))
		internal_error("wildcard out of range");
	ls_srtoken tok;
	tok.fixed_content = NULL;
	tok.wildcard = n;
	tok.whitespace = FALSE;
	tok.nonwhitespace = FALSE;
	return tok;
}

@ Note that |NO_WSRULEOUTCOME| is never the outcome of any rule: it's a value
used to mean "nothing matched".

@e NO_WSRULEOUTCOME from 0

@e AUDIO_WSRULEOUTCOME
@e BEGINPARAGRAPH_WSRULEOUTCOME
@e BREAK_WSRULEOUTCOME
@e CAROUSELABOVE_WSRULEOUTCOME
@e CAROUSELBELOW_WSRULEOUTCOME
@e CAROUSELEND_WSRULEOUTCOME
@e CAROUSELSLIDE_WSRULEOUTCOME
@e CODE_WSRULEOUTCOME
@e CODEEXTRACT_WSRULEOUTCOME
@e COMBINED_WSRULEOUTCOME
@e COMMENTARY_WSRULEOUTCOME
@e DEFAULT_DEFINITION_WSRULEOUTCOME
@e DEFINITION_CONTINUED_WSRULEOUTCOME
@e DEFINITION_WSRULEOUTCOME
@e DOWNLOAD_WSRULEOUTCOME
@e EARLYCODEEXTRACT_WSRULEOUTCOME
@e EMBEDDEDVIDEO_WSRULEOUTCOME
@e ENDEXTRACT_WSRULEOUTCOME
@e ENUMERATION_WSRULEOUTCOME
@e EXTRACT_WSRULEOUTCOME
@e FIGURE_WSRULEOUTCOME
@e HEADING_WSRULEOUTCOME
@e HTML_WSRULEOUTCOME
@e HYPERLINKED_WSRULEOUTCOME
@e NAMEDCODEFRAGMENT_WSRULEOUTCOME
@e NAMEDCODEFRAGMENTADDENDUM_WSRULEOUTCOME
@e PARAGRAPHTAG_WSRULEOUTCOME
@e PARAGRAPHTITLING_WSRULEOUTCOME
@e PURPOSE_WSRULEOUTCOME
@e QUOTATION_WSRULEOUTCOME
@e SECTIONTITLE_WSRULEOUTCOME
@e TEXTASCODEEXTRACT_WSRULEOUTCOME
@e TEXTEXTRACT_WSRULEOUTCOME
@e TEXTEXTRACTTO_WSRULEOUTCOME
@e TITLE_WSRULEOUTCOME
@e TITLEANDAUTHOR_WSRULEOUTCOME
@e UNDISPLAYED_WSRULEOUTCOME
@e VERYEARLYCODEEXTRACT_WSRULEOUTCOME
@e VIDEO_WSRULEOUTCOME

@e WEBWIDEHOLON_WSRULEOUTCOME
@e VERYEARLYHOLON_WSRULEOUTCOME
@e EARLYHOLON_WSRULEOUTCOME
@e LATEHOLON_WSRULEOUTCOME
@e VERYLATEHOLON_WSRULEOUTCOME

=
int WebNotation::outcome_by_name(text_stream *outcome) {
	if (Str::eq(outcome, I"audio"))                return AUDIO_WSRULEOUTCOME;
	if (Str::eq(outcome, I"beginparagraph"))       return BEGINPARAGRAPH_WSRULEOUTCOME;
	if (Str::eq(outcome, I"break"))                return BREAK_WSRULEOUTCOME;
	if (Str::eq(outcome, I"carouselaboveslide"))   return CAROUSELABOVE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"carouselbelowslide"))   return CAROUSELBELOW_WSRULEOUTCOME;
	if (Str::eq(outcome, I"carouselend"))          return CAROUSELEND_WSRULEOUTCOME;
	if (Str::eq(outcome, I"carouselslide"))        return CAROUSELSLIDE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"code"))                 return CODE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"codeextract"))          return CODEEXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"commentary"))           return COMMENTARY_WSRULEOUTCOME;
	if (Str::eq(outcome, I"defaultdefinition"))    return DEFAULT_DEFINITION_WSRULEOUTCOME;
	if (Str::eq(outcome, I"definition"))           return DEFINITION_WSRULEOUTCOME;
	if (Str::eq(outcome, I"definitioncontinued"))  return DEFINITION_CONTINUED_WSRULEOUTCOME;
	if (Str::eq(outcome, I"download"))             return DOWNLOAD_WSRULEOUTCOME;
	if (Str::eq(outcome, I"earlycodeextract"))     return EARLYCODEEXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"embeddedvideo"))        return EMBEDDEDVIDEO_WSRULEOUTCOME;
	if (Str::eq(outcome, I"endextract"))           return ENDEXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"enumeration"))          return ENUMERATION_WSRULEOUTCOME;
	if (Str::eq(outcome, I"extract"))              return EXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"figure"))               return FIGURE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"heading"))              return HEADING_WSRULEOUTCOME;
	if (Str::eq(outcome, I"html"))                 return HTML_WSRULEOUTCOME;
	if (Str::eq(outcome, I"hyperlinked"))          return HYPERLINKED_WSRULEOUTCOME;
	if (Str::eq(outcome, I"namedcodefragment"))    return NAMEDCODEFRAGMENT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"namedcodefragmentaddendum")) return NAMEDCODEFRAGMENTADDENDUM_WSRULEOUTCOME;
	if (Str::eq(outcome, I"paragraphtag"))         return PARAGRAPHTAG_WSRULEOUTCOME;
	if (Str::eq(outcome, I"paragraphtitling"))     return PARAGRAPHTITLING_WSRULEOUTCOME;
	if (Str::eq(outcome, I"purpose"))              return PURPOSE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"quotation"))            return QUOTATION_WSRULEOUTCOME;
	if (Str::eq(outcome, I"sectiontitle"))         return SECTIONTITLE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"textascodeextract"))    return TEXTASCODEEXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"textextract"))          return TEXTEXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"textextractto"))        return TEXTEXTRACTTO_WSRULEOUTCOME;
	if (Str::eq(outcome, I"title"))                return TITLE_WSRULEOUTCOME;
	if (Str::eq(outcome, I"titleandauthor"))       return TITLEANDAUTHOR_WSRULEOUTCOME;
	if (Str::eq(outcome, I"titleandpurpose"))      return COMBINED_WSRULEOUTCOME;
	if (Str::eq(outcome, I"undisplayed"))          return UNDISPLAYED_WSRULEOUTCOME;
	if (Str::eq(outcome, I"veryearlycodeextract")) return VERYEARLYCODEEXTRACT_WSRULEOUTCOME;
	if (Str::eq(outcome, I"video"))                return VIDEO_WSRULEOUTCOME;

	if (Str::eq(outcome, I"webwideholon"))         return WEBWIDEHOLON_WSRULEOUTCOME;
	if (Str::eq(outcome, I"veryearlyholon"))       return VERYEARLYHOLON_WSRULEOUTCOME;
	if (Str::eq(outcome, I"earlyholon"))           return EARLYHOLON_WSRULEOUTCOME;
	if (Str::eq(outcome, I"lateholon"))            return LATEHOLON_WSRULEOUTCOME;
	if (Str::eq(outcome, I"verylateholon"))        return VERYLATEHOLON_WSRULEOUTCOME;
	return NO_WSRULEOUTCOME;
}

@h Matching text to grammar.
We find the first rule in the list which applies to the given text, and return
it; if none apply, we return |NULL|. If a match is made, then the content of any
wildcards is written into the supplied array.

First we check the context to see whether a rule can apply:

=
ls_notation_rule *WebNotation::match(linked_list *rules_list, text_stream *full_text,
	int whitespace_nature, text_stream **wildcards, ls_class *previously, int single_file,
	ls_notation *S) {
	int top_flag = FALSE, trace = FALSE;
	if (previously->major == UNCLASSIFIED_MAJLC) top_flag = TRUE;
	ls_notation_rule *R;
	if (trace) WRITE_TO(STDERR, "Match %S (wsn %d, pwsn %d, psft %d)\n",
		full_text, whitespace_nature, previously->whitespace_nature, previously->follows_title);

	LOOP_OVER_LINKED_LIST(R, ls_notation_rule, rules_list) {
		int applies = FALSE;
		switch (R->context) {
			case FIRST_LINE_WSRULECONTEXT:
				if (top_flag) applies = TRUE; break;
			case FIRST_LINE_SF_WSRULECONTEXT:
				if ((single_file) && (top_flag)) applies = TRUE; break;
			case FOLLOWING_TITLE_WSRULECONTEXT:
				if (previously->follows_title) applies = TRUE; break;
			case INDENTED_WSRULECONTEXT:
				if ((whitespace_nature == WHITE_LINESHADE) && (previously->whitespace_nature == BLACK_LINESHADE))
					applies = FALSE;
				else if ((whitespace_nature != BLACK_LINESHADE) && (previously->whitespace_nature != BLACK_LINESHADE))
					applies = TRUE;
				break;
			case DEFINITION_WSRULECONTEXT:
				if (LineClassification::definition_lines_can_follow(
					previously->major, previously->minor)) applies = TRUE;
				break;
			case EXTRACT_WSRULECONTEXT:
				if (LineClassification::extract_lines_can_follow(
					previously->major, previously->minor)) applies = TRUE;
				break;
			default:
				applies = TRUE;
				break;
		}
		switch (R->outcome) {
			case PARAGRAPHTAG_WSRULEOUTCOME:
				if (WebNotation::supports_paragraph_tags(S) == FALSE) applies = (R->not)?FALSE:TRUE;
				break;
		}
		
		if (R->not != applies) {
			if (R->context == INDENTED_WSRULECONTEXT) {
				TEMPORARY_TEXT(text)
				int wsc = 0, on = FALSE;
				for (int i=0; i<Str::len(full_text); i++) {
					inchar32_t c = Str::get_at(full_text, i);
					if (on) {
						PUT_TO(text, c);
					} else {
						if (c == ' ') wsc++;
						else if (c == '\t') wsc = (wsc/4+1)*4;
						if (wsc == 4) on = TRUE;
					}
				}
				@<Try to find a match against the text@>;
				DISCARD_TEXT(text)
			} else {
				text_stream *text = full_text;
				@<Try to find a match against the text@>;
			}
		}
	}
	return NULL;
}

@ And now we try to make a textual match. Note that we clear the wildcard
variables each time, since otherwise we could have results from a previous
partial but failed match lingering on into a successful one.

Note that an empty token list matches only a whitespace line, since the text
we are matching has already had its whitespace at each end trimmed, so that
a whitespace line leads to the empty text here.

@<Try to find a match against the text@> =
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++)
		if (wildcards[i]) Str::clear(wildcards[i]);
	int match_from = 0, match_to = R->no_tokens - 1;
	int p_from = 0, p_to = Str::len(text) - 1;
	while (match_from <= match_to) {
		if (trace) WRITE_TO(STDERR, "Match tokens %d to %d, chars %c to %c\n",
			match_from, match_to, Str::get_at(text, p_from), Str::get_at(text, p_to));
		@<If the leftmost token is fixed text, check that it matches@>;
		@<If the rightmost token is fixed text, check that it matches@>;
		@<If only one token is left, it must be a wildcard, so copy the remaining text into it@>;
		@<At this point, the leftmost tokens must be a wildcard followed by fixed text, so look ahead@>;
	}
	if ((match_from > match_to) && (p_from > p_to)) @<Return a match@>;
	if (trace) WRITE_TO(STDERR, "Failure\n");

@<If the leftmost token is fixed text, check that it matches@> =
	if (R->tokens[match_from].wildcard < 0) {
		text_stream *prefix = R->tokens[match_from].fixed_content;
		if (Str::includes_at(text, p_from, prefix) == FALSE) break;
		p_from += Str::len(prefix);
		match_from++;
		continue;
	}

@<If the rightmost token is fixed text, check that it matches@> =
	if (R->tokens[match_to].wildcard < 0) {
		text_stream *suffix = R->tokens[match_to].fixed_content;
		if (Str::includes_at(text, p_to - Str::len(suffix) + 1, suffix) == FALSE) break;
		p_to -= Str::len(suffix);
		match_to--;
		continue;
	}

@<If only one token is left, it must be a wildcard, so copy the remaining text into it@> =
	if (match_from == match_to) {
		text_stream *WT = wildcards[R->tokens[match_from].wildcard];
		Str::substr(WT, Str::at(text, p_from), Str::at(text, p_to+1));
		if ((R->tokens[match_from].nonwhitespace) &&
			((Str::includes_character(WT, ' ')) || (Str::includes_character(WT, '\t'))))
			break;
		if ((R->tokens[match_from].whitespace) && (Str::is_whitespace(WT) == FALSE))
			break;
		p_from = p_to + 1;
		match_from++;
		continue;
	}

@ The leftmost token must be a wildcard because if it were fixed wording then
we would have checked it already; it cannot be the only token, because we've
just handled that case; so there is a next token, which cannot be a wildcard
because we cannot have two consecutive wildcards. And therefore...

Note that we use a non-greedy algorithm, i.e., we make the earliest match
possible, and with no backtracking to check other possibilities. This is a
deliberately simple parser, intended to work quickly on simple unambiguous
grammars.

@<At this point, the leftmost tokens must be a wildcard followed by fixed text, so look ahead@> =
	if (R->tokens[match_from+1].wildcard >= 0) internal_error("consecutive wildcard tokens");
	int lookahead = p_from+1, l_to = p_to - Str::len(R->tokens[match_from+1].fixed_content);
	for (; lookahead <= l_to; lookahead++)
		if (Str::includes_at(text, lookahead, R->tokens[match_from+1].fixed_content)) {
			text_stream *WT = wildcards[R->tokens[match_from].wildcard];
			Str::substr(WT, Str::at(text, p_from), Str::at(text, lookahead));
			p_from = lookahead + Str::len(R->tokens[match_from+1].fixed_content);
			match_from += 2;
			break;					
		} else if ((R->tokens[match_from].nonwhitespace) && (Characters::is_whitespace(Str::get_at(text, lookahead))))
			lookahead = l_to + 1;
	if (lookahead > l_to) break;

@<Return a match@> =
	if (trace) WRITE_TO(STDERR, "Success with outcome %d\n", R->outcome);
	return R;
