[Colonies::] Colonies.

Cross-referencing multiple webs gathered together.

@h Colonies of webs.
Social spiders are said to form "colonies" when their webs are shared,[1] and in
that spirit, a colony is a collection of coexisting webs -- which share no code,
and in that sense have no connection at run-time, but which need to be
cross-referenced in their woven form, so that readers can easily turn from one
to another.

[1] Those curious to see what a colony of 110,000,000 spiders might be like to
walk through should see Albert Greene et al., "An Immense Concentration of
Orb-Weaving Spiders With Communal Webbing in a Man-Made Structural Habitat
(Arachnida: Araneae: Tetragnathidae, Araneidae)",
//American Entomologist (Fall 2010) -> https://doi.org/10.1093/ae/56.3.146//.

@ So, then, a colony is really just a membership list:

=
typedef struct colony {
	struct wcl_declaration *declaration;
	struct linked_list *members; /* of |colony_member| */
	struct text_stream *home; /* path of home repository */
	struct pathname *assets_path; /* where assets shared between weaves live */
	struct pathname *patterns_path; /* where additional patterns live */
	CLASS_DEFINITION
} colony;

@ Each member is represented by an instance of the following. Note the |loaded|
field: this holds metadata on the web/module in question. (Recall that a module
is really just a web that doesn't tangle to an independent program but to a
library of code: for almost all purposes, it's a web.) But for efficiency's
sake, we read this metadata only on demand.

Note that the |path| might be either the name of a single-file web, or of a
directory holding a multi-section web.

=
typedef struct colony_member {
	struct colony *owner;

	int web_rather_than_module; /* |TRUE| for a web, |FALSE| for a module */
	struct text_stream *name; /* the |N| in |N at P in W| */
	struct text_stream *path; /* the |P| in |N at P in W| */
	struct pathname *weave_path; /* the |W| in |N at P in W| */
	struct text_stream *home_leaf; /* usually |index.html|, but not for single-file webs */
	struct text_stream *default_weave_pattern; /* for use when weaving */
	
	struct ls_web *loaded; /* metadata on its sections, lazily evaluated */
	struct filename *navigation; /* navigation sidebar HTML */
	struct linked_list *breadcrumb_tail; /* of |breadcrumb_request| */
	CLASS_DEFINITION
} colony_member;

@ And the following reads a colony file |F| and produces a suitable |colony|
object from it.

=
typedef struct colony_reader_state {
	struct wcl_declaration *D;
	struct colony *province;
	struct filename *nav;
	struct linked_list *crumbs; /* of |breadcrumb_request| */
	struct text_stream *pattern;
} colony_reader_state;

colony *Colonies::load(filename *F) {
	wcl_declaration *D = WCL::read_just_one(F, COLONY_WCLTYPE);
	if (D == NULL) return NULL;
	return RETRIEVE_POINTER_colony(D->object_declared);
}

colony *Colonies::parse_declaration(wcl_declaration *D) {
	colony *C = CREATE(colony);
	C->declaration = D;
	C->members = NEW_LINKED_LIST(colony_member);
	C->home = I"docs";
	C->assets_path = NULL;
	C->patterns_path = NULL;
	colony_reader_state crs;
	crs.D = D;
	crs.province = C;
	crs.nav = NULL;
	crs.crumbs = NEW_LINKED_LIST(breadcrumb_request);
	crs.pattern = NULL;

	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		Colonies::read_line(line, &tfp, (void *) &crs);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	D->object_declared = STORE_POINTER_colony(C);
	return C;
}

void Colonies::resolve_declaration(wcl_declaration *D) {
}

@ Lines from the colony file are fed, one by one, into:

=
void Colonies::read_line(text_stream *line, text_file_position *tfp, void *v_crs) {
	colony_reader_state *crs = (colony_reader_state *) v_crs;
	colony *C = crs->province;

	Str::trim_white_space(line); /* ignore trailing space */
	if (Str::len(line) == 0) return; /* ignore blank lines */
	if (Str::get_first_char(line) == '#') return; /* lines opening with |#| are comments */

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"(%c*?): \"*(%C+)\" at \"(%c*)\" in \"(%c*)\"")) {
		colony_member *CM = CREATE(colony_member);
		if (Str::eq(mr.exp[0], I"web")) CM->web_rather_than_module = TRUE;
		else if (Str::eq(mr.exp[0], I"module")) CM->web_rather_than_module = FALSE;
		else {
			CM->web_rather_than_module = FALSE;
			Errors::in_text_file("text before ':' must be 'web' or 'module'", tfp);
		}
		CM->name = Str::duplicate(mr.exp[1]);
		CM->path = Str::duplicate(mr.exp[2]);
		CM->home_leaf = Str::new();
		TEMPORARY_TEXT(weave_path)
		WRITE_TO(weave_path, "%S", mr.exp[3]);
		match_results mr2 = Regexp::create_mr();
		if (Regexp::match(&mr2, weave_path, U"(%c*)/(%c*?.html)")) {
			Str::clear(weave_path);
			Str::copy(weave_path, mr2.exp[0]);
			Str::copy(CM->home_leaf, mr2.exp[1]);
		} else if (Str::suffix_eq(CM->path, I".inweb", 6)) {
			filename *F = Filenames::from_text(CM->path);
			Filenames::write_unextended_leafname(CM->home_leaf, F);
			WRITE_TO(CM->home_leaf, ".html");
		} else {
			WRITE_TO(CM->home_leaf, "index.html");
		}
		Regexp::dispose_of(&mr2);
		CM->weave_path = Pathnames::from_text(weave_path);
		CM->loaded = NULL;
		CM->navigation = crs->nav;
		CM->breadcrumb_tail = crs->crumbs;
		CM->default_weave_pattern = Str::duplicate(crs->pattern);
		ADD_TO_LINKED_LIST(CM, colony_member, C->members);
	} else if (Regexp::match(&mr, line, U"home: *(%c*)")) {
		C->home = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"assets: *(%c*)")) {
		C->assets_path = Pathnames::from_text(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"patterns: *(%c*)")) {
		C->patterns_path = Pathnames::from_text(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"pattern: none")) {
		crs->pattern = NULL;
	} else if (Regexp::match(&mr, line, U"pattern: *(%c*)")) {
		crs->pattern = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"navigation: none")) {
		crs->nav = NULL;
	} else if (Regexp::match(&mr, line, U"navigation: *(%c*)")) {
		crs->nav = Filenames::from_text(mr.exp[0]);
	} else if (Regexp::match(&mr, line, U"breadcrumbs: none")) {
		crs->crumbs = NEW_LINKED_LIST(breadcrumb_request);
	} else if (Regexp::match(&mr, line, U"breadcrumbs: *(%c*)")) {
		crs->crumbs = NEW_LINKED_LIST(breadcrumb_request);
		match_results mr2 = Regexp::create_mr();
		while (Regexp::match(&mr2, mr.exp[0], U"(\"%c*?\") > (%c*)")) {
			Colonies::add_crumb(crs->crumbs, mr2.exp[0], tfp);
			Str::clear(mr.exp[0]); Str::copy(mr.exp[0], mr2.exp[1]);
		}
		Colonies::add_crumb(crs->crumbs, mr.exp[0], tfp);
	} else {
		Errors::in_text_file("unable to read colony member", tfp);
	}
	Regexp::dispose_of(&mr);
}

@ "Breadcrumbs" are the chain of links in a horizontal list at the top of
the page, and this requests one.

=
void Colonies::add_crumb(linked_list *L, text_stream *spec, text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, spec, U"\"(%c*?)\"") == FALSE) {
		Errors::in_text_file("each crumb must be in double-quotes", tfp);
		return;
	}
	spec = mr.exp[0];
	breadcrumb_request *br = Colonies::request_breadcrumb(spec);
	ADD_TO_LINKED_LIST(br, breadcrumb_request, L);
	Regexp::dispose_of(&mr);
}

typedef struct breadcrumb_request {
	struct text_stream *breadcrumb_text;
	struct text_stream *breadcrumb_link;
	CLASS_DEFINITION
} breadcrumb_request;

breadcrumb_request *Colonies::request_breadcrumb(text_stream *arg) {
	breadcrumb_request *BR = CREATE(breadcrumb_request);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, arg, U"(%c*?): *(%c*)")) {
		BR->breadcrumb_text = Str::duplicate(mr.exp[0]);
		BR->breadcrumb_link = Str::duplicate(mr.exp[1]);	
	} else {
		BR->breadcrumb_text = Str::duplicate(arg);
		BR->breadcrumb_link = Str::duplicate(arg);
		WRITE_TO(BR->breadcrumb_link, ".html");
	}
	Regexp::dispose_of(&mr);
	return BR;
}

void Colonies::drop_initial_breadcrumbs(OUTPUT_STREAM, colony *context, filename *F, linked_list *crumbs) {
	breadcrumb_request *BR;
	LOOP_OVER_LINKED_LIST(BR, breadcrumb_request, crumbs) {
		TEMPORARY_TEXT(url)
		Colonies::link_URL(url, context, BR->breadcrumb_link, F);
		Colonies::write_breadcrumb(OUT, BR->breadcrumb_text, url);
		DISCARD_TEXT(url)
	}
}

void Colonies::write_breadcrumb(OUTPUT_STREAM, text_stream *text, text_stream *link) {
	if (link) {
		HTML_OPEN("li");
		HTML::begin_link(OUT, link);
		WRITE("%S", text);
		HTML::end_link(OUT);
		HTML_CLOSE("li");
	} else {
		HTML_OPEN("li");
		HTML_OPEN("b");
		WRITE("%S", text);
		HTML_CLOSE("b");
		HTML_CLOSE("li");
	}
}

@h Searching.
Given a name |T|, we try to find a colony member of that name, returning the
first we find.

=
colony_member *Colonies::find(colony *C, text_stream *T) {
	colony_member *CM;
	if (C)
		LOOP_OVER_LINKED_LIST(CM, colony_member, C->members)
			if (Str::eq_insensitive(T, CM->name))
				return CM;
	return NULL;
}

@ And this is where we find the web metadata for a colony member. It's a more
subtle business than first appears, because maybe the colony member is already
in memory (because it is the web being woven, or is a module imported by that
web even if not now being woven). If it is, we want to use the data we already
have; but if not, we read it in.

=
ls_module *Colonies::as_module(colony_member *CM, ls_line *lst, ls_web *Wm) {
	if (CM->loaded == NULL) @<Perhaps the web being woven@>;
	if (CM->loaded == NULL) @<Perhaps a module imported by the web being woven@>;
	if (CM->loaded == NULL) @<Perhaps a module not yet seen@>;
	if (CM->loaded == NULL) @<Failing that, throw an error@>;
	return CM->loaded->main_module;
}

@<Perhaps the web being woven@> =
	if ((Wm) && (Str::eq_insensitive(Wm->main_module->module_name, CM->name)))
		CM->loaded = Wm;

@<Perhaps a module imported by the web being woven@> =
	if (Wm) {
		ls_module *M;
		LOOP_OVER_LINKED_LIST(M, ls_module, Wm->main_module->dependencies)
			if (Str::eq_insensitive(M->module_name, CM->name))
				CM->loaded = Wm;
	}

@<Perhaps a module not yet seen@> =
	filename *F = NULL;
	pathname *P = NULL;
	
	filename *putative = Filenames::from_text(CM->path);
	pathname *putative_path = Pathnames::from_text(CM->path);
	if (Directories::exists(putative_path)) P = putative_path;
	else if (TextFiles::exists(putative)) F = putative;
	else P = putative_path;
	wcl_declaration *D = WCL::read_web(P, F);
	if (D) CM->loaded = WebStructure::from_declaration(D);

@<Failing that, throw an error@> =
	TEMPORARY_TEXT(err)
	WRITE_TO(err, "unable to load '%S'", CM->name);
	WebErrors::issue_at(err, lst);

@ Finally:

=
text_stream *Colonies::home(void) {
	colony *C;
	LOOP_OVER(C, colony)
		return C->home;
	return I"docs";
}

pathname *Colonies::assets_path(void) {
	colony *C;
	LOOP_OVER(C, colony)
		return C->assets_path;
	return NULL;
}

pathname *Colonies::patterns_path(void) {
	colony *C;
	LOOP_OVER(C, colony)
		return C->patterns_path;
	return NULL;
}

@h Cross-references.
The following must decide what references like the following should refer to:
= (text)
	Chapter 3
	Manual
	Enumerated Constants
	WebRanges::to_section
	weave_order
	foundation: Text Streams
	goldbach
=
The reference text is in |text|; we return |TRUE| if we can make unambiguous
sense of it, or throw an error and return |FALSE| if not. If all is well, we
must write a title and URL for the link.

The web metadata |Wm| is for the web currently being woven, and the line |L|
is where the reference is made from.

=
int Colonies::resolve_reference_in_weave(colony *C, text_stream *url, text_stream *title,
	filename *for_HTML_file, text_stream *text, ls_web *Wm, ls_line *lst, int *ext) {
	int r = 0;
	if (ext) *ext = FALSE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, U"(%c+?) -> (%c+)")) {
		r = Colonies::resolve_reference_in_weave_inner(C, url, NULL,
			for_HTML_file, mr.exp[1], Wm, lst, ext);
		WRITE_TO(title, "%S", mr.exp[0]);
	} else {
		r = Colonies::resolve_reference_in_weave_inner(C, url, title,
			for_HTML_file, text, Wm, lst, ext);
	}
	Regexp::dispose_of(&mr);
	return r;
}

int Colonies::resolve_reference_in_weave_inner(colony *C, text_stream *url, text_stream *title,
	filename *for_HTML_file, text_stream *text, ls_web *Wm, ls_line *lst,
	int *ext) {
	ls_module *from_M = (Wm)?(Wm->main_module):NULL;
	ls_module *search_M = from_M;
	colony_member *search_CM = NULL;
	int external = FALSE;
	
	@<Is it an explicit URL?@>;
	@<Is it the name of a member of our colony?@>;
	@<If it contains a colon, does this indicate a section in a colony member?@>;

	ls_module *found_M = NULL;
	ls_section *found_Sm = NULL;
	int bare_module_name = FALSE;

	/* find how many hits (N), and how many which are sections (NS) */
	int N = WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
		NULL, search_M, text, FALSE, FALSE);
	found_M = NULL; found_Sm = NULL; bare_module_name = FALSE;
	int NS = WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
		NULL, search_M, text, FALSE, TRUE);
	int sections_only = FALSE;
	if ((N > 1) && (NS == 1)) sections_only = TRUE;

	/* now perform the definitive search */
	found_M = NULL; found_Sm = NULL; bare_module_name = FALSE;
	N = WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
		title, search_M, text, FALSE, sections_only);

	if (N == 0) {
		if ((lst) && (external == FALSE)) {
			@<Is it the name of a function in the current web?@>;
			@<Is it the name of a type in the current web?@>;
		}
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "Can't find the cross-reference '%S'", text);
		WebErrors::issue_at(err, lst);
		DISCARD_TEXT(err)
		return FALSE;
	}
	if (N > 1) {
		WebErrors::issue_at(I"Multiple cross-references might be meant here", lst);
		WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
			title, search_M, text, TRUE, FALSE);
		return FALSE;
	}
	@<It refers unambiguously to a single section@>;
	return TRUE;
}

@<Is it an explicit URL?@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, U"https*://%c*")) {
		WRITE_TO(url, "%S", text);
		WRITE_TO(title, "%S", text);
		Regexp::dispose_of(&mr);
		if (ext) *ext = TRUE;
		return TRUE;
	}
	Regexp::dispose_of(&mr);

@<Is it the name of a member of our colony?@> =	
	search_CM = Colonies::find(C, text);
	if (search_CM) {
		ls_module *found_M = Colonies::as_module(search_CM, lst, Wm);
		if (found_M == NULL) internal_error("could not locate M");
		ls_chapter *found_C = FIRST_IN_LINKED_LIST(ls_chapter, found_M->chapters);
		if (found_C == NULL) internal_error("module without chapters");
		ls_section *found_Sm = FIRST_IN_LINKED_LIST(ls_section, found_C->sections);
		if (found_Sm == NULL) internal_error("chapter without sections");
		int bare_module_name = TRUE;
		WRITE_TO(title, "%S", search_CM->name);
		@<It refers unambiguously to a single section@>;
	}

@<If it contains a colon, does this indicate a section in a colony member?@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, U"(%c*?): (%c*)")) {
		search_CM = Colonies::find(C, mr.exp[0]);
		if (search_CM) {
			ls_module *found_M = Colonies::as_module(search_CM, lst, Wm);
			if (found_M) {
				search_M = found_M;
				text = Str::duplicate(mr.exp[1]);
				external = TRUE;
			}
		}
	}
	Regexp::dispose_of(&mr);

@<Is it the name of a function in the current web?@> =
	language_function *fn;
	LOOP_OVER_LINKED_LIST(fn, language_function, CodeAnalysis::language_functions_list(Wm))
		if (Str::eq_insensitive(fn->function_name, text)) {
			Colonies::paragraph_URL(url, Functions::declaration_lsparagraph(fn),
				for_HTML_file, C);
			WRITE_TO(title, "%S", fn->function_name);
			return TRUE;
		}

@<Is it the name of a type in the current web?@> =
	language_type *str;
	LOOP_OVER(str, language_type) {
		if (Str::eq_insensitive(str->structure_name, text)) {
			Colonies::paragraph_URL(url, LiterateSource::par_of_line(str->structure_header_at),
				for_HTML_file, C);
			WRITE_TO(title, "%S", str->structure_name);
			return TRUE;
		}
	}

@<It refers unambiguously to a single section@> =
	if (found_M == NULL) internal_error("could not locate M");
	if (search_CM) @<The section is a known colony member@>
	else @<The section is not in a known colony member@>;
	return TRUE;

@<The section is a known colony member@> =
	pathname *from = Filenames::up(for_HTML_file);
	pathname *to = search_CM->weave_path;
	Pathnames::relative_URL(url, from, to);
	if (bare_module_name) WRITE_TO(url, "%S", search_CM->home_leaf);
	else if (found_Sm) Colonies::section_URL(url, found_Sm); 
	if (bare_module_name == FALSE)
		WRITE_TO(title, " (in %S)", search_CM->name);

@ In the absence of a colony file, we can really only guess, and the guess we
make is that modules of the current web will be woven alongside the main one.

@<The section is not in a known colony member@> =
	if (found_M == from_M) {
		Colonies::section_URL(url, found_Sm);
	} else {
		WRITE_TO(url, "../%S-module/", found_M->module_name);
		Colonies::section_URL(url, found_Sm); 
		if (bare_module_name == FALSE)
			WRITE_TO(title, " (in %S)", found_M->module_name);
	}

@h URL management.

=
void Colonies::link_URL(OUTPUT_STREAM, colony *context, text_stream *link_text, filename *F) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, link_text, U" *//(%c+)// *"))
		Colonies::reference_URL(OUT, context, mr.exp[0], F);
	else
		WRITE("%S", link_text);
	Regexp::dispose_of(&mr);
}

void Colonies::reference_URL(OUTPUT_STREAM, colony *context, text_stream *link_text, filename *F) {
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(url)
	if (Colonies::resolve_reference_in_weave(context, url, title, F, link_text, NULL, NULL, NULL))
		WRITE("%S", url);
	else
		PRINT("Warning: unable to resolve reference '%S' in navigation\n", link_text);
	DISCARD_TEXT(title)
	DISCARD_TEXT(url)
}

void Colonies::section_URL(OUTPUT_STREAM, ls_section *S) {
	if (S == NULL) internal_error("unwoven section");
	filename *F = WeavingDetails::get_section_weave_to(S);
	if (F) {
		WRITE("%S", Filenames::get_leafname(F));
	} else {
		LOOP_THROUGH_TEXT(pos, WebRanges::of(S))
			if ((Str::get(pos) == '/') || (Str::get(pos) == ' '))
				PUT('-');
			else
				PUT(Str::get(pos));
		WRITE(".html");
	}
}

void Colonies::paragraph_URL(OUTPUT_STREAM, ls_paragraph *par, filename *from, colony *context) {
	if (from == NULL) internal_error("no from file");
	if (par == NULL) internal_error("no para");
	ls_section *to_S = LiterateSource::section_of_par(par);
	ls_module *to_M = to_S->owning_chapter->owning_module;
	if (Str::ne(to_M->module_name, I"(main)")) {
		colony_member *to_C = Colonies::find(context, to_M->module_name);
		if (to_C) {
			pathname *from_path = Filenames::up(from);
			pathname *to_path = to_C->weave_path;
			Pathnames::relative_URL(OUT, from_path, to_path);
		} else {
			PRINT("Warning: a link in the weave will work only if '%S' appears in the colony file\n",
				to_M->module_name);
		}
	}
	Colonies::section_URL(OUT, to_S);
	WRITE("#");
	Colonies::paragraph_anchor(OUT, par);
}

void Colonies::paragraph_anchor(OUTPUT_STREAM, ls_paragraph *par) {
	if (par == NULL) internal_error("no para");
	WRITE("%S", LiterateSource::par_ornament(par));
	WRITE("P");
	text_stream *N = par->paragraph_number;
	LOOP_THROUGH_TEXT(pos, N)
		if (Str::get(pos) == '.') WRITE("_");
		else PUT(Str::get(pos));
}
