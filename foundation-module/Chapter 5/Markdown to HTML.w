[MDRenderHTML::] Markdown to HTML.

To render a Markdown tree as HTML.

@h Main rendering recursion.
Do not call this function directly: use the API in //Markdown Rendering//.

=
void MDRenderHTML::recurse(OUTPUT_STREAM, markdown_render *rdr, markdown_item *md, int mode) {
	if (rdr == NULL) internal_error("no render details in recursion");
	if (md == NULL) return;
	if (MarkdownVariations::intervene_in_rendering(rdr->variation, rdr, OUT, md, mode)) return;
	int old_mode = mode, tag = (mode & ALT_TEXT_MDRMODE)?FALSE:TRUE;
	switch (md->type) {	
		/* Container blocks */
		case BLOCK_QUOTE_MIT:           @<Render a block quote@>; break;
		case ALERT_MIT:                 @<Render an alert@>; break;
		case UNORDERED_LIST_MIT:        @<Render an unordered list@>; break;
		case ORDERED_LIST_MIT:          @<Render an ordered list@>; break;
		case UNORDERED_LIST_ITEM_MIT:   @<Render a list item@>; break;
		case ORDERED_LIST_ITEM_MIT:     @<Render a list item@>; break;
		case FOOTNOTE_BODY_MIT:         @<Render a footnote body@>; break;

		/* Leaf blocks */
		case PARAGRAPH_MIT:             @<Render a paragraph@>; break;
		case THEMATIC_MIT:              @<Render a thematic break@>; break;
		case HEADING_MIT:               @<Render a heading@>; break;
		case CODE_BLOCK_MIT:            @<Render a code block@>; break;
		case HTML_MIT:                  @<Render a raw HTML block@>; break;
		case EMPTY_MIT:                 break;
		case TABLE_MIT:					@<Render a table@>; break;
		case TICKBOX_MIT:               @<Render a tickbox@>; break;

		/* Inline types */
		case PLAIN_MIT:    	            @<Render plain text@>; break;
		case LINE_BREAK_MIT:        	@<Render a line break@>; break;
		case SOFT_BREAK_MIT:            @<Render a soft line break@>; break;
		case EMPHASIS_MIT: 	            @<Render emphasised text@>; break;
		case STRONG_MIT:   	            @<Render strongly emphasised text@>; break;
		case CODE_MIT:                  @<Render inline code sample@>; break;
		case URI_AUTOLINK_MIT:          @<Render URI link@>; break;
		case EMAIL_AUTOLINK_MIT:        @<Render email link@>; break;
		case INLINE_HTML_MIT:           @<Render inline HTML content@>; break;
		case LINK_MIT:                  @<Render link@>; break;
		case IMAGE_MIT:                 @<Render image@>; break;
		case LINK_DEST_MIT:             @<Render link destination@>; break;
		case STRIKETHROUGH_MIT:   	    @<Render struck-through text@>; break;
		case XMPP_AUTOLINK_MIT:         @<Render email link@>; break;
		case TEX_MIT:   	            @<Render maths matter in TeX@>; break;
		case DISPLAYED_TEX_MIT:   	    @<Render maths matter in TeX@>; break;
		case INWEB_LINK_MIT:   	    	@<Render Inweb link@>; break;

		default:                        @<Recurse@>; break;
	}
	mode = old_mode;
}

@ Many of these types (and all types not explicitly listed above) perform the
following recursion down the Markdown tree. Note that `EXISTING_PAR_MDRMODE` mode
is only used when recursing down the leading edge of the tree: this means that
a render at a node can open a paragraph in HTML and then recurse downwards to
render the contents even when the first of those contents is known to be a
`PARAGRAPH_MIT`, and the HTML `p` will not be opened a second time.

@<Recurse@> =
	int m = mode;
	for (markdown_item *c = md->down; c; c = c->next) {
		MDRenderHTML::recurse(OUT, rdr, c, m);
		m = m & (~EXISTING_PAR_MDRMODE);
	}

@h Container block items.
In these cases we cannot be in `ALT_TEXT_MDRMODE` mode, since alt-text can
only contain inline material, so we need not check this mode before writing
HTML tags. See below.

@<Render a block quote@> =
	HTML_OPEN("blockquote");
	WRITE("\n");
	@<Recurse@>;
	HTML_CLOSE("blockquote");
	break;

@<Render an alert@> =
	int type = Markdown::get_alert_type(md);
	text_stream *name = MarkdownVariations::get_alert_form_name(rdr->variation, type);
	inchar32_t icon = MarkdownVariations::get_alert_form_icon(rdr->variation, type);
	TEMPORARY_TEXT(cl)
	WRITE_TO(cl, "alert");
	for (int i=0; i<Str::len(name); i++) PUT_TO(cl, Characters::tolower(Str::get_at(name, i)));
	HTML_OPEN_WITH("blockquote", "class=\"%S\"", cl);
	DISCARD_TEXT(cl)
	WRITE("\n");
	HTML_OPEN_WITH("p", "class=\"alertheading\"");
	if (icon) { PUT(icon); PUT(' '); }
	if (Str::len(name) > 0) {
		PUT(Str::get_at(name, 0));
		for (int i=1; i<Str::len(name); i++) PUT(Characters::tolower(Str::get_at(name, i)));
	} else {
		WRITE("Alert");
	}
	HTML_CLOSE("p");	
	@<Recurse@>;
	HTML_CLOSE("blockquote");
	break;

@<Render an unordered list@> =
	int skip_ul_rendering = FALSE;
	if (MarkdownVariations::supports(rdr->variation, GADGETS_MARKDOWNFEATURE))
		skip_ul_rendering = MDRender::render_ul_as_carousel(OUT, mode, rdr, md);

	if (skip_ul_rendering == FALSE) {
		HTML_OPEN("ul");
		WRITE("\n");
		@<Recurse through list@>;
		HTML_CLOSE("ul");
		WRITE("\n");
	}

@<Render an ordered list@> =
	int start = Markdown::get_item_number(md->down);
	if (start != 1) {
		HTML_OPEN_WITH("ol", "start=\"%d\"", start);
	} else {
		HTML_OPEN("ol");
	}
	WRITE("\n");
	@<Recurse through list@>;
	HTML_CLOSE("ol");
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
	HTML_OPEN("li");
	int nl_issued = FALSE;
	for (markdown_item *ch = md->down; ch; ch = ch->next)
		if (((mode & LOOSE_MDRMODE) == 0) && (ch->type == PARAGRAPH_MIT)) {
			for (markdown_item *gch = ch->down; gch; gch = gch->next)
				MDRenderHTML::recurse(OUT, rdr, gch, mode);
		} else {
			if (nl_issued == FALSE) { nl_issued = TRUE; WRITE("\n"); }
			MDRenderHTML::recurse(OUT, rdr, ch, mode);
		}
	HTML_CLOSE("li");
	WRITE("\n");

@<Render a footnote body@> =
	int displayed_number = md->details;
	if (displayed_number == 1) {
		HTML_OPEN_WITH("ul", "class=\"inwebfootnotetexts\"");
	}
	HTML_OPEN_WITH("li", "class=\"footnote\" id=\"fn:%d\"", md->details);
	HTML_OPEN_WITH("p", "class=\"inwebfootnote\"");
	HTML_OPEN_WITH("sup", "id=\"fnref:%d\"", md->details);
	HTML_OPEN_WITH("a", "href=\"#fn:%d\" rel=\"footnote\"", md->details);
	WRITE("%d", displayed_number);
	HTML_CLOSE("a");
	HTML_CLOSE("sup");
	WRITE("\n");
	markdown_item *r_from = md->down;
	int reopen_for_return_marker = FALSE;
	if ((r_from) && (r_from->type == PARAGRAPH_MIT)) {
		MDRenderHTML::recurse(OUT, rdr, r_from->down, mode);
		r_from = r_from->next;
		if (r_from) {
			HTML_CLOSE("p");
			reopen_for_return_marker = TRUE;
		}
	}
	int m = mode;
	for (markdown_item *c = r_from; c; c = c->next) {
		MDRenderHTML::recurse(OUT, rdr, c, m);
		m = m & (~EXISTING_PAR_MDRMODE);
	}
	if (reopen_for_return_marker) HTML_CLOSE("p");
	HTML_OPEN_WITH("a", "href=\"#fnref:%d\" title=\"return to text\"", md->details);
	WRITE(" &#x21A9;");
	HTML_CLOSE("a");
	HTML_CLOSE("p");
	HTML_CLOSE("li");
	if ((md->next == NULL) || (md->next->type != FOOTNOTE_BODY_MIT)) HTML_CLOSE("ul");
	WRITE("\n");
	break;

@h Leaf blocks.
As with container blocks, we cannot be in `ALT_TEXT_MDRMODE` mode in any of
these cases.

@<Render a paragraph@> =
	if ((mode & EXISTING_PAR_MDRMODE) == 0) HTML_OPEN("p");
	mode = mode & (~EXISTING_PAR_MDRMODE);
	@<Recurse@>;
	HTML_CLOSE("p");
	break;

@<Render a thematic break@> =
	WRITE("<hr />\n");
	break;

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
	HTML_OPEN(h);
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
	HTML_CLOSE(h);
	WRITE("\n");

@ We use the convention that the first word of the info string on a fenced
code block is the "language", and give it a CSS class accordingly. A piquant
part of CommonMark is that the language does respect entities, but that the
body of the code block does not. (It also respects backslash escapes, but we
do not render the language in `ESCAPES_MDRMODE` mode because those have already
been taken out at the parsing stage.)

@<Render a code block@> =
	mode = mode & (~ESCAPES_MDRMODE) & (~ENTITIES_MDRMODE);
	TEMPORARY_TEXT(language)
	for (int i=0; i<Str::len(md->info_string); i++) {
		inchar32_t c = Str::get_at(md->info_string, i);
		if ((c == ' ') || (c == '\t')) break;
		PUT_TO(language, c);
	}
	TEMPORARY_TEXT(language_rendered)
	if (Str::len(language) > 0) {
		md->sliced_from = language;
		md->from = 0; md->to = Str::len(language) - 1;
		if (MarkdownVariations::supports(rdr->variation, ENTITIES_MARKDOWNFEATURE))
			MDRender::slice(language_rendered, rdr, md, mode | ENTITIES_MDRMODE);
		else
			MDRender::slice(language_rendered, rdr, md, mode);
	}
	DISCARD_TEXT(language)

	if (MarkdownVariations::supports(rdr->variation, INWEB_SYNTAX_COLOURING_MARKDOWNFEATURE))
		MDRenderHTML::render_code_block(OUT, mode, rdr, md->stashed, language_rendered);
	else @<Render a code block the default way@>;
	DISCARD_TEXT(language_rendered)

@<Render a code block the default way@> =
	HTML_OPEN("pre");
	if (Str::len(language_rendered) > 0) {
		HTML_OPEN_WITH("code", "class=\"language-%S\"", language_rendered);
	} else {
		HTML_OPEN("code");
	}
	md->sliced_from = md->stashed;
	md->from = 0; md->to = Str::len(md->sliced_from) - 1;
	MDRender::slice(OUT, rdr, md, mode);
	HTML_CLOSE("code");
	HTML_CLOSE("pre");
	WRITE("\n");

@<Render a raw HTML block@> =
	if (MarkdownVariations::supports(rdr->variation, DISALLOWED_RAW_HTML_MARKDOWNFEATURE)) {
		for (int i=0; i<Str::len(md->stashed); i++)
			if (Str::get_at(md->stashed, i) == '<') {
				TEMPORARY_TEXT(rtag)
				for (int j=i+1; j<Str::len(md->stashed); j++)
					if (Characters::is_ASCII_letter(Str::get_at(md->stashed, j)))
						PUT_TO(rtag, Str::get_at(md->stashed, j));
					else
						break;
				if (Markdown::tag_should_be_filtered(rtag)) WRITE("&lt;");
				else PUT('<');
				DISCARD_TEXT(rtag)
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
				if (md->down) MDRenderHTML::recurse(OUT, rdr, md->down, mode);
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
						if (md->down) MDRenderHTML::recurse(OUT, rdr, md->down, mode);
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

@<Render a tickbox@> =
	if (Markdown::get_tick_state(md)) {
		WRITE("<input checked=\"\" disabled=\"\" type=\"checkbox\"> ");
	} else {
		WRITE("<input disabled=\"\" type=\"checkbox\"> ");
	}

@h Inline types.
Here we might be in `ALT_TEXT_MDRMODE` mode; that is, we might be rendering
Markdown which represents the alt-text for an image. The CommonMark specification
calls that an image description, and says:

> Though this spec is concerned with parsing, not rendering, it is recommended
> that in rendering to HTML, only the plain string content of the image
> description be used.

Exactly what "plain string content" means is unclear but the demonstrated test
cases imply that we render inline elements as normal, but without their HTML
tags. So from here on, HTML tags can only be opened or closed if the flag `tag`
is `TRUE`.

@<Render plain text@> =
	MDRender::slice(OUT, rdr, md, mode);
	break;

@<Render a line break@> =
	if (tag) WRITE("<br />\n"); else WRITE(" ");
	break;

@<Render a soft line break@> =
	MDRenderHTML::char(OUT, '\n', mode);
	break;

@<Render emphasised text@> =
	if (tag) HTML_OPEN("em");
	@<Recurse@>;
	if (tag) HTML_CLOSE("em");
	break;

@<Render strongly emphasised text@> =
	if (tag) HTML_OPEN("strong");
	@<Recurse@>;
	if (tag) HTML_CLOSE("strong");
	break;

@<Render inline code sample@> =
	if (tag) HTML_OPEN("code");
	mode = mode & (~ESCAPES_MDRMODE);
	mode = mode & (~ENTITIES_MDRMODE);
	MDRender::slice(OUT, rdr, md, mode);
	if (tag) HTML_CLOSE("code");
	break;

@<Render URI link@> =
	text_stream *supplied_scheme = NULL;
	if (Markdown::get_add_protocol_state(md)) supplied_scheme = I"http://";
	@<Render autolink@>;

@<Render email link@> =
	text_stream *supplied_scheme = NULL;
	if (Markdown::get_add_protocol_state(md)) {
		supplied_scheme = I"mailto:";
		if (md->type == XMPP_AUTOLINK_MIT) supplied_scheme = I"xmpp:";
	}
	@<Render autolink@>;

@<Render autolink@> =
	TEMPORARY_TEXT(address)
	MDRender::slice(address, rdr, md, (mode & (~ESCAPES_MDRMODE)) | URI_MDRMODE);
	if (tag) HTML_OPEN_WITH("a", "href=\"%S%S\"", supplied_scheme, address);
	MDRender::slice(OUT, rdr, md, mode & (~ESCAPES_MDRMODE));
	if (tag) HTML_CLOSE("a");
	DISCARD_TEXT(address)

@<Render inline HTML content@> =
	mode = mode | RAW_MDRMODE;
	if (Markdown::get_filtered_state(md)) mode = mode | FILTERED_MDRMODE;
	mode = mode & (~ESCAPES_MDRMODE);
	mode = mode & (~ENTITIES_MDRMODE);
	MDRender::slice(OUT, rdr, md, mode);
	break;

@<Render link@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	if (md->details > 0) {
		WRITE_TO(URI, "#fn:%d", md->details);
	} else if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderHTML::recurse(URI, rdr, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderHTML::recurse(title, rdr, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderHTML::recurse(title, rdr, md->down->next, mode);
		}
	}
	if (md->details > 0) {
		if (tag) HTML_OPEN_WITH("sup", "id=\"fnred:%d\"", md->details);
		if (tag) HTML_OPEN_WITH("a", "href=\"%S\" rel=\"footnote\"", URI);
	} else if (Str::len(title) > 0) {
		if (tag) HTML_OPEN_WITH("a", "href=\"%S\" title=\"%S\"", URI, title);
	} else {
		if (tag) HTML_OPEN_WITH("a", "href=\"%S\"", URI);
	}
	MDRenderHTML::recurse(OUT, rdr, md->down, mode);
	if (tag) HTML_CLOSE("a");
	if (md->details > 0) {
		if (tag) HTML_CLOSE("sup");
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)

@<Render image@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(alt)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderHTML::recurse(URI, rdr, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderHTML::recurse(title, rdr, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderHTML::recurse(title, rdr, md->down->next, mode);
		}
	}
	MDRenderHTML::recurse(alt, rdr, md->down, mode | ALT_TEXT_MDRMODE);
	if ((MarkdownVariations::supports(rdr->variation, GADGETS_MARKDOWNFEATURE) == FALSE) ||
		(MDRender::render_gadget(OUT, rdr, mode, alt, URI) == FALSE)) {
		int w = -1, h = -1;
		int j = 0;
		for (int i=1; i<Str::len(URI)-1; i++)
			if (Str::get_at(URI, i) == '@')
				j = i;
		if (j > 0) {
			int x = 0;
			for (int i=j+1; i<Str::len(URI); i++)
				if (Str::get_at(URI, i) == 'x')
					x = i;
			int bad = FALSE;
			for (int i=j+1; i<Str::len(URI); i++)
				if ((i != x) && (Characters::isdigit(Str::get_at(URI, i)) == FALSE))
					bad = TRUE;
			if (bad == FALSE) {
				if (x > 0) {
					if (x > j+1) w = Str::atoi(URI, j+1);
					if (x < Str::len(URI) - 1) h = Str::atoi(URI, x+1);
				} else {
					w = Str::atoi(URI, j+1);
				}
				Str::truncate(URI, j);
			}
		}
		MDRender::notify_image(rdr, URI);
		@<Actually render the image tag@>;
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)
	DISCARD_TEXT(alt)

@ If alt-text for one image contains another image, what should be done? CommonMark
implies this is not allowed, but just in case, the decision below is that the
second image is replaced by its own alt-text.

@<Actually render the image tag@> =
	if (Str::len(title) > 0) {
		if (tag) {
			if ((w > 0) && (h > 0)) {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" title=\"%S\" width=\"%d\" height=\"%d\" /", URI, alt, title, w, h);
			} else if (w > 0) {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" title=\"%S\" width=\"%d\" /", URI, alt, title, w);
			} else if (h > 0) {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" title=\"%S\" height=\"%d\" /", URI, alt, title, h);
			} else {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" title=\"%S\" /", URI, alt, title);
			}
		} else {
			WRITE("%S", alt);
		}
	} else {
		if (tag) {
			if ((w > 0) && (h > 0)) {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" width=\"%d\" height=\"%d\" /", URI, alt, w, h);
			} else if (w > 0) {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" width=\"%d\" /", URI, alt, w);
			} else if (h > 0) {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" height=\"%d\" /", URI, alt, h);
			} else {
				HTML_TAG_WITH("img", "src=\"%S\" alt=\"%S\" /", URI, alt);
			}
		} else {
			WRITE("%S", alt);
		}
	}

@<Render link destination@> =
	MDRender::slice(OUT, rdr, md->down, mode | URI_MDRMODE);
	break;

@<Render struck-through text@> =
	if (tag) HTML_OPEN("del");
	@<Recurse@>;
	if (tag) HTML_CLOSE("del");
	break;

@<Render maths matter in TeX@> =
	TEMPORARY_TEXT(TEX)
	if (MarkdownVariations::supports(rdr->variation, ALT_TEX_MARKDOWNFEATURE)) {
		int m = RAW_MDRMODE;
		for (markdown_item *c = md->down; c; c = c->next) {
			MDRenderHTML::recurse(TEX, rdr, c, m);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
	} else {
		for (int i=md->from; i<=md->to; i++) {
			inchar32_t c = Markdown::get_at(md, i);
			PUT_TO(TEX, c);
		}
	}
	MDRenderHTML::render_maths(OUT, rdr, TEX, (md->type == DISPLAYED_TEX_MIT)?TRUE:FALSE);
	DISCARD_TEXT(TEX)

@<Render Inweb link@> =
	TEMPORARY_TEXT(address)
	MDRenderHTML::recurse(address, rdr, md->down, RAW_MDRMODE);
	query_results qr = MDRender::resolve_link(rdr, address);
	if (qr.found) {
		if (qr.external) {
			if (tag) MDRenderHTML::link(OUT, rdr, I"", qr.url, mode);
		} else {
			if (tag) MDRenderHTML::link_internal(OUT, qr.url, mode);
		}
		if (qr.token) WRITE("<span class=\"linelabel\">");
		WRITE("%S", qr.title);
		if (qr.token) WRITE("</span>");
		if (tag) MDRenderHTML::end_link(OUT, mode);
	} else {
		HTML_OPEN("b");
		WRITE("[Unresolved link: %S]", address);
		HTML_CLOSE("b");
	}
	DISCARD_TEXT(address)
	
@h Character output.
Down at the individual character level, there are three mutually exclusive
ways to render characters: they all agree on ASCII digits and letters.

=
void MDRenderHTML::char(OUTPUT_STREAM, inchar32_t c, int mode) {
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

@ Where:

@d MARKDOWN_URI_HEX(x) {
		unsigned int z = (unsigned int) x;
		PUT('%');
		MDRender::hex_digit(OUT, z >> 4);
		MDRender::hex_digit(OUT, z & 0x0f);
	}

@ While this is strictly speaking nothing to do with Markdown, it turns out
to be convenient to provide a variant which does not encode `"` as `&quot;`:

=
void MDRenderHTML::escape_text(text_stream *OUT, text_stream *id) {
	for (int i=0; i < Str::len(id); i++) {
		if (Str::get_at(id, i) == '&') WRITE("&amp;");
		else if (Str::get_at(id, i) == '<') WRITE("&lt;");
		else if (Str::get_at(id, i) == '>') WRITE("&gt;");
		else PUT(Str::get_at(id, i));
	}
}

@h Inweb links.

=
void MDRenderHTML::link(OUTPUT_STREAM, markdown_render *rdr,
	text_stream *supplied_scheme, text_stream *address, int mode) {
	TEMPORARY_TEXT(url)
	WRITE_TO(url, "%S%S", supplied_scheme, address);
	HTML::begin_link_with_class(OUT, I"external", url);
	DISCARD_TEXT(url)
}
void MDRenderHTML::link_internal(OUTPUT_STREAM, text_stream *nameid, int mode) {
	HTML::begin_link_with_class(OUT, I"internal", nameid);
}
void MDRenderHTML::end_link(OUTPUT_STREAM, int mode) {
	HTML::end_link(OUT);
}

@h Code block rendering.

=
void MDRenderHTML::render_code_block(OUTPUT_STREAM, int mode, markdown_render *rdr,
	text_stream *code, text_stream *language_rendered) {
	TEMPORARY_TEXT(colouring)
	void *colours = NULL;
	MDRender::colour_code_block(rdr, language_rendered, code, colouring, &colours);
	if (colours) {
		TEMPORARY_TEXT(prefix)
		MDRender::name_colour_scheme(rdr, prefix, colours);
		HTML_OPEN_WITH("pre", "class=\"%S-displayed-code all-displayed-code code-font\"",
			prefix);
	} else {
		HTML_OPEN_WITH("pre", "class=\"displayed-code all-displayed-code code-font\"");
	}
	MDRenderHTML::render_syntax_coloured(OUT, rdr, code, colouring, colours);
	DISCARD_TEXT(colouring)
	HTML_CLOSE("pre");
	WRITE("\n");
}

void MDRenderHTML::render_syntax_coloured(OUTPUT_STREAM, markdown_render *rdr,
	text_stream *code, text_stream *colouring, void *colours) {
	int ind = Streams::get_indentation(OUT); Streams::set_indentation(OUT, 0);
	int current_colour = -1, colour_wanted = PLAIN_COLOUR;
	for (int i=0; i < Str::len(code); i++) {
		colour_wanted = (int) Str::get_at(colouring, i);
		if (colour_wanted == 0) colour_wanted = PLAIN_COLOUR;
		if (colour_wanted != current_colour) {
			if (current_colour >= 0)
				MDRenderHTML::change_colour(OUT, rdr, -1, colours);
			if (colour_wanted >= 0)
				MDRenderHTML::change_colour(OUT, rdr, colour_wanted, colours);
			current_colour = colour_wanted;
		}
		if (Str::get_at(code, i) == '<') WRITE("&lt;");
		else if (Str::get_at(code, i) == '>') WRITE("&gt;");
		else if (Str::get_at(code, i) == '&') WRITE("&amp;");
		else WRITE("%c", Str::get_at(code, i));
	}
	if (current_colour >= 0) MDRenderHTML::change_colour(OUT, rdr, -1, colours);
	Streams::set_indentation(OUT, ind);
}

void MDRenderHTML::change_colour(OUTPUT_STREAM, markdown_render *rdr, int col,
	void *colours) {
	if (col == -1) {
		HTML_CLOSE("span");
	} else {
		TEMPORARY_TEXT(cl)
		MDRender::name_colour(rdr, cl, col);
		if (Str::len(cl) == 0) {
			PRINT("col: %d\n", col); internal_error("bad colour");
		} else {
			TEMPORARY_TEXT(csname)
			MDRender::name_colour_scheme(rdr, csname, colours);
			HTML_OPEN_WITH("span", "class=\"%S%S\"", csname, cl);
			DISCARD_TEXT(csname)
		}
		DISCARD_TEXT(cl)
	}
}

@ Maths is rendered using MathJax-friendly formats unless the client has
vetoed this: only then do we resort to paraphrasing in plain text.

=
void MDRenderHTML::render_maths(OUTPUT_STREAM, markdown_render *rdr, text_stream *TEX,
	int displayed) {
	if (MDRender::veto_mathematics(rdr, displayed)) @<Paraphrase maths as text@>
	else @<Render maths as MathJax@>;
}

@<Paraphrase maths as text@> =
	TEMPORARY_TEXT(R)
	MDRender::remove_math_mode(R, TEX, TRUE);
	if (displayed) {
		HTML_OPEN("center");
		MDRender::stream(OUT, rdr, R, 0);
		HTML_CLOSE("center");
	} else {
		MDRender::stream(OUT, rdr, R, 0);
	}
	DISCARD_TEXT(R)

@ In order to support Knuth's webs slightly better, we assume that `|...|`
inside TeX math mode is intended to mean an inline code sample.

@<Render maths as MathJax@> =
	if (displayed) WRITE("$$"); else WRITE("\\INWEBMATH(");
	TEMPORARY_TEXT(escaped)
	MDRender::stream(escaped, rdr, TEX, 0);
	for (int i=0; i<Str::len(escaped); i++) {
		if (Str::get_at(escaped, i) == '|') {
			int found = FALSE;
			for (int j=i+1; j<Str::len(escaped); j++) {
				if (Str::get_at(escaped, j) == '|') {
					WRITE("\\hbox{\\tt ");
					for (int k=i+1; k<j; k++) PUT(Str::get_at(escaped, k));
					WRITE("}");
					i = j;
					found = TRUE; break;
				}
			}
			if (found == FALSE) PUT(Str::get_at(escaped, i));
		} else {
			PUT(Str::get_at(escaped, i));
		}
	}
	DISCARD_TEXT(escaped)
	if (displayed) WRITE("$$"); else WRITE("\\INWEBMATH)");
