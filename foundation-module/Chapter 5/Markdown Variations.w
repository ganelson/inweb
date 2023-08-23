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
}

markdown_variation *CommonMark_variation = NULL;

markdown_variation *MarkdownVariations::CommonMark(void) {
	return CommonMark_variation;
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
@e EMPHASIS_MARKDOWNFEATURE

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
markdown_feature *emphasis_Markdown_feature = NULL;

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
	emphasis_Markdown_feature =             MarkdownVariations::new_feature(I"emphasis",             EMPHASIS_MARKDOWNFEATURE);

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
	MarkdownVariations::add_feature(variation, EMPHASIS_MARKDOWNFEATURE);

	MarkdownVariations::add_feature(variation, ENTITIES_MARKDOWNFEATURE);
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

