[WebStructure::] Web Structure.

To read the structure of a literate programming web from a path in the file
system.

@h Web objects.
Each web loaded in produces a single instance of the following. If |W| is an
|ls_web|, note that |W->chapters| is the full list of all chapters in its
program, including those imported from other webs: this may be different from
|W->main_module->chapters|, which contains just its own chapters.

In fact, the |W->chapters| list is arguably redundant, since it's just a
concatenation of the chapter lists of the modules, but it's much more convenient
to store this redundant copy than to have to keep traversing the module tree.

=
typedef struct ls_web {
	struct wcl_declaration *declaration;
	struct ls_module *main_module; /* the root of a small dependency graph */
	struct linked_list *chapters; /* of |ls_chapter| */

	struct pathname *path_to_web; /* relative to the current working directory */
	struct filename *single_file; /* relative to the current working directory */
	int is_page; /* is this a simple one-section web with no contents page? */
	struct linked_list *bibliographic_data; /* of |web_bibliographic_datum| */
	struct semantic_version_number version_number; /* as deduced from bibliographic data */
	struct ls_syntax *web_syntax; /* which version syntax the sections will have */
	int chaptered; /* has the author explicitly divided it into named chapters? */

	struct programming_language *web_language; /* in which most of the sections are written */
	struct linked_list *tangle_target_names; /* of |text_stream| */
	struct linked_list *tangle_targets; /* of |tangle_target| */

	struct filename *contents_filename; /* or |NULL| for a single-file web */
	struct linked_list *header_filenames; /* of |filename| */

	void *weaving_ref;
	void *tangling_ref;
	void *analysis_ref;
	CLASS_DEFINITION
} ls_web;

ls_web *WebStructure::new_ls_web(wcl_declaration *D) {
	ls_web *W = CREATE(ls_web);
	W->declaration = D;
	if (D) D->object_declared = STORE_POINTER_ls_web(W);
	W->bibliographic_data = NEW_LINKED_LIST(web_bibliographic_datum);
	Bibliographic::initialise_data(W);
	W->is_page = FALSE;
	if ((D) && (D->modifier == PAGE_WCLMODIFIER)) W->is_page = TRUE;
	if ((D) && (D->scope)) {
		W->path_to_web = D->scope->associated_path;
		if (W->path_to_web == NULL)
			W->path_to_web = Filenames::up(D->scope->associated_file);
		W->single_file = NULL;
		W->contents_filename = NULL;
	} else if (D->associated_path) {
		W->path_to_web = D->associated_path;
		W->single_file = NULL;
		W->contents_filename = D->associated_file;
	} else {
		W->path_to_web = Filenames::up(D->associated_file);
		W->single_file = D->associated_file;
		W->contents_filename = NULL;
	}
	W->version_number = VersionNumbers::null();
	W->web_syntax = NULL;
	W->chaptered = FALSE;
	W->chapters = NEW_LINKED_LIST(ls_chapter);
	W->tangle_target_names = NEW_LINKED_LIST(text_stream);
	W->tangle_targets = NEW_LINKED_LIST(tangle_target);
	W->web_language = NULL;
	W->header_filenames = NEW_LINKED_LIST(filename);
	W->main_module = WebModules::create_main_module(W);
	W->weaving_ref = NULL;
	W->tangling_ref = NULL;
	W->analysis_ref = NULL;
	return W;
}

ls_web *WebStructure::from_declaration(wcl_declaration *D) {
	if (D == NULL) return NULL;
	return RETRIEVE_POINTER_ls_web(D->object_declared);
}

@h Web reading.

=
ls_web *WebStructure::read_fully(colony *C, wcl_declaration *D,
	int enumerating, int weaving, int verbosely) {
	ls_web *W = WebStructure::from_declaration(D);
	WebStructure::read_web_source(W, verbosely, weaving);
	WebErrors::issue_all_recorded(W);
	@<Write the Inweb Version bibliographic datum@>;
	CodeAnalysis::initialise_analysis_details(W);
	WeavingDetails::initialise(W);
	CodeAnalysis::analyse_web(W, enumerating, weaving);
	if ((weaving) &&
		(WebSyntax::supports(W->web_syntax, MARKDOWN_COMMENTARY_WSF))) {
		ls_chapter *Ch;
		ls_section *S;
		LOOP_OVER_LINKED_LIST(Ch, ls_chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S, ls_section, Ch->sections)
				LiterateSource::parse_markdown(S->literate_source);
	}
	return W;
}

@<Write the Inweb Version bibliographic datum@> =
	TEMPORARY_TEXT(IB)
	WRITE_TO(IB, "[[Version Number]]");
	web_bibliographic_datum *bd = Bibliographic::set_datum(W, I"Inweb Version", IB);
	bd->declaration_permitted = FALSE;
	DISCARD_TEXT(IB)

@ Statistics:

=
int WebStructure::chapter_count(ls_web *W) {
	int n = 0;
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) n++;
	return n;
}
int WebStructure::imported_chapter_count(ls_web *W) {
	int n = 0;
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if (C->imported)
			n++;
	return n;
}
int WebStructure::section_count(ls_web *W) {
	int n = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			n++;
	return n;
}
int WebStructure::imported_section_count(ls_web *W) {
	int n = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if (C->imported)
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				n++;
	return n;
}
int WebStructure::paragraph_count(ls_web *W) {
	int n = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if (S->literate_source)
				for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
					n++;
	return n;
}
int WebStructure::imported_paragraph_count(ls_web *W) {
	int n = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if (C->imported)
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				if (S->literate_source)
					for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
						n++;
	return n;
}
int WebStructure::line_count(ls_web *W) {
	int n = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			n += (S->literate_source)?(S->literate_source->lines_read):0;
	return n;
}
int WebStructure::imported_line_count(ls_web *W) {
	int n = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if (C->imported)
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				n += (S->literate_source)?(S->literate_source->lines_read):0;
	return n;
}

int WebStructure::has_only_one_section(ls_web *W) {
	if (WebStructure::section_count(W) == 1) return TRUE;
	return FALSE;
}

int WebStructure::has_errors(ls_web *W) {
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if (LiterateSource::unit_has_errors(S->literate_source))
				return TRUE;
	return FALSE;
}

@ This really serves no purpose, but seems to boost morale.

=
void WebStructure::print_statistics(ls_web *W) {
	int s = 0, c = 0, n = 0, lc = 0;
	ls_chapter *C;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) {
		c++;
		ls_section *S;
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
			s++;
			for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
				n++;
			lc += S->literate_source->lines_read;
		}
	}
	PRINT("web \"%S\"", Bibliographic::get_datum(W, I"Title"));
	if (W->web_syntax) PRINT(" (%S", W->web_syntax->name); else PRINT(" (no syntax");
	if (WebStructure::web_language(W)) PRINT(", %S)", WebStructure::web_language(W)->language_name); else PRINT(", no language)");
	PRINT(": ");
	if (W->chaptered) PRINT("%d chapter%s : ",
		c, (c == 1)?"":"s");
	PRINT("%d section%s : %d paragraph%s : %d line%s\n",
		s, (s == 1)?"":"s",
		n, (n == 1)?"":"s",
		lc, (lc == 1)?"":"s");
}

@ This is really for debugging:

=
void WebStructure::write_literate_source(OUTPUT_STREAM, ls_web *W) {
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			LiterateSource::write_lsu(OUT, S->literate_source);
}

@h Chapter objects.
The |chapters| list in a |ls_web| contains these as its entries. Instances
of |ls_chapter| are never created for any other purpose, so they can exist only
as part of an |ls_web|; and once added they are never removed.

=
typedef struct ls_chapter {
	struct ls_web *owning_web;
	struct ls_module *owning_module;
	int imported; /* did this originate in a different web? */
	struct linked_list *sections; /* of |ls_section| */

	struct text_stream *ch_range; /* e.g., |P| for Preliminaries, |7| for Chapter 7, |C| for Appendix C */
	struct text_stream *ch_title; /* e.g., "Chapter 3: Fresh Water Fish" */
	struct text_stream *ch_basic_title; /* e.g., "Chapter 3" */
	struct text_stream *ch_decorated_title; /* e.g., "Fresh Water Fish" */
	struct text_stream *rubric; /* optional; without double-quotation marks */

	struct text_stream *ch_language_name; /* in which most of the sections are written */
	struct programming_language *ch_language; /* in which this chapter is written */


	void *weaving_ref;
	void *tangling_ref;
	void *analysis_ref;
	CLASS_DEFINITION
} ls_chapter;

ls_chapter *WebStructure::new_ls_chapter(ls_web *W, text_stream *range, text_stream *titling) {
	if (W == NULL) internal_error("no web for chapter");
	ls_chapter *C = CREATE(ls_chapter);
	C->ch_range = Str::duplicate(range);
	C->ch_title = Str::duplicate(titling);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, C->ch_title, U"(%c*?): *(%c*)")) {
		C->ch_basic_title = Str::duplicate(mr.exp[0]);
		C->ch_decorated_title = Str::duplicate(mr.exp[1]);
	} else {
		C->ch_basic_title = Str::duplicate(C->ch_title);
		C->ch_decorated_title = Str::new();
	}
	Regexp::dispose_of(&mr);
	C->rubric = Str::new();
	C->ch_language_name = NULL;
	C->ch_language = NULL;
	C->imported = FALSE;
	C->sections = NEW_LINKED_LIST(ls_section);
	C->owning_web = W;
	C->owning_module = NULL;
	C->weaving_ref = NULL;
	C->tangling_ref = NULL;
	C->analysis_ref = NULL;

	ADD_TO_LINKED_LIST(C, ls_chapter, W->chapters);
	return C;
}

@h Section objects.
The |chapters| list in an |ls_chapter| contains these as its entries. Instances
of |ls_section| are never created for any other purpose, so they can exist only
as part of an |ls_chapter|; and once added they are never removed.

=
typedef struct ls_section {
	struct ls_chapter *owning_chapter;

	struct text_stream *sect_title; /* e.g., "Program Control" */
	struct text_stream *sect_range; /* e.g., "2/ct" */

	struct text_stream *titling_line_to_insert;
	struct ls_unit *literate_source;

	struct filename *source_file_for_section; /* content either from a file... */
	struct wcl_declaration *source_declaration_for_section; /* ...or the body of a declaration */
	int skip_from; /* ignore lines numbered in this inclusive range */
	int skip_to;
	int sect_extent; /* total number of lines read from a file (including skipped ones) */

	struct text_stream *tag_name;

	struct programming_language *sect_language; /* in which this section is written */
	struct text_stream *sect_language_name;
	int is_independent_target;
	struct tangle_target *sect_target; /* |NULL| unless this section produces a tangle of its own */
	int paragraph_numbers_visible;

	int scratch_flag; /* temporary workspace */

	void *weaving_ref;
	void *tangling_ref;
	void *analysis_ref;
	CLASS_DEFINITION
} ls_section;

ls_section *WebStructure::new_ls_section(ls_chapter *C, text_stream *titling) {
	if (C == NULL) internal_error("no chapter for section");
	ls_section *S = CREATE(ls_section);
	S->source_file_for_section = NULL;
	S->source_declaration_for_section = NULL;
	S->skip_from = 0;
	S->skip_to = 0;
	S->titling_line_to_insert = NULL;
	S->sect_range = Str::new();
	S->literate_source = NULL;
	S->sect_language_name = NULL;
	S->sect_language = NULL;
	S->is_independent_target = FALSE;
	S->sect_target = NULL;
	S->paragraph_numbers_visible = TRUE;

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, titling, U"(%c+) %^\"(%c+)\" *")) {
		S->sect_title = Str::duplicate(mr.exp[0]);
		S->tag_name = Str::duplicate(mr.exp[1]);
	} else {
		S->sect_title = Str::duplicate(titling);
		S->tag_name = NULL;
	}
	Regexp::dispose_of(&mr);
	S->owning_chapter = C;
	
	S->scratch_flag = FALSE;
	S->sect_extent = 0;

	S->weaving_ref = NULL;
	S->tangling_ref = NULL;
	S->analysis_ref = NULL;

	ADD_TO_LINKED_LIST(S, ls_section, C->sections);
	return S;
}

int WebStructure::paragraph_count_within_section(ls_section *S) {
	int n = 0;
	for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
		n++;
	return n;
}

@h Woven and Tangled folders.
We abstract these in order to be able to respond well to their not existing:

=
pathname *WebStructure::woven_folder(ls_web *W) {
	pathname *P = Pathnames::down(W->path_to_web, I"Woven");
	if (Pathnames::create_in_file_system(P) == FALSE)
		Errors::fatal_with_path("unable to create Woven subdirectory", P);
	return P;
}
pathname *WebStructure::tangled_folder(ls_web *W) {
	pathname *P = Pathnames::down(W->path_to_web, I"Tangled");
	if (Pathnames::create_in_file_system(P) == FALSE)
		Errors::fatal_with_path("unable to create Tangled subdirectory", P);
	return P;
}

@h Contents page.
The contents page for a large web is usually at a fixed leafname, so:

=
int WebStructure::directory_looks_like_a_web(pathname *P) {
	return TextFiles::exists(Filenames::in(P, I"Contents.w"));
}

@ But mid-sized webs can consist more or less of an arbitrary file itself
serving as contents page, so we won't assume it's always "Contents.w":

=
filename *WebStructure::contents_filename(ls_web *W) {
	return W->contents_filename;
}

@h Reading from the file system.
Webs can be stored in two ways: as a directory containing a multitude of files,
in which case the pathname |P| is supplied; or as a single file with everything
in one (and thus, implicitly, a single chapter and a single section), in which
case a filename |alt_F| is supplied.

=
ls_web *WebStructure::parse_declaration(wcl_declaration *D) {
	ls_web *W = WebStructure::new_ls_web(D);
	
	if (W->is_page)
		SingleFileWebs::reconnoiter(W);
	else
		WebContents::read_contents_page(W, W->main_module,
			WebModules::get_default_search_path(), TRUE, NULL);
	if (W->web_syntax == NULL) internal_error("no LS syntax for web");

	Bibliographic::check_required_data(W);
	BuildFiles::set_bibliographic_data_for(W);
	BuildFiles::deduce_semver(W);
	return W;
}

@h Web reading.
All of that ran very quickly, but now things will slow down. The next
function is where the actual contents of a web are read -- which means opening
each section and reading it line by line. We read the complete literate source
of the web into memory, which is profligate, but saves time.

=
void WebStructure::read_web_source(ls_web *W, int verbosely, int with_internals) {
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			@<Read one section from a file@>;
}

@<Read one section from a file@> =
	pathname *P = W->path_to_web;
	ls_module *M = S->owning_chapter->owning_module;
	if ((M) && (M->module_location))
		P = M->module_location; /* references are relative to module */

	S->literate_source = LiterateSource::begin_unit(S, W->web_syntax, WebStructure::section_language(S), P, W);
	if (Str::eq(Bibliographic::get_datum(W, I"Paragraph Numbers Visibility"), I"Off"))
		S->paragraph_numbers_visible = FALSE;

	if (WebSyntax::supports(W->web_syntax, EXPLICIT_SECTION_HEADINGS_WSF)) {
		if (W->is_page)
			@<Insert an implied purpose, for a single-file web@>;
	}

	int cl = 0;
	if (S->source_declaration_for_section) {
		wcl_declaration *D = S->source_declaration_for_section;
		text_file_position tfp = D->body_position;
		text_stream *L;
		LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
			TEMPORARY_TEXT(line)
			Str::copy(line, L);
			WebStructure::scan_source_line(line, &tfp, (void *) S);
			DISCARD_TEXT(line);
			tfp.line_count++; cl++;
		}
	} else {
		filename *F = S->source_file_for_section;
		if (F == NULL) internal_error("no source file");
		cl = TextFiles::read(F, FALSE, "can't open section file", TRUE,
				WebStructure::scan_source_line, NULL, (void *) S);
	}

	LiterateSource::complete_unit(S->literate_source);
	if (Str::len(S->literate_source->heading.operand1) > 0) {
		S->sect_title = Str::duplicate(S->literate_source->heading.operand1);
		if (W->is_page) Bibliographic::set_datum(W, I"Title", S->sect_title);
	}
	if (verbosely) PRINT("Read section: '%S' (%d lines)\n", S->sect_title, cl);

@<Insert an implied purpose, for a single-file web@> =
	text_stream *purpose = Bibliographic::get_datum(W, I"Purpose");
	if (Str::len(purpose) > 0) LiterateSource::add_purpose(S->literate_source, NULL, purpose);

@ Non-implied source lines come from here. Note that we assume here that
trailing whitespace on a line is not significant in the language being
tangled for.

=
void WebStructure::scan_source_line(text_stream *line, text_file_position *tfp, void *state) {
	ls_section *S = (ls_section *) state;
	S->sect_extent++;
	if ((S->skip_from > 0) && (S->skip_from <= tfp->line_count) && (tfp->line_count <= S->skip_to))
		return;
	int l = Str::len(line) - 1;
	while ((l>=0) && (Characters::is_space_or_tab(Str::get_at(line, l))))
		Str::truncate(line, l--);
	LiterateSource::feed_line(S->literate_source, tfp, line);
}

@h Language.
I'm probably showing my age here: the default language for a web is C.

=
void WebStructure::resolve_declaration(wcl_declaration *D) {
	ls_web *W = RETRIEVE_POINTER_ls_web(D->object_declared);
	text_stream *language_name = Bibliographic::get_datum(W, I"Language");
	if (Str::len(language_name) == 0) language_name = I"C";
	W->web_language = Languages::find_or_fail(W, language_name);
	ls_chapter *C; ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) {
		if (Str::len(C->ch_language_name) > 0)
			C->ch_language = Languages::find_or_fail(W, C->ch_language_name);
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			if (Str::len(S->sect_language_name) > 0)
				S->sect_language = Languages::find_or_fail(W, S->sect_language_name);
	}
}

programming_language *WebStructure::section_language(ls_section *S) {
	if (S->sect_language == NULL) return WebStructure::chapter_language(S->owning_chapter);
	return S->sect_language;
}

programming_language *WebStructure::chapter_language(ls_chapter *C) {
	if (C->ch_language == NULL) return WebStructure::web_language(C->owning_web);
	return C->ch_language;
}

programming_language *WebStructure::web_language(ls_web *W) {
	return W->web_language;
}

void WebStructure::set_language(ls_web *W, programming_language *pl) {
	Bibliographic::set_datum(W, I"Language", pl->language_name);
	W->web_language = pl;
}

@h Debugging.
This is useful mainly for testing: it produces a verbose listing of everything
in a web.

=
void WebStructure::write_web(OUTPUT_STREAM, ls_web *W, text_stream *range) {
	ls_chapter *C = WebRanges::to_chapter(W, range);
	if (C) {
		ls_section *S;
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			LiterateSource::write_lsu(OUT, S->literate_source);
	} else {
		ls_section *S = WebRanges::to_section(W, range);
		if (S) {
			LiterateSource::write_lsu(OUT, S->literate_source);
		} else {
			LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
				LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
					LiterateSource::write_lsu(OUT, S->literate_source);
		}
	}
}
