[MDRenderer::] Markdown Rendering.

To render a Markdown tree as HTML.

@h Disclaimer.
Do not call functions in this section directly: use the API in //Markdown//.

@h Rendering.
This is blessedly simple by comparison with parsing, but there are some
pitfalls to look out for just the same.

We preserve a piece of state called the |mode| as we recurse downwards
through the tree: it's a bitmap composed of the following.

@d TAGS_MDRMODE     0x0001     /* Render HTML tags? */
@d ESCAPES_MDRMODE  0x0002     /* Treat backslash followed by ASCII punctuation as an escape? */
@d URI_MDRMODE      0x0004     /* Encode characters as they need to appear in a URI */
@d RAW_MDRMODE      0x0008     /* Treat all characters literally */
@d LOOSE_MDRMODE    0x0010     /* Wrap list items in paragraph tags */
@d ENTITIES_MDRMODE 0x0020     /* Convert |&entity;| to whatever it ought to represent */
@d FILTERED_MDRMODE 0x0040     /* Make first |<| character safe as |&lt;| */
@d TOLOWER_MDRMODE  0x0080     /* Force letters to lower case */

=
void MDRenderer::render_extended(OUTPUT_STREAM, markdown_item *md,
	markdown_variation *variation) {
	int default_mode = TAGS_MDRMODE | ESCAPES_MDRMODE;
	if (MarkdownVariations::supports(variation, ENTITIES_MARKDOWNFEATURE))
		default_mode = default_mode | ENTITIES_MDRMODE;	
	MDRenderer::recurse(OUT, md, default_mode, variation);
}

void MDRenderer::recurse(OUTPUT_STREAM, markdown_item *md, int mode,
	markdown_variation *variation) {
	if (md == NULL) return;
	if (MarkdownVariations::intervene_in_rendering(variation, OUT, md, mode)) return;
	int old_mode = mode;
	switch (md->type) {
		case ORDERED_LIST_MIT:          @<Render an ordered list@>; break;
		case ORDERED_LIST_ITEM_MIT:     @<Render a list item@>; break;
		case UNORDERED_LIST_MIT:        @<Render an unordered list@>; break;
		case UNORDERED_LIST_ITEM_MIT:   @<Render a list item@>; break;

		case BLOCK_QUOTE_MIT:           if (mode & TAGS_MDRMODE) HTML_OPEN("blockquote");
									    WRITE("\n");
									    @<Recurse@>;
									    if (mode & TAGS_MDRMODE) HTML_CLOSE("blockquote");
								        break;

		case PARAGRAPH_MIT:             if (mode & TAGS_MDRMODE) HTML_OPEN("p");
								        @<Recurse@>;
								        if (mode & TAGS_MDRMODE) HTML_CLOSE("p");
								        break;
		case TICKBOX_MIT:               @<Render a tickbox@>; break;
		case HEADING_MIT:               @<Render a heading@>; break;
		case CODE_BLOCK_MIT:            @<Render a code block@>; break;
		case HTML_MIT:                  @<Render a raw HTML block@>; break;
		case THEMATIC_MIT:              if (mode & TAGS_MDRMODE) WRITE("<hr />\n");
		                                break;
		case TABLE_MIT:					@<Render a table@>; break;
		case EMPTY_MIT:                 break;

		case PLAIN_MIT:    	            MDRenderer::slice(OUT, md, mode);
								        break;
		case LINE_BREAK_MIT:            if (mode & TAGS_MDRMODE) WRITE("<br />\n");
								        break;
		case SOFT_BREAK_MIT:            MDRenderer::char(OUT, '\n', mode);
								        break;
		case EMPHASIS_MIT: 	            if (mode & TAGS_MDRMODE) HTML_OPEN("em");
								        @<Recurse@>;
								        if (mode & TAGS_MDRMODE) HTML_CLOSE("em");
								        break;
		case STRONG_MIT:   	            if (mode & TAGS_MDRMODE) HTML_OPEN("strong");
								        @<Recurse@>;
								        if (mode & TAGS_MDRMODE) HTML_CLOSE("strong");
								        break;
		case STRIKETHROUGH_MIT:   	    if (mode & TAGS_MDRMODE) HTML_OPEN("del");
								        @<Recurse@>;
								        if (mode & TAGS_MDRMODE) HTML_CLOSE("del");
								        break;
		case CODE_MIT:                  if (mode & TAGS_MDRMODE) HTML_OPEN("code");
								       	mode = mode & (~ESCAPES_MDRMODE);
								       	mode = mode & (~ENTITIES_MDRMODE);
								        MDRenderer::slice(OUT, md, mode);
								        if (mode & TAGS_MDRMODE) HTML_CLOSE("code");
								        break;

		case EMAIL_AUTOLINK_MIT:        @<Render email link@>; break;
		case XMPP_AUTOLINK_MIT:         @<Render email link@>; break;
		case URI_AUTOLINK_MIT:          @<Render URI link@>; break;
		case INLINE_HTML_MIT:           mode = mode | RAW_MDRMODE;
										if (Markdown::get_filtered_state(md))
											mode = mode | FILTERED_MDRMODE;
								       	mode = mode & (~ESCAPES_MDRMODE);
								       	mode = mode & (~ENTITIES_MDRMODE);
								       	MDRenderer::slice(OUT, md, mode);
		                            	break;

		case LINK_MIT:                  @<Render link@>; break;
		case IMAGE_MIT:                 @<Render image@>; break;
		case LINK_DEST_MIT:             mode = mode | URI_MDRMODE;
								       	MDRenderer::slice(OUT, md->down, mode);
								       	break;
		case LINK_TITLE_MIT:            @<Recurse@>; break;

		default:                        @<Recurse@>; break;
	}
	mode = old_mode;
}

@<Render an ordered list@> =
	if (mode & TAGS_MDRMODE) {
		int start = Markdown::get_item_number(md->down);
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

@<Render an unordered list@> =
	if (mode & TAGS_MDRMODE) HTML_OPEN("ul");
	WRITE("\n");
	@<Recurse through list@>;
	if (mode & TAGS_MDRMODE) HTML_CLOSE("ul");
	WRITE("\n");

@<Recurse through list@> =
	mode = mode & (~LOOSE_MDRMODE);
	for (markdown_item *ch = md->down; ch; ch = ch->next) {
		if ((ch->next) && (ch->whitespace_follows))
			mode = mode | LOOSE_MDRMODE;
		for (markdown_item *gch = ch->down; gch; gch = gch->next)
			if ((gch->next) && (gch->whitespace_follows))
				mode = mode | LOOSE_MDRMODE;
	}
	@<Recurse@>;
 
@<Render a list item@> =
	if (mode & TAGS_MDRMODE) HTML_OPEN("li");
	int nl_issued = FALSE;
	for (markdown_item *ch = md->down; ch; ch = ch->next)
		if (((mode & LOOSE_MDRMODE) == 0) && (ch->type == PARAGRAPH_MIT)) {
			for (markdown_item *gch = ch->down; gch; gch = gch->next)
				MDRenderer::recurse(OUT, gch, mode, variation);
		} else {
			if (nl_issued == FALSE) { nl_issued = TRUE; WRITE("\n"); }
			MDRenderer::recurse(OUT, ch, mode, variation);
		}
	if (mode & TAGS_MDRMODE) HTML_CLOSE("li");
	WRITE("\n");

@<Render a tickbox@> =
	if (mode & TAGS_MDRMODE) {
		if (Markdown::get_tick_state(md)) {
			WRITE("<input checked=\"\" disabled=\"\" type=\"checkbox\"> ");
		} else {
			WRITE("<input disabled=\"\" type=\"checkbox\"> ");
		}
	}

@<Render a heading@> =
	char *h = "p";
	switch (Markdown::get_heading_level(md)) {
		case 1: h = "h1"; break;
		case 2: h = "h2"; break;
		case 3: h = "h3"; break;
		case 4: h = "h4"; break;
		case 5: h = "h5"; break;
		case 6: h = "h6"; break;
	}
	if (mode & TAGS_MDRMODE) HTML_OPEN(h);
	TEMPORARY_TEXT(anchor)
	text_stream *url = MarkdownVariations::URL_for_heading(md);
	for (int i=0; i<Str::len(url); i++)
		if (Str::get_at(url, i) == '#')
			for (i++; i<Str::len(url); i++)
				PUT_TO(anchor, Str::get_at(url, i));
	if (Str::len(anchor) > 0) {
		HTML_OPEN_WITH("span", "id=%S", anchor);
	}
	@<Recurse@>;
	if (Str::len(anchor) > 0) {
		HTML_CLOSE("span");
	}
	DISCARD_TEXT(anchor)
	if (mode & TAGS_MDRMODE) HTML_CLOSE(h);
	WRITE("\n");

@ We use the convention that the first word of the info string on a fenced
code block is the "language", and give it a CSS class accordingly. A piquant
part of CommonMark is that the language does respect entities, but that the
body of the code block does not. (It also respects backslash escapes, but we
do not render the language in |ESCAPES_MDRMODE| mode because those have already
been taken out at the parsing stage.)

@<Render a code block@> =
	mode = mode & (~ESCAPES_MDRMODE) & (~ENTITIES_MDRMODE);
	if (mode & TAGS_MDRMODE) HTML_OPEN("pre");
	TEMPORARY_TEXT(language)
	for (int i=0; i<Str::len(md->info_string); i++) {
		inchar32_t c = Str::get_at(md->info_string, i);
		if ((c == ' ') || (c == '\t')) break;
		PUT_TO(language, c);
	}
	if (Str::len(language) > 0) {
		TEMPORARY_TEXT(language_rendered)
		md->sliced_from = language;
		md->from = 0; md->to = Str::len(language) - 1;
		if (MarkdownVariations::supports(variation, ENTITIES_MARKDOWNFEATURE))
			MDRenderer::slice(language_rendered, md, mode | ENTITIES_MDRMODE);
		else
			MDRenderer::slice(language_rendered, md, mode);
		if (mode & TAGS_MDRMODE)
			HTML_OPEN_WITH("code", "class=\"language-%S\"", language_rendered);
		DISCARD_TEXT(language_rendered)
	} else {
		if (mode & TAGS_MDRMODE) HTML_OPEN("code");
	}
	DISCARD_TEXT(language)
	md->sliced_from = md->stashed;
	md->from = 0; md->to = Str::len(md->sliced_from) - 1;
	MDRenderer::slice(OUT, md, mode);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("code");
	if (mode & TAGS_MDRMODE) HTML_CLOSE("pre");
	WRITE("\n");

@<Render a raw HTML block@> =
	if (MarkdownVariations::supports(variation, DISALLOWED_RAW_HTML_MARKDOWNFEATURE)) {
		for (int i=0; i<Str::len(md->stashed); i++)
			if (Str::get_at(md->stashed, i) == '<') {
				TEMPORARY_TEXT(tag)
				for (int j=i+1; j<Str::len(md->stashed); j++)
					if (Characters::is_ASCII_letter(Str::get_at(md->stashed, j)))
						PUT_TO(tag, Str::get_at(md->stashed, j));
					else
						break;
				if (Markdown::tag_should_be_filtered(tag)) WRITE("&lt;");
				else PUT('<');
				DISCARD_TEXT(tag)
			} else {
				PUT(Str::get_at(md->stashed, i));
			}
	} else {
		WRITE("%S", md->stashed);
	}

@<Render a table@> =
	markdown_item *alignment_markers = md->down;
	if (alignment_markers) {
		int row_count = 0;
		for (markdown_item *md = alignment_markers->next; md; md = md->next) row_count++;
		if (row_count > 0) {
			WRITE("<table>\n");
			WRITE("<thead>\n");
			markdown_item *row = alignment_markers->next;
			WRITE("<tr>\n");
			for (markdown_item *md = row->down, *top = alignment_markers->down;
				md; md = md->next, top = top->next) {
				switch (Markdown::get_alignment(top)) {
					case 0: WRITE("<th>"); break;
					case 1: WRITE("<th align=\"left\">"); break;
					case 2: WRITE("<th align=\"right\">"); break;
					case 3: WRITE("<th align=\"center\">"); break;
				}
				if (md->down) MDRenderer::recurse(OUT, md->down, mode, variation);
				WRITE("</th>\n");
			}
			WRITE("</tr>\n");
			row = row->next;
			WRITE("</thead>\n");
			if (row_count > 1) {
				WRITE("<tbody>\n");
				while (row) {
					WRITE("<tr>\n");
					for (markdown_item *md = row->down, *top = alignment_markers->down;
						md; md = md->next, top = top->next) {
						switch (Markdown::get_alignment(top)) {
							case 0: WRITE("<td>"); break;
							case 1: WRITE("<td align=\"left\">"); break;
							case 2: WRITE("<td align=\"right\">"); break;
							case 3: WRITE("<td align=\"center\">"); break;
						}
						if (md->down) MDRenderer::recurse(OUT, md->down, mode, variation);
						WRITE("</td>\n");
					}
					WRITE("</tr>\n");
					row = row->next;
				}
				WRITE("</tbody>\n");
			}
			WRITE("</table>\n");
		}
	}

@<Render email link@> =
	text_stream *supplied_scheme = NULL;
	if (Markdown::get_add_protocol_state(md)) {
		supplied_scheme = I"mailto:";
		if (md->type == XMPP_AUTOLINK_MIT) supplied_scheme = I"xmpp:";
	}
	@<Render autolink@>;

@<Render URI link@> =
	text_stream *supplied_scheme = NULL;
	if (Markdown::get_add_protocol_state(md)) supplied_scheme = I"http://";
	@<Render autolink@>;

@<Render autolink@> =
	TEMPORARY_TEXT(address)
	MDRenderer::slice(address, md, (mode & (~ESCAPES_MDRMODE)) | URI_MDRMODE);
	if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S%S\"", supplied_scheme, address);
	MDRenderer::slice(OUT, md, mode & (~ESCAPES_MDRMODE));
	if (mode & TAGS_MDRMODE) HTML_CLOSE("a");
	DISCARD_TEXT(address)

@<Render link@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderer::recurse(URI, md->down->next, mode, variation);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderer::recurse(title, md->down->next->next, mode, variation);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderer::recurse(title, md->down->next, mode, variation);
		}
	}
	if (Str::len(title) > 0) {
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S\" title=\"%S\"", URI, title);
	} else {
		if (mode & TAGS_MDRMODE) HTML_OPEN_WITH("a", "href=\"%S\"", URI);
	}
	MDRenderer::recurse(OUT, md->down, mode, variation);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("a");
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)

@<Render image@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(alt)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderer::recurse(URI, md->down->next, mode, variation);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderer::recurse(title, md->down->next->next, mode, variation);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderer::recurse(title, md->down->next, mode, variation);
		}
	}
	MDRenderer::recurse(alt, md->down, mode & (~TAGS_MDRMODE), variation);
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

@ And finally, the obvious definition:

@<Recurse@> =
	for (markdown_item *c = md->down; c; c = c->next)
		MDRenderer::recurse(OUT, c, mode, variation);

@ Down at the lower level now: how to render the slice of text in a single
inline item. In |ESCAPES_MDRMODE|, backslash followed by ASCII (but not
Unicode) punctuation produces a literal of that character. In |ENTITIES_MDRMODE|,
we convert any valid entity ending in a semicolon to its Unicode code point(s).
Note that CommonMark requires us not to respect HTML5 entities which do not
end in a semicolon, such as |&copy| rather than |&copy;|.

=
void MDRenderer::slice(OUTPUT_STREAM, markdown_item *md, int mode) {
	if (md) {
		int angles = 0;
		for (int i=md->from; i<=md->to; i++) {
			inchar32_t c = Markdown::get_at(md, i);
			if ((mode & ESCAPES_MDRMODE) && (c == '\\') && (i<md->to) &&
				(Characters::is_ASCII_punctuation(Markdown::get_at(md, i+1))))
				c = Markdown::get_at(md, ++i);
			else if ((mode & ENTITIES_MDRMODE) && (c == '&') && (i+2<=md->to)) {
				int at = i;
				TEMPORARY_TEXT(entity)
				inchar32_t d = c;
				while ((d != 0) && (d != ';')) {
					if (at > md->to) break;
					d = Markdown::get_at(md, at++);
					PUT_TO(entity, d);
				}
				if (d == ';') {
					inchar32_t A = 0, B = 0;
					int valid = HTMLEntities::parse(entity, &A, &B);
					DISCARD_TEXT(entity)
					if (valid) {
						if (A == 0) A = 0xFFFD;
						MDRenderer::char(OUT, A, mode);
						if (B) MDRenderer::char(OUT, B, mode);
						i = at - 1;
						continue;
					}
				}
			}
			if ((c == '<') && (angles++ == 0) && (mode & FILTERED_MDRMODE))
				MDRenderer::char(OUT, c, 0);
			else
				MDRenderer::char(OUT, c, mode);
		}
	}
}

@ Down at the individual character level, there are three mutually exclusive
ways to render characters: they all agree on ASCII digits and letters.

=
void MDRenderer::char(OUTPUT_STREAM, inchar32_t c, int mode) {
	if (mode & TOLOWER_MDRMODE) c = Characters::tolower(c);
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

@ CommonMark likes hexadecimal escapes in URIs to use upper case A to F;
I suspect Web browsers don't care, but it's nice to comply exactly with the
CommonMark test examples, so:

@d MARKDOWN_URI_HEX(x) {
		unsigned int z = (unsigned int) x;
		PUT('%');
		MDRenderer::hex_digit(OUT, z >> 4);
		MDRenderer::hex_digit(OUT, z & 0x0f);
	}

=
void MDRenderer::hex_digit(OUTPUT_STREAM, unsigned int x) {
	x = x%16;
	if (x<10) PUT('0'+x);
	else PUT('A'+(x-10));
}
