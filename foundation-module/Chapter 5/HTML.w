[HTML::] HTML.

Utility functions for writing HTML.

@h Header and footer.

=
void HTML::header(OUTPUT_STREAM, text_stream *title, filename *css1, filename *css2,
	filename *js1, filename *js2, void *state) {
	HTML::declare_as_HTML(OUT, FALSE);
	HTML::begin_head(OUT, NULL);
	HTML::title(OUT, title);
	if (css1) HTML::incorporate_CSS(OUT, css1);
	if (css2) HTML::incorporate_CSS(OUT, css2);
	if (js1) HTML::incorporate_javascript(OUT, TRUE, js1);
	if (js2) HTML::incorporate_javascript(OUT, TRUE, js2);
	#ifdef ADDITIONAL_SCRIPTING_HTML_CALLBACK
	ADDITIONAL_SCRIPTING_HTML_CALLBACK(OUT, state);
	#endif
	HTML::end_head(OUT);
	HTML::begin_body(OUT, NULL);
}

void HTML::footer(OUTPUT_STREAM) {
	WRITE("\n");
	HTML::end_body(OUT);
}

@h Abstraction.
Though the code below does nothing at all interesting, to put it mildly,
it's written a little defensively, to increase the chances that the client
is producing valid HTML with it. In particular, the client won't be
allowed to open a |p| tag, then open a |b| tag, then close the |p|, then
close the |b|: that would be wrongly nested. We want to throw errors like
that into the debugging log, so:

@d tag_error(x) {
	LOG("Tag error: %s\n", x);
	HTML_tag *ht;
	int i = 1;
	LOG("HTML tag stack:\n");
	LOOP_DOWN_LIFO_STACK(ht, HTML_tag, hs->tag_stack) {
		LOG("    %d. %s (opened at line %d of '%s')\n", i++,
			ht->tag_name, ht->from_line, ht->from_filename);
	}
	LOG("\n\n");
}

@ Any text stream can be declared as being HTML, and therefore subject to
this auditing. To do that, we atach an |HTML_file_state| object to the
text stream.

=
typedef struct HTML_file_state {
	int XHTML_flag; /* writing strict XHTML for use in epubs */
	struct lifo_stack *tag_stack; /* of |HTML_tag|: those currently open */
	int CSS_included;
	int JS_included;
	CLASS_DEFINITION
} HTML_file_state;

void HTML::declare_as_HTML(OUTPUT_STREAM, int XHTML) {
	HTML_file_state *hs = CREATE(HTML_file_state);
	hs->XHTML_flag = XHTML;
	hs->tag_stack = NEW_LIFO_STACK(HTML_tag);
	hs->CSS_included = 0;
	hs->JS_included = 0;
	Streams::declare_as_HTML(OUT, hs);
}

@ What we require is that any tag "pushed" to the file must later be "pulled",
and in the right order. Thus we can't open body, open div, close body, because
that would be a div tag which was pushed but not pulled.

=
int unique_xref = 0;
typedef struct HTML_tag {
	char *tag_name;
	int tag_xref;
	char *from_filename;
	int from_line;
	CLASS_DEFINITION
} HTML_tag;

int HTML::push_tag(OUTPUT_STREAM, char *tag, char *fn, int lc) {
	int u = unique_xref++;
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) {
		HTML_tag *ht = CREATE(HTML_tag);
		ht->tag_name = tag;
		ht->tag_xref = u;
		ht->from_filename = fn;
		ht->from_line = lc;
		PUSH_TO_LIFO_STACK(ht, HTML_tag, hs->tag_stack);
	}
	return u;
}

@ =
void HTML::pop_tag(OUTPUT_STREAM, char *tag, char *fn, int lc) {
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) {
		if (LIFO_STACK_EMPTY(HTML_tag, hs->tag_stack)) {
			LOG("Trying to close %s at line %d of '%s', but:\n", tag, lc, fn);
			tag_error("closed HTML tag which wasn't open");
		} else {
			HTML_tag *ht = TOP_OF_LIFO_STACK(HTML_tag, hs->tag_stack);
			if ((ht == NULL) || (strcmp(tag, ht->tag_name) != 0)) {
				LOG("Trying to close %s at line %d of '%s', but:\n", tag, lc, fn);
				tag_error("closed HTML tag which wasn't open");
			}
			POP_LIFO_STACK(HTML_tag, hs->tag_stack);
		}
	}
}

@ At the end, therefore, no tags must remain unpulled.

=
void HTML::completed(OUTPUT_STREAM) {
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if ((hs) && (LIFO_STACK_EMPTY(HTML_tag, hs->tag_stack) == FALSE)) {
		tag_error("HTML tags still open");
	}
}

@ We will open and close all HTML tags using the following macros, two
of which are variadic and have to be written out the old-fashioned way:

@d HTML_TAG(tag) HTML::tag(OUT, tag, NULL);
@d HTML_OPEN(tag) HTML::open(OUT, tag, NULL, __FILE__, __LINE__);
@d HTML_CLOSE(tag) HTML::close(OUT, tag, __FILE__, __LINE__);

=
#define HTML_TAG_WITH(tag, args...) { \
	TEMPORARY_TEXT(details) \
	WRITE_TO(details, args); \
	HTML::tag(OUT, tag, details); \
	DISCARD_TEXT(details) \
}

#define HTML_OPEN_WITH(tag, args...) { \
	TEMPORARY_TEXT(details) \
	WRITE_TO(details, args); \
	HTML::open(OUT, tag, details, __FILE__, __LINE__); \
	DISCARD_TEXT(details) \
}

@ Which themselves depend on these routines:

=
void HTML::tag(OUTPUT_STREAM, char *tag, text_stream *details) {
	WRITE("<%s", tag);
	if (Str::len(details) > 0) WRITE(" %S", details);
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if ((hs) && (hs->XHTML_flag)) WRITE(" /");
	WRITE(">");
	if (HTML::tag_formatting(tag) >= 1) WRITE("\n");
}

void HTML::tag_sc(OUTPUT_STREAM, char *tag, text_stream *details) {
	WRITE("<%s", tag);
	if (Str::len(details) > 0) WRITE(" %S", details);
	WRITE(" />");
	if (HTML::tag_formatting(tag) >= 1) WRITE("\n");
}

int HTML::tag_formatting(char *tag) {
	if (strcmp(tag, "meta") == 0) return 1;
	if (strcmp(tag, "link") == 0) return 1;
	if (strcmp(tag, "hr") == 0) return 1;
	if (strcmp(tag, "br") == 0) return 1;

	return 0;
}

void HTML::open(OUTPUT_STREAM, char *tag, text_stream *details, char *fn, int lc) {
	int f = HTML::pair_formatting(tag);
	HTML::push_tag(OUT, tag, fn, lc);
	WRITE("<%s", tag);
	if (Str::len(details) > 0) WRITE(" %S", details);
	WRITE(">");
	if (f >= 2) { WRITE("\n"); INDENT; }
}

void HTML::close(OUTPUT_STREAM, char *tag, char *fn, int lc) {
	int f = HTML::pair_formatting(tag);
	if (f >= 3) WRITE("\n");
	if (f >= 2) OUTDENT;
	WRITE("</%s>", tag);
	HTML::pop_tag(OUT, tag, fn, lc);
	if (f >= 1) WRITE("\n");
}

void HTML::open_indented_p(OUTPUT_STREAM, int depth, char *class) {
	int margin = depth;
	if (margin < 1) internal_error("minimal HTML indentation is 1");
	if (margin > 9) margin = 9;
	HTML_OPEN_WITH("p", "class=\"%sin%d\"", class, margin);
	while (depth > 9) { depth--; WRITE("&nbsp;&nbsp;&nbsp;&nbsp;"); }
}

int HTML::pair_formatting(char *tag) {
	if (strcmp(tag, "td") == 0) return 3;

	if (strcmp(tag, "head") == 0) return 2;
	if (strcmp(tag, "body") == 0) return 2;
	if (strcmp(tag, "div") == 0) return 2;
	if (strcmp(tag, "table") == 0) return 2;
	if (strcmp(tag, "tr") == 0) return 2;
	if (strcmp(tag, "script") == 0) return 2;
	if (strcmp(tag, "style") == 0) return 2;

	if (strcmp(tag, "html") == 0) return 1;
	if (strcmp(tag, "p") == 0) return 1;
	if (strcmp(tag, "title") == 0) return 1;
	if (strcmp(tag, "blockquote") == 0) return 1;

	return 0;
}

@h Head.

=
void HTML::begin_head(OUTPUT_STREAM, filename *CSS_file) {
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if ((hs) && (hs->XHTML_flag)) {
		WRITE("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" ");
		WRITE("\"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n");
		HTML_OPEN_WITH("html", "xmlns=\"http://www.w3.org/1999/xhtml\"");
	} else {
		WRITE("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" ");
		WRITE("\"http://www.w3.org/TR/html4/loose.dtd\">\n");
		HTML_OPEN("html");
	}
	WRITE("\n");
	HTML_OPEN("head");
	HTML_TAG_WITH("meta", "http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\"");
	if (CSS_file)
		HTML_TAG_WITH("link", "href=\"%/f\" rel=\"stylesheet\" type=\"text/css\"", CSS_file);
}

void HTML::end_head(OUTPUT_STREAM) {
	HTML_CLOSE("head");
}

@ =
void HTML::title(OUTPUT_STREAM, text_stream *title) {
	HTML_OPEN("title");
	WRITE("%S", title);
	HTML_CLOSE("title");
}

@h Scripts and styles.

=
void HTML::open_javascript(OUTPUT_STREAM, int define_project) {
	HTML_OPEN_WITH("script", "type=\"text/javascript\"");
	if (define_project) {
		WRITE("function project() {\n"); INDENT;
		WRITE("return window.Project;\n");
		OUTDENT; WRITE("}\n");
	}
}

void HTML::close_javascript(OUTPUT_STREAM) {
	HTML_CLOSE("script");
}

dictionary *HTML_incorporation_cache = NULL;

void HTML::incorporate_javascript(OUTPUT_STREAM, int define_project, filename *M) {
	HTML::open_javascript(OUT, define_project);
	if (HTML_incorporation_cache == NULL)
		HTML_incorporation_cache = Dictionaries::new(32, TRUE);
	TEMPORARY_TEXT(key)
	WRITE_TO(key, "%f", M);
	text_stream *existing_entry = Dictionaries::get_text(HTML_incorporation_cache, key);
	if (existing_entry) {
		WRITE("%S", existing_entry);
	} else {
		text_stream *new_entry = Dictionaries::create_text(HTML_incorporation_cache, key);
		HTML::incorporate_javascript_from_file(new_entry, M);
		WRITE("%S", new_entry);
	}
	DISCARD_TEXT(key)
	HTML::close_javascript(OUT);
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) hs->JS_included++;
}

void HTML::incorporate_javascript_from_file(OUTPUT_STREAM, filename *M) {
	if (TextFiles::read(M, FALSE, NULL, FALSE, HTML::incorporate_helper, NULL, OUT) == FALSE) {
		WRITE_TO(STDERR, "%f", M);
		internal_error("Unable to open model JS material for reading");
	}
}

void HTML::open_CSS(OUTPUT_STREAM) {
	HTML_OPEN_WITH("style", "type=\"text/css\"");
	WRITE("<!--\n");
}

void HTML::close_CSS(OUTPUT_STREAM) {
	WRITE("-->\n");
	HTML_CLOSE("style");
}

void HTML::incorporate_CSS(OUTPUT_STREAM, filename *M) {
	if (HTML_incorporation_cache == NULL)
		HTML_incorporation_cache = Dictionaries::new(32, TRUE);
	TEMPORARY_TEXT(key)
	WRITE_TO(key, "%f", M);
	text_stream *existing_entry = Dictionaries::get_text(HTML_incorporation_cache, key);
	if (existing_entry) {
		WRITE("%S", existing_entry);
	} else {
		text_stream *new_entry = Dictionaries::create_text(HTML_incorporation_cache, key);
		HTML::incorporate_CSS_from_file(new_entry, M);
		WRITE("%S", new_entry);
	}
	DISCARD_TEXT(key)
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) hs->CSS_included++;
}

void HTML::incorporate_CSS_from_file(OUTPUT_STREAM, filename *M) {
	HTML::open_CSS(OUT);
	if (TextFiles::read(M, FALSE, NULL, FALSE, HTML::incorporate_helper, NULL, OUT) == FALSE) {
		WRITE_TO(STDERR, "CSS filename: %f\n", M);
		internal_error("Unable to open model CSS material for reading");
	}
	HTML::close_CSS(OUT);
}

void HTML::incorporate_HTML(OUTPUT_STREAM, filename *M) {
	if (HTML_incorporation_cache == NULL)
		HTML_incorporation_cache = Dictionaries::new(32, TRUE);
	TEMPORARY_TEXT(key)
	WRITE_TO(key, "%f", M);
	text_stream *existing_entry = Dictionaries::get_text(HTML_incorporation_cache, key);
	if (existing_entry) {
		WRITE("%S", existing_entry);
	} else {
		text_stream *new_entry = Dictionaries::create_text(HTML_incorporation_cache, key);
		HTML::incorporate_HTML_from_file(new_entry, M);
		WRITE("%S", new_entry);
	}
	DISCARD_TEXT(key)
}

void HTML::incorporate_HTML_from_file(OUTPUT_STREAM, filename *M) {
	if (TextFiles::read(M, FALSE, NULL, FALSE, HTML::incorporate_helper, NULL, OUT) == FALSE)
		internal_error("Unable to open model HTML material for reading");
}

@ The helper simply performs a textual copy:

=
void HTML::incorporate_helper(text_stream *line_of_template,
	text_file_position *tfp, void *OUT) {
	WRITE("%S\n", line_of_template);
}

@h Body.

=
void HTML::begin_body(OUTPUT_STREAM, text_stream *class) {
	if (class) HTML_OPEN_WITH("body", "class=\"%S\"", class)
	else HTML_OPEN("body");
}

void HTML::end_body(OUTPUT_STREAM) {
	HTML_CLOSE("body");
	HTML_CLOSE("html");
}

@h Divisions.

=
void HTML::begin_div_with_id(OUTPUT_STREAM, char *id) {
	HTML_OPEN_WITH("div", "id=\"%s\"", id);
}

void HTML::begin_div_with_class(OUTPUT_STREAM, char *cl) {
	HTML_OPEN_WITH("div", "class=\"%s\"", cl);
}

void HTML::begin_div_with_class_and_id(OUTPUT_STREAM, char *cl, char *id, int hide) {
	if (hide) HTML_OPEN_WITH("div", "class=\"%s\" id=\"%s\" style=\"display: none;\"", cl, id)
	else HTML_OPEN_WITH("div", "class=\"%s\" id=\"%s\"", cl, id);
}

void HTML::begin_div_with_id_S(OUTPUT_STREAM, text_stream *id, char *fn, int lc) {
	TEMPORARY_TEXT(details)
	WRITE_TO(details, "id=\"%S\"", id);
	HTML::open(OUT, "div", details, fn, lc);
	DISCARD_TEXT(details)
}

void HTML::begin_div_with_class_S(OUTPUT_STREAM, text_stream *cl, char *fn, int lc) {
	TEMPORARY_TEXT(details)
	WRITE_TO(details, "class=\"%S\"", cl);
	HTML::open(OUT, "div", details, fn, lc);
	DISCARD_TEXT(details)
}

void HTML::begin_div_with_class_and_id_S(OUTPUT_STREAM, text_stream *cl,
	text_stream *id, int hide, char *fn, int lc) {
	TEMPORARY_TEXT(details)
	WRITE_TO(details, "class=\"%S\" id=\"%S\"", cl, id);
	if (hide) WRITE_TO(details, " style=\"display: none;\"");
	HTML::open(OUT, "div", details, fn, lc);
	DISCARD_TEXT(details)
}

void HTML::end_div(OUTPUT_STREAM) {
	HTML_CLOSE("div");
}

@h Images.

=
void HTML::image(OUTPUT_STREAM, filename *F) {
	HTML_TAG_WITH("img", "src=\"%/f\"", F);
}

void HTML::image_to_dimensions(OUTPUT_STREAM, filename *F, text_stream *A, int w, int h) {
	if (Str::len(A) == 0) A = Filenames::get_leafname(F);
	if ((w > 0) && (h > 0)) {
		HTML_TAG_WITH("img", "src=\"%/f\" alt=\"%S\" width=\"%d\" height=\"%d\"", F, A, w, h);
	} else if (w > 0) {
		HTML_TAG_WITH("img", "src=\"%/f\" alt=\"%S\" width=\"%d\"", F, A, w);
	} else if (h > 0) {
		HTML_TAG_WITH("img", "src=\"%/f\" alt=\"%S\" height=\"%d\"", F, A, h);
	} else {
		HTML_TAG_WITH("img", "src=\"%/f\" alt=\"%S\"", F, A);
	}
}

@ Tooltips are the evanescent pop-up windows which appear, a little behind the
mouse arrow, when it is poised waiting over the icon. (Inform makes heavy use of
these in its World index, for instance, to clarify what abbreviations mean.)

=
void HTML::icon_with_tooltip(OUTPUT_STREAM, text_stream *icon_name,
	text_stream *tip, text_stream *tip2) {
	TEMPORARY_TEXT(img)
	WRITE_TO(img, "border=0 src=%S ", icon_name);
	if (tip) {
		WRITE_TO(img, "title=\"%S", tip);
		if (tip2) WRITE_TO(img, " %S", tip2);
		WRITE_TO(img, "\"");
	}
	HTML_TAG_WITH("img", "%S", img);
	DISCARD_TEXT(img)
}

@h Links.

=
void HTML::anchor(OUTPUT_STREAM, text_stream *id) {
	HTML_OPEN_WITH("a", "id=\"%S\"", id); HTML_CLOSE("a");
}

void HTML::anchor_with_class(OUTPUT_STREAM, text_stream *id, text_stream *cl) {
	HTML_OPEN_WITH("a", "id=\"%S\" class=\"%S\"", id, cl); HTML_CLOSE("a");
}

void HTML::begin_link(OUTPUT_STREAM, text_stream *to) {
	HTML_OPEN_WITH("a", "href=\"%S\"", to);
}

void HTML::begin_download_link(OUTPUT_STREAM, text_stream *to) {
	HTML_OPEN_WITH("a", "href=\"%S\" download", to);
}

void HTML::begin_link_with_class(OUTPUT_STREAM, text_stream *cl, text_stream *to) {
	HTML::begin_link_with_class_onclick(OUT, cl, to, NULL);
}

void HTML::begin_link_with_class_title(OUTPUT_STREAM, text_stream *cl, text_stream *to, text_stream *ti) {
	HTML::begin_link_with_class_title_onclick(OUT, cl, to, ti, NULL);
}

void HTML::begin_link_with_class_onclick(OUTPUT_STREAM, text_stream *cl, text_stream *to, text_stream *on) {
	HTML::begin_link_with_class_title_onclick(OUT, cl, to, NULL, on);
}

void HTML::begin_link_with_class_title_onclick(OUTPUT_STREAM, text_stream *cl, text_stream *to, text_stream *ti, text_stream *on) {
	TEMPORARY_TEXT(extras)
	WRITE_TO(extras, "class=\"%S\"", cl);
	if (Str::len(ti) > 0) WRITE_TO(extras, " title=\"%S\"", ti);
	if (Str::len(on) > 0) WRITE_TO(extras, " onclick=\"%S\"", on);
	HTML_OPEN_WITH("a", "href=\"%S\" %S", to, extras);
	DISCARD_TEXT(extras)
}

void HTML::end_link(OUTPUT_STREAM) {
	HTML_CLOSE("a");
}

@ For convenience we keep a global setting for a prefix of a URL which
can be removed. None of that removal happens here; we're just the bookkeeper.

=
pathname *abbreviate_links_within = NULL;
void HTML::set_link_abbreviation_path(pathname *P) {
	abbreviate_links_within = P;
}
pathname *HTML::get_link_abbreviation_path(void) {
	return abbreviate_links_within;
}

@h Tables.
Opening a generic bland table with reasonable column spacing:

=
void HTML::begin_plain_html_table(OUTPUT_STREAM) {
	HTML::begin_html_table(OUT, NULL, FALSE, 0, 0, 0, 0, 0);
}

void HTML::begin_wide_html_table(OUTPUT_STREAM) {
	HTML::begin_html_table(OUT, NULL, TRUE, 0, 0, 0, 0, 0);
}

@ And some more general code:

=
void HTML::begin_html_table(OUTPUT_STREAM, text_stream *classname, int full_width,
	int border, int cellspacing, int cellpadding, int height, int width) {
	TEMPORARY_TEXT(tab)
	WRITE_TO(tab, "border=\"%d\" cellspacing=\"%d\" cellpadding=\"%d\"",
		border, cellspacing, cellpadding);
	if (Str::len(classname) > 0) WRITE_TO(tab, " class=\"%S\"", classname);
	if (full_width) WRITE_TO(tab, " width=100%%");
	if (width > 0) WRITE_TO(tab, " width=\"%d\"", width);
	if (height > 0) WRITE_TO(tab, " height=\"%d\"", height);
	HTML_OPEN_WITH("table", "%S", tab);
	DISCARD_TEXT(tab)
}
void HTML::begin_html_table_bg(OUTPUT_STREAM, text_stream *classname, int full_width,
	int border, int cellspacing, int cellpadding, int height, int width, text_stream *bg) {
	TEMPORARY_TEXT(tab)
	WRITE_TO(tab, "border=\"%d\" cellspacing=\"%d\" cellpadding=\"%d\"",
		border, cellspacing, cellpadding);
	if (Str::len(bg) > 0) WRITE_TO(tab, " background=\"inform:/%S\"", bg);
	if (Str::len(classname) > 0) WRITE_TO(tab, " class=\"%S\"", classname);
	if (full_width) WRITE_TO(tab, " width=100%%");
	if (width > 0) WRITE_TO(tab, " width=\"%d\"", width);
	if (height > 0) WRITE_TO(tab, " height=\"%d\"", height);
	HTML_OPEN_WITH("table", "%S", tab);
	DISCARD_TEXT(tab)
}
void HTML::first_html_column(OUTPUT_STREAM, int width) {
	HTML_OPEN("tr");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\"");
}
void HTML::first_html_column_nowrap(OUTPUT_STREAM, int width, text_stream *classname) {
	if (Str::len(classname) > 0)
		HTML_OPEN_WITH("tr", "class=\"%S\"", classname)
	else
		HTML_OPEN("tr");
	TEMPORARY_TEXT(col)
	WRITE_TO(col, "style=\"white-space:nowrap;\" align=\"left\" valign=\"top\" height=\"20\"");
	if (width > 0) WRITE_TO(col, " width=\"%d\"", width);
	HTML_OPEN_WITH("td", "%S", col);
	DISCARD_TEXT(col)
}
void HTML::first_html_column_spaced(OUTPUT_STREAM, int width) {
	HTML_OPEN("tr");
	TEMPORARY_TEXT(col)
	WRITE_TO(col, "style=\"padding-top: 3px;\" align=\"left\" valign=\"top\"");
	if (width > 0) WRITE_TO(col, " width=\"%d\"", width);
	HTML_OPEN_WITH("td", "%S", col);
	DISCARD_TEXT(col)
}
void HTML::first_html_column_coloured(OUTPUT_STREAM, int width, text_stream *classname,
	int cs) {
	if (Str::len(classname) > 0)
		HTML_OPEN_WITH("tr", "class=\"%S\"", classname)
	else
		HTML_OPEN("tr");
	TEMPORARY_TEXT(col)
	WRITE_TO(col, "nowrap=\"nowrap\" align=\"left\" valign=\"top\"");
	if (width > 0) WRITE_TO(col, " width=\"%d\"", width);
	if (cs > 0) WRITE_TO(col, " colspan=\"%d\"", cs);
	HTML_OPEN_WITH("td", "%S", col);
	DISCARD_TEXT(col)
}
void HTML::next_html_column(OUTPUT_STREAM, int width) {
	WRITE("&nbsp;&nbsp;&nbsp;&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\"");
}
void HTML::next_html_column_centred(OUTPUT_STREAM, int width) {
	WRITE("&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"center\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "align=\"center\" valign=\"top\"");
}
void HTML::next_html_column_spanning(OUTPUT_STREAM, int width, int sp) {
	WRITE("&nbsp;&nbsp;&nbsp;&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\" colspan=\"%d\" width=\"%d\"", sp, width)
	else HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\" colspan=\"%d\"", sp);
}
void HTML::next_html_column_nowrap(OUTPUT_STREAM, int width) {
	WRITE("&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "style=\"white-space:nowrap;\" align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "style=\"white-space:nowrap;\" align=\"left\" valign=\"top\"");
}
void HTML::next_html_column_spaced(OUTPUT_STREAM, int width) {
	WRITE("&nbsp;&nbsp;&nbsp;&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "style=\"padding-top: 3px;\" align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "style=\"padding-top: 3px;\" align=\"left\" valign=\"top\"");
}
void HTML::next_html_column_nw(OUTPUT_STREAM, int width) {
	WRITE("&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "nowrap=\"nowrap\" align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "nowrap=\"nowrap\" align=\"left\" valign=\"top\"");
}
void HTML::next_html_column_w(OUTPUT_STREAM, int width) {
	WRITE("&nbsp;");
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\"");
}
void HTML::next_html_column_right_justified(OUTPUT_STREAM, int width) {
	HTML_CLOSE("td");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"right\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "align=\"right\" valign=\"top\"");
}
void HTML::end_html_row(OUTPUT_STREAM) {
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
}
void HTML::end_html_table(OUTPUT_STREAM) {
	HTML_CLOSE("table");
}

@h Round-rects.

@d CORNER_SIZE 8 /* measured in pixels */
@d ROUND_BOX_TOP 1
@d ROUND_BOX_BOTTOM 2

=
void HTML::open_coloured_box(OUTPUT_STREAM, text_stream *classname, int rounding) {
	HTML_OPEN_WITH("table",
		"width=\"100%%\" cellpadding=\"6\" cellspacing=\"0\" border=\"0\" "
		"class=\"%S\"", classname);
	HTML_OPEN("tr");
	HTML_OPEN("td");
}

void HTML::close_coloured_box(OUTPUT_STREAM, text_stream *classname, int rounding) {
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML::end_html_table(OUT);
}

void HTML::box_corner(OUTPUT_STREAM, text_stream *classname, text_stream *corner) {
	HTML_TAG_WITH("img",
		"src=\"inform:/bg_images/%S_corner_%S.gif\" "
		"width=\"%d\" height=\"%d\" border=\"0\" alt=\"...\"",
		corner, classname, CORNER_SIZE, CORNER_SIZE);
}

@h Miscellaneous.

=
void HTML::comment(OUTPUT_STREAM, text_stream *text) {
	WRITE("<!-- %S -->\n", text);
}

void HTML::heading(OUTPUT_STREAM, char *tag, text_stream *text) {
	HTML_OPEN(tag);
	WRITE("%S", text);
	HTML_CLOSE(tag);
	WRITE("\n");
}

void HTML::hr(OUTPUT_STREAM, char *class) {
	if (class) HTML_TAG_WITH("hr", "class=\"%s\"", class)
	else HTML_TAG("hr");
}

@h HTML colours.
Inform uses these when constructing the map in the World index.

=
typedef struct colour_translation {
	inchar32_t *chip_name;
	inchar32_t *html_colour;
} colour_translation;

colour_translation table_of_translations[] = {
	{ U"Alice Blue", U"F0F8FF" },
	{ U"Antique White", U"FAEBD7" },
	{ U"Aqua", U"00FFFF" },
	{ U"Aquamarine", U"7FFFD4" },
	{ U"Azure", U"F0FFFF" },
	{ U"Beige", U"F5F5DC" },
	{ U"Bisque", U"FFE4C4" },
	{ U"Black", U"000000" },
	{ U"Blanched Almond", U"FFEBCD" },
	{ U"Blue", U"0000FF" },
	{ U"Blue Violet", U"8A2BE2" },
	{ U"Brown", U"A52A2A" },
	{ U"Burly Wood", U"DEB887" },
	{ U"Cadet Blue", U"5F9EA0" },
	{ U"Chartreuse", U"7FFF00" },
	{ U"Chocolate", U"D2691E" },
	{ U"Coral", U"FF7F50" },
	{ U"Cornflower Blue", U"6495ED" },
	{ U"Cornsilk", U"FFF8DC" },
	{ U"Crimson", U"DC143C" },
	{ U"Cyan", U"00FFFF" },
	{ U"Dark Blue", U"00008B" },
	{ U"Dark Cyan", U"008B8B" },
	{ U"Dark Golden Rod", U"B8860B" },
	{ U"Dark Gray", U"A9A9A9" },
	{ U"Dark Green", U"006400" },
	{ U"Dark Khaki", U"BDB76B" },
	{ U"Dark Magenta", U"8B008B" },
	{ U"Dark Olive Green", U"556B2F" },
	{ U"Dark Orange", U"FF8C00" },
	{ U"Dark Orchid", U"9932CC" },
	{ U"Dark Red", U"8B0000" },
	{ U"Dark Salmon", U"E9967A" },
	{ U"Dark Sea Green", U"8FBC8F" },
	{ U"Dark Slate Blue", U"483D8B" },
	{ U"Dark Slate Gray", U"2F4F4F" },
	{ U"Dark Turquoise", U"00CED1" },
	{ U"Dark Violet", U"9400D3" },
	{ U"Deep Pink", U"FF1493" },
	{ U"Deep Sky Blue", U"00BFFF" },
	{ U"Dim Gray", U"696969" },
	{ U"Dodger Blue", U"1E90FF" },
	{ U"Feldspar", U"D19275" },
	{ U"Fire Brick", U"B22222" },
	{ U"Floral White", U"FFFAF0" },
	{ U"Forest Green", U"228B22" },
	{ U"Fuchsia", U"FF00FF" },
	{ U"Gainsboro", U"DCDCDC" },
	{ U"Ghost White", U"F8F8FF" },
	{ U"Gold", U"FFD700" },
	{ U"Golden Rod", U"DAA520" },
	{ U"Gray", U"808080" },
	{ U"Green", U"008000" },
	{ U"Green Yellow", U"ADFF2F" },
	{ U"Honey Dew", U"F0FFF0" },
	{ U"Hot Pink", U"FF69B4" },
	{ U"Indian Red", U"CD5C5C" },
	{ U"Indigo", U"4B0082" },
	{ U"Ivory", U"FFFFF0" },
	{ U"Khaki", U"F0E68C" },
	{ U"Lavender", U"E6E6FA" },
	{ U"Lavender Blush", U"FFF0F5" },
	{ U"Lawn Green", U"7CFC00" },
	{ U"Lemon Chiffon", U"FFFACD" },
	{ U"Light Blue", U"ADD8E6" },
	{ U"Light Coral", U"F08080" },
	{ U"Light Cyan", U"E0FFFF" },
	{ U"Light Golden Rod Yellow", U"FAFAD2" },
	{ U"Light Grey", U"D3D3D3" },
	{ U"Light Green", U"90EE90" },
	{ U"Light Pink", U"FFB6C1" },
	{ U"Light Salmon", U"FFA07A" },
	{ U"Light Sea Green", U"20B2AA" },
	{ U"Light Sky Blue", U"87CEFA" },
	{ U"Light Slate Blue", U"8470FF" },
	{ U"Light Slate Gray", U"778899" },
	{ U"Light Steel Blue", U"B0C4DE" },
	{ U"Light Yellow", U"FFFFE0" },
	{ U"Lime", U"00FF00" },
	{ U"Lime Green", U"32CD32" },
	{ U"Linen", U"FAF0E6" },
	{ U"Magenta", U"FF00FF" },
	{ U"Maroon", U"800000" },
	{ U"Medium Aquamarine", U"66CDAA" },
	{ U"Medium Blue", U"0000CD" },
	{ U"Medium Orchid", U"BA55D3" },
	{ U"Medium Purple", U"9370D8" },
	{ U"Medium Sea Green", U"3CB371" },
	{ U"Medium Slate Blue", U"7B68EE" },
	{ U"Medium Spring Green", U"00FA9A" },
	{ U"Medium Turquoise", U"48D1CC" },
	{ U"Medium Violet Red", U"CA226B" },
	{ U"Midnight Blue", U"191970" },
	{ U"Mint Cream", U"F5FFFA" },
	{ U"Misty Rose", U"FFE4E1" },
	{ U"Moccasin", U"FFE4B5" },
	{ U"Navajo White", U"FFDEAD" },
	{ U"Navy", U"000080" },
	{ U"Old Lace", U"FDF5E6" },
	{ U"Olive", U"808000" },
	{ U"Olive Drab", U"6B8E23" },
	{ U"Orange", U"FFA500" },
	{ U"Orange Red", U"FF4500" },
	{ U"Orchid", U"DA70D6" },
	{ U"Pale Golden Rod", U"EEE8AA" },
	{ U"Pale Green", U"98FB98" },
	{ U"Pale Turquoise", U"AFEEEE" },
	{ U"Pale Violet Red", U"D87093" },
	{ U"Papaya Whip", U"FFEFD5" },
	{ U"Peach Puff", U"FFDAB9" },
	{ U"Peru", U"CD853F" },
	{ U"Pink", U"FFC0CB" },
	{ U"Plum", U"DDA0DD" },
	{ U"Powder Blue", U"B0E0E6" },
	{ U"Purple", U"800080" },
	{ U"Red", U"FF0000" },
	{ U"Rosy Brown", U"BC8F8F" },
	{ U"Royal Blue", U"4169E1" },
	{ U"Saddle Brown", U"8B4513" },
	{ U"Salmon", U"FA8072" },
	{ U"Sandy Brown", U"F4A460" },
	{ U"Sea Green", U"2E8B57" },
	{ U"Sea Shell", U"FFF5EE" },
	{ U"Sienna", U"A0522D" },
	{ U"Silver", U"C0C0C0" },
	{ U"Sky Blue", U"87CEEB" },
	{ U"Slate Blue", U"6A5ACD" },
	{ U"Slate Gray", U"708090" },
	{ U"Snow", U"FFFAFA" },
	{ U"Spring Green", U"00FF7F" },
	{ U"Steel Blue", U"4682B4" },
	{ U"Tan", U"D2B48C" },
	{ U"Teal", U"008080" },
	{ U"Thistle", U"D8BFD8" },
	{ U"Tomato", U"FF6347" },
	{ U"Turquoise", U"40E0D0" },
	{ U"Violet", U"EE82EE" },
	{ U"Violet Red", U"D02090" },
	{ U"Wheat", U"F5DEB3" },
	{ U"White", U"FFFFFF" },
	{ U"White Smoke", U"F5F5F5" },
	{ U"Yellow", U"FFFF00" },
	{ U"Yellow Green", U"9ACD32" },
	{ U"", U"" }
};

@ The following is used only a handful of times, if at all, and does not
need to run quickly.

=
inchar32_t *HTML::translate_colour_name(inchar32_t *original) {
	for (int j=0; Wide::cmp(table_of_translations[j].chip_name, U""); j++)
		if (Wide::cmp(table_of_translations[j].chip_name, original) == 0)
			return table_of_translations[j].html_colour;
	return NULL;
}

@ =
void HTML::begin_colour(OUTPUT_STREAM, text_stream *col) {
	HTML_OPEN_WITH("span", "style='color:#%S'", col);
}
void HTML::end_colour(OUTPUT_STREAM) {
	HTML_CLOSE("span");
}

@h Spans by class.

=
void HTML::begin_span(OUTPUT_STREAM, text_stream *class_name) {
	if (Str::len(class_name) > 0) {
		HTML_OPEN_WITH("span", "class=\"%S\"", class_name);
	} else {
		HTML_OPEN("span");
	}
}
void HTML::end_span(OUTPUT_STREAM) {
	HTML_CLOSE("span");
}

@h Writing text.
To begin with, to XML:

=
void HTML::write_xml_safe_text(OUTPUT_STREAM, text_stream *txt) {
	LOOP_THROUGH_TEXT(pos, txt) {
		inchar32_t c = Str::get(pos);
		switch(c) {
			case '&': WRITE("&amp;"); break;
			case '<': WRITE("&lt;"); break;
			case '>': WRITE("&gt;"); break;
			default: PUT(c); break;
		}
	}
}

@ And now to HTML. This would be very similar, except:

- if the |words| and |html| modules are both present, we recognise
|*source text*Source/story.ni*14*| as something which should expand to a
source code link -- except that the much less commonly occurring
|SOURCE_REF_CHAR| character code is used in place of the asterisk;
- if the |problems| module is present, we recognise |FORCE_NEW_PARA_CHAR|
as a paragraph break.

These two special case characters are lower and upper case Icelandic eth,
respectively. These do not occur in Inform source text.

@d SOURCE_REF_CHAR L'\xf0'
@d FORCE_NEW_PARA_CHAR L'\xd0'

=
text_stream *source_ref_fields[3] = { NULL, NULL, NULL }; /* paraphrase, filename, line */
int source_ref_field = -1; /* which field we are buffering */

void HTML::put(OUTPUT_STREAM, inchar32_t charcode) {
	@<Buffer into one of the source reference fields@>;
	switch(charcode) {
		case '"': WRITE("&quot;"); break;
		case '<': WRITE("&lt;"); break;
		case '>': WRITE("&gt;"); break;
		case '&': WRITE("&amp;"); break;
		case NEWLINE_IN_STRING: HTML_TAG("br"); break;

		#ifdef PROBLEMS_MODULE
		case FORCE_NEW_PARA_CHAR: HTML_CLOSE("p"); HTML_OPEN_WITH("p", "class=\"in2\"");
			HTML::icon_with_tooltip(OUT, I"inform:/doc_images/ornament_flower.png", NULL, NULL);
			WRITE("&nbsp;"); break;
		#endif

		#ifdef WORDS_MODULE
		case SOURCE_REF_CHAR: @<Deal with a source reference field divider@>; break;
		#endif

		default: PUT(charcode); break;
	}
}

@<Buffer into one of the source reference fields@> =
	if ((source_ref_field >= 0) && (charcode != SOURCE_REF_CHAR)) {
		PUT_TO(source_ref_fields[source_ref_field], charcode); return;
	}

@<Deal with a source reference field divider@> =
	source_ref_field++;
	if (source_ref_field == 3) {
		source_ref_field = -1;
		source_location sl;
		sl.file_of_origin = TextFromFiles::filename_to_source_file(source_ref_fields[1]);
		sl.line_number = Str::atoi(source_ref_fields[2], 0);
		#ifdef HTML_MODULE
		SourceLinks::link(OUT, sl, TRUE);
		#endif
	} else {
		if (source_ref_fields[source_ref_field] == NULL)
			source_ref_fields[source_ref_field] = Str::new();
		Str::clear(source_ref_fields[source_ref_field]);
	}
