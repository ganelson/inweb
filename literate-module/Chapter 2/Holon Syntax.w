[HolonSyntax::] Holon Syntax.

Constructing a finite state machine for the parsing of code in holons.

@ The code in each holon has to be scanned, mainly to spot names of other holons
within it. This is not as simple as it seems because it depends both on the
syntax used to mark holons inside code, and also the syntax of the programming
language, in order that we don't get false positives of holon notation from
inside comments, string literals or character literals. For example, if our
syntax for a holon in C is |XXname of holonYY|, then we don't want to be fooled
by |printf("XX"); /* YYZ is my favourite Rush number */|, where the |XX|
doesn't count because it's inside a string literal, and the |YY| because it's
inside a multiline comment.

We therefore construct a finite state machine which does the necessary parsing
depending on these two sets of syntax. For efficiency, we don't want to construct
a new FSM every time, so we cache the results.

@d DO_NOT_TRACE_HOLON_FSMS

=
typedef struct ls_holon_scanner {
	struct ls_notation *syntax;
	struct programming_language *pl;
	struct finite_state_machine *machine;
	CLASS_DEFINITION
} ls_holon_scanner;

finite_state_machine *HolonSyntax::get(ls_notation *S, programming_language *pl) {
	ls_holon_scanner *sc;
	LOOP_OVER(sc, ls_holon_scanner)
		if ((sc->syntax == S) && (sc->pl == pl))
			return sc->machine;
	@<Create a new scanner@>;
	#ifdef TRACE_HOLON_FSMS
	WRITE_TO(STDERR, "Created scanner for language %S with %S\n",
		(pl)?(pl->language_name):I"NONE", S->name);
	FSM::write_fsm(STDERR, sc->machine);
	#endif
	return sc->machine;
}

@ Every scanner has a state called "code" for the normal compiled matter,
that is, what isn't in some form of quotation marks or comment markers.

@<Create a new scanner@> =
	sc = CREATE(ls_holon_scanner);
	sc->syntax = S;
	sc->pl = pl;
	fsm_state *code_state = FSM::new_state(I"code");
	fsm_state *whitespace_at_line_start_state = NULL;
	@<Create the finite state machine@>;
	if (pl) {
		@<Add line comment syntax to finite state machine@>;
		@<Add multiline comment syntax to finite state machine@>;
		@<Add whole line comment syntax to finite state machine@>;
		@<Add string literal syntax to finite state machine@>;
		@<Add character literal syntax to finite state machine@>;
	}
	@<Add literate syntax to finite state machine@>;

@ There's an annoying dance here because some languages have a form of line
comment which can only be used where the comment character(s) is/are the first
non-white-space token on that line: we call those "whole line comments".
That means having to track the difference between general code, and whitespace
at the start of a line inside code. But most languages do not, so we only
want to add this complexity if we have to.

@<Create the finite state machine@> =
	if ((pl) && (Str::len(pl->whole_line_comment) > 0)) {
		whitespace_at_line_start_state = FSM::new_state(I"whitespace");
		sc->machine = FSM::new_machine(whitespace_at_line_start_state);
		FSM::add_entry_transition(code_state, '\n', whitespace_at_line_start_state);
		FSM::add_transition(code_state, '\n', whitespace_at_line_start_state);
		FSM::add_transition(whitespace_at_line_start_state, ' ', whitespace_at_line_start_state);
		FSM::add_transition(whitespace_at_line_start_state, '\t', whitespace_at_line_start_state);
		FSM::add_transition_with_event(whitespace_at_line_start_state, 0, code_state, AGAIN_FSMEVENT);
	} else {
		sc->machine = FSM::new_machine(code_state);
	}

@ Note that this scanner accepts holon names and commands which are empty, or which
contain newlines. That doesn't mean those are legal: they need to be rejected by
the user of the machine.

@e NAME_START_FSMEVENT
@e NAME_END_FSMEVENT

@e COMMAND_START_FSMEVENT
@e COMMAND_END_FSMEVENT

@<Add literate syntax to finite state machine@> =
	if (WebNotation::supports_named_holons(S)) {
		fsm_state *holon_name_state = FSM::new_state(I"holon");
		FSM::add_transition_spelling_out_with_events(code_state,
			WebNotation::notation(S, NAMED_HOLONS_WSF, 1),
			holon_name_state, NO_FSMEVENT, NAME_START_FSMEVENT);
		FSM::add_transition_spelling_out_with_events(holon_name_state,
			WebNotation::notation(S, NAMED_HOLONS_WSF, 2),		
			code_state, NO_FSMEVENT, NAME_END_FSMEVENT);
	}
/*	if (WebNotation::supports_metadata_in_strings(S)) {
		fsm_state *command_name_state = FSM::new_state(I"tangle-command");
		FSM::add_transition_spelling_out_with_events(code_state,
			WebNotation::notation(S, METADATA_IN_STRINGS_WSF, 1),
			command_name_state, NO_FSMEVENT, COMMAND_START_FSMEVENT);
		FSM::add_transition(command_name_state, '"', code_state);
		FSM::add_transition(command_name_state, '\n', code_state);
		FSM::add_transition_spelling_out_with_events(command_name_state,
			WebNotation::notation(S, METADATA_IN_STRINGS_WSF, 2),
			code_state, NO_FSMEVENT, COMMAND_END_FSMEVENT);
	}
*/

@ These are mostly straightforward. For example, if you're scanning code and
you see the notation to start a line comment, then transition to line-comment
state; and stay there until you see a newline, and then revert to code state.

@<Add line comment syntax to finite state machine@> =
	if (Str::len(pl->line_comment) > 0) {
		fsm_state *lc_state = FSM::new_state(I"line-comment");
		FSM::add_transition_spelling_out(code_state, pl->line_comment, lc_state);
		FSM::add_transition(lc_state, '\n', code_state);
	}

@ Almost uniquely, Inform 7 comments respect string literals, so the closing
notation must not occur inside double-quoted matter in a comment.

@<Add multiline comment syntax to finite state machine@> =
	if (Str::len(pl->multiline_comment_open) > 0) {
		fsm_state *mlc_state = FSM::new_state(I"multi-line-comment");
		FSM::add_transition_spelling_out(code_state, pl->multiline_comment_open, mlc_state);
		if (Str::eq(pl->language_name, I"Inform 7")) {
			fsm_state *smlc_state = FSM::new_state(I"string-in-mlc");
			FSM::add_transition_spelling_out(mlc_state, pl->string_literal, smlc_state);
			FSM::add_transition_spelling_out(smlc_state, pl->string_literal, mlc_state);
		}
		FSM::add_transition_spelling_out(mlc_state, pl->multiline_comment_close, code_state);
	}

@<Add whole line comment syntax to finite state machine@> =
	if (Str::len(pl->whole_line_comment) > 0) {
		fsm_state *wlc_state = FSM::new_state(I"whole-line-comment");
		FSM::add_transition_spelling_out(whitespace_at_line_start_state, pl->whole_line_comment, wlc_state);
		FSM::add_transition(wlc_state, '\n', code_state);
	}

@ Also annoyingly, InC and Inform 6 allow tangle commands to be used inside
string literals. We forbid this for most other languages.

@<Add string literal syntax to finite state machine@> =
	if (Str::len(pl->string_literal) > 0) {
		fsm_state *string_state = FSM::new_state(I"string");
		FSM::add_transition_spelling_out(code_state, pl->string_literal, string_state);
		FSM::add_transition_spelling_out(string_state, pl->string_literal, code_state);
		if (WebNotation::supports_metadata_in_strings(S)) {
			fsm_state *smlc_state = FSM::new_state(I"metadata-in-string");
			FSM::add_transition_spelling_out_with_events(string_state,
				WebNotation::notation(S, METADATA_IN_STRINGS_WSF, 1),
				smlc_state, AGAIN_FSMEVENT, COMMAND_START_FSMEVENT);
			FSM::add_transition(smlc_state, '"', code_state);
			FSM::add_transition(smlc_state, '\n', code_state);
			FSM::add_transition_spelling_out_with_events(smlc_state,
				WebNotation::notation(S, METADATA_IN_STRINGS_WSF, 2),
				string_state, AGAIN_FSMEVENT, COMMAND_END_FSMEVENT);
		}
		if (Str::len(pl->string_literal_escape) > 0) {
			fsm_state *escape_state = FSM::new_state_from(string_state);
			FSM::add_transition_spelling_out(string_state, pl->string_literal_escape, escape_state);
			FSM::add_transition(escape_state, 0, string_state);
		}
	}

@ Note the surprising transition here which can terminate a character literal at
a newline (unless it has been backslashed). There can be few if any languages
allowing newlines in character literals, so it really does no harm to have this
rule. We do it to avoid false positives with Preform notation in InC if we don't
allow for this.

@<Add character literal syntax to finite state machine@> =
	if (Str::len(pl->character_literal) > 0) {
		fsm_state *char_state = FSM::new_state(I"character");
		FSM::add_transition_spelling_out(code_state, pl->character_literal, char_state);
		FSM::add_transition_spelling_out(char_state, pl->character_literal, code_state);
		FSM::add_transition(char_state, '\n', code_state);
		if (Str::len(pl->character_literal_escape) > 0) {
			fsm_state *escape_state = FSM::new_state_from(char_state);
			FSM::add_transition_spelling_out(char_state, pl->character_literal_escape, escape_state);
			FSM::add_transition(escape_state, 0, char_state);
		}
	}
