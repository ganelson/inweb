[Parser::] The Parser.

To work through the program read in, assigning each line its category,
and noting down other useful information as we go.

@h Sequence of parsing.
At this point, thw web has been read into memory. It's a linked list of
chapters, each of which is a linked list of sections, each of which must
be parsed in turn.

When we're done, we offer the support code for the web's programming language
a chance to do some further work, if it wants to. (This is how, for example,
function definitions are recognised in C programs.) There is no requirement
for it to do anything.

=
void Parser::parse_web(web *W, int inweb_mode) {
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			@<Parse a section@>;
	Languages::further_parsing(W, W->main_language);
}

@ The task now is to parse those source lines, categorise them, and group them
further into a linked list of paragraphs. The basic method would be simple
enough, but is made more elaborate by supporting both version 1 and version 2
markup syntax, and trying to detect incorrect uses of one within the other.

@<Parse a section@> =
	int comment_mode = TRUE;
	int code_lcat_for_body = NO_LCAT;
	int before_bar = TRUE;
	int next_par_number = 1;
	paragraph *current_paragraph = NULL;
	TEMPORARY_TEXT(tag_list);
	for (source_line *L = S->first_line, *PL = NULL; L; PL = L, L = L->next_line) {
		@<Apply tag list, if any@>;
		@<Remove tag list, if any@>;
		@<Detect implied paragraph breaks@>;
		@<Determine category for this source line@>;
	}
	DISCARD_TEXT(tag_list);
	@<In version 2 syntax, construe the comment under the heading as the purpose@>;
	@<If the section as a whole is tagged, apply that tag to each paragraph in it@>;

@ In versiom 2 syntax, the notation for tags was clarified. The tag list
for a paragraph is the run of |^"This"| and |^"That"| markers at the end of
the line introducing that paragraph. They can only occur, therefore, on a
line beginning with an |@|. We extract them into a string called |tag_list|.
(The reason we can't act on them straight away, which would make for simpler
code, is that they need to be applied to a paragraph structure which doesn't
yet exist -- it will only exist when the line has been fully parsed.)

@<Remove tag list, if any@> =
	if (Str::get_first_char(L->text) == '@') {
		match_results mr = Regexp::create_mr();
		while (Regexp::match(&mr, L->text, L"(%c*?)( *%^\"%c+?\")(%c*)")) {
			if (S->using_syntax < V2_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "tags written ^\"thus\"", V2_SYNTAX);
			Str::clear(L->text);
			WRITE_TO(tag_list, "%S", mr.exp[1]);
			Str::copy(L->text, mr.exp[0]); WRITE_TO(L->text, " %S", mr.exp[2]);
		}
		Regexp::dispose_of(&mr);
	}

@ And now it's later, and we can safely apply the tags. |current_paragraph|
now points to the para which was created by this line, not the one before.

@<Apply tag list, if any@> =
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, tag_list, L" *%^\"(%c+?)\" *(%c*)")) {
		Tags::add_by_name(current_paragraph, mr.exp[0]);
		Str::copy(tag_list, mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
	Str::clear(tag_list);

@<If the section as a whole is tagged, apply that tag to each paragraph in it@> =
	paragraph *P;
	if (S->tag_with)
		LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)
			Tags::add_to_paragraph(P, S->tag_with, NULL);

@ The "purpose" of a section is a brief note about what it's for. In version 1
syntax, this had to be explicitly declared with a |@Purpose:| command; in
version 2 it's much tidier.

@<In version 2 syntax, construe the comment under the heading as the purpose@> =
	if (S->using_syntax >= V2_SYNTAX) {
		source_line *L = S->first_line;
		if ((L) && (L->category == CHAPTER_HEADING_LCAT)) L = L->next_line;	
		S->sect_purpose = Parser::extract_purpose(I"", L?L->next_line: NULL, S, NULL);
		if (Str::len(S->sect_purpose) > 0) L->next_line->category = PURPOSE_LCAT;
	}

@ A new paragraph is implied when a macro definition begins in the middle of
what otherwise would be code, or when a paragraph and its code divider are
immediately adjacent on the same line.

@<Detect implied paragraph breaks@> =
	match_results mr = Regexp::create_mr();
	if ((PL) && (PL->category == CODE_BODY_LCAT) &&
		(Str::get_first_char(L->text) == '@') && (Str::get_at(L->text, 1) == '<') &&
		(Regexp::match(&mr, L->text, L"%c<(%c+)@> *= *")) &&
		(S->using_syntax >= V2_SYNTAX)) {
		@<Insert an implied paragraph break@>;
	}
	if ((PL) && (Regexp::match(&mr, L->text, L"@ *= *"))) {
		Str::clear(L->text);
		Str::copy(L->text, I"=");
		if (S->using_syntax < V2_SYNTAX)
			Parser::wrong_version(S->using_syntax, L, "implied paragraph breaks", V2_SYNTAX);
		@<Insert an implied paragraph break@>;
	}
	Regexp::dispose_of(&mr);

@ We handle implied paragraph dividers by inserting a paragraph marker and
reparsing from there.

@<Insert an implied paragraph break@> =
	source_line *NL = Lines::new_source_line(I"@", &(L->source));
	PL->next_line = NL;
	NL->next_line = L;
	L = PL;
	Regexp::dispose_of(&mr);
	continue;

@h Categorisatiom.
This is where the work is really done. We have a source line: is it comment,
code, definition, what?

@<Determine category for this source line@> =
	L->is_commentary = comment_mode;
	L->category = COMMENT_BODY_LCAT; /* until set otherwise down below */
	L->owning_paragraph = current_paragraph;

	if (L->source.line_count == 0) @<Parse the line as a probable chapter heading@>;
	if (L->source.line_count <= 1) @<Parse the line as a probable section heading@>;
	@<Parse the line as a possible Inweb command@>;
	@<Parse the line as a possible paragraph macro definition@>;
	if (Str::get_first_char(L->text) == '=') {
		if (S->using_syntax < V2_SYNTAX)
			Parser::wrong_version(S->using_syntax, L, "column-1 '=' as code divider", V2_SYNTAX);
		@<Parse the line as an equals structural marker@>;
	}
	if ((Str::get_first_char(L->text) == '@') &&
		(Str::get_at(L->text, 1) != '<') &&
		(L->category != MACRO_DEFINITION_LCAT))
		@<Parse the line as a structural marker@>;
	if (comment_mode) @<This is a line destined for commentary@>;
	if (comment_mode == FALSE) @<This is a line destined for the verbatim code@>;

@ This must be one of the inserted lines marking chapter headings; it doesn't
come literally from the source web.

@<Parse the line as a probable chapter heading@> =
	if (Str::eq_wide_string(L->text, L"Chapter Heading")) {
		comment_mode = TRUE;
		L->is_commentary = TRUE;
		L->category = CHAPTER_HEADING_LCAT;
	}

@ The top line of a section gives its title and range; in InC, it can
also give the namespace for its functions.

@<Parse the line as a probable section heading@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, L"%[(%C+)%] (%C+/%C+): (%c+).")) {
		S->sect_namespace = Str::duplicate(mr.exp[0]);
		S->range = Str::duplicate(mr.exp[1]);
		S->sect_title = Str::duplicate(mr.exp[2]);
		L->text_operand = Str::duplicate(mr.exp[2]);
		L->category = SECTION_HEADING_LCAT;
	} else if (Regexp::match(&mr, L->text, L"(%C+/%C+): (%c+).")) {
		S->range = Str::duplicate(mr.exp[0]);
		S->sect_title = Str::duplicate(mr.exp[1]);
		L->text_operand = Str::duplicate(mr.exp[1]);
		L->category = SECTION_HEADING_LCAT;
	} else if (Regexp::match(&mr, L->text, L"%[(%C+::)%] (%c+).")) {
		S->sect_namespace = Str::duplicate(mr.exp[0]);
		S->sect_title = Str::duplicate(mr.exp[1]);
		@<Set the range to an automatic abbreviation of the relative pathname@>;
		L->text_operand = Str::duplicate(mr.exp[1]);
		L->category = SECTION_HEADING_LCAT;
	} else if (Regexp::match(&mr, L->text, L"(%c+).")) {
		S->sect_title = Str::duplicate(mr.exp[0]);
		@<Set the range to an automatic abbreviation of the relative pathname@>;
		L->text_operand = Str::duplicate(mr.exp[0]);
		L->category = SECTION_HEADING_LCAT;
	}
	Regexp::dispose_of(&mr);

@ If no range is supplied, we make one ourselves.

@<Set the range to an automatic abbreviation of the relative pathname@> =
	S->range = Str::new();

	text_stream *from = S->sect_title;
	int letters_from_each_word = 5;
	do {
		Str::clear(S->range);
		WRITE_TO(S->range, "%S/", C->ch_range);
		@<Make the tail using this many consonants from each word@>;
		if (--letters_from_each_word == 0) break;
	} while (Str::len(S->range) > 5);

	@<Terminate with disambiguating numbers in case of collisions@>;

@ We collapse words to an initial letter plus consonants: thus "electricity"
would be "elctrcty", since we don't count "y" as a vowel here.

@<Make the tail using this many consonants from each word@> =
	int sn = 0, sw = Str::len(S->range);
	if (Str::get_at(from, sn) == FOLDER_SEPARATOR) sn++;
	int letters_from_current_word = 0;
	while ((Str::get_at(from, sn)) && (Str::get_at(from, sn) != '.')) {
		if (Str::get_at(from, sn) == ' ') letters_from_current_word = 0;
		else {
			if (letters_from_current_word < letters_from_each_word) {
				if (Str::get_at(from, sn) != '-') {
					int l = tolower(Str::get_at(from, sn));
					if ((letters_from_current_word == 0) ||
						((l != 'a') && (l != 'e') && (l != 'i') && (l != 'o') && (l != 'u'))) {
						Str::put_at(S->range, sw++, l); Str::put_at(S->range, sw, 0);
						letters_from_current_word++;
					}
				}
			}
		}
		sn++;
	}

@ We never want two sections to have the same range.

@<Terminate with disambiguating numbers in case of collisions@> =
	TEMPORARY_TEXT(original_range);
	Str::copy(original_range, S->range);
	int disnum = 0, collision = FALSE;
	do {
		if (disnum++ > 0) {
			int ldn = 5;
			if (disnum >= 1000) ldn = 4;
			else if (disnum >= 100) ldn = 3;
			else if (disnum >= 10) ldn = 2;
			else ldn = 1;
			Str::clear(S->range);
			WRITE_TO(S->range, "%S%d", original_range);
			Str::truncate(S->range, Str::len(S->range) - ldn);
			WRITE_TO(S->range, "%d", disnum);
		}
		collision = FALSE;
		chapter *C;
		section *S2;
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S2, section, C->sections)
				if ((S2 != S) && (Str::eq(S2->range, S->range))) {
					collision = TRUE; break;
				}
	} while (collision);
	DISCARD_TEXT(original_range);

@ Version 1 syntax was cluttered up with a number of hardly-used markup
syntaxes called "commands", written in double squared brackets |[[Thus]]|.
In version 2, this notation is used only for figures.

@<Parse the line as a possible Inweb command@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, L"%[%[(%c+)%]%]")) {
		TEMPORARY_TEXT(full_command);
		TEMPORARY_TEXT(command_text);
		Str::copy(full_command, mr.exp[0]);
		Str::copy(command_text, mr.exp[0]);
		L->category = COMMAND_LCAT;
		if (Regexp::match(&mr, command_text, L"(%c+?): *(%c+)")) {
			Str::copy(command_text, mr.exp[0]);
			L->text_operand = Str::duplicate(mr.exp[1]);
		}
		if (Str::eq_wide_string(command_text, L"Page Break")) {
			if (S->using_syntax > V1_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "[[Page Break]]", V1_SYNTAX);
			L->command_code = PAGEBREAK_CMD;
		} else if (Str::eq_wide_string(command_text, L"Grammar Index"))
			L->command_code = GRAMMAR_INDEX_CMD;
		else if (Str::eq_wide_string(command_text, L"Tag")) {
			if (S->using_syntax > V1_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "[[Tag...]]", V1_SYNTAX);
			Tags::add_by_name(L->owning_paragraph, L->text_operand);
			L->command_code = TAG_CMD;
		} else if (Str::eq_wide_string(command_text, L"Figure")) {
			if (S->using_syntax > V1_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "[[Figure...]]", V1_SYNTAX);
			Tags::add_by_name(L->owning_paragraph, I"Figures");
			L->command_code = FIGURE_CMD;
		} else {
			if (S->using_syntax >= V2_SYNTAX) {
				Tags::add_by_name(L->owning_paragraph, I"Figures");
				L->command_code = FIGURE_CMD;
				Str::copy(L->text_operand, full_command);
			} else {
				Main::error_in_web(I"unknown [[command]]", L);
			}
		}
		L->is_commentary = TRUE;
		DISCARD_TEXT(command_text);
		DISCARD_TEXT(full_command);
	}
	Regexp::dispose_of(&mr);

@ Some paragraphs define angle-bracketed macros, and those need special
handling. We'll call these "paragraph macros".

@<Parse the line as a possible paragraph macro definition@> =
	match_results mr = Regexp::create_mr();
	if ((Str::get_first_char(L->text) == '@') && (Str::get_at(L->text, 1) == '<') &&
		(Regexp::match(&mr, L->text, L"%c<(%c+)@> *= *"))) {
		TEMPORARY_TEXT(para_macro_name);
		Str::copy(para_macro_name, mr.exp[0]);
		L->category = MACRO_DEFINITION_LCAT;
		if (current_paragraph == NULL)
			Main::error_in_web(I"<...> definition begins outside of a paragraph", L);
		else Macros::create(S, current_paragraph, L, para_macro_name);
		comment_mode = FALSE;
		L->is_commentary = FALSE;
		code_lcat_for_body = CODE_BODY_LCAT; /* code follows on subsequent lines */
		DISCARD_TEXT(para_macro_name);
		continue;
	}
	Regexp::dispose_of(&mr);

@ A structural marker is introduced by an |@| in column 1, and is a structural
division in the current section.

@<Parse the line as a structural marker@> =
	TEMPORARY_TEXT(command_text);
	Str::copy(command_text, L->text);
	Str::delete_first_character(command_text); /* i.e., strip the at-sign from the front */
	TEMPORARY_TEXT(remainder);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, command_text, L"(%C*) *(%c*?)")) {
		Str::copy(command_text, mr.exp[0]);
		Str::copy(remainder, mr.exp[1]);
	}
	@<Deal with a structural marker@>;
	DISCARD_TEXT(remainder);
	DISCARD_TEXT(command_text);
	Regexp::dispose_of(&mr);
	continue;

@ An equals sign in column 1 is also a structural marker:

@<Parse the line as an equals structural marker@> =
	L->category = BEGIN_CODE_LCAT;
	code_lcat_for_body = CODE_BODY_LCAT;
	comment_mode = FALSE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, L"= *(%c+) *")) {
		if ((current_paragraph) && (Str::eq(mr.exp[0], I"(very early code)"))) {
			current_paragraph->placed_very_early = TRUE;
		} else if ((current_paragraph) && (Str::eq(mr.exp[0], I"(early code)"))) {
			current_paragraph->placed_early = TRUE;
		} else if ((current_paragraph) && (Str::eq(mr.exp[0], I"(not code)"))) {
			code_lcat_for_body = TEXT_EXTRACT_LCAT;
		} else {
			Main::error_in_web(I"unknown bracketed annotation", L);
		}
	} else if (Regexp::match(&mr, L->text, L"= *%C%c*")) {
		Main::error_in_web(I"unknown material after '='", L);
	}
	Regexp::dispose_of(&mr);
	continue;

@ So here we have the possibilities which start with a column-1 |@| sign.
There appear to be hordes of these, but in fact most of them were removed
in Inweb syntax version 2: in modern syntax, only |@d|, |@e|, |@h|, their
long forms |@define|, |@enum| and |@heading|, and plain old |@| remain.
(But |@e| has a different meaning from in version 1.)

@<Deal with a structural marker@> =
	if (Str::eq_wide_string(command_text, L"Purpose:")) @<Deal with Purpose@>
	else if (Str::eq_wide_string(command_text, L"Interface:")) @<Deal with Interface@>
	else if (Str::eq_wide_string(command_text, L"Definitions:")) @<Deal with Definitions@>
	else if (Regexp::match(&mr, command_text, L"----+")) @<Deal with the bar@>
	else if ((Str::eq_wide_string(command_text, L"c")) ||
			(Str::eq_wide_string(command_text, L"x")) ||
			((S->using_syntax == V1_SYNTAX) && (Str::eq_wide_string(command_text, L"e"))))
				@<Deal with the code and extract markers@>
	else if (Str::eq_wide_string(command_text, L"d")) @<Deal with the define marker@>
	else if (Str::eq_wide_string(command_text, L"define")) {
		if (S->using_syntax < V2_SYNTAX)
			Parser::wrong_version(S->using_syntax, L, "'@define' for definitions (use '@d' instead)", V2_SYNTAX);
		@<Deal with the define marker@>;
	} else if (Str::eq_wide_string(command_text, L"enum")) @<Deal with the enumeration marker@>
	else if ((Str::eq_wide_string(command_text, L"e")) && (S->using_syntax >= V2_SYNTAX))
		@<Deal with the enumeration marker@>
	else {
		int weight = -1, new_page = FALSE;
		if (Str::eq_wide_string(command_text, L"")) weight = ORDINARY_WEIGHT;
		if ((Str::eq_wide_string(command_text, L"h")) || (Str::eq_wide_string(command_text, L"heading"))) {
			if (S->using_syntax < V2_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "'@h' or '@heading' for headings (use '@p' instead)", V2_SYNTAX);
			weight = SUBHEADING_WEIGHT;
		}
		if (Str::eq_wide_string(command_text, L"p")) {
			if (S->using_syntax > V1_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "'@p' for headings (use '@h' instead)", V1_SYNTAX);
			weight = SUBHEADING_WEIGHT;
		}
		if (Str::eq_wide_string(command_text, L"pp")) {
			if (S->using_syntax > V1_SYNTAX)
				Parser::wrong_version(S->using_syntax, L, "'@pp' for super-headings", V1_SYNTAX);
			weight = SUBHEADING_WEIGHT; new_page = TRUE;
		}
		if (weight >= 0) @<Begin a new paragraph of this weight@>
		else Main::error_in_web(I"don't understand @command", L);
	}

@ In version 1 syntax there were some peculiar special headings above a divider
in the file made of hyphens, called "the bar". All of that has gone in V2.

@<Deal with Purpose@> =
	if (before_bar == FALSE) Main::error_in_web(I"Purpose used after bar", L);
	if (S->using_syntax >= V2_SYNTAX)
		Parser::wrong_version(S->using_syntax, L, "'@Purpose'", V1_SYNTAX);
	L->category = PURPOSE_LCAT;
	L->is_commentary = TRUE;
	L->text_operand = Str::duplicate(remainder);
	S->sect_purpose = Parser::extract_purpose(remainder, L->next_line, L->owning_section, &L);

@<Deal with Interface@> =
	if (S->using_syntax >= V2_SYNTAX)
		Parser::wrong_version(S->using_syntax, L, "'@Interface'", V1_SYNTAX);
	if (before_bar == FALSE) Main::error_in_web(I"Interface used after bar", L);
	L->category = INTERFACE_LCAT;
	L->is_commentary = TRUE;
	source_line *XL = L->next_line;
	while ((XL) && (XL->next_line) && (XL->owning_section == L->owning_section)) {
		if (Str::get_first_char(XL->text) == '@') break;
		XL->category = INTERFACE_BODY_LCAT;
		L = XL;
		XL = XL->next_line;
	}

@<Deal with Definitions@> =
	if (S->using_syntax >= V2_SYNTAX)
		Parser::wrong_version(S->using_syntax, L, "'@Definitions' headings", V1_SYNTAX);
	if (before_bar == FALSE) Main::error_in_web(I"Definitions used after bar", L);
	L->category = DEFINITIONS_LCAT;
	L->is_commentary = TRUE;
	before_bar = TRUE;
	next_par_number = 1;

@ An |@| sign in the first column, followed by a row of four or more dashes,
constitutes the optional division bar in a section.

@<Deal with the bar@> =
	if (S->using_syntax >= V2_SYNTAX)
		Parser::wrong_version(S->using_syntax, L, "the bar '----...'", V1_SYNTAX);
	if (before_bar == FALSE) Main::error_in_web(I"second bar in the same section", L);
	L->category = BAR_LCAT;
	L->is_commentary = TRUE;
	comment_mode = TRUE;
	S->barred = TRUE;
	before_bar = FALSE;
	next_par_number = 1;

@ In version 1, the division point where a paragraoh begins to go into
verbatim code was not marked with an equals sign, but with one of the three
commands |@c| ("code"), |@e| ("early code") and |@x| ("code-like extract").
These had identical behaviour except for whether or not to tangle what
follows:

@<Deal with the code and extract markers@> =
	if (S->using_syntax > V1_SYNTAX)
		Parser::wrong_version(S->using_syntax, L, "'@c' and '@x'", V1_SYNTAX);
	L->category = BEGIN_CODE_LCAT;
	if ((Str::eq_wide_string(command_text, L"e")) && (current_paragraph))
		current_paragraph->placed_early = TRUE;
	if (Str::eq_wide_string(command_text, L"x")) code_lcat_for_body = TEXT_EXTRACT_LCAT;
	else code_lcat_for_body = CODE_BODY_LCAT;
	comment_mode = FALSE;

@ This is for |@d| and |@define|. Definitions are intended to translate to
C preprocessor macros, Inform 6 |Constant|s, and so on.

@<Deal with the define marker@> =
	L->category = BEGIN_DEFINITION_LCAT;
	code_lcat_for_body = CONT_DEFINITION_LCAT;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, remainder, L"(%C+) (%c+)")) {
		L->text_operand = Str::duplicate(mr.exp[0]); /* name of term defined */
		L->text_operand2 = Str::duplicate(mr.exp[1]); /* Value */
	} else {
		L->text_operand = Str::duplicate(remainder); /* name of term defined */
		L->text_operand2 = Str::new(); /* no value given */
	}
	Analyser::mark_reserved_word(S, L->text_operand, CONSTANT_COLOUR);
	comment_mode = FALSE;
	L->is_commentary = FALSE;
	Regexp::dispose_of(&mr);

@ This is for |@e| (in version 2) and |@enum|, which makes an automatically
enumerated sort of |@d|.

@<Deal with the enumeration marker@> =
	L->category = BEGIN_DEFINITION_LCAT;
	text_stream *from = NULL;
	match_results mr = Regexp::create_mr();
	L->text_operand = Str::duplicate(remainder); /* name of term defined */
	TEMPORARY_TEXT(before);
	TEMPORARY_TEXT(after);
	if (Languages::parse_comment(S->sect_language, L->text_operand,
		before, after)) {
		Str::copy(L->text_operand, before);
	}
	DISCARD_TEXT(before);
	DISCARD_TEXT(after);
	Str::trim_white_space(L->text_operand);
	if (Regexp::match(&mr, L->text_operand, L"(%C+) from (%c+)")) {
		from = mr.exp[1];
		Str::copy(L->text_operand, mr.exp[0]);
	} else if (Regexp::match(&mr, L->text_operand, L"(%C+) (%c+)")) {
		Main::error_in_web(I"enumeration constants can't supply a value", L);
	}
	L->text_operand2 = Str::new();
	if (inweb_mode == TANGLE_MODE)
		Enumerations::define(L->text_operand2, L->text_operand, from, L);
	Analyser::mark_reserved_word(S, L->text_operand, CONSTANT_COLOUR);
	comment_mode = FALSE;
	L->is_commentary = FALSE;
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

	|@h The chronology of French weaving. Auguste de Papillon (1734-56) soon|

is split into two, so that the title of the paragraph is just "The chronology
of French weaving" and the remainder,

	|Auguste de Papillon (1734-56) soon|

will be woven exactly as the succeeding lines will be.

@d ORDINARY_WEIGHT 0 /* an ordinary paragraph has this "weight" */
@d SUBHEADING_WEIGHT 1 /* a heading paragraph */

@<Begin a new paragraph of this weight@> =
	comment_mode = TRUE;
	L->is_commentary = TRUE;
	L->category = PARAGRAPH_START_LCAT;
	if (weight == SUBHEADING_WEIGHT) L->category = HEADING_START_LCAT;
	L->text_operand = Str::new(); /* title */
	match_results mr = Regexp::create_mr();
	if ((weight == SUBHEADING_WEIGHT) && (Regexp::match(&mr, remainder, L"(%c+). (%c+)"))) {
		L->text_operand = Str::duplicate(mr.exp[0]);
		L->text_operand2 = Str::duplicate(mr.exp[1]);
	} else if ((weight == SUBHEADING_WEIGHT) && (Regexp::match(&mr, remainder, L"(%c+). *"))) {
		L->text_operand = Str::duplicate(mr.exp[0]);
		L->text_operand2 = Str::new();
	} else {
		L->text_operand = Str::new();
		L->text_operand2 = Str::duplicate(remainder);
	}
	@<Create a new paragraph, starting here, as new current paragraph@>;

	L->owning_paragraph = current_paragraph;
	W->no_paragraphs++;
	Regexp::dispose_of(&mr);

@ So now it's time to create paragraph structures:

=
typedef struct paragraph {
	int above_bar; /* placed above the dividing bar in its section (in Version 1 syntax) */
	int placed_early; /* should appear early in the tangled code */
	int placed_very_early; /* should appear very early in the tangled code */
	struct text_stream *ornament; /* a "P" for a pilcrow or "S" for section-marker */
	struct text_stream *paragraph_number; /* used in combination with the ornament */
	int next_child_number; /* used when working out paragraph numbers */
	struct paragraph *parent_paragraph; /* ditto */

	int weight; /* typographic prominence: one of the |*_WEIGHT| values */
	int starts_on_new_page; /* relevant for weaving to TeX only, of course */

	struct para_macro *defines_macro; /* there can only be one */
	struct linked_list *functions; /* of |function|: those defined in this para */
	struct linked_list *structures; /* of |c_structure|: similarly */
	struct linked_list *taggings; /* of |paragraph_tagging| */
	struct source_line *first_line_in_paragraph;
	struct section *under_section;
	MEMORY_MANAGEMENT
} paragraph;

@<Create a new paragraph, starting here, as new current paragraph@> =
	paragraph *P = CREATE(paragraph);
	if (S->using_syntax > V1_SYNTAX) {
		P->above_bar = FALSE;
		P->placed_early = FALSE;
		P->placed_very_early = FALSE;
	} else {
		P->above_bar = before_bar;
		P->placed_early = before_bar;
		P->placed_very_early = FALSE;
	}
	if ((S->using_syntax == V1_SYNTAX) && (before_bar))
		P->ornament = Str::duplicate(I"P");
	else
		P->ornament = Str::duplicate(I"S");
	WRITE_TO(P->paragraph_number, "%d", next_par_number++);
	P->parent_paragraph = NULL;
	P->next_child_number = 1;
	P->starts_on_new_page = FALSE;
	P->weight = weight;
	P->first_line_in_paragraph = L;
	P->defines_macro = NULL;
	P->functions = NEW_LINKED_LIST(function);
	P->structures = NEW_LINKED_LIST(c_structure);
	P->taggings = NEW_LINKED_LIST(paragraph_tagging);

	P->under_section = S;
	S->sect_paragraphs++;
	ADD_TO_LINKED_LIST(P, paragraph, S->paragraphs);

	current_paragraph = P;

@ Finally, we're down to either commentary or code.

@<This is a line destined for commentary@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, L">> (%c+)")) {
		L->category = SOURCE_DISPLAY_LCAT;
		L->text_operand = Str::duplicate(mr.exp[0]);
	}
	Regexp::dispose_of(&mr);

@ Note that in an |@d| definition, a blank line is treated as the end of the
definition. (This is unnecessary for C, and is a point of difference with
CWEB, but is needed for languages which don't allow multi-line definitions.)

@<This is a line destined for the verbatim code@> =
	if ((L->category != BEGIN_DEFINITION_LCAT) && (L->category != COMMAND_LCAT))
		L->category = code_lcat_for_body;

	if ((L->category == CONT_DEFINITION_LCAT) && (Regexp::string_is_white_space(L->text))) {
		L->category = COMMENT_BODY_LCAT;
		L->is_commentary = TRUE;
		code_lcat_for_body = COMMENT_BODY_LCAT;
		comment_mode = TRUE;
	}

	Languages::subcategorise_line(S->sect_language, L);

@ The purpose text occurs just below the heading. In version 1 it's cued with
a |@Purpose:| command; in version 2 it is unmarked. The following routine
is not elegant but handles the back end of both possibilities.

=
text_stream *Parser::extract_purpose(text_stream *prologue, source_line *XL, section *S, source_line **adjust) {
	text_stream *P = Str::duplicate(prologue);
	while ((XL) && (XL->next_line) && (XL->owning_section == S) &&
		(((adjust) && (isalnum(Str::get_first_char(XL->text)))) ||
		 ((!adjust) && (XL->category == COMMENT_BODY_LCAT)))) {
		WRITE_TO(P, " %S", XL->text);
		XL->category = PURPOSE_BODY_LCAT;
		XL->is_commentary = TRUE;
		if (adjust) *adjust = XL;
		XL = XL->next_line;
	}
	Str::trim_white_space(P);
	return P;
}

@h Version errors.
These are not fatal (why should they be?): Inweb carries on and allows the use
of the feature despite the version mismatch. They nevertheless count as errors
when it comes to Inweb's exit code, so they will halt a make.

=
void Parser::wrong_version(int using, source_line *L, char *feature, int need) {
	TEMPORARY_TEXT(warning);
	WRITE_TO(warning, "%s is a feature available only in version %d syntax (you're using version %d)",
		feature, need, using);
	Main::error_in_web(warning, L);
	DISCARD_TEXT(warning);
}
