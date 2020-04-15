[Epub::] Epub Ebooks.

To provide for wrapping up sets of HTML files into ePub ebooks.

@h Ebooks.
Constructing an ePub file (essentially a zipped folder of HTML with some
metadata attached) is simple enough, but the details are finicky. The
HTML pages need to be fully XHTML compliant, which is quite a strict
requirement, and we can't help with that here. But we can at least sort
out the directory structure and the rather complicated indexing and
contents files also required.

See Liza Daly's invaluable tutorial "Build a digital book with EPUB" to
explicate all of this.

While under construction, any single ebook is represented by an instance
of the following structure. Conceptually, we will organise it as a series
of "volumes" (possibly only one), each of which is a series of "chapters"
(possibly only one). The actual content is a series of "pages", which are
essentially individual HTML files, plus some images.

=
typedef struct ebook {
	struct linked_list *metadata_list; /* of |ebook_datum|: DCMI-standard bibliographic data */
	char *prefix; /* to apply to the page leafnames */
	struct filename *CSS_file_throughout; /* where to find a CSS file to be used for all volumes */

	struct filename *eventual_epub; /* filename of the final |*.epub| to be made */
	struct pathname *holder; /* directory to put the ingredients into */
	struct pathname *OEBPS_path; /* subdirectory which mysteriously has to be called |OEBPS| */

	struct linked_list *ebook_volume_list; /* of |ebook_volume| */
	struct ebook_volume *current_volume; /* the one to which chapters are now being added */

	struct linked_list *ebook_chapter_list; /* of |ebook_chapter| */
	struct ebook_chapter *current_chapter; /* the one to which pages are now being added */

	struct linked_list *ebook_page_list; /* of |book_page| */
	struct linked_list *ebook_image_list; /* of |ebook_image| */
	MEMORY_MANAGEMENT
} ebook;

@ DCMI, or "Dublin Core", metadata is a standard set of key-value pairs used to
identify ebooks; we need to maintain a small dictionary, and so small that a
list is entirely sufficient.

=
typedef struct ebook_datum {
	struct text_stream *key;
	struct text_stream *value;
	MEMORY_MANAGEMENT
} ebook_datum;

@ As noted above, we use the following to stratify the book:

=
typedef struct ebook_volume {
	struct text_stream *volume_title;
	struct ebook_page *volume_starts; /* on which page the volume starts */
	struct filename *CSS_file; /* where to find the CSS file to be included */
	MEMORY_MANAGEMENT
} ebook_volume;

typedef struct ebook_chapter {
	struct text_stream *chapter_title;
	struct ebook_volume *in_volume; /* to which volume this chapter belongs */
	struct ebook_page *chapter_starts; /* on which page the chapter starts */
	struct linked_list *ebook_mark_list; /* of |ebook_mark|: for when multiple navigable points exist within this */
	struct text_stream *start_URL;
	MEMORY_MANAGEMENT
} ebook_chapter;

@ Now for the actual resources which will end up in the EPUB. Here are the
pages:

=
typedef struct ebook_page {
	struct text_stream *page_title;
	struct text_stream *page_type;
	struct text_stream *page_ID;

	struct filename *relative_URL; /* eventual URL of this page within the ebook */

	struct ebook_volume *in_volume; /* to which volume this page belongs */
	struct ebook_chapter *in_chapter; /* to which chapter this page belongs */

	int nav_entry_written; /* keep track of what we've written to the navigation tree */
	MEMORY_MANAGEMENT
} ebook_page;

typedef struct ebook_mark {
	struct text_stream *mark_text;
	struct text_stream *mark_URL;
	MEMORY_MANAGEMENT
} ebook_mark;

typedef struct ebook_image {
	struct text_stream *image_ID;
	struct filename *relative_URL; /* eventual URL of this image within the ebook */
	MEMORY_MANAGEMENT
} ebook_image;

@h Creation.

=
ebook *Epub::new(text_stream *title, char *prefix) {
	ebook *B = CREATE(ebook);
	B->metadata_list = NEW_LINKED_LIST(ebook_datum);
	B->OEBPS_path = NULL;
	B->ebook_page_list = NEW_LINKED_LIST(ebook_page);
	B->ebook_image_list = NEW_LINKED_LIST(ebook_image);
	B->ebook_volume_list = NEW_LINKED_LIST(ebook_volume);
	B->current_volume = NULL;
	B->ebook_chapter_list = NEW_LINKED_LIST(ebook_chapter);
	B->current_chapter = NULL;
	B->eventual_epub = NULL;
	B->prefix = prefix;
	Epub::attach_metadata(B, L"title", title);
	return B;
}

void Epub::use_CSS_throughout(ebook *B, filename *F) {
	B->CSS_file_throughout = F;
}

void Epub::use_CSS(ebook_volume *V, filename *F) {
	V->CSS_file = F;
}

text_stream *Epub::attach_metadata(ebook *B, wchar_t *K, text_stream *V) {
	ebook_datum *D = NULL;
	LOOP_OVER_LINKED_LIST(D, ebook_datum, B->metadata_list)
		if (Str::eq_wide_string(D->key, K)) {
			Str::copy(D->value, V);
			return D->value;
		}
	D = CREATE(ebook_datum);
	D->key = Str::new_from_wide_string(K);
	D->value = Str::duplicate(V);
	ADD_TO_LINKED_LIST(D, ebook_datum, B->metadata_list);
	return D->value;
}

text_stream *Epub::get_metadata(ebook *B, wchar_t *K) {
	ebook_datum *D = NULL;
	LOOP_OVER_LINKED_LIST(D, ebook_datum, B->metadata_list)
		if (Str::eq_wide_string(D->key, K))
			return D->value;
	return NULL;
}

text_stream *Epub::ensure_metadata(ebook *B, wchar_t *K) {
	text_stream *S = Epub::get_metadata(B, K);
	if (S == NULL) S = Epub::attach_metadata(B, K, NULL);
	return S;
}

ebook_page *Epub::note_page(ebook *B, filename *F, text_stream *title, text_stream *type) {
	ebook_page *P = CREATE(ebook_page);
	P->relative_URL = F;
	P->nav_entry_written = FALSE;
	P->in_volume = B->current_volume;
	P->in_chapter = B->current_chapter;
	P->page_title = Str::duplicate(title);
	P->page_type = Str::duplicate(type);

	P->page_ID = Str::new();
	WRITE_TO(P->page_ID, B->prefix);
	Filenames::write_unextended_leafname(P->page_ID, F);
	LOOP_THROUGH_TEXT(pos, P->page_ID) {
		wchar_t c = Str::get(pos);
		if ((c == '-') || (c == ' ')) Str::put(pos, '_');
	}
	ADD_TO_LINKED_LIST(P, ebook_page, B->ebook_page_list);
	return P;
}

void Epub::note_image(ebook *B, filename *F) {
	ebook_image *I = CREATE(ebook_image);
	I->relative_URL = F;
	I->image_ID = Str::new();
	Filenames::write_unextended_leafname(I->image_ID, F);
	ADD_TO_LINKED_LIST(I, ebook_image, B->ebook_image_list);
}

ebook_volume *Epub::starts_volume(ebook *B, ebook_page *P, text_stream *title) {
	ebook_volume *V = CREATE(ebook_volume);
	V->volume_starts = P;
	P->in_volume = V;
	V->volume_title = Str::duplicate(title);
	B->current_volume = V;
	V->CSS_file = NULL;
	ADD_TO_LINKED_LIST(V, ebook_volume, B->ebook_volume_list);
	return V;
}

ebook_chapter *Epub::starts_chapter(ebook *B, ebook_page *P, text_stream *title, text_stream *URL) {
	ebook_chapter *C = CREATE(ebook_chapter);
	C->chapter_starts = P;
	C->in_volume = B->current_volume;
	C->chapter_title = Str::duplicate(title);
	C->start_URL = Str::duplicate(URL);
	C->ebook_mark_list = NEW_LINKED_LIST(ebook_mark);
	ADD_TO_LINKED_LIST(C, ebook_chapter, B->ebook_chapter_list);
	B->current_chapter = C;
	P->in_chapter = C;
	return C;
}

void Epub::set_mark_in_chapter(ebook_chapter *C, text_stream *text, text_stream *URL) {
	ebook_mark *M = CREATE(ebook_mark);
	M->mark_text = Str::duplicate(text);
	M->mark_URL = Str::duplicate(URL);
	ADD_TO_LINKED_LIST(M, ebook_mark, C->ebook_mark_list);
}

@h Construction.
Note that if the client wants to use a cover image, it must also "note" this
image separately. (This is a little inconvenient, but indoc wants to do it
that way.)

=
pathname *Epub::begin_construction(ebook *B, pathname *P, filename *cover_image) {
	if (Pathnames::create_in_file_system(P) == FALSE) return NULL;

	TEMPORARY_TEXT(TEMP)
	WRITE_TO(TEMP, "%S.epub", Epub::get_metadata(B, L"title"));
	B->eventual_epub = Filenames::in(P, TEMP);
	DISCARD_TEXT(TEMP)

	pathname *Holder = Pathnames::down(P, I"ePub");
	if (Pathnames::create_in_file_system(Holder) == FALSE) return NULL;
	B->holder = Holder;

	@<Write the EPUB mimetype file@>;
	@<Write the EPUB meta-inf directory@>;
	pathname *OEBPS = Pathnames::down(Holder, I"OEBPS");
	if (Pathnames::create_in_file_system(OEBPS) == FALSE) return NULL;
	if (cover_image) @<Make the cover image page@>;
	B->OEBPS_path = OEBPS;
	return OEBPS;
}

@<Write the EPUB mimetype file@> =
	filename *Mimetype = Filenames::in(Holder, I"mimetype");
	text_stream EM_struct; text_stream *OUT = &EM_struct;
	if (STREAM_OPEN_TO_FILE(OUT, Mimetype, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to open mimetype file for output: %f",
			Mimetype);
	WRITE("application/epub+zip"); /* EPUB requires there be no newline here */
	STREAM_CLOSE(OUT);

@<Write the EPUB meta-inf directory@> =
	pathname *META_INF = Pathnames::down(Holder, I"META-INF");
	if (Pathnames::create_in_file_system(META_INF) == FALSE) return NULL;
	filename *container = Filenames::in(META_INF, I"container.xml");
	text_stream C_struct; text_stream *OUT = &C_struct;
	if (STREAM_OPEN_TO_FILE(OUT, container, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to open container file for output: %f",
			container);
	WRITE("<?xml version=\"1.0\"?>\n");
	WRITE("<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">\n");
	INDENT;
	WRITE("<rootfiles>\n");
	INDENT;
	WRITE("<rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\" />\n");
	OUTDENT;
	WRITE("</rootfiles>\n");
	OUTDENT;
	WRITE("</container>\n");
	STREAM_CLOSE(OUT);

@ It's a much-lamented fact that EPUB 2, at any rate, has no standard way
to define cover images, and different readers behave slightly differently.
But the following seems to work with iTunes 9.1 and later, and therefore
on Apple devices. (See Keith Fahlgren's post "Best practices in ePub cover
images" at the ThreePress Consulting blog.)

@<Make the cover image page@> =
	filename *cover = Filenames::in(OEBPS, I"cover.html");
	text_stream C_struct; text_stream *OUT = &C_struct;
	if (STREAM_OPEN_TO_FILE(OUT, cover, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to open cover file for output: %f",
			cover);

	Epub::note_page(B, cover, I"Cover", I"cover");

	HTML::declare_as_HTML(OUT, TRUE);
	HTML::begin_head(OUT, NULL);
	HTML_OPEN("title");
	WRITE("Cover");
	HTML_CLOSE("title");
	HTML_OPEN_WITH("style", "type=\"text/css\"");
	WRITE("img { max-width: 100%%; }\n");
	HTML_CLOSE("style");
	HTML::end_head(OUT);
	HTML::begin_body(OUT, NULL);
	HTML_OPEN_WITH("div", "id=\"cover-image\"");
	HTML_TAG_WITH("img", "src=\"%/f\" alt=\"%S\"", cover_image, Epub::get_metadata(B, L"title"));
	WRITE("\n");
	HTML_CLOSE("div");
	HTML::end_body(OUT);
	HTML::completed(OUT);
	STREAM_CLOSE(OUT);

@ =
void Epub::end_construction(ebook *B) {
	@<Attach default metadata@>;
	@<Write the EPUB OPF file@>;
	@<Write the EPUB NCX file@>;
	@<Zip the EPUB@>;
}

@<Attach default metadata@> =
	text_stream *datestamp = Epub::ensure_metadata(B, L"date");
	if (Str::len(datestamp) == 0) {
		WRITE_TO(datestamp, "%04d-%02d-%02d", the_present->tm_year + 1900,
			(the_present->tm_mon)+1, the_present->tm_mday);
	}

	TEMPORARY_TEXT(TEMP)
	WRITE_TO(TEMP, "urn:www.inform7.com:");
	text_stream *identifier = Epub::ensure_metadata(B, L"identifier");
	if (Str::len(identifier) == 0)
		WRITE_TO(TEMP, "%S", Epub::get_metadata(B, L"title"));
	else
		WRITE_TO(TEMP, "%S", identifier);
	Str::copy(identifier, TEMP);
	DISCARD_TEXT(TEMP)

	text_stream *lang = Epub::ensure_metadata(B, L"language");
	if (Str::len(lang) == 0) WRITE_TO(lang, "en-UK");

@<Write the EPUB OPF file@> =
	filename *content = Filenames::in(B->OEBPS_path, I"content.opf");
	text_stream C_struct; text_stream *OUT = &C_struct;
	if (STREAM_OPEN_TO_FILE(OUT, content, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to open content file for output: %f",
			content);

	WRITE("<?xml version='1.0' encoding='utf-8'?>\n");
	WRITE("<package xmlns=\"http://www.idpf.org/2007/opf\"\n");
	WRITE("xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n");
	WRITE("unique-identifier=\"bookid\" version=\"2.0\">\n"); INDENT;
	@<Write the OPF metadata@>;
	@<Write the OPF manifest@>;
	@<Write the OPF spine@>;
	@<Write the OPF guide@>;
	OUTDENT; WRITE("</package>\n");

	STREAM_CLOSE(OUT);

@ The metadata here conforms to the Dublin Core Metadata Initiative (ebook_datum).
(Other default values are set in the configuration file.)

@<Write the OPF metadata@> =
	WRITE("<metadata>\n"); INDENT;
	ebook_datum *D = NULL;
	LOOP_OVER_LINKED_LIST(D, ebook_datum, B->metadata_list) {
		WRITE("<dc:%S", D->key);
		if (Str::eq_wide_string(D->key, L"identifier")) WRITE(" id=\"bookid\"");
		WRITE(">");
		WRITE("%S</dc:%S>\n", D->value, D->key);
	}
	WRITE("<meta name=\"cover\" content=\"cover-image\" />\n");
	OUTDENT; WRITE("</metadata>\n");

@<Write the OPF manifest@> =
	WRITE("<manifest>\n"); INDENT;
	WRITE("<item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/>\n");
	@<Manifest the CSS files@>;
	@<Manifest the XHTML files@>;
	@<Manifest the images@>;
	OUTDENT; WRITE("</manifest>\n");

@<Manifest the CSS files@> =
	int cssc = 1;
	if (B->CSS_file_throughout)
		WRITE("<item id=\"css%d\" href=\"%S\" media-type=\"text/css\"/>\n",
				cssc++, Filenames::get_leafname(B->CSS_file_throughout));
	ebook_volume *V;
	LOOP_OVER_LINKED_LIST(V, ebook_volume, B->ebook_volume_list)
		if (V->CSS_file)
			WRITE("<item id=\"css%d\" href=\"%S\" media-type=\"text/css\"/>\n",
				cssc++, Filenames::get_leafname(V->CSS_file));

@<Manifest the XHTML files@> =
	ebook_page *P;
	LOOP_OVER_LINKED_LIST(P, ebook_page, B->ebook_page_list)
		WRITE("<item id=\"%S\" href=\"%S\" media-type=\"application/xhtml+xml\"/>\n",
			P->page_ID, Filenames::get_leafname(P->relative_URL));

@<Manifest the images@> =
	ebook_image *I;
	LOOP_OVER_LINKED_LIST(I, ebook_image, B->ebook_image_list) {
		char *image_type = "";
		switch (Filenames::guess_format(I->relative_URL)) {
			case FORMAT_PERHAPS_PNG: image_type = "png"; break;
			case FORMAT_PERHAPS_JPEG: image_type = "jpeg"; break;
			case FORMAT_PERHAPS_SVG: image_type = "svg"; break;
			case FORMAT_PERHAPS_GIF: image_type = "gif"; break;
			default: Errors::nowhere("image not .gif, .png, .jpg or .svg"); break;
		}
		WRITE("<item id=\"%S\" href=\"%/f\" media-type=\"image/%s\"/>\n",
			I->image_ID, I->relative_URL, image_type);
	}

@<Write the OPF spine@> =
	WRITE("<spine toc=\"ncx\">\n"); INDENT;
	ebook_page *P;
	LOOP_OVER_LINKED_LIST(P, ebook_page, B->ebook_page_list) {
		WRITE("<itemref idref=\"%S\"", P->page_ID);
		if (Str::len(P->page_type) > 0) WRITE(" linear=\"no\"");
		WRITE("/>\n");
	}
	OUTDENT; WRITE("</spine>\n");

@<Write the OPF guide@> =
	WRITE("<guide>\n"); INDENT;
	ebook_page *P;
	LOOP_OVER_LINKED_LIST(P, ebook_page, B->ebook_page_list) {
		if (Str::len(P->page_type) > 0) {
			WRITE("<reference href=\"%S\" type=\"%S\" title=\"%S\"/>\n",
				Filenames::get_leafname(P->relative_URL), P->page_type, P->page_title);
		}
	}
	OUTDENT; WRITE("</guide>\n");

@ The NCX duplicates some of what's in the OPF file, for historical reasons;
it's left over from an earlier standard used by book-readers for visually
impaired people.

@<Write the EPUB NCX file@> =
	filename *toc = Filenames::in(B->OEBPS_path, I"toc.ncx");
	text_stream C_struct; text_stream *OUT = &C_struct;
	if (STREAM_OPEN_TO_FILE(OUT, toc, UTF8_ENC) == FALSE)
		Errors::fatal_with_file("unable to open ncx file for output: %f",
			toc);

	WRITE("<?xml version='1.0' encoding='utf-8'?>\n");
	WRITE("<!DOCTYPE ncx PUBLIC \"-//NISO//DTD ncx 2005-1//EN\"\n");
	WRITE("	\"http://www.daisy.org/z3986/2005/ncx-2005-1.dtd\">\n");
	WRITE("<ncx xmlns=\"http://www.daisy.org/z3986/2005/ncx/\" version=\"2005-1\">\n");

	int depth = 1; /* there are surely at least sections */
	if (LinkedLists::len(B->ebook_chapter_list) > 0) depth = 2;
	if (LinkedLists::len(B->ebook_volume_list) > 0) depth = 3;

	@<Write the NCX metadata@>;
	@<Write the NCX navigation map@>;
	WRITE("</ncx>\n");

	STREAM_CLOSE(OUT);

@<Write the NCX metadata@> =
	WRITE("<head>\n"); INDENT;
	WRITE("<meta name=\"dtb:uid\" content=\"%S\"/>\n", Epub::get_metadata(B, L"identifier"));
	WRITE("<meta name=\"dtb:depth\" content=\"%d\"/>\n", depth);
	WRITE("<meta name=\"dtb:totalPageCount\" content=\"0\"/>\n");
	WRITE("<meta name=\"dtb:maxPageNumber\" content=\"0\"/>\n");
	OUTDENT; WRITE("</head>\n");
	WRITE("<docTitle>\n"); INDENT;
	WRITE("<text>%S</text>\n", Epub::get_metadata(B, L"title"));
	OUTDENT; WRITE("</docTitle>\n");

@<Write the NCX navigation map@> =
	WRITE("<navMap>\n"); INDENT;
	int navpoint_count = 1;
	int navmap_depth = 1;
	int phase = 0;
	@<Include the non-section pages in this phase@>;
	ebook_volume *V = NULL;
	LOOP_OVER_LINKED_LIST(V, ebook_volume, B->ebook_volume_list) {
		@<Begin navPoint@>;
		WRITE("<navLabel><text>%S</text></navLabel>", V->volume_title);
		WRITE("<content src=\"%S\"/>\n", Filenames::get_leafname(V->volume_starts->relative_URL));
		@<Include the chapters and sections in this volume@>;
		@<End navPoint@>;
	}
	phase = 1;
	@<Include the non-section pages in this phase@>;
	OUTDENT; WRITE("</navMap>\n");
	if (navmap_depth != 1) internal_error("navMap numbering unbalanced");

@<Include the non-section pages in this phase@> =
	ebook_page *P;
	LOOP_OVER_LINKED_LIST(P, ebook_page, B->ebook_page_list) {
		int in_phase = 1;
		if ((Str::eq_wide_string(P->page_ID, L"cover")) ||
			(Str::eq_wide_string(P->page_ID, L"index")))
			in_phase = 0;
		if ((in_phase == phase) && (P->nav_entry_written == FALSE)) {
			@<Begin navPoint@>;
			WRITE("<navLabel><text>%S</text></navLabel> <content src=\"%S\"/>\n",
				P->page_title, Filenames::get_leafname(P->relative_URL));
			@<End navPoint@>;
		}
	}

@<Include the chapters and sections in this volume@> =
	ebook_chapter *C = NULL;
	LOOP_OVER_LINKED_LIST(C, ebook_chapter, B->ebook_chapter_list)
		if (C->in_volume == V) {
			@<Begin navPoint@>;
			WRITE("<navLabel><text>%S</text></navLabel>", C->chapter_title);
			WRITE("<content src=\"%S\"/>\n", C->start_URL);
			if (C->ebook_mark_list)
				@<Include the marks in this chapter@>
			else
				@<Include the sections in this chapter@>;
			ebook_page *P;
			LOOP_OVER_LINKED_LIST(P, ebook_page, B->ebook_page_list)
				if (P->in_chapter == C)
					P->nav_entry_written = TRUE;
			@<End navPoint@>;
		}

@<Include the sections in this chapter@> =
	ebook_page *P;
	LOOP_OVER_LINKED_LIST(P, ebook_page, B->ebook_page_list) {
		if ((P->in_chapter == C) && (P->nav_entry_written == FALSE)) {
			@<Begin navPoint@>;
			WRITE("<navLabel><text>%S</text></navLabel>", P->page_title);
			WRITE("<content src=\"%S\"/>\n", Filenames::get_leafname(P->relative_URL));
			@<End navPoint@>;
			P->nav_entry_written = TRUE;
		}
	}

@<Include the marks in this chapter@> =
	ebook_mark *M;
	LOOP_OVER_LINKED_LIST(M, ebook_mark, C->ebook_mark_list) {
		@<Begin navPoint@>;
		WRITE("<navLabel><text>%S</text></navLabel>", M->mark_text);
		WRITE("<content src=\"%S\"/>\n", M->mark_URL);
		@<End navPoint@>;
	}

@<Begin navPoint@> =
	WRITE("<navPoint id=\"navpoint-%d\" playOrder=\"%d\">\n",
		navpoint_count, navpoint_count);
	navpoint_count++;
	navmap_depth++; INDENT;

@<End navPoint@> =
	navmap_depth--;
	if (navmap_depth < 1) internal_error("navMap numbering awry");
	OUTDENT; WRITE("</navPoint>\n");

@<Zip the EPUB@> =
	pathname *up = Pathnames::from_text(I"..");
	filename *ePub_relative =
		Filenames::in(up, Filenames::get_leafname(B->eventual_epub));
	@<Issue first zip instruction@>;
	@<Issue second zip instruction@>;

@<Issue first zip instruction@> =
	TEMPORARY_TEXT(COMMAND)
	Shell::plain(COMMAND, "cd ");
	Shell::quote_path(COMMAND, B->holder);
	Shell::plain(COMMAND, "; zip -0Xq ");
	Shell::quote_file(COMMAND, ePub_relative);
	Shell::plain(COMMAND, " mimetype");
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)

@<Issue second zip instruction@> =
	TEMPORARY_TEXT(COMMAND)
	Shell::plain(COMMAND, "cd ");
	Shell::quote_path(COMMAND, B->holder);
	Shell::plain(COMMAND, "; zip -Xr9Dq ");
	Shell::quote_file(COMMAND, ePub_relative);
	Shell::plain(COMMAND, " *");
	Shell::run(COMMAND);
	DISCARD_TEXT(COMMAND)
