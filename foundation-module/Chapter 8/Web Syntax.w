[WebSyntax::] Web Syntax.

To manage possible syntaxes for webs.

@h Introduction.
Inweb syntax has gradually shifted over the years, but there are two main
versions: the second was cleaned up and simplified from the first in 2019.

@e KEY_VALUE_PAIRS_WSF from 0
@e SYNTAX_REDECLARATION_WSF
@e PARAGRAPH_TAGS_WSF
@e EXPLICIT_SECTION_HEADINGS_WSF
@e PURPOSE_NOTES_WSF

=
typedef struct web_syntax {
	struct text_stream *name;
	struct text_stream *legacy_name;
	int supports[NO_DEFINED_WSF_VALUES];
	CLASS_DEFINITION
} web_syntax;

web_syntax *WebSyntax::new(text_stream *name) {
	web_syntax *S = CREATE(web_syntax);
	S->name = Str::duplicate(name);
	S->legacy_name = Str::duplicate(name);
	for (int i=0; i<NO_DEFINED_WSF_VALUES; i++) S->supports[i] = FALSE;
	return S;
}

@

=
web_syntax *old_Inweb_syntax = NULL;
web_syntax *new_Inweb_syntax = NULL;
web_syntax *Markdown_syntax = NULL;
web_syntax *MASH_syntax = NULL;

void WebSyntax::create(void) {
	old_Inweb_syntax = WebSyntax::new(I"old Inweb");
	old_Inweb_syntax->legacy_name = I"1";
	WebSyntax::does_support(old_Inweb_syntax, KEY_VALUE_PAIRS_WSF);
	WebSyntax::does_support(old_Inweb_syntax, SYNTAX_REDECLARATION_WSF);
	WebSyntax::does_support(old_Inweb_syntax, EXPLICIT_SECTION_HEADINGS_WSF);
	new_Inweb_syntax = WebSyntax::new(I"new Inweb");
	new_Inweb_syntax->legacy_name = I"2";
	WebSyntax::does_support(new_Inweb_syntax, KEY_VALUE_PAIRS_WSF);
	WebSyntax::does_support(new_Inweb_syntax, SYNTAX_REDECLARATION_WSF);
	WebSyntax::does_support(new_Inweb_syntax, EXPLICIT_SECTION_HEADINGS_WSF);
	WebSyntax::does_support(new_Inweb_syntax, PARAGRAPH_TAGS_WSF);
	WebSyntax::does_support(new_Inweb_syntax, PURPOSE_NOTES_WSF);
	Markdown_syntax = WebSyntax::new(I"Markdown");
	MASH_syntax = WebSyntax::new(I"MASH");
}

web_syntax *WebSyntax::default(void) {
	return new_Inweb_syntax;
}

@ Syntaxes are named, case-insensitively.

=
web_syntax *WebSyntax::syntax_by_name(text_stream *name) {
	web_syntax *T;
	LOOP_OVER(T, web_syntax)
		if ((Str::eq_insensitive(name, T->name)) ||
			(Str::eq_insensitive(name, T->legacy_name)))
			return T;
	return NULL;
}

@ A "shebang" is a line at the top of a web section which gives away its
syntax.

=
web_syntax *WebSyntax::detect_shebang(web_syntax *current_syntax,
	text_stream *line, text_file_position *tfp, text_stream *title, text_stream *author) {
	web_syntax *S = NULL;
	match_results mr = Regexp::create_mr();
	if ((tfp->line_count == 1) && (Str::get_at(line, 0) == '#')) {
		if (Regexp::match(&mr, line, U"# (%C%c*?) by (%C%c*?) *")) {
			Str::copy(title, mr.exp[0]);
			Str::copy(author, mr.exp[1]);
		} else if (Regexp::match(&mr, line, U"# (%C%c*) *")) {
			Str::copy(title, mr.exp[0]);
		}
		S = Markdown_syntax;
	}
	Regexp::dispose_of(&mr);
	return S;
}

int WebSyntax::line_can_mark_end_of_metadata(web_syntax *syntax,
	text_stream *line, text_file_position *tfp) {
	if (Str::is_whitespace(line)) return TRUE;
	web_line_cf cf = WebSyntax::classify_line(syntax, line, WebSyntax::unclassified());
	if (WebSyntax::opens_paragraph(cf)) return TRUE;
	return FALSE;
}










int WebSyntax::supports(web_syntax *S, int feature) {
	if (S == NULL) internal_error("no syntax");
	if ((feature<0) || (feature >=NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	return S->supports[feature];
}

void WebSyntax::does_support(web_syntax *S, int feature) {
	if (S == NULL) internal_error("no syntax");
	if ((feature<0) || (feature >=NO_DEFINED_WSF_VALUES))
		internal_error("feature out of range");
	S->supports[feature] = TRUE;
}


void WebSyntax::write(OUTPUT_STREAM, web_syntax *syntax) {
	WRITE("%S", syntax->name);
}

@ Okay, so lines are structural markers or they are not.

@e NO_WSFL from 0
@e PARAGRAPH_START_WSFL
@e DEFINITION_WSFL
@e MACRO_DECLARATION_WSFL
@e EXTRACT_START_WSFL
@e EXTRACT_MATTER_WSFL
@e EXTRACT_END_WSFL
@e INSERTION_WSFL
@e D_CONTINUATION_WSFL
@e COMMENTARY_WSFL
@e PURPOSE_WSFL
@e CHAPTER_HEADING_WSFL
@e SECTION_HEADING_WSFL

@e NO_WSFSL from 0
@e AUDIO_WSFSL
@e CAROUSEL_ABOVE_WSFSL
@e CAROUSEL_BELOW_WSFSL
@e CAROUSEL_END_WSFSL
@e CAROUSEL_SLIDE_WSFSL
@e CAROUSEL_WSFSL
@e DOWNLOAD_WSFSL
@e EARLY_WSFSL
@e EMBEDDED_AV_WSFSL
@e FIGURE_WSFSL
@e HTML_WSFSL
@e TEXT_AS_WSFSL
@e TEXT_FROM_AS_WSFSL
@e TEXT_FROM_WSFSL
@e TEXT_TO_WSFSL
@e TEXT_WSFSL
@e VERY_EARLY_WSFSL
@e VIDEO_WSFSL
@e UNKNOWN_WSFSL

@e DEFINE_COMMAND_WSFSL
@e DEFAULT_COMMAND_WSFSL
@e ENUMERATE_COMMAND_WSFSL
@e HEADING_COMMAND_WSFSL

=
typedef struct web_line_cf {
	int classification;
	struct text_stream *operand1;
	struct text_stream *operand2;
	struct text_stream *operand3;
	int subclassification;
	int implies_paragraph;
	int implies_extract;
	int implies_extract_end;
	struct linked_list *tag_list; /* of text_stream */
} web_line_cf;

web_line_cf WebSyntax::unclassified(void) {
	return WebSyntax::new_cf(NO_WSFL, NO_WSFSL);
}

web_line_cf WebSyntax::new_cf(int c, int sc) {
	web_line_cf cf;
	cf.classification = c;
	cf.subclassification = sc;
	cf.operand1 = NULL;
	cf.operand2 = NULL;
	cf.operand3 = NULL;
	cf.tag_list = NULL;
	cf.implies_paragraph = FALSE;
	cf.implies_extract = FALSE;
	cf.implies_extract_end = FALSE;
	return cf;
}

int WebSyntax::is_unclassified(web_line_cf cf) {
	if (cf.classification == NO_WSFSL) return TRUE;
	return FALSE;
}		

int WebSyntax::opens_paragraph(web_line_cf cf) {
	if ((cf.classification == PARAGRAPH_START_WSFL) || (cf.implies_paragraph)) return TRUE;
	return FALSE;
}		

int WebSyntax::is_macro_definition_heading(web_line_cf cf) {
	if (cf.classification == MACRO_DECLARATION_WSFL) return TRUE;
	return FALSE;
}		

int WebSyntax::is_extract_start(web_line_cf cf) {
	if (cf.classification == EXTRACT_START_WSFL) return TRUE;
	return FALSE;
}		

int WebSyntax::is_extract_end(web_line_cf cf) {
	if (cf.classification == EXTRACT_END_WSFL) return TRUE;
	return FALSE;
}

text_stream *WebSyntax::extract_command_at(web_line_cf cf) {
	if (cf.classification == EXTRACT_START_WSFL) return cf.operand1;
	return NULL;
}		

text_stream *WebSyntax::macro_defined_at(web_line_cf cf) {
	if (cf.classification == MACRO_DECLARATION_WSFL) return cf.operand1;
	return NULL;
}

int WebSyntax::is_extract(web_line_cf C) {
	if (C.classification == EXTRACT_START_WSFL) return TRUE;
	if (C.classification == EXTRACT_MATTER_WSFL) return TRUE;
	if (C.classification == EXTRACT_END_WSFL) return TRUE;
	return FALSE;
}

int WebSyntax::is_commentary(web_line_cf C) {
	if (C.classification == EXTRACT_MATTER_WSFL) return FALSE;
	if (C.classification == MACRO_DECLARATION_WSFL) return FALSE;
	if (C.classification == D_CONTINUATION_WSFL) return FALSE;
	return TRUE;
}

int WebSyntax::extracted_matter_follows(web_line_cf C) {
	switch (C.classification) {
		case MACRO_DECLARATION_WSFL:
		case EXTRACT_MATTER_WSFL:
			return TRUE;
		case EXTRACT_START_WSFL:
			switch (C.subclassification) {
				case NO_WSFSL:
				case VERY_EARLY_WSFSL:
				case EARLY_WSFSL:
				case TEXT_WSFSL:
				case TEXT_TO_WSFSL:
				case TEXT_AS_WSFSL:
				case HTML_WSFSL:
/*				case CAROUSEL_WSFSL:
				case CAROUSEL_ABOVE_WSFSL:
				case CAROUSEL_BELOW_WSFSL:
				case CAROUSEL_SLIDE_WSFSL:
*/
					return TRUE;
			}
			break;
	}
	return FALSE;
}

int WebSyntax::extended_definition_follows(web_line_cf C) {
	switch (C.classification) {
		case D_CONTINUATION_WSFL:
			return TRUE;
		case DEFINITION_WSFL:
			return TRUE;
	}
	return FALSE;
}

@ The tag list
for a paragraph is the run of |^"This"| and |^"That"| markers at the end of
the line introducing that paragraph.

=
web_line_cf WebSyntax::classify_line(web_syntax *syntax, text_stream *line, web_line_cf previously) {
	if (syntax == new_Inweb_syntax) return WebSyntax::new_Inweb_conventions(syntax, line, previously);
	if (syntax == MASH_syntax) return WebSyntax::MASH_conventions(syntax, line, previously);
	return WebSyntax::all_code_conventions(syntax, line, previously);
}

web_line_cf WebSyntax::all_commentary_conventions(web_syntax *syntax, text_stream *line, web_line_cf previously) {
	web_line_cf cf = WebSyntax::new_cf(PARAGRAPH_START_WSFL, NO_WSFSL);
	if (previously.classification == NO_WSFL) {
		cf.implies_paragraph = TRUE;
	}
	return cf;
}

web_line_cf WebSyntax::all_code_conventions(web_syntax *syntax, text_stream *line, web_line_cf previously) {
	web_line_cf cf = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
	cf.operand1 = Str::duplicate(line);
	if (previously.classification == NO_WSFL) {
		cf.implies_paragraph = TRUE;
		cf.implies_extract = TRUE;
	}
	return cf;
}

web_line_cf WebSyntax::MASH_conventions(web_syntax *syntax, text_stream *line, web_line_cf previously) {
	int follows_extract = WebSyntax::extracted_matter_follows(previously);
	match_results mr = Regexp::create_mr();
	web_line_cf cf = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
	if (Regexp::match(&mr, line, U"Room (%c*?) *")) {
		cf = WebSyntax::new_cf(PARAGRAPH_START_WSFL, NO_WSFSL);
		cf.operand2 = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"; # (%c*?) *")) {
		cf = WebSyntax::new_cf(PARAGRAPH_START_WSFL, NO_WSFSL);
		cf.operand2 = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"; -* *")) {
		cf = WebSyntax::new_cf(COMMENTARY_WSFL, NO_WSFSL);
		cf.operand1 = Str::new();
		if ((previously.classification == NO_WSFL) || (follows_extract)) cf.implies_paragraph = TRUE;
	} else if (Regexp::match(&mr, line, U";; (%c*?) *")) {
		cf = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
		if (follows_extract == FALSE) cf.implies_extract = TRUE;
		cf.operand1 = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"; (%c*?) *")) {
		cf = WebSyntax::new_cf(COMMENTARY_WSFL, NO_WSFSL);
		cf.operand1 = Str::duplicate(mr.exp[0]);
		if ((previously.classification == NO_WSFL) || (follows_extract)) cf.implies_paragraph = TRUE;
	} else if (Str::is_whitespace(line)) {
		if (follows_extract)
			cf = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
		else
			cf = WebSyntax::new_cf(COMMENTARY_WSFL, NO_WSFSL);
	} else {
		cf = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
		cf.operand1 = Str::duplicate(line);
		if (follows_extract == FALSE) cf.implies_extract = TRUE;
	}
	Regexp::dispose_of(&mr);
	return cf;
}

web_line_cf WebSyntax::new_Inweb_conventions(web_syntax *syntax, text_stream *line, web_line_cf previously) {
	inchar32_t c1 = Str::get_at(line, 0);
	inchar32_t c2 = Str::get_at(line, 1);
	if (c1 == '@') {
		web_line_cf cf = WebSyntax::new_cf(PARAGRAPH_START_WSFL, NO_WSFSL);
		if (c2) {
			match_results mr = Regexp::create_mr();
			if ((c2 == '<') && (Regexp::match(&mr, line, U"%c<(%c+)@> *= *"))) {
				cf = WebSyntax::new_cf(MACRO_DECLARATION_WSFL, NO_WSFSL);
				cf.operand1 = Str::duplicate(mr.exp[0]);
				if (WebSyntax::extracted_matter_follows(previously))
					cf.implies_paragraph = TRUE;
			} else if (((c2 == '=') || (Characters::is_whitespace(c2))) &&
 					(Regexp::match(&mr, line, U"@ *= *"))) {
				cf = WebSyntax::new_cf(EXTRACT_START_WSFL, NO_WSFSL);
				cf.implies_paragraph = TRUE;
			} else {
				if (WebSyntax::supports(syntax, PARAGRAPH_TAGS_WSF)) {
					TEMPORARY_TEXT(run)
					Str::copy(run, line);
					while (Regexp::match(&mr, run, U"(%c*?) *%^\"(%c+?)\"(%c*)")) {
						Str::clear(run);
						if (cf.tag_list == NULL) cf.tag_list = NEW_LINKED_LIST(text_stream);
						text_stream *tag = Str::duplicate(mr.exp[1]);
						ADD_TO_LINKED_LIST(tag, text_stream, cf.tag_list);
						WRITE_TO(run, "%S %S", mr.exp[0], mr.exp[2]);
					}
					DISCARD_TEXT(run)
				}
				TEMPORARY_TEXT(command_text)
				int at = 1;
				while ((c2) && (Characters::is_whitespace(c2) == FALSE)) {
					PUT_TO(command_text, c2);
					c2 = Str::get_at(line, ++at);
				}
				while ((c2) && (Characters::is_whitespace(c2))) {
					c2 = Str::get_at(line, ++at);
				}
				while (c2) {
					if (cf.operand1 == NULL) cf.operand1 = Str::new();
					PUT_TO(cf.operand1, c2);
					c2 = Str::get_at(line, ++at);
				}

				if (Str::len(command_text) > 0) {
					int c = PARAGRAPH_START_WSFL, sc = UNKNOWN_WSFSL;
					if (Str::eq(command_text, I"d"))       { c = DEFINITION_WSFL; sc = DEFINE_COMMAND_WSFSL; }
					if (Str::eq(command_text, I"define"))  { c = DEFINITION_WSFL; sc = DEFINE_COMMAND_WSFSL; }
					if (Str::eq(command_text, I"e"))       { c = DEFINITION_WSFL; sc = ENUMERATE_COMMAND_WSFSL; }
					if (Str::eq(command_text, I"enum"))    { c = DEFINITION_WSFL; sc = ENUMERATE_COMMAND_WSFSL; }
					if (Str::eq(command_text, I"default")) { c = DEFINITION_WSFL; sc = DEFAULT_COMMAND_WSFSL; }
					if ((Str::eq(command_text, I"h")) || (Str::eq(command_text, I"heading"))) {
						sc = NO_WSFSL;
						if (Regexp::match(&mr, cf.operand1, U"(%c+). (%c+)")) {
							cf.operand1 = Str::duplicate(mr.exp[1]);
							cf.operand2 = Str::duplicate(mr.exp[0]);
						} else if (Regexp::match(&mr, cf.operand1, U"(%c+). *")) {
							cf.operand1 = NULL;
							cf.operand2 = Str::duplicate(mr.exp[0]);
						}
					}
					cf.classification = c; cf.subclassification = sc;
				}
				DISCARD_TEXT(command_text)
			}
			Regexp::dispose_of(&mr);
		}
		return cf;
	}

	if (c1 == '=') {
		web_line_cf cf = WebSyntax::new_cf(EXTRACT_START_WSFL, NO_WSFSL);
		if (Str::len(line) > 1) {
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, line, U"= *%((%c+)%) *")) {
				cf.operand1 = Str::duplicate(mr.exp[0]);
				text_stream *extract_cmd = cf.operand1;			
				match_results mr2 = Regexp::create_mr();
				if (Str::eq(extract_cmd, I"very early code")) {
					cf.subclassification = VERY_EARLY_WSFSL;
				} else if (Str::eq(extract_cmd, I"early code")) {
					cf.subclassification = EARLY_WSFSL;
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text")) {
					cf.subclassification = TEXT_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text to *(%c+)")) {
					cf.subclassification = TEXT_TO_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text as code")) {
					cf.subclassification = TEXT_AS_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text as (%c+)")) {
					cf.subclassification = TEXT_AS_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text from (%c+) as code")) {
					cf.subclassification = TEXT_FROM_AS_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text from (%c+) as (%c+)")) {
					cf.subclassification = TEXT_FROM_AS_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
					cf.operand3 = Str::duplicate(mr2.exp[2]);
				} else if (Regexp::match(&mr2, extract_cmd, U"(%c*?) *text from (%c+)")) {
					cf.subclassification = TEXT_FROM_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
				} else if (Regexp::match(&mr2, extract_cmd, U"html (%c+)")) {
					cf.subclassification = HTML_WSFSL;
					cf.operand1 = Str::duplicate(mr2.exp[0]);

				} else if (Regexp::match(&mr2, extract_cmd, U"carousel")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, CAROUSEL_WSFSL);
				} else if (Regexp::match(&mr2, extract_cmd, U"carousel \"(%c+)\" below")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, CAROUSEL_BELOW_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"carousel \"(%c+)\" above")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, CAROUSEL_ABOVE_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"carousel \"(%c+)\"")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, CAROUSEL_SLIDE_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"carousel end")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, CAROUSEL_END_WSFSL);
				} else if ((Regexp::match(&mr2, extract_cmd, U"embedded (%C+) video (%c+)")) ||
					(Regexp::match(&mr2, extract_cmd, U"embedded (%C+) audio (%c+)"))) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, EMBEDDED_AV_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
				} else if (Regexp::match(&mr2, extract_cmd, U"figure (%c+)")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, FIGURE_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"audio (%c+)")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, AUDIO_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"video (%c+)")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, VIDEO_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
				} else if (Regexp::match(&mr2, extract_cmd, U"download (%c+) \"(%c*)\"")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, DOWNLOAD_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);
					cf.operand2 = Str::duplicate(mr2.exp[1]);
				} else if (Regexp::match(&mr2, extract_cmd, U"download (%c+)")) {
					cf = WebSyntax::new_cf(INSERTION_WSFL, DOWNLOAD_WSFSL);
					cf.operand1 = Str::duplicate(mr2.exp[0]);

				} else {
					cf.subclassification = UNKNOWN_WSFSL;
					cf.operand1 = Str::duplicate(extract_cmd);
				}
				Regexp::dispose_of(&mr2);
			}
			Regexp::dispose_of(&mr);
		} else {
			if (WebSyntax::extracted_matter_follows(previously))
				cf.classification = EXTRACT_END_WSFL;
		}
		return cf;
	}
	
	if (WebSyntax::extracted_matter_follows(previously)) {
		web_line_cf cf = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
		cf.operand1 = Str::duplicate(line);
		return cf;
	}
	if (WebSyntax::extended_definition_follows(previously))
		return WebSyntax::new_cf(D_CONTINUATION_WSFL, NO_WSFSL);

	web_line_cf cf = WebSyntax::new_cf(COMMENTARY_WSFL, NO_WSFSL);
	cf.operand1 = line;
	return cf;
}

typedef struct literate_source_unit {
	struct web_syntax *syntax;
	void *(*extra_callback)(struct literate_source_unit *, void *ref, struct text_stream *, int);
	int incomplete;
	struct literate_source_token *first_lst;
	struct literate_source_token *last_lst;
	struct literate_source_paragraph *first_par;
	struct literate_source_paragraph *last_par;
	CLASS_DEFINITION
} literate_source_unit;

typedef struct literate_source_paragraph {
	struct literate_source_unit *owner;
	struct literate_source_chunk *first_chunk;
	struct literate_source_chunk *last_chunk;
	struct literate_source_token *titling_token;
	struct literate_source_paragraph *prev_par;
	struct literate_source_paragraph *next_par;
	CLASS_DEFINITION
} literate_source_paragraph;

@

@e COMMENTARY_LSCT from 1
@e EXTRACT_LSCT
@e OTHER_LSCT

typedef struct literate_source_chunk {
	int chunk_type;
	struct literate_source_paragraph *owner;
	struct literate_source_token *first_lst;
	struct literate_source_token *last_lst;
	struct literate_source_chunk *prev_chunk;
	struct literate_source_chunk *next_chunk;
	CLASS_DEFINITION
} literate_source_chunk;

typedef struct literate_source_token {
	void *ref;
	struct text_stream *text;
	int implied;
	struct web_line_cf classification;
	struct literate_source_token *prev_lst;
	struct literate_source_token *next_lst;
	CLASS_DEFINITION
} literate_source_token;

literate_source_unit *WebSyntax::begin_lsu(web_syntax *syntax,
	void *(*A)(struct literate_source_unit *, void *ref, struct text_stream *, int)) {
	literate_source_unit *lsu = CREATE(literate_source_unit);
	lsu->syntax = syntax;
	lsu->extra_callback = A;
	lsu->incomplete = TRUE;
	lsu->first_lst = NULL;
	lsu->last_lst = NULL;
	lsu->first_par = NULL;
	lsu->last_par = NULL;
	return lsu;
}

void WebSyntax::add_token(literate_source_unit *lsu, void *ref, text_stream *text, int c) {
	if ((lsu == NULL) || (lsu->incomplete == FALSE)) internal_error("bad feed");

	web_line_cf last_cf;
	if (lsu->last_lst == NULL) last_cf = WebSyntax::unclassified();
	else last_cf = lsu->last_lst->classification;

	web_line_cf next_cf;
	if (c != NO_WSFL) next_cf = WebSyntax::new_cf(c, NO_WSFSL);
	else next_cf = WebSyntax::classify_line(lsu->syntax, text, last_cf);

	if (next_cf.implies_extract_end) {
		next_cf.implies_extract_end = FALSE;
		text_stream *rationale = I"(implied extract end line)";
		void *new_ref = (*(lsu->extra_callback))(lsu, ref, rationale, EXTRACT_END_WSFL);
		WebSyntax::add_token(lsu, new_ref, rationale, EXTRACT_END_WSFL);
	}
	if (next_cf.implies_extract) {
		next_cf.implies_extract = FALSE;
		text_stream *rationale = I"(implied extract start line)";
		void *new_ref = (*(lsu->extra_callback))(lsu, ref, rationale, EXTRACT_START_WSFL);
		WebSyntax::add_token(lsu, new_ref, rationale, EXTRACT_START_WSFL);
	}
	if (next_cf.implies_paragraph) {
		next_cf.implies_paragraph = FALSE;
		text_stream *rationale = I"(implied paragraph start line)";
		void *new_ref = (*(lsu->extra_callback))(lsu, ref, rationale, PARAGRAPH_START_WSFL);
		WebSyntax::add_token(lsu, new_ref, rationale, PARAGRAPH_START_WSFL);
	}

	literate_source_token *lst = CREATE(literate_source_token);
	lst->ref = ref;
	lst->text = Str::duplicate(text);
	lst->next_lst = NULL;
	lst->classification = next_cf;
	if (c != NO_WSFL) lst->implied = TRUE; else lst->implied = FALSE;
	lst->prev_lst = lsu->last_lst;

	if (lsu->first_lst == NULL) lsu->first_lst = lst;
	else lsu->last_lst->next_lst = lst;
	lsu->last_lst = lst;
}

void WebSyntax::feed_line(literate_source_unit *lsu, void *ref, text_stream *text) {
	if ((lsu == NULL) || (lsu->incomplete == FALSE)) internal_error("bad feed");
	WebSyntax::add_token(lsu, ref, text, NO_WSFSL);
}

void WebSyntax::complete_lsu(literate_source_unit *lsu) {
	if ((lsu == NULL) || (lsu->incomplete == FALSE)) internal_error("bad feed");
	lsu->incomplete = FALSE;
	literate_source_paragraph *par = NULL;
	literate_source_chunk *chunk = NULL;
	for (literate_source_token *lst = lsu->first_lst; lst; lst = lst->next_lst) {
		if ((WebSyntax::opens_paragraph(lst->classification)) || (par == NULL)) {
			par = CREATE(literate_source_paragraph);
			par->owner = lsu;
			par->prev_par = lsu->last_par;
			par->next_par = NULL;
			par->titling_token = lst;
			if (lsu->first_par == NULL) lsu->first_par = par;
			else lsu->last_par->next_par = par;
			lsu->last_par = par;
			chunk = NULL;
			continue;
		}
		int ct = OTHER_LSCT;
		if (WebSyntax::is_extract(lst->classification)) ct = EXTRACT_LSCT;
		else if (lst->classification.classification == COMMENTARY_WSFL) ct = COMMENTARY_LSCT;
		if ((chunk) && (ct != chunk->chunk_type)) chunk = NULL;
		
		if (chunk == NULL) {
			chunk = CREATE(literate_source_chunk);
			chunk->owner = par;
			chunk->chunk_type = ct;
			chunk->first_lst = lst;
			chunk->last_lst = lst;
			chunk->prev_chunk = par->last_chunk;
			chunk->next_chunk = NULL;
			if (par->first_chunk == NULL) par->first_chunk = chunk;
			else par->last_chunk->next_chunk = chunk;
			par->last_chunk = chunk;
		} else {
			chunk->last_lst->next_lst = lst;
			chunk->last_lst = lst;
		}
	}
	for (literate_source_paragraph *par = lsu->first_par; par; par = par->next_par) {
		for (literate_source_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			chunk->first_lst->prev_lst = NULL;
			chunk->last_lst->next_lst = NULL;
			if (chunk->chunk_type == COMMENTARY_LSCT) {
				literate_source_token *first_dark = NULL;
				literate_source_token *last_dark = NULL;
				for (literate_source_token *lst = chunk->first_lst; lst; lst = lst->next_lst) {
					if (Str::is_whitespace(lst->classification.operand1) == FALSE) {
						if (first_dark == NULL) first_dark = lst;
						last_dark = lst;
					}
				}
				if (first_dark == NULL) {
					WebSyntax::remove_chunk_from_par(chunk, par);
				} else {
					chunk->first_lst = first_dark;
					chunk->last_lst = last_dark;
					chunk->first_lst->prev_lst = NULL;
					chunk->last_lst->next_lst = NULL;
				}
			}
/*			if (chunk->chunk_type == EXTRACT_LSCT) {
				literate_source_token *first_dark = NULL;
				literate_source_token *last_dark = NULL;
				for (literate_source_token *lst = chunk->first_lst; lst; lst = lst->next_lst) {
					if ((lst->classification.classification == EXTRACT_START_WSFL) ||
						(Str::is_whitespace(lst->classification.operand1) == FALSE)) {
						if (first_dark == NULL) first_dark = lst;
						last_dark = lst;
					}
				}
				if (first_dark == NULL) {
					WebSyntax::remove_chunk_from_par(chunk, par);
				} else {
					chunk->first_lst = first_dark;
					chunk->last_lst = last_dark;
					chunk->first_lst->prev_lst = NULL;
					chunk->last_lst->next_lst = NULL;
				}
			}
*/
		}
		if ((Str::is_whitespace(par->titling_token->classification.operand1)) &&
			(Str::is_whitespace(par->titling_token->classification.operand2)) &&
			(par->first_chunk == NULL)) {
			WebSyntax::remove_par_from_unit(par, lsu);
		}
	}
}

void WebSyntax::remove_chunk_from_par(literate_source_chunk *chunk, literate_source_paragraph *par) {
	if (chunk == par->first_chunk) {
		if (chunk == par->last_chunk) {
			par->first_chunk = NULL;
			par->last_chunk = NULL;
		} else {
			par->first_chunk = chunk->next_chunk;
			par->first_chunk->prev_chunk = NULL;
		}
	} else if (chunk == par->last_chunk) {
		par->last_chunk = chunk->prev_chunk;
		par->last_chunk->next_chunk = NULL;
	} else {
		chunk->prev_chunk->next_chunk = chunk->next_chunk;
	}
}

void WebSyntax::remove_par_from_unit(literate_source_paragraph *par, literate_source_unit *lsu) {
	if (par == lsu->first_par) {
		if (par == lsu->last_par) {
			lsu->first_par = NULL;
			lsu->last_par = NULL;
		} else {
			lsu->first_par = par->next_par;
			lsu->first_par->prev_par = NULL;
		}
	} else if (par == lsu->last_par) {
		lsu->last_par = par->prev_par;
		lsu->last_par->next_par = NULL;
	} else {
		par->prev_par->next_par = par->next_par;
	}
}

void WebSyntax::write_lsu(OUTPUT_STREAM, literate_source_unit *lsu) {
	if (lsu == NULL) {
		WRITE("(no literate source)\n");
	} else if (lsu->first_par == NULL) {
		WRITE("(empty literate source)\n");
	} else {
		int pc = 0, cc = 0;
		for (literate_source_paragraph *par = lsu->first_par; par; par = par->next_par) {
			pc++;
			literate_source_token *lst = par->titling_token;
			WRITE("par %d: heading '%S'\n", pc, lst->classification.operand2);
			INDENT;
			cc = 0;
			for (literate_source_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
				cc++;
				WRITE("chunk %d: ", cc);
				switch (chunk->chunk_type) {
					case COMMENTARY_LSCT: WRITE("commentary\n"); break;
					case EXTRACT_LSCT: WRITE("extract\n"); break;
					case OTHER_LSCT: WRITE("other\n"); break;
					default: WRITE("?\n"); break;
				}
				INDENT;
				for (literate_source_token *lst = chunk->first_lst; lst; lst = lst->next_lst) {
					switch (lst->classification.classification) {
						case COMMENTARY_WSFL: WRITE("%S\n", lst->classification.operand1); break;
						case EXTRACT_MATTER_WSFL: WRITE("%S\n", lst->classification.operand1); break;
						default:
							WRITE("class %d/%d: %S / %S / %S\n",
								lst->classification.classification,
								lst->classification.subclassification,
								lst->classification.operand1,
								lst->classification.operand2,
								lst->classification.operand3);
							break;
					}
				}
				OUTDENT;
			}
			OUTDENT;
		}
	}
}
