[Tangler::] The Tangler.

To transcribe a version of the text in the web into a form which
can be compiled as a program.

@h The Master Tangler.
Here's what has happened so far, on a |-tangle| run of Inweb: on any
other sort of run, of course, we would never be in this section of code.
The web was read completely into memory, and then fully parsed, with all
of the arrays and hashes populated. Program Control then sent us straight
here for the tangling to begin...

=
void Tangler::go(web *W, tangle_target *target, filename *dest_file) {
	programming_language *lang = target->tangle_language;
	PRINT("  tangling <%/f> (written in %S)\n", dest_file, lang->language_name);

	text_stream TO_struct;
	text_stream *OUT = &TO_struct;
	if (STREAM_OPEN_TO_FILE(OUT, dest_file, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", dest_file);
	@<Perform the actual tangle@>;
	STREAM_CLOSE(OUT);

	@<Tangle any imported headers@>;
	Languages::additional_tangling(lang, W, target);
}

@ All of the sections are tangled together into one big file, the structure
of which can be seen below.

@d LOOP_OVER_PARAGRAPHS(C, S, T, P)
	LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
		LOOP_OVER_LINKED_LIST(S, section, C->sections)
			if (S->sect_target == T)
				LOOP_OVER_LINKED_LIST(P, paragraph, S->paragraphs)

@<Perform the actual tangle@> =
	/* (a) The shebang line, a header for scripting languages, and other heading matter */
	Languages::shebang(OUT, lang, W, target);
	Languages::disclaimer(OUT, lang, W, target);
	Languages::additional_early_matter(OUT, lang, W, target);
	chapter *C; section *S; paragraph *P;
	LOOP_OVER_PARAGRAPHS(C, S, target, P)
		if ((P->placed_very_early) && (P->defines_macro == NULL))
			Tangler::tangle_paragraph(OUT, P);

	/* (b) Results of |@d| declarations */
	@<Tangle all the constant definitions in section order@>;

	/* (c) Miscellaneous automated C predeclarations */
	Languages::additional_predeclarations(OUT, lang, W);

	/* (d) Above-the-bar code from all of the sections (global variables, and such) */
	LOOP_OVER_PARAGRAPHS(C, S, target, P)
		if ((P->placed_early) && (P->defines_macro == NULL))
			Tangler::tangle_paragraph(OUT, P);

	/* (e) Below-the-bar code: the bulk of the program itself */
	LOOP_OVER_PARAGRAPHS(C, S, target, P)
		if ((P->placed_early == FALSE) && (P->placed_very_early == FALSE) && (P->defines_macro == NULL))
			Tangler::tangle_paragraph(OUT, P);

	/* (f) Opposite of the shebang: a footer */
	Languages::gnabehs(OUT, lang, W);

@ This is the result of all those |@d| definitions; note that these sometimes
extend across multiple lines.

@<Tangle all the constant definitions in section order@> =
	chapter *C;
	section *S;
	LOOP_WITHIN_TANGLE(C, S, target)
		if (L->category == BEGIN_DEFINITION_LCAT)
			if (L->default_defn == FALSE)
				@<Define the constant@>;
	LOOP_WITHIN_TANGLE(C, S, target)
		if (L->category == BEGIN_DEFINITION_LCAT)
			if (L->default_defn) {
				Languages::open_ifdef(OUT, lang, L->text_operand, FALSE);
				@<Define the constant@>;
				Languages::close_ifdef(OUT, lang, L->text_operand, FALSE);
			}
	Enumerations::define_extents(OUT, target, lang);

@<Define the constant@> =
	if (L->owning_paragraph == NULL) Main::error_in_web(I"misplaced definition", L);
	else Tags::open_ifdefs(OUT, L->owning_paragraph);
	Languages::start_definition(OUT, lang,
		L->text_operand,
		L->text_operand2, S, L);
	while ((L->next_line) && (L->next_line->category == CONT_DEFINITION_LCAT)) {
		L = L->next_line;
		Languages::prolong_definition(OUT, lang, L->text, S, L);
	}
	Languages::end_definition(OUT, lang, S, L);
	if (L->owning_paragraph) Tags::close_ifdefs(OUT, L->owning_paragraph);

@<Tangle any imported headers@> =
	filename *F;
	LOOP_OVER_LINKED_LIST(F, filename, W->headers)
		Shell::copy(F, Reader::tangled_folder(W), "");

@ So here is the main tangler for a single paragraph. We basically expect to
act only on |CODE_BODY_LCAT| lines (those containing actual code), unless
something quirky has been done to support a language feature.

=
void Tangler::tangle_paragraph(OUTPUT_STREAM, paragraph *P) {
	Tags::open_ifdefs(OUT, P);
	int contiguous = FALSE;
	for (source_line *L = P->first_line_in_paragraph;
		((L) && (L->owning_paragraph == P)); L = L->next_line) {
		if (Languages::will_insert_in_tangle(P->under_section->sect_language, L)) {
			@<Insert line marker if necessary to show the origin of this code@>;
			Languages::insert_in_tangle(OUT, P->under_section->sect_language, L);
		}
		if ((L->category != CODE_BODY_LCAT) || (L->suppress_tangling)) {
			contiguous = FALSE;
		} else {
			@<Insert line marker if necessary to show the origin of this code@>;
			Tangler::tangle_code(OUT, L->text, P->under_section, L); WRITE("\n");
		}
	}
	Tags::close_ifdefs(OUT, P);
}

@ The tangled file is, as the term suggests, a tangle, with lines coming
from many different origins. Some programming languages (C, for instance)
support a notation to tell the compiler that code has come from somewhere
else; if so, here's where we use it.

@<Insert line marker if necessary to show the origin of this code@> =
	if (contiguous == FALSE) {
		contiguous = TRUE;
		Languages::insert_line_marker(OUT, P->under_section->sect_language, L);
	}

@h The Code Tangler.
All of the final tangled code passes through the following routine.
Almost all of the time, it simply prints |original| verbatim to the file |OUT|.

=
void Tangler::tangle_code(OUTPUT_STREAM, text_stream *original, section *S, source_line *L) {
	int mlen, slen;
	int mpos = Regexp::find_expansion(original, '@', '<', '@', '>', &mlen);
	int spos = Regexp::find_expansion(original, '[', '[', ']', ']', &slen);
	if ((mpos >= 0) && ((spos == -1) || (mpos <= spos)) &&
		(Languages::allow_expansion(S->sect_language, original)))
		@<Expand a paragraph macro@>
	else if (spos >= 0)
		@<Expand a double-square command@>
	else
		Languages::tangle_code(OUT, S->sect_language, original); /* this is usually what happens */
}

@ The first form of escape is a paragraph macro in the middle of code. For
example, we handle

	|if (banana_count == 0) @<Yes, we have no bananas@>;|

by calling the lower-level tangler on |if (banana_count == 0) | (a substring
which we know can't involve any macros, since we are detecting macros from
left to right, and this is to the left of the one we found); then by tangling
the definition of "Yes, we have no bananas"; then by calling the upper-level
code tangler on |;|. (In this case, of course, there's nothing much there,
but in principle it could contain further macros.)

Note that when we've expanded "Yes, we have no bananas" we have certainly
placed code into the tangled file from a different location; that will insert
a |#line| marker for the definition location; and we don't want the eventual
C compiler to think that the code which follows is also from that location.
So we insert a fresh line marker.

@<Expand a paragraph macro@> =
	TEMPORARY_TEXT(temp);
	Str::copy(temp, original); Str::truncate(temp, mpos);
	Languages::tangle_code(OUT, S->sect_language, temp);

	programming_language *lang = S->sect_language;
	for (int i=0; i<mlen-4; i++) Str::put_at(temp, i, Str::get_at(original, mpos+2+i));
	Str::truncate(temp, mlen-4);
	para_macro *pmac = Macros::find_by_name(temp, S);
	if (pmac) {
		Languages::before_macro_expansion(OUT, lang, pmac);
		Tangler::tangle_paragraph(OUT, pmac->defining_paragraph);
		Languages::after_macro_expansion(OUT, lang, pmac);
		Languages::insert_line_marker(OUT, lang, L);
	} else {
		Main::error_in_web(I"unknown macro", L);
		WRITE_TO(STDERR, "Macro is '%S'\n", temp);
		Languages::comment(OUT, lang, temp); /* recover by putting macro name in comment */
	}
	TEMPORARY_TEXT(rest);
	Str::substr(rest, Str::at(original, mpos + mlen), Str::end(original));
	Tangler::tangle_code(OUT, rest, S, L);
	DISCARD_TEXT(rest);
	DISCARD_TEXT(temp);

@ This is a similar matter, except that it expands bibliographic data:

	|printf("This is build [[Build Number]].\n");|

takes the bibliographic data for "Build Number" (as set on the web's contents
page) and substitutes that, so that we end up with (say)

	|printf("This is build 5Q47.\n");|

In some languages there are also special expansions (for example, in
InC |[[nonterminals]]| has a special meaning).

If the text in double-squares isn't recognised, that's not an error: it simply
passes straight through. So |[[water]]| becomes just |[[water]]|.

@<Expand a double-square command@> =
	web *W = S->owning_web;

	TEMPORARY_TEXT(temp);
	for (int i=0; i<spos; i++) PUT_TO(temp, Str::get_at(original, i));
	Languages::tangle_code(OUT, S->sect_language, temp);

	for (int i=0; i<slen-4; i++) Str::put_at(temp, i, Str::get_at(original, spos+2+i));
	Str::truncate(temp, slen-4);
	if (Languages::special_tangle_command(OUT, S->sect_language, temp) == FALSE) {
		if (Bibliographic::look_up_datum(W->md, temp))
			WRITE("%S", Bibliographic::get_datum(W->md, temp));
		else
			WRITE("[[%S]]", temp);
	}

	TEMPORARY_TEXT(rest);
	Str::substr(rest, Str::at(original, spos + slen), Str::end(original));
	Tangler::tangle_code(OUT, rest, S, L);
	DISCARD_TEXT(rest);
	DISCARD_TEXT(temp);

@h Prinary target.
The first target in a web is always the one for the main program.

=
tangle_target *Tangler::primary_target(web *W) {
	if (W == NULL) internal_error("no such web");
	return FIRST_IN_LINKED_LIST(tangle_target, W->tangle_targets);
}
