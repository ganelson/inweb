[Holons::] Holons.

To manage fragments of eventually-compiled code, or "holons", within each section.

@ Functionally, chunks of source which contain fragments of the actual program
to be compiled are the important ones. They hold the code which will eventually
run, with everything else being annotation and commentary.

Each such chunk holds a run of 1 or more lines of source code, and that block
of code is called a "holon", a word meaning "part of the whole", which the
Belgian computer scientist Pierre-Arnoul de Marneffe coined when inventing
his early precursor to literate programming.

Some of our holons have names attached: for example, this section of code
has one called "Check final state of machine". Others, like the holon about
to appear after this paragraph, are nameless.

=
typedef struct ls_holon {
	int main_holon; /* called "Main", or some casing variation on that */
	int webwide; /* visible from other sections, for continuation purposes */
	int top_level; /* rather than being a code block */
	int placed_early; /* should appear early in the tangled code */
	int placed_very_early; /* should appear very early in the tangled code */
	int placed_late; /* similarly */
	int placed_very_late; /* similarly */
	struct text_stream *holon_name; /* can be empty */
	struct markdown_item *holon_name_as_markdown; /* can be |NULL| */
	struct linked_list *holon_usages; /* of |holon_usage| */
	struct ls_chunk *corresponding_chunk;
	int addendum;
	struct ls_holon *addendum_to;
	struct linked_list *addenda; /* of |ls_holon| */
	int file_form;
	CLASS_DEFINITION
} ls_holon;

ls_holon *Holons::new(ls_chunk *chunk, text_stream *holon_name, int addendum, int file_form,
	ls_holon_namespace *ns, int bitmap, ls_notation *ntn, programming_language *pl) {
	if (chunk == NULL) internal_error("loose holon");
	ls_holon *holon = CREATE(ls_holon);
	holon->main_holon = FALSE;
	holon->top_level = TRUE;
	holon->webwide = FALSE;
	holon->placed_early = FALSE;
	holon->placed_very_early = FALSE;
	holon->placed_late = FALSE;
	holon->placed_very_late = FALSE;
	holon->holon_name = NULL;
	if (Str::len(holon_name) > 0) {
		if (file_form == FALSE) holon->top_level = FALSE;
		holon->holon_name = Str::duplicate(holon_name);
	}
	holon->holon_name_as_markdown = NULL;
	holon->holon_usages = NEW_LINKED_LIST(holon_usage);
	holon->corresponding_chunk = chunk;
	holon->corresponding_chunk->code_excerpt = CodeExcerpts::new();
	holon->addendum = addendum;
	holon->addendum_to = NULL;
	holon->addenda = NEW_LINKED_LIST(ls_holon);
	holon->file_form = file_form;

	if (bitmap & WEBWIDEHOLON_LSNROBIT)   { holon->webwide = TRUE; }
	if (bitmap & VERYEARLYHOLON_LSNROBIT) { holon->placed_very_early = TRUE; holon->top_level = TRUE; }
	if (bitmap & EARLYHOLON_LSNROBIT)     { holon->placed_early = TRUE; holon->top_level = TRUE; }
	if (bitmap & LATEHOLON_LSNROBIT)      { holon->placed_late = TRUE; holon->top_level = TRUE; }
	if (bitmap & VERYLATEHOLON_LSNROBIT ) { holon->placed_very_late = TRUE; holon->top_level = TRUE; }

	LiterateSource::process_chunk(chunk, ntn->code_preprocessor);
	CodeExcerpts::parse(ns, holon->corresponding_chunk->code_excerpt,
		holon->corresponding_chunk->first_line, NULL, ntn, pl);
	Holons::declare_in_namespace(holon, ns);
	
	return holon;
}

typedef struct ls_holon_namespace {
	struct ls_web *owning_web;  /* or |NULL| for code isolated from any web */
	struct ls_unit *owner;      /* or |NULL| for global scope, but they're not both |NULL| */
	struct dictionary *names;
	struct linked_list *holons; /* of |ls_holon| */
	struct dictionary *expansion_names;
	struct linked_list *unabbreviated_names; /* of |text_stream| */
	int contains_Main;
	CLASS_DEFINITION
} ls_holon_namespace;

ls_holon_namespace *Holons::new_namespace(ls_web *W, ls_unit *owner) {
	ls_holon_namespace *ns = CREATE(ls_holon_namespace);
	ns->owning_web = W;
	ns->owner = owner;
	if ((W == NULL) && (owner == NULL)) internal_error("lost holon namespace");
	ns->names = Dictionaries::new(128, FALSE);
	ns->holons = NEW_LINKED_LIST(ls_holon);
	ns->expansion_names = Dictionaries::new(128, FALSE);
	ns->unabbreviated_names = NEW_LINKED_LIST(text_stream);
	ns->contains_Main = FALSE;
	return ns;
}

ls_holon_namespace *Holons::superior(ls_holon_namespace *ns) {
	if (ns->owner == NULL) return NULL; /* global already */
	if (ns->owning_web) return ns->owning_web->global_holon_namespace;
	return NULL;
}

void Holons::declare_in_namespace(ls_holon *holon, ls_holon_namespace *ns) {
	int mc = 0;
	text_stream *un = Holons::unabbreviate_name(holon->holon_name, ns, &mc);
	if (mc == 0) {
		text_stream *message = Str::new();
		WRITE_TO(message, "holon name '%S' looks like an abbreviation, but matches nothing previous", holon->holon_name);
		WebErrors::record_at(message, holon->corresponding_chunk->onset_line);
		return;
	}
	if (mc > 1) {
		text_stream *message = Str::new();
		WRITE_TO(message, "holon name '%S' looks like an abbreviation, but matches %d different previous names", holon->holon_name, mc);
		WebErrors::record_at(message, holon->corresponding_chunk->onset_line);
		return;
	}
	if (un != holon->holon_name) holon->holon_name = Str::duplicate(un);

	ls_holon_namespace *gns = Holons::superior(ns);
	if (Str::len(holon->holon_name) > 0) {
		if ((Str::eq_insensitive(holon->holon_name, I"Main")) && (holon->addendum == FALSE)) {
			if ((LinkedLists::len(ns->holons) > 0) ||
				((gns) && (LinkedLists::len(gns->holons) > 0))) {
				WebErrors::record_at(
					I"if the holon name 'Main' is used at all, it must be first in the web",
					holon->corresponding_chunk->first_line);
			} else {
				holon->main_holon = TRUE;
				holon->top_level = TRUE;
				holon->webwide = TRUE;
			}
		}

		TEMPORARY_TEXT(err)
		ls_holon *existing = Holons::find_holon(holon->holon_name, ns, (holon->addendum == TRUE)?TRUE:FALSE, err);
		if (existing) {
			if (holon->addendum == NOT_APPLICABLE) holon->addendum = TRUE;
			if (holon->addendum) {
				holon->addendum_to = existing;
				ADD_TO_LINKED_LIST(holon, ls_holon, existing->addenda);
				@<Add to namespace@>;
			} else {
				text_stream *message = Str::new();
				WRITE_TO(message, "duplicate holon name '%S'", holon->holon_name);
				WebErrors::record_at(message, holon->corresponding_chunk->onset_line);
			}
		} else {
			if (holon->addendum == NOT_APPLICABLE) holon->addendum = FALSE;
			if (Str::len(err) > 0) {
				WebErrors::record_at(err, holon->corresponding_chunk->first_line);
			} else if (holon->addendum == TRUE) {
				text_stream *message = Str::new();
				WRITE_TO(message,
					"holon says it is an addendum to '%S', but that has not been defined yet",
					holon->holon_name);
				WebErrors::record_at(message, holon->corresponding_chunk->onset_line);
			} else {
				@<Add to namespace@>;
			}
		}
		DISCARD_TEXT(err)
	} else {
		if ((ns->contains_Main) || ((gns) && (gns->contains_Main))) {
			WebErrors::record_at(
				I"because the first holon is called 'Main', all code has to be in named holons",
				holon->corresponding_chunk->onset_line);
		} else {
			@<Add to namespace@>;
		}
	}
}

@<Add to namespace@> =
	Holons::add_to_namespace(holon, ns);
	if ((gns) && (holon->webwide)) Holons::add_to_namespace(holon, gns);

@ =
void Holons::add_to_namespace(ls_holon *holon, ls_holon_namespace *ns) {
	if ((Str::len(holon->holon_name) > 0) && (holon->addendum == FALSE)) {
		if (holon->main_holon) ns->contains_Main = TRUE;
		Dictionaries::create(ns->names, holon->holon_name);
		Dictionaries::write_value(ns->names, holon->holon_name, holon);
		Holons::add_un_to_namespace(holon->holon_name, holon, ns);
	}
	ADD_TO_LINKED_LIST(holon, ls_holon, ns->holons);
}

int Holons::abbreviated(text_stream *name) {
	if (Str::ends_with(name, I"...")) return TRUE;
	return FALSE;
}

void Holons::sanitise_name(OUTPUT_STREAM, text_stream *name) {
	int i = 0;
	while ((i < Str::len(name)) && (Characters::is_whitespace(Str::get_at(name, i)))) i++;
	while (i < Str::len(name)) {
		if (Characters::is_whitespace(Str::get_at(name, i))) {
			while ((i+1 < Str::len(name)) && (Characters::is_whitespace(Str::get_at(name, i+1)))) i++;
			if (i+1 < Str::len(name)) PUT(' ');
		} else {
			PUT(Str::get_at(name, i));
		}
		i++;
	}
}

void Holons::add_un_to_namespace(text_stream *name, ls_holon *from, ls_holon_namespace *ns) {
	dict_entry *de = Dictionaries::find(ns->expansion_names, name);
	if (de == NULL) {
		Dictionaries::create(ns->expansion_names, name);
		Dictionaries::write_value(ns->expansion_names, name, from);
		text_stream *copy = Str::duplicate(name);
		ADD_TO_LINKED_LIST(copy, text_stream, ns->unabbreviated_names);
	}
}

text_stream *Holons::unabbreviate_name(text_stream *name, ls_holon_namespace *ns, int *mc) {
	if (Holons::abbreviated(name)) {
		int N = Str::len(name) - 3, matches = 0;
		text_stream *un, *match = NULL;
		LOOP_OVER_LINKED_LIST(un, text_stream, ns->unabbreviated_names) {
			int failed = FALSE;
			for (int i=0; i<N; i++)
				if (Str::get_at(name, i) != Str::get_at(un, i)) {
					failed = TRUE; break;
				}
			if (failed == FALSE) {
				match = un; matches++;
			}
		}
		*mc = matches;
		if (matches == 1) return match;
		return NULL;
	} else {
		*mc = 1; return name;
	}
}

@ The following finds a holon by name: nameless holons can't be found this way.

=
ls_holon *Holons::find_holon(text_stream *name, ls_holon_namespace *ns,
	int allow_globals, text_stream *err) {
	while (ns) {
		if (Str::len(name) > 0) @<Search this namespace@>;
		if (allow_globals == FALSE) break;
		ns = Holons::superior(ns);
	}
	return NULL;
}

@<Search this namespace@> =
	if (Holons::abbreviated(name)) {
		if ((ns->owning_web) &&
			(Conventions::get_int(ns->owning_web, HOLONS_CAN_BE_ABBREVIATED_LSCONVENTION)
				== NO_ABBREVCHOICE)) {
			WRITE_TO(err, "'%S' can't be used, because 'holons cannot be abbreviated' is in force", name);
			return NULL;			
		}
	}
	int mc = 0;
	text_stream *search_name = Holons::unabbreviate_name(name, ns, &mc);
	if (mc > 1) {
		text_stream *un;
		LOOP_OVER_LINKED_LIST(un, text_stream, ns->unabbreviated_names) {
			PRINT("%S\n", un);
		}
		WRITE_TO(err, "'%S' is too abbreviated: it might mean %d different holons", name, mc);
		return NULL;
	}
	if (mc > 0) {
		dict_entry *de = Dictionaries::find(ns->names, search_name);
		if (de) return (ls_holon *) Dictionaries::value_for_entry(de);
	}

@ Some holons tangle to sidekick files:

=
text_stream *Holons::external_filename(ls_holon *holon) {
	if ((holon == NULL) || (holon->file_form == FALSE)) return NULL;
	return holon->holon_name;
}

@ Named holons are used by being spliced into others. For example, if the code
in one holon includes a notation to include "Check final state of machine",
that's called a "holon usage".

It's slightly more convenient to record which paragraphs use the holon than
which other holons, and it comes to the same thing anyway since a paragraph
can only have at most one holon.

=
typedef struct holon_usage {
	struct ls_paragraph *used_in_paragraph;
	int multiplicity; /* for example, 2 if it's used twice in this paragraph */
	CLASS_DEFINITION
} holon_usage;

void Holons::scan(ls_holon_namespace *ns) {
	linked_list *holon_list = ns->holons;
	ls_holon *holon;
	holon_splice *hs;
	LOOP_OVER_LINKED_LIST(holon, ls_holon, holon_list)
		LOOP_OVER_HOLON_DEFINITION(hs, holon)
			if ((hs->type == EXPANSION_LSHST) ||
				(hs->type == FILE_EXPANSION_LSHST))
				@<Identify expansion name with holon@>;

	LOOP_OVER_LINKED_LIST(holon, ls_holon, holon_list)
		LOOP_OVER_HOLON_DEFINITION(hs, holon)
			if ((hs->type == EXPANSION_LSHST) ||
				(hs->type == FILE_EXPANSION_LSHST)) {
				ls_holon *expansion = hs->expansion;
				if (expansion) {
					if ((expansion->placed_very_early) || (expansion->placed_early) ||
						(expansion->placed_late) || (expansion->placed_very_late))
						WebErrors::record_at(I"this line would incorporate a holon marked as early or late", hs->line);
					@<Add a record that the holon is used in this paragraph@>;
				}
			}
}

@<Identify expansion name with holon@> =
	TEMPORARY_TEXT(err)
	TEMPORARY_TEXT(sanitised)
	Holons::sanitise_name(sanitised, hs->texts[0]);
	Str::clear(hs->texts[0]); Str::copy(hs->texts[0], sanitised);
	DISCARD_TEXT(sanitised)

	ls_holon *expansion = Holons::find_holon(hs->texts[0], ns, TRUE, err);
	if (expansion) {
		if ((hs->type == FILE_EXPANSION_LSHST) && (expansion->file_form == FALSE)) {
			text_stream *message = Str::new();
			WRITE_TO(message, "you used the filename form of holon '%S', but it is not a file holon",
				hs->texts[0]);
			WebErrors::record_at(message, hs->line);
		} else if ((hs->type != FILE_EXPANSION_LSHST) && (expansion->file_form)) {
			text_stream *message = Str::new();
			WRITE_TO(message, "you used the non-file way to refer to holon '%S', but it is a file holon",
				hs->texts[0]);
			WebErrors::record_at(message, hs->line);
		} else {
			hs->expansion = expansion;
		}
	} else {
		if (Str::len(err) > 0) {
			WebErrors::record_at(err, hs->line);
		} else {
			text_stream *message = Str::new();
			WRITE_TO(message, "no such holon as '%S'", hs->texts[0]);
			WebErrors::record_at(message, hs->line);
		}
	}
	hs->texts[0] = NULL;
	hs->type = EXPANSION_LSHST;
	DISCARD_TEXT(err)

@

=
void Holons::vet_usage(ls_unit *lsu) {
	ls_holon_namespace *ns = lsu->local_holon_namespace;
	linked_list *holon_list = ns->holons;
	@<Warn about any unused holons@>;
	@<Check that holons are well-founded@>;
	Holons::number_paragraphs(lsu);
}

@<Add a record that the holon is used in this paragraph@> =
	holon_usage *hu;
	ls_paragraph *user = holon->corresponding_chunk->owner;
	if (holon->addendum_to) user = holon->addendum_to->corresponding_chunk->owner;
	LOOP_OVER_LINKED_LIST(hu, holon_usage, expansion->holon_usages)
		if (hu->used_in_paragraph == user)
			break;
	if (hu == NULL) {
		hu = CREATE(holon_usage);
		hu->used_in_paragraph = user;
		hu->multiplicity = 0;
		ADD_TO_LINKED_LIST(hu, holon_usage, expansion->holon_usages);
	}
	hu->multiplicity++;

@ Only a named holon can be unused, because nameless ones are concatenated into
the top level of the program, and that means they are used.

@<Warn about any unused holons@> =
	ls_holon *holon;
	LOOP_OVER_LINKED_LIST(holon, ls_holon, holon_list) {
		if ((holon->top_level == FALSE) &&
			(LinkedLists::len(holon->holon_usages) == 0) &&
			(holon->addendum_to == NULL) &&
			(holon->file_form == FALSE)) {
			text_stream *message = Str::new();
			WRITE_TO(message, "unused holon '%S'", holon->holon_name);
			WebErrors::record_warning_at(message, holon->corresponding_chunk->onset_line);
		}
	}

@<Check that holons are well-founded@> =
	ls_holon *holon;
	LOOP_OVER_LINKED_LIST(holon, ls_holon, holon_list) {
		if ((holon->top_level == FALSE) &&
			(LinkedLists::len(holon->holon_usages) == 0) &&
			(holon->addendum_to == NULL)) {
			if (Holons::traverse_terminated_safely(holon, holon, 0) == FALSE) {
				text_stream *message = Str::new();
				WRITE_TO(message, "holon '%S' tries to include itself", holon->holon_name);
				WebErrors::record_at(message, holon->corresponding_chunk->onset_line);
			}
		}
	}

@ =
int Holons::traverse_terminated_safely(ls_holon *holon, ls_holon *forbidden, int depth) {
	if ((depth > 0) && (holon == forbidden)) return FALSE;
	holon_usage *hu;
	LOOP_OVER_LINKED_LIST(hu, holon_usage, holon->holon_usages) {
		ls_holon *user = hu->used_in_paragraph->holon;
		if (user == NULL) internal_error("I seem to have misunderstood");
		if (Holons::traverse_terminated_safely(user, forbidden, depth+1) == FALSE)
			return FALSE;
	}
	return TRUE;
}

@h Paragraph numbering.
We have two different ways of doing this:

=
void Holons::number_paragraphs(ls_unit *lsu) {
	if ((lsu->context) &&
		(Conventions::get_int(lsu->context, PARAGRAPHS_NUMBERED_SEQUENTIALLY_LSCONVENTION)))
		@<Number paragraphs the old-fashioned way@>
	else
		@<Work out paragraph numbers hierarchically@>;
}

@ Traditional LP tools have numbered paragraphs in the obvious way, starting
from 1 and working up to what may be an enormous number. (The web for Knuth's
Metafont runs from 1 to 1215, for example.) Here we expect to be working on
rather larger programs and therefore number independently from 1 within each
section.

@<Number paragraphs the old-fashioned way@> =
	int N = 0;
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		N++;
		par->paragraph_number = Str::new();
		WRITE_TO(par->paragraph_number, "%d", N);
	}

@  Inweb's default scheme also tries to make the numbering more structurally relevant:
thus paragraph 1.1 will be used within paragraph 1, and so on.

Basically we'll form the paragraphs into a tree, or in fact a forest. If a
paragraph defines a holon then we want it to be a child node of the
paragraph where the holon is first used; it's then a matter of filling in
other nodes a bit speculatively.

@<Work out paragraph numbers hierarchically@> =
	linked_list *holon_list = lsu->local_holon_namespace->holons;
	@<The parent of a holon definition is the place where it's first used@>;
	@<Otherwise share the parent of a following paragraph, provided that parent precedes us@>;
	@<Create paragraph number texts@>;
	@<Number the still parent-less paragraphs consecutively from 1@>;
	@<Recursively derive the numbers of parented paragraphs from those of their parents@>;

@<The parent of a holon definition is the place where it's first used@> =
	ls_holon *holon;
	LOOP_OVER_LINKED_LIST(holon, ls_holon, holon_list) {
		if ((holon->top_level == FALSE) && (holon->addendum_to == NULL)) {
			ls_paragraph *par = holon->corresponding_chunk->owner;
			holon_usage *hu;
			LOOP_OVER_LINKED_LIST(hu, holon_usage, holon->holon_usages)
				if ((par != hu->used_in_paragraph) &&
					(hu->used_in_paragraph->owning_unit == par->owning_unit)) {
					Holons::set_parent(par, hu->used_in_paragraph);
					break;
				}
		}
	}

@<Otherwise share the parent of a following paragraph, provided that parent precedes us@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		if (par->parent_paragraph == NULL)
			for (ls_paragraph *par2 = par; par2; par2 = par2->next_par)
				if (par2->parent_paragraph) {
					if (par2->parent_paragraph->allocation_id < par->allocation_id)
						Holons::set_parent(par, par2->parent_paragraph);
					break;
				}

@<Create paragraph number texts@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par) {
		par->paragraph_number = Str::new();
		par->next_child_number = 0;
	}

@ Now we have our tree, and we number paragraphs accordingly: root notes are
numbered 1, 2, 3, ..., and then children are numbered with suffixes .1, .2, .3,
..., under their parents.

@<Number the still parent-less paragraphs consecutively from 1@> =
	int top_level = 1;
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		if (par->parent_paragraph == NULL) {
			WRITE_TO(par->paragraph_number, "%d", top_level++);
			par->next_child_number = 1;
		} else
			Str::clear(par->paragraph_number);

@<Recursively derive the numbers of parented paragraphs from those of their parents@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		Holons::settle_paragraph_number(par);

@ The following paragraph shows the deficiencies of the algorithm: it isn't used
anywhere and doesn't seem to be in the middle of a wider description. But better
to keep it in the sequence chosen by the author, so it gets the next top-level
number.

=
void Holons::settle_paragraph_number(ls_paragraph *par) {
	if (Str::len(par->paragraph_number) > 0) return;
	WRITE_TO(par->paragraph_number, "X"); /* to prevent malformed sections hanging this */
	if (par->parent_paragraph) Holons::settle_paragraph_number(par->parent_paragraph);
	if (par == par->parent_paragraph) internal_error("paragraph is its own parent");
	Str::clear(par->paragraph_number);
	WRITE_TO(par->paragraph_number, "%S.%d", par->parent_paragraph->paragraph_number,
			par->parent_paragraph->next_child_number++);
	par->next_child_number = 1;
}

void Holons::set_parent(ls_paragraph *of, ls_paragraph *to) {
	if (of == NULL) internal_error("no paragraph");
	if (to == of) internal_error("paragraph parent set to itself");
	of->parent_paragraph = to;
}
