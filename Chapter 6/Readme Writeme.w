[Readme::] Readme Writeme.

To construct Readme and similar files.

@ This is a simple use of //foundation: Preprocessor//. Note that we use a
non-standard comment syntax (i.e., |/| at start of line, not |#|) to avoid
colliding with Markdown's heading syntax.

=
void Readme::write(filename *prototype, filename *F) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	preprocessor_macro *mm = Preprocessor::new_macro(L,
		I"bibliographic", I"datum: DATUM of: ASSET",
		Readme::bibliographic_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(mm);
	WRITE_TO(STDOUT, "(Read script from %f)\n", prototype);
	Preprocessor::preprocess(prototype, F, NULL, L, NULL_GENERAL_POINTER, '/', ISO_ENC);
}

@ And this is the one domain-specific macro:

=
void Readme::bibliographic_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	text_stream *datum = parameter_values[0];
	text_stream *asset_name = parameter_values[1];
	text_stream *OUT = PPS->dest;
	writeme_asset *A = Readme::find_asset(asset_name);
	if (A->if_web) WRITE("%S", Bibliographic::get_datum(A->if_web, datum));
	else if (Str::eq(datum, I"Build Date")) WRITE("%S", A->date);
	else if (Str::eq(datum, I"Version Number")) WRITE("%S", A->version);
}

@ An "asset" here is something for which we might want to write the version
number of, or some similar metadata for. Assets are usually webs, but can
also be a few other rather Inform-specific things; those have a more limited
range of bibliographic data, just the version and date (and we will not
assume that the version complies with any format).

=
typedef struct writeme_asset {
	struct text_stream *name;
	struct web_md *if_web;
	struct text_stream *date;
	struct text_stream *version;
	int next_is_version;
	CLASS_DEFINITION
} writeme_asset;

void Readme::write_var(text_stream *OUT, text_stream *program, text_stream *datum) {
	writeme_asset *A = Readme::find_asset(program);
	if (A->if_web) WRITE("%S", Bibliographic::get_datum(A->if_web, datum));
	else if (Str::eq(datum, I"Build Date")) WRITE("%S", A->date);
	else if (Str::eq(datum, I"Version Number")) WRITE("%S", A->version);
}

@ That just leaves the business of inspecting assets to obtain their metadata.

=
writeme_asset *Readme::find_asset(text_stream *program) {
	writeme_asset *A;
	LOOP_OVER(A, writeme_asset) if (Str::eq(program, A->name)) return A;
	A = CREATE(writeme_asset);
	A->name = Str::duplicate(program);
	A->if_web = NULL;
	A->date = Str::new();
	A->version = Str::new();
	A->next_is_version = FALSE;
	@<Read in the asset@>;
	return A;
}

@<Read in the asset@> =
	if (Str::ends_with_wide_string(program, U".i7x")) {
		@<Read in the extension file@>;
	} else {
		if (WebMetadata::directory_looks_like_a_web(Pathnames::from_text(program))) {
			A->if_web = WebMetadata::get_without_modules(Pathnames::from_text(program), NULL);
		} else {
			filename *I6_vn = Filenames::in(
				Pathnames::down(Pathnames::from_text(program), I"inform6"), I"header.h");
			if (TextFiles::exists(I6_vn)) @<Read in I6 source header file@>;
			filename *template_vn = Filenames::in(Pathnames::from_text(program), I"(manifest).txt");
			if (TextFiles::exists(template_vn)) @<Read in template manifest file@>;
			filename *rmt_vn = Filenames::in(Pathnames::from_text(program), I"README.txt");
			if (TextFiles::exists(rmt_vn)) @<Read in README file@>;
			rmt_vn = Filenames::in(Pathnames::from_text(program), I"README.md");
			if (TextFiles::exists(rmt_vn)) @<Read in README file@>;
		}
	}

@<Read in the extension file@> =
	TextFiles::read(Filenames::from_text(program), FALSE, "unable to read extension", TRUE,
		&Readme::extension_harvester, NULL, A);

@<Read in I6 source header file@> =
	TextFiles::read(I6_vn, FALSE, "unable to read header file from I6 source", TRUE,
		&Readme::header_harvester, NULL, A);

@<Read in template manifest file@> =
	TextFiles::read(template_vn, FALSE, "unable to read manifest file from website template", TRUE,
		&Readme::template_harvester, NULL, A);

@<Read in README file@> =
	TextFiles::read(rmt_vn, FALSE, "unable to read README file from website template", TRUE,
		&Readme::readme_harvester, NULL, A);

@ The format for the contents section of a web is documented in Inweb.

=
void Readme::extension_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, U" *Version (%c*?) of %c*begins here. *"))
		A->version = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@ Explicit code to read from |header.h| in the Inform 6 repository.

=
void Readme::header_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, U"#define RELEASE_NUMBER (%c*?) *"))
		A->version = Str::duplicate(mr.exp[0]);
	if (Regexp::match(&mr, text, U"#define RELEASE_DATE \"(%c*?)\" *"))
		A->date = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);
}

@ Explicit code to read from the manifest file of a website template.

=
void Readme::template_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, U"%[INTERPRETERVERSION%]")) {
		A->next_is_version = TRUE;
	} else if (A->next_is_version) {
		A->version = Str::duplicate(text);
		A->next_is_version = FALSE;
	}
	Regexp::dispose_of(&mr);
}

@ And this is needed for |cheapglk| and |glulxe| in the Inform repository.

=
void Readme::readme_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if ((Regexp::match(&mr, text, U"CheapGlk Library: version (%c*?) *")) ||
		(Regexp::match(&mr, text, U"- Version (%c*?) *")))
		A->version = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);
}
