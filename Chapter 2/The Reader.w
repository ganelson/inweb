[Reader::] The Reader.

To read the Contents section of the web, and through that each of
the other sections in turn, and to collate all of this material.

@h Web semantics.
There's normally only one web read in during a single run of Inweb, but
this might change if we ever add batch-processing in future. A web is a set
of chapters each of which is a set of sections; webs which don't obviously
divide into chapters will be called "unchaptered", though in fact they do
have a single chapter, called simply "Sections" (and with range "S").

The program expressed by a web is output, or "tangled", to a number of
stand-alone files called "tangle targets". By default there is just one
of these.

We use the |WebMetadata::get| function of |foundation| to read the structure
of the web in from the file system. This produces a |web_md| metadata
structure for the web itself, which contains a list of |chapter_md|
structures for the chapters, each in turn containing a list of |section_md|s.
We will imitate that structure exactly, but because we want to attach a lot
of semantics at each level, we will make a |web| with a list of |chapter|s
each of which has a list of |section|s.

Here are the semantics for a web:

=
typedef struct web {
	struct web_md *md;
	struct linked_list *chapters; /* of |chapter| (including Sections, Preliminaries, etc.) */

	int web_extent; /* total lines in literate source, excluding contents */
	int no_paragraphs; /* this will be at least 1 */

	struct programming_language *main_language; /* in which most of the sections are written */
	struct linked_list *tangle_targets; /* of |tangle_target| */

	struct linked_list *headers; /* of |filename|: additional header files */
	int analysed; /* has this been scanned for function usage and such? */
	struct linked_list *language_types; /* of |language_type|: used only for C-like languages */

	struct ebook *as_ebook; /* when being woven to an ebook */
	struct pathname *redirect_weaves_to; /* ditto */

	CLASS_DEFINITION
} web;

@ And for a chapter:

=
typedef struct chapter {
	struct chapter_md *md;
	struct web *owning_web;
	struct linked_list *sections; /* of |section| */

	struct weave_order *ch_weave; /* |NULL| unless this chapter produces a weave of its own */
	int titling_line_inserted; /* has an interleaved chapter heading been added yet? */
	struct programming_language *ch_language; /* in which this chapter is written */
	CLASS_DEFINITION
} chapter;

@ And lastly for a section.

=
typedef struct section {
	struct section_md *md;
	struct web *owning_web;
	struct chapter *owning_chapter;

	struct text_stream *sect_namespace; /* e.g., "Text::Languages::" */
	struct text_stream *sect_purpose; /* e.g., "To manage the zoo, and feed all penguins" */
	int barred; /* if version 1 syntax, contains a dividing bar? */
	struct programming_language *sect_language; /* in which this section is written */
	struct tangle_target *sect_target; /* |NULL| unless this section produces a tangle of its own */
	struct weave_order *sect_weave; /* |NULL| unless this section produces a weave of its own */

	int sect_extent; /* total number of lines in this section */
	struct source_line *first_line; /* for efficiency's sake not held as a |linked_list|, */
	struct source_line *last_line; /* but that's what it is, all the same */

	int sect_paragraphs; /* total number of paragraphs in this section */
	struct linked_list *paragraphs; /* of |paragraph|: the content of this section */
	struct theme_tag *tag_with; /* automatically tag paras in this section thus */

	struct linked_list *macros; /* of |para_macro|: those defined in this section */

	int scratch_flag; /* temporary workspace */
	int paused_until_at; /* ignore the top half of the file, until the first |@| sign */
	int printed_number; /* temporary again: sometimes used in weaving */
	CLASS_DEFINITION
} section;

@ The following routine makes the |web|-|chapter|-|section| tree out of a
|web_md|-|chapter_md|-|section_md| tree:

=
web_md *Reader::load_web_md(pathname *P, filename *alt_F, module_search *I,
	int including_modules) {
	return WebMetadata::get(P, alt_F, default_inweb_syntax, I, verbose_mode,
		including_modules, path_to_inweb);
}

web *Reader::load_web(pathname *P, filename *alt_F, module_search *I,
	int including_modules) {

	web *W = CREATE(web);
	W->md = Reader::load_web_md(P, alt_F, I, including_modules);
	tangle_target *main_target = NULL;

	@<Write the Inweb Version bibliographic datum@>;
	@<Initialise the rest of the web structure@>;
	chapter_md *Cm;
	LOOP_OVER_LINKED_LIST(Cm, chapter_md, W->md->chapters_md) {
		chapter *C = CREATE(chapter);
		C->md = Cm;
		C->owning_web = W;
		@<Initialise the rest of the chapter structure@>;
		ADD_TO_LINKED_LIST(C, chapter, W->chapters);
		section_md *Sm;
		LOOP_OVER_LINKED_LIST(Sm, section_md, Cm->sections_md) {
			section *S = CREATE(section);
			S->md = Sm;
			S->owning_chapter = C;
			S->owning_web = W;
			@<Initialise the rest of the section structure@>;
			ADD_TO_LINKED_LIST(S, section, C->sections);
		}
	}
	@<Add the imported headers@>;
	return W;
}

@<Write the Inweb Version bibliographic datum@> =
	TEMPORARY_TEXT(IB)
	WRITE_TO(IB, "[[Version Number]]");
	web_bibliographic_datum *bd = Bibliographic::set_datum(W->md, I"Inweb Version", IB);
	bd->declaration_permitted = FALSE;
	DISCARD_TEXT(IB)

@<Initialise the rest of the web structure@> =
	W->chapters = NEW_LINKED_LIST(chapter);
	W->headers = NEW_LINKED_LIST(filename);
	W->language_types = NEW_LINKED_LIST(language_type);
	W->tangle_targets = NEW_LINKED_LIST(tangle_target);
	W->analysed = FALSE;
	W->as_ebook = NULL;
	W->redirect_weaves_to = NULL;
	W->main_language = Analyser::default_language(W);
	W->web_extent = 0; W->no_paragraphs = 0; 
	text_stream *language_name = Bibliographic::get_datum(W->md, I"Language");
	if (Str::len(language_name) > 0)
		W->main_language = Analyser::find_by_name(language_name, W, TRUE);
	main_target = Reader::add_tangle_target(W, W->main_language);

@<Initialise the rest of the chapter structure@> =
	C->ch_weave = NULL;
	C->titling_line_inserted = FALSE;
	C->sections = NEW_LINKED_LIST(section);
	C->ch_language = W->main_language;
	if (Str::len(Cm->ch_language_name) > 0)
		C->ch_language = Analyser::find_by_name(Cm->ch_language_name, W, TRUE);

@<Initialise the rest of the section structure@> =
	S->sect_extent = 0;
	S->first_line = NULL; S->last_line = NULL;
	S->sect_paragraphs = 0;
	S->paragraphs = NEW_LINKED_LIST(paragraph);
	S->macros = NEW_LINKED_LIST(para_macro);

	S->scratch_flag = FALSE;
	S->barred = FALSE;
	S->printed_number = -1;
	S->sect_weave = NULL;
	S->sect_namespace = Str::new();
	S->owning_web = W;
	S->sect_language = C->ch_language;
	if (Str::len(S->md->sect_language_name) > 0)
		S->sect_language = Analyser::find_by_name(S->md->sect_language_name, W, TRUE);
	if (Str::len(S->md->sect_independent_language) > 0) {
		programming_language *pl =
			Analyser::find_by_name(S->md->sect_independent_language, W, TRUE);
		S->sect_language = pl;
		S->sect_target = Reader::add_tangle_target(W, pl);
	} else {
		S->sect_target = main_target;
	}
	S->tag_with = NULL;
	if (Str::len(Sm->tag_name) > 0)
		S->tag_with = Tags::add_by_name(NULL, Sm->tag_name);

@<Add the imported headers@> =
	filename *HF;
	LOOP_OVER_LINKED_LIST(HF, filename, W->md->header_filenames)
		Reader::add_imported_header(W, HF);

@h Web reading.
All of that ran very quickly, but now things will slow down. The next
function is where the actual contents of a web are read -- which means opening
each section and reading it line by line. We read the complete literate source
of the web into memory, which is profligate, but saves time. Most of the lines
come straight from the source files, but a few chapter heading lines are
inserted if this is a multi-chapter web.

=
void Reader::read_web(web *W) {
	chapter *C;
	section *S;
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			Reader::read_file(W, C,
				S->md->source_file_for_section,
				S->md->titling_line_to_insert, S,
				(W->md->single_file)?TRUE:FALSE);
}

@ Each file, then:

=
void Reader::read_file(web *W, chapter *C, filename *F, text_stream *titling_line,
	section *S, int disregard_top) {
	S->owning_chapter = C;
	if (disregard_top)
		S->paused_until_at = TRUE;
	else
		S->paused_until_at = FALSE;

	if ((titling_line) && (Str::len(titling_line) > 0) &&
		(S->owning_chapter->titling_line_inserted == FALSE))
		@<Insert an implied chapter heading@>;
	
	if (disregard_top)
		@<Insert an implied section heading, for a single-file web@>;

	int cl = TextFiles::read(F, FALSE, "can't open section file", TRUE,
		Reader::scan_source_line, NULL, (void *) S);
	if (verbose_mode) PRINT("Read section: '%S' (%d lines)\n", S->md->sect_title, cl);
}

@<Insert an implied chapter heading@> =
	S->owning_chapter->titling_line_inserted = TRUE;
	TEMPORARY_TEXT(line)
	text_file_position *tfp = NULL;
	WRITE_TO(line, "Chapter Heading");
	@<Accept this as a line belonging to this section and chapter@>;
	DISCARD_TEXT(line)

@<Insert an implied section heading, for a single-file web@> =
	TEMPORARY_TEXT(line)
	text_file_position *tfp = NULL;
	WRITE_TO(line, "Main.");
	@<Accept this as a line belonging to this section and chapter@>;
	Str::clear(line);
	@<Accept this as a line belonging to this section and chapter@>;
	text_stream *purpose = Bibliographic::get_datum(W->md, I"Purpose");
	if (Str::len(purpose) > 0) {
		Str::clear(line);
		WRITE_TO(line, "Implied Purpose: %S", purpose);
		@<Accept this as a line belonging to this section and chapter@>;
		Str::clear(line);
		@<Accept this as a line belonging to this section and chapter@>;
	}
	DISCARD_TEXT(line)

@ Non-implied source lines come from here. Note that we assume here that
trailing whitespace on a line is not significant in the language being
tangled for.

=
void Reader::scan_source_line(text_stream *line, text_file_position *tfp, void *state) {
	section *S = (section *) state;
	int l = Str::len(line) - 1;
	while ((l>=0) && (Characters::is_space_or_tab(Str::get_at(line, l))))
		Str::truncate(line, l--);
	if (S->paused_until_at) {
		if (Str::get_at(line, 0) == '@') S->paused_until_at = FALSE;
		else return;
	}
	@<Accept this as a line belonging to this section and chapter@>;
}

@<Accept this as a line belonging to this section and chapter@> =
	source_line *sl = Lines::new_source_line_in(line, tfp, S);

	/* enter this in its section's linked list of lines: */
	if (S->first_line == NULL) S->first_line = sl;
	else S->last_line->next_line = sl;
	S->last_line = sl;

	/* we haven't detected paragraph boundaries yet, so: */
	sl->owning_paragraph = NULL;

@h Woven and Tangled folders.
We abstract these in order to be able to respond well to their not existing:

=
pathname *Reader::woven_folder(web *W) {
	pathname *P = Pathnames::down(W->md->path_to_web, I"Woven");
	if (Pathnames::create_in_file_system(P) == FALSE)
		Errors::fatal_with_path("unable to create Woven subdirectory", P);
	return P;
}
pathname *Reader::tangled_folder(web *W) {
	pathname *P = Pathnames::down(W->md->path_to_web, I"Tangled");
	if (Pathnames::create_in_file_system(P) == FALSE)
		Errors::fatal_with_path("unable to create Tangled subdirectory", P);
	return P;
}

@h Looking up chapters and sections.
Given a range, which chapter or section does it correspond to? There is no
need for this to be at all quick: there are fewer than 1000 sections even
in large webs, and lookup is performed only a few times.

Note that range comparison is case sensitive.

=
chapter *Reader::get_chapter_for_range(web *W, text_stream *range) {
	chapter *C;
	if (W)
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			if (Str::eq(C->md->ch_range, range))
				return C;
	return NULL;
}

section *Reader::get_section_for_range(web *W, text_stream *range) {
	chapter *C;
	section *S;
	if (W)
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S, section, C->sections)
				if (Str::eq(S->md->sect_range, range))
					return S;
	return NULL;
}

@ This clumsy routine is never used in syntax version 2 or later.

=
section *Reader::section_by_filename(web *W, text_stream *filename) {
	chapter *C;
	section *S;
	if (W)
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S, section, C->sections) {
				TEMPORARY_TEXT(SFN)
				WRITE_TO(SFN, "%f", S->md->source_file_for_section);
				int rv = Str::eq(SFN, filename);
				DISCARD_TEXT(SFN)
				if (rv) return S;
			}
	return NULL;
}

@h Ranges and containment.
This provides a sort of partial ordering on ranges, testing if the portion
of the web represented by |range1| is contained inside the portion represented
by |range2|. Note that |"0"| means the entire web, and is what the word |all|
translates to when it's used on the command line.

=
int Reader::range_within(text_stream *range1, text_stream *range2) {
	if (Str::eq_wide_string(range2, U"0")) return TRUE;
	if (Str::eq(range1, range2)) return TRUE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, range2, U"%c+/%c+")) { Regexp::dispose_of(&mr); return FALSE; }
	if (Regexp::match(&mr, range1, U"(%c+)/%c+")) {
		if (Str::eq(mr.exp[0], range2)) { Regexp::dispose_of(&mr); return TRUE; }
	}
	return FALSE;
}

@h Tangle targets.
In Knuth's original conception of literate programming, a web produces
just one piece of tangled output -- the program for compilation. But this
assumes that the underlying program is so simple that it won't require
ancillary files, configuration data, and such; and this is often just as
complex and worth explaining as the program itself. So Inweb allows a
web to contain multiple tangle targets, each of which contains a union of
sections. Each section belongs to exactly one tangle target; by default
a web contains just one target, which contains all of the sections.

=
typedef struct tangle_target {
	struct programming_language *tangle_language; /* common to the entire contents */
	struct hash_table symbols; /* a table of identifiable names in this program */
	CLASS_DEFINITION
} tangle_target;

@ =
tangle_target *Reader::add_tangle_target(web *W, programming_language *language) {
	tangle_target *tt = CREATE(tangle_target);
	tt->tangle_language = language;
	ReservedWords::initialise_hash_table(&(tt->symbols));
	ADD_TO_LINKED_LIST(tt, tangle_target, W->tangle_targets);
	return tt;
}

@ And the following provides a way to iterate through the lines in a tangle,
while keeping the variables |C|, |S| and |L| pointing to the current chapter,
section and line.

@d LOOP_WITHIN_TANGLE(C, S, T)
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			if (S->sect_target == T)
				for (source_line *L = S->first_line; L; L = L->next_line)

@h Additional header files.
Some C programs, in particular, may need additional header files added to
any tangle in order for them to compile. (The Inform project uses this to
get around the lack of some POSIX facilities on Windows.)

=
void Reader::add_imported_header(web *W, filename *HF) {
	ADD_TO_LINKED_LIST(HF, filename, W->headers);
}

@h Extent.

=
int Reader::web_has_one_section(web *W) {
	if (WebMetadata::section_count(W->md) == 1) return TRUE;
	return FALSE;
}

@ This really serves no purpose, but seems to boost morale.

=
void Reader::print_web_statistics(web *W) {
	PRINT("web \"%S\": ", Bibliographic::get_datum(W->md, I"Title"));
	int c = WebMetadata::chapter_count(W->md);
	int s = WebMetadata::section_count(W->md);
	if (W->md->chaptered) PRINT("%d chapter%s : ",
		c, (c == 1)?"":"s");
	PRINT("%d section%s : %d paragraph%s : %d line%s\n",
		s, (s == 1)?"":"s",
		W->no_paragraphs, (W->no_paragraphs == 1)?"":"s",
		W->web_extent, (W->web_extent == 1)?"":"s");
}


