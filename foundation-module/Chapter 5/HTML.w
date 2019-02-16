[HTML::] HTML.

Utility functions for writing HTML.

@h Abstraction.
Though the code below does nothing at all interesting, to put it mildly,
it's written a little defensively, to increase the chances that the client
is producing valid HTML with it. In particular, the client won't be
allowed to open a |p| tag, then open a |b| tag, then close the |p|, then
close the |b|: that would be wrongly nested. We want to throw errors like
that into the debugging log, so:

@d tag_error(x) { LOG("Tag error: %s\n", x); }

@ Any text stream can be declared as being HTML, and therefore subject to
this auditing. To do that, we atach an |HTML_file_state| object to the
text stream.

=
typedef struct HTML_file_state {
	int XHTML_flag; /* writing strict XHTML for use in epubs */
	struct lifo_stack *tag_stack; /* of |HTML_tag|: those currently open */
	int CSS_included;
	int JS_included;
	MEMORY_MANAGEMENT
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
	MEMORY_MANAGEMENT
} HTML_tag;

int HTML::push_tag(OUTPUT_STREAM, char *tag) {
	int u = unique_xref++;
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) {
		HTML_tag *ht = CREATE(HTML_tag);
		ht->tag_name = tag;
		ht->tag_xref = u;
		PUSH_TO_LIFO_STACK(ht, HTML_tag, hs->tag_stack);
	}
	return u;
}

@ =
void HTML::pop_tag(OUTPUT_STREAM, char *tag) {
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) {
		if (LIFO_STACK_EMPTY(HTML_tag, hs->tag_stack)) {
			LOG("{tag: %s}\n", tag);
			tag_error("closed HTML tag which wasn't open");
		} else {
			HTML_tag *ht = TOP_OF_LIFO_STACK(HTML_tag, hs->tag_stack);
			if (strcmp(tag, ht->tag_name) != 0) {
				LOG("{expected to close tag %s (%d), but actually closed %s}\n",
					ht->tag_name, ht->tag_xref, tag);
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
		HTML_tag *ht;
		int i = 0;
		LOG("HTML tag stack: ");
		LOOP_DOWN_LIFO_STACK(ht, HTML_tag, hs->tag_stack) {
			if (i++ > 0) LOG(" in ");
			LOG("%s (%d)", ht->tag_name, ht->tag_xref);
		}
		LOG("\n");
		tag_error("HTML tags still open");
	}
}

@ We will open and close all HTML tags using the following macros, two
of which are variadic and have to be written out the old-fashioned way:

@d HTML_TAG(tag) HTML::tag(OUT, tag, NULL);
@d HTML_OPEN(tag) HTML::open(OUT, tag, NULL);
@d HTML_CLOSE(tag) HTML::close(OUT, tag);

=
#define HTML_TAG_WITH(tag, args...) { \
	TEMPORARY_TEXT(details); \
	WRITE_TO(details, args); \
	HTML::tag(OUT, tag, details); \
	DISCARD_TEXT(details); \
}

#define HTML_OPEN_WITH(tag, args...) { \
	TEMPORARY_TEXT(details); \
	WRITE_TO(details, args); \
	HTML::open(OUT, tag, details); \
	DISCARD_TEXT(details); \
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

void HTML::open(OUTPUT_STREAM, char *tag, text_stream *details) {
	int f = HTML::pair_formatting(tag);
	HTML::push_tag(OUT, tag);
	WRITE("<%s", tag);
	if (Str::len(details) > 0) WRITE(" %S", details);
	WRITE(">");
	if (f >= 2) { WRITE("\n"); INDENT; }
}

void HTML::close(OUTPUT_STREAM, char *tag) {
	int f = HTML::pair_formatting(tag);
	if (f >= 3) WRITE("\n");
	if (f >= 2) OUTDENT;
	WRITE("</%s>", tag);
	HTML::pop_tag(OUT, tag);
	if (f >= 1) WRITE("\n");
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
		#ifdef WINDOWS_JAVASCRIPT
		WRITE("return external.Project;\n");
		#endif
		#ifndef WINDOWS_JAVASCRIPT
		WRITE("return window.Project;\n");
		#endif
		OUTDENT; WRITE("}\n");
	}
}

void HTML::close_javascript(OUTPUT_STREAM) {
	HTML_CLOSE("script");
}

void HTML::incorporate_javascript(OUTPUT_STREAM, int define_project, filename *M) {
	HTML::open_javascript(OUT, define_project);
	if (TextFiles::read(M, FALSE, NULL, FALSE, HTML::incorporate_helper, NULL, OUT) == FALSE) {
		WRITE_TO(STDERR, "%f", M);
		internal_error("Unable to open model JS material for reading");
	}
	HTML::close_javascript(OUT);
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) hs->JS_included++;
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
	HTML::open_CSS(OUT);
	if (TextFiles::read(M, FALSE, NULL, FALSE, HTML::incorporate_helper, NULL, OUT) == FALSE)
		internal_error("Unable to open model CSS material for reading");
	HTML::close_CSS(OUT);
	HTML_file_state *hs = Streams::get_HTML_file_state(OUT);
	if (hs) hs->CSS_included++;
}

void HTML::incorporate_HTML(OUTPUT_STREAM, filename *M) {
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

void HTML::begin_div_with_id_S(OUTPUT_STREAM, text_stream *id) {
	TEMPORARY_TEXT(details);
	WRITE_TO(details, "id=\"%S\"", id);
	HTML::open(OUT, "div", details);
	DISCARD_TEXT(details);
}

void HTML::begin_div_with_class_S(OUTPUT_STREAM, text_stream *cl) {
	TEMPORARY_TEXT(details);
	WRITE_TO(details, "class=\"%S\"", cl);
	HTML::open(OUT, "div", details);
	DISCARD_TEXT(details);
}

void HTML::begin_div_with_class_and_id_S(OUTPUT_STREAM, text_stream *cl, text_stream *id, int hide) {
	TEMPORARY_TEXT(details);
	WRITE_TO(details, "class=\"%S\" id=\"%S\"", cl, id);
	if (hide) WRITE_TO(details, " style=\"display: none;\"");
	HTML::open(OUT, "div", details);
	DISCARD_TEXT(details);
}

void HTML::end_div(OUTPUT_STREAM) {
	HTML_CLOSE("div");
}

@h Images.

=
void HTML::image(OUTPUT_STREAM, filename *F) {
	HTML_TAG_WITH("img", "src=\"%/f\"", F);
}

@h Links.

=
void HTML::anchor(OUTPUT_STREAM, text_stream *id) {
	HTML_OPEN_WITH("a", "id=\"%S\"", id); HTML_CLOSE("a");
}

void HTML::begin_link(OUTPUT_STREAM, text_stream *to) {
	HTML_OPEN_WITH("a", "href=\"%S\"", to);
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
	WRITE("<a href=\"%S\" class=\"%S\"", to, cl);
	if (Str::len(ti) > 0) WRITE(" title=\"%S\"", ti);
	if (Str::len(on) > 0) WRITE(" onclick=\"%S\"", on);
	WRITE(">");
}


void HTML::end_link(OUTPUT_STREAM) {
	HTML_CLOSE("a");
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
void HTML::begin_html_table(OUTPUT_STREAM, char *colour, int full_width,
	int border, int cellspacing, int cellpadding, int height, int width) {
	TEMPORARY_TEXT(tab);
	WRITE_TO(tab, "border=\"%d\" cellspacing=\"%d\" cellpadding=\"%d\"",
		border, cellspacing, cellpadding);
	if (colour) {
		if (*colour == '*')
			WRITE_TO(tab, "  style=\"background-image:url('inform:/%s');\"", colour+1);
		else
			WRITE_TO(tab, " bgcolor=\"%s\"", colour);
	}
	if (full_width) WRITE_TO(tab, " width=100%%");
	if (width > 0) WRITE_TO(tab, " width=\"%d\"", width);
	if (height > 0) WRITE_TO(tab, " height=\"%d\"", height);
	HTML_OPEN_WITH("table", "%S", tab);
	DISCARD_TEXT(tab);
}
void HTML::begin_html_table_bg(OUTPUT_STREAM, char *colour, int full_width,
	int border, int cellspacing, int cellpadding, int height, int width, char *bg) {
	TEMPORARY_TEXT(tab);
	WRITE_TO(tab, "border=\"%d\" cellspacing=\"%d\" cellpadding=\"%d\"",
		border, cellspacing, cellpadding);
	if (bg) WRITE_TO(tab, " background=\"inform:/map_icons/%s\"", bg);
	if (colour) WRITE_TO(tab, " bgcolor=\"%s\"", colour);
	if (full_width) WRITE_TO(tab, " width=100%%");
	if (width > 0) WRITE_TO(tab, " width=\"%d\"", width);
	if (height > 0) WRITE_TO(tab, " height=\"%d\"", height);
	HTML_OPEN_WITH("table", "%S", tab);
	DISCARD_TEXT(tab);
}
void HTML::first_html_column(OUTPUT_STREAM, int width) {
	HTML_OPEN("tr");
	if (width > 0) HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\" width=\"%d\"", width)
	else HTML_OPEN_WITH("td", "align=\"left\" valign=\"top\"");
}
void HTML::first_html_column_nowrap(OUTPUT_STREAM, int width, char *colour) {
	if (colour) HTML_OPEN_WITH("tr", "bgcolor=\"%s\"", colour) else HTML_OPEN("tr");
	TEMPORARY_TEXT(col);
	WRITE_TO(col, "style=\"white-space:nowrap;\" align=\"left\" valign=\"top\" height=\"20\"");
	if (width > 0) WRITE_TO(col, " width=\"%d\"", width);
	HTML_OPEN_WITH("td", "%S", col);
	DISCARD_TEXT(col);
}
void HTML::first_html_column_spaced(OUTPUT_STREAM, int width) {
	HTML_OPEN("tr");
	TEMPORARY_TEXT(col);
	WRITE_TO(col, "style=\"padding-top: 3px;\" align=\"left\" valign=\"top\"");
	if (width > 0) WRITE_TO(col, " width=\"%d\"", width);
	HTML_OPEN_WITH("td", "%S", col);
	DISCARD_TEXT(col);
}
void HTML::first_html_column_coloured(OUTPUT_STREAM, int width, char *colour, int cs) {
	if (colour) HTML_OPEN_WITH("tr", "bgcolor=\"%s\"", colour) else HTML_OPEN("tr");
	TEMPORARY_TEXT(col);
	WRITE_TO(col, "nowrap=\"nowrap\" align=\"left\" valign=\"top\"");
	if (width > 0) WRITE_TO(col, " width=\"%d\"", width);
	if (cs > 0) WRITE_TO(col, " colspan=\"%d\"", cs);
	HTML_OPEN_WITH("td", "%S", col);
	DISCARD_TEXT(col);
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
void HTML::open_coloured_box(OUTPUT_STREAM, char *html_colour, int rounding) {
	HTML_OPEN_WITH("table",
		"width=\"100%%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" "
		"style=\"background-color: #%s\"", html_colour);
	HTML_OPEN("tr");
	HTML_OPEN_WITH("td", "width=\"%d\"", CORNER_SIZE);
	if (rounding & ROUND_BOX_TOP) HTML::box_corner(OUT, html_colour, "tl");
	HTML_CLOSE("td");
	HTML_OPEN("td");
	HTML_CLOSE("td");
	HTML_OPEN_WITH("td", "width=\"%d\"", CORNER_SIZE);
	if (rounding & ROUND_BOX_TOP) HTML::box_corner(OUT, html_colour, "tr");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML_OPEN("tr");
	HTML_OPEN_WITH("td", "width=\"%d\"", CORNER_SIZE);
	HTML_CLOSE("td");
	HTML_OPEN("td");
}

void HTML::close_coloured_box(OUTPUT_STREAM, char *html_colour, int rounding) {
	HTML_CLOSE("td");
	HTML_OPEN_WITH("td", "width=\"%d\"", CORNER_SIZE);
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML_OPEN("tr");
	HTML_OPEN_WITH("td", "width=\"%d\"", CORNER_SIZE);
	if (rounding & ROUND_BOX_BOTTOM) HTML::box_corner(OUT, html_colour, "bl");
	HTML_CLOSE("td");
	HTML_OPEN("td");
	HTML_CLOSE("td");
	HTML_OPEN_WITH("td", "width=\"%d\"", CORNER_SIZE);
	if (rounding & ROUND_BOX_BOTTOM) HTML::box_corner(OUT, html_colour, "br");
	HTML_CLOSE("td");
	HTML_CLOSE("tr");
	HTML::end_html_table(OUT);
}

void HTML::box_corner(OUTPUT_STREAM, char *html_colour, char *corner) {
	HTML_TAG_WITH("img",
		"src=\"inform:/bg_images/%s_corner_%s.gif\" "
		"width=\"%d\" height=\"%d\" border=\"0\" alt=\"...\"",
		corner, html_colour, CORNER_SIZE, CORNER_SIZE);
}

@h Miscellaneous.

=
void HTML::comment(OUTPUT_STREAM, text_stream *text) {
	WRITE("<!--%S-->\n", text);
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
	wchar_t *chip_name;
	wchar_t *html_colour;
} colour_translation;

colour_translation table_of_translations[] = {
	{ L"Alice Blue", L"F0F8FF" },
	{ L"Antique White", L"FAEBD7" },
	{ L"Aqua", L"00FFFF" },
	{ L"Aquamarine", L"7FFFD4" },
	{ L"Azure", L"F0FFFF" },
	{ L"Beige", L"F5F5DC" },
	{ L"Bisque", L"FFE4C4" },
	{ L"Black", L"000000" },
	{ L"Blanched Almond", L"FFEBCD" },
	{ L"Blue", L"0000FF" },
	{ L"Blue Violet", L"8A2BE2" },
	{ L"Brown", L"A52A2A" },
	{ L"Burly Wood", L"DEB887" },
	{ L"Cadet Blue", L"5F9EA0" },
	{ L"Chartreuse", L"7FFF00" },
	{ L"Chocolate", L"D2691E" },
	{ L"Coral", L"FF7F50" },
	{ L"Cornflower Blue", L"6495ED" },
	{ L"Cornsilk", L"FFF8DC" },
	{ L"Crimson", L"DC143C" },
	{ L"Cyan", L"00FFFF" },
	{ L"Dark Blue", L"00008B" },
	{ L"Dark Cyan", L"008B8B" },
	{ L"Dark Golden Rod", L"B8860B" },
	{ L"Dark Gray", L"A9A9A9" },
	{ L"Dark Green", L"006400" },
	{ L"Dark Khaki", L"BDB76B" },
	{ L"Dark Magenta", L"8B008B" },
	{ L"Dark Olive Green", L"556B2F" },
	{ L"Dark Orange", L"FF8C00" },
	{ L"Dark Orchid", L"9932CC" },
	{ L"Dark Red", L"8B0000" },
	{ L"Dark Salmon", L"E9967A" },
	{ L"Dark Sea Green", L"8FBC8F" },
	{ L"Dark Slate Blue", L"483D8B" },
	{ L"Dark Slate Gray", L"2F4F4F" },
	{ L"Dark Turquoise", L"00CED1" },
	{ L"Dark Violet", L"9400D3" },
	{ L"Deep Pink", L"FF1493" },
	{ L"Deep Sky Blue", L"00BFFF" },
	{ L"Dim Gray", L"696969" },
	{ L"Dodger Blue", L"1E90FF" },
	{ L"Feldspar", L"D19275" },
	{ L"Fire Brick", L"B22222" },
	{ L"Floral White", L"FFFAF0" },
	{ L"Forest Green", L"228B22" },
	{ L"Fuchsia", L"FF00FF" },
	{ L"Gainsboro", L"DCDCDC" },
	{ L"Ghost White", L"F8F8FF" },
	{ L"Gold", L"FFD700" },
	{ L"Golden Rod", L"DAA520" },
	{ L"Gray", L"808080" },
	{ L"Green", L"008000" },
	{ L"Green Yellow", L"ADFF2F" },
	{ L"Honey Dew", L"F0FFF0" },
	{ L"Hot Pink", L"FF69B4" },
	{ L"Indian Red", L"CD5C5C" },
	{ L"Indigo", L"4B0082" },
	{ L"Ivory", L"FFFFF0" },
	{ L"Khaki", L"F0E68C" },
	{ L"Lavender", L"E6E6FA" },
	{ L"Lavender Blush", L"FFF0F5" },
	{ L"Lawn Green", L"7CFC00" },
	{ L"Lemon Chiffon", L"FFFACD" },
	{ L"Light Blue", L"ADD8E6" },
	{ L"Light Coral", L"F08080" },
	{ L"Light Cyan", L"E0FFFF" },
	{ L"Light Golden Rod Yellow", L"FAFAD2" },
	{ L"Light Grey", L"D3D3D3" },
	{ L"Light Green", L"90EE90" },
	{ L"Light Pink", L"FFB6C1" },
	{ L"Light Salmon", L"FFA07A" },
	{ L"Light Sea Green", L"20B2AA" },
	{ L"Light Sky Blue", L"87CEFA" },
	{ L"Light Slate Blue", L"8470FF" },
	{ L"Light Slate Gray", L"778899" },
	{ L"Light Steel Blue", L"B0C4DE" },
	{ L"Light Yellow", L"FFFFE0" },
	{ L"Lime", L"00FF00" },
	{ L"Lime Green", L"32CD32" },
	{ L"Linen", L"FAF0E6" },
	{ L"Magenta", L"FF00FF" },
	{ L"Maroon", L"800000" },
	{ L"Medium Aquamarine", L"66CDAA" },
	{ L"Medium Blue", L"0000CD" },
	{ L"Medium Orchid", L"BA55D3" },
	{ L"Medium Purple", L"9370D8" },
	{ L"Medium Sea Green", L"3CB371" },
	{ L"Medium Slate Blue", L"7B68EE" },
	{ L"Medium Spring Green", L"00FA9A" },
	{ L"Medium Turquoise", L"48D1CC" },
	{ L"Medium Violet Red", L"CA226B" },
	{ L"Midnight Blue", L"191970" },
	{ L"Mint Cream", L"F5FFFA" },
	{ L"Misty Rose", L"FFE4E1" },
	{ L"Moccasin", L"FFE4B5" },
	{ L"Navajo White", L"FFDEAD" },
	{ L"Navy", L"000080" },
	{ L"Old Lace", L"FDF5E6" },
	{ L"Olive", L"808000" },
	{ L"Olive Drab", L"6B8E23" },
	{ L"Orange", L"FFA500" },
	{ L"Orange Red", L"FF4500" },
	{ L"Orchid", L"DA70D6" },
	{ L"Pale Golden Rod", L"EEE8AA" },
	{ L"Pale Green", L"98FB98" },
	{ L"Pale Turquoise", L"AFEEEE" },
	{ L"Pale Violet Red", L"D87093" },
	{ L"Papaya Whip", L"FFEFD5" },
	{ L"Peach Puff", L"FFDAB9" },
	{ L"Peru", L"CD853F" },
	{ L"Pink", L"FFC0CB" },
	{ L"Plum", L"DDA0DD" },
	{ L"Powder Blue", L"B0E0E6" },
	{ L"Purple", L"800080" },
	{ L"Red", L"FF0000" },
	{ L"Rosy Brown", L"BC8F8F" },
	{ L"Royal Blue", L"4169E1" },
	{ L"Saddle Brown", L"8B4513" },
	{ L"Salmon", L"FA8072" },
	{ L"Sandy Brown", L"F4A460" },
	{ L"Sea Green", L"2E8B57" },
	{ L"Sea Shell", L"FFF5EE" },
	{ L"Sienna", L"A0522D" },
	{ L"Silver", L"C0C0C0" },
	{ L"Sky Blue", L"87CEEB" },
	{ L"Slate Blue", L"6A5ACD" },
	{ L"Slate Gray", L"708090" },
	{ L"Snow", L"FFFAFA" },
	{ L"Spring Green", L"00FF7F" },
	{ L"Steel Blue", L"4682B4" },
	{ L"Tan", L"D2B48C" },
	{ L"Teal", L"008080" },
	{ L"Thistle", L"D8BFD8" },
	{ L"Tomato", L"FF6347" },
	{ L"Turquoise", L"40E0D0" },
	{ L"Violet", L"EE82EE" },
	{ L"Violet Red", L"D02090" },
	{ L"Wheat", L"F5DEB3" },
	{ L"White", L"FFFFFF" },
	{ L"White Smoke", L"F5F5F5" },
	{ L"Yellow", L"FFFF00" },
	{ L"Yellow Green", L"9ACD32" },
	{ L"", L"" }
};

@ The following is used only a handful of times, if at all, and does not
need to run quickly.

=
wchar_t *HTML::translate_colour_name(wchar_t *original) {
	for (int j=0; Wide::cmp(table_of_translations[j].chip_name, L""); j++)
		if (Wide::cmp(table_of_translations[j].chip_name, original) == 0)
			return table_of_translations[j].html_colour;
	return NULL;
}

@ =
void HTML::begin_colour(OUTPUT_STREAM, text_stream *col) {
	HTML_OPEN_WITH("span", "style=\"color:#%S\"", col);
}
void HTML::end_colour(OUTPUT_STREAM) {
	HTML_CLOSE("span");
}
