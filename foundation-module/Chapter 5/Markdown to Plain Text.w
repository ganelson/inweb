[MDRenderPlain::] Markdown to Plain Text.

To render a Markdown tree as plain text.

@h Main rendering recursion.
Do not call this function directly: use the API in //Markdown Rendering//.

=
void MDRenderPlain::recurse(OUTPUT_STREAM, markdown_render *rdr, markdown_item *md, int mode) {
	if (rdr == NULL) internal_error("no render details in recursion");
	if (md == NULL) return;
	if (MarkdownVariations::intervene_in_rendering(rdr->variation, rdr, OUT, md, mode)) return;
	int old_mode = mode;
	switch (md->type) {	
		/* Container blocks */
		case BLOCK_QUOTE_MIT:           @<Render a block quote@>; break;
		case ALERT_MIT:                 @<Render an alert@>; break;
		case UNORDERED_LIST_MIT:        @<Render a list@>; break;
		case ORDERED_LIST_MIT:          @<Render a list@>; break;
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

@ Again, note that `EXISTING_PAR_MDRMODE` propagates only down the leading
edge of the tree: see //Markdown to HTML// for the reason.

@<Recurse@> =
	int m = mode;
	for (markdown_item *c = md->down; c; c = c->next) {
		MDRenderPlain::recurse(OUT, rdr, c, m);
		m = m & (~EXISTING_PAR_MDRMODE);
	}

@h Container block items.

@<Render a block quote@> =
	INDENT;
	WRITE("\n");
	@<Recurse@>;
	WRITE("\n");
	OUTDENT;

@<Render an alert@> =
	int type = Markdown::get_alert_type(md);
	text_stream *name = MarkdownVariations::get_alert_form_name(rdr->variation, type);
	inchar32_t icon = MarkdownVariations::get_alert_form_icon(rdr->variation, type);
	WRITE("\n");
	if (icon) WRITE("! ");
	if (Str::len(name) > 0) {
		PUT(Str::get_at(name, 0));
		for (int i=1; i<Str::len(name); i++) PUT(Characters::tolower(Str::get_at(name, i)));
	} else {
		WRITE("Alert");
	}
	WRITE("\n");		
	@<Recurse@>;
	WRITE("\n");		

@<Render a list@> =
	INDENT; WRITE("\n");
	mode = mode & (~LOOSE_MDRMODE);
	for (markdown_item *ch = md->down; ch; ch = ch->next) {
		if ((ch->next) && (ch->whitespace_follows))
			mode = mode | LOOSE_MDRMODE;
		for (markdown_item *gch = ch->down; gch; gch = gch->next)
			if ((gch->next) && (gch->whitespace_follows))
				mode = mode | LOOSE_MDRMODE;
	}
	@<Recurse@>;
	WRITE("\n"); OUTDENT; 

@<Render a list item@> =
	if (Markdown::get_item_number(md) > 0)
		WRITE("\n* ", Markdown::get_item_number(md));
	else
		WRITE("\n* ");
	int nl_issued = FALSE;
	for (markdown_item *ch = md->down; ch; ch = ch->next)
		if (((mode & LOOSE_MDRMODE) == 0) && (ch->type == PARAGRAPH_MIT)) {
			for (markdown_item *gch = ch->down; gch; gch = gch->next)
				MDRenderPlain::recurse(OUT, rdr, gch, mode);
		} else {
			if (nl_issued == FALSE) { nl_issued = TRUE; WRITE("\n"); }
			MDRenderPlain::recurse(OUT, rdr, ch, mode);
		}
	WRITE("\n");

@<Render a footnote body@> =
	WRITE("[%d] ", md->details);
	@<Recurse@>;

@h Leaf blocks.

@<Render a paragraph@> =
	mode = mode & (~EXISTING_PAR_MDRMODE);
	@<Recurse@>;
	WRITE("\n\n");

@<Render a thematic break@> =
	WRITE("\n\n-----------------------------------------------------------------\n\n");

@<Render a heading@> =
	WRITE("\n{\\bf ");
	@<Recurse@>;
	WRITE("}\n");
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

	MDRenderPlain::render_code_block(OUT, mode, rdr, md->stashed, language_rendered);
	DISCARD_TEXT(language_rendered)

@ Nothing can usefully be done here.

@<Render a raw HTML block@> =
	for (int i=0; i<Str::len(md->stashed); i++)
		MDRenderPlain::char(OUT, Str::get_at(md->stashed, i), 0);

@<Render a table@> =
	markdown_item *alignment_markers = md->down;
	if (alignment_markers) {
		int row_count = 0;
		for (markdown_item *md = alignment_markers->next; md; md = md->next) row_count++;
		if (row_count > 0) {
			WRITE("\n");
			textual_table *T = TextualTables::new_table();
			markdown_item *row = alignment_markers->next;
			int r = 0;
			while (row) {
				if (r++ > 0) TextualTables::begin_row(T);
				for (markdown_item *md = row->down, *top = alignment_markers->down;
					md; md = md->next, top = top->next) {
					if (md->down) {
						TEMPORARY_TEXT(cell)
						MDRenderPlain::recurse(cell, rdr, md->down, mode);
						WRITE_TO(TextualTables::next_cell(T), "%S", cell);
						DISCARD_TEXT(cell)
					}
				}
				row = row->next;
			}
			TextualTables::tabulate(OUT, T);
			WRITE("\n");
		}
	}

@<Render a tickbox@> =
	if (Markdown::get_tick_state(md)) {
		WRITE("[x] ");
	} else {
		WRITE("[ ] ");
	}

@h Inline types.
The fuss over `ALT_TEXT_MDRMODE` does not arise for plain text, since alt-text
does not exist in the absence of images, and even if it did, it would just be
plain text in the same way that all other material is. So we don't check for this.

@<Render plain text@> =
	MDRender::slice(OUT, rdr, md, mode);

@<Render a line break@> =
	MDRenderPlain::char(OUT, '\n', mode);

@<Render a soft line break@> =
	MDRenderPlain::char(OUT, '\n', mode);

@<Render emphasised text@> =
	@<Recurse@>;

@<Render strongly emphasised text@> =
	@<Recurse@>;

@<Render inline code sample@> =
	mode = mode & (~ESCAPES_MDRMODE);
	mode = mode & (~ENTITIES_MDRMODE);
	mode = mode | (INLINECODE_MDRMODE);
	MDRender::slice(OUT, rdr, md, mode);

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
	MDRender::stream(OUT, rdr, address, mode);
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
			MDRenderPlain::recurse(URI, rdr, md->down->next, mode | URI_MDRMODE);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderPlain::recurse(title, rdr, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderPlain::recurse(title, rdr, md->down->next, mode);
		}
		MDRenderPlain::recurse(OUT, rdr, md->down, mode);
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)

@<Render footnote instead@> =
	markdown_item *body = MDRender::seek_footnote_body(rdr, md->details);
	if (body == NULL) WRITE("[Missing footnote?]");
	else WRITE("[%d]", md->details);

@<Render image@> =
	TEMPORARY_TEXT(URI)
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(alt)
	if (md->down->next) {
		if (md->down->next->type == LINK_DEST_MIT) {
			MDRenderPlain::recurse(URI, rdr, md->down->next, mode);
			if ((md->down->next->next) && (md->down->next->next->type == LINK_TITLE_MIT))
				MDRenderPlain::recurse(title, rdr, md->down->next->next, mode);
		} else if (md->down->next->type == LINK_TITLE_MIT) {
			MDRenderPlain::recurse(title, rdr, md->down->next, mode);
		}
	}
	MDRenderPlain::recurse(alt, rdr, md->down, mode | ALT_TEXT_MDRMODE);
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
		if (Str::len(alt) > 0) WRITE("[Image: %S]\n", alt);
		else WRITE("[IMAGE %S HERE]\n", URI);
	}
	DISCARD_TEXT(URI)
	DISCARD_TEXT(title)
	DISCARD_TEXT(alt)

@<Render link destination@> =
	mode = mode | URI_MDRMODE;
	MDRender::slice(OUT, rdr, md->down, mode);

@<Render struck-through text@> =
	@<Recurse@>;

@<Render maths matter in TeX@> =
	TEMPORARY_TEXT(TEX)
	if (MarkdownVariations::supports(rdr->variation, ALT_TEX_MARKDOWNFEATURE)) {
		int m = RAW_MDRMODE;
		for (markdown_item *c = md->down; c; c = c->next) {
			MDRenderPlain::recurse(TEX, rdr, c, m);
			m = m & (~EXISTING_PAR_MDRMODE);
		}
	} else {
		for (int i=md->from; i<=md->to; i++) {
			inchar32_t c = Markdown::get_at(md, i);
			PUT_TO(TEX, c);
		}
	}
	TEMPORARY_TEXT(PARAPHRASE)
	MDRender::remove_math_mode(OUT, TEX, TRUE);
	if (md->type == DISPLAYED_TEX_MIT) {
		WRITE("\n\n");
		int width = Str::len(PARAPHRASE);
		if (width < 80) for (int i=0; i<(80-width)/2; i++) PUT(' ');
		WRITE("%S", PARAPHRASE);
		WRITE("\n\n");
	} else {
		WRITE("%S", PARAPHRASE);
	}
	DISCARD_TEXT(PARAPHRASE)

@<Render Inweb link@> =
	MDRenderPlain::recurse(OUT, rdr, md->down, mode);

@h Character output.

=
void MDRenderPlain::char(OUTPUT_STREAM, inchar32_t c, int mode) {
	if (mode & TOLOWER_MDRMODE) c = Characters::tolower(c);
	if (mode & URI_MDRMODE) {
		if (c >= 0x10000) {
			MARKDOWNPLAIN_URI_HEX(0xF0 + (unsigned char) (c >> 18));
			MARKDOWNPLAIN_URI_HEX(0x80 + (unsigned char) ((c >> 12) & 0x3f));
			MARKDOWNPLAIN_URI_HEX( 0x80 + (unsigned char) ((c >> 6) & 0x3f));
			MARKDOWNPLAIN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else if (c >= 0x800) {
			MARKDOWNPLAIN_URI_HEX(0xE0 + (unsigned char) (c >> 12));
			MARKDOWNPLAIN_URI_HEX(0x80 + (unsigned char) ((c >> 6) & 0x3f));
			MARKDOWNPLAIN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else if (c >= 0x80) {
			MARKDOWNPLAIN_URI_HEX(0xC0 + (unsigned char) (c >> 6));
			MARKDOWNPLAIN_URI_HEX(0x80 + (unsigned char) (c & 0x3f));
		} else {
			switch (c) {
				case '[': MARKDOWNPLAIN_URI_HEX((unsigned char) c); break;
				case '\\':MARKDOWNPLAIN_URI_HEX((unsigned char) c); break;
				case '\"':MARKDOWNPLAIN_URI_HEX((unsigned char) c); break;
				case ']': MARKDOWNPLAIN_URI_HEX((unsigned char) c); break;
				case '`': MARKDOWNPLAIN_URI_HEX((unsigned char) c); break;
				case ' ': MARKDOWNPLAIN_URI_HEX((unsigned char) c); break;
				default: PUT(c); break;
			}
		}
	} else {
		PUT(c);
	}
}

@ Where:

@d MARKDOWNPLAIN_URI_HEX(x) {
		unsigned int z = (unsigned int) x;
		PUT('%');
		MDRender::hex_digit(OUT, z >> 4);
		MDRender::hex_digit(OUT, z & 0x0f);
	}

@h Code block rendering.
This is very simple, since syntax-colouring can be ignored completely.

=
void MDRenderPlain::render_code_block(OUTPUT_STREAM, int mode, markdown_render *rdr,
	text_stream *code, text_stream *language_name) {
	MDRender::stream(OUT, rdr, code, INLINECODE_MDRMODE);
}
