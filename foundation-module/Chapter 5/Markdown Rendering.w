[MDRender::] Markdown Rendering.

To render a Markdown tree to a human-readable format, such as HTML.

@h Public API.
Rendering Markdown is blessedly simple by comparison with parsing it, but we
want to be flexible in how we generate our output, and it is not altogether
simple to work out how best to express this. The following provides a public
API which tries to capture that.

To render Markdown in `md` to some format, first create a `markdown_render`
order giving details of the exact Markdown variation used and the output
required, and then call this:

=
void MDRender::render(OUTPUT_STREAM, markdown_render *rdr, markdown_item *md) {
	if (rdr == NULL) internal_error("no render details");
	rdr->home = md;
	MDRender::render_in_mode(OUT, rdr, md, MDRender::entry_mode(rdr));
}

@ These four special cases are provided as conveniences:

=
void MDRender::render_CommonMark(OUTPUT_STREAM, markdown_item *tree) {
	MDRender::render_as_HTML(OUT, tree, MarkdownVariations::CommonMark());
}

void MDRender::render_as_HTML(OUTPUT_STREAM, markdown_item *tree,
	markdown_variation *variation) {
	markdown_render rdr = MDRender::context_free_HTML(variation);
	MDRender::render(OUT, &rdr, tree);
}

void MDRender::render_as_plain_text(OUTPUT_STREAM, markdown_variation *var, markdown_item *tree) {
	markdown_render rdr = MDRender::context_free_plain_text(var);
	MDRender::render(OUT, &rdr, tree);
}

void MDRender::render_as_Inform_example(OUTPUT_STREAM, markdown_item *tree,
	markdown_variation *variation) {
	markdown_render rdr = MDRender::context_free_HTML(variation);
	rdr.extra_modes = EXAMPLE_BODIES_MDRMODE;
	MDRender::render(OUT, &rdr, tree);
}

@ Render orders can be set up using the following creator functions. Note that
they return structs, rather than pointers to allocated memory: their lifetime
should only be the time taken for the render, and no `markdown_render` objects
should ever need to persist.

Once created, a `markdown_render` should not be modified by the end user,
except possibly to add methods which will customise the form of rendering.

=
classdef markdown_render {
	struct general_pointer context;
	struct markdown_variation *variation;
	int extra_modes;
	struct method_set *methods; /* provide for extensible format rendering */
	struct markdown_item *home; /* set during rendering */
	void (*recurse)(struct text_stream *, struct markdown_render *, struct markdown_item *, int);
	void (*char_out)(struct text_stream *, inchar32_t, int);
}

@ For reasons of efficiency, the `recurse` and `char_out` functions for rendering
are not stored as methods: that incurs a modest overhead, and we'll be recursing
and writing characters often enough that any overhead is best avoided.

=
markdown_render MDRender::context_free(markdown_variation *var,
	void (*recurse)(struct text_stream *, struct markdown_render *, struct markdown_item *, int),
	void (*char_out)(struct text_stream *, inchar32_t, int)) {
	markdown_render rdr;
	rdr.recurse = recurse;
	rdr.char_out = char_out;
	rdr.context = NULL_GENERAL_POINTER;
	rdr.methods = Methods::new_set();
	rdr.variation = var;
	rdr.extra_modes = 0;
	rdr.home = NULL;
	return rdr;
}

@ Conveniences for the three main renderers provided by `foundation`:

=
markdown_render MDRender::context_free_HTML(markdown_variation *var) {
	return MDRender::context_free(var, MDRenderHTML::recurse, MDRenderHTML::char);
}

markdown_render MDRender::context_free_TeX(markdown_variation *var) {
	markdown_render rdr = MDRender::context_free(var, MDRenderTeX::recurse, MDRenderTeX::char);
	rdr.extra_modes = SMARTEN_MDRMODE;
	return rdr;
}

markdown_render MDRender::context_free_LaTeX(markdown_variation *var) {
	markdown_render rdr = MDRender::context_free(var, MDRenderLaTeX::recurse, MDRenderLaTeX::char);
	rdr.extra_modes = SMARTEN_MDRMODE;
	return rdr;
}

markdown_render MDRender::context_free_plain_text(markdown_variation *var) {
	return MDRender::context_free(var, MDRenderPlain::recurse, MDRenderPlain::char);
}

@ The main `foundation` Markdown renderer ignores the optional context field;
but methods applied for customisation may well want to use it.

=
markdown_render MDRender::contextual(markdown_variation *var,
	void (*recurse)(struct text_stream *, struct markdown_render *, struct markdown_item *, int),
	void (*char_out)(struct text_stream *, inchar32_t, int),
	general_pointer context) {
	markdown_render rdr = MDRender::context_free(var, recurse, char_out);
	rdr.context = context;
	return rdr;
}

@ Conveniences once again:

=
markdown_render MDRender::contextual_HTML(markdown_variation *var, general_pointer context) {
	return MDRender::contextual(var, MDRenderHTML::recurse, MDRenderHTML::char, context);
}

markdown_render MDRender::contextual_TeX(markdown_variation *var, general_pointer context) {
	markdown_render rdr = MDRender::contextual(var, MDRenderTeX::recurse, MDRenderTeX::char, context);
	rdr.extra_modes = SMARTEN_MDRMODE;
	return rdr;
}

markdown_render MDRender::contextual_LaTeX(markdown_variation *var, general_pointer context) {
	markdown_render rdr = MDRender::contextual(var, MDRenderLaTeX::recurse, MDRenderLaTeX::char, context);
	rdr.extra_modes = SMARTEN_MDRMODE;
	return rdr;
}

markdown_render MDRender::contextual_plain_text(markdown_variation *var, general_pointer context) {
	return MDRender::contextual(var, MDRenderPlain::recurse, MDRenderPlain::char, context);
}

@h Methods to customise rendering.
The following method functions can be added to a `markdown_render`.

First, we can provide a custom way to handle an `INWEB_LINK_MIT`. This is an
extension to regular Markdown and handles the `//...//` links used therein:
those can only be sorted out in context of the web and colony surrounding
the commentary, which goes far beyond anything `foundation` knows about.

The text `url` holds the purported destination of the link. This function
returns `TRUE` if it successfully resolves this to an actual location, which
it can do in one of two ways:

- if `ext` is set to `TRUE`, this is a World Wide Web link, and `title` is set to
  its title (in the sense of the HTML `<a href...>` element), while `address` is set
  to the URL;
- if `ext` is set to `FALSE`, this is a cross-reference to some anchor point
  within whatever our user is creating: `token` is set to some non-`NULL`
  pointer meaningful to that user but not to us. `title` and `address` may
  still be set if the format is HTML and the link will be handled through
  `<a href...>`.

@e RESOLVE_LINK_MTID

=
classdef query_results {
	int found;
	int external;
	struct text_stream *url;
	struct text_stream *title;
	struct text_stream *text;
	struct text_stream *internal_xref;
	void *token;
}

query_results MDRender::create_qr(void) {
	query_results qr;
	qr.found = FALSE;
	qr.external = FALSE;
	qr.url = NULL;
	qr.title = NULL;
	qr.text = NULL;
	qr.internal_xref = NULL;
	qr.token = NULL;
	return qr;
}

void MDRender::dispose_of(query_results *qr) {
	if (qr) {
		qr->found = FALSE;
		if (qr->url) STREAM_CLOSE(qr->url);
		if (qr->title) STREAM_CLOSE(qr->title);
		if (qr->text) STREAM_CLOSE(qr->text);
	}
}

VOID_METHOD_TYPE(RESOLVE_LINK_MTID, markdown_render *rdr, text_stream *address, query_results *qr)

query_results MDRender::resolve_link(markdown_render *rdr, text_stream *address) {
	query_results qr = MDRender::create_qr();
	VOID_METHOD_CALL(rdr, RESOLVE_LINK_MTID, address, &qr);
	return qr;
}

@ In the event that the function above returns a `token` for an anchor link, the
following should then be used to provide its "name". This is only likely to be
useful if the link is being done by some mechanism other than HTML's.

@e NAME_ANCHOR_MTID

=
VOID_METHOD_TYPE(NAME_ANCHOR_MTID, markdown_render *rdr, text_stream *OUT, void *token)

void MDRender::anchor_name(markdown_render *rdr, text_stream *OUT, void *token) {
	VOID_METHOD_CALL(rdr, NAME_ANCHOR_MTID, OUT, token);
}

@ Now for syntax-colouring. We abstract the idea of syntax-colouring like so:
each different colour used is represented by a character code. `foundation`
will define only one of these, and only to ensure that code compiles properly:

@default PLAIN_COLOUR 'p'

@ If syntax-colouring is needed, then a whole suite of those will be defined
by the end user. A method is provided to give names to these: for example,
this might output `plain` when given `PLAIN_COLOUR`.

@e NAME_COLOUR_MTID

=
VOID_METHOD_TYPE(NAME_COLOUR_MTID, markdown_render *rdr, text_stream *OUT, int c)

void MDRender::name_colour(markdown_render *rdr, text_stream *OUT, int c) {
	int len = Str::len(OUT);
	VOID_METHOD_CALL(rdr, NAME_COLOUR_MTID, OUT, c);
	if ((Str::len(OUT) == len) && (c == PLAIN_COLOUR)) WRITE("plain");
}

@ We support the concept of colour schemes, which have different names (for
example, maybe one is used for C and another for Rust): exactly what identifies
a colour scheme is opaque to us here.

@e NAME_COLOUR_SCHEME_MTID

=
VOID_METHOD_TYPE(NAME_COLOUR_SCHEME_MTID, markdown_render *rdr, text_stream *OUT, void *scheme)

void MDRender::name_colour_scheme(markdown_render *rdr, text_stream *OUT, void *scheme) {
	VOID_METHOD_CALL(rdr, NAME_COLOUR_SCHEME_MTID, OUT, scheme);
}

@ Actual colouring of a passage of code works like so: first, `MDRender::begin_colouring`
must be called; and then `MDRender::colour_line` is called on each line in turn until
the passage is complete.

Note that a `BEGIN_COLOURING_MTID` method should respond by writing a "token" value,
a pointer which is opaque to us, but which is then passed through to the corresponding
`COLOUR_LINE_MTID` method. For example, Inweb uses this to turn a textual name of a
programming language ("C++", say) into a pointer to an object describing how to
syntax-colour that language. This pointer becomes the "token".

The colouring for a line is a string of characters giving the colours which
correspond to the code characters. For example, `x = 21` might be coloured
as `ipppdd`, if colours `i`, `p`, and `d` are used for identifier, plain,
and digit.

@e BEGIN_COLOURING_MTID
@e COLOUR_LINE_MTID

=
VOID_METHOD_TYPE(BEGIN_COLOURING_MTID, markdown_render *rdr,
	text_stream *language_name, void **token, void **colours)
VOID_METHOD_TYPE(COLOUR_LINE_MTID, markdown_render *rdr, void *token,
	text_stream *code_line, text_stream *cols)

void *MDRender::begin_colouring(markdown_render *rdr, text_stream *language_name, void **colours) {
	void *token = NULL;
	VOID_METHOD_CALL(rdr, BEGIN_COLOURING_MTID, language_name, &token, colours);
	return token;
}

void MDRender::colour_line(markdown_render *rdr, void *token, text_stream *code_line,
	text_stream *cols) {
	VOID_METHOD_CALL(rdr, COLOUR_LINE_MTID, token, code_line, cols);
}

@ Some renderers will need to know which images have been used, so this method
is called when that happens:

@e NOTIFY_IMAGE_MTID

=
VOID_METHOD_TYPE(NOTIFY_IMAGE_MTID, markdown_render *rdr, text_stream *URI)

void MDRender::notify_image(markdown_render *rdr, text_stream *URI) {
	VOID_METHOD_CALL(rdr, NOTIFY_IMAGE_MTID, URI);
}

@ Some renderers will need to know which images have been used, so this method
is called when that happens:

@e VETO_MATHEMATICS_MTID

=
INT_METHOD_TYPE(VETO_MATHEMATICS_MTID, markdown_render *rdr, int displayed)

int MDRender::veto_mathematics(markdown_render *rdr, int displayed) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, rdr, VETO_MATHEMATICS_MTID, displayed);
	return (rv)?TRUE:FALSE;
}

@ Relevant only when the `GADGETS_MARKDOWNFEATURE` extension is present.
See the //literate// module for more; this is quite an involved way to use
Markdown syntax to express carousels and other visual gadgets.

@e RENDER_GADGET_MTID

@e TEXT_AS_INWEBGADGET from 1
@e DOWNLOAD_INWEBGADGET
@e HTML_INWEBGADGET
@e VIDEO_INWEBGADGET
@e EMBED_INWEBGADGET
@e AUDIO_INWEBGADGET

=
INT_METHOD_TYPE(RENDER_GADGET_MTID, markdown_render *rdr, text_stream *OUT,
	int gadget, text_stream *text_operand, int w, int h, int mode, text_stream *path)

int MDRender::render_gadget(OUTPUT_STREAM, markdown_render *rdr, int mode,
	text_stream *desc, text_stream *path) {
	int gadget = -1, w = 0, h = 0;
	text_stream *text_operand = NULL;
	match_results mr = Regexp::create_mr();
	text_stream *as = NULL;
	if (Regexp::match(&mr, desc, U"text as (%c+)")) as = mr.exp[0];
	if (Str::eq(desc, I"text")) as = I"None";
	if (as) {
		text_operand = as;
		gadget = TEXT_AS_INWEBGADGET;
	} else if (Regexp::match(&mr, desc, U"download: (%c+)")) {
		gadget = DOWNLOAD_INWEBGADGET;
	} else if (Str::eq_insensitive(desc, I"HTML")) {
		gadget = HTML_INWEBGADGET;
	} else if (Str::eq(desc, I"video")) {
		gadget = VIDEO_INWEBGADGET;
	} else if (Regexp::match(&mr, desc, U"video at (%d+) by (%d+)")) {
		w = Str::atoi(mr.exp[0], 0); h = Str::atoi(mr.exp[1], 0);
		gadget = VIDEO_INWEBGADGET;
	} else if (Regexp::match(&mr, desc, U"video at width (%d+)")) {
		w = Str::atoi(mr.exp[0], 0);
		gadget = VIDEO_INWEBGADGET;
	} else if (Regexp::match(&mr, desc, U"video at height (%d+)")) {
		h = Str::atoi(mr.exp[0], 0);
		gadget = VIDEO_INWEBGADGET;
	} else if ((Regexp::match(&mr, desc, U"embedded (%c+) audio")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video"))) {
		text_operand = mr.exp[0];
		gadget = EMBED_INWEBGADGET;
	} else if ((Regexp::match(&mr, desc, U"embedded (%c+) audio at (%d+) by (%d+)")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video at (%d+) by (%d+)"))) {
		text_operand = mr.exp[0];
		w = Str::atoi(mr.exp[1], 0); h = Str::atoi(mr.exp[2], 0);
		gadget = EMBED_INWEBGADGET;
	} else if ((Regexp::match(&mr, desc, U"embedded (%c+) audio at height (%d+)")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video at height (%d+)"))) {
		text_operand = mr.exp[0];
		h = Str::atoi(mr.exp[1], 0);
		gadget = EMBED_INWEBGADGET;
	} else if ((Regexp::match(&mr, desc, U"embedded (%c+) audio at width (%d+)")) ||
		(Regexp::match(&mr, desc, U"embedded (%c+) video at width (%d+)"))) {
		text_operand = mr.exp[0];
		w = Str::atoi(mr.exp[1], 0);
		gadget = EMBED_INWEBGADGET;
	} else if (Str::eq(desc, I"audio")) {
		gadget = AUDIO_INWEBGADGET;
	}
	int rv = FALSE;
	if (gadget != -1)
		INT_METHOD_CALL(rv, rdr, RENDER_GADGET_MTID, OUT, gadget, text_operand, w, h, mode, path);
	Regexp::dispose_of(&mr);
	return (rv)?TRUE:FALSE;
}

@ And, similarly, and also gated by `GADGETS_MARKDOWNFEATURE`, we have:

@e RENDER_UL_AS_CAROUSEL_MTID

=
INT_METHOD_TYPE(RENDER_UL_AS_CAROUSEL_MTID, markdown_render *rdr, text_stream *OUT,
	int mode, markdown_item *md)

int MDRender::render_ul_as_carousel(OUTPUT_STREAM, int mode,
	markdown_render *rdr, markdown_item *md) {
	match_results mr = Regexp::create_mr();
	for (markdown_item *item = md->down; item; item = item->next)
		if (MDRender::caption(&mr, item, NULL) == FALSE) { 
			Regexp::dispose_of(&mr);
			return FALSE;
		}
	Regexp::dispose_of(&mr);

	int rv = FALSE;
	INT_METHOD_CALL(rv, rdr, RENDER_UL_AS_CAROUSEL_MTID, OUT, mode, md);
	return (rv)?TRUE:FALSE;
}

@ Thus, the actual method is called only if every item in the list matches this:

=
int MDRender::caption(match_results *mr, markdown_item *item, int *pos) {
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel%)"))) {
		if (pos) *pos = 0;
		return TRUE;
	}
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel \"(%c+)\"%)"))) {
		if (pos) *pos = 0;
		return TRUE;
	}
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel \"(%c+)\" captioned below%)"))) {
		if (pos) *pos = -1;
		return TRUE;
	}
	if ((item->type == UNORDERED_LIST_ITEM_MIT) &&
		(item->down) &&
		(item->down->type == PARAGRAPH_MIT) &&
		(Regexp::match(mr, item->down->stashed, U"%(carousel \"(%c+)\" captioned above%)"))) {
		if (pos) *pos = 1;
		return TRUE;
	}
	return FALSE;
}

@h Modes.
The essential algorithm for rendering a Markdown tree involves recursing downwards
through it, and as we do that, we carry with us an integer called the `mode`. This
is a bitmap composed of the following:

@d ALT_TEXT_MDRMODE        0x0001  /* This is an image description, or "alt-text" */
@d ESCAPES_MDRMODE         0x0002  /* Treat backslash followed by ASCII punctuation as an escape? */
@d URI_MDRMODE             0x0004  /* Encode characters as they need to appear in a URI */
@d RAW_MDRMODE             0x0008  /* Treat all characters literally */
@d LOOSE_MDRMODE           0x0010  /* Wrap list items in paragraph tags */
@d ENTITIES_MDRMODE        0x0020  /* Convert `&entity;` to whatever it ought to represent */
@d FILTERED_MDRMODE        0x0040  /* Make first `<` character safe as `&lt;` */
@d TOLOWER_MDRMODE         0x0080  /* Force letters to lower case */
@d EXAMPLE_BODIES_MDRMODE  0x0100  /* Render interiors of examples */
@d EXISTING_PAR_MDRMODE    0x0200  /* Render onto an existing paragraph */
@d INLINECODE_MDRMODE      0x0400  /* Render backticked code inline */
@d DECATCODE_MDRMODE       0x0800  /* Render backticked code inline using TeX escapes */
@d SMARTEN_MDRMODE         0x1000  /* Substitute smart left and right single and double quotes */

@ The "entry mode" is the initial state when we begin rendering at the root of
the tree:

=
int MDRender::entry_mode(markdown_render *rdr) {
	int entry_mode = ESCAPES_MDRMODE | (rdr->extra_modes);
	if (MarkdownVariations::supports(rdr->variation, ENTITIES_MARKDOWNFEATURE))
		entry_mode = entry_mode | ENTITIES_MDRMODE;
	return entry_mode;
}

@ And from here we hand over into specific renderers:

=
void MDRender::render_in_mode(OUTPUT_STREAM, markdown_render *rdr, markdown_item *md,
	int entry_mode) {
	if (rdr == NULL) internal_error("no render details");
	rdr->recurse(OUT, rdr, md, entry_mode);
}

@h Seeking footnotes.
The remainder of this section contains general rendering utility functions which
are format-agnostic.

We begin with a way to find the body of a footnote. If we are rendering the cue
of a footnote, we may (depending on format) need access to its body as well. But
this may be a long way away in the Markdown tree, and not a child (directly or
indirectly) of the cue node. This is why the `markdown_render` structure had a
`home` field, recording the root of the tree being rendered, because the
footnote body certainly will be somewhere underneath that.

In typical use cases, the tree will not be enormous; when Inweb is weaving, for
example, it will just be the commentary for a single paragraph.

=
markdown_item *MDRender::seek_footnote_body(markdown_render *rdr, int sought) {
	return MDRender::seek_footnote_body_r(rdr->home, sought);
}

markdown_item *MDRender::seek_footnote_body_r(markdown_item *md, int sought) {
	if (md) {
		if ((md->type == FOOTNOTE_BODY_MIT) && (md->details == sought)) return md;
		for (markdown_item *c = md->down; c; c = c->next) {
			markdown_item *x = MDRender::seek_footnote_body_r(c, sought);
			if (x) return x;
		}
	}
	return NULL;	
}

@h Streams and slices.
The following renders a text in the obvious way by passing it character by
character to the renderer's `char_out` function:

=
void MDRender::stream(OUTPUT_STREAM, markdown_render *rdr, text_stream *stream, int mode) {
	inchar32_t prev_c = 0;
	for (int i=0; i<Str::len(stream); i++) {
		inchar32_t c = Str::get_at(stream, i);
		MDRender::smarten(OUT, rdr, c, prev_c, mode);
		prev_c = 0;
	}
}

@ Recall that a "slice" of text is a run of contiguous characters from a `text_stream`.
In principle, we just send this each in turn to the character renderer. But:

- In `ESCAPES_MDRMODE`, backslash followed by ASCII (but not Unicode) punctuation
  produces a literal of that character.

- In `ENTITIES_MDRMODE`, we convert any valid entity ending in a semicolon to
  its Unicode code point(s). Note that CommonMark requires us not to respect
  HTML5 entities which do not end in a semicolon, such as `&copy` rather than `&copy;`.

- In `FILTERED_MDRMODE`, the _first_ `<` (only) must be made safe in HTML terms;
  so it is sent to `char_out` in mode 0, i.e., taking it out of `RAW_MDRMODE`.
  In HTML rendering, then, it becomes `&lt;`, not `<`.

=
void MDRender::slice(OUTPUT_STREAM, markdown_render *rdr, markdown_item *md, int mode) {
	if (md) {
		int angles = 0;
		inchar32_t prev_c = 0;
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
						rdr->char_out(OUT, A, mode);
						if (B) rdr->char_out(OUT, B, mode);
						i = at - 1;
						continue;
					}
				}
			}
			if ((c == '<') && (angles++ == 0) && (mode & FILTERED_MDRMODE))
				MDRender::smarten(OUT, rdr, c, prev_c, 0);
			else
				MDRender::smarten(OUT, rdr, c, prev_c, mode);
			prev_c = c;
		}
	}
}

void MDRender::smarten(OUTPUT_STREAM, markdown_render *rdr, inchar32_t c, inchar32_t prev_c, int mode) {
	if ((mode & SMARTEN_MDRMODE) && ((mode & RAW_MDRMODE) == 0)) {
		switch (c) {
			case '"':
				if ((prev_c == 0) || (Characters::is_whitespace(prev_c))) {
					rdr->char_out(OUT, 0x201C, mode);
				} else {
					rdr->char_out(OUT, 0x201D, mode);
				}
				break;
			case '\'':
				if ((prev_c == 0) || (Characters::is_whitespace(prev_c))) {
					rdr->char_out(OUT, 0x2018, mode);
				} else {
					rdr->char_out(OUT, 0x2019, mode);
				}
				break;
			default:
				rdr->char_out(OUT, c, mode);
				break;
		}
	} else {
		rdr->char_out(OUT, c, mode);
	}
}

@ This is for use in URIs. CommonMark likes hexadecimal escapes in URIs to use
upper case A to F; I suspect Web browsers don't care, but it's nice to comply
exactly with the CommonMark test examples, so:

=
void MDRender::hex_digit(OUTPUT_STREAM, unsigned int x) {
	x = x%16;
	if (x<10) PUT('0'+x);
	else PUT('A'+(x-10));
}

@h Colouring.
This manages the little dance required with the methods above for colouring
code blocks one line at a time:

=
void MDRender::colour_code_block(markdown_render *rdr, text_stream *language_name,
	text_stream *code, text_stream *colouring, void **colours) {
	void *token = MDRender::begin_colouring(rdr, language_name, colours);

	TEMPORARY_TEXT(line)
	TEMPORARY_TEXT(cols)
	int i = 0;
	while (i < Str::len(code)) {
		inchar32_t c = Str::get_at(code, i);
		if ((c == '\n') || (i+1 == Str::len(code))) {
			if (c != '\n') PUT_TO(line, c);
			MDRender::colour_line(rdr, token, line, cols);
			Str::clear(line);
			WRITE_TO(colouring, "%S%c", cols, PLAIN_COLOUR);
			Str::clear(cols);
		} else {
			PUT_TO(line, c);
		}
		i++;
	}
	DISCARD_TEXT(line)
	DISCARD_TEXT(cols)
}

@ And this produces the resulting output, though it needs to be told how to
change the colour, which of course depends on the output format:

=
void MDRender::render_code_block(OUTPUT_STREAM, markdown_render *rdr, text_stream *code,
	text_stream *colouring, void *colours, text_stream *lb,
	void (changer)(text_stream *, markdown_render *, int, void *)) {
	int current_colour = -1, pos = 0;
	for (int i=0; i < Str::len(code); i++) {
		int colour_wanted = (int) Str::get_at(colouring, i);
		if (colour_wanted != current_colour) {
			changer(OUT, rdr, colour_wanted, colours);
			current_colour = colour_wanted;
		}
		if (Str::get_at(code, i) == '\t') {
			WRITE(" "); pos++;
			while ((pos % 4) != 0) { WRITE(" "); pos++; }
		} else if (Str::get_at(code, i) == '\n') { WRITE("%S", lb); pos = 0; }
		else { rdr->char_out(OUT, Str::get_at(code, i), INLINECODE_MDRMODE); pos++; }
	}
	if (current_colour >= 0) changer(OUT, rdr, -1, colours);
}

@h Removing math mode.
"Math mode", in TeX jargon, is what happens when a mathematical formula is
written inside dollar signs: in `Answer is $x+y^2$`, the math mode content is
`x+y^2`. Using modern Javascript libraries such as MathJax, this can be rendered
straightforwardly by using what amounts to an embedded copy of TeX. But as a
fallback, we provide a dreary function able to convert simple gobbets of TeX
syntax to some sort of plain text alternative.

Here, `math_mode` should be true if the text supplied is in math mode already
(for example, `x+y^2`) and false if not (as in `This is $theta+1$.`).

At one time this produced errors of a sort: it now doesn't, because arbitrary
Markdown gibberish might flow through here. In any case, we have no aspiration
to do the job perfectly.

=
#define TEX_PARAPHRASE_NOTE(args...) ;

void MDRender::remove_math_mode(OUTPUT_STREAM, text_stream *text, int math_mode) {
	TEMPORARY_TEXT(math_matter)
	MDRender::remove_math_mode_range(math_matter, text, 0, Str::len(text)-1, math_mode);
	WRITE("%S", math_matter);
	DISCARD_TEXT(math_matter)
}

void MDRender::remove_math_mode_range(OUTPUT_STREAM, text_stream *text, int from, int to, int math_mode) {
	for (int i=from; i <= to; i++) {
		@<Remove the over construction@>;
	}
	for (int i=from; i <= to; i++) {
		@<Remove the rm and it constructions@>;
		@<Remove the sqrt constructions@>;
	}
	for (int i=from; i <= to; i++) {
		switch (Str::get_at(text, i)) {
			case '$':
				if (Str::get_at(text, i+1) == '$') i++;
				math_mode = (math_mode)?FALSE:TRUE; break;
			case '~': if (math_mode) WRITE(" "); else WRITE("~"); break;
			case '\\': @<Do something to strip out a TeX macro@>; break;
			default: PUT(Str::get_at(text, i)); break;
		}
	}
}

@ Here we remove `{{top}\over{bottom}}`, converting it to `((top) / (bottom))`.

@<Remove the over construction@> =
	if ((Str::get_at(text, i) == '\\') &&
		(Str::get_at(text, i+1) == 'o') && (Str::get_at(text, i+2) == 'v') &&
		(Str::get_at(text, i+3) == 'e') && (Str::get_at(text, i+4) == 'r') &&
		(Str::get_at(text, i+5) == '{')) {
		int bl = 1;
		int j = i-1;
		for (; j >= from; j--) {
			inchar32_t c = Str::get_at(text, j);
			if (c == '{') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '}') bl++;
		}
		MDRender::remove_math_mode_range(OUT, text, from, j-1, math_mode);
		WRITE("((");
		MDRender::remove_math_mode_range(OUT, text, j+2, i-2, math_mode);
		WRITE(") / (");
		j=i+6; bl = 1;
		for (; j <= to; j++) {
			inchar32_t c = Str::get_at(text, j);
			if (c == '}') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '{') bl++;
		}
		MDRender::remove_math_mode_range(OUT, text, i+6, j-1, math_mode);
		WRITE("))");
		MDRender::remove_math_mode_range(OUT, text, j+2, to, math_mode);
		return;
	}

@ Here we remove `{\rm text}`, converting it to `text`, and similarly `\it`.

@<Remove the rm and it constructions@> =
	if ((Str::get_at(text, i) == '{') && (Str::get_at(text, i+1) == '\\') &&
		(((Str::get_at(text, i+2) == 'r') && (Str::get_at(text, i+3) == 'm')) ||
			((Str::get_at(text, i+2) == 'i') && (Str::get_at(text, i+3) == 't'))) &&
		(Str::get_at(text, i+4) == ' ')) {
		MDRender::remove_math_mode_range(OUT, text, from, i-1, math_mode);
		int j=i+5;
		for (; j <= to; j++)
			if (Str::get_at(text, j) == '}')
				break;
		MDRender::remove_math_mode_range(OUT, text, i+5, j-1, FALSE);
		MDRender::remove_math_mode_range(OUT, text, j+1, to, math_mode);
		return;
	}

@ Here we remove `\sqrt{N}`, converting it to `sqrt(N)`. As a special treat,
we also look out for `{}^3\sqrt{N}` for cube root.

@<Remove the sqrt constructions@> =
	if ((Str::get_at(text, i) == '\\') &&
		(Str::get_at(text, i+1) == 's') && (Str::get_at(text, i+2) == 'q') &&
		(Str::get_at(text, i+3) == 'r') && (Str::get_at(text, i+4) == 't') &&
		(Str::get_at(text, i+5) == '{')) {
		if ((Str::get_at(text, i-4) == '{') &&
			(Str::get_at(text, i-3) == '}') &&
			(Str::get_at(text, i-2) == '^') &&
			(Str::get_at(text, i-1) == '3')) {
			MDRender::remove_math_mode_range(OUT, text, from, i-5, math_mode);
			WRITE(" curt(");				
		} else {
			MDRender::remove_math_mode_range(OUT, text, from, i-1, math_mode);
			WRITE(" sqrt(");
		}
		int j=i+6, bl = 1;
		for (; j <= to; j++) {
			inchar32_t c = Str::get_at(text, j);
			if (c == '}') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '{') bl++;
		}
		MDRender::remove_math_mode_range(OUT, text, i+6, j-1, math_mode);
		WRITE(")");
		MDRender::remove_math_mode_range(OUT, text, j+1, to, math_mode);
		return;
	}

@<Do something to strip out a TeX macro@> =
	TEMPORARY_TEXT(macro)
	i++;
	while ((i < Str::len(text)) && (Characters::isalpha(Str::get_at(text, i))))
		PUT_TO(macro, Str::get_at(text, i++));
	if (Str::eq(macro, I"not")) @<Remove the not prefix@>
	else @<Remove a general macro@>;
	DISCARD_TEXT(macro)
	i--;

@<Remove a general macro@> =
	if (Str::eq(macro, I"leq")) WRITE("<=");
	else if (Str::eq(macro, I"geq")) WRITE(">=");
	else if (Str::eq(macro, I"sim")) WRITE("~");
	else if (Str::eq(macro, I"hbox")) WRITE("");
	else if (Str::eq(macro, I"left")) WRITE("");
	else if (Str::eq(macro, I"right")) WRITE("");
	else if (Str::eq(macro, I"Rightarrow")) WRITE("=>");
	else if (Str::eq(macro, I"Leftrightarrow")) WRITE("<=>");
	else if (Str::eq(macro, I"to")) WRITE("-->");
	else if (Str::eq(macro, I"rightarrow")) WRITE("-->");
	else if (Str::eq(macro, I"longrightarrow")) WRITE("-->");
	else if (Str::eq(macro, I"leftarrow")) WRITE("<--");
	else if (Str::eq(macro, I"longleftarrow")) WRITE("<--");
	else if (Str::eq(macro, I"lbrace")) WRITE("{");
	else if (Str::eq(macro, I"mid")) WRITE("|");
	else if (Str::eq(macro, I"rbrace")) WRITE("}");
	else if (Str::eq(macro, I"cdot")) WRITE(".");
	else if (Str::eq(macro, I"cdots")) WRITE("...");
	else if (Str::eq(macro, I"dots")) WRITE("...");
	else if (Str::eq(macro, I"times")) WRITE("*");
	else if (Str::eq(macro, I"quad")) WRITE("  ");
	else if (Str::eq(macro, I"qquad")) WRITE("    ");
	else if (Str::eq(macro, I"TeX")) WRITE("TeX");
	else if (Str::eq(macro, I"neq")) WRITE("!=");
	else if (Str::eq(macro, I"noteq")) WRITE("!=");
	else if (Str::eq(macro, I"ell")) WRITE("l");
	else if (Str::eq(macro, I"log")) WRITE("log");
	else if (Str::eq(macro, I"exp")) WRITE("exp");
	else if (Str::eq(macro, I"sin")) WRITE("sin");
	else if (Str::eq(macro, I"cos")) WRITE("cos");
	else if (Str::eq(macro, I"tan")) WRITE("tan");
	else if (Str::eq(macro, I"top")) WRITE("T");
	else if (Str::eq(macro, I"Alpha")) PUT((inchar32_t) 0x0391);
	else if (Str::eq(macro, I"Beta")) PUT((inchar32_t) 0x0392);
	else if (Str::eq(macro, I"Gamma")) PUT((inchar32_t) 0x0393);
	else if (Str::eq(macro, I"Delta")) PUT((inchar32_t) 0x0394);
	else if (Str::eq(macro, I"Epsilon")) PUT((inchar32_t) 0x0395);
	else if (Str::eq(macro, I"Zeta")) PUT((inchar32_t) 0x0396);
	else if (Str::eq(macro, I"Eta")) PUT((inchar32_t) 0x0397);
	else if (Str::eq(macro, I"Theta")) PUT((inchar32_t) 0x0398);
	else if (Str::eq(macro, I"Iota")) PUT((inchar32_t) 0x0399);
	else if (Str::eq(macro, I"Kappa")) PUT((inchar32_t) 0x039A);
	else if (Str::eq(macro, I"Lambda")) PUT((inchar32_t) 0x039B);
	else if (Str::eq(macro, I"Mu")) PUT((inchar32_t) 0x039C);
	else if (Str::eq(macro, I"Nu")) PUT((inchar32_t) 0x039D);
	else if (Str::eq(macro, I"Xi")) PUT((inchar32_t) 0x039E);
	else if (Str::eq(macro, I"Omicron")) PUT((inchar32_t) 0x039F);
	else if (Str::eq(macro, I"Pi")) PUT((inchar32_t) 0x03A0);
	else if (Str::eq(macro, I"Rho")) PUT((inchar32_t) 0x03A1);
	else if (Str::eq(macro, I"Varsigma")) PUT((inchar32_t) 0x03A2);
	else if (Str::eq(macro, I"Sigma")) PUT((inchar32_t) 0x03A3);
	else if (Str::eq(macro, I"Tau")) PUT((inchar32_t) 0x03A4);
	else if (Str::eq(macro, I"Upsilon")) PUT((inchar32_t) 0x03A5);
	else if (Str::eq(macro, I"Phi")) PUT((inchar32_t) 0x03A6);
	else if (Str::eq(macro, I"Chi")) PUT((inchar32_t) 0x03A7);
	else if (Str::eq(macro, I"Psi")) PUT((inchar32_t) 0x03A8);
	else if (Str::eq(macro, I"Omega")) PUT((inchar32_t) 0x03A9);
	else if (Str::eq(macro, I"alpha")) PUT((inchar32_t) 0x03B1);
	else if (Str::eq(macro, I"beta")) PUT((inchar32_t) 0x03B2);
	else if (Str::eq(macro, I"gamma")) PUT((inchar32_t) 0x03B3);
	else if (Str::eq(macro, I"delta")) PUT((inchar32_t) 0x03B4);
	else if (Str::eq(macro, I"epsilon")) PUT((inchar32_t) 0x03B5);
	else if (Str::eq(macro, I"zeta")) PUT((inchar32_t) 0x03B6);
	else if (Str::eq(macro, I"eta")) PUT((inchar32_t) 0x03B7);
	else if (Str::eq(macro, I"theta")) PUT((inchar32_t) 0x03B8);
	else if (Str::eq(macro, I"iota")) PUT((inchar32_t) 0x03B9);
	else if (Str::eq(macro, I"kappa")) PUT((inchar32_t) 0x03BA);
	else if (Str::eq(macro, I"lambda")) PUT((inchar32_t) 0x03BB);
	else if (Str::eq(macro, I"mu")) PUT((inchar32_t) 0x03BC);
	else if (Str::eq(macro, I"nu")) PUT((inchar32_t) 0x03BD);
	else if (Str::eq(macro, I"xi")) PUT((inchar32_t) 0x03BE);
	else if (Str::eq(macro, I"omicron")) PUT((inchar32_t) 0x03BF);
	else if (Str::eq(macro, I"pi")) PUT((inchar32_t) 0x03C0);
	else if (Str::eq(macro, I"rho")) PUT((inchar32_t) 0x03C1);
	else if (Str::eq(macro, I"varsigma")) PUT((inchar32_t) 0x03C2);
	else if (Str::eq(macro, I"sigma")) PUT((inchar32_t) 0x03C3);
	else if (Str::eq(macro, I"tau")) PUT((inchar32_t) 0x03C4);
	else if (Str::eq(macro, I"upsilon")) PUT((inchar32_t) 0x03C5);
	else if (Str::eq(macro, I"phi")) PUT((inchar32_t) 0x03C6);
	else if (Str::eq(macro, I"chi")) PUT((inchar32_t) 0x03C7);
	else if (Str::eq(macro, I"psi")) PUT((inchar32_t) 0x03C8);
	else if (Str::eq(macro, I"omega")) PUT((inchar32_t) 0x03C9);
	else if (Str::eq(macro, I"exists")) PUT((inchar32_t) 0x2203);
	else if (Str::eq(macro, I"in")) PUT((inchar32_t) 0x2208);
	else if (Str::eq(macro, I"forall")) PUT((inchar32_t) 0x2200);
	else if (Str::eq(macro, I"cap")) PUT((inchar32_t) 0x2229);
	else if (Str::eq(macro, I"emptyset")) PUT((inchar32_t) 0x2205);
	else if (Str::eq(macro, I"subseteq")) PUT((inchar32_t) 0x2286);
	else if (Str::eq(macro, I"land")) PUT((inchar32_t) 0x2227);
	else if (Str::eq(macro, I"lor")) PUT((inchar32_t) 0x2228);
	else if (Str::eq(macro, I"lnot")) PUT((inchar32_t) 0x00AC);
	else if (Str::eq(macro, I"sum")) PUT((inchar32_t) 0x03A3);
	else if (Str::eq(macro, I"prod")) PUT((inchar32_t) 0x03A0);
	else {
		if (Str::len(macro) > 0) {
			int suspect = TRUE;
			LOOP_THROUGH_TEXT(pos, macro) {
				inchar32_t c = Str::get(pos);
				if ((c >= 'A') && (c <= 'Z')) continue;
				if ((c >= 'a') && (c <= 'z')) continue;
				suspect = FALSE;
			}
			if (Str::eq(macro, I"n")) suspect = FALSE;
			if (Str::eq(macro, I"t")) suspect = FALSE;
			if (suspect)
				TEX_PARAPHRASE_NOTE("Passing through unknown TeX macro \\%S:\n  %S\n", macro, text);
		}
		WRITE("\\%S", macro);
	}

@ For Inform's purposes, we need to deal with just `\not\exists` and `\not\forall`.

@<Remove the not prefix@> =
	if (Str::get_at(text, i) == '\\') {
		Str::clear(macro);
		i++;
		while ((i < Str::len(text)) && (Characters::isalpha(Str::get_at(text, i))))
			PUT_TO(macro, Str::get_at(text, i++));
		if (Str::eq(macro, I"exists")) PUT((inchar32_t) 0x2204);
		else if (Str::eq(macro, I"forall")) { PUT((inchar32_t) 0x00AC); PUT((inchar32_t) 0x2200); }
		else {
			TEX_PARAPHRASE_NOTE("Don't know how to apply '\\not' to '\\%S'\n", macro);
		}
	} else {
		TEX_PARAPHRASE_NOTE("Don't know how to apply '\\not' here\n");
	}
