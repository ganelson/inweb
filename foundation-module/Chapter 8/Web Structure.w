[WebMetadata::] Web Structure.

To read the structure of a literate programming web from a path in the file
system.

@h Introduction.
Webs are literate programs for the Inweb LP system. A single web consists of
a number of chapters (though sometimes just one, called "Sections"), each
of which consists of a number of sections. A web can represent a stand-alone
program, or a library to be used in multiple programs, in which case it is
called a "module".

Inweb syntax has gradually shifted over the years, but there are two main
versions: the second was cleaned up and simplified from the first in 2019.

@e V1_SYNTAX from 1
@e V2_SYNTAX

@h Web MD.
No relation to the website of the same name: MD here stands for metadata.
Our task in this section will be to read a web from the filing system and
produce the following metadata structure.

Each web produces a single instance of |web_md|:

=
typedef struct web_md {
	struct pathname *path_to_web; /* relative to the current working directory */
	struct filename *single_file; /* relative to the current working directory */
	struct linked_list *bibliographic_data; /* of |web_bibliographic_datum| */
	struct semantic_version_number version_number; /* as deduced from bibliographic data */
	int default_syntax; /* which version syntax the sections will have */
	int chaptered; /* has the author explicitly divided it into named chapters? */
	struct text_stream *main_language_name; /* in which most of the sections are written */

	struct module *as_module; /* the root of a small dependency graph */

	struct filename *contents_filename; /* or |NULL| for a single-file web */
	struct linked_list *tangle_target_names; /* of |text_stream| */
	struct linked_list *header_filenames; /* of |filename| */

	struct linked_list *chapters_md; /* of |chapter_md| */
	struct linked_list *sections_md; /* of |section_md| */
	MEMORY_MANAGEMENT
} web_md;

@ The |chapters_md| list in a |web_md| contains these as its entries:

=
typedef struct chapter_md {
	struct text_stream *ch_range; /* e.g., |P| for Preliminaries, |7| for Chapter 7, |C| for Appendix C */
	struct text_stream *ch_title; /* e.g., "Chapter 3: Fresh Water Fish" */
	struct text_stream *rubric; /* optional; without double-quotation marks */

	struct text_stream *ch_language_name; /* in which most of the sections are written */

	int imported; /* from a different web? */

	struct linked_list *sections_md; /* of |section_md| */
	MEMORY_MANAGEMENT
} chapter_md;

@ And the |sections_md| list in a |chapter_md| contains these as its entries:

=
typedef struct section_md {
	struct text_stream *sect_title; /* e.g., "Program Control" */
	int using_syntax; /* which syntax the web is written in */
	int is_a_singleton; /* is this the only section in its entire web? */

	struct filename *source_file_for_section;

	struct text_stream *tag_name;
	struct text_stream *sect_independent_language;
	struct text_stream *sect_language_name;
	struct text_stream *titling_line_to_insert;
	MEMORY_MANAGEMENT
} section_md;

@h Reading from the file system.
Webs can be stored in two ways: as a directory containing a multitude of files,
in which case the pathname |P| is supplied; or as a single file with everything
in one (and thus, implicitly, a single chapter and a single section), in which
case a filename |alt_F| is supplied.

=
web_md *WebMetadata::get_without_modules(pathname *P, filename *alt_F) {
	return WebMetadata::get(P, alt_F, V2_SYNTAX, NULL, FALSE, FALSE, NULL);
}

web_md *WebMetadata::get(pathname *P, filename *alt_F, int syntax_version,
	module_search *I, int verbosely, int including_modules, pathname *path_to_inweb) {
	if ((including_modules) && (I == NULL)) I = WebModules::make_search_path(NULL);
	web_md *Wm = CREATE(web_md);
	@<Begin the bibliographic data@>;
	@<Initialise the rest of the web MD@>;
	WebMetadata::read_contents_page(Wm, Wm->as_module, I, verbosely,
		including_modules, NULL, path_to_inweb);
	@<Consolidate the bibliographic data@>;
	return Wm;
}

@<Begin the bibliographic data@> =
	Wm->bibliographic_data = NEW_LINKED_LIST(web_bibliographic_datum);
	Bibliographic::initialise_data(Wm);

@<Initialise the rest of the web MD@> =
	if (P) {
		Wm->path_to_web = P;
		Wm->single_file = NULL;
		Wm->contents_filename = WebMetadata::contents_filename(P);
	} else {
		Wm->path_to_web = Filenames::get_path_to(alt_F);
		Wm->single_file = alt_F;
		Wm->contents_filename = NULL;
	}
	Wm->version_number = VersionNumbers::null();
	Wm->default_syntax = syntax_version;
	Wm->chaptered = FALSE;
	Wm->sections_md = NEW_LINKED_LIST(sections_md);
	Wm->chapters_md = NEW_LINKED_LIST(chapter_md);
	Wm->tangle_target_names = NEW_LINKED_LIST(text_stream);
	Wm->main_language_name = Str::new();
	Wm->header_filenames = NEW_LINKED_LIST(filename);
	Wm->as_module = WebModules::create_main_module(Wm);

@<Consolidate the bibliographic data@> =
	Bibliographic::check_required_data(Wm);
	BuildFiles::set_bibliographic_data_for(Wm);
	BuildFiles::deduce_semver(Wm);

@h Reading the contents page.
Making the web begins by reading the contents section, which really isn't a
section at all (and perhaps we shouldn't pretend that it is by the use of the
|.w| file extension, but we probably want it to have the same file extension,
and its syntax is chosen so that syntax-colouring for regular sections doesn't
make it look odd). When the word "section" is used in the Inweb code, it
almost always means "section other than the contents".

Because a contents page can, by importing a module, cause a further contents
page to be read, we set this up as a recursion.

We then run through an individual contents page line by line, using the
following slate of variables to keep track of where we are.

With a single-file web, the "contents section" doesn't exist as a file in its
own right: instead, it's the top few lines of the single file. We handle that
by halting at the junction point.

=
typedef struct reader_state {
	struct web_md *Wm;
	struct filename *contents_filename;
	int in_biblio;
	int in_purpose; /* Reading the bit just after the new chapter? */
	struct chapter_md *chapter_being_scanned;
	struct text_stream *chapter_folder_name; /* Where sections in the current chapter live */
	struct text_stream *titling_line_to_insert; /* To be inserted automagically */
	struct pathname *path_to; /* Where web material is being read from */
	struct module *reading_from;
	struct module_search *import_from; /* Where imported webs are */
	struct pathname *path_to_inweb;
	int scan_verbosely;
	int including_modules;
	int main_web_not_module; /* Reading the original web, or an included one? */
	int halt_at_at; /* Used for reading contents pages of single-file webs */
	int halted; /* Set when such a halt has occurred */
	int section_count;
	struct section_md *last_section;
} reader_state;

void WebMetadata::read_contents_page(web_md *Wm, module *of_module,
	module_search *import_path, int verbosely,
	int including_modules, pathname *path, pathname *X) {
	reader_state RS;
	@<Initialise the reader state@>;

	int cl = TextFiles::read(RS.contents_filename, FALSE, "can't open contents file",
		TRUE, WebMetadata::read_contents_line, NULL, &RS);
	if (verbosely) {
		if (Wm->single_file) {
			PRINT("Read %d lines of contents part at top of file\n", cl);
		} else {
			PRINT("Read contents section (%d lines)\n", cl);
		}
	}
	if (RS.section_count == 1) RS.last_section->is_a_singleton = TRUE;
}

@<Initialise the reader state@> =
	RS.Wm = Wm;
	RS.reading_from = of_module;
	RS.in_biblio = TRUE;
	RS.in_purpose = FALSE;
	RS.chapter_being_scanned = NULL;
	RS.chapter_folder_name = Str::new();
	RS.titling_line_to_insert = Str::new();
	RS.scan_verbosely = verbosely;
	RS.including_modules = including_modules;
	RS.path_to = path;
	RS.import_from = import_path;
	RS.halted = FALSE;
	RS.path_to_inweb = X;

	if (path == NULL) {
		path = Wm->path_to_web;
		RS.main_web_not_module = TRUE;
	} else {
		RS.main_web_not_module = FALSE;
	}

	if (Wm->single_file) {
		RS.contents_filename = Wm->single_file;
		RS.halt_at_at = TRUE;
	} else {
		RS.contents_filename = WebMetadata::contents_filename(path);
		RS.halt_at_at = FALSE;
	}
	RS.section_count = 0;
	RS.last_section = NULL;

@ The contents section has a syntax quite different from all other sections,
and sets out bibliographic information about the web, the sections and their
organisation, and so on.

=
void WebMetadata::read_contents_line(text_stream *line, text_file_position *tfp, void *X) {
	reader_state *RS = (reader_state *) X;
	if (RS->halted) return;

	int begins_with_white_space = FALSE;
	if (Characters::is_whitespace(Str::get_first_char(line)))
		begins_with_white_space = TRUE;
	Str::trim_white_space(line);
	
	@<Act immediately if the web syntax version is changed@>;
	int syntax = RS->Wm->default_syntax;

	filename *filename_of_single_file_web = NULL;
	if ((RS->halt_at_at) && (Str::get_at(line, 0) == '@'))
		@<Halt at this point in the single file, and make the rest of it a one-chapter section@>;

	@<Read regular contents material@>;
}

@ Since the web syntax version affects how the rest of the file is read, it's
no good simply to store this up for later: we have to change the web structure
immediately.

@<Act immediately if the web syntax version is changed@> =
	if (Str::eq(line, I"Web Syntax Version: 1"))
		RS->Wm->default_syntax = V1_SYNTAX;
	else if (Str::eq(line, I"Web Syntax Version: 2"))
		RS->Wm->default_syntax = V2_SYNTAX;

@ Suppose we're reading a single-file web, and we hit the first |@| marker.
The contents part has now ended, so we should halt scanning. But we also need
to give the web a single chapter ("Sections", range "S"), which contains a
single section ("All") consisting of the remainder of the single file.

@<Halt at this point in the single file, and make the rest of it a one-chapter section@> =
	RS->halted = TRUE;
	text_stream *new_chapter_range = I"S";
	text_stream *language_name = NULL;
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
contents page, and are soon going to read in the sections.

@<End bibliographic data here, at the blank line@> =
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
	if (Bibliographic::datum_can_be_declared(RS->Wm, key)) {
		if (Bibliographic::datum_on_or_off(RS->Wm, key)) {
			if ((Str::ne_wide_string(value, L"On")) && (Str::ne_wide_string(value, L"Off"))) {
				TEMPORARY_TEXT(err);
				WRITE_TO(err, "this setting must be 'On' or 'Off': %S", key);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err);
				Str::clear(value);
				WRITE_TO(value, "Off");
			}
		}
		Bibliographic::set_datum(RS->Wm, key, value);
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
		if (Str::get_first_char(line) == '"') {
			RS->in_purpose = TRUE; Str::delete_first_character(line);
		}
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
	text_stream *language_name = NULL;

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c*%C) %(Independent(%c*)%)")) {
		text_stream *title_alone = mr.exp[0];
		language_name = mr.exp[1];
		@<Mark this chapter as an independent tangle target@>;
		Str::copy(line, title_alone);
	}
	int this_is_a_chapter = TRUE;
	Str::clear(RS->chapter_folder_name);
	if (Str::eq_wide_string(line, L"Sections")) {
		WRITE_TO(new_chapter_range, "S");
		WRITE_TO(RS->chapter_folder_name, "Sections");
		WRITE_TO(pdf_leafname, "Sections.pdf");
		RS->Wm->chaptered = FALSE;
		Str::clear(RS->titling_line_to_insert);
	} else if (Str::eq_wide_string(line, L"Preliminaries")) {
		WRITE_TO(new_chapter_range, "P");
		WRITE_TO(RS->chapter_folder_name, "Preliminaries");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Preliminaries.pdf");
		RS->Wm->chaptered = TRUE;
	} else if (Str::eq_wide_string(line, L"Manual")) {
		WRITE_TO(new_chapter_range, "M");
		WRITE_TO(RS->chapter_folder_name, "Manual");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Manual.pdf");
		RS->Wm->chaptered = TRUE;
	} else if (Regexp::match(&mr, line, L"Header: (%c+)")) {
		pathname *P = RS->path_to;
		if (P == NULL) P = RS->Wm->path_to_web;
		P = Pathnames::subfolder(P, I"Headers");
		filename *HF = Filenames::in_folder(P, mr.exp[0]);
		ADD_TO_LINKED_LIST(HF, filename, RS->Wm->header_filenames);
		this_is_a_chapter = FALSE;
	} else if (Regexp::match(&mr, line, L"Import: (%c+)")) {
		if (RS->import_from) {
			module *imported =
				WebModules::find(RS->Wm, RS->import_from, mr.exp[0], RS->path_to_inweb);
			if (imported == NULL) {
				TEMPORARY_TEXT(err);
				WRITE_TO(err, "unable to find module: %S", line);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err);
			} else {
				if (RS->including_modules) {
					int save_syntax = RS->Wm->default_syntax;
					WebMetadata::read_contents_page(RS->Wm, imported, RS->import_from,
						RS->scan_verbosely, RS->including_modules,
						imported->module_location, RS->path_to_inweb);
					RS->Wm->default_syntax = save_syntax;
				}
			}
		}
		this_is_a_chapter = FALSE;
	} else if (Regexp::match(&mr, line, L"Chapter (%d+): %c+")) {
		int n = Str::atoi(mr.exp[0], 0);
		WRITE_TO(new_chapter_range, "%d", n);
		WRITE_TO(RS->chapter_folder_name, "Chapter %d", n);
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Chapter-%d.pdf", n);
		RS->Wm->chaptered = TRUE;
	} else if (Regexp::match(&mr, line, L"Appendix (%c): %c+")) {
		text_stream *letter = mr.exp[0];
		Str::copy(new_chapter_range, letter);
		WRITE_TO(RS->chapter_folder_name, "Appendix %S", letter);
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Appendix-%S.pdf", letter);
		RS->Wm->chaptered = TRUE;
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
		language_name = Bibliographic::get_datum(RS->Wm, I"Language");
	else if (Regexp::match(&mr, language_name, L" *(%c*?) *"))
		language_name = mr.exp[0];
	Regexp::dispose_of(&mr);

@<Create the new chapter with these details@> =
	chapter_md *Cm = CREATE(chapter_md);
	Cm->ch_range = Str::duplicate(new_chapter_range);
	Cm->ch_title = Str::duplicate(line);
	Cm->rubric = Str::new();
	Cm->ch_language_name = language_name;
	Cm->imported = TRUE;
	Cm->sections_md = NEW_LINKED_LIST(section_md);
	if (RS->main_web_not_module) Cm->imported = FALSE;

	ADD_TO_LINKED_LIST(Cm, chapter_md, RS->Wm->chapters_md);
	RS->chapter_being_scanned = Cm;

@ That's enough on creating chapters. This is the more interesting business
of registering a new section within a chapter -- more interesting because
we also read in and process its file.

@<Read about, and read in, a new section@> =
	section_md *Sm = CREATE(section_md);
	Sm = CREATE(section_md);
	@<Initialise the section structure@>;
	@<Add the section to the web and the current chapter@>;
	@<Work out the language and tangle target for the section@>;

	if (Sm->source_file_for_section == NULL)
		@<Work out the filename of this section file@>;

@<Initialise the section structure@> =
	Sm->source_file_for_section = filename_of_single_file_web;
	Sm->using_syntax = syntax;
	Sm->is_a_singleton = FALSE;
	Sm->titling_line_to_insert = Str::duplicate(RS->titling_line_to_insert);
	Str::clear(RS->titling_line_to_insert);

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c+) %^\"(%c+)\" *")) {
		Sm->sect_title = Str::duplicate(mr.exp[0]);
		Sm->tag_name = Str::duplicate(mr.exp[1]);
	} else {
		Sm->sect_title = Str::duplicate(line);
		Sm->tag_name = NULL;
	}
	Regexp::dispose_of(&mr);

@<Add the section to the web and the current chapter@> =
	chapter_md *Cm = RS->chapter_being_scanned;
	RS->section_count++;
	RS->last_section = Sm;
	ADD_TO_LINKED_LIST(Sm, section_md, Cm->sections_md);
	ADD_TO_LINKED_LIST(Sm, section_md, RS->Wm->sections_md);
	ADD_TO_LINKED_LIST(Sm, section_md, RS->reading_from->sections_md);

@<Work out the language and tangle target for the section@> =
	Sm->sect_language_name = RS->chapter_being_scanned->ch_language_name; /* by default */
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L"(%c*%C) %(Independent (%c*) *%)")) {
		text_stream *title_alone = mr.exp[0];
		text_stream *language_name = mr.exp[1];
		@<Mark this section as an independent tangle target@>;
		Str::copy(Sm->sect_title, title_alone);
	}
	Regexp::dispose_of(&mr);

@<Mark this section as an independent tangle target@> =
	text_stream *p = language_name;
	if (Str::len(p) == 0) p = Bibliographic::get_datum(RS->Wm, I"Language");
	Sm->sect_independent_language = Str::duplicate(p);

@ If we're told that a section is called "Bells and Whistles", what filename
is it stored in? Firstly, the leafname is normally |Bells and Whistles.w|,
but the extension used doesn't have to be |.w|: for Inform 6 template files,
the extension needs to be |.i6t|. We allow either.

@<Work out the filename of this section file@> =
	TEMPORARY_TEXT(leafname_to_use);
	WRITE_TO(leafname_to_use, "%S.i6t", Sm->sect_title);
	pathname *P = RS->path_to;
	if (P == NULL) P = RS->Wm->path_to_web;
	if (Str::len(RS->chapter_folder_name) > 0)
		P = Pathnames::subfolder(P, RS->chapter_folder_name);
	Sm->source_file_for_section = Filenames::in_folder(P, leafname_to_use);
	if (TextFiles::exists(Sm->source_file_for_section) == FALSE) {
		Str::clear(leafname_to_use);
		WRITE_TO(leafname_to_use, "%S.w", Sm->sect_title);
		Sm->source_file_for_section = Filenames::in_folder(P, leafname_to_use);
	}
	DISCARD_TEXT(leafname_to_use);

@h Relative pathnames or filenames.

=
int WebMetadata::directory_looks_like_a_web(pathname *P) {
	return TextFiles::exists(WebMetadata::contents_filename(P));
}

filename *WebMetadata::contents_filename(pathname *P) {
	return Filenames::in_folder(P, I"Contents.w");
}

@h Statistics.

=
int WebMetadata::chapter_count(web_md *Wm) {
	int n = 0;
	chapter_md *Cm;
	LOOP_OVER_LINKED_LIST(Cm, chapter_md, Wm->chapters_md) n++;
	return n;
}
int WebMetadata::section_count(web_md *Wm) {
	int n = 0;
	chapter_md *Cm;
	LOOP_OVER_LINKED_LIST(Cm, chapter_md, Wm->chapters_md) {
		section_md *Sm;
		LOOP_OVER_LINKED_LIST(Sm, section_md, Cm->sections_md) n++;
	}
	return n;
}
