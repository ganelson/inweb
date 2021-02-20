[Colonies::] Colonies.

Cross-referencing multiple webs gathered together.

@h Colonies of webs.
Social spiders are said to form "colonies" when their webs are shared,[1] and
in that spirit, a colony to Inweb is a collection of coexisting webs -- which
share no code, and in that sense have no connection at run-time, but which
need to be cross-referenced in their woven form, so that readers can easily
turn from one to another.

[1] Those curious to see what a colony of 110,000,000 spiders might be like
to walk through should see Albert Greene et al., "An Immense Concentration of
Orb-Weaving Spiders With Communal Webbing in a Man-Made Structural Habitat
(Arachnida: Araneae: Tetragnathidae, Araneidae)", American Entomologist
(Fall 2010), at: https://www.entsoc.org/PDF/2010/Orb-weaving-spiders.pdf

@ So, then, a colony is really just a membership list:

=
typedef struct colony {
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
	int web_rather_than_module; /* |TRUE| for a web, |FALSE| for a module */
	struct text_stream *name; /* the |N| in |N at P in W| */
	struct text_stream *path; /* the |P| in |N at P in W| */
	struct pathname *weave_path; /* the |W| in |N at P in W| */
	struct text_stream *home_leaf; /* usually |index.html|, but not for single-file webs */
	struct text_stream *default_weave_pattern; /* for use when weaving */
	
	struct web_md *loaded; /* metadata on its sections, lazily evaluated */
	struct filename *navigation; /* navigation sidebar HTML */
	struct linked_list *breadcrumb_tail; /* of |breadcrumb_request| */
	CLASS_DEFINITION
} colony_member;

@ And the following reads a colony file |F| and produces a suitable |colony|
object from it. This, for example, is the colony file for the Inweb repository
at GitHub:
= (text from Figures/colony.txt)

=
typedef struct colony_reader_state {
	struct colony *province;
	struct filename *nav;
	struct linked_list *crumbs; /* of |breadcrumb_request| */
	struct text_stream *pattern;
} colony_reader_state;

void Colonies::load(filename *F) {
	colony *C = CREATE(colony);
	C->members = NEW_LINKED_LIST(colony_member);
	C->home = I"docs";
	C->assets_path = NULL;
	C->patterns_path = NULL;
	colony_reader_state crs;
	crs.province = C;
	crs.nav = NULL;
	crs.crumbs = NEW_LINKED_LIST(breadcrumb_request);
	crs.pattern = NULL;
	TextFiles::read(F, FALSE, "can't open colony file",
		TRUE, Colonies::read_line, NULL, (void *) &crs);
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
	if (Regexp::match(&mr, line, L"(%c*?): \"*(%C+)\" at \"(%c*)\" in \"(%c*)\"")) {
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
		if (Str::suffix_eq(CM->path, I".inweb", 6)) {
			filename *F = Filenames::from_text(CM->path);
			Filenames::write_unextended_leafname(CM->home_leaf, F);
			WRITE_TO(CM->home_leaf, ".html");
		} else {
			WRITE_TO(CM->home_leaf, "index.html");
		}
		CM->weave_path = Pathnames::from_text(mr.exp[3]);
		CM->loaded = NULL;
		CM->navigation = crs->nav;
		CM->breadcrumb_tail = crs->crumbs;
		CM->default_weave_pattern = Str::duplicate(crs->pattern);
		ADD_TO_LINKED_LIST(CM, colony_member, C->members);
	} else if (Regexp::match(&mr, line, L"home: *(%c*)")) {
		C->home = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, L"assets: *(%c*)")) {
		C->assets_path = Pathnames::from_text(mr.exp[0]);
	} else if (Regexp::match(&mr, line, L"patterns: *(%c*)")) {
		C->patterns_path = Pathnames::from_text(mr.exp[0]);
	} else if (Regexp::match(&mr, line, L"pattern: none")) {
		crs->pattern = NULL;
	} else if (Regexp::match(&mr, line, L"pattern: *(%c*)")) {
		crs->pattern = Str::duplicate(mr.exp[0]);
	} else if (Regexp::match(&mr, line, L"navigation: none")) {
		crs->nav = NULL;
	} else if (Regexp::match(&mr, line, L"navigation: *(%c*)")) {
		crs->nav = Filenames::from_text(mr.exp[0]);
	} else if (Regexp::match(&mr, line, L"breadcrumbs: none")) {
		crs->crumbs = NEW_LINKED_LIST(breadcrumb_request);
	} else if (Regexp::match(&mr, line, L"breadcrumbs: *(%c*)")) {
		crs->crumbs = NEW_LINKED_LIST(breadcrumb_request);
		match_results mr2 = Regexp::create_mr();
		while (Regexp::match(&mr2, mr.exp[0], L"(\"%c*?\") > (%c*)")) {
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
	if (Regexp::match(&mr, spec, L"\"(%c*?)\"") == FALSE) {
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
	if (Regexp::match(&mr, arg, L"(%c*?): *(%c*)")) {
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

void Colonies::drop_initial_breadcrumbs(OUTPUT_STREAM, filename *F, linked_list *crumbs) {
	breadcrumb_request *BR;
	LOOP_OVER_LINKED_LIST(BR, breadcrumb_request, crumbs) {
		TEMPORARY_TEXT(url)
		Colonies::link_URL(url, BR->breadcrumb_link, F);
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
colony_member *Colonies::find(text_stream *T) {
	colony *C;
	LOOP_OVER(C, colony) {
		colony_member *CM;
		LOOP_OVER_LINKED_LIST(CM, colony_member, C->members)
			if (Str::eq_insensitive(T, CM->name))
				return CM;
	}
	return NULL;
}

@ And this is where we find the web metadata for a colony member. It's a
more subtle business than first appears, because maybe the colony member is
already in Inweb's memory (because it is the web being woven, or is a module
imported by that web even if not now being woven). If it is, we want to use
the data we already have; but if not, we read it in.

=
module *Colonies::as_module(colony_member *CM, source_line *L, web_md *Wm) {
	if (CM->loaded == NULL) @<Perhaps the web being woven@>;
	if (CM->loaded == NULL) @<Perhaps a module imported by the web being woven@>;
	if (CM->loaded == NULL) @<Perhaps a module not yet seen@>;
	if (CM->loaded == NULL) @<Failing that, throw an error@>;
	return CM->loaded->as_module;
}

@<Perhaps the web being woven@> =
	if ((Wm) && (Str::eq_insensitive(Wm->as_module->module_name, CM->name)))
		CM->loaded = Wm;

@<Perhaps a module imported by the web being woven@> =
	if (Wm) {
		module *M;
		LOOP_OVER_LINKED_LIST(M, module, Wm->as_module->dependencies)
			if (Str::eq_insensitive(M->module_name, CM->name))
				CM->loaded = Wm;
	}

@<Perhaps a module not yet seen@> =
	filename *F = NULL;
	pathname *P = NULL;
	if (Str::suffix_eq(CM->path, I".inweb", 6))
		F = Filenames::from_text(CM->path);
	else
		P = Pathnames::from_text(CM->path);
	CM->loaded = WebMetadata::get_without_modules(P, F);

@<Failing that, throw an error@> =
	TEMPORARY_TEXT(err)
	WRITE_TO(err, "unable to load '%S'", CM->name);
	Main::error_in_web(err, L);

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
	Reader::get_section_for_range
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
int Colonies::resolve_reference_in_weave(text_stream *url, text_stream *title,
	filename *for_HTML_file, text_stream *text, web_md *Wm, source_line *L, int *ext) {
	int r = 0;
	if (ext) *ext = FALSE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L"(%c+?) -> (%c+)")) {
		r = Colonies::resolve_reference_in_weave_inner(url, NULL,
			for_HTML_file, mr.exp[1], Wm, L, ext);
		WRITE_TO(title, "%S", mr.exp[0]);
	} else {
		r = Colonies::resolve_reference_in_weave_inner(url, title,
			for_HTML_file, text, Wm, L, ext);
	}
	Regexp::dispose_of(&mr);
	return r;
}

int Colonies::resolve_reference_in_weave_inner(text_stream *url, text_stream *title,
	filename *for_HTML_file, text_stream *text, web_md *Wm, source_line *L, int *ext) {
	module *from_M = (Wm)?(Wm->as_module):NULL;
	module *search_M = from_M;
	colony_member *search_CM = NULL;
	int external = FALSE;
	
	@<Is it an explicit URL?@>;
	@<Is it the name of a member of our colony?@>;
	@<If it contains a colon, does this indicate a section in a colony member?@>;

	module *found_M = NULL;
	section_md *found_Sm = NULL;
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
		if ((L) && (external == FALSE)) {
			@<Is it the name of a function in the current web?@>;
			@<Is it the name of a type in the current web?@>;
		}
		TEMPORARY_TEXT(err)
		WRITE_TO(err, "Can't find the cross-reference '%S'", text);
		Main::error_in_web(err, L);
		DISCARD_TEXT(err)
		return FALSE;
	}
	if (N > 1) {
		Main::error_in_web(I"Multiple cross-references might be meant here", L);
		WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
			title, search_M, text, TRUE, FALSE);
		return FALSE;
	}
	@<It refers unambiguously to a single section@>;
	return TRUE;
}

@<Is it an explicit URL?@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L"https*://%c*")) {
		WRITE_TO(url, "%S", text);
		WRITE_TO(title, "%S", text);
		Regexp::dispose_of(&mr);
		if (ext) *ext = TRUE;
		return TRUE;
	}
	Regexp::dispose_of(&mr);

@<Is it the name of a member of our colony?@> =	
	search_CM = Colonies::find(text);
	if (search_CM) {
		module *found_M = Colonies::as_module(search_CM, L, Wm);
		section_md *found_Sm = FIRST_IN_LINKED_LIST(section_md, found_M->sections_md);
		int bare_module_name = TRUE;
		WRITE_TO(title, "%S", search_CM->name);
		@<It refers unambiguously to a single section@>;
	}

@<If it contains a colon, does this indicate a section in a colony member?@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, text, L"(%c*?): (%c*)")) {
		search_CM = Colonies::find(mr.exp[0]);
		if (search_CM) {
			module *found_M = Colonies::as_module(search_CM, L, Wm);
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
	LOOP_OVER(fn, language_function) {
		if (Str::eq_insensitive(fn->function_name, text)) {
			Colonies::paragraph_URL(url, fn->function_header_at->owning_paragraph,
				for_HTML_file);
			WRITE_TO(title, "%S", fn->function_name);
			return TRUE;
		}
	}

@<Is it the name of a type in the current web?@> =
	language_type *str;
	LOOP_OVER(str, language_type) {
		if (Str::eq_insensitive(str->structure_name, text)) {
			Colonies::paragraph_URL(url, str->structure_header_at->owning_paragraph,
				for_HTML_file);
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

@ In the absence of a colony file, Inweb can really only guess, and the
guess it makes is that modules of the current web will be woven alongside
the main one.

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
void Colonies::link_URL(OUTPUT_STREAM, text_stream *link_text, filename *F) {
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, link_text, L" *//(%c+)// *"))
		Colonies::reference_URL(OUT, mr.exp[0], F);
	else
		WRITE("%S", link_text);
	Regexp::dispose_of(&mr);
}

void Colonies::reference_URL(OUTPUT_STREAM, text_stream *link_text, filename *F) {
	TEMPORARY_TEXT(title)
	TEMPORARY_TEXT(url)
	if (Colonies::resolve_reference_in_weave(url, title, F, link_text, NULL, NULL, NULL))
		WRITE("%S", url);
	else
		PRINT("Warning: unable to resolve reference '%S' in navigation\n", link_text);
	DISCARD_TEXT(title)
	DISCARD_TEXT(url)
}

void Colonies::section_URL(OUTPUT_STREAM, section_md *Sm) {
	if (Sm == NULL) internal_error("unwoven section");
	LOOP_THROUGH_TEXT(pos, Sm->sect_range)
		if ((Str::get(pos) == '/') || (Str::get(pos) == ' '))
			PUT('-');
		else
			PUT(Str::get(pos));
	WRITE(".html");
}

void Colonies::paragraph_URL(OUTPUT_STREAM, paragraph *P, filename *from) {
	if (from == NULL) internal_error("no from file");
	if (P == NULL) internal_error("no para");
	section *to_S = P->under_section;
	module *to_M = to_S->md->owning_module;
	if (Str::ne(to_M->module_name, I"(main)")) {
		colony_member *to_C = Colonies::find(to_M->module_name);
		if (to_C) {
			pathname *from_path = Filenames::up(from);
			pathname *to_path = to_C->weave_path;
			Pathnames::relative_URL(OUT, from_path, to_path);
		} else {
			PRINT("Warning: a link in the weave will work only if '%S' appears in the colony file\n",
				to_M->module_name);
		}
	}
	Colonies::section_URL(OUT, to_S->md);
	WRITE("#");
	Colonies::paragraph_anchor(OUT, P);
}

void Colonies::paragraph_anchor(OUTPUT_STREAM, paragraph *P) {
	if (P == NULL) internal_error("no para");
	WRITE("%S", P->ornament);
	WRITE("P");
	text_stream *N = P->paragraph_number;
	LOOP_THROUGH_TEXT(pos, N)
		if (Str::get(pos) == '.') WRITE("_");
		else PUT(Str::get(pos));
}
