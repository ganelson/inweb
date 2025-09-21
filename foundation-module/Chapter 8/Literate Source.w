[LiterateSource::] Literate Source.

To parse and represent units of literate source text.

@ At this point we've done all of the large-scale organisations of webs into
chapters and sections, and we get into the lower-level literate source.
By analogy with "compilation units", we use the term "unit" to mean a stretch
of self-contained literate source -- self-contained in that its holons can
incorporate each other, but not holons from other sections of a web, which
are different units.

We will end up with an |ls_unit| which is essentially a list of |ls_paragraph|,
which is a list of |ls_chunk|, which is a list of |ls_line|.

=
typedef struct ls_unit {
	struct ls_syntax *syntax; /* what notation is this unit written with? */
	struct programming_language *language; /* what language is the program in? */

	struct ls_section *owning_section; /* can be NULL if not read from a web */

	struct ls_class heading;
	struct ls_class purpose;
	struct ls_paragraph *first_par;
	struct ls_paragraph *last_par;
	
	/* result of parsing */
	int lines_read;
	struct linked_list *errors; /* of |ls_error| */
	
	/* temporary workspace used only in parsing */
	int incomplete;
	int eligible_to_have_implicit_purpose;
	int window_for_implicit_purpose_open;
	struct pathname *extracts_path;
	struct ls_web *context; /* used only for finding language names */
	struct ls_line *temp_first_line;
	struct ls_line *temp_last_line;
	struct ls_line *spool_point;

	CLASS_DEFINITION
} ls_unit;

@ To parse source text into an |ls_unit|, begin by calling this to produce
an empty one, ready for parsing. Note that |S|, the section, can be |NULL|,
in cases when tiny fragments of code are being parsed outside the context
of a full literate program. However, |syntax| and |language| must be set.

The |extracts_path| and |dialects_path| directories are relevant only when
parsing extracts: those drawn from files need to get the files from somewhere,
and those which name their contents as being written in a given language
need to get that from somewhere, too. Either or both can be |NULL|, which
means the current working directory.

=
ls_unit *LiterateSource::begin_unit(ls_section *S, ls_syntax *syntax,
	programming_language *language, pathname *extracts_path, ls_web *context) {
	ls_unit *lsu = CREATE(ls_unit);
	lsu->syntax = syntax;
	lsu->language = language;

	lsu->owning_section = S;

	lsu->heading = LineClassification::unclassified();
	lsu->purpose = LineClassification::unclassified();
	lsu->first_par = NULL;
	lsu->last_par = NULL;

	lsu->lines_read = 0;
	lsu->errors = NEW_LINKED_LIST(ls_error);

	lsu->incomplete = TRUE;
	lsu->eligible_to_have_implicit_purpose = FALSE;
	lsu->window_for_implicit_purpose_open = TRUE;
	lsu->extracts_path = extracts_path;
	lsu->context = context;
	lsu->temp_first_line = NULL;
	lsu->temp_last_line = NULL;
	lsu->spool_point = NULL;
	return lsu;
}

@ You can, optionally, then follow up by supplying a "purpose" text from outside
of the source code.

=
void LiterateSource::add_purpose(ls_unit *lsu, text_file_position *tfp, text_stream *text) {
	ls_line *line = LiterateSource::feed_line_segment(lsu, tfp, text, COMMENTARY_MAJLC, PURPOSE_MINLC);
	line->classification.operand1 = Str::duplicate(text);
}

@ Once the unit has been begun, call |LiterateSource::feed_line| on each line
of source text to feed into it; then call |LiterateSource::complete_unit| to
indicate that you're done.

=
void LiterateSource::feed_line(ls_unit *lsu, text_file_position *tfp, text_stream *text) {
	if (lsu) lsu->lines_read++;
	LiterateSource::feed_line_segment(lsu, tfp, text, NO_MINLC, NO_MINLC);
}

@ That function wasn't recursive: this one is. We need to remember here that a
literal line of source text can, in some notations for LS, produce multiple
|ls_line| objects -- if a single line combines a title for a paragraph with
some commentary beginning that paragraph, for example.

=
ls_line *LiterateSource::feed_line_segment(ls_unit *lsu, text_file_position *tfp,
	text_stream *text, int major, int minor) {
	if (lsu == NULL) internal_error("no unit to feed lines to");
	if (lsu->incomplete == FALSE) internal_error("too late to for lines: unit already completed");

	ls_class_parsing res;
	@<Classify this line segment@>;
	@<Insert any implied lines first@>;

	ls_line *line = LiterateSource::new_line(tfp, text, res.cf);
	if (Str::len(res.error) > 0) WebErrors::record_in_unit(res.error, line, lsu);

	@<Then insert the explicit line@>;
	@<And finally insert any residue left over@>;

	return line;
}

@ If we were called with |major| and |minor| already set to a given classification,
then that's how the line segment is classified. If not, then we don't know the
answer in advance, and will have to work it out. This depends on context, as
provided by the previous line segment's classification.

@<Classify this line segment@> =
	if (major != UNCLASSIFIED_MAJLC) {
		res = LineClassification::new_results(major, minor);
	} else {
		ls_class last_cf;
		if (lsu->temp_last_line == NULL) last_cf = LineClassification::unclassified();
		else last_cf = lsu->temp_last_line->classification;
		res = LineClassification::classify(lsu->syntax, text, &last_cf);

		if ((res.cf.major == COMMENTARY_MAJLC) && (lsu->window_for_implicit_purpose_open)) {
			if (Str::is_whitespace(text) == FALSE)
				lsu->eligible_to_have_implicit_purpose = TRUE;
		} else {
			if ((res.cf.major != PARAGRAPH_START_MAJLC) || (res.cf.minor == HEADING_COMMAND_MINLC))
				lsu->window_for_implicit_purpose_open = FALSE;
		}
	}

@ In some syntaxes for literate programming, paragraph breaks (for example) are
explicitly marked: in others they are implied, and we need to insert them.

Note that it is possible for more than one of these occur at at single position.

@<Insert any implied lines first@> =	
	if (res.implies_extract_end)
		LiterateSource::feed_line_segment(lsu, tfp, I"(implied extract end line)",
			EXTRACT_END_MAJLC, NO_MINLC);
	if (res.implies_paragraph)
		LiterateSource::feed_line_segment(lsu, tfp, I"(implied paragraph start line)",
			PARAGRAPH_START_MAJLC, NO_MINLC);
	if (res.implies_extract) 
		LiterateSource::feed_line_segment(lsu, tfp, I"(implied extract start line)",
			EXTRACT_START_MAJLC, CODE_MINLC);

@ For now, we're storing the lines as a doubly-linked list:

@<Then insert the explicit line@> =
	line->prev_line = lsu->temp_last_line;
	if (lsu->temp_first_line == NULL) lsu->temp_first_line = line;
	else lsu->temp_last_line->next_line = line;
	lsu->temp_last_line = line;

@ Sometimes the classifier has decided that only the first few characters
of the line were significant, and wants to give us a "residue" of material
left over. We recurse in order to insert line(s) arising from that, too.

Usually the classifier has left that residue unclassified for now -- so that
it will be classified when we recurse -- but sometimes the classifier already
knows and wants to tell us:

@<And finally insert any residue left over@> =
	if (Str::len(res.residue) > 0)
		LiterateSource::feed_line_segment(lsu, tfp, res.residue,
			res.residue_cf.major, res.residue_cf.minor);

@ If for some reason you don't want to use any external classification, because
you already know how all your lines are to be classified, you can use these
convenience functions rather than calling |LiterateSource::feed_line|.
Note that these all increment the line count, just as that does:

=
void LiterateSource::feed_paragraph_start(ls_unit *lsu, text_file_position *tfp) {
	if (lsu) lsu->lines_read++;
	LiterateSource::feed_line_segment(lsu, tfp, I"", PARAGRAPH_START_MAJLC, NO_MINLC);
}

void LiterateSource::feed_code_start(ls_unit *lsu, text_file_position *tfp) {
	if (lsu) lsu->lines_read++;
	LiterateSource::feed_line_segment(lsu, tfp, I"", EXTRACT_START_MAJLC, CODE_MINLC);
}

void LiterateSource::feed_code_line(ls_unit *lsu, text_file_position *tfp, text_stream *text) {
	if (lsu) lsu->lines_read++;
	ls_line *line = LiterateSource::feed_line_segment(lsu, tfp, text, EXTRACT_MATTER_MAJLC, NO_MINLC);
	line->classification.operand1 = Str::duplicate(text);
}

void LiterateSource::feed_code_end(ls_unit *lsu, text_file_position *tfp) {
	if (lsu) lsu->lines_read++;
	LiterateSource::feed_line_segment(lsu, tfp, I"", EXTRACT_END_MAJLC, NO_MINLC);
}

@ The above created |ls_line| objects, so we should take a look at those:

=
typedef struct ls_line {
	/* where this came from, and its original text */
	struct text_file_position origin;
	struct text_stream *text;

	/* what the line means to us */
	void *analysis_ref;
	struct ls_class classification;
	struct ls_footnote *footnote_text; /* which fn this is the text of, if it is at all */
	int suppress_tangling; /* if e.g., lines are tangled out of order */

	/* how the line sits inside the wider source */
	struct ls_chunk *owning_chunk; /* |NULL| until the unit has been divided up into chunks */
	struct ls_line *prev_line;
	struct ls_line *next_line;
	CLASS_DEFINITION
} ls_line;

ls_line *LiterateSource::new_line(text_file_position *tfp, text_stream *text, ls_class cf) {
	ls_line *line = CREATE(ls_line);
	if (tfp) line->origin = *tfp; else line->origin = TextFiles::nowhere();
	line->text = Str::duplicate(text);

	line->analysis_ref = NULL;
	line->classification = cf;
	line->footnote_text = NULL;
	line->suppress_tangling = FALSE;
	
	line->owning_chunk = NULL;
	line->prev_line = NULL;
	line->next_line = NULL;
	return line;
}

@ With the raw parsing done, the fun can really begin. At this point all the lines
have been read in, but they sit inside the unit only as a doubly-linked list.
We need to reassemble that into a hierarchy of paragraphs and chunks, and
generally to tidy up so that the unit is ready for use. All of that happens
when the following is called:

=
void LiterateSource::complete_unit(ls_unit *lsu) {
	@<Perform a sanity check before doing anything@>;
	@<Trim off header lines at the top@>;
	@<Spool in extracts from external files@>;
	@<Convert the line list to a paragraph and chunk tree@>;
	@<Trim redundant lines away from the chunks@>;

	if ((LiterateSource::unit_has_purpose(lsu) == FALSE) &&
		(WebSyntax::supports(lsu->syntax, PURPOSE_UNDER_HEADING_WSF)))
		@<Construe an opening paragraph consisting only of commentary as a purpose text@>;

	@<Parse some last nuances for text extracts@>;
	@<Assign holons to chunks containing fragments of the target code@>;
	@<Police carousel structure@>;

	int next_footnote = 1;
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		@<Work out footnote numbering for this paragraph@>;
}

@ To see the first (up to) N lines of the raw linked list of lines, before
completion begins, set the following constant to N.

@d TRACE_RAW_LS_LINE_LIST 0

@<Perform a sanity check before doing anything@> =
	if (lsu == NULL) internal_error("no unit to complete");
	if (lsu->incomplete == FALSE) internal_error("too late: unit already completed");
	lsu->incomplete = FALSE;
	
	if (TRACE_RAW_LS_LINE_LIST > 0) {
		ls_line *line = lsu->temp_first_line;
		int lc = 0;
		while ((lc < TRACE_RAW_LS_LINE_LIST) && (line)) {
			lc++;
			WRITE_TO(STDERR, "%d: %d/%d <%S> <%S> <%S>\n", lc,
				line->classification.major, line->classification.minor,
				line->text, line->classification.operand1, line->classification.operand2);
			line = line->next_line;
		}
	}

@ If the first line of substance is a section heading then we take that out of
the list; if the first remaining is a purpose line, we do likewise. Those should
be the only |SECTION_HEADING_MINLC| or |PURPOSE_MINLC| lines in the list,
leaving us with standard material only.

@<Trim off header lines at the top@> =
	ls_line *top = lsu->temp_first_line;
	@<Skip past insubstantial lines@>;
	if ((top) && (top->classification.minor == SECTION_HEADING_MINLC)) {
		lsu->heading = top->classification;
		lsu->temp_first_line = top->next_line;
		if (lsu->temp_first_line) lsu->temp_first_line->prev_line = NULL;
		else lsu->temp_last_line = NULL;
		top = lsu->temp_first_line;
		@<Skip past insubstantial lines@>;
	}
	if ((top) && (top->classification.minor == PURPOSE_MINLC)) {
		lsu->purpose = top->classification;
		lsu->temp_first_line = top->next_line;
		if (lsu->temp_first_line) lsu->temp_first_line->prev_line = NULL;
		else lsu->temp_last_line = NULL;
	}

@ Because of implicit paragraphing in some syntaxes, the line list may open
with some blank commentary lines or paragraph-start markers, so:

@<Skip past insubstantial lines@> =
	while ((top) &&
		(((top->classification.major == COMMENTARY_MAJLC) &&
			(Str::is_whitespace(top->classification.operand1))) ||
		((top->classification.major == PARAGRAPH_START_MAJLC) &&
			(top->classification.minor != SECTION_HEADING_MINLC))))
		top = top->next_line;

@ We allow two forms of extract to display text drawn from an external file.
This is handled by loading it in, and inserting it as extract lines into the
list, with each new line being added after the "spool point".

After this point, all |TEXT_FROM_MINLC| extracts have been converted to
|TEXT_MINLC|, and all |TEXT_FROM_AS_MINLC| to |TEXT_AS_MINLC|.

We're forgiving if the file doesn't exist, but not if it does exist but
can't be read for some permissions reason, which is more serious.

@<Spool in extracts from external files@> =
	for (ls_line *line = lsu->temp_first_line; line; line = line->next_line) {
		if ((line->classification.major == EXTRACT_START_MAJLC) &&
			((line->classification.minor == TEXT_FROM_MINLC) ||
				(line->classification.minor == TEXT_FROM_AS_MINLC))) {
			filename *F = Filenames::from_text_relative(
				lsu->extracts_path, line->classification.operand2);
			if (TextFiles::exists(F)) {
				lsu->spool_point = line;
				TextFiles::read(F, FALSE, "can't open extract file", TRUE,
					LiterateSource::spool_line, NULL, (void *) lsu);
				if (line->classification.minor == TEXT_FROM_MINLC)
					line->classification.minor = TEXT_MINLC;
				else {
					line->classification.minor = TEXT_AS_MINLC;
				}
			} else {
				line->classification.major = COMMENTARY_MAJLC;
				line->classification.minor = NO_MINLC;
				line->classification.operand1 = Str::new();
				WRITE_TO(line->classification.operand1, "(No such file as %f)", F);
				line->text = line->classification.operand1;
			}
		}
	}

@ And this is the service function called on every line of the extract file:

=
void LiterateSource::spool_line(text_stream *line, text_file_position *tfp, void *state) {
	ls_unit *lsu = (ls_unit *) state;
	ls_class cf = LineClassification::new(EXTRACT_MATTER_MAJLC, NO_MINLC);
	cf.operand1 = Str::duplicate(line);
	ls_line *new_lst = LiterateSource::new_line(tfp, line, cf);
	ls_line *old_lst = lsu->spool_point;
	new_lst->next_line = old_lst->next_line;
	if (new_lst->next_line) new_lst->next_line->prev_line = new_lst;
	else lsu->temp_last_line = new_lst;
	new_lst->prev_line = old_lst;
	old_lst->next_line = new_lst;
	lsu->spool_point = new_lst;	
}

@ Okay, so within the line list, paragraph divisions occur at |PARAGRAPH_START_MAJLC|
lines. We assign an |ls_paragraph| to each gap between those divisions, including
before the first and after the last. Note that the |PARAGRAPH_START_MAJLC| lines
are then not included in any of the chunks.

Within each paragraph, chunk divisions occur when a line belonging to a different
"chunk type" is found, or when the start of a definition is found. Thus, for example,
these nine lines would be formed into three chunks, each getting an |ls_chunk|:
= (text)
	COMMENTARY_MAJLC                chunk 1 (2 lines)
	COMMENTARY_MAJLC
	EXTRACT_START_MAJLC             chunk 2 (4 lines)
	EXTRACT_MATTER_MAJLC
	EXTRACT_MATTER_MAJLC
	EXTRACT_END_MAJLC
	DEFINITION_MAJLC                chunk 3 (1 line)
	DEFINITION_MAJLC                chunk 4 (2 lines)
	DEFINITION_CONTINUED_MAJLC
=
The original doubly-linked line list is broken into smaller lists, one for each
chunk, and we conclude by removing the unit's pointers to its temporary list
altogether, so that nobody uses it by mistake.

@<Convert the line list to a paragraph and chunk tree@> =
	ls_paragraph *par = NULL;
	ls_chunk *chunk = NULL;
	int next_par_number = 1;
	for (ls_line *line = lsu->temp_first_line; line; line = line->next_line) {
		if ((line->classification.major == PARAGRAPH_START_MAJLC) || (par == NULL)) {
			@<Begin a new paragraph@>;
			chunk = NULL;
			if (line->classification.major == PARAGRAPH_START_MAJLC) continue;
		}
		
		int ct;
		switch (line->classification.major) {
			case EXTRACT_START_MAJLC:        ct = EXTRACT_LSCT; break;
			case EXTRACT_MATTER_MAJLC:       ct = EXTRACT_LSCT; break;
			case EXTRACT_END_MAJLC:          ct = EXTRACT_LSCT; break;
			case COMMENTARY_MAJLC:           ct = COMMENTARY_LSCT; break;
			case DEFINITION_MAJLC:           ct = DEFINITION_LSCT; break;
			case DEFINITION_CONTINUED_MAJLC: ct = DEFINITION_LSCT; break;
			case QUOTATION_MAJLC:            ct = QUOTATION_LSCT; break;
			case HOLON_DECLARATION_MAJLC:    ct = HOLON_DECLARATION_LSCT; break;
			case INSERTION_MAJLC:            ct = INSERTION_LSCT; break;
			default:                         ct = OTHER_LSCT; break;
		}
		if ((chunk == NULL) || (ct != chunk->chunk_type) ||
			(line->classification.major == DEFINITION_MAJLC) ||
			(line->classification.major == INSERTION_MAJLC) ||
			(line->classification.major == HOLON_DECLARATION_MAJLC))
			@<Begin a new chunk with this line@>
		else
			@<Add this line to the current chunk@>;

		if (line->classification.major == INSERTION_MAJLC)
			@<Tag the paragraph as containing a particular sort of insertion@>;
	}
	
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			chunk->first_line->prev_line = NULL;
			chunk->last_line->next_line = NULL;
		}

	lsu->temp_first_line = NULL; lsu->temp_last_line = NULL;

@ So this is the |ls_paragraph| object:

=
typedef struct ls_paragraph {
	/* how the paragraph sits inside the wider source */
	struct ls_unit *owning_unit;
	struct ls_paragraph *prev_par;
	struct ls_paragraph *next_par;

	/* about the paragraph */
	struct text_stream *paragraph_number; /* note: a text, not an int */
	void *analysis_ref;
	struct ls_holon *holon;
	struct ls_class titling;
	struct linked_list *taggings; /* of |literate_source_tagging| */

	/* contents of the paragraph */
	struct ls_chunk *first_chunk;
	struct ls_chunk *last_chunk;
	struct linked_list *footnotes; /* of |ls_footnote| */

	/* used only when computing the paragraph numbers */
	struct ls_paragraph *parent_paragraph; /* the super-para of this, if any */
	int next_child_number; /* how many sub-paras we've had so far */
	CLASS_DEFINITION
} ls_paragraph;

@ The new paragraph is appended to the list of paras in the unit, and assigned
a temporary paragraph number. (This may be replaced later by better numbers,
but only after holons have been looked at to work out which paras are
subordinate to which others.)

When created, a paragraph is empty of chunks, but this is put right almost
immediately afterwards:

@<Begin a new paragraph@> =
	par = CREATE(ls_paragraph);
	par->owning_unit = lsu;
	par->prev_par = lsu->last_par;
	par->next_par = NULL;
	if (lsu->first_par == NULL) lsu->first_par = par;
	else lsu->last_par->next_par = par;
	lsu->last_par = par;

	par->paragraph_number = Str::new();
	WRITE_TO(par->paragraph_number, "%d", next_par_number++);
	par->titling = line->classification;
	par->holon = NULL;
	par->taggings = NULL;

	par->first_chunk = NULL;
	par->last_chunk = NULL;
	par->footnotes = NULL;

	par->parent_paragraph = NULL;
	par->next_child_number = 0;

@ And now for chunks. Each chunk has a "chunk type", which is one of the
following:

@e COMMENTARY_LSCT from 1
@e EXTRACT_LSCT
@e QUOTATION_LSCT
@e DEFINITION_LSCT
@e HOLON_DECLARATION_LSCT
@e INSERTION_LSCT
@e OTHER_LSCT

=
typedef struct ls_chunk {
	/* how the chunk sits inside the wider source */
	struct ls_paragraph *owner;
	struct ls_chunk *prev_chunk;
	struct ls_chunk *next_chunk;
	
	/* about the chunk */
	int chunk_type;
	struct ls_class metadata;
	struct ls_line *onset_line; /* where to report errors about the chunk */

	/* meaningful for EXTRACT_LSCT chunks only */
	struct ls_holon *holon; /* or |NULL|, if this doesn't contain a program fragment */
	int plainer;
	int hyperlinked;
	struct text_stream *extract_to;
	struct programming_language *extract_language;

	/* meaningful for DEFINITION_LSCT chunks only */
	struct text_stream *symbol_defined;
	struct text_stream *symbol_value;

	/* meaningful for COMMENTARY_LSCT chunks only */
	struct markdown_item *as_markdown; /* for commentary only */

	/* meaningful for INSERTION_LSCT chunks only */
	int carousel_caption_position;

	/* contents of the chunk */
	struct ls_line *first_line;
	struct ls_line *last_line;

	CLASS_DEFINITION
} ls_chunk;

@ When created, a chunk contains a single line:

@<Begin a new chunk with this line@> =
	chunk = CREATE(ls_chunk);
	chunk->owner = par;
	chunk->prev_chunk = par->last_chunk;
	chunk->next_chunk = NULL;
	if (par->first_chunk == NULL) par->first_chunk = chunk;
	else par->last_chunk->next_chunk = chunk;
	par->last_chunk = chunk;

	chunk->chunk_type = ct;
	chunk->metadata = LineClassification::unclassified();
	chunk->onset_line = line;

	chunk->holon = NULL;
	chunk->plainer = FALSE;
	chunk->hyperlinked = FALSE;
	chunk->extract_to = NULL;
	chunk->extract_language = NULL;

	chunk->symbol_defined = NULL;
	chunk->symbol_value = NULL;

	chunk->as_markdown = NULL;
	
	chunk->carousel_caption_position = 0;

	chunk->first_line = line;
	chunk->last_line = line;

@<Add this line to the current chunk@> =
	chunk->last_line->next_line = line;
	chunk->last_line = line;

@ This automatic tagging is a convenience for extracting, say, a weave of
just those paragraphs containing figures.

@<Tag the paragraph as containing a particular sort of insertion@> =
	switch (line->classification.minor) {
		case AUDIO_MINLC:          LiterateSource::tag_paragraph(par, I"Audio"); break;
		case EMBEDDED_AV_MINLC:    LiterateSource::tag_paragraph(par, I"Video"); break;
		case FIGURE_MINLC:         LiterateSource::tag_paragraph(par, I"Figures"); break;
		case DOWNLOAD_MINLC:       LiterateSource::tag_paragraph(par, I"Downloads"); break;
		case VIDEO_MINLC:          LiterateSource::tag_paragraph(par, I"Video"); break;
		case HTML_MINLC:           LiterateSource::tag_paragraph(par, I"HTML"); break;
		case CAROUSEL_ABOVE_MINLC: LiterateSource::tag_paragraph(par, I"Carousels"); break;
		case CAROUSEL_BELOW_MINLC: LiterateSource::tag_paragraph(par, I"Carousels"); break;
		case CAROUSEL_SLIDE_MINLC: LiterateSource::tag_paragraph(par, I"Carousels"); break;
		case CAROUSEL_END_MINLC:   LiterateSource::tag_paragraph(par, I"Carousels"); break;			
	}

@ In some syntaxes, blank lines are used to indicate extract or commentary
ends, but then leak through as unnecessary bits of extract or commentary, etc.
The following trims such blanks away.

Note that whole chunks can be removed as a result, and even whole paragraphs,
if they then turn out to contain no chunks (unless they hold important heading
material).

@<Trim redundant lines away from the chunks@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			if (chunk->chunk_type == COMMENTARY_LSCT)
				@<Trim whitespace lines from start or end of this chunk@>;

			if (chunk->chunk_type == EXTRACT_LSCT)
				@<Trim extract end markers from an extract chunk@>;

			if (chunk->chunk_type == DEFINITION_LSCT)
				@<Tidy up definition chunks@>;

			if (chunk->chunk_type == INSERTION_LSCT)
				@<Tidy up insertion chunks@>;
		}
		if ((Str::is_whitespace(par->titling.operand1)) &&
			(Str::is_whitespace(par->titling.operand2)) &&
			(par->first_chunk == NULL)) {
			LiterateSource::remove_par_from_unit(par, lsu);
		}
	}

@ This does just what it says. Note that if it ends up removing every line of
the chunk, then we remove the chunk entirely, because we do not allow empty chunks.

@<Trim whitespace lines from start or end of this chunk@> =
	ls_line *first_dark = NULL;
	ls_line *last_dark = NULL;
	for (ls_line *line = chunk->first_line; line; line = line->next_line) {
		if (Str::is_whitespace(line->classification.operand1) == FALSE) {
			if (first_dark == NULL) first_dark = line;
			last_dark = line;
		}
	}
	if (first_dark == NULL) {
		LiterateSource::remove_chunk_from_par(chunk, par);
	} else {
		chunk->first_line = first_dark;
		chunk->last_line = last_dark;
		chunk->first_line->prev_line = NULL;
		chunk->last_line->next_line = NULL;
	}

@ At this point an extract chunk can begin with one optional |EXTRACT_START_MAJLC|
line, giving details of what sort of extract it is: if this isn't present, the
extract will be standard code. It then consists only of |EXTRACT_MATTER_MAJLC|
lines, running up to an optional |EXTRACT_END_MAJLC| line which, if present,
must be the last in the chunk.

Here we strip out the start and end markers, if they are present, extracting
any metadata from the start marker as we do. That leaves a chunk with a list
of 0 or more |EXTRACT_MATTER_MAJLC| lines: if there are none, we remove the
chunk.

If the syntax calls for extracts to have opening and closing blank lines
removed, then we do that, and once again delete the chunk if it becomes
empty as a result.

@<Trim extract end markers from an extract chunk@> =
	chunk->metadata = LineClassification::new(EXTRACT_START_MAJLC, CODE_MINLC);
	chunk->onset_line = chunk->first_line;
	if (chunk->onset_line) chunk->onset_line->owning_chunk = chunk;
	if ((chunk->first_line) && (chunk->first_line->classification.major == EXTRACT_START_MAJLC)) {
		chunk->metadata = chunk->first_line->classification;
		chunk->first_line = chunk->first_line->next_line;
		if (chunk->first_line == NULL) chunk->last_line = NULL;
		else chunk->first_line->prev_line = NULL;
	}
	if ((chunk->last_line) && (chunk->last_line->classification.major == EXTRACT_END_MAJLC)) {
		chunk->last_line = chunk->last_line->prev_line;
		if (chunk->last_line == NULL) chunk->first_line = NULL;
		else chunk->last_line->next_line = NULL;
	}
	if (chunk->first_line == NULL) LiterateSource::remove_chunk_from_par(chunk, par);
	else if (WebSyntax::supports(lsu->syntax, TRIMMED_EXTRACTS_WSF))
		@<Trim whitespace lines from start or end of this chunk@>;

@ A definition chunk begins with a |DEFINITION_MAJLC| line, followed by 0
or more |DEFINITION_CONTINUED_MAJLC| lines. We trim away any blank continuation
lines from the bottom end, but don't touch the top. Note that the chunk cannot
thus become empty, because it always has its header line.

We take this opportunity to parse out the symbol defined, and the value given
for it.

@<Tidy up definition chunks@> =
	chunk->metadata = chunk->first_line->classification;
	ls_line *last_dark = chunk->last_line;
	for (ls_line *line = chunk->first_line; line; line = line->next_line)
		if ((line->classification.major != DEFINITION_CONTINUED_MAJLC) ||
			(Str::is_whitespace(line->classification.operand1) == FALSE))
			last_dark = line;
	if (last_dark == NULL) internal_error("definition without header");
	chunk->last_line = last_dark;
	chunk->last_line->next_line = NULL;
	match_results mr = Regexp::create_mr();
	chunk->symbol_defined = Str::duplicate(chunk->first_line->classification.operand1);
	if ((chunk->first_line->classification.minor == ENUMERATE_COMMAND_MINLC) &&
		(Regexp::match(&mr, chunk->first_line->classification.operand2, U"from (%c+)"))) {
		chunk->symbol_value = Str::duplicate(mr.exp[0]);
	} else {
		chunk->symbol_value = Str::duplicate(chunk->first_line->classification.operand2);
	}
	Regexp::dispose_of(&mr);

@<Tidy up insertion chunks@> =
	chunk->metadata = chunk->first_line->classification;
	if (chunk->metadata.minor == CAROUSEL_BELOW_MINLC) {
		chunk->carousel_caption_position = -1;
		chunk->metadata.minor = CAROUSEL_SLIDE_MINLC;
		chunk->first_line->classification.minor = CAROUSEL_SLIDE_MINLC;
	} else if (chunk->metadata.minor == CAROUSEL_ABOVE_MINLC) {
		chunk->carousel_caption_position = 1;
		chunk->metadata.minor = CAROUSEL_SLIDE_MINLC;
		chunk->first_line->classification.minor = CAROUSEL_SLIDE_MINLC;
	}

@ If there's just one chunk in the opening para, and it contains commentary,
read this as a purpose written in plain text, and remove the para.

@<Construe an opening paragraph consisting only of commentary as a purpose text@> =
	ls_paragraph *par = lsu->first_par;
	if ((par) && (par->first_chunk) && (par->first_chunk == par->last_chunk) &&
		(par->first_chunk->chunk_type == COMMENTARY_LSCT) && (lsu->eligible_to_have_implicit_purpose)) {
		lsu->purpose = LineClassification::new(COMMENTARY_MAJLC, PURPOSE_MINLC);
		lsu->purpose.operand1 = Str::new();
		for (ls_line *line = par->first_chunk->first_line; line; line = line->next_line) {
			WRITE_TO(lsu->purpose.operand1, "%S", line->classification.operand1);
			if (line->next_line) WRITE_TO(lsu->purpose.operand1, " ");
		}
		LiterateSource::remove_par_from_unit(par, lsu);
	}

@<Parse some last nuances for text extracts@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			text_stream *language_name = NULL;
			switch (chunk->metadata.minor) {
				case TEXT_AS_MINLC:
					@<Parse out the optional undisplayed and hyperlinked keywords@>;
					language_name = chunk->metadata.operand1;
					break;
				case TEXT_TO_MINLC:
					@<Parse out the optional undisplayed and hyperlinked keywords@>;
					language_name = I"Extracts";
					chunk->extract_to = chunk->metadata.operand1;
					break;
				case TEXT_MINLC:
					@<Parse out the optional undisplayed and hyperlinked keywords@>;
					break;
			}
			if (Str::len(language_name) > 0)
				chunk->extract_language =
					Languages::find_or_fail(lsu->context, language_name);				
		}
	}

@ This is all a little clumsy, but it'll do:

@<Parse out the optional undisplayed and hyperlinked keywords@> =
	if (chunk->metadata.options_bitmap & 1) chunk->hyperlinked = TRUE;
	if (chunk->metadata.options_bitmap & 2) chunk->plainer = TRUE;

@ So, each chunk which contains a fragment of the actual program code (rather
than, say, a definition, or commentary, or an extract of other code not to be
compiled) must be paired to an |ls_holon| structure. If there's a holon
declaration line (i.e., a name for it) anywhere in the paragraph prior to
this chunk, we'll use that as the name; otherwise it will go nameless.

This process removes all |EARLY_MINLC| or |VERY_EARLY_MINLC| lines.

We finish up by scanning the holons in detail, and resolving cross-references
between them, but that's another story: see //Holons::scan//.

@<Assign holons to chunks containing fragments of the target code@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		TEMPORARY_TEXT(holon_name)
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			for (ls_line *line = chunk->first_line; line; line = line->next_line)
				line->owning_chunk = chunk;
			if (chunk->chunk_type == HOLON_DECLARATION_LSCT) {
				if (Str::len(holon_name) > 0)
					WebErrors::record_at(I"second fragment name declaration in one paragraph",
						chunk->first_line);
				Str::clear(holon_name);
				WRITE_TO(holon_name, "%S", chunk->first_line->classification.operand1);
			}
			if (chunk->chunk_type == EXTRACT_LSCT) {
				switch (chunk->metadata.minor) {
					case CODE_MINLC:
						@<Assign a holon to this chunk@>; break;
					case EARLY_MINLC:
						@<Assign a holon to this chunk@>;
						chunk->holon->placed_early = TRUE;
						chunk->metadata.minor = CODE_MINLC; break;
					case VERY_EARLY_MINLC:
						@<Assign a holon to this chunk@>;
						chunk->holon->placed_very_early = TRUE;
						chunk->metadata.minor = CODE_MINLC; break;
				}
			}
		}
		if (Str::len(holon_name) > 0)
			WebErrors::record_at(I"no code fragment follows name declaration",
				par->first_chunk->first_line);
		DISCARD_TEXT(holon_name)
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
			if (chunk->chunk_type == HOLON_DECLARATION_LSCT)
				LiterateSource::remove_chunk_from_par(chunk, par);
	}
	Holons::scan(lsu);

@<Assign a holon to this chunk@> =
	chunk->holon = Holons::new(chunk, holon_name);
	if (chunk->owner->holon)
		WebErrors::record_at(I"two code fragments in the same paragraph",
			chunk->first_line);
	chunk->owner->holon = chunk->holon;
	Str::clear(holon_name);

@<Police carousel structure@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		ls_chunk *in_carousel = NULL;
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			if ((chunk->chunk_type == INSERTION_LSCT) &&
				(chunk->metadata.minor == CAROUSEL_SLIDE_MINLC))
				if (in_carousel == NULL) in_carousel = chunk;
			if ((chunk->chunk_type == INSERTION_LSCT) &&
				(chunk->metadata.minor == CAROUSEL_END_MINLC)) {
				if (in_carousel == NULL)
					WebErrors::record_at(I"no carousel to end", chunk->onset_line);
				in_carousel = NULL;
			}
			if ((chunk->holon) && (in_carousel))
				WebErrors::record_at(I"code cannot appear in a carousel slide", chunk->onset_line);
			if ((chunk->chunk_type == DEFINITION_LSCT) && (in_carousel))
				WebErrors::record_at(I"definitions cannot appear in a carousel slide", chunk->onset_line);
		}
		if (in_carousel) WebErrors::record_at(I"this carousel has no end", in_carousel->onset_line);
	}

@ In some webs, the content of the commentary chunks is written in Markdown
format. We're only going to parse this if we need to: for tangling, for example,
we don't need to, and nor if the syntax doesn't use Markdown anyway. So this
is a further function which can be called after completion of a unit:

=
void LiterateSource::parse_markdown(ls_unit *lsu) {
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
			if (chunk->chunk_type == COMMENTARY_LSCT) {
				TEMPORARY_TEXT(concatenated)
				for (ls_line *line = chunk->first_line; line; line = line->next_line)
					WRITE_TO(concatenated, "%S\n", line->classification.operand1);
				chunk->as_markdown = Markdown::parse_extended(concatenated,
					MarkdownVariations::GitHub_flavored_Markdown());
				DISCARD_TEXT(concatenated)
			}
}

@ In all of that construction, we needed some surgery on doubly-linked lists:

=
void LiterateSource::remove_chunk_from_par(ls_chunk *chunk, ls_paragraph *par) {
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
		chunk->next_chunk->prev_chunk = chunk->prev_chunk;
	}
}

void LiterateSource::remove_par_from_unit(ls_paragraph *par, ls_unit *lsu) {
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

@h Fragments only.
The following provides the simplest possible demonstration of the functions
above. It makes an |ls_unit| out of a small fragment of code stored as text
in memory, and which contains only code, not commentary or any of the other
bells and whistles possible.

As can be seen, most of the work is just breaking the text into lines, so
that they can be fed to the unit.

The result will be a unit of one paragraph, holding one chunk, corresponding
to a single nameless holon.

=
ls_unit *LiterateSource::code_fragment_to_unit(ls_syntax *syntax,
	programming_language *language, text_stream *code, text_file_position tfp) {
	ls_unit *lsu = LiterateSource::begin_unit(NULL, syntax, language, NULL, NULL);
	LiterateSource::feed_paragraph_start(lsu, &tfp);
	LiterateSource::feed_code_start(lsu, &tfp);
	TEMPORARY_TEXT(buffer)
	for (int i=0; i<Str::len(code); i++) {
		inchar32_t c = Str::get_at(code, i);
		if (c == '\n') {
			LiterateSource::feed_code_line(lsu, &tfp, buffer);
			tfp.line_count++;
			Str::clear(buffer);
		} else {
			PUT_TO(buffer, c);
		}
	}
	if (Str::len(buffer) > 0) LiterateSource::feed_code_line(lsu, &tfp, buffer);
	DISCARD_TEXT(buffer)
	LiterateSource::feed_code_end(lsu, &tfp);
	LiterateSource::complete_unit(lsu);
	return lsu;
}

@h Functions for examining webs.
Units first:

=
text_stream *LiterateSource::unit_namespace(ls_unit *lsu) {
	if ((lsu) && (lsu->heading.minor == SECTION_HEADING_MINLC)) return lsu->heading.operand2;
	return NULL;
}

text_stream *LiterateSource::unit_purpose(ls_unit *lsu) {
	if ((lsu) && (lsu->purpose.minor == PURPOSE_MINLC)) return lsu->purpose.operand1;
	return NULL;
}

int LiterateSource::unit_has_purpose(ls_unit *lsu) {
	if (Str::len(LiterateSource::unit_purpose(lsu)) > 0) return TRUE;
	return FALSE;
}

int LiterateSource::unit_has_errors(ls_unit *lsu) {
	if (LinkedLists::len(lsu->errors) > 0) return TRUE;
	return FALSE;
}

@ Paragraphs:

=
text_stream *LiterateSource::par_title(ls_paragraph *par) {
	return par->titling.operand1;
}

text_stream *LiterateSource::par_ornament(ls_paragraph *par) {
	return I"S";
}

int LiterateSource::par_has_visible_number(ls_paragraph *par) {
	ls_section *S = LiterateSource::section_of_par(par);
	if (S) return S->paragraph_numbers_visible;
	return TRUE;
}

int LiterateSource::par_contains_early_code(ls_paragraph *par) {
	if ((par == NULL) || (par->holon == NULL)) return FALSE;
	return par->holon->placed_early;
}

int LiterateSource::par_contains_very_early_code(ls_paragraph *par) {
	if ((par == NULL) || (par->holon == NULL)) return FALSE;
	return par->holon->placed_very_early;
}

int LiterateSource::par_contains_named_holon(ls_paragraph *par) {
	if ((par == NULL) || (par->holon == NULL)) return FALSE;
	if (Str::len(par->holon->holon_name) > 0) return TRUE;
	return FALSE;
}

@ Chunks:

=
int LiterateSource::is_code_chunk(ls_chunk *chunk) {
	if ((chunk) && (chunk->chunk_type == EXTRACT_LSCT) && (chunk->holon)) return TRUE;
	return FALSE;
}

int LiterateSource::is_text_extract_chunk(ls_chunk *chunk) {
	if ((chunk) && (chunk->chunk_type == EXTRACT_LSCT) && (chunk->holon == NULL)) return TRUE;
	return FALSE;
}

@ Lines:

=
text_stream *LiterateSource::line_weaving_matter(ls_line *line) {
	if (line == NULL) return NULL;
	if ((line->classification.operand1) &&
		((line->classification.major == COMMENTARY_MAJLC) ||
			(line->classification.major == QUOTATION_MAJLC) ||
			(line->classification.major == EXTRACT_MATTER_MAJLC)))
		return line->classification.operand1;
	return line->text;	
}

@h Functions for crawling webs.

=
ls_section *LiterateSource::section_of_par(ls_paragraph *par) {
	if (par == NULL) return NULL;
	if (par->owning_unit == NULL) return NULL;
	return par->owning_unit->owning_section;
}
ls_paragraph *LiterateSource::par_of_line(ls_line *line) {
	if (line == NULL) return NULL;
	if (line->owning_chunk == NULL) return NULL;
	return line->owning_chunk->owner;
}
ls_unit *LiterateSource::unit_of_line(ls_line *line) {
	ls_paragraph *par = LiterateSource::par_of_line(line);
	if (par == NULL) return NULL;
	return par->owning_unit;
}
ls_section *LiterateSource::section_of_line(ls_line *line) {
	return LiterateSource::section_of_par(LiterateSource::par_of_line(line));
}

@h Tagging of paragraphs.
A "tagging" occurs when a paragraph is marked with a given tag, and perhaps
also with a contextually relevant caption. The following records those;
they're stored as a linked list within each paragraph.

=
typedef struct literate_source_tagging {
	struct text_stream *the_tag;
	struct text_stream *caption;
	CLASS_DEFINITION
} literate_source_tagging;

void LiterateSource::tag_paragraph_with_caption(ls_paragraph *par, text_stream *tag, text_stream *caption) {
	if (Str::len(tag) == 0) internal_error("empty tag name");
	if (par) {
		if (par->taggings == NULL) par->taggings = NEW_LINKED_LIST(literate_source_tagging);
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if ((Str::eq(pt->the_tag, tag)) && (Str::eq(pt->caption, caption)))
				return;
		pt = CREATE(literate_source_tagging);
		pt->the_tag = Str::duplicate(tag);
		if (caption) pt->caption = Str::duplicate(caption);
		else pt->caption = Str::new();
		ADD_TO_LINKED_LIST(pt, literate_source_tagging, par->taggings);
	}
}

@ Tags are created simply by being used in taggings. If the tag notation
|^"History: How tags came about"| is found, the following is called, and
the tag is |History|, the caption "How tags came about".

=
void LiterateSource::tag_paragraph(ls_paragraph *par, text_stream *text) {
	if (Str::len(text) == 0) internal_error("empty tag name");
	if (par) {
		TEMPORARY_TEXT(name) Str::copy(name, text);
		TEMPORARY_TEXT(caption)
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, name, U"(%c+?): (%c+)")) {
			Str::copy(name, mr.exp[0]);
			Str::copy(caption, mr.exp[1]);
		}
		LiterateSource::tag_paragraph_with_caption(par, name, caption);
		DISCARD_TEXT(name)
		DISCARD_TEXT(caption)
		Regexp::dispose_of(&mr);
	}
}

@ If a given line is tagged with a given tag, what caption does it have?

=
text_stream *LiterateSource::retrieve_caption_for_tag(ls_paragraph *par, text_stream *tag) {
	if (Str::len(tag) == 0) return NULL;
	if ((par) && (par->taggings)) {
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if (tag == pt->the_tag)
				return pt->caption;
	}
	return NULL;
}

@ Finally, this tests whether a given paragraph falls under a given tag.
(Everything falls under the null non-tag: this ensures that a weave which
doesn't specify a tag will include everything.)

=
int LiterateSource::is_tagged_with(ls_paragraph *par, text_stream *tag) {
	if (Str::len(tag) == 0) return TRUE; /* see above! */
	if ((par) && (par->taggings)) {
		literate_source_tagging *pt;
		LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings)
			if (tag == pt->the_tag)
				return TRUE;
	}
	return FALSE;
}

@h Footnote notation.

=
typedef struct ls_footnote {
	int footnote_cue_number;
	int footnote_text_number;
	struct text_stream *cue_text;
	int cued_already;
} ls_footnote;

@<Work out footnote numbering for this paragraph@> =
	int next_footnote_in_para = 1;
	ls_footnote *current_text = NULL;
	TEMPORARY_TEXT(before)
	TEMPORARY_TEXT(cue)
	TEMPORARY_TEXT(after)
	for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
		if (chunk->chunk_type == COMMENTARY_LSCT)
			for (ls_line *line = chunk->first_line; line; line = line->next_line) {
				Str::clear(before); Str::clear(cue); Str::clear(after);
				if (LiterateSource::detect_footnote(par->owning_unit->syntax, line->text, before, cue, after)) {
					int this_is_a_cue = FALSE;
					LOOP_THROUGH_TEXT(pos, before)
						if (Characters::is_whitespace(Str::get(pos)) == FALSE)
							this_is_a_cue = TRUE;
					if (this_is_a_cue == FALSE)
						@<This line begins a footnote text@>;
				}
				line->footnote_text = current_text;
			}
	DISCARD_TEXT(before)
	DISCARD_TEXT(cue)
	DISCARD_TEXT(after)

@<This line begins a footnote text@> =
	ls_footnote *F = CREATE(ls_footnote);	
	F->footnote_cue_number = Str::atoi(cue, 0);
	if (F->footnote_cue_number != next_footnote_in_para) {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "footnote should be numbered [%d], not [%d]",
			next_footnote_in_para, F->footnote_cue_number);
		WebErrors::record_at(err, line);
		DISCARD_TEXT(err)
	}
	next_footnote_in_para++;
	F->footnote_text_number = next_footnote++;
	F->cue_text = Str::new();
	F->cued_already = FALSE;
	WRITE_TO(F->cue_text, "%d", F->footnote_text_number);
	if (par->footnotes == NULL) par->footnotes = NEW_LINKED_LIST(ls_footnote);
	ADD_TO_LINKED_LIST(F, ls_footnote, par->footnotes);
	current_text = F;

@ Where:

=
int LiterateSource::detect_footnote(ls_syntax *S,
	text_stream *matter, text_stream *before, text_stream *cue, text_stream *after) {
	if (WebSyntax::supports(S, FOOTNOTES_WSF)) {
		text_stream *on_notation = WebSyntax::notation(S, FOOTNOTES_WSF, 1);
		text_stream *off_notation = WebSyntax::notation(S, FOOTNOTES_WSF, 2);
		int N1 = Str::len(on_notation);
		int N2 = Str::len(off_notation);
		if ((N1 > 0) && (N2 > 0))
			for (int i=0; i < Str::len(matter); i++) {
				if (Str::includes_at(matter, i, on_notation)) {
					int j = i + N1 + 1;
					while (j < Str::len(matter)) {
						if (Str::includes_at(matter, j, off_notation)) {
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

ls_footnote *LiterateSource::find_footnote_in_para(ls_paragraph *par, text_stream *cue) {
	int N = Str::atoi(cue, 0);		
	ls_footnote *F;
	if ((par) && (par->footnotes))
		LOOP_OVER_LINKED_LIST(F, ls_footnote, par->footnotes)
			if (N == F->footnote_cue_number)
				return F;
	return NULL;
}

@h Debugging.
The following provides a textual summary of a unit after its completion:

=
void LiterateSource::write_lsu(OUTPUT_STREAM, ls_unit *lsu) {
	if (lsu == NULL) {
		WRITE("(no literate source)\n");
		return;
	}
	if (lsu->heading.minor == SECTION_HEADING_MINLC) {
		WRITE("heading '%S'", lsu->heading.operand1);
		if (Str::len(lsu->heading.operand2) > 0)
			WRITE(", namespace '%S'", lsu->heading.operand2);
		WRITE("\n");
	}
	if (lsu->purpose.minor == PURPOSE_MINLC) {
		WRITE("Purpose '%S'\n", lsu->purpose.operand1);
	}
	if (lsu->first_par == NULL) {
		WRITE("(empty literate source)\n");
		return;
	}
	int cc = 0;
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		WRITE("%S%S", LiterateSource::par_ornament(par), par->paragraph_number);
		if (Str::len(par->titling.operand1) > 0)
			WRITE(" '%S'", par->titling.operand1);
		if (par->taggings) {
			literate_source_tagging *pt;
			LOOP_OVER_LINKED_LIST(pt, literate_source_tagging, par->taggings) {
				WRITE(" <%S>", pt->the_tag);
				if (Str::len(pt->caption) > 0) WRITE("{%S}", pt->caption);
			}
		}
		WRITE("\n");
		INDENT;
		cc = 0;
		ls_chunk *my_previous = NULL;
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk) {
			cc++;
			WRITE("C%d: ", cc);
			if (chunk->holon) @<Write holon@>
			else @<Write non-holon chunk@>;
			if ((chunk == par->first_chunk) && (chunk->prev_chunk))
				WRITE("*** first chunk but has prev_chunk set\n");
			if ((chunk == par->last_chunk) && (chunk->next_chunk))
				WRITE("*** last chunk but has next_chunk set\n");
			if ((chunk != par->first_chunk) && (chunk->prev_chunk == NULL))
				WRITE("*** prev_chunk is null\n");
			else if ((chunk != par->first_chunk) && (chunk->prev_chunk != my_previous))
				WRITE("*** prev_chunk is wrong\n");
			my_previous = chunk;
		}
		OUTDENT;
	}
}

@<Write holon@> =
	WRITE("holon");
	ls_holon *holon = chunk->holon;
	if (Str::len(holon->holon_name) > 0) WRITE(" '%S'", holon->holon_name);
	if (holon->placed_early) WRITE(" (early)");
	if (holon->placed_very_early) WRITE(" (very early)");
	int uc = 0;
	holon_usage *hu;
	LOOP_OVER_LINKED_LIST(hu, holon_usage, holon->holon_usages) {
		if (uc == 0) WRITE(" (used in "); else WRITE(", ");
		uc++;
		WRITE("%S%S", LiterateSource::par_ornament(hu->used_in_paragraph),
			hu->used_in_paragraph->paragraph_number);
		if (hu->multiplicity > 1) WRITE(" x %d", hu->multiplicity);
	}
	if (uc == 0) {
		if (Str::len(holon->holon_name) > 0) WRITE(" (unused)");
		WRITE(" (used sequentially)");
	} else {
		WRITE(")");
	}
	WRITE("\n");
	INDENT
	holon_splice *hs;
	LOOP_OVER_LINKED_LIST(hs, holon_splice, holon->splice_list) {
		if (hs->expansion) {
			ls_paragraph *par = hs->expansion->corresponding_chunk->owner;
			WRITE("  holon '%S' (defined in %S%S)",
				hs->expansion->holon_name,
				LiterateSource::par_ornament(par),
				par->paragraph_number);
		} else if (Str::len(hs->command) > 0) WRITE("command '%S'", hs->command);
		else {
			LiterateSource::write_code(OUT, hs->line, hs->line->text, hs->from, hs->to);
		}
		WRITE("\n");
	}
	OUTDENT
		
@<Write non-holon chunk@> =
	switch (chunk->chunk_type) {
		case COMMENTARY_LSCT: WRITE("commentary\n"); break;
		case QUOTATION_LSCT: WRITE("quotation\n"); break;
		case EXTRACT_LSCT:
			if (chunk->hyperlinked) WRITE("hyperlinked ");
			if (chunk->plainer) WRITE("undisplayed ");
			switch (chunk->metadata.minor) {
				case CODE_MINLC: WRITE("code "); break;
				case EARLY_MINLC: WRITE("early code "); break;
				case VERY_EARLY_MINLC: WRITE("very early code "); break;
				case TEXT_AS_MINLC: WRITE("code ");
					if (Str::len(chunk->metadata.operand1) > 0)
						WRITE("in %S ", chunk->metadata.operand1); break;
				case TEXT_TO_MINLC: WRITE("plain text to file '%S' ", chunk->metadata.operand1); break;
				case TEXT_MINLC: WRITE("plain text "); break;
				case NO_MINLC: WRITE("code "); break;
				default: WRITE("? "); break;
			}
			WRITE("extract\n");
			break;
		case INSERTION_LSCT:
			switch (chunk->metadata.minor) {
				case AUDIO_MINLC: WRITE("audio '%S'", chunk->metadata.operand1); break;
				case CAROUSEL_SLIDE_MINLC:
					WRITE("carousel slide captioned '%S'", chunk->metadata.operand1);
					if (chunk->carousel_caption_position < 0) WRITE(" (positioned below)");
					if (chunk->carousel_caption_position > 0) WRITE(" (positioned above)");
					break;
				case CAROUSEL_END_MINLC: WRITE("carousel end"); break;
				case DOWNLOAD_MINLC: WRITE("download '%S'", chunk->metadata.operand1); break;
				case EMBEDDED_AV_MINLC: WRITE("embedded av '%S'", chunk->metadata.operand1); break;
				case FIGURE_MINLC: WRITE("figure '%S'", chunk->metadata.operand1); break;
				case HTML_MINLC: WRITE("HTML '%S'", chunk->metadata.operand1); break;
				case VIDEO_MINLC: WRITE("video '%S'", chunk->metadata.operand1); break;
				default: WRITE("?"); break;
			}
			WRITE(" insertion\n"); break;
		case DEFINITION_LSCT:
			switch (chunk->metadata.minor) {
				case DEFINE_COMMAND_MINLC: WRITE("define"); break;
				case DEFAULT_COMMAND_MINLC: WRITE("default"); break;
				case ENUMERATE_COMMAND_MINLC: WRITE("enumerate"); break;
				default: WRITE("? definition of some sort"); break;
			}
			WRITE(" '%S'", chunk->symbol_defined);
			if (Str::len(chunk->symbol_value) > 0) WRITE(" = %S", chunk->symbol_value);
			WRITE("\n");
			break;
		case HOLON_DECLARATION_LSCT: WRITE("holon definition\n"); break;
		case OTHER_LSCT: WRITE("other\n"); break;
		default: WRITE("?\n"); break;
	}
	INDENT;
	for (ls_line *line = chunk->first_line; line; line = line->next_line) {
		switch (line->classification.major) {
			case COMMENTARY_MAJLC:
			case QUOTATION_MAJLC:
			case EXTRACT_MATTER_MAJLC:
				WRITE("_______ ");
				LiterateSource::write_code(OUT, NULL, line->classification.operand1,
					0, Str::len(line->classification.operand1)-1);
				WRITE("\n"); break;
			case HOLON_DECLARATION_MAJLC:
				WRITE("holon declaration '%S'\n", line->classification.operand1); break;
			case DEFINITION_MAJLC: break;
			case DEFINITION_CONTINUED_MAJLC:
				LiterateSource::write_code(OUT, line, line->text, 0, Str::len(line->text)-1);
				WRITE("\n");
				break;
			case INSERTION_MAJLC:
				break;
			default:
				WRITE("class %d/%d: %S / %S / %S\n",
					line->classification.major,
					line->classification.minor,
					line->classification.operand1,
					line->classification.operand2,
					line->classification.operand3);
				break;
		}
	}
	OUTDENT;

@ =
void LiterateSource::write_code(OUTPUT_STREAM, ls_line *line, text_stream *text, int from, int to) {
	if (line) WRITE("%07d ", line->origin.line_count);
	for (int i=from; i<=to; i++) {
		inchar32_t c = Str::get_at(text, i);
		if (c == ' ') PUT(0x23D1);
		else if (c == '\t') PUT(0x21E2);
		else PUT(c);
		if (c == '\t') WRITE("   ");
	}
}
