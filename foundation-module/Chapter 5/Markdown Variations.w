[MarkdownVariations::] Markdown Variations.

To specify modified versions of the Markdown markup syntax.

@ In practice, nobody quite uses pure Markdown, because there are always
minor additions or removals people want to make in particular use cases.
We'll call modified versions of the Markdown syntax "variations", but
will provide only one of these here: the baseline of CommonMark.

@d MAX_MARKDOWNFEATURES 256

=
markdown_feature *markdown_feature_registry[MAX_MARKDOWNFEATURES];

void MarkdownVariations::start(void) {
	Markdown::create_item_types();
	for (int i=0; i<MAX_MARKDOWNFEATURES; i++) markdown_feature_registry[i] = NULL;
	MarkdownVariations::define_CommonMark();
	MarkdownVariations::define_GFM();
	MarkdownVariations::define_IWFM();
}

markdown_variation *CommonMark_variation = NULL;
markdown_variation *GitHub_flavored_Markdown_variation = NULL;
markdown_variation *Inweb_flavoured_Markdown_variation = NULL;
markdown_variation *simplified_Inweb_flavoured_Markdown_variation = NULL;

markdown_variation *MarkdownVariations::CommonMark(void) {
	return CommonMark_variation;
}

markdown_variation *MarkdownVariations::GitHub_flavored_Markdown(void) {
	return GitHub_flavored_Markdown_variation;
}

markdown_variation *MarkdownVariations::Inweb_flavoured_Markdown(void) {
	return Inweb_flavoured_Markdown_variation;
}

markdown_variation *MarkdownVariations::simplified_Inweb_flavoured_Markdown(void) {
	return simplified_Inweb_flavoured_Markdown_variation;
}

@ A variation is essentially a named collection of features, which may affect
parsing, or rendering, or both.

All newly-created variations begin with the CommonMark baseline set of features
active, and no others. The caller should use |MarkdownVariations::add_feature| to
add a home-brew feature, or |MarkdownVariations::remove_feature| to take away
one of the CommonMark ones.

=
typedef struct markdown_variation {
	struct text_stream *name;
	int active_built_in_features[NO_DEFINED_MARKDOWNFEATURE_VALUES];
	struct method_set *methods;
	CLASS_DEFINITION
} markdown_variation;

markdown_variation *MarkdownVariations::new(text_stream *name) {
	markdown_variation *variation = CREATE(markdown_variation);
	variation->name = Str::duplicate(name);
	variation->methods = Methods::new_set();
	for (int i=0; i<NO_DEFINED_MARKDOWNFEATURE_VALUES; i++)
		variation->active_built_in_features[i] = FALSE;
	MarkdownVariations::make_baseline_features_active(variation);
	return variation;
}

void MarkdownVariations::add_feature(markdown_variation *variation, int feature_id) {
	variation->active_built_in_features[feature_id] = TRUE;
}

void MarkdownVariations::remove_feature(markdown_variation *variation, int feature_id) {
	variation->active_built_in_features[feature_id] = FALSE;
}

void MarkdownVariations::copy_features_of(markdown_variation *to, markdown_variation *from) {
	for (int i=0; i<NO_DEFINED_MARKDOWNFEATURE_VALUES; i++)
		to->active_built_in_features[i] = from->active_built_in_features[i];
}

@ A "feature" is an aspect of Markdown syntax or behaviour; any given variation
can either support it or not.

=
typedef struct markdown_feature {
	struct text_stream *name;
	int feature_ID;
	struct method_set *methods;
	CLASS_DEFINITION
} markdown_feature;


markdown_feature *MarkdownVariations::new_feature(text_stream *name, int id) {
	markdown_feature *feature = CREATE(markdown_feature);
	if (id >= MAX_MARKDOWNFEATURES) internal_error("too many Markdown features");
	feature->name = Str::duplicate(name);
	feature->feature_ID = id;
	feature->methods = Methods::new_set();
	if (markdown_feature_registry[id]) internal_error("Markdown feature ID clash");
	markdown_feature_registry[id] = feature;
	return feature;
}

@ The point of the cumbersome business of both defining an ID and creating
an object to represent the same feature was to make this function quick.

=
int MarkdownVariations::supports(markdown_variation *variation, int feature_id) {
	return variation->active_built_in_features[feature_id];
}

@h The CommonMark variation.
Vanilla ice cream is under-rated:

@e BLOCK_QUOTES_MARKDOWNFEATURE from 0
@e ORDERED_LISTS_MARKDOWNFEATURE
@e UNORDERED_LISTS_MARKDOWNFEATURE
@e INDENTED_CODE_BLOCKS_MARKDOWNFEATURE
@e FENCED_CODE_BLOCKS_MARKDOWNFEATURE
@e HTML_BLOCKS_MARKDOWNFEATURE
@e THEMATIC_MARKERS_MARKDOWNFEATURE
@e ATX_HEADINGS_MARKDOWNFEATURE
@e SETEXT_HEADINGS_MARKDOWNFEATURE

@e WEB_AUTOLINKS_MARKDOWNFEATURE
@e EMAIL_AUTOLINKS_MARKDOWNFEATURE
@e INLINE_HTML_MARKDOWNFEATURE
@e BACKTICKED_CODE_MARKDOWNFEATURE
@e LINKS_MARKDOWNFEATURE
@e IMAGES_MARKDOWNFEATURE
@e ASTERISK_EMPHASIS_MARKDOWNFEATURE
@e UNDERSCORE_EMPHASIS_MARKDOWNFEATURE

@e ENTITIES_MARKDOWNFEATURE

=
markdown_feature *block_quotes_Markdown_feature = NULL;
markdown_feature *ordered_lists_Markdown_feature = NULL;
markdown_feature *unordered_lists_Markdown_feature = NULL;
markdown_feature *indented_code_blocks_Markdown_feature = NULL;
markdown_feature *fenced_code_blocks_Markdown_feature = NULL;
markdown_feature *HTML_blocks_Markdown_feature = NULL;
markdown_feature *thematic_markers_Markdown_feature = NULL;
markdown_feature *ATX_headings_Markdown_feature = NULL;
markdown_feature *setext_headings_Markdown_feature = NULL;

markdown_feature *web_autolinks_Markdown_feature = NULL;
markdown_feature *email_autolinks_Markdown_feature = NULL;
markdown_feature *inline_HTML_Markdown_feature = NULL;
markdown_feature *backticked_code_Markdown_feature = NULL;
markdown_feature *links_Markdown_feature = NULL;
markdown_feature *images_Markdown_feature = NULL;
markdown_feature *asterisk_emphasis_Markdown_feature = NULL;
markdown_feature *underscore_emphasis_Markdown_feature = NULL;

markdown_feature *entities_Markdown_feature = NULL;

void MarkdownVariations::define_CommonMark(void) {
	block_quotes_Markdown_feature =         MarkdownVariations::new_feature(I"block quotes",         BLOCK_QUOTES_MARKDOWNFEATURE);
	ordered_lists_Markdown_feature =        MarkdownVariations::new_feature(I"ordered lists",        ORDERED_LISTS_MARKDOWNFEATURE);
	unordered_lists_Markdown_feature =      MarkdownVariations::new_feature(I"unordered lists",      UNORDERED_LISTS_MARKDOWNFEATURE);
	indented_code_blocks_Markdown_feature = MarkdownVariations::new_feature(I"indented code blocks", INDENTED_CODE_BLOCKS_MARKDOWNFEATURE);
	fenced_code_blocks_Markdown_feature =   MarkdownVariations::new_feature(I"fenced code blocks",   FENCED_CODE_BLOCKS_MARKDOWNFEATURE);
	HTML_blocks_Markdown_feature =          MarkdownVariations::new_feature(I"HTML blocks",          HTML_BLOCKS_MARKDOWNFEATURE);
	thematic_markers_Markdown_feature =     MarkdownVariations::new_feature(I"thematic markers",     THEMATIC_MARKERS_MARKDOWNFEATURE);
	ATX_headings_Markdown_feature =         MarkdownVariations::new_feature(I"ATX headings",         ATX_HEADINGS_MARKDOWNFEATURE);
	setext_headings_Markdown_feature =      MarkdownVariations::new_feature(I"setext headings",      SETEXT_HEADINGS_MARKDOWNFEATURE);

	web_autolinks_Markdown_feature =        MarkdownVariations::new_feature(I"web autolinks",        WEB_AUTOLINKS_MARKDOWNFEATURE);
	email_autolinks_Markdown_feature =      MarkdownVariations::new_feature(I"email autolinks",      EMAIL_AUTOLINKS_MARKDOWNFEATURE);
	inline_HTML_Markdown_feature =          MarkdownVariations::new_feature(I"inline HTML",          INLINE_HTML_MARKDOWNFEATURE);
	backticked_code_Markdown_feature =      MarkdownVariations::new_feature(I"backticked code",      BACKTICKED_CODE_MARKDOWNFEATURE);
	links_Markdown_feature =                MarkdownVariations::new_feature(I"links",                LINKS_MARKDOWNFEATURE);
	images_Markdown_feature =               MarkdownVariations::new_feature(I"images",               IMAGES_MARKDOWNFEATURE);
	asterisk_emphasis_Markdown_feature =    MarkdownVariations::new_feature(I"emphasis",             ASTERISK_EMPHASIS_MARKDOWNFEATURE);
	underscore_emphasis_Markdown_feature =  MarkdownVariations::new_feature(I"emphasis",             UNDERSCORE_EMPHASIS_MARKDOWNFEATURE);

	entities_Markdown_feature =             MarkdownVariations::new_feature(I"entities",             ENTITIES_MARKDOWNFEATURE);

	CommonMark_variation = MarkdownVariations::new(I"CommonMark 0.30");
}

void MarkdownVariations::make_baseline_features_active(markdown_variation *variation) {
	MarkdownVariations::add_feature(variation, BLOCK_QUOTES_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, ORDERED_LISTS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, UNORDERED_LISTS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, INDENTED_CODE_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, FENCED_CODE_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, HTML_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, THEMATIC_MARKERS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, ATX_HEADINGS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, SETEXT_HEADINGS_MARKDOWNFEATURE);

	MarkdownVariations::add_feature(variation, WEB_AUTOLINKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, EMAIL_AUTOLINKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, INLINE_HTML_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, BACKTICKED_CODE_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, LINKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, IMAGES_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, ASTERISK_EMPHASIS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, UNDERSCORE_EMPHASIS_MARKDOWNFEATURE);

	MarkdownVariations::add_feature(variation, ENTITIES_MARKDOWNFEATURE);
}

@h Github extensions to CommonMark.
See //GitHub's specification -> https://github.github.com/gfm//, which is based
on CommonMark, though its description of new features is a little more concise,
since these have been added with more prudent syntax.

@e STRIKETHROUGH_MARKDOWNFEATURE
@e TABLES_MARKDOWNFEATURE
@e TASK_LIST_ITEMS_MARKDOWNFEATURE
@e EXTENDED_AUTOLINKS_MARKDOWNFEATURE
@e DISALLOWED_RAW_HTML_MARKDOWNFEATURE

=
markdown_feature *strikethrough_Markdown_feature = NULL;
markdown_feature *tables_Markdown_feature = NULL;
markdown_feature *task_list_items_Markdown_feature = NULL;
markdown_feature *extended_autolinks_Markdown_feature = NULL;
markdown_feature *disallowed_raw_HTML_Markdown_feature = NULL;

void MarkdownVariations::define_GFM(void) {
	strikethrough_Markdown_feature =       MarkdownVariations::new_feature(I"strikethrough",       STRIKETHROUGH_MARKDOWNFEATURE);
	tables_Markdown_feature =              MarkdownVariations::new_feature(I"tables",              TABLES_MARKDOWNFEATURE);
	task_list_items_Markdown_feature =     MarkdownVariations::new_feature(I"task list items",     TASK_LIST_ITEMS_MARKDOWNFEATURE);
	extended_autolinks_Markdown_feature =  MarkdownVariations::new_feature(I"extended autolinks",  EXTENDED_AUTOLINKS_MARKDOWNFEATURE);
	disallowed_raw_HTML_Markdown_feature = MarkdownVariations::new_feature(I"disallowed raw HTML", DISALLOWED_RAW_HTML_MARKDOWNFEATURE);

	GitHub_flavored_Markdown_variation = MarkdownVariations::new(I"GitHub-flavored Markdown 0.29");
	MarkdownVariations::make_GitHub_features_active(GitHub_flavored_Markdown_variation);
}

void MarkdownVariations::make_GitHub_features_active(markdown_variation *variation) {
	MarkdownVariations::add_feature(variation, STRIKETHROUGH_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, TABLES_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, TASK_LIST_ITEMS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, EXTENDED_AUTOLINKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, DISALLOWED_RAW_HTML_MARKDOWNFEATURE);
}

@h Inweb extensions to GFM.
We provide just a few of these, and they are intended to be used on top of GFM:

@e TEX_MARKDOWNFEATURE
@e INWEB_LINKS_MARKDOWNFEATURE
@e FOOTNOTES_MARKDOWNFEATURE
@e STROKED_CODE_MARKDOWNFEATURE

=
markdown_feature *TeX_Markdown_feature = NULL;
markdown_feature *inweb_links_Markdown_feature = NULL;
markdown_feature *footnotes_Markdown_feature = NULL;
markdown_feature *stroked_code_Markdown_feature = NULL;

void MarkdownVariations::define_IWFM(void) {
	TeX_Markdown_feature =          MarkdownVariations::new_feature(I"TeX",             TEX_MARKDOWNFEATURE);
	inweb_links_Markdown_feature =  MarkdownVariations::new_feature(I"inweb links",     INWEB_LINKS_MARKDOWNFEATURE);
	footnotes_Markdown_feature =    MarkdownVariations::new_feature(I"inweb footnotes", FOOTNOTES_MARKDOWNFEATURE);
	stroked_code_Markdown_feature = MarkdownVariations::new_feature(I"stroked code",    STROKED_CODE_MARKDOWNFEATURE);

	Inweb_flavoured_Markdown_variation = MarkdownVariations::new(I"Inweb-flavoured Markdown");
	MarkdownVariations::make_GitHub_features_active(Inweb_flavoured_Markdown_variation);
	MarkdownVariations::make_Inweb_features_active(Inweb_flavoured_Markdown_variation);

	simplified_Inweb_flavoured_Markdown_variation = MarkdownVariations::new(I"Inweb-flavoured Markdown");
	MarkdownVariations::make_simplified_Inweb_features_active(simplified_Inweb_flavoured_Markdown_variation);
}

void MarkdownVariations::make_Inweb_features_active(markdown_variation *variation) {
	MarkdownVariations::add_feature(variation, TEX_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, INWEB_LINKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, FOOTNOTES_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, EXTENDED_AUTOLINKS_MARKDOWNFEATURE);
}

void MarkdownVariations::make_simplified_Inweb_features_active(markdown_variation *variation) {
	MarkdownVariations::remove_feature(variation, BLOCK_QUOTES_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, ORDERED_LISTS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, UNORDERED_LISTS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, INDENTED_CODE_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, FENCED_CODE_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, HTML_BLOCKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, THEMATIC_MARKERS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, ATX_HEADINGS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, SETEXT_HEADINGS_MARKDOWNFEATURE);

	MarkdownVariations::remove_feature(variation, WEB_AUTOLINKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, EMAIL_AUTOLINKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, INLINE_HTML_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, BACKTICKED_CODE_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, LINKS_MARKDOWNFEATURE);
	MarkdownVariations::remove_feature(variation, IMAGES_MARKDOWNFEATURE);

	MarkdownVariations::add_feature(variation, TEX_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, INWEB_LINKS_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, FOOTNOTES_MARKDOWNFEATURE);
	MarkdownVariations::add_feature(variation, STROKED_CODE_MARKDOWNFEATURE);
}

@h Methods for features.
New features need to be able to intervene in the parsing or rendering algorithms,
so for that we provide methods.

|RENDER_MARKDOWN_MTID| allows a feature to meddle in how a node is rendered.

@e RENDER_MARKDOWN_MTID

=
INT_METHOD_TYPE(RENDER_MARKDOWN_MTID, markdown_feature *feature, text_stream *OUT,
	markdown_item *md, int mode)
int MarkdownVariations::intervene_in_rendering(markdown_variation *variation,
	text_stream *OUT, markdown_item *md, int mode) {
	markdown_feature *feature;
	LOOP_OVER(feature, markdown_feature) {
		if (MarkdownVariations::supports(variation, feature->feature_ID)) {
			int rv = FALSE;
			INT_METHOD_CALL(rv, feature, RENDER_MARKDOWN_MTID, OUT, md, mode);
			if (rv) return TRUE;
		}
	}
	return FALSE;
}

@ |POST_PHASE_I_MARKDOWN_MTID| allows a feature to restructure or annotate the
block tree produced by Phase I parsing; similarly |POST_PHASE_II_MARKDOWN_MTID|.

@e POST_PHASE_I_MARKDOWN_MTID
@e POST_PHASE_II_MARKDOWN_MTID

=
VOID_METHOD_TYPE(POST_PHASE_I_MARKDOWN_MTID, markdown_feature *feature,
	markdown_item *tree, md_links_dictionary *link_references)
VOID_METHOD_TYPE(POST_PHASE_II_MARKDOWN_MTID, markdown_feature *feature,
	markdown_item *tree, md_links_dictionary *link_references)
void MarkdownVariations::intervene_after_Phase_I(markdown_variation *variation,
	markdown_item *tree, md_links_dictionary *link_references) {
	markdown_feature *feature;
	LOOP_OVER(feature, markdown_feature) {
		if (MarkdownVariations::supports(variation, feature->feature_ID)) {
			VOID_METHOD_CALL(feature, POST_PHASE_I_MARKDOWN_MTID, tree, link_references);
		}
	}
}
void MarkdownVariations::intervene_after_Phase_II(markdown_variation *variation,
	markdown_item *tree, md_links_dictionary *link_references) {
	markdown_feature *feature;
	LOOP_OVER(feature, markdown_feature) {
		if (MarkdownVariations::supports(variation, feature->feature_ID)) {
			VOID_METHOD_CALL(feature, POST_PHASE_II_MARKDOWN_MTID, tree, link_references);
		}
	}
}

@ |MULTIFILE_MARKDOWN_MTID| allows a feature to tell the parser that the content
will end up being split across multiple HTML files. If a feature wants to do
this, it should then set a "file point" at any top-level positions of its
choice, and return |TRUE|.

@e MULTIFILE_MARKDOWN_MTID

=
INT_METHOD_TYPE(MULTIFILE_MARKDOWN_MTID, markdown_feature *feature,
	markdown_item *tree, md_links_dictionary *link_references)
int MarkdownVariations::multifile_mode(markdown_variation *variation,
	markdown_item *tree, md_links_dictionary *link_references) {
	if (tree->down) {
		markdown_feature *feature;
		LOOP_OVER(feature, markdown_feature) {
			if (MarkdownVariations::supports(variation, feature->feature_ID)) {
				int rv = FALSE;
				INT_METHOD_CALL(rv, feature, MULTIFILE_MARKDOWN_MTID, tree, link_references);
				if (rv) {
					MarkdownVariations::assign_URLs_to_headings(tree, link_references);
					return TRUE;
				}
			}
		}
	}
	return FALSE;
}

void MarkdownVariations::assign_URLs_to_headings(markdown_item *tree,
	md_links_dictionary *link_references) {
	if (tree->down->type != VOLUME_MIT) {
		markdown_item *index = Markdown::new_volume_marker(I"all in one");
		index->next = tree->down; tree->down = index;
	}
	for (markdown_item *md = tree->down; md; md = md->next) {
		if (md->type == VOLUME_MIT) {
			md->down = md->next; md->next = NULL;
			markdown_item *ch = md->down, *prev_ch = NULL;
			while ((ch) && (ch->type != VOLUME_MIT)) { prev_ch = ch, ch = ch->next; }
			if (ch) { prev_ch->next = NULL; md->next = ch; }
		}
	}
	for (markdown_item *vol = tree->down; vol; vol = vol->next) {
		if (vol->type == VOLUME_MIT) {
			if ((vol->down) && (vol->down->type != FILE_MIT)) {
				#ifdef SUPERVISOR_MODULE
				text_stream *home_URL = DocumentationCompiler::home_URL_at_volume_item(vol);
				#endif
				#ifndef SUPERVISOR_MODULE
				text_stream *home_URL = I"index.html";
				#endif
				markdown_item *index = Markdown::new_file_marker(Filenames::from_text(home_URL));
				index->next = vol->down; vol->down = index;
			}
			for (markdown_item *md = vol->down; md; md = md->next) {
				if (md->type == FILE_MIT) {
					md->down = md->next; md->next = NULL;
					markdown_item *ch = md->down, *prev_ch = NULL;
					while ((ch) && (ch->type != FILE_MIT) && (ch->type != VOLUME_MIT)) { prev_ch = ch, ch = ch->next; }
					if (ch) { prev_ch->next = NULL; md->next = ch; }
				}
			}
		}
	}
	
	markdown_item *headings[7] = { NULL, NULL, NULL, NULL, NULL, NULL, NULL };
	MarkdownVariations::multifile_r(tree->down, link_references, headings, NULL);
}

@

=
void MarkdownVariations::multifile_r(markdown_item *md, md_links_dictionary *link_references,
	markdown_item *headings[7], markdown_item *file_item) {
	int non_heading_found = FALSE;
	for (; md; md = md->next) {
		if (md->type == HEADING_MIT) {
			int L = Markdown::get_heading_level(md);
			headings[L] = md;
			for (int i=L+1; i<=6; i++) headings[i] = NULL;
			text_stream *URL = Str::new();
			if (file_item) {
				WRITE_TO(URL, "%f", Markdown::get_filename(file_item));
			}
			TEMPORARY_TEXT(xref)
			TEMPORARY_TEXT(anchor)
			match_results mr = Regexp::create_mr();
			if (Regexp::match(&mr, md->stashed, U"Chapter (%d+): *(%c*)")) {
				WRITE_TO(xref, "%S", mr.exp[1]);
				WRITE_TO(anchor, "chapter%S", mr.exp[0]);
			} else if (Regexp::match(&mr, md->stashed, U"Chapter (%d+)")) {
				WRITE_TO(xref, "%S", md->stashed);
				WRITE_TO(anchor, "chapter%S", mr.exp[0]);
			} else if (Regexp::match(&mr, md->stashed, U"Section (%d+).(%d+): *(%c*)")) {
				WRITE_TO(xref, "%S", mr.exp[2]);
				WRITE_TO(anchor, "c%Ss%S", mr.exp[0], mr.exp[1]);
			} else if (Regexp::match(&mr, md->stashed, U"Section (%d+).(%d+)")) {
				WRITE_TO(xref, "%S", md->stashed);
				WRITE_TO(anchor, "c%Ss%S", mr.exp[0], mr.exp[1]);
			} else if (Regexp::match(&mr, md->stashed, U"Section (%d+): *(%c*)")) {
				WRITE_TO(xref, "%S", mr.exp[1]);
				WRITE_TO(anchor, "s%S", mr.exp[0]);
			} else if (Regexp::match(&mr, md->stashed, U"Section (%d+)")) {
				WRITE_TO(xref, "%S", md->stashed);
				WRITE_TO(anchor, "s%S", mr.exp[0]);
			} else {
				WRITE_TO(xref, "%S", md->stashed);
				WRITE_TO(anchor, "heading%d", md->id);
			}
			Regexp::dispose_of(&mr);
			if (non_heading_found) {
				WRITE_TO(URL, "#%S", anchor);
			}
			md->user_state = STORE_POINTER_text_stream(URL);
			Markdown::create(link_references, xref, URL, md->stashed);
			DISCARD_TEXT(xref)
			DISCARD_TEXT(anchor)
		} else {
			non_heading_found = TRUE;
		}
		MarkdownVariations::multifile_r(md->down, link_references, headings, (md->type == FILE_MIT)?md:NULL);
	}
}

text_stream *MarkdownVariations::URL_for_heading(markdown_item *md) {
	if ((md) && (md->type == HEADING_MIT) && (Markdown::get_heading_level(md) <= 2))
		if (GENERAL_POINTER_IS_NULL(md->user_state) == FALSE)
			return RETRIEVE_POINTER_text_stream(md->user_state);
	return NULL;
}
