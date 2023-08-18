[MarkdownVariations::] Markdown Variations.

To specify modified versions of the Markdown markup syntax.

@ This all does nothing as yet, but it's a hook. The idea is that an instance
of this object represents a variant of Markdown, either parsed differently
or rendered differently, or both.

=
typedef struct markdown_variation {
	struct text_stream *name;
	struct method_set *methods;
	CLASS_DEFINITION
} markdown_variation;

markdown_variation *MarkdownVariations::new(text_stream *name) {
	markdown_variation *variation = CREATE(markdown_variation);
	variation->name = Str::duplicate(name);
	return variation;
}

@ Vanilla ice cream is under-rated:

=
markdown_variation *CommonMark_variation = NULL;

markdown_variation *MarkdownVariations::CommonMark(void) {
	if (CommonMark_variation == NULL)
		CommonMark_variation = MarkdownVariations::new(I"CommonMark 0.30");
	return CommonMark_variation;
}
