[Conventions::] Conventions.

To manage "conventions", tweaks to Inweb's normal behaviour, which may be
associated with any Inweb resource.

@h Levels of conventions.
There are numerous ways to make preference settings (well, six), and we need
to adjudicate which take precedence over which. High levels beat low ones:

@e GENERIC_LSCONVENTIONLEVEL from 1
@e NOTATION_LSCONVENTIONLEVEL
@e LANGUAGE_LSCONVENTIONLEVEL
@e PERSONAL_LSCONVENTIONLEVEL
@e COLONY_LSCONVENTIONLEVEL
@e WEB_LSCONVENTIONLEVEL

@h Conventions.
And the individual conventions are also enumerated:

@e PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION from 0
@e NAMESPACES_ENFORCED_LSCONVENTION
@e SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION
@e TEX_NOTATION_LSCONVENTION
@e FOOTNOTES_LSCONVENTION
@e HOLON_NAME_SYNTAX_LSCONVENTION
@e METADATA_IN_STRINGS_SYNTAX_LSCONVENTION
@e TAGS_SYNTAX_LSCONVENTION
@e HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION
@e HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION
@e HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION
@e COMMENTARY_MARKUP_LSCONVENTION
@e SUMMARY_UNDER_TITLE_LSCONVENTION
@e SINGLE_FILE_METADATA_PAIRS_LSCONVENTION

@e INT_LSCONVENTIONTYPE from 1
@e TEXTUAL_LSCONVENTIONTYPE
@e TEXTUAL_PAIR_LSCONVENTIONTYPE
@e BOTH_LSCONVENTIONTYPE

=
int Conventions::type(int conv) {
	if ((conv < 0) || (conv >= NO_DEFINED_LSCONVENTION_VALUES)) internal_error("convention out of range");
	switch (conv) {
		case PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION:
		case NAMESPACES_ENFORCED_LSCONVENTION:
		case SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION:
		case TEX_NOTATION_LSCONVENTION:
		case FOOTNOTES_LSCONVENTION:
		case HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION:
		case HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION:
		case HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION:
		case COMMENTARY_MARKUP_LSCONVENTION:
		case SUMMARY_UNDER_TITLE_LSCONVENTION:
		case SINGLE_FILE_METADATA_PAIRS_LSCONVENTION:
			return INT_LSCONVENTIONTYPE;
		case HOLON_NAME_SYNTAX_LSCONVENTION:
		case METADATA_IN_STRINGS_SYNTAX_LSCONVENTION:
		case TAGS_SYNTAX_LSCONVENTION:
			return TEXTUAL_PAIR_LSCONVENTIONTYPE;
	}
	internal_error("unimplemented convention");
}

@ In particular, |COMMENTARY_MARKUP_LSCONVENTION| has to be one of these:

@e MARKDOWN_COMMENTARY_MARKUPCHOICE from 1
@e SIMPLIFIED_COMMENTARY_MARKUPCHOICE
@e TEX_COMMENTARY_MARKUPCHOICE

@ And |SUMMARY_UNDER_TITLE_LSCONVENTION| must be one of:

@e PURPOSE_SUMMARYCHOICE from 1
@e PURPOSE_IF_ITALIC_SUMMARYCHOICE
@e NO_SUMMARYCHOICE

=
void Conventions::describe(OUTPUT_STREAM, int conv, int iv, text_stream *tv, text_stream *tv2) {
	if ((conv < 0) || (conv >= NO_DEFINED_LSCONVENTION_VALUES)) internal_error("convention out of range");
	switch (conv) {
		case PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION:
			if (iv) WRITE("paragraph numbers are visible");
			else WRITE("paragraph numbers are invisible");
			break;
		case NAMESPACES_ENFORCED_LSCONVENTION:
			if (iv) WRITE("namespaces are enforced");
			else WRITE("namespaces are unenforced");
			break;
		case SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION:
			if (iv) WRITE("sections are numbered sequentially");
			else WRITE("sections are not numbered sequentially");
			break;
		case SINGLE_FILE_METADATA_PAIRS_LSCONVENTION:
			if (iv) WRITE("metadata key-value pairs are allowed at the top of single-file webs");
			else WRITE("metadata key-value pairs are not allowed at the top of single-file webs");
			break;
		case TEX_NOTATION_LSCONVENTION:
			if (iv) WRITE("TeX notation is used for mathematics");
			else WRITE("TeX notation is not used for mathematics");
			break;
		case FOOTNOTES_LSCONVENTION:
			if (iv) WRITE("footnotes are recognised");
			else WRITE("footnotes are not recognised");
			break;
		case HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION:
			if (iv) WRITE("holon names can be abbreviated");
			else WRITE("holon names cannot be abbreviated");
			break;
		case HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION:
			if (iv) WRITE("whitespace lines opening holons are not tangled");
			else WRITE("whitespace lines opening holons are tangled");
			break;
		case HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION:
			if (iv) WRITE("whitespace lines closing holons are not tangled");
			else WRITE("whitespace lines closing holons are tangled");
			break;
		case HOLON_NAME_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("holons are not named");
			else WRITE("holon names are written between %S and %S", tv, tv2);
			break;
		case TAGS_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("paragraph tags are not recognised");
			else WRITE("paragraph tags are written between %S and %S", tv, tv2);
			break;
		case METADATA_IN_STRINGS_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("metadata in strings are not recognised");
			else WRITE("metadata in strings are written between %S and %S", tv, tv2);
			break;
		case COMMENTARY_MARKUP_LSCONVENTION:
			switch (iv) {
				case MARKDOWN_COMMENTARY_MARKUPCHOICE:
					WRITE("commentary uses Markdown notation"); break;
				case SIMPLIFIED_COMMENTARY_MARKUPCHOICE:
					WRITE("commentary uses simplified notation"); break;
				case TEX_COMMENTARY_MARKUPCHOICE:
					WRITE("commentary uses TeX notation"); break;
			}
			break;
		case SUMMARY_UNDER_TITLE_LSCONVENTION:
			switch (iv) {
				case PURPOSE_SUMMARYCHOICE:
					WRITE("read a summary under the title as the purpose"); break;
				case PURPOSE_IF_ITALIC_SUMMARYCHOICE:
					WRITE("read an italicised summary under the title as the purpose"); break;
				case NO_SUMMARYCHOICE:
					WRITE("do not read a summary under the title as the purpose"); break;
			}
			break;
		default:
			internal_error("unimplemented convention");
	}
}

@h Convention sets.

=
typedef struct ls_conventions {
	int level; /* one of the |*_LSCONVENTIONLEVEL| values above */
	int setting_made[NO_DEFINED_LSCONVENTION_VALUES]; /* |TRUE| only if an explicit choice made */
	int integer_value[NO_DEFINED_LSCONVENTION_VALUES];
	struct text_stream *textual_value[NO_DEFINED_LSCONVENTION_VALUES];
	struct text_stream *textual_value2[NO_DEFINED_LSCONVENTION_VALUES];
	CLASS_DEFINITION
} ls_conventions;

ls_conventions *Conventions::new_set(int level) {
	ls_conventions *conventions = CREATE(ls_conventions);
	conventions->level = level;
	for (int i=0; i<NO_DEFINED_LSCONVENTION_VALUES; i++) {
		conventions->setting_made[i] = FALSE;
		conventions->integer_value[i] = 0;
		conventions->textual_value[i] = NULL;
		conventions->textual_value2[i] = NULL;
	}
	return conventions;
}

void Conventions::set_both(ls_conventions *conventions, int conv, int val, text_stream *text, text_stream *text2) {
	if (conventions == NULL) internal_error("no conventions");
	if ((conv < 0) || (conv >= NO_DEFINED_LSCONVENTION_VALUES)) internal_error("convention out of range");
	conventions->setting_made[conv] = TRUE;
	conventions->integer_value[conv] = val;
	conventions->textual_value[conv] = (text)?(Str::duplicate(text)):NULL;
	conventions->textual_value2[conv] = (text2)?(Str::duplicate(text2)):NULL;
}

void Conventions::set_int(ls_conventions *conventions, int conv, int val) {
	Conventions::set_both(conventions, conv, val, NULL, NULL);
}

void Conventions::set_textual(ls_conventions *conventions, int conv, text_stream *text, text_stream *text2) {
	Conventions::set_both(conventions, conv, 0, text, text2);
}

@h Setting values.

=
void Conventions::parse_declaration(wcl_declaration *D) {
	ls_conventions *conventions = Conventions::new_set(GENERIC_LSCONVENTIONLEVEL);
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		Str::trim_white_space(line);
		text_stream *err = Conventions::parse_line(conventions, line);
		if (Str::len(err) > 0) WCL::error(D, &tfp, err);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	D->object_declared = STORE_POINTER_ls_conventions(conventions);
}

text_stream *Conventions::parse_line(ls_conventions *conventions, text_stream *line) {
	int iv = 0;
	text_stream *tv = NULL, *tv2 = NULL;
	int conv = -1;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U" *paragraph numbers are visible *")) {
		conv = PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *paragraph numbers are invisible *")) {
		conv = PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *namespaces are enforced *")) {
		conv = NAMESPACES_ENFORCED_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *namespaces are unenforced *")) {
		conv = NAMESPACES_ENFORCED_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *sections are numbered sequentially *")) {
		conv = SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *sections are not numbered sequentially *")) {
		conv = SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *metadata key-value pairs are allowed at the top of single-file webs *")) {
		conv = SINGLE_FILE_METADATA_PAIRS_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *metadata key-value pairs are not allowed at the top of single-file webs *")) {
		conv = SINGLE_FILE_METADATA_PAIRS_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *TeX notation is used for mathematics *")) {
		conv = TEX_NOTATION_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *TeX notation is not used for mathematics *")) {
		conv = TEX_NOTATION_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *footnotes are recognised *")) {
		conv = FOOTNOTES_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *footnotes are not recognised *")) {
		conv = FOOTNOTES_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *whitespace lines opening holons are not tangled *")) {
		conv = HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *whitespace lines opening holons are tangled *")) {
		conv = HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *whitespace lines closing holons are not tangled *")) {
		conv = HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *whitespace lines closing holons are tangled *")) {
		conv = HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *holon names can be abbreviated *")) {
		conv = HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *holon names cannot be abbreviated *")) {
		conv = HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *holon names are written between (%c+) and (%c+) *")) {
		conv = HOLON_NAME_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *holons are not named *")) {
		conv = HOLON_NAME_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *metadata in strings are written between (%c+) and (%c+) *")) {
		conv = METADATA_IN_STRINGS_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *metadata in strings are not recognised *")) {
		conv = METADATA_IN_STRINGS_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *paragraph tags are written between (%c+) and (%c+) *")) {
		conv = TAGS_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *paragraph tags are not recognised *")) {
		conv = TAGS_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *commentary uses Markdown notation *")) {
		conv = COMMENTARY_MARKUP_LSCONVENTION; iv = MARKDOWN_COMMENTARY_MARKUPCHOICE;
	} else if (Regexp::match(&mr, line, U" *commentary uses simplified notation *")) {
		conv = COMMENTARY_MARKUP_LSCONVENTION; iv = SIMPLIFIED_COMMENTARY_MARKUPCHOICE;
	} else if (Regexp::match(&mr, line, U" *commentary uses TeX notation *")) {
		conv = COMMENTARY_MARKUP_LSCONVENTION; iv = TEX_COMMENTARY_MARKUPCHOICE;
	} else if (Regexp::match(&mr, line, U" *read a summary under the title as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = PURPOSE_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *read an italicised summary under the title as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = PURPOSE_IF_ITALIC_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *read an italicized summary under the title as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = PURPOSE_IF_ITALIC_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *do not read a summary under the title as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = NO_SUMMARYCHOICE;
	} else {
		text_stream *err = Str::new();
		WRITE_TO(err, "unknown convention: %S", line);
		return err;
	}
	Regexp::dispose_of(&mr);
	switch (Conventions::type(conv)) {
		case INT_LSCONVENTIONTYPE:     Conventions::set_int(conventions, conv, iv); break;
		case TEXTUAL_LSCONVENTIONTYPE: Conventions::set_textual(conventions, conv, tv, NULL); break;
		case TEXTUAL_PAIR_LSCONVENTIONTYPE: Conventions::set_textual(conventions, conv, tv, tv2); break;
		case BOTH_LSCONVENTIONTYPE:    Conventions::set_both(conventions, conv, iv, tv, NULL); break;
	}
	return NULL;
}

@ =
void Conventions::resolve_declaration(wcl_declaration *D) {
}

void Conventions::set_level(wcl_declaration *D, int level) {
	wcl_declaration *X;
	LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations) {
		if (X->declaration_type == CONVENTIONS_WCLTYPE) {
			ls_conventions *conventions = RETRIEVE_POINTER_ls_conventions(X->object_declared);
			conventions->level = level;
		}
	}
}

void Conventions::apply(linked_list *L, wcl_declaration *D) {
	wcl_declaration *X;
	LOOP_OVER_LINKED_LIST(X, wcl_declaration, D->declarations) {
		if (X->declaration_type == CONVENTIONS_WCLTYPE) {
			ls_conventions *conventions = RETRIEVE_POINTER_ls_conventions(X->object_declared);
			ADD_TO_LINKED_LIST(conventions, ls_conventions, L);
		}
	}
}

@h Retrieving values.

=
ls_conventions *Conventions::find(linked_list *L, int conv) {
	if (L == NULL) internal_error("no list");
	if ((conv < 0) || (conv >= NO_DEFINED_LSCONVENTION_VALUES)) internal_error("convention out of range");
	ls_conventions *conventions = NULL, *C;
	LOOP_OVER_LINKED_LIST(C, ls_conventions, L)
		if (C->setting_made[conv])
			conventions = C;
	if (conventions == NULL) internal_error("unresolved convention");
	return conventions;
}

int Conventions::get_int_from(linked_list *L, int conv) {
	ls_conventions *conventions = Conventions::find(L, conv);
	return conventions->integer_value[conv];
}

text_stream *Conventions::get_textual_from(linked_list *L, int conv) {
	ls_conventions *conventions = Conventions::find(L, conv);
	return conventions->textual_value[conv];
}

text_stream *Conventions::get_textual2_from(linked_list *L, int conv) {
	ls_conventions *conventions = Conventions::find(L, conv);
	return conventions->textual_value2[conv];
}

void Conventions::diagnose(OUTPUT_STREAM, linked_list *L, int fuller) {
	for (int conv=0; conv<NO_DEFINED_LSCONVENTION_VALUES; conv++) {
		ls_conventions *C, *last = NULL;
		LOOP_OVER_LINKED_LIST(C, ls_conventions, L)
			if (C->setting_made[conv])
				last = C;
		LOOP_OVER_LINKED_LIST(C, ls_conventions, L)
			if (C->setting_made[conv]) {
				if ((fuller) || (C == last)) {
					switch (C->level) {
						case GENERIC_LSCONVENTIONLEVEL:  WRITE("(generic)  "); break;
						case NOTATION_LSCONVENTIONLEVEL: WRITE("(notation) "); break;
						case LANGUAGE_LSCONVENTIONLEVEL: WRITE("(language) "); break;
						case PERSONAL_LSCONVENTIONLEVEL: WRITE("(-using)   "); break;
						case COLONY_LSCONVENTIONLEVEL:   WRITE("(colony)   "); break;
						case WEB_LSCONVENTIONLEVEL:      WRITE("(web)      "); break;
					}
					Conventions::describe(OUT, conv, C->integer_value[conv], C->textual_value[conv], C->textual_value2[conv]);
					WRITE("\n");
				}
			}
	}
}

@h Setting and retrieving for a web.

=
ls_conventions *Conventions::generic(void) {
	static ls_conventions *generic = NULL;
	if (generic == NULL) {
		generic = Conventions::new_set(GENERIC_LSCONVENTIONLEVEL);

		Conventions::set_int(generic, PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION, TRUE);
		Conventions::set_int(generic, NAMESPACES_ENFORCED_LSCONVENTION, FALSE);
		Conventions::set_int(generic, SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION, FALSE);
		Conventions::set_int(generic, SINGLE_FILE_METADATA_PAIRS_LSCONVENTION, TRUE);
		Conventions::set_int(generic, HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION, FALSE);
		Conventions::set_int(generic, HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION, FALSE);
		Conventions::set_int(generic, TEX_NOTATION_LSCONVENTION, TRUE);
		Conventions::set_int(generic, FOOTNOTES_LSCONVENTION, TRUE);
		Conventions::set_int(generic, HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION, TRUE);
		Conventions::set_int(generic, COMMENTARY_MARKUP_LSCONVENTION, SIMPLIFIED_COMMENTARY_MARKUPCHOICE);
		Conventions::set_int(generic, SUMMARY_UNDER_TITLE_LSCONVENTION, NO_SUMMARYCHOICE);

		Conventions::set_textual(generic, HOLON_NAME_SYNTAX_LSCONVENTION, I"{{", I"}}");
		Conventions::set_textual(generic, METADATA_IN_STRINGS_SYNTAX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, TAGS_SYNTAX_LSCONVENTION, NULL, NULL);
	}
	return generic;
}

linked_list *Conventions::applicable(ls_web *W, ls_colony *C) {
	ls_conventions *generic = Conventions::generic();
	linked_list *L = NEW_LINKED_LIST(ls_conventions);
	ADD_TO_LINKED_LIST(generic, ls_conventions, L);
	if (W) {
		ls_notation *N = W->web_syntax;
		if (N) Conventions::apply(L, N->declaration);
		programming_language *pl = W->web_language;
		if (pl) Conventions::apply(L, pl->declaration);
	}
	Conventions::set_level(WCL::global_resources_declaration(), PERSONAL_LSCONVENTIONLEVEL);
	Conventions::apply(L, WCL::global_resources_declaration());
	if (C) Conventions::apply(L, C->declaration);
	if (W) Conventions::apply(L, W->declaration);
	return L;
}

void Conventions::establish(ls_web *W, ls_colony *C) {
	W->conventions = Conventions::applicable(W, C);
}

void Conventions::show(OUTPUT_STREAM, ls_web *W, int fuller) {
	Conventions::diagnose(OUT, W->conventions, fuller);
}

int Conventions::get_int(ls_web *W, int conv) {
	return Conventions::get_int_from(W->conventions, conv);
}

text_stream *Conventions::get_textual(ls_web *W, int conv) {
	return Conventions::get_textual_from(W->conventions, conv);
}

text_stream *Conventions::get_textual2(ls_web *W, int conv) {
	return Conventions::get_textual2_from(W->conventions, conv);
}
