[Conventions::] Conventions.

To manage "conventions", tweaks to Inweb's normal behaviour, which may be
associated with any Inweb resource.

@h Levels of conventions.
There are numerous ways to make preference settings (well, six), and we need
to adjudicate which take precedence over which. High levels beat low ones:

@e GENERIC_LSCONVENTIONLEVEL from 1
@e LANGUAGE_LSCONVENTIONLEVEL
@e NOTATION_LSCONVENTIONLEVEL
@e PERSONAL_LSCONVENTIONLEVEL
@e COLONY_LSCONVENTIONLEVEL
@e WEB_LSCONVENTIONLEVEL

@h Conventions.
And the individual conventions are also enumerated:

@e PARAGRAPH_NUMBERS_VISIBLE_LSCONVENTION from 0
@e NAMESPACES_ENFORCED_LSCONVENTION
@e SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION
@e PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION
@e TEX_NOTATION_LSCONVENTION
@e FOOTNOTES_LSCONVENTION
@e HOLON_NAME_SYNTAX_LSCONVENTION
@e FILE_HOLON_NAME_SYNTAX_LSCONVENTION
@e VERBATIM_LSCONVENTION
@e METADATA_IN_STRINGS_SYNTAX_LSCONVENTION
@e TAGS_SYNTAX_LSCONVENTION
@e HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION
@e HOLONS_STYLED_LSCONVENTION
@e COMMENTS_STYLED_LSCONVENTION
@e HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION
@e HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION
@e TANGLED_BETWEEN_LSCONVENTION
@e COMMENTARY_MARKUP_LSCONVENTION
@e SUMMARY_UNDER_TITLE_LSCONVENTION
@e SINGLE_FILE_METADATA_PAIRS_LSCONVENTION
@e LIBRARY_INCLUDES_EARLY_LSCONVENTION
@e TYPEDEFS_EARLY_LSCONVENTION
@e TYPEDEF_STRUCTS_EARLY_LSCONVENTION
@e FUNCTION_PREDECLARATIONS_LSCONVENTION
@e COMMENTS_LSCONVENTION
@e INDEX_LSCONVENTION
@e IMPORTANT_INDEX_LSCONVENTION
@e TT_INDEX_LSCONVENTION
@e IMPORTANT_TT_INDEX_LSCONVENTION
@e NS_INDEX_LSCONVENTION
@e IMPORTANT_NS_INDEX_LSCONVENTION
@e LITERAL_CHARACTERS_LSCONVENTION

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
		case PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION:
		case TEX_NOTATION_LSCONVENTION:
		case FOOTNOTES_LSCONVENTION:
		case HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION:
		case HOLONS_STYLED_LSCONVENTION:
		case COMMENTS_STYLED_LSCONVENTION:
		case HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION:
		case HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION:
		case COMMENTARY_MARKUP_LSCONVENTION:
		case SUMMARY_UNDER_TITLE_LSCONVENTION:
		case SINGLE_FILE_METADATA_PAIRS_LSCONVENTION:
		case LIBRARY_INCLUDES_EARLY_LSCONVENTION:
		case TYPEDEFS_EARLY_LSCONVENTION:
		case TYPEDEF_STRUCTS_EARLY_LSCONVENTION:
		case FUNCTION_PREDECLARATIONS_LSCONVENTION:
			return INT_LSCONVENTIONTYPE;
		case HOLON_NAME_SYNTAX_LSCONVENTION:
		case FILE_HOLON_NAME_SYNTAX_LSCONVENTION:
		case METADATA_IN_STRINGS_SYNTAX_LSCONVENTION:
		case TAGS_SYNTAX_LSCONVENTION:
		case TANGLED_BETWEEN_LSCONVENTION:
		case VERBATIM_LSCONVENTION:
		case COMMENTS_LSCONVENTION:
		case INDEX_LSCONVENTION:
		case IMPORTANT_INDEX_LSCONVENTION:
		case TT_INDEX_LSCONVENTION:
		case IMPORTANT_TT_INDEX_LSCONVENTION:
		case NS_INDEX_LSCONVENTION:
		case IMPORTANT_NS_INDEX_LSCONVENTION:
		case LITERAL_CHARACTERS_LSCONVENTION:
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

@ And |HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION| must be one of:

@e NO_ABBREVCHOICE from 1
@e YES_ABBREVCHOICE
@e EVEN_ABBREVCHOICE

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
		case PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION:
			if (iv) WRITE("paragraphs are numbered sequentially");
			else WRITE("paragraphs are numbered hierarchically");
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
			switch (iv) {
				case YES_ABBREVCHOICE: WRITE("holon names can be abbreviated"); break;
				case EVEN_ABBREVCHOICE: WRITE("holon names can be abbreviated even at declarations"); break;
				case NO_ABBREVCHOICE: WRITE("holon names cannot be abbreviated"); break;
			}
			break;
		case HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION:
			if (iv) WRITE("whitespace lines opening holons are not tangled");
			else WRITE("whitespace lines opening holons are tangled");
			break;
		case HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION:
			if (iv) WRITE("whitespace lines closing holons are not tangled");
			else WRITE("whitespace lines closing holons are tangled");
			break;
		case TANGLED_BETWEEN_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("named holons are not tangled with prefix or suffix");
			else WRITE("named holons are tangled between %S and %S", Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case HOLON_NAME_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("holons are not named");
			else WRITE("holon names are written between %S and %S", Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case FILE_HOLON_NAME_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("holons are not extracted to files");
			else WRITE("holon names to be extracted to files are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case VERBATIM_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no verbatim tangle material syntax");
			else WRITE("verbatim tangle material is written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case COMMENTS_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no web comment syntax");
			else WRITE("web comments are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case INDEX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no index entry syntax");
			else WRITE("index entries are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case IMPORTANT_INDEX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no important index entry syntax");
			else WRITE("important index entries are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case TT_INDEX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no typewritten index entry syntax");
			else WRITE("typewritten index entries are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case IMPORTANT_TT_INDEX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no important typewritten index entry syntax");
			else WRITE("important typewritten index entries are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case NS_INDEX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no nonstandard index entry syntax");
			else WRITE("nonstandard index entries are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case IMPORTANT_NS_INDEX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no important nonstandard index entry syntax");
			else WRITE("important nonstandard index entries are written between %S and %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case LITERAL_CHARACTERS_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("there is no literal character syntax");
			else WRITE("literal %S is written %S",
				Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case HOLONS_STYLED_LSCONVENTION:
			if (iv) WRITE("holon names can contain styling");
			else WRITE("holon names cannot contain styling");
			break;
		case COMMENTS_STYLED_LSCONVENTION:
			if (iv) WRITE("comments can contain styling");
			else WRITE("comments cannot contain styling");
			break;
		case TAGS_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("paragraph tags are not recognised");
			else WRITE("paragraph tags are written between %S and %S", Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case METADATA_IN_STRINGS_SYNTAX_LSCONVENTION:
			if (Str::len(tv) == 0) WRITE("metadata in strings are not recognised");
			else WRITE("metadata in strings are written between %S and %S", Conventions::convert_to_angled(tv), Conventions::convert_to_angled(tv2));
			break;
		case COMMENTARY_MARKUP_LSCONVENTION:
			switch (iv) {
				case MARKDOWN_COMMENTARY_MARKUPCHOICE:
					WRITE("commentary uses Markdown markup"); break;
				case SIMPLIFIED_COMMENTARY_MARKUPCHOICE:
					WRITE("commentary uses simplified markup"); break;
				case TEX_COMMENTARY_MARKUPCHOICE:
					WRITE("commentary uses TeX markup"); break;
			}
			break;
		case SUMMARY_UNDER_TITLE_LSCONVENTION:
			switch (iv) {
				case PURPOSE_SUMMARYCHOICE:
					WRITE("a summary under the title is read as the purpose"); break;
				case PURPOSE_IF_ITALIC_SUMMARYCHOICE:
					WRITE("an italicised summary under the title is read as the purpose"); break;
				case NO_SUMMARYCHOICE:
					WRITE("a summary under the title is not read as the purpose"); break;
			}
			break;
		case LIBRARY_INCLUDES_EARLY_LSCONVENTION:
			if (iv) WRITE("standard library #includes are tangled early in the program");
			else WRITE("standard library #includes are treated like any other code");
			break;
		case TYPEDEFS_EARLY_LSCONVENTION:
			if (iv) WRITE("typedefs are tangled early in the program");
			else WRITE("typedefs are treated like any other code");
			break;
		case TYPEDEF_STRUCTS_EARLY_LSCONVENTION:
			if (iv) WRITE("typedef structs are tangled early and reordered logically");
			else WRITE("typedef structs are treated like any other code");
			break;
		case FUNCTION_PREDECLARATIONS_LSCONVENTION:
			if (iv) WRITE("function predeclarations are tangled automatically");
			else WRITE("functions are treated like any other code");
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
	conventions->textual_value[conv] = Conventions::convert_from_angled(text);
	conventions->textual_value2[conv] = Conventions::convert_from_angled(text2);
}

text_stream *Conventions::convert_from_angled(text_stream *text) {
	if (text) {
		text_stream *OUT = Str::new();
		for (int i=0; i<Str::len(text); i++) {
			if (Str::includes_at(text, i, I"<NEWLINE>")) {
				PUT('\n'); i += 8;
			} else if (Str::includes_at(text, i, I"<NOTHING>")) {
				i += 8;
			} else if (Str::includes_at(text, i, I"<SPACE>")) {
				PUT('\n'); i += 6;
			} else if (Str::includes_at(text, i, I"<TAB>")) {
				PUT('\t'); i += 4;
			} else if (Str::includes_at(text, i, I"<LEFTANGLE>")) {
				PUT('<'); i += 10;
			} else if (Str::includes_at(text, i, I"<RIGHTANGLE>")) {
				PUT('>'); i += 11;
			} else {
				PUT(Str::get_at(text, i));
			}
		}
		return OUT;
	} else {
		return NULL;
	}
}

text_stream *Conventions::convert_to_angled(text_stream *text) {
	text_stream *OUT = Str::new();
	for (int i=0; i<Str::len(text); i++) {
		inchar32_t c = Str::get_at(text, i);
		switch (c) {
			case '\n': WRITE("<NEWLINE>"); break;
			case ' ': if ((i==0) || (i==Str::len(text)-1)) WRITE("<SPACE>"); else PUT(' '); break;
			case '<': WRITE("<LEFTANGLE>"); break;
			case '>': WRITE("<RIGHTANGLE>"); break;
			default: PUT(c); break;
		}
	}
	return OUT;
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
	} else if (Regexp::match(&mr, line, U" *paragraphs are numbered sequentially *")) {
		conv = PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *paragraphs are numbered hierarchically *")) {
		conv = PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION; iv = FALSE;
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
		conv = HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION; iv = YES_ABBREVCHOICE;
	} else if (Regexp::match(&mr, line, U" *holon names can be abbreviated even at declarations *")) {
		conv = HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION; iv = EVEN_ABBREVCHOICE;
	} else if (Regexp::match(&mr, line, U" *holon names cannot be abbreviated *")) {
		conv = HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION; iv = NO_ABBREVCHOICE;
	} else if (Regexp::match(&mr, line, U" *holon names can contain styling *")) {
		conv = HOLONS_STYLED_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *holon names cannot contain styling *")) {
		conv = HOLONS_STYLED_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *comments can contain styling *")) {
		conv = COMMENTS_STYLED_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *comments cannot contain styling *")) {
		conv = COMMENTS_STYLED_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *holon names are written between (%c+) and (%c+) *")) {
		conv = HOLON_NAME_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *holons are not named *")) {
		conv = HOLON_NAME_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *holon names to be extracted to files are written between (%c+) and (%c+) *")) {
		conv = FILE_HOLON_NAME_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *holons are not extracted to files *")) {
		conv = FILE_HOLON_NAME_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *verbatim tangle material is written between (%c+) and (%c+) *")) {
		conv = VERBATIM_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no verbatim tangle material syntax *")) {
		conv = VERBATIM_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *web comments are written between (%c+) and (%c+) *")) {
		conv = COMMENTS_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no web comment syntax *")) {
		conv = COMMENTS_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *index entries are written between (%c+) and (%c+) *")) {
		conv = INDEX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no index entry syntax *")) {
		conv = INDEX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *important index entries are written between (%c+) and (%c+) *")) {
		conv = IMPORTANT_INDEX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no important index entry syntax *")) {
		conv = IMPORTANT_INDEX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *typewritten index entries are written between (%c+) and (%c+) *")) {
		conv = TT_INDEX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no typewritten index entry syntax *")) {
		conv = TT_INDEX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *important typewritten index entries are written between (%c+) and (%c+) *")) {
		conv = IMPORTANT_TT_INDEX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no important typewritten index entry syntax *")) {
		conv = IMPORTANT_TT_INDEX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *nonstandard index entries are written between (%c+) and (%c+) *")) {
		conv = NS_INDEX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no nonstandard index entry syntax *")) {
		conv = NS_INDEX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *important nonstandard index entries are written between (%c+) and (%c+) *")) {
		conv = IMPORTANT_NS_INDEX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no important nonstandard index entry syntax *")) {
		conv = IMPORTANT_NS_INDEX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *literal (%c+) is written (%c+) *")) {
		conv = LITERAL_CHARACTERS_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *there is no literal character syntax *")) {
		conv = LITERAL_CHARACTERS_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *metadata in strings are written between (%c+) and (%c+) *")) {
		conv = METADATA_IN_STRINGS_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *metadata in strings are not recognised *")) {
		conv = METADATA_IN_STRINGS_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *paragraph tags are written between (%c+) and (%c+) *")) {
		conv = TAGS_SYNTAX_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *paragraph tags are not recognised *")) {
		conv = TAGS_SYNTAX_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *named holons are tangled between (%c+) and (%c+) *")) {
		conv = TANGLED_BETWEEN_LSCONVENTION; tv = mr.exp[0]; tv2 = mr.exp[1];
	} else if (Regexp::match(&mr, line, U" *named holons are not tangled with prefix or suffix *")) {
		conv = TANGLED_BETWEEN_LSCONVENTION; tv = NULL; tv2 = NULL;
	} else if (Regexp::match(&mr, line, U" *commentary uses Markdown markup *")) {
		conv = COMMENTARY_MARKUP_LSCONVENTION; iv = MARKDOWN_COMMENTARY_MARKUPCHOICE;
	} else if (Regexp::match(&mr, line, U" *commentary uses simplified markup *")) {
		conv = COMMENTARY_MARKUP_LSCONVENTION; iv = SIMPLIFIED_COMMENTARY_MARKUPCHOICE;
	} else if (Regexp::match(&mr, line, U" *commentary uses TeX markup *")) {
		conv = COMMENTARY_MARKUP_LSCONVENTION; iv = TEX_COMMENTARY_MARKUPCHOICE;
	} else if (Regexp::match(&mr, line, U" *a summary under the title is read as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = PURPOSE_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *an italicized summary under the title is read as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = PURPOSE_IF_ITALIC_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *an italicised summary under the title is read as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = PURPOSE_IF_ITALIC_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *a summary under the title is not read as the purpose *")) {
		conv = SUMMARY_UNDER_TITLE_LSCONVENTION; iv = NO_SUMMARYCHOICE;
	} else if (Regexp::match(&mr, line, U" *standard library #includes are tangled early in the program *")) {
		conv = LIBRARY_INCLUDES_EARLY_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *standard library #includes are treated like any other code *")) {
		conv = LIBRARY_INCLUDES_EARLY_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *typedefs are tangled early in the program *")) {
		conv = TYPEDEFS_EARLY_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *typedefs are treated like any other code *")) {
		conv = TYPEDEFS_EARLY_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *typedef structs are tangled early and reordered logically *")) {
		conv = TYPEDEF_STRUCTS_EARLY_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *typedef structs are treated like any other code *")) {
		conv = TYPEDEF_STRUCTS_EARLY_LSCONVENTION; iv = FALSE;
	} else if (Regexp::match(&mr, line, U" *function predeclarations are tangled automatically *")) {
		conv = FUNCTION_PREDECLARATIONS_LSCONVENTION; iv = TRUE;
	} else if (Regexp::match(&mr, line, U" *functions are treated like any other code *")) {
		conv = FUNCTION_PREDECLARATIONS_LSCONVENTION; iv = FALSE;
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
		Conventions::set_int(generic, PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION, FALSE);
		Conventions::set_int(generic, SINGLE_FILE_METADATA_PAIRS_LSCONVENTION, TRUE);
		Conventions::set_int(generic, HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION, FALSE);
		Conventions::set_int(generic, HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION, FALSE);
		Conventions::set_int(generic, HOLONS_STYLED_LSCONVENTION, TRUE);
		Conventions::set_int(generic, COMMENTS_STYLED_LSCONVENTION, FALSE);
		Conventions::set_int(generic, TEX_NOTATION_LSCONVENTION, TRUE);
		Conventions::set_int(generic, FOOTNOTES_LSCONVENTION, TRUE);
		Conventions::set_int(generic, HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION, YES_ABBREVCHOICE);
		Conventions::set_int(generic, COMMENTARY_MARKUP_LSCONVENTION, MARKDOWN_COMMENTARY_MARKUPCHOICE);
		Conventions::set_int(generic, SUMMARY_UNDER_TITLE_LSCONVENTION, NO_SUMMARYCHOICE);
		Conventions::set_int(generic, LIBRARY_INCLUDES_EARLY_LSCONVENTION, FALSE);
		Conventions::set_int(generic, TYPEDEFS_EARLY_LSCONVENTION, FALSE);
		Conventions::set_int(generic, TYPEDEF_STRUCTS_EARLY_LSCONVENTION, FALSE);
		Conventions::set_int(generic, FUNCTION_PREDECLARATIONS_LSCONVENTION, FALSE);

		Conventions::set_textual(generic, HOLON_NAME_SYNTAX_LSCONVENTION, I"{{", I"}}");
		Conventions::set_textual(generic, FILE_HOLON_NAME_SYNTAX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, VERBATIM_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, METADATA_IN_STRINGS_SYNTAX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, TAGS_SYNTAX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, TANGLED_BETWEEN_LSCONVENTION, I"\n", I"\n");

		Conventions::set_textual(generic, COMMENTS_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, INDEX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, IMPORTANT_INDEX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, TT_INDEX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, IMPORTANT_TT_INDEX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, NS_INDEX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, IMPORTANT_NS_INDEX_LSCONVENTION, NULL, NULL);
		Conventions::set_textual(generic, LITERAL_CHARACTERS_LSCONVENTION, NULL, NULL);
	}
	return generic;
}

linked_list *Conventions::generic_set(void) {
	linked_list *conventions = NEW_LINKED_LIST(ls_conventions);
	ls_conventions *generic = Conventions::generic();
	ADD_TO_LINKED_LIST(generic, ls_conventions, conventions);
	return conventions;
}

linked_list *Conventions::applicable(ls_web *W, ls_colony *C) {
	ls_conventions *generic = Conventions::generic();
	linked_list *L = NEW_LINKED_LIST(ls_conventions);
	ADD_TO_LINKED_LIST(generic, ls_conventions, L);
	if (W) {
		programming_language *pl = W->web_language;
		if (pl) Conventions::apply(L, pl->declaration);
		ls_notation *ntn = W->web_notation;
		if (ntn) Conventions::apply(L, ntn->declaration);
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
