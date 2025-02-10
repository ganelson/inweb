[WebSyntax::] Web Syntax.

To manage possible syntaxes for webs.

@h Introduction.
Inweb syntax has gradually shifted over the years, but there are two main
versions: the second was cleaned up and simplified from the first in 2019.

@e KEY_VALUE_PAIRS_WSF from 0
@e SYNTAX_REDECLARATION_WSF
@e PARAGRAPH_TAGS_WSF

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

@

=
web_syntax *old_Inweb_syntax = NULL;
web_syntax *new_Inweb_syntax = NULL;
web_syntax *Markdown_syntax = NULL;

void WebSyntax::create(void) {
	old_Inweb_syntax = WebSyntax::new(I"old Inweb");
	old_Inweb_syntax->legacy_name = I"1";
	WebSyntax::does_support(old_Inweb_syntax, KEY_VALUE_PAIRS_WSF);
	WebSyntax::does_support(old_Inweb_syntax, SYNTAX_REDECLARATION_WSF);
	new_Inweb_syntax = WebSyntax::new(I"new Inweb");
	new_Inweb_syntax->legacy_name = I"2";
	WebSyntax::does_support(new_Inweb_syntax, KEY_VALUE_PAIRS_WSF);
	WebSyntax::does_support(new_Inweb_syntax, SYNTAX_REDECLARATION_WSF);
	WebSyntax::does_support(new_Inweb_syntax, PARAGRAPH_TAGS_WSF);
	Markdown_syntax = WebSyntax::new(I"Markdown");
}

web_syntax *WebSyntax::default(void) {
	return new_Inweb_syntax;
}

@ How does a web identify its own syntax? Not all of them do, and if so then
the default web syntax (or else one set at the command line) will be used.

Note that the following is called repeatedly on each line at the top of
the contents section of a multi-file web, or at the top of the single
file in a single-file web.

=
web_syntax *WebSyntax::parse_internal_declaration(web_syntax *current_syntax,
	text_stream *line, text_file_position *tfp, text_stream *title, text_stream *author) {
	web_syntax *S = NULL;
	match_results mr = Regexp::create_mr();
	if ((WebSyntax::supports(current_syntax, KEY_VALUE_PAIRS_WSF)) &&
		(Regexp::match(&mr, line, U"Web Syntax Version: (%c+) *"))) {
		web_syntax *T;
		LOOP_OVER(T, web_syntax)
			if ((Str::eq_insensitive(mr.exp[0], T->name)) ||
				(Str::eq_insensitive(mr.exp[0], T->legacy_name)))
				S = T;
	}
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
	if ((syntax == Markdown_syntax) && (Str::is_whitespace(line))) return TRUE;
	if (WebSyntax::is_structural(WebSyntax::classify_line(syntax, line, WebSyntax::start_cf()))) return TRUE;
	return FALSE;
}

void WebSyntax::write(OUTPUT_STREAM, web_syntax *syntax) {
	WRITE("%S", syntax->name);
}

@ Okay, so lines are structural markers or they are not.

@e NO_WSFL from 0
@e STRUCTURAL_WSFL
@e DEFINITION_WSFL
@e IMMEDIATE_EXTRACT_WSFL
@e EXTRACT_START_WSFL
@e EXTRACT_MATTER_WSFL
@e WHITESPACE_WSFL
@e OTHER_WSFL

=
typedef struct web_line_cf {
	int classification;
	struct text_stream *operand1;
	struct text_stream *operand2;
	struct linked_list *tag_list; /* of text_stream */
} web_line_cf;

web_line_cf WebSyntax::start_cf(void) {
	return WebSyntax::new_cf(NO_WSFL, NULL);
}

web_line_cf WebSyntax::new_cf(int c, text_stream *operand1) {
	web_line_cf cf;
	cf.classification = c;
	if (Str::len(operand1) > 0) cf.operand1 = Str::duplicate(operand1);
	else cf.operand1 = NULL;
	cf.operand2 = NULL;
	cf.tag_list = NULL;
	return cf;
}

int WebSyntax::is_structural(web_line_cf cf) {
	if ((cf.classification == STRUCTURAL_WSFL) ||
		(cf.classification == DEFINITION_WSFL) ||
		(cf.classification == IMMEDIATE_EXTRACT_WSFL)) return TRUE;
	return FALSE;
}		

int WebSyntax::is_macro_definition_heading(web_line_cf cf) {
	if (cf.classification == DEFINITION_WSFL) return TRUE;
	return FALSE;
}		

int WebSyntax::is_immediate_extract(web_line_cf cf) {
	if (cf.classification == IMMEDIATE_EXTRACT_WSFL) return TRUE;
	return FALSE;
}		

int WebSyntax::is_extract(web_line_cf cf) {
	if (cf.classification == EXTRACT_START_WSFL) return TRUE;
	return FALSE;
}		

text_stream *WebSyntax::extract_command_at(web_line_cf cf) {
	if (cf.classification == EXTRACT_START_WSFL) return cf.operand1;
	return NULL;
}		

text_stream *WebSyntax::macro_defined_at(web_line_cf cf) {
	if (cf.classification == DEFINITION_WSFL) return cf.operand1;
	return NULL;
}

@ The tag list
for a paragraph is the run of |^"This"| and |^"That"| markers at the end of
the line introducing that paragraph.

=
web_line_cf WebSyntax::classify_line(web_syntax *syntax, text_stream *line, web_line_cf previously) {
	inchar32_t c1 = Str::get_at(line, 0);
	inchar32_t c2 = Str::get_at(line, 1);
	if (c1 == '@') {
		web_line_cf cf = WebSyntax::new_cf(STRUCTURAL_WSFL, NULL);
		if (c2) {
			match_results mr = Regexp::create_mr();
			if ((c2 == '<') && (Regexp::match(&mr, line, U"%c<(%c+)@> *= *"))) {
				cf = WebSyntax::new_cf(DEFINITION_WSFL, mr.exp[0]);
			} else if (((c2 == '=') || (Characters::is_whitespace(c2))) &&
 					(Regexp::match(&mr, line, U"@ *= *"))) {
				cf = WebSyntax::new_cf(IMMEDIATE_EXTRACT_WSFL, NULL);
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
				int at = 1;
				while ((c2) && (Characters::is_whitespace(c2) == FALSE)) {
					if (cf.operand1 == NULL) cf.operand1 = Str::new();
					PUT_TO(cf.operand1, c2);
					c2 = Str::get_at(line, ++at);
				}
				while ((c2) && (Characters::is_whitespace(c2))) {
					c2 = Str::get_at(line, ++at);
				}
				while (c2) {
					if (cf.operand2 == NULL) cf.operand2 = Str::new();
					PUT_TO(cf.operand2, c2);
					c2 = Str::get_at(line, ++at);
				}
			}
			Regexp::dispose_of(&mr);
		}
		return cf;
	}
	if (c1 == '=') {
		web_line_cf cf = WebSyntax::new_cf(EXTRACT_START_WSFL, NULL);
		if (Str::len(line) > 1) {
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, line, U"= *(%c+) *"))
				cf = WebSyntax::new_cf(EXTRACT_START_WSFL, mr.exp[0]);
			Regexp::dispose_of(&mr);
		}
		return cf;
	}
	if (Str::is_whitespace(line)) return WebSyntax::new_cf(WHITESPACE_WSFL, NULL);
	switch (previously.classification) {
		case IMMEDIATE_EXTRACT_WSFL:
		case EXTRACT_MATTER_WSFL:
			return WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NULL);
		default:
			return WebSyntax::new_cf(OTHER_WSFL, NULL);
	}	
}
