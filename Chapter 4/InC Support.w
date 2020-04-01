[InCSupport::] InC Support.

To support a modest extension of C called InC.

@h Creation.
As can be seen, InC is a basically C-like language, but in addition to having
all of those methods, it has a whole lot more of its own.

=
programming_language *InCSupport::create(void) {
	programming_language *pl = Languages::new_language(I"InC", I".c");
	pl->supports_namespaces = TRUE;
	CLike::make_c_like(pl);

	METHOD_ADD(pl, FURTHER_PARSING_PAR_MTID, InCSupport::further_parsing);

	METHOD_ADD(pl, SUPPRESS_EXPANSION_TAN_MTID, InCSupport::suppress_expansion);
	METHOD_ADD(pl, TANGLE_COMMAND_TAN_MTID, InCSupport::special_tangle_command);
	METHOD_ADD(pl, ADDITIONAL_PREDECLARATIONS_TAN_MTID, InCSupport::additional_predeclarations);
	METHOD_ADD(pl, WILL_TANGLE_EXTRA_LINE_TAN_MTID, InCSupport::will_insert_in_tangle);
	METHOD_ADD(pl, TANGLE_EXTRA_LINE_TAN_MTID, InCSupport::insert_in_tangle);
	METHOD_ADD(pl, TANGLE_CODE_UNUSUALLY_TAN_MTID, InCSupport::tangle_code);
	METHOD_ADD(pl, GNABEHS_TAN_MTID, InCSupport::gnabehs);
	METHOD_ADD(pl, ADDITIONAL_TANGLING_TAN_MTID, InCSupport::additional_tangling);

	METHOD_ADD(pl, SKIP_IN_WEAVING_WEA_MTID, InCSupport::skip_in_weaving);
	METHOD_ADD(pl, WEAVE_CODE_LINE_WEA_MTID, InCSupport::weave_code_line);
	METHOD_ADD(pl, NOTIFY_NEW_TAG_WEA_MTID, InCSupport::new_tag_declared);

	METHOD_ADD(pl, EARLY_PREWEAVE_ANALYSIS_ANA_MTID, InCSupport::analyse_code);
	METHOD_ADD(pl, SHARE_ELEMENT_ANA_MTID, InCSupport::share_element);
	return pl;
}

@ We will apply this special tag wherever Preform grammar is defined:

=
theme_tag *Preform_theme = NULL;

@h Parsing methods.
We only provide one parsing method, but it's a big one:

=
preform_nonterminal *alphabetical_list_of_nonterminals = NULL;

void InCSupport::further_parsing(programming_language *self, web *W) {
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W)) {
		@<Detect and deal with Preform grammar@>;
		@<Detect and deal with I-literals@>
	}
}

@h Parsing Preform grammar.
This is where we look for declarations of nonterminals. Very little about
the following code will make sense unless you've first read the Preform
section of the |words| module, which is what we're supporting, and seen
some examples of Preform being used in the Inform source code.

In parsing, we categorise the opening lines |PREFORM_LCAT|. Subsequent lines
of grammar are |PREFORM_GRAMMAR_LCAT|; but the lines of InC code inside an
|internal| definition remain just plain |CODE_BODY_LCAT| lines.

@d NOT_A_NONTERMINAL -4
@d A_FLEXIBLE_NONTERMINAL -3
@d A_VORACIOUS_NONTERMINAL -2
@d A_GRAMMAR_NONTERMINAL -1

@<Detect and deal with Preform grammar@> =
	int form = NOT_A_NONTERMINAL; /* one of the four values above, or a non-negative word count */
	TEMPORARY_TEXT(pntname);
	TEMPORARY_TEXT(header);
	@<Parse a Preform nonterminal header line@>;
	if (form != NOT_A_NONTERMINAL) @<Record a Preform nonterminal here@>;
	DISCARD_TEXT(pntname);
	DISCARD_TEXT(header);

@ The keyword |internal| can be followed by an indication of the number
of words the nonterminal will match: usually a decimal non-negative number,
but optionally a question mark |?| to indicate voracity.

@<Parse a Preform nonterminal header line@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, L->text, L"(<%p+>) ::=%c*")) {
		form = A_GRAMMAR_NONTERMINAL;
		Str::copy(pntname, mr.exp[0]);
		Str::copy(header, mr.exp[0]);
		@<Parse the subsequent lines as Preform grammar@>;
	} else if (Regexp::match(&mr, L->text, L"((<%p+>) internal %?) {%c*")) {
		form = A_VORACIOUS_NONTERMINAL;
		Str::copy(pntname, mr.exp[1]);
		Str::copy(header, mr.exp[0]);
	} else if (Regexp::match(&mr, L->text, L"((<%p+>) internal) {%c*")) {
		form = A_FLEXIBLE_NONTERMINAL;
		Str::copy(pntname, mr.exp[1]);
		Str::copy(header, mr.exp[0]);
	} else if (Regexp::match(&mr, L->text, L"((<%p+>) internal (%d+)) {%c*")) {
		form = Str::atoi(mr.exp[2], 0);
		Str::copy(pntname, mr.exp[1]);
		Str::copy(header, mr.exp[0]);
	}
	Regexp::dispose_of(&mr);

@ Each Preform nonterminal defined in the tangle will cause one of these
structures to be created:

=
typedef struct preform_nonterminal {
	struct text_stream *nt_name; /* e.g., |<action-clause>| */
	struct text_stream *unangled_name; /* e.g., |action-clause| */
	struct text_stream *as_C_identifier; /* e.g., |action_clause_NTM| */
	int as_function; /* defined internally, that is, parsed by a C function */
	int voracious; /* a voracious nonterminal: see "The English Syntax of Inform" */
	int min_word_count; /* for internals only */
	int max_word_count;
	int takes_pointer_result; /* right-hand formula defines |*XP|, not |*X| */
	struct source_line *where_defined;
	struct preform_nonterminal *next_pnt_alphabetically;
	MEMORY_MANAGEMENT
} preform_nonterminal;

@ We will

@<Record a Preform nonterminal here@> =
	preform_nonterminal *pnt = CREATE(preform_nonterminal);
	pnt->where_defined = L;
	pnt->nt_name = Str::duplicate(pntname);
	pnt->unangled_name = Str::duplicate(pntname);
	pnt->as_C_identifier = Str::duplicate(pntname);
	pnt->next_pnt_alphabetically = NULL;
	@<Apply unangling cream to name@>;
	@<Compose a C identifier for the nonterminal@>;
	@<Work out the parsing characteristics of the nonterminal@>;

	@<Insertion-sort this this nonterminal into the alphabetical list@>;
	@<Register the nonterminal with the line and paragraph from which it comes@>;

@<Apply unangling cream to name@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, pntname, L"%<(%c*)%>")) pnt->unangled_name = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);

@ When the program we are tangling is eventually running, each nonterminal
will be represented by a pointer to a unique data structure for it. Inweb
automatically compiles code to create these pointers; and here's how it
works out their names.

@<Compose a C identifier for the nonterminal@> =
	Str::delete_first_character(pnt->as_C_identifier);
	LOOP_THROUGH_TEXT(pos, pnt->as_C_identifier) {
		if (Str::get(pos) == '-') Str::put(pos, '_');
		if (Str::get(pos) == '>') { Str::put(pos, 0); break; }
	}
	WRITE_TO(pnt->as_C_identifier, "_NTM");

@ "Artamène ou le Grand Cyrus", by Georges or possibly his sister Madeleine
de Scudéry, published around 1650, runs to 1,954,300 words. If you can write
an Inform source text 500 times longer than that, then you may need to raise
the following definition:

@d INFINITE_WORD_COUNT 1000000000

@<Work out the parsing characteristics of the nonterminal@> =
	pnt->voracious = FALSE; if (form == A_VORACIOUS_NONTERMINAL) pnt->voracious = TRUE;
	pnt->as_function = TRUE; if (form == A_GRAMMAR_NONTERMINAL) pnt->as_function = FALSE;

	pnt->takes_pointer_result = FALSE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, pnt->nt_name, L"<k-%c+")) pnt->takes_pointer_result = TRUE;
	if (Regexp::match(&mr, pnt->nt_name, L"<s-%c+")) pnt->takes_pointer_result = TRUE;
	Regexp::dispose_of(&mr);

	int min = 1, max = form;
	if (form < 0) max = INFINITE_WORD_COUNT;
	if (max == 0) min = 0;
	else if (max != INFINITE_WORD_COUNT) min = max;
	pnt->min_word_count = min;
	pnt->max_word_count = max;

@<Insertion-sort this this nonterminal into the alphabetical list@> =
	if (alphabetical_list_of_nonterminals == NULL) alphabetical_list_of_nonterminals = pnt;
	else {
		int placed = FALSE;
		preform_nonterminal *last = NULL;
		for (preform_nonterminal *seq = alphabetical_list_of_nonterminals; seq;
			seq = seq->next_pnt_alphabetically) {
			if (Str::cmp(pntname, seq->nt_name) < 0) {
				if (seq == alphabetical_list_of_nonterminals) {
					pnt->next_pnt_alphabetically = alphabetical_list_of_nonterminals;
					alphabetical_list_of_nonterminals = pnt;
				} else {
					last->next_pnt_alphabetically = pnt;
					pnt->next_pnt_alphabetically = seq;
				}
				placed = TRUE;
				break;
			}
			last = seq;
		}
		if (placed == FALSE) last->next_pnt_alphabetically = pnt;
	}

@<Register the nonterminal with the line and paragraph from which it comes@> =
	L->preform_nonterminal_defined = pnt;
	if (Preform_theme) Tags::add_to_paragraph(L->owning_paragraph, Preform_theme, NULL);
	L->category = PREFORM_LCAT;
	L->text_operand = Str::duplicate(header);

@h Parsing the body of Preform grammar.
After a line like |<action-clause> ::=|, Preform grammar follows on subsequent
lines until we hit the end of the paragraph, or a white-space line, whichever
comes first. Each line of grammar is categorised |PREFORM_GRAMMAR_LCAT|.
If we have a line with an arrow, like so:

	|porcupine tree  ==>  2|

then the text on the left goes into |text_operand| and the right into
|text_operand2|, with the arrow itself (and white space around it) cut out.

@<Parse the subsequent lines as Preform grammar@> =
	source_line *AL;
	for (AL = L; (AL) && (AL->category == CODE_BODY_LCAT); AL = AL->next_line) {
		if (Regexp::string_is_white_space(AL->text)) break;
		AL->category = PREFORM_GRAMMAR_LCAT;

		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, AL->text, L"(%c+) ==> (%c*)")) {
			AL->text_operand = Str::duplicate(mr.exp[0]);
			AL->text_operand2 = Str::duplicate(mr.exp[1]);
		} else {
			AL->text_operand = AL->text;
			AL->text_operand2 = Str::new();
		}
		@<Remove any C comment from the left side of the arrow@>;
		@<Detect any nonterminal variables being set on the right side of the arrow@>;
		Regexp::dispose_of(&mr);
	}

@ In case we have a comment at the end of the grammar, like this:

	|porcupine tree  /* what happens now? */|

we want to remove it. The regular expression here isn't terribly legible, but
trust me, it's correct.

@<Remove any C comment from the left side of the arrow@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, AL->text_operand, L"(%c*)%/%*%c*%*%/ *"))
		AL->text_operand = Str::duplicate(mr.exp[0]);
	Regexp::dispose_of(&mr);

@ Note that nonterminal variables are, by default, integers. If their names
are divided internally with a colon, however, as |<<structure:name>>|, then
they have the type |structure *|.

@<Detect any nonterminal variables being set on the right side of the arrow@> =
	TEMPORARY_TEXT(to_scan); Str::copy(to_scan, AL->text_operand2);
	match_results mr = Regexp::create_mr();
	while (Regexp::match(&mr, to_scan, L"%c*?<<(%P+?)>> =(%c*)")) {
		TEMPORARY_TEXT(var_given); Str::copy(var_given, mr.exp[0]);
		TEMPORARY_TEXT(type_given); WRITE_TO(type_given, "int");
		Str::copy(to_scan, mr.exp[1]);
		if (Regexp::match(&mr, var_given, L"(%p+):%p+")) {
			Str::clear(type_given);
			WRITE_TO(type_given, "%S *", mr.exp[0]);
		}
		nonterminal_variable *ntv;
		LOOP_OVER(ntv, nonterminal_variable)
			if (Str::eq(ntv->ntv_name, var_given))
				break;
		if (ntv == NULL) @<This one's new, so create a new nonterminal variable@>;
		DISCARD_TEXT(var_given);
		DISCARD_TEXT(type_given);
	}
	DISCARD_TEXT(to_scan);
	Regexp::dispose_of(&mr);

@ Nonterminal variables are actually just global C variables, and their C
identifiers need to avoid hyphens and colons. For example, |<<kind:ref>>|
has identifier |"kind_ref_NTMV"|. Each one is recorded in a structure thus:

=
typedef struct nonterminal_variable {
	struct text_stream *ntv_name; /* e.g., |"num"| */
	struct text_stream *ntv_type; /* e.g., |"int"| */
	struct text_stream *ntv_identifier; /* e.g., |"num_NTMV"| */
	struct source_line *first_mention; /* first usage */
	MEMORY_MANAGEMENT
} nonterminal_variable;

@<This one's new, so create a new nonterminal variable@> =
	ntv = CREATE(nonterminal_variable);
	ntv->ntv_name = Str::duplicate(var_given);
	ntv->ntv_type = Str::duplicate(type_given);
	LOOP_THROUGH_TEXT(P, var_given)
		if ((Str::get(P) == '-') || (Str::get(P) == ':'))
			Str::put(P, '_');
	ntv->ntv_identifier = Str::new();
	WRITE_TO(ntv->ntv_identifier, "%S_NTMV", var_given);
	ntv->first_mention = AL;

@h Parsing I-literals.
A simpler but useful further addition to C is that we recognise a new form
of string literal: |I"quartz"| makes a constant text stream with the content
"quartz".

@<Detect and deal with I-literals@> =
	for (int i = 0, quoted = FALSE; i < Str::len(L->text); i++) {
		if (Str::get_at(L->text, i) == '"')
			if ((Str::get_at(L->text, i-1) != '\\') &&
				((Str::get_at(L->text, i-1) != '\'') || (Str::get_at(L->text, i+1) != '\'')))
					quoted = quoted?FALSE:TRUE;
		if ((fundamental_mode != WEAVE_MODE) && (quoted == FALSE) &&
			(Str::get_at(L->text, i) == 'I') && (Str::get_at(L->text, i+1) == '"'))
			@<This looks like an I-literal@>;
	}

@<This looks like an I-literal@> =
	TEMPORARY_TEXT(lit);
	int i_was = i;
	int ended = FALSE;
	i += 2;
	while (Str::get_at(L->text, i)) {
		if (Str::get_at(L->text, i) == '"') { ended = TRUE; break; }
		PUT_TO(lit, Str::get_at(L->text, i++));
	}
	if (ended) @<This is definitely an I-literal@>;
	DISCARD_TEXT(lit);

@ Each I-literal results in an instance of the following being created. The
I-literal |I"quartz"| would have content |quartz| and identifier something
like |TL_IS_123|.

=
typedef struct text_literal {
	struct text_stream *tl_identifier;
	struct text_stream *tl_content;
	MEMORY_MANAGEMENT
} text_literal;

@ So suppose we've got a line of web such as

	|text_stream *T = I"quartz";|

We create the necessary I-literal, and splice the line so that it now reads
|text_stream *T = TL_IS_123;|. (That's why we don't call any of this on a
weave run; we're actually amending the code of the web.)

@<This is definitely an I-literal@> =
	text_literal *tl = CREATE(text_literal);
	tl->tl_identifier = Str::new();
	WRITE_TO(tl->tl_identifier, "TL_IS_%d", tl->allocation_id);
	tl->tl_content = Str::duplicate(lit);
	TEMPORARY_TEXT(before);
	TEMPORARY_TEXT(after);
	Str::copy(before, L->text);
	Str::truncate(before, i_was);
	Str::copy_tail(after, L->text, i+1);
	Str::clear(L->text);
	WRITE_TO(L->text, "%S%S", before, tl->tl_identifier);
	i = Str::len(L->text);
	WRITE_TO(L->text, "%S", after);
	DISCARD_TEXT(before);
	DISCARD_TEXT(after);

@h Tangling methods.
Suppress the expansion of macros occurring on a line introduced by a |//|
comment. (This avoids problems when tangling code that's been commented out.)

=
int InCSupport::suppress_expansion(programming_language *self, text_stream *material) {
	if ((Str::get_at(material, 0) == '/') && (Str::get_at(material, 1) == '/'))
		return TRUE;
	return FALSE;
}

@ InC does three things which C doesn't: it allows the namespaced function
names like |Section::function()|; it allows Foundation-class-style string
literals marked with an I, |I"like this"|, which we will call I-literals;
and it allows Preform natural language grammar to be mixed in with code.

The following routine is a hook needed for two of these. It recognises
two special tangling commands:

(a) |[[nonterminals]]| tangles to code which initialises the Preform
grammar. (The grammar defines the meaning of nonterminals such as
|<sentence>|. They're not terminal in the sense that they are defined
as combinations of other things.) In practice, this needs to appear once
in any program using Preform. For the Inform project, that's done in the
|words| module of the Inform 7 compiler.

(b) |[[textliterals]]| tangles to code which initialises the I-literals.

=
int InCSupport::special_tangle_command(programming_language *me, OUTPUT_STREAM, text_stream *data) {
	if (Str::eq_wide_string(data, L"nonterminals")) {
		WRITE("register_tangled_nonterminals();\n");
		return TRUE;
	}
	if (Str::eq_wide_string(data, L"textliterals")) {
		WRITE("register_tangled_text_literals();\n");
		return TRUE;
	}
	return FALSE;
}

@ Time to predeclare things. InC is going to create a special function, right
at the end of the code, which "registers" the nonterminals, creating their
run-time data structures; we must predeclare this function. It will set values
for the pointers |action_clause_NTM|, and so on; these are global variables,
which we initially declare as |NULL|.

We also declare the nonterminal variables like |kind_ref_NTMV|, initialising
all integers to zero and all pointers to |NULL|.

We do something similar, but simpler, to declare text stream constants.

=
void InCSupport::additional_predeclarations(programming_language *self, text_stream *OUT, web *W) {
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		if (L->preform_nonterminal_defined) {
			preform_nonterminal *pnt = L->preform_nonterminal_defined;
			Languages::insert_line_marker(OUT, W->main_language, L);
			WRITE("nonterminal *%S = NULL;\n", pnt->as_C_identifier);
		}

	nonterminal_variable *ntv;
	LOOP_OVER(ntv, nonterminal_variable)
		WRITE("%S %S = %s;\n",
			ntv->ntv_type, ntv->ntv_identifier,
			(Str::eq_wide_string(ntv->ntv_type, L"int"))?"0":"NULL");

	WRITE("void register_tangled_nonterminals(void);\n");

	text_literal *tl;
	LOOP_OVER(tl, text_literal)
		WRITE("text_stream *%S = NULL;\n", tl->tl_identifier);

	WRITE("void register_tangled_text_literals(void);\n");
}

@ And here are the promised routines, which appear at the very end of the code.
They make use of macros and data structures defined in the Inform 7 web.

=
void InCSupport::gnabehs(programming_language *self, text_stream *OUT, web *W) {
	WRITE("void register_tangled_nonterminals(void) {\n");
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, Tangler::primary_target(W))
		if (L->preform_nonterminal_defined) {
			preform_nonterminal *pnt = L->preform_nonterminal_defined;
			Languages::insert_line_marker(OUT, W->main_language, L);
			if (pnt->as_function) {
				WRITE("\tINTERNAL_NONTERMINAL(L\"%S\", %S, %d, %d);\n",
					pnt->nt_name, pnt->as_C_identifier,
					pnt->min_word_count, pnt->max_word_count);
				WRITE("\t%S->voracious = %d;\n",
					pnt->as_C_identifier, pnt->voracious);
			} else {
				WRITE("\tREGISTER_NONTERMINAL(L\"%S\", %S);\n",
					pnt->nt_name, pnt->as_C_identifier);
			}
		}
	WRITE("}\n");
	WRITE("void register_tangled_text_literals(void) {\n"); INDENT;
	text_literal *tl;
	LOOP_OVER(tl, text_literal)
		WRITE("%S = Str::literal(L\"%S\");\n", tl->tl_identifier, tl->tl_content);
	OUTDENT; WRITE("}\n");
}

@ That's it for big structural additions to the tangled C code. Now we turn
to how to tangle the lines we've given special categories to.

We need to tangle |PREFORM_LCAT| lines (those holding nonterminal declarations)
in a special way...

=
int InCSupport::will_insert_in_tangle(programming_language *self, source_line *L) {
	if (L->category == PREFORM_LCAT) return TRUE;
	return FALSE;
}

@ ...and this is how. As can be seen, each nonterminal turns into a C function.
In the case of an internal definition, like

	|<k-kind-for-template> internal {|

we tangle this opening line to

	|int k_kind_for_template_NTM(wording W, int *X, void **XP) {|

that is, to a function which returns |TRUE| if it makes a match on the text
excerpt in Inform's source text, |FALSE| otherwise; if it matches and produces
an integer and/or pointer result, these are copied into |*X| and |*XP|. The
remaining lines of the function are tangled unaltered, i.e., following the
same rules as for the body of any other C function.

=
void InCSupport::insert_in_tangle(programming_language *self, text_stream *OUT, source_line *L) {
	preform_nonterminal *pnt = L->preform_nonterminal_defined;
	if (pnt->as_function) {
		WRITE("int %SR(wording W, int *X, void **XP) {\n",
			pnt->as_C_identifier);
	} else {
		WRITE("int %SC(int *X, void **XP, int *R, void **RP, wording *FW, wording W) {\n",
			pnt->as_C_identifier);
		@<Compile the body of the compositor function@>;
		WRITE("}\n");
	}
}

@ On the other hand, a grammar nonterminal tangles to a "compositor function".
Thus the opening line

	|<action-clause> ::=|

tangles to a function header:

	|int action_clause_NTMC(int *X, void **XP, int *R, void **RP, wording *FW, wording W) {|

Subsequent lines of the nonterminal are categorised |PREFORM_GRAMMAR_LCAT|
and thus won't tangle to code at all, by the usual rules; so we tangle from
them directly here.

Composition is what happens after a successful match of the text in the
word range |W|. The idea is that, especially if the pattern was
complicated, we will need to "compose" the results of parsing individual
pieces of it into a result for the whole. These partial results can be found
in the arrays |R[n]| and |RP[n]| passed as parameters; recall that every
nonterminal has in principle both an integer and a pointer result, though
often one or both is undefined.

A simple example would be

	|<cardinal-number> + <cardinal-number> ==> R[1] + R[2]|

where the composition function would be called on a match of, say, "$5 + 7$",
and would find the values 5 and 7 in |R[1]| and |R[2]| respectively. It would
then add these together, store 12 in |*X|, and return |TRUE| to show that all
was well.

A more typical example, drawn from the actual Inform 7 web, is:

	|<k-kind-of-kind> <k-formal-kind-variable> ==> Kinds::variable_construction(R[2], RP[1])|

which says that the composite result -- the right-hand formula -- is formed by
calling a particular routine on the integer result of subexpression 2
(|<k-formal-kind-variable>|) and the pointer result of subexpression 1
(|<k-kind-of-kind>|). The answer, the composite result, that is, must be
placed in |*X| and |*XP|. (Composition functions are also allowed to
invalidate the result, by returning |FALSE|, and have other tricks up their
sleeves, but none of that is handled by Inweb: see the Inform 7 web for more
on this.)

@<Compile the body of the compositor function@> =
	int needs_collation = FALSE;
	for (source_line *AL = L->next_line;
		((AL) && (AL->category == PREFORM_GRAMMAR_LCAT));
		AL = AL->next_line)
			if (Str::len(AL->text_operand2) > 0)
				needs_collation = TRUE;
	if (needs_collation) @<At least one of the grammar lines provided an arrow and formula@>
	else @<None of the grammar lines provided an arrow and formula@>;
	WRITE("\treturn TRUE;\n");

@ In the absence of any |==>| formulae, we simply set |*X| to the default
result supplied; this is the production number within the grammar (0 for the
first line, 1 for the second, and so on) by default, with an undefined pointer.

@<None of the grammar lines provided an arrow and formula@> =
	WRITE("\t*X = R[0];\n");

@<At least one of the grammar lines provided an arrow and formula@> =
	WRITE("\tswitch(R[0]) {\n");
	int c = 0;
	for (source_line *AL = L->next_line;
		((AL) && (AL->category == PREFORM_GRAMMAR_LCAT));
		AL = AL->next_line, c++) {
		text_stream *formula = AL->text_operand2;
		if (Str::len(formula) > 0) {
			WRITE("\t\tcase %d: ", c);
			@<Tangle the formula on the right-hand side of the arrow@>;
			WRITE(";\n");
			WRITE("#pragma clang diagnostic push\n");
			WRITE("#pragma clang diagnostic ignored \"-Wunreachable-code\"\n");
			WRITE("break;\n");
			WRITE("#pragma clang diagnostic pop\n");
		}
	}
	WRITE("\t\tdefault: *X = R[0]; break;\n");
	WRITE("\t}\n");

@ We assume that the RHS of the arrow is an expression to be evaluated,
and that it produces an integer or a pointer according to what the
non-terminal expects as its main result. But we make one exception: if
the formula begins with a paragraph macro, then it can't be an expression,
and instead we read it as code in a void context. (This code will, we
assume, set |*X| and/or |*XP| in some ingenious way of its own.)

Within the body of the formula, we allow a pseudo-macro to work: |WR[n]|
expands to word range |n| in the match which we're compositing. This actually
expands like so:

	|action_clause_NTM->range_result[n]|

which saves a good deal of typing. (A regular C preprocessor macro couldn't
easily do this, because it needs to include the identifier name of the
nonterminal being parsed.)

@<Tangle the formula on the right-hand side of the arrow@> =
	match_results mr = Regexp::create_mr();
	if (!Regexp::match(&mr, formula, L"@<%c*")) {
		if (pnt->takes_pointer_result) WRITE("*XP = ");
		else WRITE("*X = ");
	}
	TEMPORARY_TEXT(expanded);
	for (int i=0; i < Str::len(formula); i++) {
		if ((Str::get_at(formula, i) == 'W') && (Str::get_at(formula, i+1) == 'R') &&
			(Str::get_at(formula, i+2) == '[') &&
			(isdigit(Str::get_at(formula, i+3))) && (Str::get_at(formula, i+4) == ']')) {
				WRITE_TO(expanded,
					"%S->range_result[%c]", pnt->as_C_identifier, Str::get_at(formula, i+3));
				i += 4;
		} else {
			PUT_TO(expanded, Str::get_at(formula, i));
		}
	}
	Tangler::tangle_code(OUT, expanded, AL->owning_section, AL);
	DISCARD_TEXT(expanded);
	Regexp::dispose_of(&mr);

@ Going down from line level to the tangling of little excerpts of C code,
we also provide for some other special extensions to C.

=
void InCSupport::tangle_code(programming_language *self, text_stream *OUT, text_stream *original) {
	int fcall_pos = -1;
	for (int i = 0; i < Str::len(original); i++) {
		@<Double-colons are namespace dividers in function names@>;
		if (Str::get_at(original, i) == '<') {
			if (Str::get_at(original, i+1) == '<') {
				@<Double-angles sometimes delimit Preform variable names@>;
			} else {
				@<Single-angles sometimes delimit Preform nonterminal names@>;
			}
		}
		if (i == fcall_pos) {
			fcall_pos = -1;
			WRITE(", NULL, NULL");
		}
		PUT(Str::get_at(original, i));
	}
}

@ For example, a function name like:

	|Text::Parsing::get_next|

must be rewritten as

	|Text__Parsing__get_next|

since colons aren't valid in C identifiers. The following is prone to all
kinds of misreadings, of course; it picks up any use of |::| between an
alphanumberic character and a letter. In particular, code like

	|printf("Trying Text::Parsing::get_next now.\n");|

will be rewritten as

	|printf("Trying Text__Parsing__get_next now.\n");|

This is probably unwanted, but it doesn't matter, because these Inform-only
extension features of Inweb aren't intended for general use: only for
Inform, where no misreadings occur.

@<Double-colons are namespace dividers in function names@> =
	if ((i > 0) && (Str::get_at(original, i) == ':') && (Str::get_at(original, i+1) == ':') &&
		(isalpha(Str::get_at(original, i+2))) && (isalnum(Str::get_at(original, i-1)))) {
		WRITE("__"); i++;
		continue;
	}

@ Angle brackets around a valid Preform variable name expand into its
C identifier; for example, |<<R>>| becomes |most_recent_result|.
We take no action if it's not a valid name, so |<<fish>>| becomes
just |<<fish>>|.

@<Double-angles sometimes delimit Preform variable names@> =
	match_results mr = Regexp::create_mr();
	TEMPORARY_TEXT(check_this);
	Str::substr(check_this, Str::at(original, i), Str::end(original));
	if (Regexp::match(&mr, check_this, L"<<(%P+)>>%c*")) {
		text_stream *putative = mr.exp[0];
		text_stream *pv_identifier = InCSupport::nonterminal_variable_identifier(putative);
		if (pv_identifier) {
			WRITE("%S", pv_identifier);
			i += Str::len(putative) + 3;
			DISCARD_TEXT(check_this);
			continue;
		}
	}
	DISCARD_TEXT(check_this);
	Regexp::dispose_of(&mr);

@ Similarly for nonterminals; |<k-kind>| might become |k_kind_NTM|.
Here, though, there's a complication:

	|if (<k-kind>(W)) { ...|

must expand to:

	|if (Text__Languages__parse_nt_against_word_range(k_kind_NTM, W, NULL, NULL)) { ...|

This is all syntactic sugar to make it easier to see parsing in action.
Anyway, it means we have to set |fcall_pos| to remember to add in the
two |NULL| arguments when we hit the |)| a little later. We're doing all
of this fairly laxly, but as before: it only needs to work for Inform,
and Inform doesn't cause any trouble.

@<Single-angles sometimes delimit Preform nonterminal names@> =
	match_results mr = Regexp::create_mr();
	TEMPORARY_TEXT(check_this);
	Str::substr(check_this, Str::at(original, i), Str::end(original));
	if (Regexp::match(&mr, check_this, L"(<%p+>)%c*")) {
		text_stream *putative = mr.exp[0];
		preform_nonterminal *pnt = InCSupport::nonterminal_by_name(putative);
		if (pnt) {
			i += Str::len(putative) - 1;
			if (Str::get_at(original, i+1) == '(') {
				int arity = 1;
				for (int j = i+2, bl = 1; ((Str::get_at(original, j)) && (bl > 0)); j++) {
					if (Str::get_at(original, j) == '(') bl++;
					if (Str::get_at(original, j) == ')') { bl--; if (bl == 0) fcall_pos = j; }
					if ((Str::get_at(original, j) == ',') && (bl == 1)) arity++;
				}
				WRITE("Preform__parse_nt_against_word_range(");
			}
			WRITE("%S", pnt->as_C_identifier);
			if (fcall_pos >= 0) {
				WRITE(", "); i++;
			}
			DISCARD_TEXT(check_this);
			continue;
		}
	}
	DISCARD_TEXT(check_this);
	Regexp::dispose_of(&mr);

@ We needed two little routines to find nonterminals and their variables by
name. They're not very efficient, but experience shows that even on a web
the size of Inform 7, there's no significant gain from speeding them up
(with, say, a hash table).

=
preform_nonterminal *InCSupport::nonterminal_by_name(text_stream *name) {
	preform_nonterminal *pnt;
	LOOP_OVER(pnt, preform_nonterminal)
		if (Str::eq(name, pnt->nt_name))
			return pnt;
	return NULL;
}

@ The special variables |<<R>>| and |<<RP>>| hold the results,
integer and pointer, for the most recent successful match. They're defined
in the Inform 7 web (see the code for parsing text against Preform grammars),
not by Inweb.

=
text_stream *InCSupport::nonterminal_variable_identifier(text_stream *name) {
	if (Str::eq_wide_string(name, L"r")) return I"most_recent_result";
	if (Str::eq_wide_string(name, L"rp")) return I"most_recent_result_p";
	nonterminal_variable *ntv;
	LOOP_OVER(ntv, nonterminal_variable)
		if (Str::eq(ntv->ntv_name, name))
			return ntv->ntv_identifier;
	return NULL;
}

@ We saw above that the grammar lines following a non-internal declaration
were divided into actual grammar, then an arrow, then a formula. The formulae
were tangled into "composition functions", but the grammar itself was
simply thrown away. It doesn't appear anywhere in the C code tangled by
Inweb.

So what does happen to it? The answer is that it's transcribed into an
auxiliary file called |Syntax.preform|, which Inform, once it is compiled,
will read in at run-time. This is how that happens:

=
void InCSupport::additional_tangling(programming_language *self, web *W, tangle_target *target) {
	if (NUMBER_CREATED(preform_nonterminal) > 0) {
		pathname *P = Reader::tangled_folder(W);
		filename *Syntax = Filenames::in_folder(P, I"Syntax.preform");

		text_stream TO_struct;
		text_stream *OUT = &TO_struct;
		if (STREAM_OPEN_TO_FILE(OUT, Syntax, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write Preform file", Syntax);

		WRITE_TO(STDOUT, "Writing Preform syntax to: %/f\n", Syntax);

		WRITE("[Preform syntax generated by inweb: do not edit.]\n\n");

		if (Bibliographic::data_exists(W->md, I"Preform Language"))
			WRITE("language %S\n", Bibliographic::get_datum(W->md, I"Preform Language"));

		@<Actually write out the Preform syntax@>;
		STREAM_CLOSE(OUT);
	}
}

@ See the "English Syntax of Inform" document for a heavily annotated
form of the result of the following. Note a useful convention: if the
right-hand side of the arrow in a grammar line uses a paragraph macro which
mentions a problem message, then we transcribe a Preform comment to that
effect. (This really is a comment: Inform ignores it, but it makes the
file more comprehensible to human eyes.) For example,

	|<article> kind ==> @<Issue C8PropertyOfKind problem@>|

(The code in this paragraph macro will indeed issue this problem message, we
assume.)

@<Actually write out the Preform syntax@> =
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, target)
		if (L->category == PREFORM_LCAT) {
			preform_nonterminal *pnt = L->preform_nonterminal_defined;
			if (pnt->as_function)
				WRITE("\n%S internal\n", pnt->nt_name);
			else
				WRITE("\n%S ::=\n", L->text_operand);
			for (source_line *AL = L->next_line;
				((AL) && (AL->category == PREFORM_GRAMMAR_LCAT));
				AL = AL->next_line) {
				WRITE("%S", AL->text_operand);
				match_results mr = Regexp::create_mr();
				if (Regexp::match(&mr, AL->text_operand2, L"%c+Issue (%c+) problem%c+"))
					WRITE("[issues %S]", mr.exp[0]);
				WRITE("\n");
				Regexp::dispose_of(&mr);
			}
		}

@h Weaving.
The following isn't a method, but is called by the weaver directly. It adds
additional endnotes to the woven form of a paragraph which includes Preform
nonterminal definitions:

=
void InCSupport::weave_grammar_index(OUTPUT_STREAM) {
	WRITE("\\raggedright\\tolerance=10000");
	preform_nonterminal *pnt;
	for (pnt = alphabetical_list_of_nonterminals; pnt;
		pnt = pnt->next_pnt_alphabetically) {
		WRITE("\\line{\\nonterminal{%S}%s"
			"\\leaders\\hbox to 1em{\\hss.\\hss}\\hfill {\\xreffont %S}}\n",
			pnt->unangled_name,
			(pnt->as_function)?" (internal)":"",
			pnt->where_defined->owning_section->sect_range);
		int said_something = FALSE;
		@<List where the nonterminal appears in other Preform declarations@>;
		@<List where the nonterminal is called from Inform code@>;
		if (said_something == FALSE)
			WRITE("\\par\\hangindent=3em{\\it unused}\n\n");
	}
	WRITE("\\penalty-1000\n");
	WRITE("\\smallbreak\n");
	WRITE("\\hrule\\smallbreak\n");
}

@<List where the nonterminal is called from Inform code@> =
	section *S;
	LOOP_OVER(S, section) S->scratch_flag = FALSE;
	hash_table_entry *hte = Analyser::find_hash_entry(pnt->where_defined->owning_section, pnt->unangled_name, FALSE);
	hash_table_entry_usage *hteu;
	LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages)
		if (hteu->form_of_usage & PREFORM_IN_CODE_USAGE)
			hteu->usage_recorded_at->under_section->scratch_flag = TRUE;
	int use_count = 0;
	LOOP_OVER(S, section)
		if (S->scratch_flag)
			use_count++;
	if (use_count > 0) {
		said_something = TRUE;
		WRITE("\\par\\hangindent=3em{\\it called from} ");
		int c = 0;
		LOOP_OVER(S, section)
			if (S->scratch_flag) {
				if (c++ > 0) WRITE(", ");
				WRITE("{\\xreffont %S}", S->sect_range);
			}
		WRITE("\n\n");
	}

@<List where the nonterminal appears in other Preform declarations@> =
	section *S;
	LOOP_OVER(S, section) S->scratch_flag = FALSE;
	hash_table_entry *hte = Analyser::find_hash_entry(pnt->where_defined->owning_section, pnt->unangled_name, FALSE);
	hash_table_entry_usage *hteu;
	LOOP_OVER_LINKED_LIST(hteu, hash_table_entry_usage, hte->usages)
		if (hteu->form_of_usage & PREFORM_IN_GRAMMAR_USAGE)
			hteu->usage_recorded_at->under_section->scratch_flag = TRUE;
	int use_count = 0;
	LOOP_OVER(S, section)
		if (S->scratch_flag)
			use_count++;
	if (use_count > 0) {
		said_something = TRUE;
		WRITE("\\par\\hangindent=3em{\\it used by other nonterminals in} ");
		int c = 0;
		LOOP_OVER(S, section)
			if (S->scratch_flag) {
				if (c++ > 0) WRITE(", ");
				WRITE("{\\xreffont %S}", S->sect_range);
			}
		WRITE("\n\n");
	}

@h Weaving methods.
If we're weaving just a document of Preform grammar, then we skip any lines
of C code which appear in |internal| nonterminal definitions:

=
int skipping_internal = FALSE, preform_production_count = 0;

int InCSupport::skip_in_weaving(programming_language *self, weave_target *wv, source_line *L) {
	if ((Preform_theme) && (wv->theme_match == Preform_theme)) {
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, L->text, L"}%c*")) {
			skipping_internal = FALSE; Regexp::dispose_of(&mr); return TRUE; }
		if (skipping_internal) { Regexp::dispose_of(&mr); return TRUE; }
		if (Regexp::match(&mr, L->text, L"<%c*?> internal%c*")) skipping_internal = TRUE;
		Regexp::dispose_of(&mr);
	}
	return FALSE;
}

@ And here is the TeX code for displaying Preform grammar:

=
int InCSupport::weave_code_line(programming_language *self, text_stream *OUT,
	weave_target *wv, web *W, chapter *C, section *S, source_line *L,
	text_stream *matter, text_stream *concluding_comment) {
	if ((Preform_theme) && (wv->theme_match == Preform_theme))
		return Formats::preform_document(OUT, wv, W, C, S, L,
			matter, concluding_comment);
	return FALSE;
}

@ In paragraphs where we spot Preform nonterminals being defined, we're
going to automatically apply the tag |^"Preform"|, but only if it already
exists. We watch for it here:

=
void InCSupport::new_tag_declared(programming_language *self, theme_tag *tag) {
	if (Str::eq_wide_string(tag->tag_name, L"Preform")) Preform_theme = tag;
}

@h Analysis methods.

=
void InCSupport::analyse_code(programming_language *self, web *W) {
	preform_nonterminal *pnt;
	LOOP_OVER(pnt, preform_nonterminal)
		Analyser::find_hash_entry(pnt->where_defined->owning_section, pnt->unangled_name, TRUE);
}

int InCSupport::share_element(programming_language *self, text_stream *elname) {
	if (Str::eq_wide_string(elname, L"word_ref1")) return TRUE;
	if (Str::eq_wide_string(elname, L"word_ref2")) return TRUE;
	if (Str::eq_wide_string(elname, L"next")) return TRUE;
	if (Str::eq_wide_string(elname, L"down")) return TRUE;
	if (Str::eq_wide_string(elname, L"allocation_id")) return TRUE;
	if (Str::eq_wide_string(elname, L"method_set")) return TRUE;
	return FALSE;
}
