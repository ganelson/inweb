[InformFlavouredMarkdown::] Inform-Flavoured Markdown.

A form of Markdown adapted to the needs of the Inform tools.

@ The Inform tools use something close to, but not quite the same as,
GitHub-flavored Markdown (GFM). There are minor syntactic differences, but
the main addition is a custom renderer.

=
markdown_variation *Inform_flavoured_Markdown = NULL;

markdown_variation *InformFlavouredMarkdown::variation(void) {
	if (Inform_flavoured_Markdown) return Inform_flavoured_Markdown;
	Inform_flavoured_Markdown = MarkdownVariations::new(I"Inform-flavoured Markdown");
	
	MarkdownVariations::copy_features_of(Inform_flavoured_Markdown,
		MarkdownVariations::GitHub_flavored_Markdown());

	MarkdownVariations::remove_feature(Inform_flavoured_Markdown, HTML_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(Inform_flavoured_Markdown, INLINE_HTML_MARKDOWNFEATURE);

	@<Add the formatting errors feature@>;
	@<Add the old Indoc headings feature@>;
	@<Add the descriptive headings feature@>;
	@<Add the embedded examples feature@>;
	@<Add the paste icons feature@>;
	@<Add the phrase defn boxes feature@>;
	@<Add the indexing marks feature@>;
	@<Add the heading markers feature@>;
	@<Add the paragraph gating feature@>;
	@<Add the Inform syntax-colouring feature@>;

	return Inform_flavoured_Markdown;
}

@h Formatting errors.
Traditionally, there are no errors in Markdown, but we want to be able to display
cautionary boxes with error-like messages anyway.

@e FORMATTING_ERRORS_MARKDOWNFEATURE
@e INFORM_ERROR_MARKER_MIT

@<Add the formatting errors feature@> =
	markdown_feature *fe = MarkdownVariations::new_feature(I"formatting errors",
		FORMATTING_ERRORS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		FORMATTING_ERRORS_MARKDOWNFEATURE);
	METHOD_ADD(fe, RENDER_MARKDOWN_MTID, InformFlavouredMarkdown::render_errors);
	Markdown::new_leaf_block_type(INFORM_ERROR_MARKER_MIT, I"INFORM_ERROR_MARKER");

@ =
markdown_item *InformFlavouredMarkdown::error_item(text_stream *text) {
	markdown_item *E = Markdown::new_item(INFORM_ERROR_MARKER_MIT);
	E->stashed = Str::duplicate(text);
	return E;
}

int InformFlavouredMarkdown::render_errors(markdown_feature *feature, text_stream *OUT,
	markdown_item *md, int mode) {
	if (md->type == INFORM_ERROR_MARKER_MIT) {
		HTML_OPEN_WITH("p", "class=\"documentationerrorbox\"");
		HTML::begin_span(OUT, I"documentationerror");
		WRITE("Error: %S", md->stashed);
		HTML_CLOSE("span");
		HTML_CLOSE("p");
		return TRUE;
	}
	return FALSE;
}

@h Old-style Indoc headings.
Indoc used to use a truly odd style for headings:
= (text)
	[Chapter: Things] Descriptions

	[x] Rooms and the map
=
The second is a section heading, but the first is a sort of duplex containing
both a chapter heading and a section heading, and thus needs to be expanded
into two Markdown items, not one.

@e OLD_INDOC_HEADINGS_MARKDOWNFEATURE

@<Add the old Indoc headings feature@> =
	markdown_feature *he = MarkdownVariations::new_feature(I"old Indoc headings",
		OLD_INDOC_HEADINGS_MARKDOWNFEATURE);
	METHOD_ADD(he, POST_PHASE_I_MARKDOWN_MTID,
		InformFlavouredMarkdown::OIH_intervene_after_Phase_I);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		OLD_INDOC_HEADINGS_MARKDOWNFEATURE);

@ =
void InformFlavouredMarkdown::OIH_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *md, md_links_dictionary *link_references) {
	if (md->type == PARAGRAPH_MIT) {
		text_stream *line = md->stashed;
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, U"%[x%] *(%c+?)")) {
			MDBlockParser::change_type(NULL, md, HEADING_MIT);
			Markdown::set_heading_level(md, 2);
			Str::clear(line);
			WRITE_TO(line, "%S", mr.exp[0]);
		} else if (Regexp::match(&mr, line, U"%[Chapter: *(%c+)%] *(%c+?)")) {
			MDBlockParser::change_type(NULL, md, HEADING_MIT);
			Markdown::set_heading_level(md, 1);
			Str::clear(line);
			WRITE_TO(line, "%S", mr.exp[0]);
			markdown_item *sect = Markdown::new_item(HEADING_MIT);
			Markdown::set_heading_level(sect, 2);
			sect->stashed = Str::duplicate(mr.exp[1]);
			sect->next = md->next; md->next = sect;
		}
		Regexp::dispose_of(&mr);
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::OIH_intervene_after_Phase_I(feature, ch, link_references);
	}
}

@h Descriptive headings.
Markdown paragraphs which take the following shapes are to be headings:
= (text)
	Chapter: Survey and Prospecting
	Section: Black Gold
=
where in each case the colon can equally be a hyphen, and with optional
space either side. We treat the Chapter headings as level 1, and Sections
as level 2.

@e DESCRIPTIVE_INFORM_HEADINGS_MARKDOWNFEATURE

@<Add the descriptive headings feature@> =
	markdown_feature *he = MarkdownVariations::new_feature(I"descriptive headings",
		DESCRIPTIVE_INFORM_HEADINGS_MARKDOWNFEATURE);
	METHOD_ADD(he, POST_PHASE_I_MARKDOWN_MTID,
		InformFlavouredMarkdown::Inform_headings_intervene_after_Phase_I);
	METHOD_ADD(he, RENDER_MARKDOWN_MTID, InformFlavouredMarkdown::render_descriptive_headings);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		DESCRIPTIVE_INFORM_HEADINGS_MARKDOWNFEATURE);

@ =
void InformFlavouredMarkdown::Inform_headings_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *tree, md_links_dictionary *link_references) {
	InformFlavouredMarkdown::Inform_headings_r(tree);
}

void InformFlavouredMarkdown::Inform_headings_r(markdown_item *md) {
	if (md->type == PARAGRAPH_MIT) {
		text_stream *line = md->stashed;
		match_results mr = Regexp::create_mr();
		if ((Regexp::match(&mr, line, U"Section *: *(%c+?)")) ||
			(Regexp::match(&mr, line, U"Section *- *(%c+?)"))) {
			MDBlockParser::change_type(NULL, md, HEADING_MIT);
			Markdown::set_heading_level(md, 2);
			Str::clear(line);
			WRITE_TO(line, "%S", mr.exp[0]);
		} else if ((Regexp::match(&mr, line, U"Chapter *: *(%c+?)")) ||
			(Regexp::match(&mr, line, U"Chapter *- *(%c+?)"))) {
			MDBlockParser::change_type(NULL, md, HEADING_MIT);
			Markdown::set_heading_level(md, 1);
			Str::clear(line);
			WRITE_TO(line, "%S", mr.exp[0]);
		}
		Regexp::dispose_of(&mr);
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::Inform_headings_r(ch);
	}
}

@ This function is not called by default. It applies numbering to the level 1
and 2 headings: note that this applies to such headings whatever the notation
they were written with.

=
void InformFlavouredMarkdown::number_headings(markdown_item *tree) {
	int section_number = 0, chapter_number = 0;
	TEMPORARY_TEXT(latest)
	InformFlavouredMarkdown::number_headings_r(tree, &section_number, &chapter_number, latest, 0);
	DISCARD_TEXT(latest)
}

void InformFlavouredMarkdown::number_headings_r(markdown_item *md,
	int *section_number, int *chapter_number, text_stream *latest, int level) {
	if (md->type == VOLUME_MIT) {
		*section_number = 0;
		*chapter_number = 0;
	}
	if (md->type == HEADING_MIT) {
		switch (Markdown::get_heading_level(md)) {
			case 1: {
				if (level > 1) {
					MDBlockParser::change_type(NULL, md, PARAGRAPH_MIT);
				} else {
					md->user_state = STORE_POINTER_text_stream(md->stashed);
					(*chapter_number)++;
					(*section_number) = 0;
					Str::clear(latest);
					WRITE_TO(latest, "Chapter %d: %S", *chapter_number, md->stashed);
					md->stashed = Str::duplicate(latest);
				}
				break;
			}
			case 2: {
				if (level > 1) {
					MDBlockParser::change_type(NULL, md, PARAGRAPH_MIT);
				} else {
					md->user_state = STORE_POINTER_text_stream(md->stashed);
					(*section_number)++;
					Str::clear(latest);
					WRITE_TO(latest, "Section ");
					if (*chapter_number > 0) WRITE_TO(latest, "%d.", *chapter_number);
					WRITE_TO(latest, "%d: %S", *section_number, md->stashed);
					md->stashed = Str::duplicate(latest);
				}
				break;
			}
		}
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::number_headings_r(ch, section_number, chapter_number,
			latest, level + 1);
	}
}

@ =
markdown_item *InformFlavouredMarkdown::find_section(markdown_item *md, text_stream *name) {
	if (Str::len(name) == 0) return NULL;
	markdown_item *result = NULL;
	InformFlavouredMarkdown::find_s(md, name, &result);
	return result;
}

void InformFlavouredMarkdown::find_s(markdown_item *md, text_stream *name, markdown_item **result) {
	if (md->type == HEADING_MIT) {
		switch (Markdown::get_heading_level(md)) {
			case 1:
			case 2: {
				int i=0;
				for (; i<Str::len(md->stashed); i++)
					if (Str::get_at(md->stashed, i) == ':') { i+=2; break; }
				if (i + Str::len(name) == Str::len(md->stashed)) {
					int fail = FALSE;
					for (int j=0; j<Str::len(name); j++, i++)
						if (Str::get_at(name, j) != Str::get_at(md->stashed, i)) { fail = TRUE; break; }
					if ((fail == FALSE) && (*result == NULL)) *result = md;
				}
				break;
			}
		}
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::find_s(ch, name, result);
	}
}

@ =
int InformFlavouredMarkdown::render_descriptive_headings(markdown_feature *feature,
	text_stream *OUT, markdown_item *md, int mode) {
	if (md->type == HEADING_MIT) {
		int L = Markdown::get_heading_level(md);
		switch (L) {
			case 1: HTML_OPEN("h2"); break;
			case 2: HTML_OPEN("h3"); break;
			case 3: HTML_OPEN("h4"); break;
			case 4: HTML_OPEN("h5"); break;
			default: HTML_OPEN("h6"); break;
		}
		TEMPORARY_TEXT(anchor)
		text_stream *url = MarkdownVariations::URL_for_heading(md);
		for (int i=0; i<Str::len(url); i++)
			if (Str::get_at(url, i) == '#')
				for (i++; i<Str::len(url); i++)
					PUT_TO(anchor, Str::get_at(url, i));
		if (Str::len(anchor) > 0) {
			HTML_OPEN_WITH("span", "id=%S", anchor);
		} else {
			HTML_OPEN("span");
		}
		DISCARD_TEXT(anchor)
		for (markdown_item *ch = md->down; ch; ch = ch->next)
			Markdown::render_extended(OUT, ch, InformFlavouredMarkdown::variation());
		HTML_CLOSE("span");
		switch (L) {
			case 1: HTML_CLOSE("h2"); break;
			case 2: HTML_CLOSE("h3"); break;
			case 3: HTML_CLOSE("h4"); break;
			case 4: HTML_CLOSE("h5"); break;
			default: HTML_CLOSE("h6"); break;
		}
		WRITE("\n");
		return TRUE;
	}
	return FALSE;
}

@h Embedded examples.
These are used in old-style Inform extension documentation, which is given below
the cut-off line in a single-file extension. In that context, an example has to
be written out in full, and not left to a stand-alone file, as it is with
directory-format extension documentation or Indoc manuals.

@e EMBEDDED_EXAMPLES_MARKDOWNFEATURE
@e INFORM_EXAMPLE_HEADING_MIT

@<Add the embedded examples feature@> =
	markdown_feature *ee =
		MarkdownVariations::new_feature(I"embedded examples", EMBEDDED_EXAMPLES_MARKDOWNFEATURE);
	METHOD_ADD(ee, POST_PHASE_I_MARKDOWN_MTID, InformFlavouredMarkdown::EE_intervene_after_Phase_I);
	METHOD_ADD(ee, RENDER_MARKDOWN_MTID, InformFlavouredMarkdown::EE_render);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown, EMBEDDED_EXAMPLES_MARKDOWNFEATURE);
	Markdown::new_container_block_type(INFORM_EXAMPLE_HEADING_MIT, I"INFORM_EXAMPLE_HEADING");

@ The first thing we need to do is to spot the heading, which looks like this:
= (text)
	Example: *** Gelignite Anderson - A Tale of the Texas Oilmen
=
where the colon can equally be a hyphen, and with optional space either side.

=
void InformFlavouredMarkdown::EE_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *tree, md_links_dictionary *link_references) {
	int example_number = 0;
	InformFlavouredMarkdown::detect_embedded_examples_r(tree, &example_number);
	InformFlavouredMarkdown::regroup_examples_r(tree, &example_number);
}

void InformFlavouredMarkdown::detect_embedded_examples_r(markdown_item *md, int *example_number) {
	if (md->type == PARAGRAPH_MIT) {
		text_stream *line = md->stashed;
		match_results mr = Regexp::create_mr();
		if ((Regexp::match(&mr, line, U"Example *: *(%**) *(%c+?)")) ||
			(Regexp::match(&mr, line, U"Example *- *(%**) *(%c+?)"))) {
			MDBlockParser::change_type(NULL, md, INFORM_EXAMPLE_HEADING_MIT);
			int star_count = Str::len(mr.exp[0]);
			IFM_example *new_eg = InformFlavouredMarkdown::new_example(mr.exp[1], NULL,
				star_count, ++(*example_number));
			new_eg->cue = NULL;
			new_eg->secondary_cue = NULL;
			new_eg->header = md;
			if (star_count == 0) {
				markdown_item *E = InformFlavouredMarkdown::error_item(
					I"this example should be marked (before the title) '*', '**', '***' or '****' for difficulty");
				E->next = md->next; md->next = E;
			}
			if (star_count > 4) {
				markdown_item *E = InformFlavouredMarkdown::error_item(
					I"four stars '****' is the maximum difficulty rating allowed");
				E->next = md->next; md->next = E;
			}
			md->user_state = STORE_POINTER_IFM_example(new_eg);
		}
		Regexp::dispose_of(&mr);
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::detect_embedded_examples_r(ch, example_number);
	}
}

@ Content for an embedded example runs on after the heading and continues until
the next Chapter or Section heading, or until its container block ends. We move
that material down to become the child nodes of the |INFORM_EXAMPLE_HEADING_MIT|
item: in effect, it's a container.

=
void InformFlavouredMarkdown::regroup_examples_r(markdown_item *md, int *example_number) {
	if (md->type == INFORM_EXAMPLE_HEADING_MIT) {
		if (md->down == NULL) {
			markdown_item *run_from = md->next;
			if (run_from) {
				markdown_item *run_to = run_from, *prev = NULL;
				while (run_to) {
					if (run_to->type == INFORM_EXAMPLE_HEADING_MIT) break;
					if ((run_to->type == HEADING_MIT) &&
						(Markdown::get_heading_level(run_to) <= 2)) break;
					prev = run_to;
					run_to = run_to->next;
				}
				if (prev) {
					md->down = run_from; md->next = run_to; prev->next = NULL;
				}
			}
		}
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::regroup_examples_r(ch, example_number);
	}
}

@ The following looks through the tree for an example with a particular number.

=
markdown_item *InformFlavouredMarkdown::find_example(markdown_item *tree, int eg) {
	if (eg <= 0) return NULL;
	markdown_item *result = NULL;
	int counter = 0;
	InformFlavouredMarkdown::find_e(tree, eg, &result, &counter);
	return result;
}

void InformFlavouredMarkdown::find_e(markdown_item *md, int eg, markdown_item **result,
	int *counter) {
	if (md->type == INFORM_EXAMPLE_HEADING_MIT) {
		(*counter)++;
		if (*counter == eg) *result = md;
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::find_e(ch, eg, result, counter);
	}
}

@ Lettered examples have a "difficulty rating" in stars, 0 to 4. Numbers are unique
from 1, 2, ...; letters are unique from A, B, C, ...

=
typedef struct IFM_example {
	struct text_stream *name;
	struct text_stream *description;
	struct markdown_item *header;
	struct markdown_item *secondary_header;
	struct markdown_item *cue;
	struct markdown_item *secondary_cue;
	struct text_stream *primary_label;
	struct text_stream *secondary_label;
	int star_count;
	int number;
	struct text_stream *insignia;
	struct text_stream *URL;
	struct text_stream *ex_index;
	struct text_stream *ex_subtitle;
	CLASS_DEFINITION
} IFM_example;

IFM_example *InformFlavouredMarkdown::new_example(text_stream *title, text_stream *desc,
	int star_count, int ecount) {
	IFM_example *E = CREATE(IFM_example);
	E->name = Str::duplicate(title);
	E->description = Str::duplicate(desc);
	E->header = NULL;
	E->secondary_header = NULL;
	E->cue = NULL;
	E->secondary_cue = NULL;
	E->primary_label = NULL;
	E->secondary_label = NULL;
	E->star_count = star_count;
	E->number = ecount;
	E->insignia = Str::new();
	E->URL = Str::new(); WRITE_TO(E->URL, "eg_%d.html", ecount);
	E->ex_index = Str::new();
	E->ex_subtitle = Str::new();
	WRITE_TO(E->insignia, "e%d", ecount);
	return E;
}

@ And this is the standard way to display an example heading. In the bad old
days, this was all done with tables and used a transparent image, and so on.
CSS is now much more reliable.

=
int InformFlavouredMarkdown::EE_render(markdown_feature *feature,
	text_stream *OUT, markdown_item *md, int mode) {
	if (md->type == INFORM_EXAMPLE_HEADING_MIT) {
		IFM_example *E = RETRIEVE_POINTER_IFM_example(md->user_state);
		InformFlavouredMarkdown::render_example_heading(OUT, E, md);
		if (mode & EXAMPLE_BODIES_MDRMODE)
			for (markdown_item *ch=md->down; ch; ch = ch->next)
				MDRenderer::recurse(OUT, ch, mode, InformFlavouredMarkdown::variation());
		return TRUE;
	}
	return FALSE;
}

void InformFlavouredMarkdown::render_example_heading(OUTPUT_STREAM, IFM_example *E,
	markdown_item *md) {
	HTML_OPEN_WITH("div", "class=\"examplebox\"");

	TEMPORARY_TEXT(link)
	TEMPORARY_TEXT(linkl)
	TEMPORARY_TEXT(linkr)
	text_stream *label = E->secondary_label;
	if (md == NULL) {
		if (E->cue) {
			WRITE_TO(linkl, "style=\"text-decoration: none\" href=\"%S\"",
				MarkdownVariations::URL_for_heading(E->cue));
		}
		if (E->secondary_cue) {
			WRITE_TO(linkr, "style=\"text-decoration: none\" href=\"%S\"",
				MarkdownVariations::URL_for_heading(E->secondary_cue));
		}
	} else {
		WRITE_TO(link, "style=\"text-decoration: none\" href=\"%S\"",
			E->URL);
		if ((md == E->header) && (E->secondary_cue)) {
			WRITE_TO(linkl, "%S", link);
			WRITE_TO(linkr, "style=\"text-decoration: none\" href=\"%S\"",
				MarkdownVariations::URL_for_heading(E->secondary_cue));
			label = E->secondary_label;
		}
		if ((md == E->secondary_header) && (E->cue)) {
			WRITE_TO(linkl, "%S", link);
			WRITE_TO(linkr, "style=\"text-decoration: none\" href=\"%S\"",
				MarkdownVariations::URL_for_heading(E->cue));
			label = E->primary_label;
		}
	}

	/* Left hand cell: the oval icon */
	HTML_OPEN_WITH("div", "class=\"exampleleft\"");
	HTML_OPEN_WITH("span", "id=eg%S", E->insignia); /* provide the anchor point */
	if (Str::len(linkl) > 0) HTML_OPEN_WITH("a", "%S", linkl);
	HTML::begin_span(OUT, I"extensionexampleletter");
	WRITE("%S", E->insignia);
	HTML::end_span(OUT);
	if (Str::len(linkl) > 0) HTML_CLOSE("a");
	HTML_CLOSE("span"); /* end the textual link */
	HTML_CLOSE("div");

	/* Middle cell: the asterisks and title, with rubric underneath */
	HTML_OPEN_WITH("div", "class=\"examplemiddle\"");
	if (Str::len(link) > 0) HTML_OPEN_WITH("a", "%S", link);
	HTML::begin_span(OUT, I"examplestars");
	for (int asterisk = 0; asterisk < E->star_count; asterisk++)
		PUT(0x2605); /* the Unicode for "black star" emoji */
	/* or 0x2B50 is the Unicode for "star" emoji */
	/* or again, could use the asterisk.png image in the app */
	HTML::end_span(OUT);
	WRITE("&nbsp; ");
	HTML_OPEN("b");
	HTML::begin_span(OUT, I"exampleword");
	WRITE("&nbsp;Example&nbsp;");
	HTML::end_span(OUT);
	HTML::begin_span(OUT, I"examplename");
	InformFlavouredMarkdown::render_text(OUT, E->name);
	HTML::end_span(OUT);
	HTML_CLOSE("b");
	HTML_TAG("br");
	HTML::begin_span(OUT, I"exampledescription");
	InformFlavouredMarkdown::render_text(OUT, E->description);
	HTML::end_span(OUT);
	if (Str::len(link) > 0) HTML_CLOSE("a");
	HTML_CLOSE("div");

	if (Str::len(linkr) > 0) {
		/* Right hand cell: the cross-reference */
		HTML_OPEN_WITH("div", "class=\"exampleright\"");
		HTML_OPEN_WITH("span", "id=eg%S", E->insignia); /* provide the anchor point */
		HTML_OPEN_WITH("a", "%S", linkr);
		HTML::begin_span(OUT, I"extensionexampleseealso");
		WRITE("%S", label);
		HTML::end_span(OUT);
		if (Str::len(linkr) > 0) HTML_CLOSE("a");
		HTML_CLOSE("span"); /* end the textual link */
		HTML_CLOSE("div");
	}

	HTML_CLOSE("div");
	DISCARD_TEXT(link)
	DISCARD_TEXT(linkl)
	DISCARD_TEXT(linkr)
}

@h Paste buttons.
Note that this feature only works if Inform syntax-colouring is also active
(though not vice versa) and even then only when the tool using it contains
the Inform |html| module, so this isn't really of general application.

@e PASTE_BUTTONS_MARKDOWNFEATURE

@<Add the paste icons feature@> =
	markdown_feature *pi = MarkdownVariations::new_feature(I"paste buttons",
		PASTE_BUTTONS_MARKDOWNFEATURE);
	METHOD_ADD(pi, POST_PHASE_I_MARKDOWN_MTID,
		InformFlavouredMarkdown::paste_buttons_intervene_after_Phase_I);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown, PASTE_BUTTONS_MARKDOWNFEATURE);

@ =
void InformFlavouredMarkdown::paste_buttons_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *tree, md_links_dictionary *link_references) {
	InformFlavouredMarkdown::pbiapi_r(tree);
}

void InformFlavouredMarkdown::pbiapi_r(markdown_item *md) {
	markdown_item *current_sample = NULL;
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		if ((ch->type == CODE_BLOCK_MIT) && (Str::prefix_eq(ch->stashed, I"{*}", 3))) {
			ch->user_state = STORE_POINTER_markdown_item(ch);
			current_sample = ch;
			Str::delete_first_character(ch->stashed);
			Str::delete_first_character(ch->stashed);
			Str::delete_first_character(ch->stashed);
		} else if ((ch->type == CODE_BLOCK_MIT) &&
			(Str::prefix_eq(ch->stashed, I"{**}", 3)) && (current_sample)) {
			ch->user_state = STORE_POINTER_markdown_item(current_sample);
			Str::delete_first_character(ch->stashed);
			Str::delete_first_character(ch->stashed);
			Str::delete_first_character(ch->stashed);
			Str::delete_first_character(ch->stashed);
		}
		InformFlavouredMarkdown::pbiapi_r(ch);
		if (ch->type == CODE_BLOCK_MIT) {
			TEMPORARY_TEXT(detabbed)
			for (int i=0, margin=0; i<Str::len(ch->stashed); i++) {
				inchar32_t c = Str::get_at(ch->stashed, i);
				if (c == '\t') {
					PUT_TO(detabbed, ' '); margin++;
					while (margin % 4 != 0) { PUT_TO(detabbed, ' '); margin++; }
				} else if ((c == ' ') || (c == '\n')) {
					PUT_TO(detabbed, c); margin++;
					if (c == '\n') margin = 0;
				} else {
					PUT_TO(detabbed, c);
					for (i++; i<Str::len(ch->stashed); i++)
						PUT_TO(detabbed, Str::get_at(ch->stashed, i));
				}
			}
			Str::clear(ch->stashed);
			WRITE_TO(ch->stashed, "%S", detabbed);
			DISCARD_TEXT(detabbed);
		}
	}
}

@h Phrase definition boxes.

@e PHRASE_DEFN_BOXES_MARKDOWNFEATURE
@e PHRASE_HEADER_MIT

@<Add the phrase defn boxes feature@> =
	markdown_feature *pd = MarkdownVariations::new_feature(I"phrase defn boxes",
		PHRASE_DEFN_BOXES_MARKDOWNFEATURE);
	METHOD_ADD(pd, POST_PHASE_I_MARKDOWN_MTID,
		InformFlavouredMarkdown::PD_intervene_after_Phase_I);
	METHOD_ADD(pd, RENDER_MARKDOWN_MTID, InformFlavouredMarkdown::PD_render);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown, PHRASE_DEFN_BOXES_MARKDOWNFEATURE);
	Markdown::new_leaf_block_type(PHRASE_HEADER_MIT, I"PHRASE_HEADER");

@ =
void InformFlavouredMarkdown::PD_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *md, md_links_dictionary *link_references) {
	markdown_item *last_section = NULL;
	InformFlavouredMarkdown::PD_r(md, &last_section);
}

void InformFlavouredMarkdown::PD_r(markdown_item *md, markdown_item **last_section) {
	if ((md->type == HEADING_MIT) && (Markdown::get_heading_level(md) == 2))
		*last_section = md;
	if (md->type == BLOCK_QUOTE_MIT) {
		if ((md->down) && (md->down->type == PARAGRAPH_MIT)) {
			match_results mr = Regexp::create_mr();
			if ((Regexp::match(&mr, md->down->stashed, U"phrase: *%{(%c*?)%} *(%c+?)")) ||
				(Regexp::match(&mr, md->down->stashed, U"(phrase): *(%c+?)"))) {
				markdown_item *join_to = NULL;
				TEMPORARY_TEXT(phrase)
				for (int i=0; i<Str::len(mr.exp[1]); i++) {
					if (Str::get_at(mr.exp[1], i) == '&') {
						@<Insert a phrase header here@>;
						Str::clear(phrase);
					} else {
						PUT_TO(phrase, Str::get_at(mr.exp[1], i));
					}
				}
				@<Insert a phrase header here@>;
				DISCARD_TEXT(phrase)
				if ((Str::ne(mr.exp[0], I"phrase")) && (*last_section)) {
					markdown_item *hm_item = Markdown::new_item(HEADING_MARKER_MIT);
					hm_item->stashed = Str::duplicate(mr.exp[0]);
					Markdown::add_to(hm_item, *last_section);
				}
			}
		}
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::PD_r(ch, last_section);
	}
}

@<Insert a phrase header here@> =
	Str::trim_white_space(phrase);
	if (Str::len(phrase) > 0) {
		markdown_item *ph = Markdown::new_item(PHRASE_HEADER_MIT);
		ph->stashed = Str::duplicate(phrase);
		if (join_to == NULL) { ph->next = md->down->next; md->down = ph; }
		else { ph->next = join_to->next; join_to->next = ph; }
		join_to = ph; 

		markdown_item *im = Markdown::new_item(INDEX_MARKER_MIT);
		im->stashed = Str::new();
		text_stream *category = I"+to+";
		if (Str::begins_with(phrase, I"if ")) category = I"+toif+";
		if (Str::begins_with(phrase, I"say ")) category = I"+tosay+";
		WRITE_TO(im->stashed, "%S%S", category, phrase);
		if (Str::get_last_char(im->stashed) == ':')
			Str::delete_last_character(im->stashed);
		im->details = 1;
		im->next = join_to->next; join_to->next = im;
		join_to = im; 
	}

@

=
int InformFlavouredMarkdown::PD_render(markdown_feature *feature, text_stream *OUT,
	markdown_item *md, int mode) {
	if ((md->type == BLOCK_QUOTE_MIT) && (md->down) && (md->down->type == PHRASE_HEADER_MIT)) {
		HTML_OPEN_WITH("div", "class=\"definition\"");
		for (markdown_item *ch = md->down; ch; ch = ch->next)
			Markdown::render_extended(OUT, ch, InformFlavouredMarkdown::variation());
		HTML_CLOSE("div");
		return TRUE;
	}
	if (md->type == PHRASE_HEADER_MIT) {
		HTML_OPEN_WITH("p", "class=\"defnprototype\"");
		MDRenderer::stream(OUT, md->stashed, mode);
		HTML_CLOSE("p");
		return TRUE;
	}
	return FALSE;
}

@h Indexing marks for longer documentation.

@e INDEXING_MARKS_MARKDOWNFEATURE
@e INDEX_MARKER_MIT

@<Add the indexing marks feature@> =
	MarkdownVariations::new_feature(I"indexing marks", INDEXING_MARKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		INDEXING_MARKS_MARKDOWNFEATURE);
	Markdown::new_quasiplainish_inline_type(INDEX_MARKER_MIT, I"INDEX_MARKER");

@h Heading markers for longer documentation.
This is a notation from indoc. When a heading ends with a |{tag}| of
non-whitespace, non-brace characters in single braces, we extract that as
metadata not passing through into rendering.

@e HEADING_MARKERS_MARKDOWNFEATURE
@e HEADING_MARKER_MIT

@<Add the heading markers feature@> =
	markdown_feature *he = MarkdownVariations::new_feature(I"heading markers",
		HEADING_MARKERS_MARKDOWNFEATURE);
	METHOD_ADD(he, POST_PHASE_I_MARKDOWN_MTID,
		InformFlavouredMarkdown::HM_intervene_after_Phase_I);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		HEADING_MARKERS_MARKDOWNFEATURE);
	Markdown::new_leaf_block_type(HEADING_MARKER_MIT, I"HEADING_MARKER");

@ =
void InformFlavouredMarkdown::HM_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *md, md_links_dictionary *link_references) {
	if ((md->type == HEADING_MIT) && (Markdown::get_heading_level(md) <= 2)) {
		text_stream *line = md->stashed;
		match_results mr = Regexp::create_mr();
		while (Regexp::match(&mr, line, U"(%c*) %{(%C+)%} *")) {
			markdown_item *hm_item = Markdown::new_item(HEADING_MARKER_MIT);
			hm_item->stashed = Str::duplicate(mr.exp[1]);
			Str::clear(line); Str::copy(line, mr.exp[0]);
			Markdown::add_to(hm_item, md);
		}
		Regexp::dispose_of(&mr);
		Str::trim_white_space(line);
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::HM_intervene_after_Phase_I(feature, ch, link_references);
	}
}

@h Paragraph gating for multi-platform tweaks.
Essentially, this allows paragraphs in the documentation to be rendered
only on some platforms and not others: it's conditional compilation for text.

@e PARAGRAPH_GATING_MARKDOWNFEATURE
@e GATE_MIT

@<Add the paragraph gating feature@> =
	markdown_feature *pg = MarkdownVariations::new_feature(I"paragraph gating",
		PARAGRAPH_GATING_MARKDOWNFEATURE);
	METHOD_ADD(pg, POST_PHASE_I_MARKDOWN_MTID,
		InformFlavouredMarkdown::PG_intervene_after_Phase_I);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		PARAGRAPH_GATING_MARKDOWNFEATURE);
	METHOD_ADD(pg, RENDER_MARKDOWN_MTID, InformFlavouredMarkdown::PG_render);
	Markdown::new_container_block_type(GATE_MIT, I"GATE");

@ =
void InformFlavouredMarkdown::PG_intervene_after_Phase_I(markdown_feature *feature,
	markdown_item *md, md_links_dictionary *link_references) {
	if (md->type == PARAGRAPH_MIT) {
		text_stream *line = md->stashed;
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, line, U"%{(%C+?):%} *(%c*)")) {
			MDBlockParser::change_type(NULL, md, GATE_MIT);
			md->details = TRUE;
			Str::clear(line); Str::copy(line, mr.exp[0]);
			markdown_item *gated_item = Markdown::new_item(PARAGRAPH_MIT);
			gated_item->stashed = Str::duplicate(mr.exp[1]);
			gated_item->down = md->down;
			md->down = gated_item;
			InformFlavouredMarkdown::expand_gate(md);
		}
		Regexp::dispose_of(&mr);
	}
	for (markdown_item *ch = md->down; ch; ch=ch->next) {
		InformFlavouredMarkdown::PG_intervene_after_Phase_I(feature, ch, link_references);
	}
}

void InformFlavouredMarkdown::expand_gate(markdown_item *md) {
	if (Str::get_at(md->stashed, 0) == '^') {
		md->details = FALSE;
		Str::delete_first_character(md->stashed);
	}
	for (int i=0; i<Str::len(md->stashed); i++)
		if (Str::get_at(md->stashed, i) == ',') {
			markdown_item *subgate_item = Markdown::new_item(GATE_MIT);
			subgate_item->stashed = Str::new();
			for (int j=i+1; j<Str::len(md->stashed); j++)
				PUT_TO(subgate_item->stashed, Str::get_at(md->stashed, j));
			subgate_item->details = TRUE;
			Str::truncate(md->stashed, i);
			subgate_item->down = md->down; md->down = subgate_item;
			InformFlavouredMarkdown::expand_gate(subgate_item);
			break;
		}
}

int (*IFM_gatekeeper)(text_stream *) = NULL;

void InformFlavouredMarkdown::set_gatekeeper_function(int (gatekeeper)(text_stream *)) {
	IFM_gatekeeper = gatekeeper;
}

int InformFlavouredMarkdown::PG_render(markdown_feature *feature, text_stream *OUT,
	markdown_item *md, int mode) {
	if (md->type == GATE_MIT) {
		int decision = FALSE;
		if (IFM_gatekeeper) decision = IFM_gatekeeper(md->stashed);
		if (md->details == FALSE) decision = (decision)?FALSE:TRUE;
		if (decision)
			Markdown::render_extended(OUT, md->down, InformFlavouredMarkdown::variation());
		return TRUE;
	}
	return FALSE;
}

@h Syntax-colouring for the Inform family.

@e INFORM_SYNTAX_COLOURING_MARKDOWNFEATURE

@<Add the Inform syntax-colouring feature@> =
	markdown_feature *sc =
		MarkdownVariations::new_feature(I"Inform syntax-colouring",
			INFORM_SYNTAX_COLOURING_MARKDOWNFEATURE);
	METHOD_ADD(sc, RENDER_MARKDOWN_MTID, InformFlavouredMarkdown::SC_render);
	MarkdownVariations::add_feature(Inform_flavoured_Markdown,
		INFORM_SYNTAX_COLOURING_MARKDOWNFEATURE);

@ =
int InformFlavouredMarkdown::SC_render(markdown_feature *feature, text_stream *OUT,
	markdown_item *md, int mode) {
	switch (md->type) {
		case CODE_MIT:       @<Render a code snippet@>; return TRUE;
		case CODE_BLOCK_MIT: @<Render a code block@>;   return TRUE;
	}
	return FALSE;
}

@ We consider a snippet backticked once as being Inform source text, and
twice or more as being in some other more conventional programming language.
But this affects only the CSS class applied to it.

@<Render a code snippet@> =
	if (mode & TAGS_MDRMODE) {
		if (Markdown::get_backtick_count(md) == 1) {
			HTML_OPEN_WITH("code", "class=\"inlinesourcetext\"");
		} else if (Markdown::get_backtick_count(md) == 2) {
			int lc = FALSE;
			for (int i=md->from; i<=md->to; i++) {
				inchar32_t c = Markdown::get_at(md, i);
				if (Characters::islower(c)) lc = TRUE;
			}
			if (lc) {
				HTML_OPEN_WITH("code", "class=\"inlinetranscript\"");
			} else {
				HTML_OPEN_WITH("code", "class=\"inlinetranscriptcommand\"");
				mode = mode | TOLOWER_MDRMODE;
			}
		} else {
			HTML_OPEN_WITH("code", "class=\"inlinecode\"");
		}
	}
	mode = mode & (~ESCAPES_MDRMODE);
	mode = mode & (~ENTITIES_MDRMODE);
	MDRenderer::slice(OUT, md, mode);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("code");

@ As is customary in Markdown, the first word of the info string on a code
block (if there is one) names the language in use.

@<Render a code block@> =
	TEMPORARY_TEXT(language_text)
	TEMPORARY_TEXT(language)
	for (int i=0; i<Str::len(md->info_string); i++) {
		inchar32_t c = Str::get_at(md->info_string, i);
		if ((c == ' ') || (c == '\t')) break;
		PUT_TO(language_text, c);
	}
	if (Str::len(language_text) > 0) {
		md->sliced_from = language_text;
		md->from = 0; md->to = Str::len(language_text) - 1;
		MDRenderer::slice(language, md, mode | ENTITIES_MDRMODE);
	}
	@<Decide on a language if none was supplied@>;
	if ((Str::eq_insensitive(language, I"inform")) ||
		(Str::eq_insensitive(language, I"inform7"))) {
		@<Render as Inform 7 source text@>;
	} else if (Str::eq_insensitive(language, I"problems")) {
		@<Render as problem message@>;
	} else {
		@<Render as some other programming language content@>;
	}
	DISCARD_TEXT(language_text)
	DISCARD_TEXT(language)

@ Usually Inform, but if one line looks like a traditional IF prompt character,
use "transcript" instead.

@<Decide on a language if none was supplied@> =
	if (Str::len(language) == 0) {
		for (int i=0; i<Str::len(md->stashed); i++)
			if ((Str::get_at(md->stashed, i) == '>') &&
				((i==0) || (Str::get_at(md->stashed, i-1) == '\n'))) {
				Str::clear(language);
				WRITE_TO(language, "transcript");
			}
		if (Str::len(language) == 0) WRITE_TO(language, "inform");
	}

@<Render as Inform 7 source text@> =
	HTML_OPEN_WITH("blockquote", "class=\"extract-inform7\"");
	if (GENERAL_POINTER_IS_NULL(md->user_state) == FALSE) {
		markdown_item *first = RETRIEVE_POINTER_markdown_item(md->user_state);
		TEMPORARY_TEXT(accumulated)
		for (markdown_item *ch = md; ch; ch = ch->next) {
			if (ch->type == CODE_BLOCK_MIT) {
				if (GENERAL_POINTER_IS_NULL(ch->user_state) == FALSE) {
					markdown_item *latest = RETRIEVE_POINTER_markdown_item(ch->user_state);
					if (first == latest) WRITE_TO(accumulated, "%S", ch->stashed);
				}
			}
		}
		#ifdef HTML_MODULE
		PasteButtons::paste_text_new_style(OUT, accumulated);
		#endif
		DISCARD_TEXT(accumulated)
	}
	TEMPORARY_TEXT(colouring)
	programming_language *default_language = Languages::find_by_name(I"Inform", NULL, FALSE);

	programming_language *pl = default_language;
	if (pl) {
		Painter::reset_syntax_colouring(pl);
		Painter::syntax_colour(pl, NULL, md->stashed, colouring, FALSE);
		if (Str::eq(pl->language_name, I"Inform")) {
			int ts = FALSE;
			for (int i=0; i<Str::len(colouring); i++) {
				if (Str::get_at(colouring, i) == STRING_COLOUR) {
					inchar32_t c = Str::get_at(md->stashed, i);
					if (c == '[') ts = TRUE;
					if (ts) Str::put_at(colouring, i, EXTRACT_COLOUR);
					if (c == ']') ts = FALSE;
				} else ts = FALSE;
			}
		}
	}

	HTML::begin_span(OUT, I"indexdullblue");
	int tabulating = FALSE, tabular = FALSE, line_count = 0;
	TEMPORARY_TEXT(line)
	TEMPORARY_TEXT(line_colouring)
	for (int k=0; k<Str::len(md->stashed); k++) {
		if (Str::get_at(md->stashed, k) == '\n') {
			@<Render line@>;
			Str::clear(line);
			Str::clear(line_colouring);
		} else {
			PUT_TO(line, Str::get_at(md->stashed, k));
			PUT_TO(line_colouring, Str::get_at(colouring, k));
		}
		if ((k == Str::len(md->stashed) - 1) && (Str::len(line) > 0)) @<Render line@>;
	}
	if (tabulating) @<End I7 table in extension documentation@>;
	HTML_CLOSE("span");
	HTML_CLOSE("blockquote");
	DISCARD_TEXT(line)
	DISCARD_TEXT(line_colouring)

@<Render line@> =
	line_count++;
	if (Str::is_whitespace(line)) tabular = FALSE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"Table %c*")) tabular = TRUE;
	Regexp::dispose_of(&mr);
	if (tabular) {
		if (tabulating) {
			@<Begin new row of I7 table in extension documentation@>;
			int cell_from = 0, cell_to = 0, i = 0;
			@<Begin table cell for I7 table in extension documentation@>;
			for (; i<Str::len(line); i++) {
				if (Str::get_at(line, i) == '\t') {
					@<End table cell for I7 table in extension documentation@>;
					while (Str::get_at(line, i) == '\t') i++;
					@<Begin table cell for I7 table in extension documentation@>;
					i--;
				} else {
					cell_to++;
				}
			}
			@<End last table cell for I7 table in extension documentation@>;
		} else {
			@<Render line outside of a table@>;
			@<Begin I7 table in extension documentation@>;
			tabulating = TRUE;
		}
	} else {
		@<Render line outside of a table@>;
	}
	WRITE("\n");

@<Render line outside of a table@> =
	if (line_count > 1) HTML_TAG("br");
	if (tabulating) {
		@<End I7 table in extension documentation@>;
		tabulating = FALSE;
	}
	int indentation = 0;
	int z=0, spaces = 0;
	for (; z<Str::len(line); z++)
		if (Str::get_at(line, z) == ' ') { spaces++; if (spaces == 4) { indentation++; spaces = 0; } }
		else if (Str::get_at(line, z) == '\t') { indentation++; spaces = 0; }
		else break;
	for (int n=0; n<indentation; n++) WRITE("&nbsp;&nbsp;&nbsp;&nbsp;");
	InformFlavouredMarkdown::syntax_coloured_code(OUT, line, line_colouring,
		z, Str::len(line), mode);

@ Unsurprisingly, I7 tables are set (after their titling lines) as HTML tables,
and this is fiddly but elementary in the usual way of HTML tables:

@<Begin I7 table in extension documentation@> =
	HTML::end_span(OUT);
	HTML_TAG("br");
	HTML::begin_plain_html_table(OUT);

@<End table cell for I7 table in extension documentation@> =
	InformFlavouredMarkdown::syntax_coloured_code(OUT, line, line_colouring,
		cell_from, cell_to, mode);
	HTML::end_span(OUT);
	HTML::next_html_column(OUT, 0);

@<End last table cell for I7 table in extension documentation@> =
	InformFlavouredMarkdown::syntax_coloured_code(OUT, line, line_colouring,
		cell_from, cell_to, mode);
	HTML::end_span(OUT);
	HTML::end_html_row(OUT);

@<Begin table cell for I7 table in extension documentation@> =
	cell_from = i; cell_to = cell_from;
	HTML::begin_span(OUT, I"indexdullblue");

@<Begin new row of I7 table in extension documentation@> =
	HTML::first_html_column(OUT, 0);

@<End I7 table in extension documentation@> =
	HTML::end_html_table(OUT);
	HTML::begin_span(OUT, I"indexdullblue");

@<Render as problem message@> =
	if (mode & TAGS_MDRMODE)
		HTML_OPEN_WITH("div", "class=\"extract-problems\"");
	if (mode & TAGS_MDRMODE) HTML_OPEN("blockquote");
	for (int k=0; k<Str::len(md->stashed); k++)
		MDRenderer::char(OUT, Str::get_at(md->stashed, k), mode);
	if (mode & TAGS_MDRMODE) HTML_CLOSE("blockquote");
	if (mode & TAGS_MDRMODE) HTML_CLOSE("div");

@<Render as some other programming language content@> =
	programming_language *pl = NULL;
	if (Str::len(language) > 0) {
		if (mode & TAGS_MDRMODE)
			HTML_OPEN_WITH("div", "class=\"extract-%S\"", language);
	}
	if (mode & TAGS_MDRMODE) HTML_OPEN("pre");
	if (Str::len(language) > 0) {
		if (mode & TAGS_MDRMODE)
			HTML_OPEN_WITH("code", "class=\"language-%S\"", language);
		pl = Languages::find_by_name(language, NULL, FALSE);
		if (pl == NULL) LOG("Unable to find language <%S>\n", language);
	} else {
		if (mode & TAGS_MDRMODE) HTML_OPEN("code");
	}

	Painter::reset_syntax_colouring(pl);
	TEMPORARY_TEXT(line)
	TEMPORARY_TEXT(line_colouring)
	for (int k=0; k<Str::len(md->stashed); k++) {
		if (Str::get_at(md->stashed, k) == '\n') {
			@<Render line as code@>;
			Str::clear(line);
			Str::clear(line_colouring);
		} else {
			PUT_TO(line, Str::get_at(md->stashed, k));
		}
		if ((k == Str::len(md->stashed) - 1) && (Str::len(line) > 0))
			@<Render line as code@>;
	}
	DISCARD_TEXT(line)
	DISCARD_TEXT(line_colouring)
	if (mode & TAGS_MDRMODE) HTML_CLOSE("code");
	if (mode & TAGS_MDRMODE) HTML_CLOSE("pre");
	if (Str::len(language) > 0) {
		if (mode & TAGS_MDRMODE) HTML_CLOSE("div");
	}

@<Render line as code@> =
	if (pl) Painter::syntax_colour(pl, NULL, line, line_colouring, FALSE);
	InformFlavouredMarkdown::syntax_coloured_code(OUT, line, line_colouring,
		0, Str::len(line), mode);
	if (mode & TAGS_MDRMODE) WRITE("<br>"); else WRITE(" ");


@ =
void InformFlavouredMarkdown::syntax_coloured_code(OUTPUT_STREAM, text_stream *text,
	text_stream *colouring, int from, int to, int mode) {
	inchar32_t current_col = 0;
	for (int i=from; i<to; i++) {
		inchar32_t c = Str::get_at(text, i);
		inchar32_t col = Str::get_at(colouring, i);
		if (col != current_col) {
			if (current_col) HTML_CLOSE("span");
			text_stream *span_class = NULL;
			switch (col) {
				case DEFINITION_COLOUR: span_class = I"syntaxdefinition"; break;
				case FUNCTION_COLOUR:   span_class = I"syntaxfunction"; break;
				case RESERVED_COLOUR:   span_class = I"syntaxreserved"; break;
				case ELEMENT_COLOUR:    span_class = I"syntaxelement"; break;
				case IDENTIFIER_COLOUR: span_class = I"syntaxidentifier"; break;
				case CHARACTER_COLOUR:  span_class = I"syntaxcharacter"; break;
				case CONSTANT_COLOUR:   span_class = I"syntaxconstant"; break;
				case STRING_COLOUR:     span_class = I"syntaxstring"; break;
				case PLAIN_COLOUR:      span_class = I"syntaxplain"; break;
				case EXTRACT_COLOUR:    span_class = I"syntaxextract"; break;
				case COMMENT_COLOUR:    span_class = I"syntaxcomment"; break;
			}
			HTML_OPEN_WITH("span", "class=\"%S\"", span_class);
			current_col = col;
		}
		MDRenderer::char(OUT, c, mode);
	}
	if (current_col) HTML_CLOSE("span");
}

@h Small inline texts.
This utility function parses and renders short inline content only:

=
void InformFlavouredMarkdown::render_text(OUTPUT_STREAM, text_stream *text) {
	markdown_item *md = Markdown::parse_inline(text);
	HTML_OPEN_WITH("span", "class=\"markdowncontent\"");
	Markdown::render_extended(OUT, md, InformFlavouredMarkdown::variation());
	HTML_CLOSE("span");
}
