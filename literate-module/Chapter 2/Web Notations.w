[WebNotation::] Web Notations.

To manage possible notations for writing programs in web form.

@h Introduction.
We want to provide a literate-programming engine which can handle a wide range
of different possible markup notations for LP.

Each notation is represented by a |ls_notation| object:

=
typedef struct ls_notation {
	struct wcl_declaration *declaration;
	struct text_stream *name;

	/* for deciding when a web might be using this notation */
	struct linked_list *recognised_filename_extensions; /* of |text_stream| */

	/* what aspects of LP are allowed under this notation, with what notations */
	int footnotes_in_commentary;
	int holons_trimmed_above;
	int holons_trimmed_below;
	struct text_stream *left_marker[NO_DEFINED_NTNMARKER_VALUES];
	struct text_stream *right_marker[NO_DEFINED_NTNMARKER_VALUES];

	/* how input lines are classified when this notation is used */
	struct ls_classifier *main_classifier;
	struct ls_classifier *residue_classifier[NO_DEFINED_LSNROID_VALUES];
	struct ls_classifier *options_classifier[NO_DEFINED_LSNROID_VALUES];

	/* how index entries are read from the web source */
	struct finite_state_machine *indexing_machine;

	/* how the web source is rewritten before and after classification */
	struct notation_rewriting_machine *preprocessor;
	struct notation_rewriting_machine *postprocessor;
	struct notation_rewriting_machine *code_preprocessor;
	struct notation_rewriting_machine *code_postprocessor;
	struct notation_rewriting_machine *commentary_preprocessor;
	struct notation_rewriting_machine *commentary_postprocessor;

	/* temporarily needed in parsing notation files */
	struct ls_classifier *c_stanza;
	struct notation_rewriting_machine *p_stanza;
	CLASS_DEFINITION
} ls_notation;

@ =
ls_notation *WebNotation::new(text_stream *name) {
	ls_notation *ntn = CREATE(ls_notation);
	ntn->declaration = NULL;
	ntn->name = Str::duplicate(name);
	ntn->recognised_filename_extensions = NEW_LINKED_LIST(text_stream);

	ntn->footnotes_in_commentary = FALSE;
	ntn->holons_trimmed_above = FALSE;
	ntn->holons_trimmed_below = FALSE;
	for (int i=0; i<NO_DEFINED_NTNMARKER_VALUES; i++) {
		ntn->left_marker[i] = NULL;
		ntn->right_marker[i] = NULL;
	}

	ntn->main_classifier = LineClassifiers::new();
	for (int i=0; i<NO_DEFINED_LSNROID_VALUES; i++) {
		ntn->residue_classifier[i] = LineClassifiers::new();
		ntn->options_classifier[i] = LineClassifiers::new();
	}

	ntn->indexing_machine = NULL;

	ntn->preprocessor = WebNotation::new_machine();
	ntn->postprocessor = WebNotation::new_machine();
	ntn->code_preprocessor = WebNotation::new_machine();
	ntn->code_postprocessor = WebNotation::new_machine();
	ntn->commentary_preprocessor = WebNotation::new_machine();
	ntn->commentary_postprocessor = WebNotation::new_machine();

	ntn->c_stanza = NULL;
	ntn->p_stanza = NULL;
	return ntn;
}

@h Identification.
Notations are named Inweb resources, so to find a notation with a given name,
we hand over to the usual resource resolution code.

For historical reasons, |InwebClassic| used to be called web syntax version 2,
which is why "2" is read here as if it were "InwebClassic".

=
ls_notation *WebNotation::notation_by_name(ls_web *W, text_stream *name) {
	if (Str::eq(name, I"2")) name = I"InwebClassic";
	wcl_declaration *X = WCL::resolve_resource(W?(W->declaration):NULL, NOTATION_WCLTYPE, name);
	if (X) return RETRIEVE_POINTER_ls_notation(X->object_declared);
	return NULL;
}

@ Pages inside colony declarations default to |MarkdownCode|, and all other
webs default to |InwebClassic|; though in practice other considerations usually
get in before defaults are resorted to. These will almost certainly be found,
since they're supplied with Inweb.

=
ls_notation *WebNotation::default(int embedded) {
	if (embedded) {
		static ls_notation *default_embedded_notation = NULL;
		if (default_embedded_notation == NULL) {
			wcl_declaration *D = WCL::resolve_resource(NULL, NOTATION_WCLTYPE, I"MarkdownCode");
			if (D) default_embedded_notation = RETRIEVE_POINTER_ls_notation(D->object_declared);
			if (default_embedded_notation == NULL)
				Errors::fatal("Unable to locate notation 'MarkdownCode' for literate programs");
		}
		return default_embedded_notation;
	} else {
		static ls_notation *default_ls_notation = NULL;
		if (default_ls_notation == NULL) {
			wcl_declaration *D = WCL::resolve_resource(NULL, NOTATION_WCLTYPE, I"InwebClassic");
			if (D) default_ls_notation = RETRIEVE_POINTER_ls_notation(D->object_declared);
			if (default_ls_notation == NULL)
				Errors::fatal("Unable to locate notation 'InwebClassic' for literate programs");
		}
		return default_ls_notation;
	}
}

void WebNotation::write_known_notations(OUTPUT_STREAM, ls_web *W) {
	WRITE("I can see the following literate programming notations:\n\n");
	WCL::write_sorted_list_of_resources(OUT, W, NOTATION_WCLTYPE);
}

@ Here we take a guess from a filename:

=
ls_notation *WebNotation::guess_from_filename(ls_web *W, filename *F) {
	TEMPORARY_TEXT(extension)
	TEMPORARY_TEXT(penultimate_extension)
	Filenames::write_final_extension(extension, F);
	Filenames::write_penultimate_extension(penultimate_extension, F);
	ls_notation *result = NULL;
	linked_list *L = WCL::list_resources(W?(W->declaration):NULL, NOTATION_WCLTYPE, NULL);
	wcl_declaration *D;
	LOOP_OVER_LINKED_LIST(D, wcl_declaration, L) {
		ls_notation *T = RETRIEVE_POINTER_ls_notation(D->object_declared);
		text_stream *ext;
		LOOP_OVER_LINKED_LIST(ext, text_stream, T->recognised_filename_extensions)
			if (Str::begins_with(ext, I".*.")) {
				if ((Str::len(penultimate_extension) > 0) && (Str::ends_with(ext, extension))) {
					result = T;
					goto DoubleBreak;
				}
			} else if (Str::eq_insensitive(ext, extension)) {
				result = T;
				goto DoubleBreak;
			}
	}	
	DoubleBreak: ;
	DISCARD_TEXT(penultimate_extension)
	DISCARD_TEXT(extension)
	return result;
}

@h Adoption and adaptation to conventions.
Suppose, then, that the above methods decide that a given web |W| should be read
with notation |ntn|. What happens then?

Not much, right away: we simply set the `Notation` metadata.

=
void WebNotation::adopt_for_web(ls_web *W, ls_notation *ntn) {
	if (W->web_notation != ntn) {
		W->web_notation = ntn;
		if (ntn) Bibliographic::set_datum(W, I"Notation", ntn->name);
	}
}

@ The |ls_notation| is not immutable once created, because it needs to be
tinkered with each time is used with a given web. The reason for this is that
each web has its own conventions, and those override some of the syntaxes
in the notation (or might do). So the following is called whenever a
notation needs to be used in the context of a given set of conventions:

=
void WebNotation::adapt_to_conventions(ls_notation *ntn, linked_list *C) {
	WebNotation::set_markers(ntn, NAMED_HOLONS_NTNMARKER,
		Conventions::get_textual_from(C, HOLON_NAME_SYNTAX_LSCONVENTION),
		Conventions::get_textual2_from(C, HOLON_NAME_SYNTAX_LSCONVENTION));
	WebNotation::set_markers(ntn, FILE_NAMED_HOLONS_NTNMARKER,
		Conventions::get_textual_from(C, FILE_HOLON_NAME_SYNTAX_LSCONVENTION),
		Conventions::get_textual2_from(C, FILE_HOLON_NAME_SYNTAX_LSCONVENTION));
	WebNotation::set_markers(ntn, VERBATIM_CODE_NTNMARKER,
		Conventions::get_textual_from(C, VERBATIM_LSCONVENTION),
		Conventions::get_textual2_from(C, VERBATIM_LSCONVENTION));
	WebNotation::set_markers(ntn, METADATA_IN_STRINGS_NTNMARKER,
		Conventions::get_textual_from(C, METADATA_IN_STRINGS_SYNTAX_LSCONVENTION),
		Conventions::get_textual2_from(C, METADATA_IN_STRINGS_SYNTAX_LSCONVENTION));
	WebNotation::set_markers(ntn, PARAGRAPH_TAGS_NTNMARKER,
		Conventions::get_textual_from(C, TAGS_SYNTAX_LSCONVENTION),
		Conventions::get_textual2_from(C, TAGS_SYNTAX_LSCONVENTION));

	ntn->footnotes_in_commentary =
		Conventions::get_int_from(C, FOOTNOTES_LSCONVENTION);
	ntn->holons_trimmed_above =
		Conventions::get_int_from(C, HOLONS_ARE_TRIMMED_ABOVE_LSCONVENTION);
	ntn->holons_trimmed_below =
		Conventions::get_int_from(C, HOLONS_ARE_TRIMMED_BELOW_LSCONVENTION);

	LineClassifiers::reparse_patterns_with_new_conventions(ntn->main_classifier, C);
	for (int i = 0; i < NO_DEFINED_LSNROID_VALUES; i++) {
		if (ntn->residue_classifier[i])
			LineClassifiers::reparse_patterns_with_new_conventions(ntn->residue_classifier[i], C);
		if (ntn->options_classifier[i])
			LineClassifiers::reparse_patterns_with_new_conventions(ntn->options_classifier[i], C);
	}

	ntn->indexing_machine = WebIndexing::make_indexing_machine(C);
}

@h Notation markers.
These are textual markers occurring inside code or commentary, but not at
convenient line boundaries, such as the "{{" and "}}" used to mark named
holons in |MarkdownCode|. As it turns out, the ones we need all occur in
left/right pairs.

@e NAMED_HOLONS_NTNMARKER from 0          /* notation for holon names */
@e FILE_NAMED_HOLONS_NTNMARKER            /* notation for file holon names */
@e VERBATIM_CODE_NTNMARKER                /* notation for verbatim tangle matter */
@e METADATA_IN_STRINGS_NTNMARKER          /* notation for metadata in strings */
@e PARAGRAPH_TAGS_NTNMARKER               /* paragraphs can be tagged */

=
text_stream *WebNotation::left(ls_notation *ntn, int feature) {
	if ((feature < 0) || (feature >= NO_DEFINED_NTNMARKER_VALUES))
		internal_error("feature out of range");
	return ntn->left_marker[feature];
}

text_stream *WebNotation::right(ls_notation *ntn, int feature) {
	if ((feature < 0) || (feature >= NO_DEFINED_NTNMARKER_VALUES))
		internal_error("feature out of range");
	return ntn->right_marker[feature];
}

void WebNotation::set_markers(ls_notation *ntn, int feature, text_stream *left, text_stream *right) {
	ntn->left_marker[feature] = Str::duplicate(left);
	ntn->right_marker[feature] = Str::duplicate(right);
}

int WebNotation::has_nonempty_markers(ls_notation *ntn, int feature) {
	if ((Str::len(ntn->left_marker[feature]) > 0) &&
		(Str::len(ntn->right_marker[feature]) > 0)) return TRUE;
	return FALSE;
}

int WebNotation::supports_named_holons(ls_notation *ntn) {
	return WebNotation::has_nonempty_markers(ntn, NAMED_HOLONS_NTNMARKER);
}

int WebNotation::supports_verbatim_material(ls_notation *ntn) {
	return WebNotation::has_nonempty_markers(ntn, VERBATIM_CODE_NTNMARKER);
}

int WebNotation::supports_file_named_holons(ls_notation *ntn) {
	return WebNotation::has_nonempty_markers(ntn, FILE_NAMED_HOLONS_NTNMARKER);
}

int WebNotation::supports_metadata_in_strings(ls_notation *ntn) {
	return WebNotation::has_nonempty_markers(ntn, METADATA_IN_STRINGS_NTNMARKER);
}

int WebNotation::supports_paragraph_tags(ls_notation *ntn) {
	return WebNotation::has_nonempty_markers(ntn, PARAGRAPH_TAGS_NTNMARKER);
}

@h Commentary markup.
This is entirely decided by conventions, which is why it isn't explicitly
visible in the |ls_notation| structure. If a notation's declaration says
that commentary uses Markdown, for example, that will be part of the
|Conventions| resource which is a child of the notation declaration.

So in a sense the following pair of functions don't belong here, since they
don't use any part of the |ls_notation|. On the other hand, they're clearly
notational...

=
int WebNotation::commentary_markup(ls_web *W) {
	if (W == NULL) return SIMPLIFIED_COMMENTARY_MARKUPCHOICE;
	return Conventions::get_int(W, COMMENTARY_MARKUP_LSCONVENTION);
}

markdown_variation *WebNotation::commentary_variation(ls_web *W) {
	int markup = WebNotation::commentary_markup(W);
	switch (markup) {
		case SIMPLIFIED_COMMENTARY_MARKUPCHOICE:
			return MarkdownVariations::simplified_Inweb_flavoured_Markdown();
		case MARKDOWN_COMMENTARY_MARKUPCHOICE:
			return MarkdownVariations::Inweb_flavoured_Markdown();
		case TEX_COMMENTARY_MARKUPCHOICE:
			return MarkdownVariations::TeX_flavoured_Markdown();
	}
	internal_error("unsupported commentary variation");
}

@h Reading notation definitions.
We can read in a whole directory of these...

=
void WebNotation::read_definitions(pathname *P) {
	scan_directory *D = Directories::open(P);
	TEMPORARY_TEXT(leafname)
	while (Directories::next(D, leafname)) {
		if (Platform::is_folder_separator(Str::get_last_char(leafname)) == FALSE) {
			filename *F = Filenames::in(P, leafname);
			WebNotation::read_definition(F);
		}
	}
	DISCARD_TEXT(leafname)
	Directories::close(D);
}

@ ...or just a single file...

=
ls_notation *WebNotation::read_definition(filename *F) {
	wcl_declaration *D = WCL::read_just_one(F, NOTATION_WCLTYPE);
	if (D == NULL) return NULL;
	return RETRIEVE_POINTER_ls_notation(D->object_declared);
}

@ And notations can also arise as resources nested inside other WCL resources,
such as webs or colonies. In all these cases, though, we end up having to
parse the lines of a WCL declaration for the notation, as follows.

There is a possibly unnecessary little dance here to deal with notations
which have no explicit name: it's unclear whether we should even support those,
but for what it's worth, we call them |NamelessNotation|, |NamelessNotation2|,
..., in order of discovery.

=
ls_notation *WebNotation::parse_declaration(wcl_declaration *D) {
	ls_notation *ntn = WebNotation::new(I"_pending_naming_only");
	ntn->declaration = D;
	@<Parse lines of the declaration@>;
	D->object_declared = STORE_POINTER_ls_notation(ntn);
	if (Str::eq(ntn->name, I"_pending_naming_only")) {
		ntn->name = Str::duplicate(D->name);
		if (Str::len(ntn->name) == 0) {
			static int nameless_notations = 0;
			nameless_notations++;
			Str::clear(ntn->name);
			WRITE_TO(ntn->name, "NamelessNotation");
			if (nameless_notations > 1) WRITE_TO(ntn->name, "%d", nameless_notations);
		}
	} else if (WCL::check_name(D, ntn->name) == FALSE) {
		TEMPORARY_TEXT(msg)
		WRITE_TO(msg, "language has two different names, '%S' and '%S'",
			D->name, ntn->name);
		WCL::error(D, &(D->declaration_position), msg);
		DISCARD_TEXT(msg)
	}
	return ntn;
}

@<Parse lines of the declaration@> =
	text_file_position tfp = D->body_position;
	text_stream *L;
	LOOP_OVER_LINKED_LIST(L, text_stream, D->declaration_lines) {
		TEMPORARY_TEXT(line)
		Str::copy(line, L);
		WebNotation::read_definition_line(line, &tfp, (void *) ntn);
		DISCARD_TEXT(line);
		tfp.line_count++;
	}
	if ((ntn->c_stanza) || (ntn->p_stanza)) {
		WCL::error(ntn->declaration, &tfp, I"notation ended without 'end'");
	}

@ Each line of the declaration funnels in turn through this function:

=
void WebNotation::read_definition_line(text_stream *line, text_file_position *tfp, void *v_state) {
	ls_notation *ntn = (ls_notation *) v_state;
	Str::trim_white_space(line);
	text_stream *error = WebNotation::apply_definition_line(ntn, line);
	if (Str::len(error) > 0) WCL::error(ntn->declaration, tfp, error);
}

@ The following either acts on a line, or does nothing and returns a non-empty
text which represents an error message.

"Stanzas" are the blocks of lines occurring between, say, |classify| and |end|.
Some make changes to classifiers, others to processing machines. If our line
is in a classifier stanza, |ntn->c_stanza| is set to that classifier; if in
a processing stanza, similarly for |ntn->p_stanza|; and they cannot both be
set at the same time. Stanzas cannot be nested.

=
text_stream *WebNotation::apply_definition_line(ls_notation *ntn, text_stream *cmd) {
	text_stream *error = NULL;
	match_results mr = Regexp::create_mr();
	if (Str::is_whitespace(cmd)) @<Setting done@>;
	if ((ntn->c_stanza) || (ntn->p_stanza)) {
		@<Inside stanzas@>
	} else {
		@<Entering processor stanzas@>;
		@<Entering classifier stanzas@>;
		@<Miscellaneous settings@>;
	}
	error = Str::new();
	WRITE_TO(error, "unknown inweb notation command '%S'", cmd);
	@<Setting done@>;
}

@<Entering processor stanzas@> =
	if (Regexp::match(&mr, cmd, U"preprocess")) {
		ntn->p_stanza = ntn->preprocessor; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"postprocess")) {
		ntn->p_stanza = ntn->postprocessor; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"process code")) {
		ntn->p_stanza = ntn->code_preprocessor; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"postprocess code")) {
		ntn->p_stanza = ntn->code_postprocessor; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"process commentary")) {
		ntn->p_stanza = ntn->commentary_preprocessor; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"postprocess commentary")) {
		ntn->p_stanza = ntn->commentary_postprocessor; @<Setting done@>;
	}

@<Entering classifier stanzas@> =
	if (Regexp::match(&mr, cmd, U"classify")) {
		ntn->c_stanza = ntn->main_classifier; @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"residue of (%C+)")) {
		int R = LineClassifiers::outcome_by_name(mr.exp[0]);
		if (R == NO_LSNROID) {
			error = Str::new();
			WRITE_TO(error, "unknown outcome '%S'", mr.exp[0]);
		} else {
			ntn->c_stanza = ntn->residue_classifier[R];
		}
		@<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"options of (%C+)")) {
		int R = LineClassifiers::outcome_by_name(mr.exp[0]);
		if (R == NO_LSNROID) {
			error = Str::new();
			WRITE_TO(error, "unknown outcome '%S'", mr.exp[0]);
		} else {
			ntn->c_stanza = ntn->options_classifier[R];
		}
		@<Setting done@>;
	}

@<Miscellaneous settings@> =
	if (Regexp::match(&mr, cmd, U"name \"(%C+)\"")) {
		ntn->name = Str::duplicate(mr.exp[0]); @<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"recognise (.%C+)")) {
		text_stream *ext = Str::duplicate(mr.exp[0]);
		ADD_TO_LINKED_LIST(ext, text_stream, ntn->recognised_filename_extensions);
		@<Setting done@>;
	}
	if (Regexp::match(&mr, cmd, U"end")) {
		error = I"unexpected 'end'";
		@<Setting done@>;
	}		

@ Inside a stanza, the only content allowed is a grammar rule.

@<Inside stanzas@> =
	if (Regexp::match(&mr, cmd, U"end")) {
		ntn->c_stanza = NULL; ntn->p_stanza = NULL;
		@<Setting done@>;
	}		
	if (ntn->c_stanza) {
		if (Regexp::match(&mr, cmd, U"(%c*?) ==> (%c*)")) {
			error = LineClassifiers::parse_rule(ntn->c_stanza, mr.exp[0], mr.exp[1]);
		} else if (Regexp::match(&mr, cmd, U" *==> (%c*)")) {
			error = LineClassifiers::parse_rule(ntn->c_stanza, NULL, mr.exp[0]);
		} else {
			error = Str::new();
			WRITE_TO(error, "not a grammar line: '%S'", cmd);
		}
		@<Setting done@>;
	}
	if (ntn->p_stanza) {
		if (Regexp::match(&mr, cmd, U"(%c*?) ==> (%c*)")) {
			error = WebNotation::add_rewrite(ntn, ntn->p_stanza, mr.exp[0], mr.exp[1]);
		} else {
			error = Str::new();
			WRITE_TO(error, "not a process line: '%S'", cmd);
		}
		@<Setting done@>;
	}

@ And, in all cases, this is where we end up.

@<Setting done@> =
	Regexp::dispose_of(&mr);
	return error;

@ All WCL declarations are first parsed and then "resolved". There's actually
nothing to do at the resolution stage except to tell the conventions system
how important our choices are (relative to languages, webs, etc.):

=
void WebNotation::resolve_declaration(wcl_declaration *D) {
	Conventions::set_level(D, NOTATION_LSCONVENTIONLEVEL);
}

@h Processing.
A "notation rewriting machine" is a form of finite state machine, set to recognise
the patterns needing to be rewritten.

=
typedef struct notation_rewriting_machine {
	struct finite_state_machine *fsm;
	struct fsm_state *base_state;
	CLASS_DEFINITION
} notation_rewriting_machine;

notation_rewriting_machine *WebNotation::new_machine(void) {
	notation_rewriting_machine *nrm = CREATE(notation_rewriting_machine);
	nrm->base_state = FSM::new_state(I"base");
	nrm->fsm = FSM::new_machine(nrm->base_state);
	return nrm;
}

@ When the machine spots a rewrite, it then signals an |INWEB_REWRITE_FSMEVENT|,
which is supplemented by a pointer to one of these structures:

@e INWEB_REWRITE_FSMEVENT

=
typedef struct notation_rewriter {
	struct text_stream *from;
	struct text_stream *to;
	CLASS_DEFINITION
} notation_rewriter;

@ And the following sets that up:

=
text_stream *WebNotation::add_rewrite(ls_notation *ntn, notation_rewriting_machine *nrm,
	text_stream *from, text_stream *to) {
	if (nrm == NULL) internal_error("no fsm");
	text_stream *error = NULL;
	notation_rewriter *nr = CREATE(notation_rewriter);
	nr->from = Str::duplicate(from);
	nr->to = Str::new();
	for (int i=0; i<Str::len(to); i++) {
		if (Str::includes_at(to, i, I"<SPACE>")) {
			PUT_TO(nr->to, ' ');
			i += 6;
		} else if (Str::includes_at(to, i, I"<NOTHING>")) {
			i += 8;
		} else if (Str::includes_at(to, i, I"<TAB>")) {
			PUT_TO(nr->to, '\t');
			i += 5;
		} else if (Str::includes_at(to, i, I"<LEFTANGLE>")) {
			PUT_TO(nr->to, '<');
			i += 11;
		} else if (Str::includes_at(to, i, I"<RIGHTANGLE>")) {
			PUT_TO(nr->to, '>');
			i += 12;
		} else {
			PUT_TO(nr->to, Str::get_at(to, i));
		}
	}
	
	FSM::add_transition_spelling_out_with_events_and_parameter(nrm->base_state, from,
		nrm->base_state, NO_FSMEVENT, INWEB_REWRITE_FSMEVENT, STORE_POINTER_notation_rewriter(nr));
	return error;
}

@ So much for building the rewriting machine: using it is easier.

=
void WebNotation::rewrite(OUTPUT_STREAM, text_stream *text, notation_rewriting_machine *nrm) {
	FSM::reset_machine(nrm->fsm);
	for (int i=0; i<Str::len(text); i++) {
		inchar32_t c = Str::get_at(text, i);
		PUT(c);
		int event = FSM::cycle_machine(nrm->fsm, c, NULL);
		if (event == INWEB_REWRITE_FSMEVENT) {
			general_pointer parameter = FSM::get_last_parameter(nrm->fsm);
			notation_rewriter *nr = RETRIEVE_POINTER_notation_rewriter(parameter);
			int backspace = Str::len(nr->from);
			Str::truncate(OUT, Str::len(OUT) - backspace);
			WRITE("%S", nr->to);
		}
	}
}

@ And in particular:

=
void WebNotation::postprocess(text_stream *text, ls_notation *ntn) {
	if (Str::len(text) == 0) return;
	TEMPORARY_TEXT(processed)
	WebNotation::rewrite(processed, text, ntn->postprocessor);
	if (Str::ne(processed, text)) { Str::clear(text); Str::copy(text, processed); }
	DISCARD_TEXT(processed)
}
