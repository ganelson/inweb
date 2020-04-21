[Patterns::] Patterns.

Managing weave patterns, which are bundled configuration settings for weaving.

@h Reading in.
Patterns are stored as directories in the file system, and are identified by
names such as |HTML|. On request, we need to find the directory corresponding
to such a name, and to read it in. This structure holds the result:

=
typedef struct weave_pattern {
	struct text_stream *pattern_name; /* such as |HTML| */
	struct pathname *pattern_location; /* the directory */
	struct weave_pattern *based_on; /* inherit from which other pattern? */

	struct weave_format *pattern_format; /* such as |DVI|: the desired final format */
	struct linked_list *plugins; /* of |weave_plugin|: any extras needed */
	struct linked_list *colour_schemes; /* of |colour_scheme|: any extras needed */
	struct linked_list *payloads; /* of |text_stream|: leafnames of associated files */
	struct linked_list *up_payloads; /* of |text_stream|: leafnames of associated files */

	struct text_stream *tex_command; /* shell command to use for |tex| */
	struct text_stream *pdftex_command; /* shell command to use for |pdftex| */
	struct text_stream *open_command; /* shell command to use for |open| */

	int embed_CSS; /* embed CSS directly into any HTML files made? */
	int hierarchical; /* weave as one part of a collection of woven webs */
	int show_abbrevs; /* show section range abbreviations in the weave? */
	int number_sections; /* insert section numbers into the weave? */
	struct text_stream *default_range; /* for example, |sections| */

	struct web *patterned_for; /* the web which caused this to be read in */
	MEMORY_MANAGEMENT
} weave_pattern;

@ When a given web needs a pattern with a given name, this is where it comes.

=
weave_pattern *Patterns::find(web *W, text_stream *name) {
	filename *pattern_file = NULL;
	weave_pattern *wp = CREATE(weave_pattern);
	@<Initialise the pattern structure@>;
	@<Locate the pattern directory@>;
	@<Read in the pattern.txt file@>;
	return wp;
}

@<Initialise the pattern structure@> =
	wp->pattern_name = Str::duplicate(name);
	wp->pattern_location = NULL;
	wp->plugins = NEW_LINKED_LIST(weave_plugin);
	wp->colour_schemes = NEW_LINKED_LIST(colour_scheme);
	wp->payloads = NEW_LINKED_LIST(text_stream);
	wp->up_payloads = NEW_LINKED_LIST(text_stream);
	wp->based_on = NULL;
	wp->embed_CSS = FALSE;
	wp->hierarchical = FALSE;
	wp->patterned_for = W;
	wp->show_abbrevs = TRUE;
	wp->number_sections = FALSE;
	wp->default_range = Str::duplicate(I"0");
	wp->tex_command = Str::duplicate(I"tex");
	wp->pdftex_command = Str::duplicate(I"pdftex");
	wp->open_command = Str::duplicate(I"open");

@<Locate the pattern directory@> =
	wp->pattern_location = NULL;
	pathname *CP = Colonies::patterns_path();
	if (CP) {
		wp->pattern_location = Pathnames::down(CP, name);
		pattern_file = Filenames::in(wp->pattern_location, I"pattern.txt");
		if (TextFiles::exists(pattern_file) == FALSE) wp->pattern_location = NULL;
	}
	if (wp->pattern_location == NULL) {
		wp->pattern_location = Pathnames::down(
			Pathnames::down(W->md->path_to_web, I"Patterns"), name);
		pattern_file = Filenames::in(wp->pattern_location, I"pattern.txt");
		if (TextFiles::exists(pattern_file) == FALSE) wp->pattern_location = NULL;
	}
	if (wp->pattern_location == NULL) {
		wp->pattern_location = Pathnames::down(
			path_to_inweb_patterns, name);
		pattern_file = Filenames::in(wp->pattern_location, I"pattern.txt");
		if (TextFiles::exists(pattern_file) == FALSE) wp->pattern_location = NULL;
	}
	if (wp->pattern_location == NULL)
		Errors::fatal_with_text("no such weave pattern as '%S'", name);

@<Read in the pattern.txt file@> =
	if (pattern_file)
		TextFiles::read(pattern_file, FALSE, "can't open pattern.txt file",
			TRUE, Patterns::scan_pattern_line, NULL, wp);
	if (wp->pattern_format == NULL)
		Errors::fatal_with_text("pattern did not specify a format", name);

@ The Foundation module provides a standard way to scan text files line by
line, and this is used to send each line in the |pattern.txt| file to the
following routine:

=
void Patterns::scan_pattern_line(text_stream *line, text_file_position *tfp, void *X) {
	weave_pattern *wp = (weave_pattern *) X;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *from (%c+)")) @<This is a from command@>;
	if (Regexp::match(&mr, line, L" *(%c+?) = (%c+)")) @<This is an X = Y command@>;
	if (Regexp::match(&mr, line, L" *embed css *")) @<This is an embed CSS command@>;
	if (Regexp::match(&mr, line, L" *hierarchical *")) @<This is a hierarchical command@>;
	if (Regexp::match(&mr, line, L" *plugin (%c+)")) @<This is a plugin command@>;
	if (Regexp::match(&mr, line, L" *use (%c+)")) @<This is a use command@>;
	if (Regexp::match(&mr, line, L" *use-up (%c+)")) @<This is a use-up command@>;
	if (Regexp::match(&mr, line, L" *%C%c*"))
		Errors::in_text_file("unrecognised pattern command", tfp);
	Regexp::dispose_of(&mr);
}

@<This is a from command@> =
	wp->based_on = Patterns::find(wp->patterned_for, mr.exp[0]);
	Regexp::dispose_of(&mr);
	return;

@<This is an X = Y command@> =
	if (Str::eq(mr.exp[0], I"format")) {
		wp->pattern_format = Formats::find_by_name(mr.exp[1]);
	} else if (Str::eq(mr.exp[0], I"abbrevs")) {
		wp->show_abbrevs = Patterns::yes_or_no(mr.exp[1], tfp);
	} else if (Str::eq(mr.exp[0], I"numbered")) {
		wp->number_sections = Patterns::yes_or_no(mr.exp[1], tfp);
	} else if (Str::eq(mr.exp[0], I"default-range")) {
		wp->default_range = Str::duplicate(mr.exp[1]);
	} else if (Str::eq(mr.exp[0], I"tex-command")) {
		wp->tex_command = Str::duplicate(mr.exp[1]);
	} else if (Str::eq(mr.exp[0], I"pdftex-command")) {
		wp->pdftex_command = Str::duplicate(mr.exp[1]);
	} else if (Str::eq(mr.exp[0], I"open-command")) {
		wp->open_command = Str::duplicate(mr.exp[1]);
	} else if ((Bibliographic::data_exists(wp->patterned_for->md, mr.exp[0])) ||
		(Str::eq(mr.exp[0], I"Booklet Title"))) {
		Bibliographic::set_datum(wp->patterned_for->md, mr.exp[0], mr.exp[1]);
	} else {
		PRINT("Setting: %S\n", mr.exp[0]);
		Errors::in_text_file("no such pattern setting", tfp);
	}
	Regexp::dispose_of(&mr);
	return;

@<This is an embed CSS command@> =
	wp->embed_CSS = TRUE;
	Regexp::dispose_of(&mr);
	return;

@<This is a hierarchical command@> =
	wp->hierarchical = TRUE;
	Regexp::dispose_of(&mr);
	return;

@ "Plugins" here refer to //Weave Plugins//.

@<This is a plugin command@> =
	weave_plugin *plugin = WeavePlugins::new(mr.exp[0]);
	ADD_TO_LINKED_LIST(plugin, weave_plugin, wp->plugins);
	Regexp::dispose_of(&mr);
	return;

@ "Payloads" are associated files such as images which may be needed for an
HTML weave to look right. We identify them here only by leafname: their
actual location will depend on where the pattern directory is.

@<This is a use command@> =
	text_stream *leafname = Str::duplicate(mr.exp[0]);
	ADD_TO_LINKED_LIST(leafname, text_stream, wp->payloads);
	Regexp::dispose_of(&mr);
	return;

@<This is a use-up command@> =
	text_stream *leafname = Str::duplicate(mr.exp[0]);
	ADD_TO_LINKED_LIST(leafname, text_stream, wp->up_payloads);
	Regexp::dispose_of(&mr);
	return;

@ =
int Patterns::yes_or_no(text_stream *arg, text_file_position *tfp) {
	if (Str::eq(arg, I"yes")) return TRUE;
	if (Str::eq(arg, I"no")) return FALSE;
	Errors::in_text_file("setting must be 'yes' or 'no'", tfp);
	return FALSE;
}

@h Obtaining files.
Patterns provide not merely some configuration settings (above): they also
provide template or style files of various kinds. When Inweb wants to find
a pattern file with a given leafname, it looks for it in the pattern
directory. If that fails, it then looks in the directory of the pattern
inherited from.

Note that if you're rash enough to set up a cycle of patterns inheriting
from each other then this routine will lock up into an infinite loop.

=
filename *Patterns::obtain_filename(weave_pattern *pattern, text_stream *leafname) {
	if (Str::prefix_eq(leafname, I"../", 3)) {
		Str::delete_first_character(leafname);
		Str::delete_first_character(leafname);
		Str::delete_first_character(leafname);
	}
	filename *F = Filenames::in(pattern->pattern_location, leafname);
	if (TextFiles::exists(F)) return F;
	if (pattern->based_on) return Patterns::obtain_filename(pattern->based_on, leafname);
	return NULL;
}

@ And similarly, but with an intermediate directory:

=
filename *Patterns::find_asset(weave_pattern *pattern, text_stream *dirname,
	text_stream *leafname) {
	for (weave_pattern *wp = pattern; wp; wp = wp->based_on) {
		pathname *P = Pathnames::down(wp->pattern_location, dirname);
		filename *F = Filenames::in(P, leafname);
		if (TextFiles::exists(F)) return F;
	}
	return NULL;
}

@ When we eventually want to deal with the |use P| commands, which call
for payloads to be copied into weave, we make good use of the above:

=
void Patterns::copy_payloads_into_weave(web *W, weave_pattern *pattern) {
	text_stream *leafname;
	LOOP_OVER_LINKED_LIST(leafname, text_stream, pattern->payloads) {
		filename *F = Patterns::obtain_filename(pattern, leafname);
		Patterns::copy_file_into_weave(W, F, NULL, NULL);
		if (W->as_ebook) {
			filename *rel = Filenames::in(NULL, leafname);
			Epub::note_image(W->as_ebook, rel);
		}
	}
	LOOP_OVER_LINKED_LIST(leafname, text_stream, pattern->up_payloads) {
		filename *F = Patterns::obtain_filename(pattern, leafname);
		Patterns::copy_up_file_into_weave(W, F, NULL);
		if (W->as_ebook) {
			filename *rel = Filenames::in(NULL, leafname);
			Epub::note_image(W->as_ebook, rel);
		}
	}
}

@ =
typedef struct css_file_transformation {
	struct text_stream *OUT;
	struct text_stream *trans;
} css_file_transformation;

void Patterns::copy_file_into_weave(web *W, filename *F, pathname *P, text_stream *trans) {
	pathname *H = W->redirect_weaves_to;
	if (H == NULL) H = Reader::woven_folder(W);
	if (P) H = P;
	if (Str::len(trans) > 0) {
		text_stream css_S;
		filename *G = Filenames::in(P, Filenames::get_leafname(F));
		if (STREAM_OPEN_TO_FILE(&css_S, G, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write tangled file", F);
		css_file_transformation cft;
		cft.OUT = &css_S;
		cft.trans = trans;
		TextFiles::read(F, FALSE, "can't open CSS file", TRUE,
			Patterns::transform_CSS, NULL, (void *) &cft);
		STREAM_CLOSE(cft.OUT);
	} else Shell::copy(F, H, "");
}

void Patterns::transform_CSS(text_stream *line, text_file_position *tfp, void *X) {
	css_file_transformation *cft = (css_file_transformation *) X;
	text_stream *OUT = cft->OUT;
	match_results mr = Regexp::create_mr();
	TEMPORARY_TEXT(spanned);
	while (Regexp::match(&mr, line, L"(%c*?span.)(%i+)(%c*?)")) {
		WRITE_TO(spanned, "%S%S%S", mr.exp[0], cft->trans, mr.exp[1]);
		Str::clear(line); Str::copy(line, mr.exp[2]);
	}
	WRITE_TO(spanned, "%S\n", line);
	while (Regexp::match(&mr, spanned, L"(%c*?pre.)(%i+)(%c*?)")) {
		WRITE("%S%S%S", mr.exp[0], cft->trans, mr.exp[1]);
		Str::clear(spanned); Str::copy(spanned, mr.exp[2]);
	}
	WRITE("%S\n", spanned);
	DISCARD_TEXT(spanned);
	Regexp::dispose_of(&mr);
}

void Patterns::copy_up_file_into_weave(web *W, filename *F, pathname *P) {
	pathname *H = W->redirect_weaves_to;
	if (H == NULL) H = Reader::woven_folder(W);
	H = Pathnames::up(H);
	if (P) H = P;
	Shell::copy(F, H, "");
}

@ =
void Patterns::include_plugins(OUTPUT_STREAM, web *W, weave_pattern *pattern, filename *from) {
	for (weave_pattern *p = pattern; p; p = p->based_on) {
		weave_plugin *wp;
		LOOP_OVER_LINKED_LIST(wp, weave_plugin, p->plugins)
			WeavePlugins::include_plugin(OUT, W, wp, pattern, from);
		colour_scheme *cs;
		LOOP_OVER_LINKED_LIST(cs, colour_scheme, p->colour_schemes)
			WeavePlugins::include_colour_scheme(OUT, W, cs, pattern, from);
	}
}
