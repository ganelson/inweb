[MarkdownRenderer::] Markdown Rendering.

To render a Markdown tree as HTML.

@h Rendering.
This is blessedly simple by comparison with parsing, but there are some
pitfalls to look out for just the same.

We preserve a piece of state called the |mode| as we recurse downwards
through the tree: it's a bitmap composed of the following.

@d TAGS_MDRMODE    1     /* Render HTML tags? */
@d ESCAPES_MDRMODE 2     /* Treat backslash followed by ASCII punctuation as an escape? */
@d URI_MDRMODE     4     /* Encode characters as they need to appear in a URI */
@d RAW_MDRMODE     8     /* Treat all characters literally */
@d LOOSE_MDRMODE  16     /* Wrap list items in paragraph tags */
@d ENTITIES_MDRMODE 32   /* Convert |&etc;| to whatever it ought to represent */

=
void MarkdownRenderer::go(OUTPUT_STREAM, markdown_item *md) {
	MarkdownRenderer::recurse(OUT, md, TAGS_MDRMODE | ESCAPES_MDRMODE | ENTITIES_MDRMODE);
}

void MarkdownRenderer::recurse(OUTPUT_STREAM, markdown_item *md, int mode) {
	if (md == NULL) return;
	switch (md->type) {
		case DOCUMENT_MIT: 	     @<Recurse@>;
								 break;
		case HEADING_MIT:        @<Render a heading@>;
								 WRITE("\n");
								 break;
		case PARAGRAPH_MIT:      if (mode & TAGS_MDRMODE) HTML_OPEN("p");
								 @<Recurse@>;
								 if (mode & TAGS_MDRMODE) HTML_CLOSE("p");
								 break;
		case BLOCK_QUOTE_MIT:    // if (md->down) {
									 if (mode & TAGS_MDRMODE) HTML_OPEN("blockquote");
									 WRITE("\n");
									 @<Recurse@>;
									 if (mode & TAGS_MDRMODE) HTML_CLOSE("blockquote");
								//  }
								 break;
		case CODE_BLOCK_MIT:     @<Render a code block@>; break;
		case ORDERED_LIST_ITEM_MIT:
		case UNORDERED_LIST_ITEM_MIT:
								 @<Render a list item@>; break;
		case ORDERED_LIST_MIT:   if (mode & TAGS_MDRMODE) {
									int start = md->down->details;
									if (start < 0) start = -(start+1);
									if (start != 1) {
										HTML_OPEN_WITH("ol", "start=\"%d\"", start);
								    } else {
										HTML_OPEN("ol");
									}
								 }
								 WRITE("\n");
								 @<Recurse through list@>;
								 if (mode & TAGS_MDRMODE) HTML_CLOSE("ol");
								 WRITE("\n");
								 break;
		case UNORDERED_LIST_MIT: if (mode & TAGS_MDRMODE) HTML_OPEN("ul");
								 WRITE("\n");
								 @<Recurse through list@>;
								 if (mode & TAGS_MDRMODE) HTML_CLOSE("ul");
								 WRITE("\n");
								 break;
		case HTML_MIT:           @<Render a raw HTML block@>; break;
		case THEMATIC_MIT:       if (mode & TAGS_MDRMODE) WRITE("<hr />\n"); break;
		case LINK_REF_MIT:       break;
		case MATERIAL_MIT: 	     @<Recurse@>;
								 break;
		case PLAIN_MIT:    	     MarkdownRenderer::slice(OUT, md, mode);
								 break;
		case EMPHASIS_MIT: 	     if (mode & TAGS_MDRMODE) HTML_OPEN("em");
								 @<Recurse@>;
								 if (mode & TAGS_MDRMODE) HTML_CLOSE("em");
								 break;
		case STRONG_MIT:   	     if (mode & TAGS_MDRMODE) HTML_OPEN("strong");
								 @<Recurse@>;
								 if (mode & TAGS_MDRMODE) HTML_CLOSE("strong");
								 break;
		case CODE_MIT:           if (mode & TAGS_MDRMODE) HTML_OPEN("code");
									int old_mode = mode;
									mode = mode & (~ESCAPES_MDRMODE) & (~ENTITIES_MDRMODE);
								 MarkdownRenderer::slice(OUT, md, mode);
								 if (mode & TAGS_MDRMODE) HTML_CLOSE("code");
								 mode = old_mode;
								 break;
		case LINK_MIT:           @<Render link@>; break;
		case IMAGE_MIT:          @<Render image@>; break;
		case LINK_DEST_MIT:      MarkdownRenderer::slice(OUT, md->down, mode | URI_MDRMODE); break;
		case LINK_TITLE_MIT:     @<Recurse@>; break;
		case LINE_BREAK_MIT:     if (mode & TAGS_MDRMODE) WRITE("<br />\n"); break;
		case SOFT_BREAK_MIT:     MarkdownRenderer::char(OUT, '\n', mode); break;
		case EMAIL_AUTOLINK_MIT: @<Render email link@>; break;
		case URI_AUTOLINK_MIT:   @<Render URI link@>; break;
		case INLINE_HTML_MIT:    MarkdownRenderer::slice(OUT, md, (mode | RAW_MDRMODE) & (~ESCAPES_MDRMODE) & (~ENTITIES_MDRMODE)); break;
		default:                 internal_error("unimplemented Markdown item render");
	}
}

@<Recurse@> =
	for (markdown_item *c = md->down; c; c = c->next)
		MarkdownRenderer::recurse(OUT, c, mode);

@<Render a heading@> =
	char *h = "p";
	switch (md->details) {
		case 1: h = "h1"; break;
		case 2: h = "h2"; break;
		case 3: h = "h3"; break;
		case 4: h = "h4"; break;
		case 5: h = "h5"; break;
		case 6: h = "h6"; break;
	}
	if (mode & TAGS_MDRMODE) HTML_OPEN(h);
	@<Recurse@>;
	if (mode & TAGS_MDRMODE) HTML_CLOSE(h);

@<Render a code block@> =
	int old_mode = mode;
	mode = mode & (~ESCAPES_MDRMODE) & (~ENTITIES_MDRMODE);
	if (mode & TAGS_MDRMODE) HTML_OPEN("pre");
	TEMPORARY_TEXT(language)
	for (int i=0; i<Str::len(md->info_string); i++) {
		wchar_t c = Str::get_at(md->info_string, i);
		if ((c == ' ') || (c == '\t')) break;
		PUT_TO(language, c);
	}
	if (Str::len(language) > 0) {
		TEMPORARY_TEXT(language_rendered)
		md->sliced_from = language;
		md->from = 0; md->to = Str::len(language) - 1;
		MarkdownRenderer::slice(language_rendered, md, mode | ENTITIES_MDRMODE);
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("code", "class=\"language-%S\"", language_rendered);
		DISCARD_TEXT(language_rendered)
	} else {
		if (mode & TAGS_MDRMODE) HTML_OPEN("code");
	}
	DISCARD_TEXT(language)
	md->sliced_from = md->stashed;
	md->from = 0; md->to = Str::len(md->sliced_from) - 1;
	MarkdownRenderer::slice(OUT, md, mode);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("code");
	if (mode & TAGS_MDRMODE) HTML_CLOSE("pre");
	WRITE("\n");
	mode = old_mode;

@<Render a raw HTML block@> =
	WRITE("%S", md->stashed);

@<Recurse through list@> =
	int old_mode = mode;
	mode = mode & (~LOOSE_MDRMODE);
	for (markdown_item *ch = md->down; ch; ch = ch->next) {
		if ((ch->next) && (ch->whitespace_follows))
			mode = mode | LOOSE_MDRMODE;
		for (markdown_item *gch = ch->down; gch; gch = gch->next)
			if ((gch->next) && (gch->whitespace_follows))
				mode = mode | LOOSE_MDRMODE;
	}
	@<Recurse@>;
	mode = old_mode;
 
@<Render a list item@> =
	if (mode & TAGS_MDRMODE) HTML_OPEN("li");
	int nl_issued = FALSE;
	for (markdown_item *ch = md->down; ch; ch = ch->next)
		if (((mode & LOOSE_MDRMODE) == 0) && (ch->type == PARAGRAPH_MIT))
			MarkdownRenderer::recurse(OUT, ch->down, mode);
		else {
			if (nl_issued == FALSE) { nl_issued = TRUE; WRITE("\n"); }
			MarkdownRenderer::recurse(OUT, ch, mode);
		}
	if (mode & TAGS_MDRMODE) HTML_CLOSE("li");
	WRITE("\n");

@<Render link@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MarkdownRenderer::recurse(URI, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MarkdownRenderer::recurse(title, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MarkdownRenderer::recurse(title, md->down->next, mode);
		}
	}
	if (Str::len(title) > 0) {
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S\" title=\"%S\"", URI, title);
	} else {
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S\"", URI);
	}
	MarkdownRenderer::recurse(OUT, md->down, mode);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("a");
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)

@<Render image@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(alt)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MarkdownRenderer::recurse(URI, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MarkdownRenderer::recurse(title, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MarkdownRenderer::recurse(title, md->down->next, mode);
		}
	}
	MarkdownRenderer::recurse(alt, md->down, mode & (~TAGS_MDRMODE));
	if (Str::len(title) > 0) {
		if (mode & TAGS_MDRMODE) {
			HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" title=\"%S\" /", URI, alt, title);
		} else {
			WRITE("%S", alt);
		}
	} else {
		if (mode & TAGS_MDRMODE) {
			HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" /", URI, alt);
		} else {
			WRITE("%S", alt);
		}
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)
	DISCARD_TEXT(alt)

@<Render email link@> =
	text_stream *supplied_scheme = I"mailto:";
	@<Render autolink@>;

@<Render URI link@> =
	text_stream *supplied_scheme = NULL;
	@<Render autolink@>;

@<Render autolink@> =
	TEMPORARY_TEXT(address)
	MarkdownRenderer::slice(address, md, (mode & (~ESCAPES_MDRMODE)) | URI_MDRMODE);
	if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S%S\"", supplied_scheme, address);
	MarkdownRenderer::slice(OUT, md, mode & (~ESCAPES_MDRMODE));
	if (mode & TAGS_MDRMODE) HTML_CLOSE("a");
	DISCARD_TEXT(address)

@

=
void MarkdownRenderer::slice(OUTPUT_STREAM, markdown_item *md, int mode) {
	if (md) {
		for (int i=md->from; i<=md->to; i++) {
			wchar_t c = Markdown::get_at(md, i);
			if ((mode & ESCAPES_MDRMODE) && (c == '\\') && (i<md->to) &&
				(Markdown::is_ASCII_punctuation(Markdown::get_at(md, i+1))))
				c = Markdown::get_at(md, ++i);
			else if ((mode & ENTITIES_MDRMODE) && (c == '&') && (i+2<=md->to)) {
				int at = i;
				TEMPORARY_TEXT(entity)
				wchar_t d = c;
				while ((d != 0) && (d != ';')) {
					if (at > md->to) break;
					d = Markdown::get_at(md, at++);
					PUT_TO(entity, d);
				}
				if (d == ';') {
					wchar_t A = 0, B = 0;
					int valid = HTMLEntities::parse(entity, &A, &B);
					DISCARD_TEXT(entity)
					if (valid) {
						if (A == 0) A = 0xFFFD;
						MarkdownRenderer::char(OUT, A, mode);
						if (B) MarkdownRenderer::char(OUT, B, mode);
						i = at - 1;
						continue;
					}
				}
			}
			MarkdownRenderer::char(OUT, c, mode);
		}
	}
}

void MarkdownRenderer::char(OUTPUT_STREAM, wchar_t c, int mode) {
	if (mode & RAW_MDRMODE) {
		PUT(c);
	} else if (mode & URI_MDRMODE) {
		if (c >= 0x10000) {
			MARKDOWN_URI_HEX(0xF0 + (unsigned char) (c >> 18));
			MARKDOWN_URI_HEX(0x80 + (unsigned char) ((c >> 12) & 0x3f));
			MARKDOWN_URI_HEX( 0x80 + (unsigned char) ((c >> 6) & 0x3f));
			MARKDOWN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else if (c >= 0x800) {
			MARKDOWN_URI_HEX(0xE0 + (unsigned char) (c >> 12));
			MARKDOWN_URI_HEX(0x80 + (unsigned char) ((c >> 6) & 0x3f));
			MARKDOWN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else if (c >= 0x80) {
			MARKDOWN_URI_HEX(0xC0 + (unsigned char) (c >> 6));
			MARKDOWN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else {
			switch (c) {
				case '<': WRITE("&lt;"); break;
				case '&': WRITE("&amp;"); break;
				case '>': WRITE("&gt;"); break;
				case '[': MARKDOWN_URI_HEX((unsigned char) c); break;
				case '\\':MARKDOWN_URI_HEX((unsigned char) c); break;
				case '\"':MARKDOWN_URI_HEX((unsigned char) c); break;
				case ']': MARKDOWN_URI_HEX((unsigned char) c); break;
				case '`': MARKDOWN_URI_HEX((unsigned char) c); break;
				case ' ': MARKDOWN_URI_HEX((unsigned char) c); break;
				default: PUT(c); break;
			}
		}
	} else {
		switch (c) {
			case '<': WRITE("&lt;"); break;
			case '&': WRITE("&amp;"); break;
			case '>': WRITE("&gt;"); break;
			case '"': WRITE("&quot;"); break;
			default: PUT(c); break;
		}
	}
}

@

@d MARKDOWN_URI_HEX(x) {
		unsigned int z = (unsigned int) x;
		PUT('%');
		MarkdownRenderer::hex_digit(OUT, z >> 4);
		MarkdownRenderer::hex_digit(OUT, z & 0x0f);
	}

=
void MarkdownRenderer::hex_digit(OUTPUT_STREAM, unsigned int x) {
	x = x%16;
	if (x<10) PUT('0'+(int) x);
	else PUT('A'+((int) x-10));
}

