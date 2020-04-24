[Lines::] Line Categories.

To store individual lines from webs, and to categorise them according
to their meaning.

@h Line storage.
In the next section, we'll read in an entire web, building its hierarchical
structure of chapters, sections and eventually paragraphs. But before we do
that, we'll define the structure used to store a single line of the web.

Because Inweb markup makes use of the special characters |@| and |=| as
dividers, but only in column 1, the important divisions between material
all effectively occur at line boundaries -- this is a major point of
difference with, for example, CWEB, for which the source is just a stream
of characters in which all white space is equivalent. Because Inweb source
is so tidily divisible into lines, we can usefully make each source line
correspond to one of these:

=
typedef struct source_line {
	struct text_stream *text; /* the text as read in */
	struct text_stream *text_operand; /* meaning depends on category */
	struct text_stream *text_operand2; /* meaning depends on category */

	int category; /* what sort of line this is: an |*_LCAT| value */
	int command_code; /* used only for |COMMAND_LCAT| lines: a |*_CMD| value */
	int default_defn; /* used only for |BEGIN_DEFINITION_LCAT| lines */
	int plainer; /* used only for |BEGIN_CODE_LCAT| lines: suppresses box */
	int enable_hyperlinks; /* used only for |CODE_BODY_LCAT| lines: link URLs in weave */
	struct programming_language *colour_as; /* used only for |TEXT_EXTRACT_LCAT| lines */
	int is_commentary; /* flag */
	struct language_function *function_defined; /* if any C-like function is defined on this line */
	struct preform_nonterminal *preform_nonterminal_defined; /* similarly */
	int suppress_tangling; /* if e.g., lines are tangled out of order */
	int interface_line_identified; /* only relevant during parsing of Interface lines */
	struct footnote *footnote_text; /* which fn this is the text of, if it is at all */

	struct text_file_position source; /* which file this was read in from, if any */

	struct section *owning_section; /* for interleaved title lines, it's the one about to start */
	struct source_line *next_line; /* within the owning section's linked list */
	struct paragraph *owning_paragraph; /* for lines falling under paragraphs; |NULL| if not */
} source_line;

@ =
source_line *Lines::new_source_line_in(text_stream *line, text_file_position *tfp,
	section *S) {
	source_line *sl = CREATE(source_line);
	sl->text = Str::duplicate(line);
	sl->text_operand = Str::new();
	sl->text_operand2 = Str::new();

	sl->category = NO_LCAT; /* that is, unknown category as yet */
	sl->command_code = NO_CMD;
	sl->default_defn = FALSE;
	sl->plainer = FALSE;
	sl->enable_hyperlinks = FALSE;
	sl->colour_as = NULL;
	sl->is_commentary = FALSE;
	sl->function_defined = NULL;
	sl->preform_nonterminal_defined = NULL;
	sl->suppress_tangling = FALSE;
	sl->interface_line_identified = FALSE;
	sl->footnote_text = NULL;

	if (tfp) sl->source = *tfp; else sl->source = TextFiles::nowhere();

	sl->owning_section = S;
	sl->owning_section->sect_extent++;
	sl->owning_section->owning_chapter->owning_web->web_extent++;

	sl->next_line = NULL;
	sl->owning_paragraph = NULL;
	return sl;
}

@h Categories.
The line categories are enumerated as follows. We briefly note what the text
operands (TO and TO2) are set to, if anything: most of the time they're blank.
Note that a few of these categories are needed only for the more cumbersome
version 1 syntax; version 2 removed the need for |BAR_LCAT|,
|INTERFACE_BODY_LCAT|, and |INTERFACE_LCAT|.

@e NO_LCAT from 0 /* (used when none has been set as yet) */

@e BAR_LCAT                /* a bar line |@---------------|... */
@e BEGIN_CODE_LCAT         /* an |@c|, |@e| or |@x| line below which is code, early code or extract */
@e BEGIN_DEFINITION_LCAT   /* an |@d| definition: TO is term, TO2 is this line's part of defn */
@e C_LIBRARY_INCLUDE_LCAT  /* C-like languages only: a |#include| for an ANSI C header file */
@e CHAPTER_HEADING_LCAT    /* chapter heading line inserted automatically, not read from web */
@e CODE_BODY_LCAT          /* the rest of the paragraph under an |@c| or |@e| or macro definition */
@e COMMAND_LCAT            /* a |[[Command]]| line, with the operand set to the |*_CMD| value */
@e COMMENT_BODY_LCAT       /* text following a paragraph header, which is all comment */
@e CONT_DEFINITION_LCAT    /* subsequent lines of an |@d| definition */
@e DEFINITIONS_LCAT        /* line holding the |@Definitions:| heading */
@e END_EXTRACT_LCAT        /* an |=| line used to mark the end of an extract */
@e FOOTNOTE_TEXT_LCAT      /* the opening of the text of a footnote */
@e HEADING_START_LCAT      /* |@h| paragraph start: TO is title, TO2 is rest of line */
@e INTERFACE_BODY_LCAT     /* line within the interface, under this heading */
@e INTERFACE_LCAT          /* line holding the |@Interface:| heading */
@e MACRO_DEFINITION_LCAT   /* line on which a paragraph macro is defined with an |=| sign */
@e PARAGRAPH_START_LCAT    /* simple |@| paragraph start: TO is blank, TO2 is rest of line */
@e PREFORM_GRAMMAR_LCAT    /* InC only: line of Preform grammar */
@e PREFORM_LCAT            /* InC only: opening line of a Preform nonterminal */
@e PURPOSE_BODY_LCAT       /* continuation lines of purpose declaration */
@e PURPOSE_LCAT            /* first line of purpose declaration; TO is rest of line */
@e SECTION_HEADING_LCAT    /* section heading line, at top of file */
@e SOURCE_DISPLAY_LCAT     /* commentary line beginning |>>| for display: TO is display text */
@e TEXT_EXTRACT_LCAT       /* the rest of the paragraph under an |@x| */
@e TYPEDEF_LCAT            /* C-like languages only: a |typedef| which isn't a structure definition */

@ We want to print these out nicely for the sake of a |-scan| analysis run
of Inweb:

=
char *Lines::category_name(int cat) {
	switch (cat) {
		case NO_LCAT: return "(uncategorised)";

		case BAR_LCAT: return "BAR";
		case BEGIN_CODE_LCAT: return "BEGIN_CODE";
		case BEGIN_DEFINITION_LCAT: return "BEGIN_DEFINITION";
		case C_LIBRARY_INCLUDE_LCAT: return "C_LIBRARY_INCLUDE";
		case CHAPTER_HEADING_LCAT: return "CHAPTER_HEADING";
		case CODE_BODY_LCAT: return "CODE_BODY";
		case COMMAND_LCAT: return "COMMAND";
		case COMMENT_BODY_LCAT: return "COMMENT_BODY";
		case CONT_DEFINITION_LCAT: return "CONT_DEFINITION";
		case DEFINITIONS_LCAT: return "DEFINITIONS";
		case END_EXTRACT_LCAT: return "END_EXTRACT";
		case FOOTNOTE_TEXT_LCAT: return "FOOTNOTE_TEXT";
		case HEADING_START_LCAT: return "HEADING_START";
		case INTERFACE_BODY_LCAT: return "INTERFACE_BODY";
		case INTERFACE_LCAT: return "INTERFACE";
		case MACRO_DEFINITION_LCAT: return "MACRO_DEFINITION";
		case PARAGRAPH_START_LCAT: return "PARAGRAPH_START";
		case PREFORM_GRAMMAR_LCAT: return "PREFORM_GRAMMAR";
		case PREFORM_LCAT: return "PREFORM";
		case PURPOSE_BODY_LCAT: return "PURPOSE_BODY";
		case PURPOSE_LCAT: return "PURPOSE";
		case SECTION_HEADING_LCAT: return "SECTION_HEADING";
		case SOURCE_DISPLAY_LCAT: return "SOURCE_DISPLAY";
		case TEXT_EXTRACT_LCAT: return "TEXT_EXTRACT";
		case TYPEDEF_LCAT: return "TYPEDEF";
	}
	return "(?unknown)";
}

@h Command codes.
Command-category lines are further divided up into the following. Again,
some of these fell into disuse in version 2 syntax.

@e NO_CMD from 0
@e PAGEBREAK_CMD
@e GRAMMAR_INDEX_CMD
@e FIGURE_CMD
@e AUDIO_CMD
@e CAROUSEL_CMD
@e CAROUSEL_ABOVE_CMD
@e CAROUSEL_BELOW_CMD
@e CAROUSEL_UNCAPTIONED_CMD
@e CAROUSEL_END_CMD
@e EMBED_CMD
@e TAG_CMD
