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
	MEMORY_MANAGEMENT
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
	struct web_md *loaded; /* metadata on its sections, lazily evaluated */
	MEMORY_MANAGEMENT
} colony_member;

@ And the following reads a colony file |F| and produces a suitable |colony|
object from it. This, for example, is the colony file for the Inweb repository
at GitHub:
= (text from Figures/colony.txt)

=
void Colonies::load(filename *F) {
	colony *C = CREATE(colony);
	C->members = NEW_LINKED_LIST(colony_member);
	TextFiles::read(F, FALSE, "can't open colony file",
		TRUE, Colonies::read_line, NULL, (void *) C);
}

@ Lines from the colony file are fed, one by one, into:

=
void Colonies::read_line(text_stream *line, text_file_position *tfp, void *v_C) {
	colony *C = (colony *) v_C;

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
		CM->weave_path = Pathnames::from_text(mr.exp[3]);
		CM->loaded = NULL;
		ADD_TO_LINKED_LIST(CM, colony_member, C->members);
	} else {
		Errors::in_text_file("unable to read colony member", tfp);
	}
	Regexp::dispose_of(&mr);
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
	TEMPORARY_TEXT(err);
	WRITE_TO(err, "unable to load '%S'", CM->name);
	Main::error_in_web(err, L);

@h Cross-references.
The following must decide what references like the following should refer to:
= (text)
	Chapter 3
	Manual
	Enumerated Constants
	Reader::get_section_for_range
	weave_target
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
	weave_target *wv, text_stream *text, web_md *Wm, source_line *L) {
	module *from_M = (Wm)?(Wm->as_module):NULL;
	module *search_M = from_M;
	colony_member *search_CM = NULL;
	int external = FALSE;
	
	@<Is it the name of a member of our colony?@>;
	@<If it contains a colon, does this indicate a section in a colony member?@>;

	module *found_M = NULL;
	section_md *found_Sm = NULL;
	int bare_module_name = FALSE;
	int N = WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
		title, search_M, text, FALSE);
	if (N == 0) {
		if ((L) && (external == FALSE)) {
			@<Is it the name of a function in the current web?@>;
			@<Is it the name of a type in the current web?@>;
		}
		Main::error_in_web(I"Can't find this cross-reference", L);
		return FALSE;
	} else if (N > 1) {
		Main::error_in_web(I"Multiple cross-references might be meant here", L);
		WebModules::named_reference(&found_M, &found_Sm, &bare_module_name,
			title, search_M, text, TRUE);
		return FALSE;
	} else {
		@<It refers unambiguously to a single section@>;
		return TRUE;
	}
}

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
			HTMLFormat::xref(url, wv, fn->function_header_at->owning_paragraph,
				L->owning_section, TRUE);
			WRITE_TO(title, "%S", fn->function_name);
			return TRUE;
		}
	}

@<Is it the name of a type in the current web?@> =
	language_type *str;
	LOOP_OVER(str, language_type) {
		if (Str::eq_insensitive(str->structure_name, text)) {
			HTMLFormat::xref(url, wv, str->structure_header_at->owning_paragraph,
				L->owning_section, TRUE);
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
	pathname *from = Filenames::get_path_to(wv->weave_to);
	pathname *to = search_CM->weave_path;
	Pathnames::relative_URL(url, from, to);
	if (bare_module_name) WRITE_TO(url, "index.html");
	else if (found_Sm) HTMLFormat::section_URL(url, wv, found_Sm); 
	if (bare_module_name == FALSE)
		WRITE_TO(title, " (in %S)", search_CM->name);

@ In the absence of a colony file, Inweb can really only guess, and the
guess it makes is that modules of the current web will be woven alongside
the main one, and suffixed by |-module|.

@<The section is not in a known colony member@> =
	if (found_M == from_M) {
		HTMLFormat::section_URL(url, wv, found_Sm);
	} else {
		WRITE_TO(url, "../%S-module/", found_M->module_name);
		HTMLFormat::section_URL(url, wv, found_Sm); 
		if (bare_module_name == FALSE)
			WRITE_TO(title, " (in %S)", found_M->module_name);
	}
