[Readme::] Readme Writeme.

To construct Readme and similar files.

@ This is a simple use of //foundation: Preprocessor//. Note that we use a
non-standard comment syntax (i.e., |/| at start of line, not |#|) to avoid
colliding with Markdown's heading syntax.

=
typedef struct inweb_reference_data {
	struct ls_web *W;
	struct ls_colony *C;
	struct ls_colony_member *CM;
	CLASS_DEFINITION
} inweb_reference_data;

linked_list *Readme::write(filename *prototype, filename *F, ls_web *W, ls_colony *C, ls_colony_member *CM) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	preprocessor_macro *mm = Preprocessor::new_macro(L,
		I"bibliographic", I"datum: DATUM ?of: ASSET",
		Readme::bibliographic_expander, NULL);
	preprocessor_macro *mm2 = Preprocessor::new_macro(L,
		I"metadata", I": DATUM ?of: ASSET",
		Readme::bibliographic_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(mm);
	Preprocessor::do_not_suppress_whitespace(mm2);
	preprocessor_macro *vm = Preprocessor::new_macro(L,
		I"version", I"?web: WEB ?program: PROGRAM ?template: TEMPLATE ?extension: EXTENSION ?inform6: INFORM6",
		Readme::version_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(vm);
	preprocessor_macro *dm = Preprocessor::new_macro(L,
		I"date", I"?web: WEB ?program: PROGRAM ?template: TEMPLATE ?extension: EXTENSION ?inform6: INFORM6",
		Readme::date_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(dm);
	preprocessor_macro *lwm = Preprocessor::new_macro(L,
		I"list-of-webs", NULL,
		Readme::list_of_webs_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(lwm);
	preprocessor_macro *wm = Preprocessor::new_macro(L,
		I"web", NULL,
		Readme::web_expander, NULL);
	Preprocessor::do_not_suppress_whitespace(wm);
	inweb_reference_data *ird = CREATE(inweb_reference_data);
	ird->W = W; ird->C = C; ird->CM = CM;
	return Preprocessor::preprocess(prototype, F, NULL, L,
		STORE_POINTER_inweb_reference_data(ird), '/', ISO_ENC);
}

@ And this is the one domain-specific macro:

=
void Readme::bibliographic_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	inweb_reference_data *ird = RETRIEVE_POINTER_inweb_reference_data(PPS->specifics);
	text_stream *datum = parameter_values[0];
	text_stream *asset_name = parameter_values[1];
	text_stream *OUT = PPS->dest;
	@<Expand metadata for web@>;
}

@<Expand metadata for web@> =
	if ((Readme::refers_to(asset_name, ird->W)) || (Str::len(asset_name) == 0)) {
		ls_web *W = NULL;
		ls_colony_member *CM = ird->CM;
		if (ird->W) {
			W = ird->W;
		} else if (ird->C) {
			CM = FIRST_IN_LINKED_LIST(ls_colony_member, ird->C->members);
			if (CM) {
				Colonies::fully_load_member(CM);
				W = CM->loaded;
			}
		} else if (ird->CM) {
			Colonies::fully_load_member(ird->CM);
			W = ird->CM->loaded;
		}
		
		@<Expand datum from web W@>;
		return;
	}
	if (ird->C) {
		ls_colony_member *CM = Colonies::find(ird->C, asset_name);
		if (CM) {
			Colonies::fully_load_member(CM);
			ls_web *W = CM->loaded;
			@<Expand datum from web W@>;
			return;
		}
	}
	TEMPORARY_TEXT(err)
	WRITE_TO(err, "cannot see a web called '%S'", asset_name);
	Preprocessor::error(PPS, tfp, err);
	DISCARD_TEXT(err)
	WRITE("{%S}", datum);

@<Expand datum from web W@> =
	if (W) {
		if (Bibliographic::look_up_datum(W, datum)) {
			WRITE("%S", Bibliographic::get_datum(W, datum));
		} else {
			text_stream *id = Bibliographic::get_datum(W, I"Title");
			if (CM) id = CM->name;
			TEMPORARY_TEXT(err)
			WRITE_TO(err, "the web '%S' does not provide '%S'", id, datum);
			Preprocessor::error(PPS, tfp, err);
			DISCARD_TEXT(err)
			WRITE("{%S}", datum);
		}
	} else {
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "cannot see which web should provide '%S'", datum);
		Preprocessor::error(PPS, tfp, err);
		DISCARD_TEXT(err)
		WRITE("{%S}", datum);
	}

@

=
void Readme::version_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	Readme::details_expander(TRUE, mm, PPS, parameter_values, loop, tfp);
}
	
void Readme::date_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	Readme::details_expander(FALSE, mm, PPS, parameter_values, loop, tfp);
}
	
void Readme::details_expander(int version, preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	inweb_reference_data *ird = RETRIEVE_POINTER_inweb_reference_data(PPS->specifics);
	pathname *home = NULL;
	if (ird->C) home = Colonies::base_pathname(ird->C);
	text_stream *web_name = parameter_values[0];
	text_stream *program_name = parameter_values[1];
	text_stream *template_name = parameter_values[2];
	text_stream *extension_name = parameter_values[3];
	text_stream *inform6_name = parameter_values[4];
	text_stream *OUT = PPS->dest;
	if (Str::len(web_name) > 0) {
		text_stream *datum = I"Version Number";
		text_stream *asset_name = web_name;
		@<Expand metadata for web@>;
	} else if (Str::len(program_name) > 0) {
		writeme_asset *A = Readme::find_asset(program_name);
		filename *rmt_vn = Filenames::in(Pathnames::from_text_relative(home, program_name), I"README.txt");
		if (TextFiles::exists(rmt_vn)) {
			@<Read in README file@>;
			@<Write the detail@>;
		} else {
			rmt_vn = Filenames::in(Pathnames::from_text_relative(home, program_name), I"README.md");
			if (TextFiles::exists(rmt_vn)) {
				@<Read in README file@>;
				@<Write the detail@>;
			} else {
				Preprocessor::error(PPS, tfp, I"program does not have a 'README.txt' or 'README.md' file");
			}
		}
	} else if (Str::len(template_name) > 0) {
		writeme_asset *A = Readme::find_asset(template_name);
		filename *template_vn = Filenames::in(Pathnames::from_text_relative(home, template_name), I"(manifest).txt");
		if (TextFiles::exists(template_vn)) {
			@<Read in template manifest file@>;
			@<Write the detail@>;
		} else {
			Preprocessor::error(PPS, tfp, I"does not seem to be a template");
		}
	} else if (Str::len(extension_name) > 0) {
		writeme_asset *A = Readme::find_asset(extension_name);
		@<Read in the extension file@>;
		@<Write the detail@>;
	} else if (Str::len(inform6_name) > 0) {
		writeme_asset *A = Readme::find_asset(inform6_name);
		filename *I6_vn = Filenames::in(
			Pathnames::down(Pathnames::from_text_relative(home, inform6_name), I"inform6"), I"header.h");
		if (TextFiles::exists(I6_vn)) {
			@<Read in I6 source header file@>;
			@<Write the detail@>;
		} else {
			Preprocessor::error(PPS, tfp, I"does not seem to be the Inform 6 compiler source location");
		}
	} else {
		Preprocessor::error(PPS, tfp, I"nothing to find details of");
	}
}

@<Write the detail@> =
	if (version) WRITE("%S", A->version);
	else WRITE("%S", A->date);

@

=
void Readme::list_of_webs_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	inweb_reference_data *ird = RETRIEVE_POINTER_inweb_reference_data(PPS->specifics);
	text_stream *OUT = PPS->dest;
	if (ird->C) {
		int N = 0;
		ls_colony_member *CM;
		LOOP_OVER_LINKED_LIST(CM, ls_colony_member, ird->C->members) {
			if (N++ > 0) WRITE(", ");
			WRITE("%S", CM->name);
		}
	} else if (ird->W) {
		if (ird->W->single_file)
			Filenames::write_unextended_leafname(OUT, ird->W->single_file);
		else
			WRITE("%S", Pathnames::directory_name(ird->W->path_to_web));
	}
}

void Readme::web_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	inweb_reference_data *ird = RETRIEVE_POINTER_inweb_reference_data(PPS->specifics);
	text_stream *OUT = PPS->dest;
	if (ird->W) {
		if (ird->W->single_file)
			Filenames::write_unextended_leafname(OUT, ird->W->single_file);
		else
			WRITE("%S", Pathnames::directory_name(ird->W->path_to_web));
	} else if (ird->C) {
		ls_colony_member *CM;
		LOOP_OVER_LINKED_LIST(CM, ls_colony_member, ird->C->members) {
			WRITE("%S", CM->name);
			break;
		}
	}
}

@

=
int Readme::refers_to(text_stream *name, ls_web *W) {
	if (W == NULL) return FALSE;
	if (Str::eq_insensitive(Bibliographic::get_datum(W, I"Title"), name)) return TRUE;
	if (W->single_file) {
		TEMPORARY_TEXT(leaf)
		Filenames::write_unextended_leafname(leaf, W->single_file);
		int rv = Str::eq_insensitive(leaf, name);
		DISCARD_TEXT(leaf)
		return rv;
	}
	if (Str::eq_insensitive(Pathnames::directory_name(W->path_to_web), name)) return TRUE;
	return FALSE;
}

@ An "asset" here is something for which we might want to write the version
number of, or some similar metadata for. Assets are usually webs, but can
also be a few other rather Inform-specific things; those have a more limited
range of bibliographic data, just the version and date (and we will not
assume that the version complies with any format).

=
typedef struct writeme_asset {
	struct text_stream *name;
	struct ls_web *if_web;
	struct text_stream *date;
	struct text_stream *version;
	int next_is_version;
	int identified;
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
	A->identified = FALSE;
	return A;
}

@<Read in the extension file@> =
	A->identified = TRUE;
	TextFiles::read(Filenames::from_text_relative(home, program_name), FALSE, "unable to read extension", TRUE,
		&Readme::extension_harvester, NULL, A);

@<Read in I6 source header file@> =
	A->identified = TRUE;
	TextFiles::read(I6_vn, FALSE, "unable to read header file from I6 source", TRUE,
		&Readme::header_harvester, NULL, A);

@<Read in template manifest file@> =
	A->identified = TRUE;
	TextFiles::read(template_vn, FALSE, "unable to read manifest file from website template", TRUE,
		&Readme::template_harvester, NULL, A);

@<Read in README file@> =
	A->identified = TRUE;
	TextFiles::read(rmt_vn, FALSE, "unable to read README file from website template", TRUE,
		&Readme::readme_harvester, NULL, A);

@ This extracts just the version text from an extension's titling line.

=
void Readme::extension_harvester(text_stream *text, text_file_position *tfp, void *state) {
	writeme_asset *A = (writeme_asset *) state;
	match_results mr = Regexp::create_mr();
	if (Str::len(text) == 0) return;
	if (Regexp::match(&mr, text, U" *Version (%c*?) of %c*begins* here. *"))
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
