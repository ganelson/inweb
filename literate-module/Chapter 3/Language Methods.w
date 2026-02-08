[LanguageMethods::] Language Methods.

To characterise the relevant differences in behaviour between the
various programming languages supported.

@h Introduction.
The conventions for writing, weaving and tangling a web are really quite
independent of the programming language being written, woven or tangled;
Knuth began literate programming with Pascal, but now uses C, and the original
Pascal webs were mechanically translated into C ones with remarkably little
fuss or bother. Modern LP tools, such as |noweb|, aim to be language-agnostic.
But of course if you act the same on all languages, you give up the benefits
which might follow from knowing something about the languages you actually
write in.

Really all of the functionality of languages is provided through method calls,
all of them made from this section. That means a lot of simple wrapper routines
which don't do very much. This section may still be useful to read, since it
documents what amounts to an API.

@h Parsing methods.
We begin with parsing extensions. When these are used, we have already read
the web into chapters, sections and paragraphs, but for some languages we will
need a more detailed picture.

|PARSE_TYPES_PAR_MTID| gives a language to look for type declarations.

@e PARSE_TYPES_PAR_MTID

=
VOID_METHOD_TYPE(PARSE_TYPES_PAR_MTID, programming_language *pl, ls_web *W)
void LanguageMethods::parse_types(ls_web *W, programming_language *pl) {
	VOID_METHOD_CALL(pl, PARSE_TYPES_PAR_MTID, W);
}

@ |PARSE_FUNCTIONS_PAR_MTID| is, similarly, for function declarations.

@e PARSE_FUNCTIONS_PAR_MTID

=
VOID_METHOD_TYPE(PARSE_FUNCTIONS_PAR_MTID, programming_language *pl, ls_web *W)
void LanguageMethods::parse_functions(ls_web *W, programming_language *pl) {
	VOID_METHOD_CALL(pl, PARSE_FUNCTIONS_PAR_MTID, W);
}

@ |FURTHER_PARSING_PAR_MTID| is "further" in that it is called when the main
parser has finished work; it typically looks over the whole web for something
of interest.

@e FURTHER_PARSING_PAR_MTID

=
VOID_METHOD_TYPE(FURTHER_PARSING_PAR_MTID, programming_language *pl, ls_web *W, int weaving)
void LanguageMethods::further_parsing(ls_web *W, programming_language *pl, int weaving) {
	VOID_METHOD_CALL(pl, FURTHER_PARSING_PAR_MTID, W, weaving);
}

@ |SUBCATEGORISE_LINE_PAR_MTID| looks at a single line, after the main parser
has given it a category. The idea is not so much to second-guess the parser
(although we can) but to change to a more exotic category which it would
otherwise never produce.

@e SUBCATEGORISE_LINE_PAR_MTID

=
VOID_METHOD_TYPE(SUBCATEGORISE_LINE_PAR_MTID, programming_language *pl, ls_line *lst)
void LanguageMethods::subcategorise_line(programming_language *pl, ls_line *lst) {
	VOID_METHOD_CALL(pl, SUBCATEGORISE_LINE_PAR_MTID, lst);
}

void LanguageMethods::subcategorise_lines(ls_web *W) {
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
			for (ls_paragraph *par = S->literate_source->first_par; par; par = par->next_par)
				for (ls_chunk *chunk = par->first_chunk; chunk; chunk = chunk->next_chunk)
					for (ls_line *lst = chunk->first_line; lst; lst = lst->next_line)
						if (LiterateSource::is_code_chunk(chunk))
							LanguageMethods::subcategorise_line(WebStructure::section_language(S), lst);
}

@ Comments have different syntax in different languages. The method here is
expected to look for a comment on the |line|, and if so to return |TRUE|,
but not before splicing the non-comment parts of the line before and
within the comment into the supplied strings.

@e PARSE_COMMENT_TAN_MTID

=
INT_METHOD_TYPE(PARSE_COMMENT_TAN_MTID, programming_language *pl, text_stream *line, text_stream *before, text_stream *within)

int LanguageMethods::parse_comment(programming_language *pl,
	text_stream *line, text_stream *before, text_stream *within) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, PARSE_COMMENT_TAN_MTID, line, before, within);
	return rv;
}

@h Tangling methods.
We take these roughly in order of their effects on the tangled output, from
the top to the bottom of the file.

The top of the tangled file is a header called the "shebang". By default,
there's nothing there, but |SHEBANG_TAN_MTID| allows the language to add one.
For example, Perl prints |#!/usr/bin/perl| here.

@e SHEBANG_TAN_MTID

=
VOID_METHOD_TYPE(SHEBANG_TAN_MTID, programming_language *pl, text_stream *OUT, ls_web *W, tangle_target *target)
void LanguageMethods::shebang(OUTPUT_STREAM, programming_language *pl, ls_web *W, tangle_target *target) {
	VOID_METHOD_CALL(pl, SHEBANG_TAN_MTID, OUT, W, target);
}

@ Sometimes we want to put some boilerplate at the top:

@e ADDITIONAL_EARLY_MATTER_TAN_MTID

=
VOID_METHOD_TYPE(ADDITIONAL_EARLY_MATTER_TAN_MTID, programming_language *pl, text_stream *OUT, ls_web *W, tangle_target *target, tangle_docket *docket)
void LanguageMethods::additional_early_matter(text_stream *OUT, programming_language *pl, ls_web *W, tangle_target *target, tangle_docket *docket) {
	VOID_METHOD_CALL(pl, ADDITIONAL_EARLY_MATTER_TAN_MTID, OUT, W, target, docket);
}

@ A tangled file then normally declares "definitions". The following write a
definition of the constant named |term| as the value given. If the value spans
multiple lines, the first-line part is supplied to |START_DEFN_TAN_MTID| and
then subsequent lines are fed in order to |PROLONG_DEFN_TAN_MTID|. At the end,
|END_DEFN_TAN_MTID| is called.

@e START_DEFN_TAN_MTID
@e PROLONG_DEFN_TAN_MTID
@e END_DEFN_TAN_MTID

=
INT_METHOD_TYPE(START_DEFN_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *term, ls_code_excerpt *body, ls_section *S, ls_line *lst, tangle_docket *docket)
INT_METHOD_TYPE(PROLONG_DEFN_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *more, ls_section *S, ls_line *lst, tangle_docket *docket)
INT_METHOD_TYPE(END_DEFN_TAN_MTID, programming_language *pl, text_stream *OUT, ls_section *S, ls_line *lst, tangle_docket *docket)

void LanguageMethods::start_definition(OUTPUT_STREAM, programming_language *pl,
	text_stream *term, ls_code_excerpt *body, ls_section *S, ls_line *lst, tangle_docket *docket) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, START_DEFN_TAN_MTID, OUT, term, body, S, lst, docket);
	if (rv == FALSE)
		WebErrors::issue_at(I"this programming language does not support @d", lst);
}

void LanguageMethods::prolong_definition(OUTPUT_STREAM, programming_language *pl,
	text_stream *more, ls_section *S, ls_line *lst, tangle_docket *docket) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, PROLONG_DEFN_TAN_MTID, OUT, more, S, lst, docket);
	if (rv == FALSE)
		WebErrors::issue_at(I"this programming language does not support multiline @d", lst);
}

void LanguageMethods::end_definition(OUTPUT_STREAM, programming_language *pl,
	ls_section *S, ls_line *lst, tangle_docket *docket) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, END_DEFN_TAN_MTID, OUT, S, lst, docket);
}

@ Then we have some "predeclarations"; for example, for C-like languages we
automatically predeclare all functions, obviating the need for header files.

@e ADDITIONAL_PREDECLARATIONS_TAN_MTID

=
INT_METHOD_TYPE(ADDITIONAL_PREDECLARATIONS_TAN_MTID, programming_language *pl,
	text_stream *OUT, tangle_docket *docket, ls_web *W)
void LanguageMethods::additional_predeclarations(OUTPUT_STREAM, programming_language *pl,
	tangle_docket *docket, ls_web *W) {
	VOID_METHOD_CALL(pl, ADDITIONAL_PREDECLARATIONS_TAN_MTID, OUT, docket, W);
}

@ So much for the special material at the top of a tangle: now we're into
the more routine matter, tangling ordinary paragraphs into code.

Tangle commands can be handled by attaching methods as follows, which return
|TRUE| if they recognised and acted on the command.

@e TANGLE_COMMAND_TAN_MTID

=
INT_METHOD_TYPE(TANGLE_COMMAND_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *data)

int LanguageMethods::special_tangle_command(OUTPUT_STREAM, programming_language *pl, text_stream *data) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, TANGLE_COMMAND_TAN_MTID, OUT, data);
	return rv;
}

@ The following method makes it possible for languages to tangle unorthodox
lines into code.

@e TANGLE_EXTRA_LINE_TAN_MTID

=
VOID_METHOD_TYPE(TANGLE_EXTRA_LINE_TAN_MTID, programming_language *pl, text_stream *OUT, int *did, ls_line *lst, tangle_docket *docket)
void LanguageMethods::insert_in_tangle(OUTPUT_STREAM, int *did, programming_language *pl, ls_line *lst, tangle_docket *docket) {
	VOID_METHOD_CALL(pl, TANGLE_EXTRA_LINE_TAN_MTID, OUT, did, lst, docket);
}

@ In order for C compilers to report C syntax errors on the correct line,
despite rearranging by automatic tools, C conventionally recognises the
preprocessor directive |#line| to tell it that a contiguous extract follows
from the given file; we generate this automatically.

@e INSERT_LINE_MARKER_TAN_MTID

=
VOID_METHOD_TYPE(INSERT_LINE_MARKER_TAN_MTID, programming_language *pl, text_stream *OUT, ls_line *lst)
void LanguageMethods::insert_line_marker(OUTPUT_STREAM, programming_language *pl, ls_line *lst) {
	VOID_METHOD_CALL(pl, INSERT_LINE_MARKER_TAN_MTID, OUT, lst);
}

@ The following hooks are provided so that we can top and/or tail the expansion
of paragraph macros in the code. For example, C-like languages, use this to
splice |{| and |}| around the expanded matter.

@e BEFORE_HOLON_EXPANSION_TAN_MTID
@e AFTER_HOLON_EXPANSION_TAN_MTID

=
VOID_METHOD_TYPE(BEFORE_HOLON_EXPANSION_TAN_MTID, programming_language *pl, tangle_docket *D, text_stream *OUT, ls_paragraph *par)
VOID_METHOD_TYPE(AFTER_HOLON_EXPANSION_TAN_MTID, programming_language *pl, tangle_docket *D, text_stream *OUT, ls_paragraph *par)
void LanguageMethods::before_holon_expansion(OUTPUT_STREAM, programming_language *pl, tangle_docket *D, ls_paragraph *par) {
	VOID_METHOD_CALL(pl, BEFORE_HOLON_EXPANSION_TAN_MTID, D, OUT, par);
}
void LanguageMethods::after_holon_expansion(OUTPUT_STREAM, programming_language *pl, tangle_docket *D, ls_paragraph *par) {
	VOID_METHOD_CALL(pl, AFTER_HOLON_EXPANSION_TAN_MTID, D, OUT, par);
}

@ It's a sad necessity, but sometimes we have to unconditionally tangle code
for a preprocessor to conditionally read: that is, to tangle code which contains
|#ifdef| or similar preprocessor directive.

@e OPEN_IFDEF_TAN_MTID
@e CLOSE_IFDEF_TAN_MTID

=
VOID_METHOD_TYPE(OPEN_IFDEF_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *symbol, int sense)
VOID_METHOD_TYPE(CLOSE_IFDEF_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *symbol, int sense)
void LanguageMethods::open_ifdef(OUTPUT_STREAM, programming_language *pl, text_stream *symbol, int sense) {
	VOID_METHOD_CALL(pl, OPEN_IFDEF_TAN_MTID, OUT, symbol, sense);
}
void LanguageMethods::close_ifdef(OUTPUT_STREAM, programming_language *pl, text_stream *symbol, int sense) {
	VOID_METHOD_CALL(pl, CLOSE_IFDEF_TAN_MTID, OUT, symbol, sense);
}

@ Now a routine to tangle a comment. Languages without comment should write nothing.

@e COMMENT_TAN_MTID

=
VOID_METHOD_TYPE(COMMENT_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *comm)
void LanguageMethods::comment(OUTPUT_STREAM, programming_language *pl, text_stream *comm) {
	VOID_METHOD_CALL(pl, COMMENT_TAN_MTID, OUT, comm);
}

@ The inner code tangler now acts on all code known not to contain CWEB
macros or double-square substitutions. In almost every language this simply
passes the code straight through, printing |original| to |OUT|.

@e TANGLE_LINE_UNUSUALLY_TAN_MTID

=
INT_METHOD_TYPE(TANGLE_LINE_UNUSUALLY_TAN_MTID, programming_language *pl, text_stream *OUT, text_stream *original)
void LanguageMethods::tangle_line(OUTPUT_STREAM, programming_language *pl, text_stream *original) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, TANGLE_LINE_UNUSUALLY_TAN_MTID, OUT, original);
	if (rv == FALSE) WRITE("%S", original);
}

@ We finally reach the bottom of the tangled file, a footer called the "gnabehs":

@e GNABEHS_TAN_MTID

=
VOID_METHOD_TYPE(GNABEHS_TAN_MTID, programming_language *pl, text_stream *OUT, ls_web *W)
void LanguageMethods::gnabehs(OUTPUT_STREAM, programming_language *pl, ls_web *W) {
	VOID_METHOD_CALL(pl, GNABEHS_TAN_MTID, OUT, W);
}

@ But we still aren't quite done, because some languages need to produce
sidekick files alongside the main tangle file. This method exists to give
them the opportunity.

@e ADDITIONAL_TANGLING_TAN_MTID

=
VOID_METHOD_TYPE(ADDITIONAL_TANGLING_TAN_MTID, programming_language *pl, ls_web *W, tangle_target *target)
void LanguageMethods::additional_tangling(programming_language *pl, ls_web *W, tangle_target *target) {
	VOID_METHOD_CALL(pl, ADDITIONAL_TANGLING_TAN_MTID, W, target);
}

@h Weaving methods.
This method shouldn't do any actual weaving: it should simply initialise
anything that the language in question might need later.

@e BEGIN_WEAVE_WEA_MTID

=
VOID_METHOD_TYPE(BEGIN_WEAVE_WEA_MTID, programming_language *pl, ls_section *S, weave_order *wv)
void LanguageMethods::begin_weave(ls_section *S, weave_order *wv) {
	VOID_METHOD_CALL(WebStructure::section_language(S), BEGIN_WEAVE_WEA_MTID, S, wv);
}

@ This method allows languages to tell the weaver to ignore certain lines.

@e SKIP_IN_WEAVING_WEA_MTID

=
INT_METHOD_TYPE(SKIP_IN_WEAVING_WEA_MTID, programming_language *pl, weave_order *wv, ls_line *lst)
int LanguageMethods::skip_in_weaving(programming_language *pl, weave_order *wv, ls_line *lst) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, SKIP_IN_WEAVING_WEA_MTID, wv, lst);
	return rv;
}

@ Languages mostly do syntax colouring by having a "state" (this is now inside
a comment, inside qupted text, and so on); the following method is provided
to reset that state, if so. We will run it once per paragraph for safety's
sake, which minimises the knock-on effect of any colouring mistakes.

@e RESET_SYNTAX_COLOURING_WEA_MTID

=
VOID_METHOD_TYPE(RESET_SYNTAX_COLOURING_WEA_MTID, programming_language *pl)
void LanguageMethods::reset_syntax_colouring(programming_language *pl) {
	VOID_METHOD_CALL_WITHOUT_ARGUMENTS(pl, RESET_SYNTAX_COLOURING_WEA_MTID);
}

@ And this is where colouring is done.

@e SYNTAX_COLOUR_WEA_MTID

=
INT_METHOD_TYPE(SYNTAX_COLOUR_WEA_MTID, programming_language *pl,
	weave_order *wv, ls_line *lst, text_stream *matter, text_stream *colouring)
int LanguageMethods::syntax_colour(programming_language *pl,
	weave_order *wv, ls_line *lst, text_stream *matter, text_stream *colouring,
	pathname *path_to_inweb) {
	for (int i=0; i < Str::len(matter); i++) Str::put_at(colouring, i, PLAIN_COLOUR);
	int rv = FALSE;
	programming_language *colour_as = lst->owning_chunk->extract_language;
	if (colour_as == NULL) colour_as = pl;
	ls_line_analysis *L = (ls_line_analysis *) lst->analysis_ref;
	if (ParagraphTags::is_tagged_with(LiterateSource::par_of_line(lst), I"Preform")) {
		programming_language *prepl = Languages::find(wv->weave_web, I"Preform");
		if ((L->preform_nonterminal_defined) || (L->preform_grammar))
			if (prepl) colour_as = prepl;
	}
	if (colour_as)
		INT_METHOD_CALL(rv, colour_as, SYNTAX_COLOUR_WEA_MTID, wv, lst,
			matter, colouring);
	return rv;
}

@ This method is called for each code line to be woven. If it returns |FALSE|, the
weaver carries on in the normal way. If not, it does nothing, assuming that the
method has already woven something more attractive.

@e WEAVE_CODE_LINE_WEA_MTID

=
INT_METHOD_TYPE(WEAVE_CODE_LINE_WEA_MTID, programming_language *pl, text_stream *OUT, weave_order *wv, ls_web *W,
	ls_chapter *C, ls_section *S, ls_line_analysis *L, text_stream *matter, text_stream *concluding_comment)
int LanguageMethods::weave_code_line(OUTPUT_STREAM, programming_language *pl, weave_order *wv,
	ls_web *W, ls_chapter *C, ls_section *S, ls_line_analysis *L, text_stream *matter, text_stream *concluding_comment) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, WEAVE_CODE_LINE_WEA_MTID, OUT, wv, W, C, S, L, matter, concluding_comment);
	return rv;
}

@h Analysis methods.
These are really a little miscellaneous, but they all have to do with looking
at the code in a web and working out what's going on, rather than producing
any weave or tangle output.

The "preweave analysis" is an opportunity to look through the code before
any weaving of it occurs. It's never called on a tangle run. These methods
are called first and last in the process, respectively. (What happens in
between is essentially that we look for identifiers, for later syntax
colouring purposes.)

@e ANALYSIS_ANA_MTID
@e POST_ANALYSIS_ANA_MTID

=
VOID_METHOD_TYPE(ANALYSIS_ANA_MTID, programming_language *pl, ls_web *W)
VOID_METHOD_TYPE(POST_ANALYSIS_ANA_MTID, programming_language *pl, ls_web *W)
void LanguageMethods::early_preweave_analysis(programming_language *pl, ls_web *W) {
	VOID_METHOD_CALL(pl, ANALYSIS_ANA_MTID, W);
}
void LanguageMethods::late_preweave_analysis(programming_language *pl, ls_web *W) {
	VOID_METHOD_CALL(pl, POST_ANALYSIS_ANA_MTID, W);
}

@ And finally: in InC only, a few structure element names are given very slightly
special treatment, and this method decides which.

@e SHARE_ELEMENT_ANA_MTID

=
INT_METHOD_TYPE(SHARE_ELEMENT_ANA_MTID, programming_language *pl, text_stream *element_name)
int LanguageMethods::share_element(programming_language *pl, text_stream *element_name) {
	int rv = FALSE;
	INT_METHOD_CALL(rv, pl, SHARE_ELEMENT_ANA_MTID, element_name);
	return rv;
}

@h What we support.

=
int LanguageMethods::supports_definitions(programming_language *pl) {
	if (Str::len(pl->start_definition) > 0) return TRUE;
	if (Str::len(pl->prolong_definition) > 0) return TRUE;
	if (Str::len(pl->end_definition) > 0) return TRUE;
	return FALSE;
}
