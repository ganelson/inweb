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
	struct text_stream *assets_path; /* where assets shared between weaves live */
	struct pathname *patterns_path; /* where additional patterns live */
	CLASS_DEFINITION
} colony;

@ Each member is represented by an instance of the following. Note the |loaded|
field: this holds metadata on the web/module in question.

Note that the |path| might be either the name of a single-file web, or of a
directory holding a multi-section web.

=
typedef struct colony_member {
	struct colony *owner;

	struct text_stream *name; /* the |N| in |N at P in W| */
	struct text_stream *path; /* the |P| in |N at P in W| */
	struct text_stream *weave_path; /* the |W| in |N at P in W| */
	struct text_stream *home_leaf; /* usually |index.html|, but not for single-file webs */
	struct text_stream *default_weave_pattern; /* for use when weaving */
	int external; /* belongs to another colony, really */

	struct wcl_declaration *internal_declaration; /* for a member defined within the Colony declaration */
	struct ls_web *loaded; /* metadata on its sections, lazily evaluated */
	struct text_stream *navigation_name; /* navigation sidebar HTML */
	struct wcl_declaration *navigation; /* navigation sidebar HTML */
	struct text_stream *crumbs; /* textual form of breadcrumbs */
	struct linked_list *breadcrumb_tail; /* of |breadcrumb_request| */
	CLASS_DEFINITION
} colony_member;

colony_member *Colonies::new_member(text_stream *name, colony *C, int ext) {
	colony_member *CM = CREATE(colony_member);
	CM->owner = C;
	CM->name = Str::duplicate(name);
	CM->path = Str::new();
	CM->internal_declaration = NULL;
	CM->weave_path = NULL;
	CM->home_leaf = Str::new();
	CM->default_weave_pattern = Str::new();
	CM->external = ext;
	
	CM->loaded = NULL;
	CM->navigation_name = NULL;
	CM->navigation = NULL;
	CM->crumbs = NULL;
	CM->breadcrumb_tail = NEW_LINKED_LIST(breadcrumb_request);

	ADD_TO_LINKED_LIST(CM, colony_member, C->members);
	return CM;
}

@ This is deceptively tricky. Our problem is to take a web and find the colony
to which it belongs. But internally there may be no obvious link between the
two, and indeed, the web might be a member of multiple colonies. So we interpret
this as finding the earliest-loaded colony which has a member whose location
in the file system matches the location of the web.

=
colony_member *Colonies::find_colony_member(ls_web *W) {
	colony *C;
	LOOP_OVER(C, colony) {
		colony_member *CM;
		LOOP_OVER_LINKED_LIST(CM, colony_member, C->members) {
			if (CM->loaded == W) return CM;
			if (CM->internal_declaration) {
				ls_web *CMW = RETRIEVE_POINTER_ls_web(CM->internal_declaration->object_declared);
				if (CMW == W) {
					CM->loaded = W;
					return CM;
				}
			} else {
				filename *F = Filenames::from_text(CM->path);
				if (((W->single_file) && (Filenames::eq_insensitive(W->single_file, F))) ||
					((W->contents_filename) && (Filenames::eq_insensitive(W->contents_filename, F)))) {
					CM->loaded = W;
					return CM;
				}
			}
		}
	}
	return NULL;
}

void Colonies::fully_load(colony *C) {
	colony_member *CM;
	LOOP_OVER_LINKED_LIST(CM, colony_member, C->members)
		Colonies::fully_load_member(CM);
}

void Colonies::fully_load_member(colony_member *CM) {
	if (CM->loaded == NULL) {
		if (CM->internal_declaration) {
			ls_web *CMW = RETRIEVE_POINTER_ls_web(CM->internal_declaration->object_declared);
			CM->loaded = CMW;
		} else {
			filename *F = Filenames::from_text(CM->path);
			pathname *P = NULL;
			if (TextFiles::exists(F) == FALSE) P = Pathnames::from_text(CM->path);
			wcl_declaration *D = WCL::read_web(P, F);
			if (D) CM->loaded = RETRIEVE_POINTER_ls_web(D->object_declared);
		}
	}
}

void Colonies::fully_load_contents(OUTPUT_STREAM, colony *C) {
	Colonies::fully_load(C);
	WRITE("loading full literate source of all colony members: ");
	colony_member *CM;
	int n = 0;
	LOOP_OVER_LINKED_LIST(CM, colony_member, C->members) {
		n++;
		if (n > 1) WRITE(" ");
		WRITE("[%d]", n);
		STREAM_FLUSH(OUT);
		WebStructure::read_fully(C, CM->loaded->declaration, FALSE, TRUE, FALSE);
	}
	WRITE("\n");
}

@ Here we parse member declaration lines from colony declarations.

=
void Colonies::website_feature(colony *C, text_stream *feature, text_stream *value) {
	if (Str::eq(feature, I"home")) {
		C->home = Str::new();
		Colonies::expand_relative_path(C->home, value, C);
	} else if (Str::eq(feature, I"assets")) {
		C->assets_path = Str::duplicate(value);
	} else {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "no such feature as '%S' in declaration of website", feature);
		Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
	}
}

void Colonies::website_features(colony *C, text_stream *features, text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, features, U" *(%C+) \"(%c*?)\" *(%c*)")) {
		Colonies::website_feature(C, mr.exp[0], mr.exp[1]);
		Str::clear(features);
		Str::copy(features, mr.exp[2]);
	}
	if (Str::is_whitespace(features) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "unrecognised matter '%S' in declaration of website", features);
		Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
	}
	Regexp::dispose_of(&mr);
}

void Colonies::member_feature(colony_member *CM, text_stream *feature, text_stream *value) {
	if (Str::eq(feature, I"at")) {
		Colonies::expand_relative_path(CM->path, value, CM->owner);
	} else if (Str::eq(feature, I"pattern")) {
		Str::clear(CM->default_weave_pattern);
		Str::copy(CM->default_weave_pattern, value);
	} else if (Str::eq(feature, I"navigation")) {
		CM->navigation_name = Str::duplicate(value);
	} else if (Str::eq(feature, I"breadcrumbs")) {
		CM->crumbs = Str::duplicate(value);
	} else if (Str::eq(feature, I"to")) {
		Str::clear(CM->home_leaf);
		CM->weave_path = Str::new();
		WRITE_TO(CM->weave_path, "%S", value);
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, CM->weave_path, U"(%c*)/(%c*?.%C+?)")) {
			Str::clear(CM->weave_path);
			Str::copy(CM->weave_path, mr.exp[0]);
			Str::copy(CM->home_leaf, mr.exp[1]);
		} else if (Regexp::match(&mr, CM->weave_path, U"(%c*?.%C+?)")) {
			Str::clear(CM->weave_path);
			Str::copy(CM->home_leaf, mr.exp[0]);
		}
		Regexp::dispose_of(&mr);
	} else {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "no such feature as '%S' in declaration of colony member '%S'",
			feature, CM->name);
		Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
	}
}

void Colonies::member_features(colony_member *CM, text_stream *features,
	colony_reader_state *crs, text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, features, U" *(%C+) \"(%c*?)\" *(%c*)")) {
		Colonies::member_feature(CM, mr.exp[0], mr.exp[1]);
		Str::clear(features);
		Str::copy(features, mr.exp[2]);
	}
	if (Str::is_whitespace(features) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "unrecognised matter '%S' in declaration of colony member '%S'",
			features, CM->name);
		Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
	}
	Regexp::dispose_of(&mr);
	Colonies::member_complete(CM, crs, tfp);
}

void Colonies::default_feature(text_stream *feature, text_stream *value, colony_reader_state *crs) {
	if (Str::eq(feature, I"at")) {
		Errors::fatal("'at' cannot be set in the default settings");
	} else if (Str::eq(feature, I"pattern")) {
		crs->pattern = Str::duplicate(value);
	} else if (Str::eq(feature, I"navigation")) {
		crs->nav = Str::duplicate(value);
	} else if (Str::eq(feature, I"breadcrumbs")) {
		crs->crumbs = Str::duplicate(value);
	} else if (Str::eq(feature, I"to")) {
		Errors::fatal("'to' cannot be set in the default settings");
	} else {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "no such feature as '%S' the default settings", feature);
		Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
	}
}

void Colonies::default_features(text_stream *features, colony_reader_state *crs, text_file_position *tfp) {
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, features, U" *(%C+) \"(%c*?)\" *(%c*)")) {
		Colonies::default_feature(mr.exp[0], mr.exp[1], crs);
		Str::clear(features);
		Str::copy(features, mr.exp[2]);
	}
	if (Str::is_whitespace(features) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "unrecognised matter '%S' in declaration of default settings",
			features);
		Errors::fatal_with_text("%S", msg);
		DISCARD_TEXT(msg)
	}
	Regexp::dispose_of(&mr);
}

void Colonies::member_complete(colony_member *CM, colony_reader_state *crs, text_file_position *tfp) {
	wcl_declaration *X;
	LOOP_OVER_LINKED_LIST(X, wcl_declaration, CM->owner->declaration->declarations)
		if (X->declaration_type == WEB_WCLTYPE)
			if (Str::eq_insensitive(X->name, CM->name)) {
				CM->internal_declaration = X;
				if (Str::len(CM->path) > 0)
					Errors::with_text("colony member %S is defined inside the Colony declaration, so cannot be 'at' anywhere", CM->name);
				break;
			}

	if ((CM->internal_declaration == NULL) && (Str::len(CM->path) == 0)) {
		TEMPORARY_TEXT(at)
		WRITE_TO(at, "%S.inwebc", CM->name);
		Colonies::member_feature(CM, I"at", at);
		DISCARD_TEXT(at)
	}
	
	if (CM->weave_path == NULL) {
		TEMPORARY_TEXT(to)
		WRITE_TO(to, "%S", CM->name);
		Colonies::member_feature(CM, I"to", to);
		DISCARD_TEXT(to)
	}

	filename *F = NULL;
	pathname *P = NULL;
	if (CM->internal_declaration == NULL) {
		F = Filenames::from_text(CM->path);
		P = Pathnames::from_text(CM->path);
		if (TextFiles::exists(F)) P = NULL;
		else if (Directories::exists(P)) F = NULL;
		else Errors::with_text("colony member not found at %S", CM->path);
	}

	if (Str::len(CM->home_leaf) == 0) {
		if (CM->internal_declaration) {
			CM->home_leaf = Str::duplicate(I"index.html");
		} else {
			if (F) {
				Str::clear(CM->home_leaf);
				Filenames::write_unextended_leafname(CM->home_leaf, F);
				WRITE_TO(CM->home_leaf, ".html");
			} else {
				CM->home_leaf = Str::duplicate(I"index.html");
			}
		}
	}

	if (Str::len(CM->default_weave_pattern) == 0)
		CM->default_weave_pattern = Str::duplicate(crs->pattern);
	if ((Str::len(CM->navigation_name) == 0) && (Str::len(crs->nav) > 0))
		CM->navigation_name = Str::duplicate(crs->nav);

	match_results mr2 = Regexp::create_mr();
	TEMPORARY_TEXT(bc)
	if (CM->crumbs == NULL) CM->crumbs = Str::duplicate(crs->crumbs);
	WRITE_TO(bc, "%S", CM->crumbs);
	while (Regexp::match(&mr2, bc, U"(%c*?) > (%c*)")) {
		Colonies::add_crumb(CM->breadcrumb_tail, mr2.exp[0], tfp);
		Str::clear(bc); Str::copy(bc, mr2.exp[1]);
	}
	Colonies::add_crumb(CM->breadcrumb_tail, bc, tfp);
	DISCARD_TEXT(bc)
}

@ And the following reads a colony file |F| and produces a suitable |colony|
object from it.

=
typedef struct colony_reader_state {
	struct wcl_declaration *D;
	struct colony *province;
	struct text_stream *nav;
	struct text_stream *crumbs; /* of |breadcrumb_request| */
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
	C->home = Str::new();
	Colonies::expand_relative_path(C->home, I"docs", C);
	C->assets_path = NULL;
	C->patterns_path = NULL;
	colony_reader_state crs;
	crs.D = D;
	crs.province = C;
	crs.nav = NULL;
	crs.crumbs = NULL;
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
	colony *C = RETRIEVE_POINTER_colony(D->object_declared);
	colony_member *CM;
	LOOP_OVER_LINKED_LIST(CM, colony_member, C->members) {
		if (CM->navigation == NULL) {
			wcl_declaration *N = WCL::resolve_resource(D, NAVIGATION_WCLTYPE, CM->navigation_name);
			if (N) {
				CM->navigation = N;
				CM->navigation_name = Str::duplicate(N->name);
			} else if (Str::len(CM->navigation_name) > 0) {
				TEMPORARY_TEXT(msg)
				WRITE_TO(msg, "web needs a navigation element called '%S', but I can't find any declaration of this",
					CM->navigation_name);
				WCL::error(D, &(D->declaration_position), msg);
				DISCARD_TEXT(msg)
			}
		}
		if (CM->internal_declaration)
			Colonies::fully_load_member(CM);
	}
	if (C->assets_path == NULL) Colonies::website_feature(C, I"assets", I"docs-assets");
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
	if (Regexp::match(&mr, line, U"to: \"*(%C+)\" *(%c*)")) {
		Colonies::website_feature(C, I"home", mr.exp[0]);
		Colonies::website_features(C, mr.exp[1], tfp);
	} else if (Regexp::match(&mr, line, U"member: \"*(%C+)\" *(%c*)")) {
		colony_member *CM = Colonies::new_member(mr.exp[0], C, FALSE);
		Colonies::member_features(CM, mr.exp[1], crs, tfp);
	} else if (Regexp::match(&mr, line, U"external: \"*(%C+)\" *(%c*)")) {
		colony_member *CM = Colonies::new_member(mr.exp[0], C, TRUE);
		Colonies::member_features(CM, mr.exp[1], crs, tfp);
	} else if (Regexp::match(&mr, line, U"default: *(%c*)")) {
		Colonies::default_features(mr.exp[0], crs, tfp);
	} else if (Regexp::match(&mr, line, U"patterns: *(%c*)")) {
		TEMPORARY_TEXT(path)
		Colonies::expand_relative_path(path, mr.exp[0], C);
		C->patterns_path = Pathnames::from_text(path);
		DISCARD_TEXT(path)
	} else {
		Errors::in_text_file("unable to read colony member", tfp);
	}
	Regexp::dispose_of(&mr);
}

pathname *Colonies::base_pathname(colony *C) {
	pathname *P = NULL;
	filename *F = NULL;
	if (C) {
		P = C->declaration->associated_path;
		F = C->declaration->associated_file;
	}
	if ((P == NULL) && (F)) P = Filenames::up(F);
	return P;
}

void Colonies::expand_relative_path(OUTPUT_STREAM, text_stream *from, colony *C) {
	Colonies::expand_relative_path_to(OUT, from, C, Colonies::base_pathname(C));
}

void Colonies::expand_relative_path_to(OUTPUT_STREAM, text_stream *from, colony *C, pathname *P) {
	if (Str::len(from) == 0) {
		WRITE("%p", P);
		return;
	}
	while ((Str::begins_with(from, I"../")) &&
		(Str::ne(Pathnames::directory_name(P), I".")) &&
		(Str::ne(Pathnames::directory_name(P), I"..")) &&
		(Str::len(Pathnames::directory_name(P)) > 0)) {
		P = Pathnames::up(P);
		Str::delete_first_character(from);
		Str::delete_first_character(from);
		Str::delete_first_character(from);
	}
	TEMPORARY_TEXT(route)
	if (P) WRITE_TO(route, "%p", P);
	if (Str::len(route) > 0) WRITE_TO(route, "/");
	WRITE("%S%S", route, from);
	DISCARD_TEXT(route)
}

@ "Breadcrumbs" are the chain of links in a horizontal list at the top of
the page, and this requests one.

=
void Colonies::add_crumb(linked_list *L, text_stream *spec, text_file_position *tfp) {
	breadcrumb_request *br = Colonies::request_breadcrumb(spec);
	ADD_TO_LINKED_LIST(br, breadcrumb_request, L);
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

@h Navigation sidebars.
For the moment, at least, these require no parsing.

=
void Colonies::parse_nav_declaration(wcl_declaration *D) {
}

void Colonies::resolve_nav_declaration(wcl_declaration *D) {
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
	if (CM->loaded == NULL) @<Perhaps a web not yet loaded@>;
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

@<Perhaps a web not yet loaded@> =
	Colonies::fully_load_member(CM);

@<Failing that, throw an error@> =
	TEMPORARY_TEXT(err)
	WRITE_TO(err, "unable to load '%S'", CM->name);
	WebErrors::issue_at(err, lst);

@ Finally:

=
pathname *Colonies::home(colony *C) {
	if (C) return Pathnames::from_text(C->home);
	return Pathnames::from_text(I"docs");
}

pathname *Colonies::assets_path(colony *C) {
	if (C) {
		TEMPORARY_TEXT(path)
		Colonies::expand_relative_path_to(path, C->assets_path, C, Colonies::home(C));
		pathname *P = Pathnames::from_text(path);
		DISCARD_TEXT(path)
		return P;
	}
	return Pathnames::down(Colonies::home(C), I"docs-assets");
}

pathname *Colonies::weave_path(colony_member *CM) {
	colony *C = CM->owner;
	TEMPORARY_TEXT(path)
	Colonies::expand_relative_path_to(path, CM->weave_path, C, Colonies::home(C));
	pathname *P = Pathnames::from_text(path);
	DISCARD_TEXT(path)
	return P;
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
int Colonies::resolve_reference_in_weave_order(weave_order *wv,
	text_stream *url, text_stream *title, text_stream *text, int *ext) {
	return Colonies::resolve_reference_in_weave((wv)?wv->weave_colony:NULL,
		url, title, (wv)?wv->weave_to:NULL, text,
		(wv)?wv->weave_web:NULL, (wv)?wv->current_weave_line:NULL, ext);
}

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
	pathname *to = Colonies::weave_path(search_CM);
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
			pathname *to_path = Colonies::weave_path(to_C);
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

void Colonies::write_map(OUTPUT_STREAM, colony *C, int fully) {
	if (C == NULL) { WRITE("<no colony>\n"); return; }
	WRITE("colony declared in the file: %f\nweave output to the directory: %S\n\n",
		C->declaration->associated_file, C->home);
	linked_list *L = C->members;
	int N = LinkedLists::len(L);
	if (N == 0) { WRITE("Colony has no members, and does not generate a website\n"); return; }
	Colonies::fully_load(C);
	@<Tabulate the locations@>;
	if (fully) { Colonies::fully_load_contents(OUT, C); WRITE("\n"); }
	@<Tabulate the details@>;
	@<Tabulate the site map@>;
}

@<Tabulate the locations@> =
	textual_table *T = TextualTables::new_table();
	WRITE_TO(TextualTables::next_cell(T), "member");
	WRITE_TO(TextualTables::next_cell(T), "type");
	WRITE_TO(TextualTables::next_cell(T), "source location");
	colony_member *CM;
	LOOP_OVER_LINKED_LIST(CM, colony_member, L) {
		ls_web *W = CM->loaded;
		if (CM->loaded == NULL) Errors::fatal_with_text("Could not load colony member '%S'", CM->name);
		TextualTables::begin_row(T);
		WRITE_TO(TextualTables::next_cell(T), "%S", CM->name);
		if (CM->external) {
			if (W->is_page) {
				WRITE_TO(TextualTables::next_cell(T), "x page");
			} else {
				WRITE_TO(TextualTables::next_cell(T), "x book");
			}
		} else {
			if (W->is_page) {
				WRITE_TO(TextualTables::next_cell(T), "page");
			} else {
				WRITE_TO(TextualTables::next_cell(T), "book");
			}
		}
		if (CM->internal_declaration) {
			if (W->declaration->modifier == PAGE_WCLMODIFIER)
				WRITE_TO(TextualTables::next_cell(T), "(material in Colony file)");
			else
				WRITE_TO(TextualTables::next_cell(T), "(contents list in Colony file)");
		} else {
			WRITE_TO(TextualTables::next_cell(T), "%S", CM->path);
		}
	}
	TextualTables::tabulate_sorted(OUT, T, 1);
	WRITE("\n");

@<Tabulate the details@> =
	textual_table *T = TextualTables::new_table();
	WRITE_TO(TextualTables::next_cell(T), "member");
	WRITE_TO(TextualTables::next_cell(T), "notation");
	WRITE_TO(TextualTables::next_cell(T), "language");
	WRITE_TO(TextualTables::next_cell(T), "modules");
	WRITE_TO(TextualTables::next_cell(T), "chapters");
	WRITE_TO(TextualTables::next_cell(T), "sections");
	if (fully) WRITE_TO(TextualTables::next_cell(T), "paragraphs");
	if (fully) WRITE_TO(TextualTables::next_cell(T), "lines");
	int tcc = 0, tsc = 0, tpc = 0, tlc = 0, tm = 0;
	colony_member *CM;
	LOOP_OVER_LINKED_LIST(CM, colony_member, L) {
		tm++;
		ls_web *W = CM->loaded;
		TextualTables::begin_row(T);
		WRITE_TO(TextualTables::next_cell(T), "%s%S", (W->is_page)?"*":"", CM->name);
		WRITE_TO(TextualTables::next_cell(T), "%S", W->web_syntax->name);
		WRITE_TO(TextualTables::next_cell(T), "%S", W->web_language->language_name);
		WRITE_TO(TextualTables::next_cell(T), "%d", WebModules::no_dependencies(W->main_module));
		int cc = (W)?(WebStructure::chapter_count(W)):0;
		int icc = (W)?(WebStructure::imported_chapter_count(W)):0;
		if (icc == 0) WRITE_TO(TextualTables::next_cell(T), "%d", cc);
		else WRITE_TO(TextualTables::next_cell(T), "%d (+ %d)", cc - icc, icc);
		tcc += cc - icc;
		int sc = (W)?(WebStructure::section_count(W)):0;
		int isc = (W)?(WebStructure::imported_section_count(W)):0;
		if (isc == 0) WRITE_TO(TextualTables::next_cell(T), "%d", sc);
		else WRITE_TO(TextualTables::next_cell(T), "%d (+ %d)", sc - isc, isc);
		tsc += sc - isc;
		if (fully) {
			int pc = (W)?(WebStructure::paragraph_count(W)):0;
			int ipc = (W)?(WebStructure::imported_paragraph_count(W)):0;
			if (ipc == 0) WRITE_TO(TextualTables::next_cell(T), "%d", pc);
			else WRITE_TO(TextualTables::next_cell(T), "%d (+ %d)", pc - ipc, ipc);
			tpc += pc - ipc;
			int lc = (W)?(WebStructure::line_count(W)):0;
			int ilc = (W)?(WebStructure::imported_line_count(W)):0;
			if (ilc == 0) WRITE_TO(TextualTables::next_cell(T), "%d", lc);
			else WRITE_TO(TextualTables::next_cell(T), "%d (+ %d)", lc - ilc, ilc);
			tlc += lc - ilc;
		}
	}
	TextualTables::begin_footer_row(T);
	WRITE_TO(TextualTables::next_cell(T), "total: %d", tm);
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "%d", tcc);
	WRITE_TO(TextualTables::next_cell(T), "%d", tsc);
	if (fully) WRITE_TO(TextualTables::next_cell(T), "%d", tpc);
	if (fully) WRITE_TO(TextualTables::next_cell(T), "%d", tlc);
	TextualTables::tabulate(OUT, T);
	WRITE("\n");

@<Tabulate the site map@> =
	textual_table *T = TextualTables::new_table();
	WRITE_TO(TextualTables::next_cell(T), "path");
	WRITE_TO(TextualTables::next_cell(T), "leaf");
	WRITE_TO(TextualTables::next_cell(T), "link-name");
	WRITE_TO(TextualTables::next_cell(T), "nav");
	WRITE_TO(TextualTables::next_cell(T), "crumbs");
	WRITE_TO(TextualTables::next_cell(T), "pattern");
	int no_known_crumbs = 0;
	text_stream *known_crumbs[26];
	colony_member *CM;
	LOOP_OVER_LINKED_LIST(CM, colony_member, L) {
		TextualTables::begin_row(T);
		if (CM->external) {
			WRITE_TO(TextualTables::next_cell(T), "(external)");
			WRITE_TO(TextualTables::next_cell(T), "--");
		} else {
			WRITE_TO(TextualTables::next_cell(T), "%S/", CM->weave_path);
			WRITE_TO(TextualTables::next_cell(T), "%S", CM->home_leaf);
		}
		WRITE_TO(TextualTables::next_cell(T), "%S", CM->name);
		@<Columns about HTML weaving@>;
		if (fully) {
			ls_web *W = CM->loaded;
			ls_chapter *C; ls_section *S;
			LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
				LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
					TEMPORARY_TEXT(url)
					Colonies::section_URL(url, S);
					TextualTables::begin_row(T);
					if (CM->external) {
						WRITE_TO(TextualTables::next_cell(T), "--");
						WRITE_TO(TextualTables::next_cell(T), "--");
					} else {
						WRITE_TO(TextualTables::next_cell(T), "%S/", CM->weave_path);
						WRITE_TO(TextualTables::next_cell(T), "%S", url);
					}
					WRITE_TO(TextualTables::next_cell(T), "%S: %S", CM->name, S->sect_title);
					@<Columns about HTML weaving@>;
				} 
		}
	}
	TextualTables::begin_row(T);
	WRITE_TO(TextualTables::next_cell(T), "%S/", C->assets_path);
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "--");
	WRITE_TO(TextualTables::next_cell(T), "--");
	TextualTables::tabulate_sorted(OUT, T, 0);
	if (no_known_crumbs > 0) WRITE("\n");
	for (int i=0; i<no_known_crumbs; i++)
		WRITE("%c = %S\n", 'A' + i, known_crumbs[i]);

@<Columns about HTML weaving@> =
	if (CM->external) {
		WRITE_TO(TextualTables::next_cell(T), "--");
		WRITE_TO(TextualTables::next_cell(T), "--");
		WRITE_TO(TextualTables::next_cell(T), "--");
	} else {
		if (CM->navigation == NULL) {
			WRITE_TO(TextualTables::next_cell(T), "--");			
		} else if (Str::len(CM->navigation_name) == 0) {
			WRITE_TO(TextualTables::next_cell(T), "(nameless)", CM->navigation_name);			
		} else {
			WRITE_TO(TextualTables::next_cell(T), "%S", CM->navigation_name);
		}
		if (Str::len(CM->crumbs) > 0) {
			int found = FALSE;
			for (int i=0; i<no_known_crumbs; i++)
				if (Str::eq(CM->crumbs, known_crumbs[i])) {
					WRITE_TO(TextualTables::next_cell(T), "%c", 'A' + i);
					found = TRUE;
				}
			if (found == FALSE) {
				if (no_known_crumbs < 26) {
					known_crumbs[no_known_crumbs] = Str::duplicate(CM->crumbs);
					WRITE_TO(TextualTables::next_cell(T), "%c", 'A' + no_known_crumbs);
					no_known_crumbs++;
				} else {
					WRITE_TO(TextualTables::next_cell(T), "%S", CM->crumbs);
				}
			}
		} else {
			TextualTables::next_cell(T);
		}
		WRITE_TO(TextualTables::next_cell(T), "%S", CM->default_weave_pattern);
	}
