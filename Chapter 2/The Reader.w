[Reader::] The Reader.

To read the Contents section of the web, and through that each of
the other sections in turn, and to collate all of this material.

@h Web storage.
There's normally only one web read in during a single run of Inweb, but
this might change if we ever add batch-processing in future. A web is a set
of chapters each of which is a set of sections; webs which don't obviously
divide into chapters will be called "unchaptered", though in fact they do
have a single chapter, called simply "Sections" (and with range "S").

The program expressed by a web is output, or "tangled", to a number of
stand-alone files called "tangle targets". By default there is just one
of these.

We read the complete literate source of the web into memory, which is
profligate, but saves time. Most of the lines come straight from the
source files, but a few chapter heading lines are inserted if this is a
multi-chapter web.

=
typedef struct web {
	struct pathname *path_to_web; /* relative to the current working directory */
	struct filename *single_file; /* relative to the current working directory */
	int default_syntax; /* which version syntax the sections will have */

	/* convenient statistics */
	int no_lines; /* total lines in literate source, excluding contents */
	int no_paragraphs; /* this will be at least 1 */
	int no_sections; /* again, excluding contents: it will eventually be at least 1 */
	int no_chapters; /* this will be at least 1 */
	int chaptered; /* has the author explicitly divided it into named chapters? */
	int analysed; /* has this been scanned for function usage and such? */

	struct linked_list *bibliographic_data; /* of |bibliographic_datum|: key-value pairs for title and such */
	struct semantic_version_number version_number; /* as deduced from the bibliographic data */
	struct programming_language *main_language; /* in which most of the sections are written */
	struct linked_list *tangle_targets; /* of |tangle_target| */

	struct linked_list *chapters; /* of |chapter| (including Sections, Preliminaries, etc.) */
	struct linked_list *headers; /* of |filename|: additional header files */
	struct linked_list *c_structures; /* of |c_structure|: used only for C-like languages */

	struct module *as_module; /* the root of a small dependency graph */
	struct ebook *as_ebook; /* when being woven to an ebook */
	struct pathname *redirect_weaves_to; /* ditto */
	MEMORY_MANAGEMENT
} web;

@ =
web *Reader::load_web(pathname *P, filename *alt_F, module_search *I, int verbosely,
	int inweb_mode, pathname *redirection, int parsing) {
	web *W = CREATE(web);
	W->path_to_web = P;
	W->single_file = alt_F;
	if (alt_F) W->path_to_web = Filenames::get_path_to(alt_F);
	W->chaptered = FALSE;
	W->chapters = NEW_LINKED_LIST(chapter);
	W->headers = NEW_LINKED_LIST(filename);
	W->c_structures = NEW_LINKED_LIST(c_structure);
	W->bibliographic_data = NEW_LINKED_LIST(bibliographic_datum);
	W->tangle_targets = NEW_LINKED_LIST(tangle_target);
	W->no_lines = 0; W->no_sections = 0; W->no_chapters = 0; W->no_paragraphs = 0;
	W->analysed = FALSE;
	W->as_ebook = NULL;
	W->redirect_weaves_to = redirection;
	W->as_module = Modules::create_main_module(W);
	W->default_syntax = default_inweb_syntax;
	W->version_number = VersionNumbers::null();
	Bibliographic::initialise_data(W);
	Reader::add_tangle_target(W, Languages::default()); /* the bulk of the web is automatically a target */
	Reader::read_contents_page(W, I, verbosely, parsing);
	BuildFiles::deduce_semver(W);
	Parser::parse_web(W, inweb_mode);
	if (W->no_sections == 1) {
		chapter *C = FIRST_IN_LINKED_LIST(chapter, W->chapters);
		section *S = FIRST_IN_LINKED_LIST(section, C->sections);
		S->is_a_singleton = TRUE;
	}
	return W;
}

@ We abstract these in order to be able to respond well to their not existing:

=
pathname *Reader::woven_folder(web *W) {
	pathname *P = Pathnames::subfolder(W->path_to_web, I"Woven");
	if (Pathnames::create_in_file_system(P) == FALSE)
		Errors::fatal_with_path("unable to create Woven subdirectory", P);
	return P;
}
pathname *Reader::tangled_folder(web *W) {
	pathname *P = Pathnames::subfolder(W->path_to_web, I"Tangled");
	if (Pathnames::create_in_file_system(P) == FALSE)
		Errors::fatal_with_path("unable to create Tangled subdirectory", P);
	return P;
}

@ This really serves no purpose, but seems to boost morale.

=
void Reader::print_web_statistics(web *W) {
	PRINT("web \"%S\": ", Bibliographic::get_datum(W, I"Title"));
	if (W->chaptered) PRINT("%d chapter(s) : ", W->no_chapters);
	PRINT("%d section(s) : %d paragraph(s) : %d line(s)\n",
		W->no_sections, W->no_paragraphs, W->no_lines);
}

@h Chapters and sections.
Each web contains a linked list of chapters, in reading order:

=
typedef struct chapter {
	struct text_stream *ch_range; /* e.g., |P| for Preliminaries, |7| for Chapter 7, |C| for Appendix C */
	struct text_stream *ch_title; /* e.g., "Chapter 3: Fresh Water Fish" */
	struct text_stream *rubric; /* optional; without double-quotation marks */

	struct tangle_target *ch_target; /* |NULL| unless this chapter produces a tangle of its own */
	struct weave_target *ch_weave; /* |NULL| unless this chapter produces a weave of its own */
	struct programming_language *ch_language; /* in which most of the sections are written */

	int titling_line_inserted; /* has an interleaved chapter heading been added yet? */

	int ch_extent; /* total number of lines in the sections of this chapter */
	struct linked_list *sections; /* of |section|: the content of this chapter */

	struct web *owning_web;
	int imported; /* from a different web? */
	MEMORY_MANAGEMENT
} chapter;

@ Each chapter contains a linked list of sections, in reading order:

=
typedef struct section {
	struct text_stream *range; /* e.g., "9/tfto" */
	struct text_stream *sect_title; /* e.g., "Program Control" */
	struct text_stream *sect_namespace; /* e.g., "Text::Languages::" */
	struct text_stream *sect_purpose; /* e.g., "To manage the zoo, and feed all penguins" */
	int using_syntax; /* which syntax the web is written in */
	int barred; /* if version 1 syntax, contains a dividing bar? */
	int is_a_singleton; /* is this the only section in its entire web? */

	struct filename *source_file_for_section;
	int paused_until_at; /* ignore the top half of the file, until the first |@| sign */

	struct tangle_target *sect_target; /* |NULL| unless this section produces a tangle of its own */
	struct weave_target *sect_weave; /* |NULL| unless this section produces a weave of its own */
	struct programming_language *sect_language; /* in which this section is written */

	int sect_extent; /* total number of lines in this section */
	struct source_line *first_line; /* for efficiency's sake not held as a |linked_list|, */
	struct source_line *last_line; /* but that's what it is, all the same */

	int sect_paragraphs; /* total number of paragraphs in this section */
	struct linked_list *paragraphs; /* of |paragraph|: the content of this section */
	struct theme_tag *tag_with; /* automatically tag paras in this section thus */

	struct linked_list *macros; /* of |para_macro|: those defined in this section */

	struct chapter *owning_chapter;

	int scratch_flag; /* temporary workspace */
	int printed_number; /* temporary again: sometimes used in weaving */
	int erroneous_interface; /* problem with Interface declarations */
	MEMORY_MANAGEMENT
} section;

@h Reading the contents page.
Making the web begins by reading the contents section, which really isn't a
section at all (and perhaps we shouldn't pretend that it is by the use of the
|.w| file extension, but we probably want it to have the same file extension,
and its syntax is chosen so that syntax-colouring for regular sections doesn't
make it look odd). When the word "section" is used in the Inweb code, it
almost always means "section other than the contents".

Because a contents page can, by importing a module, cause a further contents
page to be read, we set this up as a recursion:

=
void Reader::read_contents_page(web *W, module_search *import_path, int verbosely, int parsing) {
	Reader::read_contents_page_from(W, import_path, verbosely, parsing, NULL);
	Bibliographic::check_required_data(W);
}

@ We then run through an individual contents page line by line, using the
following slate of variables to keep track of where we are.

With a single-file web, the "contents section" doesn't exist as a file in its
own right: instead, it's the top few lines of the single file. We handle that
by halting at the junction point.

=
typedef struct reader_state {
	struct web *current_web;
	struct filename *contents_filename;
	int in_biblio;
	int in_purpose; /* Reading the bit just after the new chapter? */
	struct chapter *chapter_being_scanned;
	struct text_stream *chapter_folder_name; /* Where sections in the current chapter live */
	struct text_stream *titling_line_to_insert; /* To be inserted automagically */
	struct pathname *path_to; /* Where web material is being read from */
	struct module_search *import_from; /* Where imported webs are */
	int scan_verbosely;
	int parsing;
	int main_web_not_module; /* Reading the original web, or an included one? */
	int halt_at_at; /* Used for reading contents pages of single-file webs */
	int halted; /* Set when such a halt has occurred */
} reader_state;

void Reader::read_contents_page_from(web *W, module_search *import_path, int verbosely,
	int parsing, pathname *path) {
	reader_state RS;
	@<Initialise the reader state@>;

	int cl = TextFiles::read(RS.contents_filename, FALSE, "can't open contents file",
		TRUE, Reader::read_contents_line, NULL, &RS);
	if (verbosely) {
		if (W->single_file) {
			PRINT("Read %d lines of contents part at top of file\n", cl);
		} else {
			PRINT("Read contents section: 'Contents.w' (%d lines)\n", cl);
		}
	}
}

@<Initialise the reader state@> =
	RS.current_web = W;
	RS.in_biblio = TRUE;
	RS.in_purpose = FALSE;
	RS.chapter_being_scanned = NULL;
	RS.chapter_folder_name = Str::new();
	RS.titling_line_to_insert = Str::new();
	RS.scan_verbosely = verbosely;
	RS.parsing = parsing;
	RS.path_to = path;
	RS.import_from = import_path;
	RS.halted = FALSE;

	if (path == NULL) {
		path = W->path_to_web;
		RS.main_web_not_module = TRUE;
	} else {
		RS.main_web_not_module = FALSE;
	}

	if (W->single_file) {
		RS.contents_filename = W->single_file;
		RS.halt_at_at = TRUE;
	} else {
		RS.contents_filename = Filenames::in_folder(path, I"Contents.w");
		RS.halt_at_at = FALSE;
	}

@ The contents section has a syntax quite different from all other sections,
and sets out bibliographic information about the web, the sections and their
organisation, and so on.

=
void Reader::read_contents_line(text_stream *line, text_file_position *tfp, void *X) {
	reader_state *RS = (reader_state *) X;
	if (RS->halted) return;

	int begins_with_white_space = FALSE;
	if (Characters::is_whitespace(Str::get_first_char(line)))
		begins_with_white_space = TRUE;
	Str::trim_white_space(line);
	
	@<Act immediately if the web syntax version is changed@>;
	int syntax = RS->current_web->default_syntax;

	filename *filename_of_single_file_web = NULL;
	if ((RS->halt_at_at) && (Str::get_at(line, 0) == '@'))
		@<Halt at this point in the single file, and make the rest of it a one-chaoter section@>;

	@<Read regular contents material@>;
}

@ Since the web syntax version affects how the rest of the file is read, it's
no good simply to store this up for later: we have to change the web structure
immediately.

@<Act immediately if the web syntax version is changed@> =
	if (Str::eq(line, I"Web Syntax Version: 1"))
		RS->current_web->default_syntax = V1_SYNTAX;
	else if (Str::eq(line, I"Web Syntax Version: 2"))
		RS->current_web->default_syntax = V2_SYNTAX;

@ Suppose we're reading a single-file web, and we hit the first |@| marker.
The contents part has now ended, so we should halt scanning. But we also need
to give the web a single chapter ("Sections", range "S"), which contains a
single section ("All") consisting of the remainder of the single file.

@<Halt at this point in the single file, and make the rest of it a one-chaoter section@> =
	RS->halted = TRUE;
	tangle_target *ind_target = Tangler::primary_target(RS->current_web);
	programming_language *ind_language = RS->current_web->main_language;
	text_stream *new_chapter_range = I"S";
	line = I"Sections";
	@<Create the new chapter with these details@>;
	line = I"All";
	filename_of_single_file_web = tfp->text_file_filename;
	@<Read about, and read in, a new section@>;
	return;

@ With those two complications out of the way, we now know that we're reading
a line of contents material. At the start of the contents, this will be a
series of bibliographic data values; then there's a blank line, and then
we're into the section listing.

@<Read regular contents material@> =
	if (Str::len(line) == 0) @<End bibliographic data here, at the blank line@>
	else if (RS->in_biblio) @<Read the bibliographic data block at the top@>
	else @<Read the roster of sections at the bottom@>;

@ At this point we've gone through the bibliographic lines at the top of the
contents page, and are soon going to read in the sections. The language needs
to be known for that, so we'll set it now.

@<End bibliographic data here, at the blank line@> =
	programming_language *pl =
		Languages::find_by_name(
			Bibliographic::get_datum(RS->current_web, I"Language"));
	RS->current_web->main_language = pl;
	Tangler::primary_target(RS->current_web)->tangle_language = pl;
	RS->in_biblio = FALSE;

@ The bibliographic data gives lines in any order specifying values of
variables with fixed names; a blank line ends the block.

@<Read the bibliographic data block at the top@> =
	if (RS->main_web_not_module) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, L"(%c+?): (%c+?) *")) {
			TEMPORARY_TEXT(key);
			Str::copy(key, mr.exp[0]);
			TEMPORARY_TEXT(value);
			Str::copy(value, mr.exp[1]);
			@<Set bibliographic key-value pair@>;
			DISCARD_TEXT(key);
			DISCARD_TEXT(value);
		} else {
			TEMPORARY_TEXT(err);
			WRITE_TO(err, "expected 'Setting: Value' but found '%S'", line);
			Errors::in_text_file_S(err, tfp);
			DISCARD_TEXT(err);
		}
		Regexp::dispose_of(&mr);
	}

@<Set bibliographic key-value pair@> =
	if (Bibliographic::datum_can_be_declared(RS->current_web, key)) {
		if (Bibliographic::datum_on_or_off(RS->current_web, key)) {
			if ((Str::ne_wide_string(value, L"On")) && (Str::ne_wide_string(value, L"Off"))) {
				TEMPORARY_TEXT(err);
				WRITE_TO(err, "this setting must be 'On' or 'Off': %S", key);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err);
				Str::clear(value);
				WRITE_TO(value, "Off");
			}
		}
		Bibliographic::set_datum(RS->current_web, key, value);
	} else {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "no such bibliographic datum: %S", key);
		Errors::in_text_file_S(err, tfp);
		DISCARD_TEXT(err);
	}

@ In the bulk of the contents, we find indented lines for sections and
unindented ones for chapters.

@<Read the roster of sections at the bottom@> =
	if (begins_with_white_space == FALSE) {
		if (Str::get_first_char(line) == '"') { RS->in_purpose = TRUE; Str::delete_first_character(line); }
		if (RS->in_purpose == TRUE) @<Record the purpose of the current chapter@>
		else @<Read about a new chapter@>;
	} else @<Read about, and read in, a new section@>;

@ After a declared chapter heading, subsequent lines form its purpose, until
we reach a closed quote: we then stop, but remove the quotation marks. Because
we like a spoonful of syntactic sugar on our porridge, that's why.

@<Record the purpose of the current chapter@> =
	if ((Str::len(line) > 0) && (Str::get_last_char(line) == '"')) {
		Str::truncate(line, Str::len(line)-1); RS->in_purpose = FALSE;
	}
	if (RS->chapter_being_scanned) {
		text_stream *r = RS->chapter_being_scanned->rubric;
		if (Str::len(r) > 0) WRITE_TO(r, " ");
		WRITE_TO(r, "%S", line);
	}

@ The title tells us everything we need to know about a chapter:

@<Read about a new chapter@> =
	TEMPORARY_TEXT(new_chapter_range); /* e.g., S, P, 1, 2, 3, A, B, ... */
	TEMPORARY_TEXT(pdf_leafname);
	tangle_target *ind_target = Tangler::primary_target(RS->current_web);
	programming_language *ind_language = RS->current_web->main_language;

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c*%C) %(Independent(%c*)%)")) {
		text_stream *title_alone = mr.exp[0];
		text_stream *language_name = mr.exp[1];
		@<Mark this chapter as an independent tangle target@>;
		Str::copy(line, title_alone);
	}
	int this_is_a_chapter = TRUE;
	Str::clear(RS->chapter_folder_name);
	if (Str::eq_wide_string(line, L"Sections")) {
		WRITE_TO(new_chapter_range, "S");
		WRITE_TO(RS->chapter_folder_name, "Sections");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(pdf_leafname, "Sections.pdf");
		RS->current_web->chaptered = FALSE;
	} else if (Str::eq_wide_string(line, L"Preliminaries")) {
		WRITE_TO(new_chapter_range, "P");
		WRITE_TO(RS->chapter_folder_name, "Preliminaries");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Preliminaries.pdf");
		RS->current_web->chaptered = TRUE;
	} else if (Str::eq_wide_string(line, L"Manual")) {
		WRITE_TO(new_chapter_range, "M");
		WRITE_TO(RS->chapter_folder_name, "Manual");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Manual.pdf");
		RS->current_web->chaptered = TRUE;
	} else if (Regexp::match(&mr, line, L"Header: (%c+)")) {
		pathname *P = RS->path_to;
		if (P == NULL) P = RS->current_web->path_to_web;
		P = Pathnames::subfolder(P, I"Headers");
		filename *HF = Filenames::in_folder(P, mr.exp[0]);
		Reader::add_imported_header(RS->current_web, HF);
		this_is_a_chapter = FALSE;
	} else if (Regexp::match(&mr, line, L"Import: (%c+)")) {
		if (RS->import_from) {
			pathname *imported = Modules::find(RS->current_web, RS->import_from, mr.exp[0]);
			if (imported == NULL) {
				TEMPORARY_TEXT(err);
				WRITE_TO(err, "unable to find module: %S", line);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err);
			} else {
				if (RS->parsing) {
					int save_syntax = RS->current_web->default_syntax;
					Reader::read_contents_page_from(RS->current_web, RS->import_from,
						RS->scan_verbosely, RS->parsing, imported);
					RS->current_web->default_syntax = save_syntax;
				}
			}
		}
		this_is_a_chapter = FALSE;
	} else if (Regexp::match(&mr, line, L"Chapter (%d+): %c+")) {
		int n = Str::atoi(mr.exp[0], 0);
		WRITE_TO(new_chapter_range, "%d", n);
		WRITE_TO(RS->chapter_folder_name, "Chapter %d", n);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Chapter-%d.pdf", n);
		RS->current_web->chaptered = TRUE;
	} else if (Regexp::match(&mr, line, L"Appendix (%c): %c+")) {
		text_stream *letter = mr.exp[0];
		Str::copy(new_chapter_range, letter);
		WRITE_TO(RS->chapter_folder_name, "Appendix %S", letter);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Appendix-%S.pdf", letter);
		RS->current_web->chaptered = TRUE;
	} else {
		TEMPORARY_TEXT(err);
		WRITE_TO(err, "segment not understood: %S", line);
		Errors::in_text_file_S(err, tfp);
		WRITE_TO(STDERR, "(Must be 'Chapter <number>: Title', "
			"'Appendix <letter A to O>: Title',\n");
		WRITE_TO(STDERR, "'Manual', 'Preliminaries' or 'Sections')\n");
		DISCARD_TEXT(err);
	}

	if (this_is_a_chapter) @<Create the new chapter with these details@>;
	DISCARD_TEXT(new_chapter_range);
	DISCARD_TEXT(pdf_leafname);
	Regexp::dispose_of(&mr);

@ A chapter whose title marks it as Independent becomes a new tangle target,
with the same language as the main web unless stated otherwise.

@<Mark this chapter as an independent tangle target@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, language_name, L" *"))
		language_name = Bibliographic::get_datum(RS->current_web, I"Language");
	else if (Regexp::match(&mr, language_name, L" *(%c*?) *"))
		language_name = mr.exp[0];
	ind_language = Languages::find_by_name(language_name);
	ind_target = Reader::add_tangle_target(RS->current_web, ind_language);
	Regexp::dispose_of(&mr);

@<Create the new chapter with these details@> =
	chapter *C = CREATE(chapter);
	C->ch_range = Str::duplicate(new_chapter_range);
	C->ch_title = Str::duplicate(line);
	C->rubric = Str::new();
	C->ch_target = ind_target;
	C->ch_weave = NULL;
	C->ch_language = ind_language;
	C->ch_extent = 0;
	C->titling_line_inserted = FALSE;
	C->owning_web = RS->current_web;
	C->sections = NEW_LINKED_LIST(section);
	C->imported = TRUE;
	if (RS->main_web_not_module) C->imported = FALSE;

	ADD_TO_LINKED_LIST(C, chapter, RS->current_web->chapters);
	C->owning_web->no_chapters++;
	RS->chapter_being_scanned = C;

@ That's enough on creating chapters. This is the more interesting business
of registering a new section within a chapter -- more interesting because
we also read in and process its file.

@<Read about, and read in, a new section@> =
	section *sect = CREATE(section);
	@<Initialise the section structure@>;
	@<Add the section to the web and the current chapter@>;
	@<Work out the language and tangle target for the section@>;

	if (sect->source_file_for_section == NULL)
		@<Work out the filename of this section file@>;
	if (RS->parsing)
		Reader::read_file(RS->current_web, sect->source_file_for_section,
			RS->titling_line_to_insert, sect, RS->scan_verbosely,
			(filename_of_single_file_web)?TRUE:FALSE);

@<Initialise the section structure@> =
	if (filename_of_single_file_web) {
		sect->source_file_for_section = filename_of_single_file_web;
		sect->paused_until_at = TRUE;
	} else {
		sect->source_file_for_section = NULL;
		sect->paused_until_at = FALSE;
	}
	sect->owning_chapter = NULL;

	sect->sect_extent = 0;
	sect->first_line = NULL; sect->last_line = NULL;
	sect->sect_paragraphs = 0;
	sect->paragraphs = NEW_LINKED_LIST(paragraph);
	sect->macros = NEW_LINKED_LIST(para_macro);

	sect->scratch_flag = FALSE;
	sect->erroneous_interface = FALSE;
	sect->barred = FALSE;
	sect->using_syntax = syntax;
	sect->is_a_singleton = FALSE;
	sect->printed_number = -1;
	sect->sect_weave = NULL;
	sect->sect_namespace = Str::new();

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c+) %^\"(%c+)\" *")) {
		sect->sect_title = Str::duplicate(mr.exp[0]);
		sect->tag_with = Tags::add_by_name(NULL, mr.exp[1]);
	} else {
		sect->sect_title = Str::duplicate(line);
		sect->tag_with = NULL;
	}
	Regexp::dispose_of(&mr);

@<Add the section to the web and the current chapter@> =
	chapter *C = RS->chapter_being_scanned;
	C->owning_web->no_sections++;
	sect->owning_chapter = C;
	ADD_TO_LINKED_LIST(sect, section, C->sections);

@ Just as for chapters, but a section which is an independent target with
language "Inform 6" is given the filename extension |.i6t| instead of |.w|.
This is to conform with the naming convention used within Inform, where
I6 template files -- Inweb files with language Inform 6 -- are given the
file extensions |.i6t|.

@<Work out the language and tangle target for the section@> =
	sect->sect_language = RS->chapter_being_scanned->ch_language; /* by default */
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c*%C) %(Independent (%c*) *%)")) {
		text_stream *title_alone = mr.exp[0];
		text_stream *language_name = mr.exp[1];
		@<Mark this section as an independent tangle target@>;
		Str::copy(sect->sect_title, title_alone);
	} else {
		sect->sect_target = RS->chapter_being_scanned->ch_target;
	}
	Regexp::dispose_of(&mr);

@<Mark this section as an independent tangle target@> =
	text_stream *p = language_name;
	if (Str::len(p) == 0) p = Bibliographic::get_datum(RS->current_web, I"Language");
	programming_language *pl = Languages::find_by_name(p);
	sect->sect_language = pl;
	sect->sect_target = Reader::add_tangle_target(RS->current_web, pl);

@ If we're told that a section is called "Bells and Whistles", what filename
is it stored in? Firstly, the leafname is normally |Bells and Whistles.w|,
but the extension used doesn't have to be |.w|: for Inform 6 template files,
the extension needs to be |.i6t|, and a contents line like

	|Relations Template.i6t|

translates into the leafname |Relations.i6t|, not |Relations Template.w|.
I6T files are also automatically set to Inweb syntax 1, for backwards
compatibility purposes.

@<Work out the filename of this section file@> =
	TEMPORARY_TEXT(leafname_to_use);
	WRITE_TO(leafname_to_use,
		"%S%S", sect->sect_title, sect->sect_language->source_file_extension);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, leafname_to_use, L"(%c*?) Template.i6t(%c*)")) {
		Str::clear(leafname_to_use);
		WRITE_TO(leafname_to_use, "%S.i6t%S", mr.exp[0], mr.exp[1]);
	}
	Regexp::dispose_of(&mr);
	pathname *P = RS->path_to;
	if (P == NULL) P = RS->current_web->path_to_web;
	if (Str::len(RS->chapter_folder_name) > 0)
		P = Pathnames::subfolder(P, RS->chapter_folder_name);
	sect->source_file_for_section = Filenames::in_folder(P, leafname_to_use);
	TEMPORARY_TEXT(ext);
	Filenames::write_extension(ext, sect->source_file_for_section);
	DISCARD_TEXT(ext);
	DISCARD_TEXT(leafname_to_use);

@h Reading source files.

=
void Reader::read_file(web *W, filename *OUT, text_stream *titling_line, section *sect,
	int verbosely, int disregard_top) {
	section *current_section = sect;

	if ((titling_line) && (Str::len(titling_line) > 0) &&
		(sect->owning_chapter->titling_line_inserted == FALSE))
		@<Insert an implied chapter heading@>;
	
	if (disregard_top)
		@<Insert an implied section heading, for a single-file web@>;

	int cl = TextFiles::read(OUT, FALSE, "can't open section file", TRUE,
		Reader::scan_source_line, NULL, (void *) current_section);
	if (verbosely)
		PRINT("Read section: '%S' (%d lines)\n", sect->sect_title, cl);
}

@<Insert an implied chapter heading@> =
	sect->owning_chapter->titling_line_inserted = TRUE;
	TEMPORARY_TEXT(line);
	text_file_position *tfp = NULL;
	WRITE_TO(line, "Chapter Heading");
	@<Accept this as a line belonging to this section and chapter@>;
	DISCARD_TEXT(line);

@<Insert an implied section heading, for a single-file web@> =
	TEMPORARY_TEXT(line);
	text_file_position *tfp = NULL;
	WRITE_TO(line, "Main.");
	@<Accept this as a line belonging to this section and chapter@>;
	Str::clear(line);
	@<Accept this as a line belonging to this section and chapter@>;
	DISCARD_TEXT(line);

@ Non-implied source lines come from here. Note that we assume here that
trailing whitespace on a line is not significant in the language being
tangled for.

=
void Reader::scan_source_line(text_stream *line, text_file_position *tfp, void *state) {
	section *current_section = (section *) state;
	int l = Str::len(line) - 1;
	while ((l>=0) && (Characters::is_space_or_tab(Str::get_at(line, l)))) Str::truncate(line, l--);

	if (current_section->paused_until_at) {
		if (Str::get_at(line, 0) == '@') current_section->paused_until_at = FALSE;
		else return;
	}
	@<Accept this as a line belonging to this section and chapter@>;
}

@<Accept this as a line belonging to this section and chapter@> =
	source_line *sl = Lines::new_source_line(line, tfp);

	/* enter this in its section's linked list of lines: */
	sl->owning_section = current_section;
	if (current_section->first_line == NULL) current_section->first_line = sl;
	else current_section->last_line->next_line = sl;
	current_section->last_line = sl;

	/* we haven't detected paragraph boundaries yet, so: */
	sl->owning_paragraph = NULL;

	/* and keep count: */
	sl->owning_section->sect_extent++;
	sl->owning_section->owning_chapter->ch_extent++;
	sl->owning_section->owning_chapter->owning_web->no_lines++;

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
			if (Str::eq(C->ch_range, range))
				return C;
	return NULL;
}

section *Reader::get_section_for_range(web *W, text_stream *range) {
	chapter *C;
	section *S;
	if (W)
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S, section, C->sections)
				if (Str::eq(S->range, range))
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
				TEMPORARY_TEXT(SFN);
				WRITE_TO(SFN, "%f", S->source_file_for_section);
				int rv = Str::eq(SFN, filename);
				DISCARD_TEXT(SFN);
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
	if (Str::eq_wide_string(range2, L"0")) return TRUE;
	if (Str::eq(range1, range2)) return TRUE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, range2, L"%c+/%c+")) { Regexp::dispose_of(&mr); return FALSE; }
	if (Regexp::match(&mr, range1, L"(%c+)/%c+")) {
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
	MEMORY_MANAGEMENT
} tangle_target;

@ =
tangle_target *Reader::add_tangle_target(web *W, programming_language *language) {
	tangle_target *tt = CREATE(tangle_target);
	tt->tangle_language = language;
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
