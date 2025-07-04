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
	int placed_early; /* should appear early in the tangled code */
	int placed_very_early; /* should appear very early in the tangled code */
	struct text_stream *holon_name; /* can be empty */
	struct linked_list *holon_usages; /* of |holon_usage| */
	struct ls_chunk *corresponding_chunk;
	struct linked_list *splice_list; /* of |holon_splice| */
	CLASS_DEFINITION
} ls_holon;

ls_holon *Holons::new(ls_chunk *chunk, text_stream *holon_name) {
	ls_holon *holon = CREATE(ls_holon);
	holon->placed_early = FALSE;
	holon->placed_very_early = FALSE;
	holon->holon_name = NULL;
	if (Str::len(holon_name) > 0) holon->holon_name = Str::duplicate(holon_name);
	holon->holon_usages = NEW_LINKED_LIST(holon_usage);
	holon->corresponding_chunk = chunk;
	holon->splice_list = NEW_LINKED_LIST(holon_splice);
	return holon;
}

@ The following finds a holon by name: nameless holons can't be found this way.

The scope for looking up holon names is a single unit, not an entire web. So
you can't expand a holon from another unit, but then again, you can use the same
holon name twice in different units; and lookup is much faster.

=
ls_paragraph *Holons::find_holon(text_stream *name, ls_unit *scope) {
	if (Str::len(name) > 0)
		for (ls_paragraph *par = scope->first_par; par; par = par->next_par)
			if ((par->holon) && (Str::eq(name, par->holon->holon_name)))
				return par;
	return NULL;
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

@ Because of the notations for splicing one holon into another, the code
lines in a holon may still contain literate-programming syntax, rather than
literally being the target code. We parse those lines of code into a series
of "splices", each containing a fragment of a line.

=
typedef struct holon_splice {
	struct ls_holon *expansion;
	struct text_stream *command;
	struct ls_line *line;
	int from;
	int to;
	CLASS_DEFINITION
} holon_splice;

holon_splice *Holons::new_splice(ls_line *lst, int from, int to) {
	holon_splice *splice = CREATE(holon_splice);
	splice->expansion = NULL;
	splice->command = NULL;
	splice->line = lst;
	splice->from = from;
	splice->to = to;
	ADD_TO_LINKED_LIST(splice, holon_splice, lst->owning_chunk->holon->splice_list);
	return splice;
}

@ Traditional LP tools have numbered paragraphs in the obvious way, starting
from 1 and working up to what may be an enormous number. (The web for Knuth's
Metafont runs from 1 to 1215, for example.) Here we expect to be working on
rather larger programs and therefore number independently from 1 within
each section. We also try to make the numbering more structurally relevant:
thus paragraph 1.1 will be used within paragraph 1, and so on.

It's a little ambiguous how to do this for the best, as we'll see.

=
void Holons::scan(ls_unit *lsu) {
	finite_state_machine *machine = HolonSyntax::get(lsu->syntax, lsu->language);
	@<Scan to see where holons are used@>;
	@<Warn about any unused holons@>;
	@<Work out paragraph numbers@>;
}

@<Scan to see where holons are used@> =
	TEMPORARY_TEXT(name)
	TEMPORARY_TEXT(command)
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
			if (chunk->holon)
				@<Splice holon into fragmentary lines@>;
	DISCARD_TEXT(name)
	DISCARD_TEXT(command)

@<Splice holon into fragmentary lines@> =
	FSM::reset_machine(machine);
	Str::clear(name); Str::clear(command);
	int from = 0, to = -1;
	ls_holon *expansion = NULL;
	text_stream *recording_to = NULL;
	for (ls_line *lst = chunk->first_line; lst; lst = lst->next_line) {
		from = 0, to = -1;
		int i; inchar32_t c;
		for (i=0; i<Str::len(lst->text); i++) {
			c = Str::get_at(lst->text, i); @<Run FSM@>;
		}
		c = '\n'; @<Run FSM@>;
		to = Str::len(lst->text)-1;
		if ((to >= from) || ((from == 0) && (to == -1) && (lst->next_line)))
			Holons::new_splice(lst, from, to);
	}
	@<Check final state of machine@>;

@<Run FSM@> =
	int event = FSM::cycle_machine(machine, c);
	if (recording_to) PUT_TO(recording_to, c);
	switch (event) {
		case NAME_START_FSMEVENT:
			Str::clear(name); to = i-2; recording_to = name;
			break;
		case NAME_END_FSMEVENT: {
			recording_to = NULL;
			int excess = Str::len(WebSyntax::notation(lsu->syntax, NAMED_HOLONS_WSF, 2));
			Str::truncate(name, Str::len(name) - excess);
			
			ls_paragraph *defining_par = Holons::find_holon(name, lsu);
			if (defining_par) {
				@<Splice code@>;
				@<Add a record that the holon is used in this paragraph@>;
				to = i; expansion = defining_par->holon;
				@<Splice holon@>;
			} else {
				text_stream *message = Str::new();
				WRITE_TO(message, "no such code fragment as '%S'", name);
				WebErrors::record_at(message, lst);
			}
			break;
		}
		case COMMAND_START_FSMEVENT:
			Str::clear(command); to = i-2; recording_to = command;
			break;
		case COMMAND_END_FSMEVENT: {
			recording_to = NULL;
			@<Splice code@>;
			int excess = Str::len(WebSyntax::notation(lsu->syntax, TANGLER_COMMANDS_WSF, 2));
			Str::truncate(command, Str::len(command) - excess);
			to = i;
			@<Splice command@>;
			break;
		}
	}

@<Splice code@> =
	if (to >= from) Holons::new_splice(lst, from, to);
	from = to + 1; to = -1;

@<Splice holon@> =
	if (to >= from) Holons::new_splice(lst, from, to)->expansion = expansion;
	from = to + 1; to = -1;

@<Splice command@> =
	if (to >= from) Holons::new_splice(lst, from, to)->command = Str::duplicate(command);
	from = to + 1; to = -1;

@<Add a record that the holon is used in this paragraph@> =
	holon_usage *mu;
	LOOP_OVER_LINKED_LIST(mu, holon_usage, defining_par->holon->holon_usages)
		if (mu->used_in_paragraph == par)
			break;
	if (mu == NULL) {
		mu = CREATE(holon_usage);
		mu->used_in_paragraph = par;
		mu->multiplicity = 0;
		ADD_TO_LINKED_LIST(mu, holon_usage, defining_par->holon->holon_usages);
	}
	mu->multiplicity++;

@<Check final state of machine@> =
	fsm_state *final = FSM::last_nonintermediate_state(machine);
	ls_line *L = chunk->last_line;
	if (Str::eq(final->mnemonic, I"string"))
		WebErrors::record_at(I"code fragment ends with string literal open", L);
	if (Str::eq(final->mnemonic, I"character"))
		WebErrors::record_at(I"code fragment ends with character literal open", L);
	if (Str::eq(final->mnemonic, I"multi-line-comment"))
		WebErrors::record_at(I"code fragment ends with comment open", L);

@ Only a named holon can be unused, because nameless ones are concatenated into
the top level of the program, and that means they are used.

@<Warn about any unused holons@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		if ((par->holon) && (Str::len(par->holon->holon_name) > 0) &&
			(LinkedLists::len(par->holon->holon_usages) == 0)) {
			text_stream *message = Str::new();
			WRITE_TO(message, "unused code fragment '%S'", par->holon->holon_name);
			WebErrors::record_warning_at(message, par->first_chunk->first_line);
		}

@ Basically we'll form the paragraphs into a tree, or in fact a forest. If a
paragraph defines a holon then we want it to be a child node of the
paragraph where the holon is first used; it's then a matter of filling in
other nodes a bit speculatively.

@<Work out paragraph numbers@> =
	@<The parent of a holon definition is the place where it's first used@>;
	@<Otherwise share the parent of a following paragraph, provided that parent precedes us@>;
	@<Create paragraph number texts@>;
	@<Number the still parent-less paragraphs consecutively from 1@>;
	@<Recursively derive the numbers of parented paragraphs from those of their parents@>;

@<The parent of a holon definition is the place where it's first used@> =
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		if ((par->holon) && (Str::len(par->holon->holon_name) > 0)) {
			holon_usage *mu;
			LOOP_OVER_LINKED_LIST(mu, holon_usage, par->holon->holon_usages)
				if (par != mu->used_in_paragraph) {
					Holons::set_parent(par, mu->used_in_paragraph);
					break;
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
