[Enumerations::] Enumerated Constants.

To define sequentially numbered values for families of constants.

@ The idea here is that each enumeration set is a sequence of named constants
with a given postfix: for example, |HARRY_ST|, |NEVILLE_ST|, |ANGELINA_ST|
form the |*_ST| set. By definition, the postfix part is the portion of the
name following the final underscore, so in this case |ST|.

Each set of constants begins at a given value (typically 0) and then
increments sequentially in definition order.

=
typedef struct enumeration_set {
	struct text_stream *postfix;
	struct text_stream *stub;
	int first_value;
	int next_free_value;
	struct ls_line *last_observed_at;
	struct ls_section *last_observed_in;
	CLASS_DEFINITION
} enumeration_set;

@ There won't be enough sets to make a hash table worth the overhead, so
compare all against all:

=
enumeration_set *Enumerations::find(text_stream *post) {
	enumeration_set *es = NULL;
	LOOP_OVER(es, enumeration_set)
		if (Str::eq(post, es->postfix))
			return es;
	return NULL;
}

@ The following is called when an enumeration is found. If |from| has a
sensible value, this is the start of a new enumeration set; otherwise it's
a further constant in what ought to be an existing set.

=
void Enumerations::define(OUTPUT_STREAM, text_stream *symbol,
	text_stream *from, ls_line *lst, ls_section *S) {
	TEMPORARY_TEXT(pf)
	@<Find the postfix in this symbol name@>;
	enumeration_set *es = Enumerations::find(pf);
	if (Str::len(from) == 0) @<Continue existing set@>
	else @<Begin new set@>;
	DISCARD_TEXT(pf)
	if (es) {
		es->last_observed_at = lst;
		es->last_observed_in = S;
	}
}

@ So for instance |HARRY_ST| to |ST|:

@<Find the postfix in this symbol name@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, symbol, U"%c*_(%C+?)")) Str::copy(pf, mr.exp[0]);
	else {
		WebErrors::issue_at(I"enumeration constants must belong to a _FAMILY", lst);
		WRITE_TO(pf, "BOGUS");
	}
	Regexp::dispose_of(&mr);

@<Continue existing set@> =
	if (es) {
		if (es->stub) WRITE("(%S+", es->stub);
		WRITE("%d", es->next_free_value++);
		if (es->stub) WRITE(")");
	} else WebErrors::issue_at(I"this enumeration _FAMILY is unknown", lst);

@<Begin new set@> =
	if (es) WebErrors::issue_at(I"this enumeration _FAMILY already exists", lst);
	else {
		es = CREATE(enumeration_set);
		es->postfix = Str::duplicate(pf);
		es->stub = NULL;
		if ((Str::len(from) < 8) &&
			((Regexp::match(NULL, from, U"%d+")) ||
				(Regexp::match(NULL, from, U"-%d+")))) {
			es->first_value = Str::atoi(from, 0);
			es->next_free_value = es->first_value + 1;
		} else {
			es->stub = Str::duplicate(from);
			es->first_value = 0;
			es->next_free_value = 1;
		}
	}
	if (es->stub) WRITE("(%S+", es->stub);
	WRITE("%d", es->first_value);
	if (es->stub) WRITE(")");

@ For each set, a further constant is defined to give the range; for example,
we would have |NO_DEFINED_ST_VALUES| set to 3. This is notionally placed in
the code at the last line on which an |*_ST| value was defined.

=
void Enumerations::define_extents(OUTPUT_STREAM, tangle_target *target,
	programming_language *lang, tangle_docket *docket) {
	enumeration_set *es;
	LOOP_OVER(es, enumeration_set) {
		TEMPORARY_TEXT(symbol)
		TEMPORARY_TEXT(value)
		WRITE_TO(symbol, "NO_DEFINED_%S_VALUES", es->postfix);
		WRITE_TO(value, "%d", es->next_free_value - es->first_value);
		LanguageMethods::start_definition(OUT, lang, symbol, value,
			es->last_observed_in, es->last_observed_at, docket);
		LanguageMethods::end_definition(OUT, lang,
			es->last_observed_in, es->last_observed_at, docket);
		DISCARD_TEXT(symbol)
		DISCARD_TEXT(value)
	}
}
