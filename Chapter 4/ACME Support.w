[ACMESupport::] ACME Support.

For generic programming languages by the ACME corporation.

@h One Dozen ACME Explosive Tennis Balls.
Older readers will remember that Wile E. Coyote, when wishing to frustrate
Road Runner with some ingenious device, would invariably buy it from the Acme
Corporation, which manufactured everything imaginable. See Wikipedia, "Acme
Corporation", for much else.

For us, ACME is an imaginary programming language, providing generic support
for comments and syntax colouring. Ironically, this code grew out of a language
actually called ACME: the 6502 assembler of the same name.

=
void ACMESupport::add_fallbacks(programming_language *pl) {	
	if (Methods::provided(pl->methods, PARSE_TYPES_PAR_MTID) == FALSE)
		METHOD_ADD(pl, PARSE_TYPES_PAR_MTID, ACMESupport::parse_types);
	if (Methods::provided(pl->methods, PARSE_FUNCTIONS_PAR_MTID) == FALSE)
		METHOD_ADD(pl, PARSE_FUNCTIONS_PAR_MTID, ACMESupport::parse_functions);
	if (Methods::provided(pl->methods, ANALYSIS_ANA_MTID) == FALSE)
		METHOD_ADD(pl, ANALYSIS_ANA_MTID, ACMESupport::analyse_code);
	if (Methods::provided(pl->methods, POST_ANALYSIS_ANA_MTID) == FALSE)
		METHOD_ADD(pl, POST_ANALYSIS_ANA_MTID, ACMESupport::post_analysis);
	if (Methods::provided(pl->methods, PARSE_COMMENT_TAN_MTID) == FALSE)
		METHOD_ADD(pl, PARSE_COMMENT_TAN_MTID, Painter::parse_comment);
	if (Methods::provided(pl->methods, COMMENT_TAN_MTID) == FALSE)
		METHOD_ADD(pl, COMMENT_TAN_MTID, ACMESupport::comment);
	if (Methods::provided(pl->methods, SHEBANG_TAN_MTID) == FALSE)
		METHOD_ADD(pl, SHEBANG_TAN_MTID, ACMESupport::shebang);
	if (Methods::provided(pl->methods, BEFORE_MACRO_EXPANSION_TAN_MTID) == FALSE)
		METHOD_ADD(pl, BEFORE_MACRO_EXPANSION_TAN_MTID, ACMESupport::before_macro_expansion);
	if (Methods::provided(pl->methods, AFTER_MACRO_EXPANSION_TAN_MTID) == FALSE)
		METHOD_ADD(pl, AFTER_MACRO_EXPANSION_TAN_MTID, ACMESupport::after_macro_expansion);
	if (Methods::provided(pl->methods, START_DEFN_TAN_MTID) == FALSE)
		METHOD_ADD(pl, START_DEFN_TAN_MTID, ACMESupport::start_definition);
	if (Methods::provided(pl->methods, PROLONG_DEFN_TAN_MTID) == FALSE)
		METHOD_ADD(pl, PROLONG_DEFN_TAN_MTID, ACMESupport::prolong_definition);
	if (Methods::provided(pl->methods, END_DEFN_TAN_MTID) == FALSE)
		METHOD_ADD(pl, END_DEFN_TAN_MTID, ACMESupport::end_definition);
	if (Methods::provided(pl->methods, OPEN_IFDEF_TAN_MTID) == FALSE)
		METHOD_ADD(pl, OPEN_IFDEF_TAN_MTID, ACMESupport::I6_open_ifdef);
	if (Methods::provided(pl->methods, CLOSE_IFDEF_TAN_MTID) == FALSE)
		METHOD_ADD(pl, CLOSE_IFDEF_TAN_MTID, ACMESupport::I6_close_ifdef);
	if (Methods::provided(pl->methods, INSERT_LINE_MARKER_TAN_MTID) == FALSE)
		METHOD_ADD(pl, INSERT_LINE_MARKER_TAN_MTID, ACMESupport::insert_line_marker);
	if (Methods::provided(pl->methods, SUPPRESS_DISCLAIMER_TAN_MTID) == FALSE)
		METHOD_ADD(pl, SUPPRESS_DISCLAIMER_TAN_MTID, ACMESupport::suppress_disclaimer);
	if (Methods::provided(pl->methods, BEGIN_WEAVE_WEA_MTID) == FALSE)
		METHOD_ADD(pl, BEGIN_WEAVE_WEA_MTID, ACMESupport::begin_weave);
	if (Methods::provided(pl->methods, RESET_SYNTAX_COLOURING_WEA_MTID) == FALSE)
		METHOD_ADD(pl, RESET_SYNTAX_COLOURING_WEA_MTID, ACMESupport::reset_syntax_colouring);
	if (Methods::provided(pl->methods, SYNTAX_COLOUR_WEA_MTID) == FALSE)
		METHOD_ADD(pl, SYNTAX_COLOUR_WEA_MTID, ACMESupport::syntax_colour);
}

@ This utility does a very limited |WRITE|-like job. (We don't want to use
the actual |WRITE| because that would make it possible for malicious language
files to crash Inweb.)

=
void ACMESupport::expand(OUTPUT_STREAM, text_stream *prototype, text_stream *S,
	int N, filename *F) {
	if (Str::len(prototype) > 0) {
		for (int i=0; i<Str::len(prototype); i++) {
			inchar32_t c = Str::get_at(prototype, i);
			if ((c == '%') && (Str::get_at(prototype, i+1) == 'S') && (S)) {
				WRITE("%S", S);
				i++;
			} else if ((c == '%') && (Str::get_at(prototype, i+1) == 'd') && (N >= 0)) {
				WRITE("%d", N);
				i++;
			} else if ((c == '%') && (Str::get_at(prototype, i+1) == 'f') && (F)) {
				WRITE("%/f", F);
				i++;
			} else {
				PUT(c);
			}
		}
	}
}

@h Tangling methods.

=
void ACMESupport::shebang(programming_language *pl, text_stream *OUT, web *W,
	tangle_target *target) {
	ACMESupport::expand(OUT, pl->shebang, NULL, -1, NULL);
}

void ACMESupport::before_macro_expansion(programming_language *pl,
	OUTPUT_STREAM, para_macro *pmac) {
	ACMESupport::expand(OUT, pl->before_macro_expansion, NULL, -1, NULL);
}

void ACMESupport::after_macro_expansion(programming_language *pl,
	OUTPUT_STREAM, para_macro *pmac) {
	ACMESupport::expand(OUT, pl->after_macro_expansion, NULL, -1, NULL);
}

int ACMESupport::start_definition(programming_language *pl, text_stream *OUT,
	text_stream *term, text_stream *start, section *S, source_line *L) {
	if (LanguageMethods::supports_definitions(pl)) {
		ACMESupport::expand(OUT, pl->start_definition, term, -1, NULL);
		Tangler::tangle_line(OUT, start, S, L);
	}
	return TRUE;
}

int ACMESupport::prolong_definition(programming_language *pl,
	text_stream *OUT, text_stream *more, section *S, source_line *L) {
	if (LanguageMethods::supports_definitions(pl)) {
		ACMESupport::expand(OUT, pl->prolong_definition, NULL, -1, NULL);
		Tangler::tangle_line(OUT, more, S, L);
	}
	return TRUE;
}

int ACMESupport::end_definition(programming_language *pl,
	text_stream *OUT, section *S, source_line *L) {
	if (LanguageMethods::supports_definitions(pl)) {
		ACMESupport::expand(OUT, pl->end_definition, NULL, -1, NULL);
	}
	return TRUE;
}

void ACMESupport::I6_open_ifdef(programming_language *pl,
	text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) ACMESupport::expand(OUT, pl->start_ifdef, symbol, -1, NULL);
	else ACMESupport::expand(OUT, pl->start_ifndef, symbol, -1, NULL);
}

void ACMESupport::I6_close_ifdef(programming_language *pl,
	text_stream *OUT, text_stream *symbol, int sense) {
	if (sense) ACMESupport::expand(OUT, pl->end_ifdef, symbol, -1, NULL);
	else ACMESupport::expand(OUT, pl->end_ifndef, symbol, -1, NULL);
}

void ACMESupport::insert_line_marker(programming_language *pl,
	text_stream *OUT, source_line *L) {
	ACMESupport::expand(OUT, pl->line_marker, NULL,
		L->source.line_count, L->source.text_file_filename);
}

void ACMESupport::comment(programming_language *pl,
	text_stream *OUT, text_stream *comm) {
	if (Str::len(pl->multiline_comment_open) > 0) {
		ACMESupport::expand(OUT, pl->multiline_comment_open, NULL, -1, NULL);
		WRITE(" %S ", comm);
		ACMESupport::expand(OUT, pl->multiline_comment_close, NULL, -1, NULL);
		WRITE("\n");
	} else if (Str::len(pl->line_comment) > 0) {
		ACMESupport::expand(OUT, pl->line_comment, NULL, -1, NULL);
		WRITE(" %S\n", comm);
	} else if (Str::len(pl->whole_line_comment) > 0) {
		ACMESupport::expand(OUT, pl->whole_line_comment, NULL, -1, NULL);
		WRITE(" %S\n", comm);
	}
}

@

=
void ACMESupport::parse_types(programming_language *self, web *W) {
	if (W->main_language->type_notation[0]) {
		chapter *C;
		section *S;
		LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W)) {
			if (S->sect_language == W->main_language) {
				match_results mr = Regexp::create_mr();
				if (Regexp::match(&mr, L->text, W->main_language->type_notation)) {
					Functions::new_function(mr.exp[0], L);
				}
				Regexp::dispose_of(&mr);
			}
		}
	}
}

@

=
void ACMESupport::parse_functions(programming_language *self, web *W) {
	if (W->main_language->function_notation[0]) {
		chapter *C;
		section *S;
		LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W)) {
			if (S->sect_language == W->main_language) {
				match_results mr = Regexp::create_mr();
				if ((L->category != TEXT_EXTRACT_LCAT) &&
					(Regexp::match(&mr, L->text, W->main_language->function_notation))) {
					Functions::new_function(mr.exp[0], L);
				}
				Regexp::dispose_of(&mr);
			}
		}
	}
}

@ The following is an opportunity for us to scold the author for any
violation of the namespace rules. We're going to look for functions named
|Whatever::name()| whose definitions are not in the |Whatever::| section;
in other words, we police the rule that functions actually are defined in the
namespace which their names imply. This can be turned off with a special
bibliographic variable, but don't do that.

=
void ACMESupport::post_analysis(programming_language *self, web *W) {
	int check_namespaces = FALSE;
	if (Str::eq_wide_string(Bibliographic::get_datum(W->md, I"Namespaces"), U"On"))
		check_namespaces = TRUE;
	language_function *fn;
	LOOP_OVER(fn, language_function) {
		hash_table_entry *hte =
			Analyser::find_hash_entry_for_section(fn->function_header_at->owning_section,
				fn->function_name, FALSE);
		if (hte) {
			hash_table_entry_usage *hteu;
			LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages) {
				if ((hteu->form_of_usage & FCALL_USAGE) || (fn->within_namespace))
					if (hteu->usage_recorded_at->under_section != fn->function_header_at->owning_section)
						fn->called_from_other_sections = TRUE;
			}
		}
		if ((fn->within_namespace != fn->called_from_other_sections)
			&& (check_namespaces)
			&& (fn->call_freely == FALSE)) {
			if (fn->within_namespace)
				Main::error_in_web(
					I"Being internally called, this function mustn't belong to a :: namespace",
					fn->function_header_at);
			else
				Main::error_in_web(
					I"Being externally called, this function must belong to a :: namespace",
					fn->function_header_at);
		}
	}
}

@ Having found all those functions and structure elements, we make sure they
are all known to Inweb's hash table of interesting identifiers:

=
void ACMESupport::analyse_code(programming_language *self, web *W) {
	language_function *fn;
	LOOP_OVER(fn, language_function)
		Analyser::find_hash_entry_for_section(fn->function_header_at->owning_section,
			fn->function_name, TRUE);
	language_type *str;
	structure_element *elt;
	LOOP_OVER_LINKED_LIST(str, language_type, W->language_types)
		LOOP_OVER_LINKED_LIST(elt, structure_element, str->elements)
			if (elt->allow_sharing == FALSE)
				Analyser::find_hash_entry_for_section(elt->element_created_at->owning_section,
					elt->element_name, TRUE);
}

@ This is here so that tangling the Standard Rules extension doesn't insert
a spurious comment betraying Inweb's involvement in the process.

=
int ACMESupport::suppress_disclaimer(programming_language *pl) {
	return pl->suppress_disclaimer;
}

@

=
void ACMESupport::begin_weave(programming_language *pl, section *S, weave_order *wv) {
	reserved_word *rw;
	LOOP_OVER_LINKED_LIST(rw, reserved_word, pl->reserved_words)
		Analyser::mark_reserved_word_for_section(S, rw->word, rw->colour);
}

@ ACME has all of its syntax-colouring done by the default engine:

=
void ACMESupport::reset_syntax_colouring(programming_language *pl) {
	Painter::reset_syntax_colouring(pl);
}

int ACMESupport::syntax_colour(programming_language *pl,
	weave_order *wv, source_line *L, text_stream *matter, text_stream *colouring) {
	section *S = L->owning_section;
	hash_table *ht = &(S->sect_target->symbols);
	if ((L->category == TEXT_EXTRACT_LCAT) && (pl != S->sect_language))
		ht = &(pl->built_in_keywords);
	return Painter::syntax_colour(pl, ht, matter, colouring, FALSE);
}
