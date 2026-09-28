[MDRenderTeX::] Markdown to TeX.

To render a Markdown tree as TeX.

@h Main rendering recursion.
Do not call this function directly: use the API in //Markdown Rendering//.

Note that `FOOTNOTE_BODY_MIT` content is not in fact ignored: it's rendered
out of the normal traverse sequence, since in TeX the footnote content has
to be placed at the same position in the output as its cue.

=
void MDRenderTeX::recurse(OUTPUT_STREAM, markdown_render *rdr, markdown_item *md, int mode) {
	if (rdr == NULL) internal_error("no render details in recursion");
	if (md == NULL) return;
	if (MarkdownVariations::intervene_in_rendering(rdr->variation, rdr, OUT, md, mode)) return;
	int old_mode = mode;
	switch (md->type) {	
		/* Container blocks */
		case BLOCK_QUOTE_MIT:           @<Render a block quote@>; break;
		case ALERT_MIT:                 @<Render an alert@>; break;
		case UNORDERED_LIST_MIT:        @<Render an unordered list@>; break;
		case ORDERED_LIST_MIT:          @<Render an ordered list@>; break;
		case UNORDERED_LIST_ITEM_MIT:   @<Render a list item@>; break;
		case ORDERED_LIST_ITEM_MIT:     @<Render a list item@>; break;
		case FOOTNOTE_BODY_MIT:         break;

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

@ Again, note that `EXISTING_PAR_MDRMODE` propagates only down the leading
edge of the tree: see //Markdown to HTML// for the reason.

@<Recurse@> =
	int m = mode;
	for (markdown_item *c = md->down; c; c = c->next) {
		MDRenderTeX::recurse(OUT, rdr, c, m);
		m = m & (~EXISTING_PAR_MDRMODE);
	}

@h Container block items.

@<Render a block quote@> =
	WRITE("\\smallskip\\par{\\narrower\\narrower\\noindent");
	WRITE("\n");
	@<Recurse@>;
	WRITE("\\smallskip}\n");

@<Render an alert@> =
	int type = Markdown::get_alert_type(md);
	text_stream *name = MarkdownVariations::get_alert_form_name(rdr->variation, type);
	inchar32_t icon = MarkdownVariations::get_alert_form_icon(rdr->variation, type);
	WRITE("{\\narrower\\smallskip\\noindent");
	WRITE("\n");
	if (icon) WRITE("$\\otimes$ ");
	WRITE("{\\bf ");
	if (Str::len(name) > 0) {
		PUT(Str::get_at(name, 0));
		for (int i=1; i<Str::len(name); i++) PUT(Characters::tolower(Str::get_at(name, i)));
	} else {
		WRITE("Alert");
	}
	WRITE("}\n\n\\noindent ");		
	@<Recurse@>;
	WRITE("\\smallskip}\n");

@<Render an unordered list@> =
	int skip_ul_rendering = FALSE;
	if (MarkdownVariations::supports(rdr->variation, GADGETS_MARKDOWNFEATURE))
		skip_ul_rendering = MDRender::render_ul_as_carousel(OUT, mode, rdr, md);

	if (skip_ul_rendering == FALSE) {
		WRITE("\\beginunenumerate\n");
		@<Recurse through list@>;
		WRITE("\\endunenumerate\n");
	}

@<Render an ordered list@> =
	WRITE("\\beginenumerate\n");
	@<Recurse through list@>;
	WRITE("\\endenumerate\n");

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

@ In the case of an enumerated list, the number printing will be delegated
to the TeX macro (which has redefined `\item` temporarily), so we won't
make use of `Markdown::get_item_number(md)` here, perhaps unexpectedly.

@<Render a list item@> =
	WRITE("\n\\item ");
	int nl_issued = FALSE;
	for (markdown_item *ch = md->down; ch; ch = ch->next)
		if (((mode & LOOSE_MDRMODE) == 0) && (ch->type == PARAGRAPH_MIT)) {
			for (markdown_item *gch = ch->down; gch; gch = gch->next)
				MDRenderTeX::recurse(OUT, rdr, gch, mode);
		} else {
			if (nl_issued == FALSE) { nl_issued = TRUE; WRITE("\\smallskip\n"); }
			MDRenderTeX::recurse(OUT, rdr, ch, mode);
		}
	WRITE("\n");

@h Leaf blocks.

@<Render a paragraph@> =
	mode = mode & (~EXISTING_PAR_MDRMODE);
	@<Recurse@>;
	WRITE("\n\n");

@<Render a thematic break@> =
	WRITE("\n\\bigskip\\hrule\\bigskip\n\n");

@<Render a heading@> =
	switch (Markdown::get_heading_level(md)) {
		case 1: case 2:
			WRITE("\n\\medskip\\par\\noindent{\\bf ");
			@<Recurse@>;
			WRITE("}\n\n");
			break;
		default:
			WRITE("\n\\medskip\\par\\noindent{\\it ");
			@<Recurse@>;
			WRITE("}\n\n");
			break;
	}

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

	MDRenderTeX::render_code_block(OUT, mode, rdr, md->stashed, language_rendered);
	DISCARD_TEXT(language_rendered)

@<Render a raw HTML block@> =
	for (int i=0; i<Str::len(md->stashed); i++)
		MDRenderTeX::char(OUT, Str::get_at(md->stashed, i), 0);

@<Render a table@> =
	markdown_item *alignment_markers = md->down;
	if (alignment_markers) {
		int row_count = 0;
		for (markdown_item *md = alignment_markers->next; md; md = md->next) row_count++;
		if (row_count > 0) {
			WRITE("\n\\medskip\\centerline{\\vbox{\\offinterlineskip\n\\hrule\n");
			WRITE("\\halign{");
			int col_count = 0;
			markdown_item *row = alignment_markers->next;
			for (markdown_item *md = row->down, *top = alignment_markers->down;
				md; md = md->next, top = top->next) {
				switch (Markdown::get_alignment(top)) {
					case 0: WRITE("&\\vrule#&\\strut\\quad\\hfil#\\hfil\\quad"); break;
					case 1: WRITE("&\\vrule#&\\strut\\quad#\\hfil\\quad"); break;
					case 2: WRITE("&\\vrule#&\\strut\\quad\\hfil#\\quad"); break;
					case 3: WRITE("&\\vrule#&\\strut\\quad\\hfil#\\hfil\\quad"); break;
				}
				col_count++;
			}
			WRITE("\\cr\n");
			@<Small vertical spacing inside ruled table@>;
			for (markdown_item *md = row->down, *top = alignment_markers->down;
				md; md = md->next, top = top->next) {
				WRITE("&");
				if (md->down) MDRenderTeX::recurse(OUT, rdr, md->down, mode | DECATCODE_MDRMODE);
				WRITE("&");
			}
			WRITE("\\cr\n");
			@<Small vertical spacing inside ruled table@>;
			WRITE("\\noalign{\\hrule}\n");
			@<Small vertical spacing inside ruled table@>;
			row = row->next;
			if (row_count > 1) {
				while (row) {
					for (markdown_item *md = row->down, *top = alignment_markers->down;
						md; md = md->next, top = top->next) {
						WRITE("&");
						if (md->down) MDRenderTeX::recurse(OUT, rdr, md->down, mode | DECATCODE_MDRMODE);
						WRITE("&");
					}
					WRITE("\\cr\n");
					row = row->next;
				}
			}
			@<Small vertical spacing inside ruled table@>;
			WRITE("}\\hrule}}\\medskip\n\n");
		}
	}

@<Small vertical spacing inside ruled table@> =
	WRITE("height2pt");
	for (int i=0; i<col_count; i++) WRITE("&\\omit&");
	WRITE("\\cr\n");

@<Render a tickbox@> =
	if (Markdown::get_tick_state(md)) {
		WRITE("<input checked=\"\" disabled=\"\" type=\"checkbox\"> ");
	} else {
		WRITE("<input disabled=\"\" type=\"checkbox\"> ");
	}

@h Inline types.

@<Render plain text@> =
	MDRender::slice(OUT, rdr, md, mode);

@<Render a line break@> =
	WRITE("<br />\n");

@<Render a soft line break@> =
	MDRenderTeX::char(OUT, '\n', mode);

@<Render emphasised text@> =
	WRITE("{\\it ");
	@<Recurse@>;
	WRITE("}");

@<Render strongly emphasised text@> =
	WRITE("{\\bf ");
	@<Recurse@>;
	WRITE("}");

@<Render inline code sample@> =
	WRITE("|");
	mode = mode & (~ESCAPES_MDRMODE);
	mode = mode & (~ENTITIES_MDRMODE);
	mode = mode | (INLINECODE_MDRMODE);
	MDRender::slice(OUT, rdr, md, mode);
	WRITE("|");

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
	MDRenderTeX::link(OUT, rdr, supplied_scheme, address, mode);
	MDRender::stream(OUT, rdr, address, mode);
	MDRenderTeX::end_link(OUT, mode);
	DISCARD_TEXT(address)

@<Render inline HTML content@> =
	mode = mode | RAW_MDRMODE;
	if (Markdown::get_filtered_state(md)) mode = mode | FILTERED_MDRMODE;
	mode = mode & (~ESCAPES_MDRMODE);
	mode = mode & (~ENTITIES_MDRMODE);
	MDRender::slice(OUT, rdr, md, mode);

@<Render link@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	if (md->details > 0) {
		@<Render footnote instead@>;
	} else if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderTeX::recurse(URI, rdr, md->down->next, mode | URI_MDRMODE);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderTeX::recurse(title, rdr, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderTeX::recurse(title, rdr, md->down->next, mode);
		}
		MDRenderTeX::link(OUT, rdr, I"", URI, mode);
		MDRenderTeX::recurse(OUT, rdr, md->down, mode);
			MDRenderTeX::end_link(OUT, mode);
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)

@<Render footnote instead@> =
	markdown_item *body = MDRender::seek_footnote_body(rdr, md->details);
	if (body == NULL) WRITE("{\\bf [Missing footnote?]}");
	else {
		WRITE("\\footnote{${}^{%d}$}{", md->details);
		int m = mode;
		markdown_item *r_from = body->down;
		for (markdown_item *c = r_from; c; c = c->next) {
			MDRenderTeX::recurse(OUT, rdr, c, m);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
		WRITE("}");
	}

@

@d INWEB_POINTS_PER_CM 72

@<Render image@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(alt)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderTeX::recurse(URI, rdr, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderTeX::recurse(title, rdr, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderTeX::recurse(title, rdr, md->down->next, mode);
		}
	}
	MDRenderTeX::recurse(alt, rdr, md->down, mode | ALT_TEXT_MDRMODE);
	int skip_image_rendering = FALSE;
	if (MarkdownVariations::supports(rdr->variation, GADGETS_MARKDOWNFEATURE))
		skip_image_rendering =
			MDRender::render_gadget(OUT, rdr, mode, alt, URI);

	if (skip_image_rendering == FALSE) {
		int w = -1, h = -1;
		if (rdr) {
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
		}

		MDRender::notify_image(rdr, URI);
		if ((w < 0) && (h < 0)) w = INWEB_POINTS_PER_CM*15;
		if ((w > 0) && (h > 0)) WRITE("\\inwebimagewidthheight{%S}{%d}{%d}\n",
			URI, w/INWEB_POINTS_PER_CM, h/INWEB_POINTS_PER_CM);
		else if (w >= 0) WRITE("\\inwebimagewidth{%S}{%d}\n", URI, w/INWEB_POINTS_PER_CM);
		else if (h >= 0) WRITE("\\inwebimageheight{%S}{%d}\n", URI, h/INWEB_POINTS_PER_CM);
		else WRITE("\\inwebimage{%S}\n", URI);
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)
	DISCARD_TEXT(alt)

@<Render link destination@> =
	mode = mode | URI_MDRMODE;
	MDRender::slice(OUT, rdr, md->down, mode);

@<Render struck-through text@> =
	WRITE("\\strikethrough{");
	@<Recurse@>;
	WRITE("}");

@<Render maths matter in TeX@> =
	TEMPORARY_TEXT(TEX)
	if (MarkdownVariations::supports(rdr->variation, ALT_TEX_MARKDOWNFEATURE)) {
		int m = RAW_MDRMODE;
		for (markdown_item *c = md->down; c; c = c->next) {
			MDRenderTeX::recurse(TEX, rdr, c, m);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
	} else {
		for (int i=md->from; i<=md->to; i++) {
			inchar32_t c = Markdown::get_at(md, i);
			PUT_TO(TEX, c);
		}
	}
	if (md->type == DISPLAYED_TEX_MIT) WRITE("$$"); else WRITE("$");
	WRITE("%S", TEX);
	if (md->type == DISPLAYED_TEX_MIT) WRITE("$$"); else WRITE("$");
	DISCARD_TEXT(TEX)

@<Render Inweb link@> =
	TEMPORARY_TEXT(address)
	MDRenderTeX::recurse(address, rdr, md->down, RAW_MDRMODE);
	query_results qr = MDRender::resolve_link(rdr, address);
	if ((qr.found) && (qr.external == FALSE) && (Str::len(qr.internal_xref) == 0))
		qr.found = FALSE;
	if (qr.found) {
		if (qr.external) {
			MDRenderTeX::link(OUT, rdr, I"", qr.url, mode);
		} else {
			MDRenderTeX::link_internal(OUT, qr.internal_xref, mode);
		}
		WRITE("%S", qr.title);
		MDRenderTeX::end_link(OUT, mode);
	} else {
		WRITE("{\\bf ");
		WRITE("[Unresolved link: ");
		MDRender::stream(OUT, rdr, address, mode);
		WRITE("]");
		WRITE("}");
	}
	DISCARD_TEXT(address)
	MDRender::dispose_of(&qr);

@h Character output.
`DECATCODE_MDRMODE` is an infuriating expedient. The verbatim text macros,
following those in the TeXBook, set the `\catcode` of various significant
characters to 12 ("other"), thus deactivating their normal function, within
the `|` and `|` delimiters: thus, `|5&10$|` is rendered by TeX (plus our macros)
as the five literal characters in the middle. _However_, timing issues in
the way the `\halign` table mechanism works mean that it is too late to change
catcodes because the table cell contents have already been expanded: in other
words, our regular way to deactivate these characters fails for inline code
extracts within table cells. So we have a special mode which deactivates them
by hand. Note that this relies on `\` having its regular catcode; this is why
we can't use that trick in every inline code extract, only those where we know
ordinary catcode changing has been thwarted.

=
void MDRenderTeX::char(OUTPUT_STREAM, inchar32_t c, int mode) {
	if (mode & TOLOWER_MDRMODE) c = Characters::tolower(c);
	if (mode & INLINECODE_MDRMODE) {
		if (c == '|') {
			WRITE("|{\\tt\\|}|");
		} else if (mode & DECATCODE_MDRMODE) {
			switch (c) {
 				case '\\': WRITE("|$\\backslash$|"); break;
				case '{': WRITE("|$\\{$|"); break;
				case '}': WRITE("|$\\}$|"); break;
				case '$': WRITE("\\$"); break;
				case '&': WRITE("\\&"); break;
				case '#': WRITE("\\#"); break;
				case '%': WRITE("\\%%"); break;
				case '~': WRITE("|\\tt\\char`~|"); break;
				case '_': WRITE("\\_"); break;
				case '^': WRITE("\\char`^"); break;
				default: PUT(c); break;
			}			
		} else {
			PUT(c);
		}
	} else if (mode & RAW_MDRMODE) {
		PUT(c);
	} else if (mode & URI_MDRMODE) {
		if (c >= 0x10000) {
			MARKDOWNTEX_URI_HEX(0xF0 + (unsigned char) (c >> 18));
			MARKDOWNTEX_URI_HEX(0x80 + (unsigned char) ((c >> 12) & 0x3f));
			MARKDOWNTEX_URI_HEX( 0x80 + (unsigned char) ((c >> 6) & 0x3f));
			MARKDOWNTEX_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else if (c >= 0x800) {
			MARKDOWNTEX_URI_HEX(0xE0 + (unsigned char) (c >> 12));
			MARKDOWNTEX_URI_HEX(0x80 + (unsigned char) ((c >> 6) & 0x3f));
			MARKDOWNTEX_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else if (c >= 0x80) {
			MARKDOWNTEX_URI_HEX(0xC0 + (unsigned char) (c >> 6));
			MARKDOWNTEX_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else {
			switch (c) {
				case '%': WRITE("\\%%"); break;
				case '<': WRITE("\\&lt;"); break;
				case '&': WRITE("\\&amp;"); break;
				case '#': WRITE("\\#;"); break;
				case '>': WRITE("\\&gt;"); break;
				case '[': MARKDOWNTEX_URI_HEX((unsigned char) c); break;
				case '\\':MARKDOWNTEX_URI_HEX((unsigned char) c); break;
				case '\"':MARKDOWNTEX_URI_HEX((unsigned char) c); break;
				case ']': MARKDOWNTEX_URI_HEX((unsigned char) c); break;
				case '`': MARKDOWNTEX_URI_HEX((unsigned char) c); break;
				case ' ': MARKDOWNTEX_URI_HEX((unsigned char) c); break;
				default: PUT(c); break;
			}
		}
	} else {
		switch (c) {
			case '{': WRITE("$\\{$"); break;
			case '}': WRITE("$\\}$"); break;
			case '&': WRITE("\\&"); break;
			case '%': WRITE("\\%%"); break;
			case '$': WRITE("\\$"); break;
			case '~': WRITE("\\char`~"); break;
			case '#': WRITE("\\#"); break;
			case '\\': WRITE("$\\backslash$"); break;
			case '_': WRITE("\\_"); break;
			case '|': WRITE("\\|"); break;
			case '^': WRITE("\\char`^"); break;
			case '"': WRITE("{\\tt\"}"); break;
			case '<': WRITE("{\\tt<}"); break;
			case '>': WRITE("{\\tt>}"); break;
			case '\'': WRITE("{\\tt\\char'15}"); break;
			case 0x201C: WRITE("``"); break;
			case 0x201D: WRITE("''"); break;
			case 0x2018: WRITE("`"); break;
			case 0x2019: WRITE("'"); break;
			default: PUT(c); break;
		}
	}
}

@ Note the need to escape the percent character, which is a comment in TeX.

@d MARKDOWNTEX_URI_HEX(x) {
		unsigned int z = (unsigned int) x;
		PUT('\\'); PUT('%');
		MDRender::hex_digit(OUT, z >> 4);
		MDRender::hex_digit(OUT, z & 0x0f);
	}

@h Links.
Links are all delegated to TeX macros, so that they can work differently in
different TeX variants.

=
void MDRenderTeX::link(OUTPUT_STREAM, markdown_render *rdr,
	text_stream *supplied_scheme, text_stream *address, int mode) {
	WRITE("{\\inweblinktourl{");
	MDRender::stream(OUT, rdr, supplied_scheme, RAW_MDRMODE);
	MDRender::stream(OUT, rdr, address, RAW_MDRMODE);
	WRITE("}{");
}
void MDRenderTeX::link_internal(OUTPUT_STREAM, text_stream *nameid, int mode) {
	WRITE("{\\inweblinktoanchor{%S}{", nameid);
}
void MDRenderTeX::end_link(OUTPUT_STREAM, int mode) {
	WRITE("}}");
}

@h Code block rendering.

=
void MDRenderTeX::render_code_block(OUTPUT_STREAM, int mode, markdown_render *rdr,
	text_stream *code, text_stream *language_name) {
	WRITE("\\beginlines\n\\hskip1em");
	TEMPORARY_TEXT(colouring)
	void *colours = NULL;
	MDRender::colour_code_block(rdr, language_name, code, colouring, &colours);
	MDRenderTeX::render_syntax_coloured(OUT, rdr, code, colouring, colours);
	DISCARD_TEXT(colouring)
	WRITE("\\endlines\n");
}

void MDRenderTeX::render_syntax_coloured(OUTPUT_STREAM, markdown_render *rdr, text_stream *code,
	text_stream *colouring, void *colours) {
	WRITE("|");
	MDRender::render_code_block(OUT, rdr, code, colouring, colours, I"|\n\\hskip1em|", MDRenderTeX::change_colour);
	WRITE("|");
}

void MDRenderTeX::change_colour(text_stream *OUT, markdown_render *rdr, int col, void *cs) {
	WRITE("|");
	if (col == -1) {
		WRITE("\\endcolouring{}");
	} else {
		TEMPORARY_TEXT(cl)
		MDRender::name_colour(rdr, cl, col);
		if (Str::len(cl) == 0) {
			PRINT("col: %d\n", col); internal_error("bad colour");
		} else {
			WRITE("\\");
			if (cs) {
				TEMPORARY_TEXT(csname)
				MDRender::name_colour_scheme(rdr, csname, cs);
				for (int i=0; i<Str::len(csname); i++)
					if (Characters::isalpha(Str::get_at(csname, i)))
						PUT(Characters::tolower(Str::get_at(csname, i)));
				DISCARD_TEXT(csname)
			}
			if (cl)
				for (int i=0; i<Str::len(cl); i++)
					if (Characters::isalpha(Str::get_at(cl, i)))
						PUT(Characters::tolower(Str::get_at(cl, i)));
			WRITE("colouring{}");
		}
		DISCARD_TEXT(cl)
	}
	WRITE("|");
}
