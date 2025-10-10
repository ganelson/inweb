[LineClassification::] Line Classification.

Literate source is usually very line-based, and so parsing it is a matter of
deciding what sort of thing each line represents.

@h Major and minor.
Lines are categorised by a combination of a "major" and "minor" category, with
the latter used to distinguish subvarieties. 

No line ever has major category |UNCLASSIFIED_MAJLC|, which is used only as a 
null value, but many lines have minor |NO_MINLC|, meaning that there's nothing
special about them.

@e UNCLASSIFIED_MAJLC from 0
@e NO_MINLC from 0

@ Ordinary paragraph starts (such as in this present paragraph) have minor
|NO_MINLC|, but those with named headings (such as in the "Major and minor"
case above) are |HEADING_COMMAND_MINLC|, and the grander headings at the
top of a section ("Line Classification" above) are |SECTION_HEADING_MINLC|.

@e PARAGRAPH_START_MAJLC
@e HEADING_COMMAND_MINLC /* minor of |PARAGRAPH_START_MAJLC| */
@e SECTION_HEADING_MINLC /* minor of |PARAGRAPH_START_MAJLC| */

@ Lines forming commentary material mostly have minor |NO_MINLC|, with the
only exception being the optional "purpose" paras at the top of sections.

@e COMMENTARY_MAJLC
@e PURPOSE_MINLC /* minor of |COMMENTARY_MAJLC| */

@ Blocks of code, whether intended for execution, or simply as displayed "text",
are held as extracts. Syntactically, an extract begins with an |EXTRACT_START_MAJLC|
line, though this can sometimes be implicit (in which case its minor is always
|CODE_MINLC|): if not, it signals what sort of extract follows.

Compiled code, then, lives in extracts with minors |CODE_MINLC|, |EARLY_MINLC|,
or |VERY_EARLY_MINLC|. The other extract minors are for displayed text.

@e EXTRACT_START_MAJLC
@e CODE_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e EARLY_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e VERY_EARLY_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e TEXT_AS_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e TEXT_FROM_AS_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e TEXT_FROM_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e TEXT_TO_MINLC /* minor of |EXTRACT_START_MAJLC| */
@e TEXT_MINLC /* minor of |EXTRACT_START_MAJLC| */

@ Each individual code line has this major, and no minor:

@e EXTRACT_MATTER_MAJLC

@ And an extract ends with this line, which again may be implicit in some
web syntaxes. Again it has no minor.

@e EXTRACT_END_MAJLC

@ A definition of a constant begins (and often consists only of) a |DEFINITION_MAJLC|
line, which has one of the three minors given below.

@e DEFINITION_MAJLC
@e DEFINE_COMMAND_MINLC /* minor of |DEFINITION_MAJLC| */
@e DEFAULT_COMMAND_MINLC /* minor of |DEFINITION_MAJLC| */
@e ENUMERATE_COMMAND_MINLC /* minor of |DEFINITION_MAJLC| */

@ Definitions can continue onto multiple lines, and if so, all after the first
have this major, and no minor:

@e DEFINITION_CONTINUED_MAJLC

@ A named holon of code has its declaration line, i.e., the one giving the name
of the code followed usually by an equals sign, with this major:

@e HOLON_DECLARATION_MAJLC

@ An insertion marks to include a picture or similar in the woven web, and
always has one of the following minors.

@e INSERTION_MAJLC
@e AUDIO_MINLC /* minor of |INSERTION_MAJLC| */
@e CAROUSEL_ABOVE_MINLC /* minor of |INSERTION_MAJLC| */
@e CAROUSEL_BELOW_MINLC /* minor of |INSERTION_MAJLC| */
@e CAROUSEL_END_MINLC /* minor of |INSERTION_MAJLC| */
@e CAROUSEL_SLIDE_MINLC /* minor of |INSERTION_MAJLC| */
@e DOWNLOAD_MINLC /* minor of |INSERTION_MAJLC| */
@e EMBEDDED_AV_MINLC /* minor of |INSERTION_MAJLC| */
@e FIGURE_MINLC /* minor of |INSERTION_MAJLC| */
@e HTML_MINLC /* minor of |INSERTION_MAJLC| */
@e VIDEO_MINLC /* minor of |INSERTION_MAJLC| */

@ Last and least, a feature which should perhaps go, for a sort of block-quotation
form of commentary:

@e QUOTATION_MAJLC

@ The following conditions are useful for deciding what a line might be, on the
basis of what the previous one was:

=
int LineClassification::extract_lines_can_follow(int major, int minor) {
	switch (major) {
		case HOLON_DECLARATION_MAJLC: return TRUE;
		case EXTRACT_MATTER_MAJLC: return TRUE;
		case EXTRACT_START_MAJLC:
			if ((minor == TEXT_FROM_MINLC) || (minor == TEXT_FROM_AS_MINLC)) return FALSE;
			return TRUE;
	}
	return FALSE;
}

int LineClassification::definition_lines_can_follow(int major, int minor) {
	switch (major) {
		case DEFINITION_CONTINUED_MAJLC: return TRUE;
		case DEFINITION_MAJLC: return TRUE;
	}
	return FALSE;
}

@h Classifications.
The full classification of a line has details as well as the major/minor codes,
so it comes to quite a chunk of change, in memory terms. The three textual
operands are used differently for different major/minor pairs; the tag list
for a paragraph is the run of |^"This"| and |^"That"| markers at the end of
the line introducing that paragraph, so it's used only for |PARAGRAPH_START_MAJLC|
lines.

=
typedef struct ls_class {
	int major;
	int minor;
	int options_bitmap;
	struct text_stream *operand1;
	struct text_stream *operand2;
	struct text_stream *operand3;
	struct linked_list *tag_list; /* of |text_stream| */
} ls_class;

ls_class LineClassification::new(int major, int minor) {
	ls_class cf;
	cf.major = major;
	cf.minor = minor;
	cf.options_bitmap = 0;
	cf.operand1 = NULL;
	cf.operand2 = NULL;
	cf.operand3 = NULL;
	cf.tag_list = NULL;
	return cf;
}

ls_class LineClassification::unclassified(void) {
	return LineClassification::new(UNCLASSIFIED_MAJLC, NO_MINLC);
}

@h Classifier functions.
Each web syntax provides a classifier function, which takes a line of text,
together with the classification of the previous line, and returns the new
classification.

Actually, though, it also returns some other ephemera, so it actually returns
a larger structure, |ls_class_parsing|, which additionally contains:

(a) |implies_paragraph|, |implies_extract|, |implies_extract_end| are flags
which are set to indicate that a |PARAGRAPH_START_MAJLC|, |EXTRACT_START_MAJLC|
or |EXTRACT_END_MAJLC| line should be considered to have been placed immediately
before the line just parsed (i.e., between the previous line and this one).
Note that it's possible to more than one such implication to arise for the
same line.

(b) The most notable field here is |residue|. Literate source is usually very
line-oriented, but not always, and sometimes a syntactic feature occupies
only the initial part of the line, with some left over: this, if it exists,
is put into the |residue|.

(c) If a syntax error is turned up on the line, it should be filled in as
text and placed in |error|.

=
typedef struct ls_class_parsing {
	struct ls_class cf;
	int implies_paragraph;
	int implies_extract;
	int implies_extract_end;
	struct text_stream *residue;
	struct ls_class residue_cf;
	struct text_stream *error; /* filled in only when a parsing error occurs */
} ls_class_parsing;

ls_class_parsing LineClassification::new_results(int major, int minor) {
	ls_class_parsing results;
	results.cf = LineClassification::new(major, minor);
	results.residue = NULL;
	results.residue_cf = LineClassification::unclassified();
	results.implies_paragraph = FALSE;
	results.implies_extract = FALSE;
	results.implies_extract_end = FALSE;
	results.error = NULL;
	return results;
}

ls_class_parsing LineClassification::no_results(void) {
	return LineClassification::new_results(UNCLASSIFIED_MAJLC, NO_MINLC);
}

ls_class_parsing LineClassification::classify(ls_notation *syntax, text_stream *line, ls_class *previously) {
	ls_class_parsing results;
	if (syntax->line_classifier) {
		results = (*(syntax->line_classifier))(syntax, line, previously);
		if (results.cf.major != UNCLASSIFIED_MAJLC) return results;
	}

	results = LineClassification::rules_based_classifier(syntax, line, previously);
	if (results.cf.major != UNCLASSIFIED_MAJLC) return results;

	results = LineClassification::all_code_classifier(syntax, line, previously);
	return results;
}

@ Two trivial examples are provided here. The first classifies the entire file
as commentary, with no code in: in other words, regards the file as plain text.

=
ls_class_parsing LineClassification::all_commentary_classifier(ls_notation *syntax,
	text_stream *line, ls_class *previously) {
	ls_class_parsing res = LineClassification::new_results(COMMENTARY_MAJLC, NO_MINLC);
	if (previously->major == UNCLASSIFIED_MAJLC) {
		res.implies_paragraph = TRUE;
	}
	return res;
}

@ And the second regards it as purely code, with no commentary:

=
ls_class_parsing LineClassification::all_code_classifier(ls_notation *syntax,
	text_stream *line, ls_class *previously) {
	ls_class_parsing res = LineClassification::new_results(EXTRACT_MATTER_MAJLC, NO_MINLC);
	res.cf.operand1 = Str::duplicate(line);
	if (previously->major == UNCLASSIFIED_MAJLC) {
		res.implies_paragraph = TRUE;
		res.implies_extract = TRUE;
	}
	return res;
}

@ This, more ambitiously, parses using the grammar for a syntax:

=
ls_class_parsing LineClassification::rules_based_classifier(ls_notation *syntax,
	text_stream *line, ls_class *previously) {
	int follows_extract = LineClassification::extract_lines_can_follow(
		previously->major, previously->minor);
	int first_line = (previously->major == UNCLASSIFIED_MAJLC)?TRUE:FALSE;
	if (Str::is_whitespace(line)) @<Handle whitespace lines@>
	else @<Handle nonwhitespace lines@>;
}

@ It might seem somewhat moot whether the empty line is commentary or code, but
in fact an important policy is expressed here: if a code fragment contains a
blank line, we want to read it as part of the code, in case code then continues
on subsequent lines. If we read all blank lines as commentary, then code
fragments would break up at blank lines.

@<Handle whitespace lines@> =
	if (follows_extract) return LineClassification::new_results(EXTRACT_MATTER_MAJLC, NO_MINLC);
	return LineClassification::new_results(COMMENTARY_MAJLC, NO_MINLC);

@ Otherwise, we consult the main grammar for our web syntax. If well-designed,
it will always match all nonempty lines of text. But if it should fail to
match, we consider that line to be code.

@<Handle nonwhitespace lines@> =
	ls_class_parsing res = LineClassification::new_results(EXTRACT_MATTER_MAJLC, NO_MINLC);
	TEMPORARY_TEXT(material)
	TEMPORARY_TEXT(second)
	TEMPORARY_TEXT(third)
	TEMPORARY_TEXT(options)
	TEMPORARY_TEXT(residue)
	text_stream *wildcards[NO_DEFINED_LSWILDCARD_VALUES];
	for (int i=0; i<NO_DEFINED_LSWILDCARD_VALUES; i++) wildcards[i] = NULL;
	wildcards[MATERIAL_LSWILDCARD] = material;
	wildcards[SECOND_LSWILDCARD] = second;
	wildcards[THIRD_LSWILDCARD] = third;
	wildcards[OPTIONS_LSWILDCARD] = options;
	wildcards[RESIDUE_LSWILDCARD] = residue;
	ls_notation_rule *OR = WebNotation::match(syntax->rules, line, wildcards, previously);
	if (OR) {
		@<Translate the outcome and variables into a line classification@>;
		if (OR->new_paragraph) res.implies_paragraph = TRUE;
		if (Str::len(residue) > 0) @<Deal with the RESIDUE variable, if anything is in it@>;
		if (Str::len(options) > 0) @<Deal with the OPTIONS variable, if anything is in it@>;
		if (Str::len(OR->error) > 0) res.error = OR->error;
	}
	DISCARD_TEXT(material)
	DISCARD_TEXT(second)
	DISCARD_TEXT(third)
	DISCARD_TEXT(options)
	DISCARD_TEXT(residue)
	return res;

@ Sometimes, boring and repetitive code is the quickest:

@<Translate the outcome and variables into a line classification@> =
	switch (OR->outcome) {
		case COMMENTARY_WSRULEOUTCOME:
			res = LineClassification::new_results(COMMENTARY_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if ((first_line) || (follows_extract)) res.implies_paragraph = TRUE;
			break;
		case PURPOSE_WSRULEOUTCOME:
			res = LineClassification::new_results(COMMENTARY_MAJLC, PURPOSE_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if ((first_line) || (follows_extract)) res.implies_paragraph = TRUE;
			break;
		case DEFINITION_CONTINUED_WSRULEOUTCOME:
			res = LineClassification::new_results(DEFINITION_CONTINUED_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case QUOTATION_WSRULEOUTCOME:
			res = LineClassification::new_results(QUOTATION_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case SECTIONTITLE_WSRULEOUTCOME:
			res = LineClassification::new_results(PARAGRAPH_START_MAJLC, SECTION_HEADING_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if (Str::len(second) > 0) res.cf.operand2 = Str::duplicate(second);
			break;
		case HEADING_WSRULEOUTCOME:
			res = LineClassification::new_results(PARAGRAPH_START_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case CODE_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_MATTER_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if (follows_extract == FALSE) res.implies_extract = TRUE;
			break;
		case BREAK_WSRULEOUTCOME:
			res = LineClassification::new_results(COMMENTARY_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::new();
			if ((first_line) || (follows_extract)) res.implies_paragraph = TRUE;
			break;
		case TITLE_WSRULEOUTCOME:
			res = LineClassification::new_results(PARAGRAPH_START_MAJLC, SECTION_HEADING_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case CODEEXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_START_MAJLC, CODE_MINLC);
			break;
		case EARLYCODEEXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_START_MAJLC, EARLY_MINLC);
			break;
		case VERYEARLYCODEEXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_START_MAJLC, VERY_EARLY_MINLC);
			break;
		case ENDEXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_END_MAJLC, NO_MINLC);
			break;
		case COMBINED_WSRULEOUTCOME: {
			res = LineClassification::new_results(PARAGRAPH_START_MAJLC, SECTION_HEADING_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, res.cf.operand1, U"(%c+): *(%c+)")) {
				res.cf.operand1 = Str::duplicate(mr.exp[0]);
				res.residue = Str::duplicate(mr.exp[1]);
				res.residue_cf = LineClassification::new(COMMENTARY_MAJLC, PURPOSE_MINLC);
			}
			Regexp::dispose_of(&mr);		
			break;
		}
		case EXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_MATTER_MAJLC, TEXT_MINLC);
			res.cf.operand1 = Str::duplicate(line);
			if (follows_extract == FALSE) res.implies_extract = TRUE;
			break;
		case AUDIO_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, AUDIO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case VIDEO_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, VIDEO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case FIGURE_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, FIGURE_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if (Str::len(second) > 0) res.cf.operand2 = Str::duplicate(second);
			break;
		case HTML_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, HTML_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case DOWNLOAD_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, DOWNLOAD_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if (Str::len(second) > 0) res.cf.operand2 = Str::duplicate(second);
			break;
		case EMBEDDEDVIDEO_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, EMBEDDED_AV_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			res.cf.operand2 = Str::duplicate(second);
			break;
		case CAROUSELSLIDE_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, CAROUSEL_SLIDE_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case CAROUSELABOVE_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, CAROUSEL_ABOVE_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case CAROUSELBELOW_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, CAROUSEL_BELOW_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;
		case CAROUSELEND_WSRULEOUTCOME:
			res = LineClassification::new_results(INSERTION_MAJLC, CAROUSEL_END_MINLC);
			break;

		case DEFINITION_WSRULEOUTCOME:
			res = LineClassification::new_results(DEFINITION_MAJLC, DEFINE_COMMAND_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			res.cf.operand2 = Str::duplicate(second);
			break;

		case DEFAULT_DEFINITION_WSRULEOUTCOME:
			res = LineClassification::new_results(DEFINITION_MAJLC, DEFAULT_COMMAND_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			res.cf.operand2 = Str::duplicate(second);
			break;

		case ENUMERATION_WSRULEOUTCOME:
			res = LineClassification::new_results(DEFINITION_MAJLC, ENUMERATE_COMMAND_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			res.cf.operand2 = Str::duplicate(second);
			break;

		case NAMEDCODEFRAGMENT_WSRULEOUTCOME:
			res = LineClassification::new_results(HOLON_DECLARATION_MAJLC, NO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			if (follows_extract) res.implies_paragraph = TRUE;
			break;
		
		case BEGINPARAGRAPH_WSRULEOUTCOME:
			if (Str::len(material) > 0)
				res = LineClassification::new_results(PARAGRAPH_START_MAJLC, NO_MINLC);
			else
				res = LineClassification::new_results(PARAGRAPH_START_MAJLC, HEADING_COMMAND_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;

		case TEXTEXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_START_MAJLC, TEXT_MINLC);
			if (Str::len(material) > 0) res.cf.minor = TEXT_AS_MINLC;
			if (Str::len(second) > 0) res.cf.minor = TEXT_FROM_MINLC;
			if ((Str::len(material) > 0) && (Str::len(second) > 0)) res.cf.minor = TEXT_FROM_AS_MINLC;
			res.cf.operand1 = Str::duplicate(material);
			res.cf.operand2 = Str::duplicate(second);
			break;

		case TEXTASCODEEXTRACT_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_START_MAJLC, TEXT_AS_MINLC);
			res.cf.operand1 = NULL;
			if (Str::len(second) > 0) res.cf.minor = TEXT_FROM_AS_MINLC;
			res.cf.operand2 = Str::duplicate(second);
			break;

		case TEXTEXTRACTTO_WSRULEOUTCOME:
			res = LineClassification::new_results(EXTRACT_START_MAJLC, TEXT_TO_MINLC);
			res.cf.operand1 = Str::duplicate(material);
			break;

		default: internal_error("unimplemented rule outcome");
	}

@ Anything in the RESIDUE variable is passed back to become another "line" of
the source code, but first it is run through a special grammar depending on
the outcome. This is repeated until it returns without a match.

We don't want a poorly constructed grammar to hang us, so we throw in the
towel after what are clearly too many iterations.

@d MAX_RESIDUE_OR_OPTIONS_ITERATIONS 1000

@<Deal with the RESIDUE variable, if anything is in it@> =
	res.residue = Str::duplicate(residue);
	ls_class never = LineClassification::unclassified();
	int ni = 0;
	while ((Str::len(res.residue) > 0) && (ni++ < MAX_RESIDUE_OR_OPTIONS_ITERATIONS)) {
		ls_notation_rule *RR = WebNotation::match(syntax->residue_rules[OR->outcome],
			res.residue, wildcards, &never);
		if (RR == NULL) break;
		@<Deal with a RESIDUE grammar match@>;
		if (RR->outcome == PARAGRAPHTAG_WSRULEOUTCOME) {
			text_stream *tag = Str::duplicate(material);
			if (res.cf.tag_list == NULL) res.cf.tag_list = NEW_LINKED_LIST(text_stream);
			ADD_TO_LINKED_LIST(tag, text_stream, res.cf.tag_list);
		}
		res.residue = Str::duplicate(residue);
	}

@ This mechanism was basically designed for peeling tags off of paragraph headings,
and at present that's the only thing a residue grammar can usefully match:

@<Deal with a RESIDUE grammar match@> =
	switch (RR->outcome) {
		case PARAGRAPHTAG_WSRULEOUTCOME: {
			text_stream *tag = Str::duplicate(material);
			if (res.cf.tag_list == NULL) res.cf.tag_list = NEW_LINKED_LIST(text_stream);
			ADD_TO_LINKED_LIST(tag, text_stream, res.cf.tag_list);
		}
	}

@ The OPTIONS variable is handled similarly, but here the grammar needs to
exhaust the content completely, or there's an error.

@<Deal with the OPTIONS variable, if anything is in it@> =
	TEMPORARY_TEXT(opts)
	WRITE_TO(opts, "%S", options);
	ls_class never = LineClassification::unclassified();
	int ni = 0;
	while ((Str::len(opts) > 0) && (ni++ < MAX_RESIDUE_OR_OPTIONS_ITERATIONS)) {
		ls_notation_rule *OPR = WebNotation::match(syntax->options_rules[OR->outcome],
			opts, wildcards, &never);
		if (OPR == NULL) break;
		@<Deal with an OPTIONS grammar match@>;
		Str::clear(opts);
		Str::copy(opts, options);
	}
	if (Str::len(opts) > 0) {
		res.error = Str::new();
		WRITE_TO(res.error, "unknown material in options: '%S'", opts);
	}
	DISCARD_TEXT(opts)

@<Deal with an OPTIONS grammar match@> =
	switch (OPR->outcome) {
		case HYPERLINKED_WSRULEOUTCOME: res.cf.options_bitmap |= 1; break;
		case UNDISPLAYED_WSRULEOUTCOME: res.cf.options_bitmap |= 2; break;
	}
