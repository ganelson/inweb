[Tangler::] The Tangler.

Transforming code written in literate programming notation into regular code,
fit for a compiler.

@ The code in this section was substantially redeveloped in 2025. Before that
time, a "simple tangler" provided minimal tangling support: just enough to
handle kit source, but notably not providing for definitions, or holons.
In 2025 more or less all of what had been Inweb was turned into foundation
library material in order that the tangler here could become a full-strength
tangler, and not a much-reduced stopgap.

It can nevertheless be used with some flexibility, and doesn't have to work
on an entire web: it can also tangle text in memory.

During any tangle, a collection of settings is held in an instance of the
following:

=
typedef struct tangle_docket {
	void (*command_callback)(struct text_stream *, struct text_stream *,
		struct text_stream *, struct tangle_docket *);
	void (*bplus_callback)(struct text_stream *, struct tangle_docket *);
	void (*source_marker_callback)(struct text_stream *, struct tangle_docket *);
	void (*error_callback)(struct text_file_position *, char *, struct text_stream *);
	void *state;
	struct text_file_position at;
	struct tangle_target *target;
} tangle_docket;

@ The idea here is that a docket contains optional callback functions to
deal with situations arising during the tangle. In each case they can be
|NULL|, to take no special action.

=
tangle_docket Tangler::new_docket(
	void (*B)(struct text_stream *, struct text_stream *,
		struct text_stream *, struct tangle_docket *),
	void (*C)(struct text_stream *, struct tangle_docket *),
	void (*D)(struct text_stream *, struct tangle_docket *),
	void (*E)(struct text_file_position *, char *, struct text_stream *),
	void *initial_state) {
	tangle_docket docket;
	docket.command_callback = B;
	docket.bplus_callback = C;
	docket.source_marker_callback = D;
	docket.error_callback = E;
	docket.state = initial_state;
	docket.at = TextFiles::nowhere();
	docket.target = NULL;
	return docket;
}

@ This tangles just a small excerpt of code held as text in memory, i.e., not to
be read in from a file somewhere. Note that since we never create a surrounding
web for this material to live in (instead we'll create a single literate
source unit), we call down to the lower levels of the tangler, and skip the
upper levels concerned with the web superstructure.

=
void Tangler::tangle_code_with_docket(OUTPUT_STREAM, tangle_docket *docket, text_stream *text,
	text_file_position origin, programming_language *language) {
	docket->target = TangleTargets::ad_hoc_target(language);
	docket->at = origin;
	ls_unit *lsu = LiterateSource::code_fragment_to_unit(WebSyntax::default(), language,
		text, docket->at);
	Tangler::report_errors(docket, lsu);
	Tangler::tangle_holons_in_segment(OUT, lsu, docket, MAIN_TANGLE_SEGMENT);
}

@ Otherwise, we'll be tangling an entire web.

As a convenience, this loads the web at a given path, and then tangles it.
But we need to know in advance what programming language the program is.

=
void Tangler::tangle_web_directory_with_docket(OUTPUT_STREAM, tangle_docket *docket,
	pathname *P, programming_language *language) {
	wcl_declaration *D = WCL::read_web_or_halt(P, NULL);
	ls_web *W = WebStructure::from_declaration(D);
	WebStructure::set_language(W, language);
	WebStructure::read_web_source(W, FALSE, FALSE);
	docket->target = TangleTargets::primary_target(W);
	Tangler::tangle_web_inner(OUT, docket, W, NULL);
}

@ But the most general way to tangle a web already loaded in is to use this:

=
void Tangler::tangle_web(OUTPUT_STREAM, ls_web *W, pathname *extracts_path,
	tangle_target *target) {
	tangle_docket docket = Tangler::new_docket(NULL, NULL, NULL, NULL, NULL);
	docket.target = target;
	Tangler::tangle_web_inner(OUT, &docket, W, extracts_path);
}

@ When a paragraph contains a holon of code, it might belong to any of three
"segments": though in practice almost all of the program is in the main one.
Only code specially marked as early or very early is an exception.

@d VERY_EARLY_TANGLE_SEGMENT 1
@d EARLY_TANGLE_SEGMENT 2
@d MAIN_TANGLE_SEGMENT 3

=
int Tangler::segment_of_par(ls_paragraph *par) {
	if (LiterateSource::par_contains_very_early_code(par)) return VERY_EARLY_TANGLE_SEGMENT;
	if (LiterateSource::par_contains_early_code(par)) return EARLY_TANGLE_SEGMENT;
	return MAIN_TANGLE_SEGMENT;
}

@ We will also need a way to report any parsing errors, since the likelihood
is that they have been silently noted up to now.

=
void Tangler::report_errors(tangle_docket *docket, ls_unit *lsu) {
	if (docket->error_callback) {
		ls_error *error;
		LOOP_OVER_LINKED_LIST(error, ls_error, lsu->errors) {
			if (error->warning) {
				TEMPORARY_TEXT(msg)
				WRITE_TO(msg, "warning: %S", error->message);
				(*(docket->error_callback))(&(error->tfp), "tangle warning: '%S'", msg);
				DISCARD_TEXT(msg)
			} else {
				(*(docket->error_callback))(&(error->tfp), "tangle error: '%S'", error->message);
			}
		}
	}
}

@ So, then, the following shows the basic structure of tangle output.

=
void Tangler::tangle_web_inner(OUTPUT_STREAM, tangle_docket *docket, ls_web *W,
	pathname *extracts_path) {
	tangle_target *target = docket->target;
	if (target == NULL) internal_error("tangling web with no language");
	programming_language *language = target->tangle_language;
	if (language == NULL) internal_error("tangling web with no language");
	
	ls_chapter *C; ls_section *S;
	LOOP_OVER_TARGET_SECTIONS(C, S, target)
		Tangler::report_errors(docket, S->literate_source);

	LanguageMethods::shebang(OUT, language, W, target);
	LanguageMethods::additional_early_matter(OUT, language, W, target, docket);
	
	LOOP_OVER_TARGET_SECTIONS(C, S, target)
		Tangler::tangle_holons_in_segment(OUT, S->literate_source, docket, VERY_EARLY_TANGLE_SEGMENT);

	@<Tangle all the constant definitions in section order@>;
	LanguageMethods::additional_predeclarations(OUT, language, W);

	LOOP_OVER_TARGET_SECTIONS(C, S, target)
		Tangler::tangle_holons_in_segment(OUT, S->literate_source, docket, EARLY_TANGLE_SEGMENT);

	LOOP_OVER_TARGET_SECTIONS(C, S, target)
		Tangler::tangle_holons_in_segment(OUT, S->literate_source, docket, MAIN_TANGLE_SEGMENT);

	LanguageMethods::gnabehs(OUT, language, W);

	if (extracts_path) {
		@<Tangle any imported headers@>;
		@<Tangle any extract files not part of the target itself@>;
	}
	LanguageMethods::additional_tangling(language, W, target);
}

@<Tangle all the constant definitions in section order@> =
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_TARGET_CHUNKS(C, S, target)
		if (L_chunk->chunk_type == DEFINITION_LSCT)
			if ((L_chunk->metadata.minor == DEFINE_COMMAND_MINLC) ||
				(L_chunk->metadata.minor == ENUMERATE_COMMAND_MINLC))
				@<Define the constant@>;
	LOOP_OVER_TARGET_CHUNKS(C, S, target)
		if (L_chunk->chunk_type == DEFINITION_LSCT)
			if (L_chunk->metadata.minor == DEFAULT_COMMAND_MINLC) {
				LanguageMethods::open_ifdef(OUT, language, L_chunk->symbol_defined, FALSE);
				@<Define the constant@>;
				LanguageMethods::close_ifdef(OUT, language, L_chunk->symbol_defined, FALSE);
			}
	Enumerations::define_extents(OUT, target, language, docket);

@<Define the constant@> =
	IfdefTags::open_ifdefs(OUT, L_par);
	ls_line *lst = L_chunk->first_line;
	LanguageMethods::start_definition(OUT, language,
		L_chunk->symbol_defined, L_chunk->symbol_value, S, lst, docket);
	while ((lst) && (lst->next_line)) {
		lst = lst->next_line;
		LanguageMethods::prolong_definition(OUT, language, lst->text, S, lst, docket);
	}
	LanguageMethods::end_definition(OUT, language, S, lst, docket);
	IfdefTags::close_ifdefs(OUT, L_par);

@ Some C programs, in particular, may need additional header files added to
any tangle in order for them to compile. (The Inform project uses this to
get around the lack of some POSIX facilities on Windows.)

@<Tangle any imported headers@> =
	filename *F;
	LOOP_OVER_LINKED_LIST(F, filename, W->header_filenames)
		Shell::copy(F, WebStructure::tangled_folder(W), "");

@ The following simple implementation splices raw lines from text (probably
code, or configuration gobbledegook) marked as "to ...", giving a leafname.
We place files of those leafnames in the same directory as the tangle target.

@d MAX_EXTRACT_FILES 10

@<Tangle any extract files not part of the target itself@> =
	text_stream *extract_names[MAX_EXTRACT_FILES];
	text_stream extract_files[MAX_EXTRACT_FILES];
	int no_extract_files = 0;
	ls_chapter *C; ls_section *S;
	LOOP_OVER_TARGET_CHUNKS(C, S, target)
		if (Str::len(L_chunk->extract_to) > 0)
			for (ls_line *lst = L_chunk->first_line; lst; lst = lst->next_line) {
				int j = no_extract_files;
				for (int i=0; i<no_extract_files; i++) 
					if (Str::eq(L_chunk->extract_to, extract_names[i])) j = i;
				if (j == no_extract_files) {
					if (j == MAX_EXTRACT_FILES)
						Errors::fatal("too many extract files in tangle");
					extract_names[j] = Str::duplicate(L_chunk->extract_to);
					filename *F = Filenames::in(extracts_path, L_chunk->extract_to);
					if (STREAM_OPEN_TO_FILE(&(extract_files[j]), F, UTF8_ENC) == FALSE)
						Errors::fatal_with_file("unable to write extract file", F);
					no_extract_files++;
				}
				WRITE_TO(&(extract_files[j]), "%S\n", lst->text);
			}
	for (int i=0; i<no_extract_files; i++) STREAM_CLOSE(&(extract_files[i]));

@ A traditional LP tool might tangle only the main holon, i.e., the first in
the web, which would then include all of the others. But we allow nameless
holons to be concatenated into the program, which is much simpler.

=
void Tangler::tangle_holons_in_segment(OUTPUT_STREAM, ls_unit *lsu,
	tangle_docket *docket, int segment) {
	if (lsu == NULL) internal_error("no holon");
	for (ls_paragraph *par = lsu->first_par; par; par = par->next_par)
		if ((par->holon) && (Str::len(par->holon->holon_name) == 0))
			if (segment == Tangler::segment_of_par(par)) {
				IfdefTags::open_ifdefs(OUT, par);
				Tangler::tangle_holon(OUT, par->holon, docket);
				IfdefTags::close_ifdefs(OUT, par);
			}
}

@ Note that this function is recursive: that's how holons incorporate each
other, in a tangle. We enter it with a nameless holon, then it calls itself
to include tangled contents of any named holons referred to, and so on.

=
void Tangler::tangle_holon(OUTPUT_STREAM, ls_holon *holon, tangle_docket *docket) {
	if (holon == NULL) internal_error("no holon");
	tangle_target *target = docket->target;
	if (target == NULL) internal_error("tangling holon with no target");
	holon_splice *splice;
	ls_line *last_line = NULL;
	int next_line_does_not_follow = TRUE;
	LOOP_OVER_LINKED_LIST(splice, holon_splice, holon->splice_list) {
		ls_line *lst = splice->line;
		if (lst != last_line) {
			if (last_line != NULL) WRITE("\n");
			last_line = lst;
			int did_insert = FALSE;
			LanguageMethods::insert_in_tangle(OUT, &(did_insert), target->tangle_language, lst, docket);
			if (did_insert) next_line_does_not_follow = TRUE;
		}
		if (lst->suppress_tangling) {
			next_line_does_not_follow = TRUE;
			continue;
		}
		if (next_line_does_not_follow) {
			Tangler::tangle_line_marker(OUT, lst, docket);
			next_line_does_not_follow = FALSE;
		}
		@<Tangle this splice@>;
	}
	if (last_line != NULL) WRITE("\n");
	WRITE("\n");
}

@ Much of the complexity here lies in tracking whether we need to insert another
line marker or not. These are compiler features saying "the next line derived
from line X of file Y, and any errors in it should be reported as if from there".
In principle we could be safe by providing a line marker in front of every line
we ever tangle, but that would be very cumbersome. So we simply mark lines where
we can't prove that they immediately follow the previous line.

=
void Tangler::tangle_line_marker(OUTPUT_STREAM, ls_line *lst, tangle_docket *docket) {
	docket->at = lst->origin;
	if (docket->source_marker_callback) {
		(*(docket->source_marker_callback))(OUT, docket);
	} else {
		LanguageMethods::insert_line_marker(OUT, docket->target->tangle_language, lst);
	}
}

@ We sometimes want to tangle a line in isolation, not an entire holon, and then
we really can't be sure that a line marker is unnecessary, so we always issue one.

=
void Tangler::tangle_line(OUTPUT_STREAM, ls_line *lst, tangle_docket *docket) {
	if (lst->owning_chunk == NULL) internal_error("loose line");
	ls_holon *holon = lst->owning_chunk->holon;
	if (holon == NULL) internal_error("no holon");
	Tangler::tangle_line_marker(OUT, lst, docket);
	holon_splice *splice;
	LOOP_OVER_LINKED_LIST(splice, holon_splice, holon->splice_list)
		if (lst == splice->line)
			@<Tangle this splice@>;
	WRITE("\n");
}

@ Whether tangling a holon or just a line, then, we need this:

@<Tangle this splice@> =
	if (splice->expansion) @<Recursively tangle this named holon in@>
	else if (Str::len(splice->command) > 0) @<Act on this tangler command@>
	else @<Tangle in this splice of raw content@>;

@ Here's the recursion taking place:

@<Recursively tangle this named holon in@> =
	if (docket->target) 
		LanguageMethods::before_holon_expansion(OUT,
			docket->target->tangle_language, splice->expansion->corresponding_chunk->owner);
	Tangler::tangle_holon(OUT, splice->expansion, docket);
	if (docket->target) 
		LanguageMethods::after_holon_expansion(OUT,
			docket->target->tangle_language, splice->expansion->corresponding_chunk->owner);
	Tangler::tangle_line_marker(OUT, splice->line, docket);

@ This is a similar matter, except that it expands bibliographic data:
= (text)
	printf("This is build [[Build Number]].\n");
=
takes the bibliographic data for "Build Number" (as set on the web's contents
page) and substitutes that, so that we end up with (say)
= (text as C)
	printf("This is build 5Q47.\n");
=
In some languages there are also special expansions (for example, in
InC |[[nonterminals]]| has a special meaning).

If the text in double-squares isn't recognised, that's not an error: it simply
passes straight through. So |[[water]]| becomes just |[[water]]|.

@<Act on this tangler command@> =
	int handled = LanguageMethods::special_tangle_command(OUT, docket->target->tangle_language, splice->command);
	ls_syntax *S = holon->corresponding_chunk->owner->owning_unit->syntax;
	if (handled == FALSE) {
		ls_section *sect = LiterateSource::section_of_par(holon->corresponding_chunk->owner);
		if (sect) {
			ls_web *W = sect->owning_chapter->owning_web;
			if ((W) && (Bibliographic::look_up_datum(W, splice->command))) {
				WRITE("%S", Bibliographic::get_datum(W, splice->command));
				handled = TRUE;
			}
		}
	}
	if (handled == FALSE) {
		WRITE("%S%S%S", WebSyntax::notation(S, TANGLER_COMMANDS_WSF, 1),
			splice->command, WebSyntax::notation(S, TANGLER_COMMANDS_WSF, 2));
	}

@<Tangle in this splice of raw content@> =
	if ((splice->from == 0) && (splice->to == Str::len(splice->line->text) - 1)) {
		Tangler::tangle_illiterate_code_fragment(OUT, splice->line->text, docket);
	} else {
		if ((splice->from < 0) || (splice->to >= Str::len(splice->line->text))) {
			WRITE_TO(STDERR, "Splice out of range: %d to %d in %S with len %d\n",
				splice->from, splice->to, splice->line->text, Str::len(splice->line->text));
			internal_error("splice out of range");
		}
		TEMPORARY_TEXT(text)
		for (int i=splice->from; i<=splice->to; i++)
			PUT_TO(text, Str::get_at(splice->line->text, i));
		Tangler::tangle_illiterate_code_fragment(OUT, text, docket);
		DISCARD_TEXT(text)
	}

@ Before we get down to illiterate code (i.e., code with all literate programming
syntax removed), here's a convenient way to tangle a small text which may,
nevertheless, still contain some markup for named holons:

=
void Tangler::tangle_literate_code_fragment(OUTPUT_STREAM, text_stream *code,
	tangle_docket *docket, ls_line *lst) {
	ls_unit *lsu = LiterateSource::unit_of_line(lst);
	text_stream *hopen = NULL, *hclose = NULL;
	if (WebSyntax::supports(lsu->syntax, NAMED_HOLONS_WSF)) {
		hopen = WebSyntax::notation(lsu->syntax, NAMED_HOLONS_WSF, 1);
		hclose = WebSyntax::notation(lsu->syntax, NAMED_HOLONS_WSF, 2);
	}
	finite_state_machine *machine =
		HolonSyntax::get(lsu->syntax, docket->target->tangle_language);
	FSM::reset_machine(machine);
	TEMPORARY_TEXT(name)
	TEMPORARY_TEXT(output)
	for (int i=0; i<Str::len(code); i++) {
		inchar32_t c = Str::get_at(code, i);
		int event = FSM::cycle_machine(machine, c);
		PUT_TO(name, c);
		PUT_TO(output, c);
		switch (event) {
			case NAME_START_FSMEVENT: {
				Str::clear(name);
				break;
			}
			case NAME_END_FSMEVENT: {
				int excess = Str::len(hclose);
				Str::truncate(name, Str::len(name) - excess);
				ls_paragraph *defining_par = Holons::find_holon(name, lsu);
				if (defining_par) {
					int excess = Str::len(hopen) + Str::len(name) + Str::len(hclose);
					Str::truncate(output, Str::len(output) - excess);
					LanguageMethods::before_holon_expansion(output,
						docket->target->tangle_language, defining_par);
					Tangler::tangle_holon(output, defining_par->holon, docket);
					LanguageMethods::after_holon_expansion(output,
						docket->target->tangle_language, defining_par);
				}
				break;
			}
		}
	}
	DISCARD_TEXT(name)
	Tangler::tangle_illiterate_code_fragment(OUT, output, docket);
}

@ At last, genuinely illiterate code. It might seem that the thing now is just
to print it verbatim to the output, but we still have to deal with two markup
syntaxes used internally in the Inform compiler, and which trigger callbacks.

If we're tangling a literate program in the ordinary way, those callback
functions won't be in the docket, so we will indeed just print the text,
and this function will exit very quickly.

=
void Tangler::tangle_illiterate_code_fragment(OUTPUT_STREAM, text_stream *text,
	tangle_docket *docket) {
	if ((docket->command_callback) || (docket->bplus_callback)) {
		TEMPORARY_TEXT(command)
		TEMPORARY_TEXT(argument)
		int sfp = 0;
		inchar32_t cr = 0;
		do {
			Str::clear(command);
			Str::clear(argument);
			@<Read next character@>;
			NewCharacter: if (cr == 0) break;
			@<Deal with material which isn't commentary@>;
		} while (cr != 0);
		DISCARD_TEXT(command)
		DISCARD_TEXT(argument)
	} else if (docket->target) {
		LanguageMethods::tangle_line(OUT, docket->target->tangle_language, text);
	} else {
		WRITE("%S", text);
	}
}

@<Read next character@> =
	cr = Str::get_at(text, sfp++);

@<Deal with material which isn't commentary@> =
	if (cr == '{') {
		@<Read next character@>;
		if ((cr == '-') && (docket->command_callback)) {
			@<Read up to the next close brace as a braced command and argument@>;
			if (Str::get_first_char(command) == '!') continue;
			(*(docket->command_callback))(OUT, command, argument, docket);
			continue;
		} else { /* otherwise the open brace was a literal */
			PUT_TO(OUT, '{');
			goto NewCharacter;
		}
	}
	if ((cr == '(') && (docket->bplus_callback)) {
		@<Read next character@>;
		if (cr == '+') {
			@<Read up to the next plus close-bracket as an I7 expression@>;
			continue;
		} else { /* otherwise the open bracket was a literal */
			PUT_TO(OUT, '(');
			goto NewCharacter;
		}
	}
	PUT_TO(OUT, cr);

@ And here we read a normal command. The command name must not include |}|
or |:|. If there is no |:| then the argument is left unset (so that it will
be the empty string: see above). The argument must not include |}|.

@<Read up to the next close brace as a braced command and argument@> =
	Str::clear(command);
	Str::clear(argument);
	int com_mode = TRUE;
	while (TRUE) {
		@<Read next character@>;
		if ((cr == '}') || (cr == 0)) break;
		if ((cr == ':') && (com_mode)) { com_mode = FALSE; continue; }
		if (com_mode) PUT_TO(command, cr);
		else PUT_TO(argument, cr);
	}

@ And similarly, for the |(+| ... |+)| notation which was once used to mark
I7 material within I6:

@<Read up to the next plus close-bracket as an I7 expression@> =
	TEMPORARY_TEXT(material)
	while (TRUE) {
		@<Read next character@>;
		if (cr == 0) break;
		if ((cr == ')') && (Str::get_last_char(material) == '+')) {
			Str::delete_last_character(material); break; }
		PUT_TO(material, cr);
	}
	(*(docket->bplus_callback))(material, docket);
	DISCARD_TEXT(material)

