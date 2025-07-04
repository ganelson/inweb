[FSM::] Finite State Machines.

To provide simple scanning parsers based on finite state machines.

@ The following aims to provide a reasonably fast way to scan text according
to syntaxes not known in advance, and which may awkwardly overlap, without
memory allocation during scanning.

We do this by passing the characters one by one into a finite state machine.
This is in effect a black box, whose internal state is a non-|NULL| value of
|fsm_state|, together with a count of how many cycles it has had this state for.

Having a cycle count is one of several ways where our FSMs are not as austere
as the bare minimum implementation would be. These various bells and whistles
do not give us any extra computational expressiveness, i.e., do not extend the
range of what can be scanned for, but do reduce the size and increase the
human-readability of the machines.

=
typedef struct finite_state_machine {
	struct fsm_state *start_at;
	struct fsm_state *current_state;
	int cycles_at_current_state;
	struct linked_list *states; /* of |fsm_state| */
	CLASS_DEFINITION
} finite_state_machine;

finite_state_machine *FSM::new_machine(fsm_state *start) {
	if (start == NULL) internal_error("no state for fsm");
	finite_state_machine *fsm = CREATE(finite_state_machine);
	fsm->start_at = start;
	fsm->current_state = start;
	fsm->cycles_at_current_state = 0;
	fsm->states = NEW_LINKED_LIST(fsm_state);
	FSM::attach(start, fsm);
	return fsm;
}

@ An "event" is a signal which can be sent back by the machine on certain
cycles when it finds that something has happened. The function running the
machine returns |NO_FSMEVENT| when no event has taken place.

The special |AGAIN_FSMEVENT| event is used only internally, and means that
the machine is going to cycle an extra time before returning. By definition,
then, it can never be returned to the caller.

@e NO_FSMEVENT from 0
@e AGAIN_FSMEVENT

@ Each possible state of the machine must be one of the following.

In practice some states are more important than others. For example, if we're
looking for text between |XYZ| and |PQR|, then we care more about the state of
entering that stretch than we do about the brief interstitial state which
represents having read |XY| and being potentially about to read |Z|.
Interstitial states like that are "formed from" their origin, i.e., the
state before the |X|, and we keep a count of how many states are formed from
each state, though only to provide nice human-readable names.

=
typedef struct fsm_state {
	struct text_stream *mnemonic;
	struct finite_state_machine *owner;
	struct fsm_state *formed_from;
	struct fsm_transitions exits;
	struct fsm_transitions entries;
	int no_states_formed_from_this;
	CLASS_DEFINITION
} fsm_state;

fsm_state *FSM::new_state(text_stream *memo) {
	fsm_state *state = CREATE(fsm_state);
	state->mnemonic = Str::duplicate(memo);
	state->owner = NULL;
	state->formed_from = NULL;
	state->exits = FSM::new_transitions(state);
	state->entries = FSM::new_transitions(state);
	state->no_states_formed_from_this = 0;
	return state;
}

fsm_state *FSM::new_state_from(fsm_state *existing) {
	if (existing == NULL) internal_error("no existing state");
	fsm_state *state = FSM::new_state(NULL);
	state->formed_from = existing;
	state->mnemonic = Str::new();
	WRITE_TO(state->mnemonic, "%S-x%d",
		existing->mnemonic, ++(existing->no_states_formed_from_this));
	return state;
}

@ When reading the state of the machine, we usually don't care about
interstitial states, only the more important ones they came from. So:

=
fsm_state *FSM::last_nonintermediate_state(finite_state_machine *fsm) {
	fsm_state *state = fsm->current_state;
	while (state->formed_from) state = state->formed_from;
	return state;
}

@  Note that an |fsm_state| can be the state of at most one possible machine,
its |owner|. When created, it is detached. As we'll see below, it attaches
automatically either by being the start state, or when transitions to or from
it are made. In either situation this is called:

=
void FSM::attach(fsm_state *state, finite_state_machine *fsm) {
	if (state->owner == NULL) {
		state->owner = fsm;
		ADD_TO_LINKED_LIST(state, fsm_state, fsm->states);
	} else if (state->owner != fsm) {
		internal_error("state in multiple machines");
	}
}

@ "Transitions" are the rules governing which characters cause a state change
in the machine. Each state provides both "exit" and "entry" transitions, though
the latter are rarely needed, so we'll ignore them for now.

It's faster to use a fixed-size array of these, since in practice we don't
need enormously sprouting machines.

@d MAX_FSM_TRANSITIONS 32

=
typedef struct fsm_transitions {
	int count;
	struct fsm_transition *first_trans;
} fsm_transitions;

fsm_transitions FSM::new_transitions(fsm_state *state) {
	fsm_transitions bank;
	bank.count = 0;
	bank.first_trans = NULL;
	return bank;
}

@ A transition occurs when the character matches |on|, or when |on| is 0,
which serves as an "any character" wildcard; except that, if the |first| 
flag is set, then it can occur only on the first cycle of the machine being
in its current state.

=
typedef struct fsm_transition {
	/* match criteria: */
	inchar32_t on;
	struct fsm_state *to;
	/* result of a match: */
	int first;
	int event;

	struct fsm_transition *next_trans; /* within the list for a bank */
	CLASS_DEFINITION
} fsm_transition;

@ There is an API for adding transitions, but this is not it: it's used only
below.

=
void FSM::add_primitive(fsm_state *from, fsm_transitions *bank, inchar32_t c, fsm_state *to, int event, int first_cycle_only) {
	@<Attach states to the machine@>;
	@<Replace any existing transition with these criteria@>;

	fsm_transition *nt = CREATE(fsm_transition);
	nt->on = c;
	nt->to = to;
	nt->event = event;
	nt->first = first_cycle_only;
	nt->next_trans = NULL;

	@<Place the new transition as late as it can be@>;
	bank->count++;
}

@ States can be joined only when at least one of them is attached to a machine,
and then the other is automatically attached.

@<Attach states to the machine@> =
	if (to == NULL) internal_error("no state for transition");
	if (from == NULL) internal_error("no state for transition");
	if (from->owner) FSM::attach(to, from->owner);
	else if (to->owner) FSM::attach(from, to->owner);
	else internal_error("transition from loose state");

@<Replace any existing transition with these criteria@> =
	for (fsm_transition *trans = bank->first_trans; trans; trans = trans->next_trans) {
		if ((trans->on == c) && (trans->first == first_cycle_only)) {
			trans->event = event;
			trans->to = to;
			return;
		}
	}

@ We must avoid a situation where an "any character" transition occurs before our
new one, because in that case the new one would have no effect. So we place it
just before the first existing transition which would gazump it (if there is one),
and otherwise at the end.

@<Place the new transition as late as it can be@> =
	fsm_transition *prev_trans = NULL;
		for (fsm_transition *trans = bank->first_trans; trans; prev_trans = trans, trans = trans->next_trans)
			if ((trans->on == 0) && (trans->first <= first_cycle_only)) {
				nt->next_trans = trans;
				break;
			}
	if (prev_trans == NULL) bank->first_trans = nt;
	else prev_trans->next_trans = nt;

@ This utility function finds if any existing transition has the given criteria,
not matching a general (i.e. nonzero) character against any wildcards.

=
fsm_state *FSM::find_next(fsm_state *from, inchar32_t c, int first_cycle_only) {
	fsm_transitions *bank = &(from->exits);
	for (fsm_transition *trans = bank->first_trans; trans; trans = trans->next_trans) {
		if (first_cycle_only == trans->first) {
			inchar32_t test_c = trans->on;
			if (test_c == c) return trans->to;
			if (test_c == 0) return NULL;
		}
	}
	return NULL;
}

@ So now we come to the API for adding transitions. The simplest functions are these;
once again, one of the two states |from| and |to| must already be attached to a
machine.

=
void FSM::add_transition(fsm_state *from, inchar32_t c, fsm_state *to) {
	FSM::add_primitive(from, &(from->exits), c, to, NO_FSMEVENT, FALSE);
}

void FSM::add_entry_transition(fsm_state *from, inchar32_t c, fsm_state *to) {
	FSM::add_primitive(from, &(from->entries), c, to, NO_FSMEVENT, FALSE);
}

void FSM::add_entry_transition_with_event(fsm_state *from, inchar32_t c, fsm_state *to, int event) {
	FSM::add_primitive(from, &(from->entries), c, to, event, FALSE);
}

void FSM::add_transition_with_event(fsm_state *from, inchar32_t c, fsm_state *to, int event) {
	FSM::add_primitive(from, &(from->exits), c, to, event, FALSE);
}

void FSM::add_general_transition(fsm_state *from, inchar32_t c, fsm_state *to, int event, int first_cycle_only) {
	FSM::add_primitive(from, &(from->exits), c, to, event, first_cycle_only);
}

@ More ambitiously, we can call the following functions to set up a compound
syntax where the transition is made only when a string of contiguous characters
in order is scanned, e.g., |XYZ|. Interstitial states are created where necessary,
but existing ones are used if possible, so this is a little like a trie.

=
void FSM::add_transition_spelling_out(fsm_state *from, text_stream *text, fsm_state *to) {
	FSM::add_transition_spelling_out_with_events(from, text, to, NO_FSMEVENT, NO_FSMEVENT);
}

void FSM::add_transition_spelling_out_with_events(fsm_state *from, text_stream *text,
	fsm_state *to, int fallback_event, int event) {
	fsm_state *at = from;
	for (int i=0; i<Str::len(text); i++) {
		int first_cycle_only = (i==0)?FALSE:TRUE;
		fsm_state *next = to;
		if (i+1 < Str::len(text)) {
			next = FSM::find_next(at, Str::get_at(text, i), first_cycle_only);
			if (next == NULL) {
				next = FSM::new_state_from(from);
				FSM::add_general_transition(next, 0, from, fallback_event, first_cycle_only);
			}
			FSM::add_general_transition(at, Str::get_at(text, i), next, NO_FSMEVENT, first_cycle_only);
		} else {
			FSM::add_general_transition(at, Str::get_at(text, i), next, event, first_cycle_only);
		}
		at = next;
	}
}

@h Operating the machine.
Once created, a machine can be used any number of times, but must be reset
before each fresh use:

=
void FSM::reset_machine(finite_state_machine *fsm) {
	fsm->current_state = fsm->start_at;
	fsm->cycles_at_current_state = 0;
}

@ We then call this on each character in turn of the text to be scanned.

=
int FSM::cycle_machine(finite_state_machine *fsm, inchar32_t c) {
	Repeat: ;
	// WRITE_TO(STDERR, "At state %S with c = %c\n", fsm->current_state->mnemonic, c);
	fsm_transitions *bank = &(fsm->current_state->exits);
	for (fsm_transition *trans = bank->first_trans; trans; trans = trans->next_trans) {
		inchar32_t test_c = trans->on;
		if ((test_c == 0) || (test_c == c))
			if ((fsm->cycles_at_current_state == 0) || (trans->first == FALSE))
				@<Make this transition@>;
	}
	fsm->cycles_at_current_state++;
	return NO_FSMEVENT;
}

@<Make this transition@> =
	int event = trans->event;
	fsm_state *new_state = trans->to;
	if (new_state == fsm->current_state) {
		fsm->cycles_at_current_state++;
	} else {
		fsm->current_state = new_state;
		fsm->cycles_at_current_state = 0;

		@<Consider entry transitions@>;
	}
	if (event == AGAIN_FSMEVENT) goto Repeat;
	return event;

@ When the machine transitions to a new state T, we immediately look at the
"entry transitions" for T (if any) and act on those, which may in effect
transition us away again. But note that entry transitions are simpler: there
is no concept of firstness.

If an entry transition causes an event, this takes priority over any event
signalled in the process of getting to it. Thus if A transitions to B with
event E, and then an entry transition for B redirects us to C with event F,
it's event F which is sent back to the caller, and E is forgotten. But a
well-constructed FSM won't do this.

@<Consider entry transitions@> =
	bank = &(new_state->entries);
	for (fsm_transition *trans = bank->first_trans; trans; trans = trans->next_trans) {
		inchar32_t test_c = trans->on;
		if ((test_c == 0) || (test_c == c)) {
			fsm_state *new_state = trans->to;
			if (new_state != fsm->current_state) {
				fsm->current_state = new_state;
				fsm->cycles_at_current_state = 0;
			}
			int latest_event = trans->event;
			if (latest_event != NO_FSMEVENT) event = latest_event;
			break;
		}
	}

@h Logging.
The following prints out a fairly human-readable form of the machine.

=
void FSM::write_fsm(OUTPUT_STREAM, finite_state_machine *fsm) {
	fsm_state *state;
	LOOP_OVER_LINKED_LIST(state, fsm_state, fsm->states) {
		FSM::write_state(OUT, state); WRITE("\n");
		INDENT;
		fsm_transitions *bank = &(state->entries);
		if (bank->count > 0) {
			WRITE("on entry:\n");
			INDENT;
			@<Write transitions@>;
			OUTDENT;
		}
		bank = &(state->exits);
		if (bank->count > 0) {
			@<Write transitions@>;
		}
		OUTDENT;
	}
}

@<Write transitions@> =
	fsm_transition *last_trans = NULL;
	for (fsm_transition *trans = bank->first_trans; trans; trans = trans->next_trans) {
		if (trans->first) WRITE("first time only: ");
		switch (trans->on) {
			case 0: if (last_trans == NULL) WRITE("always"); else WRITE("else"); break;
			case ' ': WRITE("on space"); break;
			case '\t': WRITE("on tab"); break;
			case '\n': WRITE("on newline"); break;
			default: WRITE("on '%c'", trans->on); break;
		}
		if (trans->to != state) {
			WRITE(" -> "); FSM::write_state(OUT, trans->to);
		} else {
			WRITE(" stay");
		}
		if (trans->event != NO_FSMEVENT) {
			if (trans->event == AGAIN_FSMEVENT) WRITE(" and cycle");
			else WRITE(" and event %d", trans->event);
		}
		WRITE("\n");
		last_trans = trans;
	}
	if (last_trans == NULL) WRITE("always stay\n");
	else if ((last_trans->on != 0) || (last_trans->first)) WRITE("else stay\n");

@ =
void FSM::write_state(OUTPUT_STREAM, fsm_state *state) {
	if (Str::len(state->mnemonic) > 0) WRITE("[%S]", state->mnemonic);
	else WRITE("[S%d]", state->allocation_id);
}
