[WebContents::] Web Contents Pages.

To read the structure of a literate programming web from a path in the file
system.

@ Not all webs have contents pages: if a web sits in a single file, then it
doesn't need one. But if it does have a contents page, then this code reads
that page in, and puts the chapter/section structure in place from it. This
is done without reading in those section files, and is a rapid process.

Because a contents page can, by importing a module, cause a further contents
page to be read, we need to remember that |WebContents::read_contents_page|
can recurse.

=
void WebContents::read_contents_page(ls_web *W, ls_module *of_module,
	module_search *import_path, int including_modules, pathname *path) {
	wcl_declaration *D = W->declaration;
	if (of_module != W->main_module) {
		filename *F = WebModules::contents_filename(of_module);
		D = WCL::read_for_type_only(F, WEB_WCLTYPE);
		if (WCL::count_errors(D) > 0) return;
		if (D->declaration_type != WEB_WCLTYPE) {
			text_file_position tfp = TextFiles::at(F, 1);
			WCL::error(D, &tfp, I"this seems not to be a contents page despite its name");
		}
		if (WCL::count_errors(D) > 0) { WCL::report_errors(D); return; }
	}
	web_contents_state RS;
	@<Initialise the reader state@>;
	if (W->web_syntax == NULL) W->web_syntax = WebSyntax::default();
	else RS.syntax_externally_set = TRUE;

	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		WebContents::read_contents_line(line, &tfp, (void *) &RS);
		DISCARD_TEXT(line);
		tfp.line_count++;
		RS.relative_line_count++;
	}
	if (WCL::count_errors(D) > 0) { WCL::report_errors(D); return; }
}

@ This rather heavy slate of variables is kept track of while we read the
contents page in, line by line:

=
typedef struct web_contents_state {
	struct ls_web *W;
	int relative_line_count;
	int in_biblio;
	int in_purpose; /* Reading the bit just after the new chapter? */
	struct ls_chapter *chapter_being_scanned;
	struct text_stream *chapter_dir_name; /* Where sections in the current chapter live */
	struct text_stream *titling_line_to_insert; /* To be inserted automagically */
	struct pathname *path_to; /* Where web material is being read from */
	struct ls_module *reading_from;
	struct module_search *import_from; /* Where imported webs are */
	int syntax_externally_set;
	int including_modules;
	int main_web_not_module; /* Reading the original web, or an included one? */
	int section_count;
	struct ls_section *last_section;
	int allow_kvps;
	int extension_form;
	int purpose_mode;
	struct text_stream *purpose;
} web_contents_state;

@<Initialise the reader state@> =
	RS.W = W;
	RS.relative_line_count = 1;
	RS.reading_from = of_module;
	RS.in_biblio = TRUE;
	RS.in_purpose = FALSE;
	RS.chapter_being_scanned = NULL;
	RS.chapter_dir_name = Str::new();
	RS.titling_line_to_insert = Str::new();
	RS.including_modules = including_modules;
	RS.path_to = path;
	RS.import_from = import_path;
	RS.syntax_externally_set = FALSE;
	if (path == NULL) {
		path = W->path_to_web;
		RS.main_web_not_module = TRUE;
	} else {
		RS.main_web_not_module = FALSE;
	}
	RS.section_count = 0;
	RS.last_section = NULL;
	RS.allow_kvps = TRUE;
	RS.extension_form = FALSE;
	RS.purpose_mode = FALSE;
	RS.purpose = NULL;

@ And so the following is called on each line in turn:

=
void WebContents::read_contents_line(text_stream *line, text_file_position *tfp, void *X) {
	web_contents_state *RS = (web_contents_state *) X;
	
	if (RS->relative_line_count == 1) {
		match_results mr = Regexp::create_mr();
		if ((Regexp::match(&mr, line, U"Version (%C+) of the (%c+) by (%c+).* *")) ||
			(Regexp::match(&mr, line, U"Version (%C+) of (%c+) by (%c+).* *"))) {
			Bibliographic::set_datum(RS->W, I"Version", mr.exp[0]);
			Bibliographic::set_datum(RS->W, I"Title", mr.exp[1]);
			Bibliographic::set_datum(RS->W, I"Author", mr.exp[2]);
			RS->extension_form = TRUE;
			Regexp::dispose_of(&mr);
			return;
		}
		if ((Regexp::match(&mr, line, U"The (%c+) by (%c+).* *")) ||
			(Regexp::match(&mr, line, U"(%c+) by (%c+).* *"))) {
			Bibliographic::set_datum(RS->W, I"Title", mr.exp[0]);
			Bibliographic::set_datum(RS->W, I"Author", mr.exp[1]);
			RS->extension_form = TRUE;
			Regexp::dispose_of(&mr);
			return;
		}
		Regexp::dispose_of(&mr);
	} else if (RS->extension_form) {
		match_results mr = Regexp::create_mr();
		if ((RS->purpose_mode == FALSE) && (Regexp::match(&mr, line, U" *\"(%c*)"))) {
			RS->purpose_mode = TRUE;
			RS->purpose = Str::new();
		}
		Regexp::dispose_of(&mr);
		if (RS->purpose_mode == TRUE) {
			if (Str::len(RS->purpose) > 0) WRITE_TO(RS->purpose, " ");
			WRITE_TO(RS->purpose, "%S", line);
			Str::trim_white_space(RS->purpose);
			if (Str::get_last_char(RS->purpose) == '"') {
				RS->purpose_mode = NOT_APPLICABLE;
				Str::delete_first_character(RS->purpose);
				Str::delete_last_character(RS->purpose);
				Bibliographic::set_datum(RS->W, I"Purpose", RS->purpose);
			}
			return;
		}
	}
	
	if ((RS->syntax_externally_set == FALSE) ||
		(WebSyntax::supports(RS->W->web_syntax, SYNTAX_REDECLARATION_WSF)))
		@<Act immediately if the web syntax version is changed@>;
	
	int begins_with_white_space = Characters::is_whitespace(Str::get_first_char(line));
	Str::trim_white_space(line);
	
	@<Read regular contents material@>;
}

@ Since the web syntax version may affect how the rest of the file is read, we
want to react to an open declaration of that syntax immediately.

@<Act immediately if the web syntax version is changed@> =
	match_results mr = Regexp::create_mr();
	if ((RS->allow_kvps) &&
		(Regexp::match(&mr, line, U"Web Syntax Version: (%c+) *"))) {
		ls_syntax *S = WebSyntax::syntax_by_name(RS->W, mr.exp[0]);
		if (S) RS->W->web_syntax = S;
	}
	Regexp::dispose_of(&mr);

@ In syntaxes supporting key-value pairs at the top of the contents page, this
will be a series of bibliographic data values; then there's a blank line, and
then we're into the section listing. Otherwise, we're already in the sections.

@<Read regular contents material@> =
	if (RS->in_biblio) {
		if ((RS->allow_kvps == FALSE) ||
			(Bibliographic::parse_kvp(RS->W, line, RS->main_web_not_module, tfp, NULL) == FALSE))
			RS->in_biblio = FALSE;
	}
	if ((RS->in_biblio == FALSE) && (Str::is_whitespace(line) == FALSE))
		@<Read the roster of sections at the bottom@>;

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
	TEMPORARY_TEXT(new_chapter_range) /* e.g., S, P, 1, 2, 3, A, B, ... */
	TEMPORARY_TEXT(pdf_leafname)
	text_stream *language_name = NULL;

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%c*%C) %(Independent(%c*)%)")) {
		text_stream *title_alone = mr.exp[0];
		language_name = mr.exp[1];
		@<Mark this chapter as an independent tangle target@>;
		Str::copy(line, title_alone);
	}
	int this_is_a_chapter = TRUE;
	Str::clear(RS->chapter_dir_name);
	if (Str::eq_wide_string(line, U"Sections")) {
		WRITE_TO(new_chapter_range, "S");
		WRITE_TO(RS->chapter_dir_name, "Sections");
		WRITE_TO(pdf_leafname, "Sections.pdf");
		RS->W->chaptered = FALSE;
		Str::clear(RS->titling_line_to_insert);
	} else if (Str::eq_wide_string(line, U"Preliminaries")) {
		WRITE_TO(new_chapter_range, "P");
		WRITE_TO(RS->chapter_dir_name, "Preliminaries");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Preliminaries.pdf");
		RS->W->chaptered = TRUE;
	} else if (Str::eq_wide_string(line, U"Manual")) {
		WRITE_TO(new_chapter_range, "M");
		WRITE_TO(RS->chapter_dir_name, "Manual");
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Manual.pdf");
		RS->W->chaptered = TRUE;
	} else if (Regexp::match(&mr, line, U"Header: (%c+)")) {
		pathname *P = RS->path_to;
		if (P == NULL) P = RS->W->path_to_web;
		P = Pathnames::down(P, I"Headers");
		filename *HF = Filenames::in(P, mr.exp[0]);
		ADD_TO_LINKED_LIST(HF, filename, RS->W->header_filenames);
		this_is_a_chapter = FALSE;
	} else if (Regexp::match(&mr, line, U"Import: (%c+)")) {
		if (RS->import_from) {
			ls_module *imported =
				WebModules::find(RS->W, RS->import_from, mr.exp[0]);
			if (imported == NULL) {
				TEMPORARY_TEXT(err)
				WRITE_TO(err, "unable to find module '%S'", mr.exp[0]);
				Errors::in_text_file_S(err, tfp);
				DISCARD_TEXT(err)
			} else {
				if (RS->including_modules) {
					ls_syntax *save_syntax = RS->W->web_syntax;
					WebContents::read_contents_page(RS->W, imported, RS->import_from,
						RS->including_modules, imported->module_location);
					RS->W->web_syntax = save_syntax;
				}
			}
		}
		this_is_a_chapter = FALSE;
	} else if (Regexp::match(&mr, line, U"Chapter (%d+): %c+")) {
		int n = Str::atoi(mr.exp[0], 0);
		WRITE_TO(new_chapter_range, "%d", n);
		WRITE_TO(RS->chapter_dir_name, "Chapter %d", n);
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Chapter-%d.pdf", n);
		RS->W->chaptered = TRUE;
	} else if (Regexp::match(&mr, line, U"Appendix (%c): %c+")) {
		text_stream *letter = mr.exp[0];
		Str::copy(new_chapter_range, letter);
		WRITE_TO(RS->chapter_dir_name, "Appendix %S", letter);
		Str::clear(RS->titling_line_to_insert);
		WRITE_TO(RS->titling_line_to_insert, "%S.", line);
		WRITE_TO(pdf_leafname, "Appendix-%S.pdf", letter);
		RS->W->chaptered = TRUE;
	} else {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "segment not understood: %S", line);
		Errors::in_text_file_S(err, tfp);
		WRITE_TO(STDERR, "(Must be 'Chapter <number>: Title', "
			"'Appendix <letter A to O>: Title',\n");
		WRITE_TO(STDERR, "'Manual', 'Preliminaries' or 'Sections')\n");
		DISCARD_TEXT(err)
	}

	if (this_is_a_chapter) @<Create the new chapter with these details@>;
	DISCARD_TEXT(new_chapter_range)
	DISCARD_TEXT(pdf_leafname)
	Regexp::dispose_of(&mr);

@ A chapter whose title marks it as Independent becomes a new tangle target,
with the same language as the main web unless stated otherwise.

@<Mark this chapter as an independent tangle target@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, language_name, U" *"))
		language_name = Bibliographic::get_datum(RS->W, I"Language");
	else if (Regexp::match(&mr, language_name, U" *(%c*?) *"))
		language_name = mr.exp[0];
	Regexp::dispose_of(&mr);

@<Create the new chapter with these details@> =
	ls_chapter *C = WebStructure::new_ls_chapter(RS->W, new_chapter_range, line);
	if (RS->main_web_not_module == FALSE) C->imported = TRUE;
	C->ch_language_name = language_name;
	WebModules::add_chapter(RS->reading_from, C);
	RS->chapter_being_scanned = C;

@ That's enough on creating chapters: now for the sections it contains.

@<Read about, and read in, a new section@> =
	ls_section *S = WebStructure::new_ls_section(RS->chapter_being_scanned, line);
	S->titling_line_to_insert = Str::duplicate(RS->titling_line_to_insert);
	Str::clear(RS->titling_line_to_insert);
	RS->section_count++;
	RS->last_section = S;
	@<Work out the language and tangle target for the section@>;
	if (S->source_file_for_section == NULL)
		@<Work out the filename of this section file@>;

@<Work out the language and tangle target for the section@> =
	S->sect_language_name = RS->chapter_being_scanned->ch_language_name; /* by default */
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%c*%C) %(Independent (%c*) *%)")) {
		text_stream *title_alone = mr.exp[0];
		text_stream *language_name = mr.exp[1];
		@<Mark this section as an independent tangle target@>;
		Str::copy(S->sect_title, title_alone);
	}
	Regexp::dispose_of(&mr);

@<Mark this section as an independent tangle target@> =
	text_stream *p = language_name;
	if (Str::len(p) == 0) p = Bibliographic::get_datum(RS->W, I"Language");
	S->is_independent_target = TRUE;
	S->sect_language_name = Str::duplicate(p);

@ The filename for a section is as given in the contents listing: unless,
when |.w| is appended, a file of that name exists in the relevant chapter
directory, in which case that's the file. (Or, failing that, |.i6t|, which
is a hangover from the days of Inform 6 template files in the Inform compiler,
and which for some reason lives on in the web source for kits.)

@<Work out the filename of this section file@> =
	TEMPORARY_TEXT(leafname_to_use)
	pathname *P = RS->path_to;
	if (P == NULL) P = RS->W->path_to_web;
	WRITE_TO(leafname_to_use, "%S", S->sect_title);
	S->source_file_for_section = Filenames::from_text_relative(P, leafname_to_use);
	Str::clear(S->sect_title);
	WRITE_TO(S->sect_title, "%S", Filenames::get_leafname(S->source_file_for_section));
	P = Filenames::up(S->source_file_for_section);
	if (TextFiles::exists(S->source_file_for_section) == FALSE) {
		TEMPORARY_TEXT(leaf)
		WRITE_TO(leaf, "%S.w", Filenames::get_leafname(S->source_file_for_section));
		if (Str::len(RS->chapter_dir_name) > 0)
			P = Pathnames::down(P, RS->chapter_dir_name);
		S->source_file_for_section = Filenames::in(P, leaf);
		if (TextFiles::exists(S->source_file_for_section) == FALSE) {
			Str::delete_last_character(leaf);
			Str::delete_last_character(leaf);
			WRITE_TO(leaf, ".i6t");
			S->source_file_for_section = Filenames::in(P, leaf);
		}
	}
	DISCARD_TEXT(leafname_to_use)
