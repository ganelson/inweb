[Parser::] The Parser.

To work through the program read in, assigning each line its category,
and noting down other useful information as we go.

@h Sequence of parsing.
At this point, the web has been read into memory. It's a linked list of
chapters, each of which is a linked list of sections, each of which must
be parsed in turn.

When we're done, we offer the support code for the web's programming language
a chance to do some further work, if it wants to. (This is how, for example,
function definitions are recognised in C programs.) There is no requirement
for it to do anything.

=
void *Parser::supply(literate_source_unit *lsu, void *ref, text_stream *text, int why) {
	source_line *L = (source_line *) ref;
	source_line *NL = Lines::new_source_line_in(text, &(L->source), L->owning_section);
	return (void *) NL;
}

void Parser::parse_web(web *W, int inweb_mode) {
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections) {
			@<Parse the syntax@>;
			@<Form into paragraphs@>;
		}
	LanguageMethods::parse_types(W, W->main_language);
	LanguageMethods::parse_functions(W, W->main_language);
	LanguageMethods::further_parsing(W, W->main_language);
}

@ This is now largely delegated.

@<Parse the syntax@> =
	S->literate_source = WebSyntax::begin_lsu(S->md->using_syntax, &Parser::supply);
	
	for (source_line *L = S->first_line, *PL = NULL; L; PL = L, L = L->next_line) 
		WebSyntax::feed_line(S->literate_source, (void *) L, L->text);
	
	WebSyntax::complete_lsu(S->literate_source);
	if (fundamental_mode == WEAVE_MODE) WebSyntax::write_lsu(STDERR, S->literate_source);
	
	S->first_line = NULL;
	source_line *L = NULL;
	for (literate_source_paragraph *par = S->literate_source->first_par; par; par = par->next_par) {
		literate_source_token *lst = par->titling_token;
		@<Convert token@>;
		for (literate_source_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			for (literate_source_token *lst = chunk->first_lst; lst; lst = lst->next_lst) {
				@<Convert token@>;
			}
		}
	}

	for (source_line *L = S->first_line, *PL = NULL; L; PL = L, L = L->next_line) {
		if ((L->classification.operand1) &&
			((L->classification.classification == COMMENTARY_WSFL) ||
				(L->classification.classification == EXTRACT_MATTER_WSFL)))
			L->weave_text = L->classification.operand1;
	}

@<Convert token@> =
	source_line *NL = (source_line *) lst->ref;
	if (L == NULL) S->first_line = NL; else L->next_line = NL;
	NL->classification = lst->classification;
	L = NL;

@ The task now is to categorise the source lines more fully, and group them
further into a linked list of paragraphs.

@<Form into paragraphs@> =
	int code_lcat_for_body = NO_LCAT,
		code_plainness_for_body = FALSE,
		hyperlink_body = FALSE;
	programming_language *code_pl_for_body = NULL;
	text_stream *code_destination = NULL;
	int next_par_number = 1;
	paragraph *current_paragraph = NULL;
	for (source_line *L = S->first_line; L; L = L->next_line)
		@<Determine category for this source line@>;
	if (WebSyntax::supports(S->md->using_syntax, PURPOSE_NOTES_WSF))
		@<Construe the comment under the heading as the purpose@>;
	@<Work out footnote numbering for this section@>;

@ In the woven form of each section, footnotes are counting upwards from 1.

@<Work out footnote numbering for this section@> =
	int next_footnote = 1;
	paragraph *P;
	LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
		@<Work out footnote numbering for this paragraph@>;

@ The "purpose" of a section is a brief note about what it's for. In version 1
syntax, this had to be explicitly declared with a |@Purpose:| command; in
version 2 it's much tidier.

@<Construe the comment under the heading as the purpose@> =
	source_line *L = S->first_line;
	if ((L) && (L->category == CHAPTER_HEADING_LCAT)) L = L->next_line;
	if (Str::len(S->sect_purpose) == 0) {
		S->sect_purpose = Parser::extract_purpose(I"", L?L->next_line: NULL, S, NULL);
		if (Str::len(S->sect_purpose) > 0) L->next_line->category = PURPOSE_LCAT;
	}

@h Categorisation.
This is where the work is really done. We have a source line: is it comment,
code, definition, what?

@<Determine category for this source line@> =
	L->category = COMMENT_BODY_LCAT; /* until set otherwise down below */
	L->owning_paragraph = current_paragraph;

	if (L->source.line_count == 0) @<Parse the line as a probable chapter heading@>;
	if (L->source.line_count <= 1) @<Parse the line as a probable section heading@>;
	@<Parse the line as a possible paragraph macro definition@>;

	if (current_paragraph) {
		if (L->classification.classification == INSERTION_WSFL) @<Deal with an insertion@>
		else if (WebSyntax::is_extract_start(L->classification)) @<Parse the line as an equals structural marker@>
		else if (WebSyntax::is_extract_end(L->classification)) @<Exit extract mode@>;
	}
	
	if (L->classification.classification == PARAGRAPH_START_WSFL)
		@<Deal with a paragraph start line@>;
	if (L->classification.classification == DEFINITION_WSFL)
		@<Deal with a definition@>;

	if (WebSyntax::is_commentary(L->classification)) @<This is a line destined for commentary@>
	else @<This is a line destined for the verbatim code@>;

@ This must be one of the inserted lines marking chapter headings; it doesn't
come literally from the source web.

@<Parse the line as a probable chapter heading@> =
	if (Str::eq_wide_string(L->text, U"Chapter Heading")) {
		L->category = CHAPTER_HEADING_LCAT;
		L->owning_paragraph = NULL;
		L->classification.classification = CHAPTER_HEADING_WSFL;
	}

@ The top line of a section gives its title; in InC, it can also give the
namespace for its functions.

@<Parse the line as a probable section heading@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, U"Implied Purpose: (%c+)")) {
		S->sect_purpose = Str::duplicate(mr.exp[0]);
		if (Str::len(S->sect_purpose) > 0) {
			L->category = PURPOSE_LCAT;
			L->classification.classification = PURPOSE_WSFL;
		}
	} else if (Regexp::match(&mr, L->text, U"%[(%C+::)%] (%c+).")) {
		S->sect_namespace = Str::duplicate(mr.exp[0]);
		S->md->sect_title = Str::duplicate(mr.exp[1]);
		L->text_operand = Str::duplicate(mr.exp[1]);
		L->category = SECTION_HEADING_LCAT;
		L->owning_paragraph = NULL;
		L->classification.classification = SECTION_HEADING_WSFL;
	} else if (Regexp::match(&mr, L->text, U"(%c+).")) {
		S->md->sect_title = Str::duplicate(mr.exp[0]);
		L->text_operand = Str::duplicate(mr.exp[0]);
		L->category = SECTION_HEADING_LCAT;
		L->owning_paragraph = NULL;
		L->classification.classification = SECTION_HEADING_WSFL;
	}
	Regexp::dispose_of(&mr);

@ Some paragraphs define angle-bracketed macros, and those need special
handling. We'll call these "paragraph macros".

@<Parse the line as a possible paragraph macro definition@> =
	text_stream *para_macro_name = WebSyntax::macro_defined_at(L->classification);
	if (Str::len(para_macro_name) > 0) {
		L->category = MACRO_DEFINITION_LCAT;
		if (current_paragraph == NULL)
			Main::error_in_web(I"<...> definition begins outside of a paragraph", L);
		else Macros::create(S, current_paragraph, L, para_macro_name);
		code_lcat_for_body = CODE_BODY_LCAT; /* code follows on subsequent lines */
		code_pl_for_body = NULL;
		code_plainness_for_body = FALSE;
		hyperlink_body = FALSE;
		continue;
	}

@ An equals sign in column 1 can just mean the end of an extract, so:

@<Exit extract mode@> =
	L->category = END_EXTRACT_LCAT;

@<Deal with an insertion@> =
	L->category = COMMAND_LCAT;
	code_lcat_for_body = COMMENT_BODY_LCAT;
	switch (L->classification.subclassification) {
		case AUDIO_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Audio");
			L->command_code = AUDIO_CMD;
			L->text_operand = L->classification.operand1;
			break;
		case EMBEDDED_AV_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Videos");
			L->command_code = EMBED_CMD;
			L->text_operand = L->classification.operand1;
			L->text_operand2 = L->classification.operand2;
			break;
		case FIGURE_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Figures");
			L->command_code = FIGURE_CMD;
			L->text_operand = L->classification.operand1;
			break;
		case DOWNLOAD_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Download");
			L->command_code = DOWNLOAD_CMD;
			L->text_operand = L->classification.operand1;
			L->text_operand2 = L->classification.operand2;
			break;
		case VIDEO_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Videos");
			L->command_code = VIDEO_CMD;
			L->text_operand = L->classification.operand1;
			break;
		case CAROUSEL_ABOVE_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Carousels");
			L->command_code = CAROUSEL_ABOVE_CMD;
			L->text_operand = L->classification.operand1;
			break;
		case CAROUSEL_BELOW_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Carousels");
			L->command_code = CAROUSEL_BELOW_CMD;
			L->text_operand = L->classification.operand1;
			break;
		case CAROUSEL_END_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Carousels");
			code_lcat_for_body = COMMENT_BODY_LCAT;
			break;
		case CAROUSEL_SLIDE_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Carousels");
			code_lcat_for_body = COMMENT_BODY_LCAT;
			L->text_operand = L->classification.operand1;
			break;
		case CAROUSEL_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"Carousels");
			code_lcat_for_body = COMMENT_BODY_LCAT;
			L->text_operand = Str::new();
			break;
		default:
			internal_error("unimplemented insertion marker");
			break;
	}

@ But more usually an equals sign in column 1 is a structural marker:

@<Parse the line as an equals structural marker@> =
	L->category = BEGIN_CODE_LCAT;
	L->plainer = FALSE;
	code_lcat_for_body = CODE_BODY_LCAT;
	code_destination = NULL;
	code_pl_for_body = NULL;

	switch (L->classification.subclassification) {
		case NO_WSFSL:
			break;
		case EARLY_WSFSL:
			current_paragraph->placed_early = TRUE;
			break;
		case TEXT_AS_WSFSL:
			@<Make plainer@>;
			code_lcat_for_body = TEXT_EXTRACT_LCAT;
			code_destination = NULL;
			if (Str::len(L->classification.operand2) > 0)
				code_pl_for_body = Analyser::find_by_name(L->classification.operand2, W, TRUE);
			else
				code_pl_for_body = S->sect_language;
			break;
		case TEXT_FROM_AS_WSFSL:
			@<Make plainer@>;
			if (Str::len(L->classification.operand3) > 0)
				code_pl_for_body = Analyser::find_by_name(L->classification.operand3, W, TRUE);
			L->classification.subclassification = TEXT_AS_WSFSL;
			@<Spool from file@>;
			break;
		case TEXT_FROM_WSFSL:
			@<Make plainer@>;
			code_pl_for_body = NULL;
			L->classification.subclassification = TEXT_WSFSL;
			@<Spool from file@>;
			break;
		case TEXT_TO_WSFSL:
			@<Make plainer@>;
			code_lcat_for_body = TEXT_EXTRACT_LCAT;
			code_destination = L->classification.operand2;
			code_pl_for_body = Analyser::find_by_name(I"Extracts", W, TRUE);
			break;
		case TEXT_WSFSL:
			@<Make plainer@>;
			code_lcat_for_body = TEXT_EXTRACT_LCAT;
			code_destination = NULL;
			code_pl_for_body = NULL;
			break;
		case HTML_WSFSL:
			Tags::add_by_name(L->owning_paragraph, I"HTML");
			L->command_code = HTML_CMD;
			L->text_operand = L->classification.operand1;
			break;
		case VERY_EARLY_WSFSL:
			current_paragraph->placed_very_early = TRUE;
			break;
		case UNKNOWN_WSFSL:
			Main::error_in_web(I"unknown material after extract marker", L);
			break;
		default:
			internal_error("unimplemented extract marker");
			break;
	}
	code_plainness_for_body = L->plainer;
	hyperlink_body = L->enable_hyperlinks;
	continue;

@<Make plainer@> =
	match_results mr3 = Regexp::create_mr();
	while (TRUE) {
		if (Regexp::match(&mr3, L->classification.operand1, U" *(%C+) *(%c*?)")) {
			if (Str::eq(mr3.exp[0], I"undisplayed")) L->plainer = TRUE;
			else if (Str::eq(mr3.exp[0], I"hyperlinked")) L->enable_hyperlinks = TRUE;
			else {
				Main::error_in_web(
					I"only 'undisplayed' and/or 'hyperlinked' can precede 'text' here", L);	
			}
		} else break;
		Str::clear(L->classification.operand1);
		Str::copy(L->classification.operand1, mr3.exp[1]);
	}
	Regexp::dispose_of(&mr3);

@<Spool from file@> =
	L->category = BEGIN_CODE_LCAT;
	pathname *P = W->md->path_to_web;
	if ((S->md->owning_module) && (S->md->owning_module->module_location))
		P = S->md->owning_module->module_location; /* references are relative to module */
	filename *F = Filenames::from_text_relative(P, L->classification.operand2);
	linked_list *lines = Painter::lines(F);
	text_stream *T;
	source_line *latest = L;
	LOOP_OVER_LINKED_LIST(T, text_stream, lines) {
		source_line *TL = Lines::new_source_line_in(T, &(L->source), S);
		TL->classification = WebSyntax::new_cf(EXTRACT_MATTER_WSFL, NO_WSFSL);
		TL->next_line = latest->next_line;
		TL->plainer = L->plainer;
		latest->next_line = TL;
		latest = TL;
	}
	source_line *EEL = Lines::new_source_line_in(I"=", &(L->source), S);
	EEL->classification = WebSyntax::new_cf(EXTRACT_END_WSFL, NO_WSFSL);
	EEL->next_line = latest->next_line;
	latest->next_line = EEL;
	code_lcat_for_body = TEXT_EXTRACT_LCAT;

@ At one time there were hordes of these commands, but less is more.

@<Deal with a definition@> =
	text_stream *remainder = L->classification.operand1;
	switch (L->classification.subclassification) {
		case DEFINE_COMMAND_WSFSL:
			@<Deal with the define marker@>; break;
		case DEFAULT_COMMAND_WSFSL:
			L->default_defn = TRUE;
			@<Deal with the define marker@>; break;
		case ENUMERATE_COMMAND_WSFSL:
			@<Deal with the enumeration marker@>; break;
	}

@ This is for |@d| and |@define|. Definitions are intended to translate to
C preprocessor macros, Inform 6 |Constant|s, and so on.

@<Deal with the define marker@> =
	L->category = BEGIN_DEFINITION_LCAT;
	code_lcat_for_body = CONT_DEFINITION_LCAT;
	code_pl_for_body = NULL;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, remainder, U"(%C+) (%c+)")) {
		L->text_operand = Str::duplicate(mr.exp[0]); /* name of term defined */
		L->text_operand2 = Str::duplicate(mr.exp[1]); /* Value */
	} else {
		L->text_operand = Str::duplicate(remainder); /* name of term defined */
		L->text_operand2 = Str::new(); /* no value given */
	}
	Analyser::mark_reserved_word_at_line(L, L->text_operand, CONSTANT_COLOUR);
	Ctags::note_defined_constant(L, L->text_operand);
	Regexp::dispose_of(&mr);

@ This is for |@e| and |@enum|, which makes an automatically enumerated sort of |@d|.

@<Deal with the enumeration marker@> =
	L->category = BEGIN_DEFINITION_LCAT;
	text_stream *from = NULL;
	match_results mr = Regexp::create_mr();
	L->text_operand = Str::duplicate(remainder); /* name of term defined */
	TEMPORARY_TEXT(before)
	TEMPORARY_TEXT(after)
	if (LanguageMethods::parse_comment(S->sect_language, L->text_operand,
		before, after)) {
		Str::copy(L->text_operand, before);
	}
	DISCARD_TEXT(before)
	DISCARD_TEXT(after)
	Str::trim_white_space(L->text_operand);
	if (Regexp::match(&mr, L->text_operand, U"(%C+) from (%c+)")) {
		from = mr.exp[1];
		Str::copy(L->text_operand, mr.exp[0]);
	} else if (Regexp::match(&mr, L->text_operand, U"(%C+) (%c+)")) {
		Main::error_in_web(I"enumeration constants can't supply a value", L);
	}
	L->text_operand2 = Str::new();
	if (inweb_mode == TANGLE_MODE)
		Enumerations::define(L->text_operand2, L->text_operand, from, L);
	Analyser::mark_reserved_word_at_line(L, L->text_operand, CONSTANT_COLOUR);
	Ctags::note_defined_constant(L, L->text_operand);
	Regexp::dispose_of(&mr);

@ Here we handle paragraph breaks which may or may not be headings. In
version 1, |@p| was a heading, and |@pp| a grander heading, while plain |@|
is no heading at all. The use of "p" was a little confusing, and went back
to CWEB, which used the term "paragraph" differently from us: it was "p"
short for what CWEB called a "paragraph". We now use |@h| or equivalently
|@heading| for a heading.

The noteworthy thing here is the way we fool around with the text on the line
of the paragraph opening. This is one of the few cases where Inweb has
retained the stream-based style of CWEB, where escape characters can appear
anywhere in a line and line breaks are not significant. Thus
= (text)
	@h The chronology of French weaving. Auguste de Papillon (1734-56) soon
=
is split into two, so that the title of the paragraph is just "The chronology
of French weaving" and the remainder,
= (text)
	Auguste de Papillon (1734-56) soon
=
will be woven exactly as the succeeding lines will be.

@d ORDINARY_WEIGHT 0 /* an ordinary paragraph has this "weight" */
@d SUBHEADING_WEIGHT 1 /* a heading paragraph */

@<Deal with a paragraph start line@> =
	text_stream *titling = L->classification.operand2;
	text_stream *remainder = L->classification.operand1;
	int weight = ORDINARY_WEIGHT;
	L->category = PARAGRAPH_START_LCAT;
	if (Str::len(titling) > 0) {
		weight = SUBHEADING_WEIGHT;
		L->category = HEADING_START_LCAT;
		L->text_operand = Str::duplicate(titling);
	}
	if (Str::len(remainder) > 0) {
		L->text_operand2 = Str::duplicate(remainder);
	}
	@<Create a new paragraph, starting here, as new current paragraph@>;
	L->owning_paragraph = current_paragraph;
	W->no_paragraphs++;

@ So now it's time to create paragraph structures:

=
typedef struct paragraph {
	int placed_early; /* should appear early in the tangled code */
	int placed_very_early; /* should appear very early in the tangled code */
	int invisible; /* do not render paragraph number */
	struct text_stream *heading_text; /* if any - many paras have none */
	struct text_stream *ornament; /* a "P" for a pilcrow or "S" for section-marker */
	struct text_stream *paragraph_number; /* used in combination with the ornament */
	int next_child_number; /* used when working out paragraph numbers */
	struct paragraph *parent_paragraph; /* ditto */

	int weight; /* typographic prominence: one of the |*_WEIGHT| values */
	int starts_on_new_page; /* relevant for weaving to TeX only, of course */

	struct para_macro *defines_macro; /* there can only be one */
	struct linked_list *functions; /* of |function|: those defined in this para */
	struct linked_list *structures; /* of |language_type|: similarly */
	struct linked_list *taggings; /* of |paragraph_tagging| */
	struct linked_list *footnotes; /* of |footnote| */
	struct source_line *first_line_in_paragraph;
	struct section *under_section;
	CLASS_DEFINITION
} paragraph;

@<Create a new paragraph, starting here, as new current paragraph@> =
	paragraph *P = CREATE(paragraph);
	P->placed_early = FALSE;
	P->placed_very_early = FALSE;
	P->invisible = FALSE;
	if (Str::eq(Bibliographic::get_datum(W->md, I"Paragraph Numbers Visibility"), I"Off"))
		P->invisible = TRUE;
	P->heading_text = Str::duplicate(L->text_operand);
	P->ornament = Str::duplicate(I"S");
	WRITE_TO(P->paragraph_number, "%d", next_par_number++);
	P->parent_paragraph = NULL;
	P->next_child_number = 1;
	P->starts_on_new_page = FALSE;
	P->weight = weight;
	P->first_line_in_paragraph = L;
	P->defines_macro = NULL;
	P->functions = NEW_LINKED_LIST(function);
	P->structures = NEW_LINKED_LIST(language_type);
	P->taggings = NEW_LINKED_LIST(paragraph_tagging);
	P->footnotes = NEW_LINKED_LIST(footnote);

	P->under_section = S;
	S->sect_paragraphs++;
	ADD_TO_LINKED_LIST(P, paragraph, S->paragraphs);

	text_stream *tag;
	LOOP_OVER_LINKED_LIST(tag, text_stream, L->classification.tag_list) {
		Tags::add_by_name(P, tag);
	}
	if (S->tag_with) Tags::add_to_paragraph(P, S->tag_with, NULL);

	current_paragraph = P;

@ Finally, we're down to either commentary or code.

@<This is a line destined for commentary@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, U">> (%c+)")) {
		L->category = SOURCE_DISPLAY_LCAT;
		L->text_operand = Str::duplicate(mr.exp[0]);
	}
	Regexp::dispose_of(&mr);

@ Note that in an |@d| definition, a blank line is treated as the end of the
definition. (This is unnecessary for C, and is a point of difference with
CWEB, but is needed for languages which don't allow multi-line definitions.)

@<This is a line destined for the verbatim code@> =
	if ((L->category != BEGIN_DEFINITION_LCAT) && (L->category != COMMAND_LCAT)) {
		L->category = code_lcat_for_body;
		L->plainer = code_plainness_for_body;
		L->enable_hyperlinks = hyperlink_body;
		if (L->category == TEXT_EXTRACT_LCAT) {
			L->colour_as = code_pl_for_body;
			if (code_destination) L->extract_to = Str::duplicate(code_destination);
		}
	}

	if ((L->category == CONT_DEFINITION_LCAT) && (Regexp::string_is_white_space(L->text))) {
		L->category = COMMENT_BODY_LCAT;
		code_lcat_for_body = COMMENT_BODY_LCAT;
	}

	LanguageMethods::subcategorise_line(S->sect_language, L);

@ The purpose text occurs just below the heading.

=
text_stream *Parser::extract_purpose(text_stream *prologue, source_line *XL, section *S, source_line **adjust) {
	text_stream *P = Str::duplicate(prologue);
	while ((XL) && (XL->next_line) && (XL->owning_section == S) &&
		(((adjust) && (Characters::isalnum(Str::get_first_char(XL->text)))) ||
		 ((!adjust) && (XL->category == COMMENT_BODY_LCAT)))) {
		WRITE_TO(P, " %S", XL->text);
		XL->category = PURPOSE_BODY_LCAT;
		if (adjust) *adjust = XL;
		XL = XL->next_line;
	}
	Str::trim_white_space(P);
	return P;
}

@h Footnote notation.

=
typedef struct footnote {
	int footnote_cue_number; /* used only for |FOOTNOTE_TEXT_LCAT| lines */
	int footnote_text_number; /* used only for |FOOTNOTE_TEXT_LCAT| lines */
	struct text_stream *cue_text;
	int cued_already;
	CLASS_DEFINITION
} footnote;

@<Work out footnote numbering for this paragraph@> =
	int next_footnote_in_para = 1;
	footnote *current_text = NULL;
	TEMPORARY_TEXT(before)
	TEMPORARY_TEXT(cue)
	TEMPORARY_TEXT(after)
	for (source_line *L = P->first_line_in_paragraph;
		((L) && (L->owning_paragraph == P)); L = L->next_line)
		if (WebSyntax::is_commentary(L->classification)) {
			Str::clear(before); Str::clear(cue); Str::clear(after);
			if (Parser::detect_footnote(W, L->text, before, cue, after)) {
				int this_is_a_cue = FALSE;
				LOOP_THROUGH_TEXT(pos, before)
					if (Characters::is_whitespace(Str::get(pos)) == FALSE)
						this_is_a_cue = TRUE;
				if (this_is_a_cue == FALSE)
					@<This line begins a footnote text@>;
			}
			L->footnote_text = current_text;
		}
	DISCARD_TEXT(before)
	DISCARD_TEXT(cue)
	DISCARD_TEXT(after)

@<This line begins a footnote text@> =
	L->category = FOOTNOTE_TEXT_LCAT;
	footnote *F = CREATE(footnote);	
	F->footnote_cue_number = Str::atoi(cue, 0);
	if (F->footnote_cue_number != next_footnote_in_para) {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "footnote should be numbered [%d], not [%d]",
			next_footnote_in_para, F->footnote_cue_number);
		Main::error_in_web(err, L);
		DISCARD_TEXT(err)
	}
	next_footnote_in_para++;
	F->footnote_text_number = next_footnote++;
	F->cue_text = Str::new();
	F->cued_already = FALSE;
	WRITE_TO(F->cue_text, "%d", F->footnote_text_number);
	ADD_TO_LINKED_LIST(F, footnote, P->footnotes);
	current_text = F;

@ Where:

=
int Parser::detect_footnote(web *W, text_stream *matter, text_stream *before,
	text_stream *cue, text_stream *after) {
	text_stream *fn_on_notation =
		Bibliographic::get_datum(W->md, I"Footnote Begins Notation");
	text_stream *fn_off_notation =
		Bibliographic::get_datum(W->md, I"Footnote Ends Notation");
	if (Str::ne(fn_on_notation, I"Off")) {
		int N1 = Str::len(fn_on_notation);
		int N2 = Str::len(fn_off_notation);
		if ((N1 > 0) && (N2 > 0))
			for (int i=0; i < Str::len(matter); i++) {
				if (Str::includes_at(matter, i, fn_on_notation)) {
					int j = i + N1 + 1;
					while (j < Str::len(matter)) {
						if (Str::includes_at(matter, j, fn_off_notation)) {
							TEMPORARY_TEXT(b)
							TEMPORARY_TEXT(c)
							TEMPORARY_TEXT(a)
							Str::substr(b, Str::start(matter), Str::at(matter, i));
							Str::substr(c, Str::at(matter, i + N1), Str::at(matter, j));
							Str::substr(a, Str::at(matter, j + N2), Str::end(matter));
							int allow = TRUE;
							LOOP_THROUGH_TEXT(pos, c)
								if (Characters::isdigit(Str::get(pos)) == FALSE)
									allow = FALSE;
							if (allow) {
								Str::clear(before); Str::copy(before, b);
								Str::clear(cue); Str::copy(cue, c);
								Str::clear(after); Str::copy(after, a);
							}
							DISCARD_TEXT(b)
							DISCARD_TEXT(c)
							DISCARD_TEXT(a)
							if (allow) return TRUE;
						}
						j++;
					}			
				}
			}
	}
	return FALSE;
}

footnote *Parser::find_footnote_in_para(paragraph *P, text_stream *cue) {
	int N = Str::atoi(cue, 0);		
	footnote *F;
	if (P)
		LOOP_OVER_LINKED_LIST(F, footnote, P->footnotes)
			if (N == F->footnote_cue_number)
				return F;
	return NULL;
}

@h Parsing of dimensions.
It's possible, optionally, to specify width and height for some visual matter.
This is the syntax used.

@d POINTS_PER_CM 72

=
text_stream *Parser::dimensions(text_stream *item, int *w, int *h) {
	*w = -1; *h = -1;
	text_stream *use = item;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, item, U"(%c+) at (%d+) by (%d+)")) {
		*w = Str::atoi(mr.exp[1], 0);
		*h = Str::atoi(mr.exp[2], 0);
		use = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, item, U"(%c+) at height (%d+)")) {
		*h = Str::atoi(mr.exp[1], 0);
		use = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, item, U"(%c+) at width (%d+)")) {
		*w = Str::atoi(mr.exp[1], 0);
		use = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, item, U"(%c+) at (%d+)cm by (%d+)cm")) {
		*w = POINTS_PER_CM*Str::atoi(mr.exp[1], 0);
		*h = POINTS_PER_CM*Str::atoi(mr.exp[2], 0);
		use = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, item, U"(%c+) at height (%d+)cm")) {
		*h = POINTS_PER_CM*Str::atoi(mr.exp[1], 0);
		use = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, item, U"(%c+) at width (%d+)cm")) {
		*w = POINTS_PER_CM*Str::atoi(mr.exp[1], 0);
		use = Str::duplicate(mr.exp[0]);
	}
	Regexp::dispose_of(&mr);
	return use;
}
