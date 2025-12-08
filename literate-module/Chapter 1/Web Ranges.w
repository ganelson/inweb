[WebRanges::] Web Ranges.

Short textual descriptions of a range of sections or chapters in a web.

@ Web syntaxes might provide for a section file to declare its own "range", the
slightly odd term we use for a mnemonic string uniquely identifying the section
within its web. But if no range is declared, e.g., for syntaxes not allowing this,
we make one ourselves:

=
text_stream *WebRanges::of(ls_section *S) {
	if (S == NULL) internal_error("no section");
	if (Str::len(S->sect_range) == 0) {
		ls_web *W = S->owning_chapter->owning_web;
		if (W == NULL) internal_error("unowned section");
		int sequential = Conventions::get_int(W, SECTIONS_NUMBERED_SEQUENTIALLY_LSCONVENTION);
		int section_counter = -1;
		int chapter_count = 0;
		ls_chapter *C;
		ls_section *CS;
		LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters) {
			chapter_count++;
			int c = 1;
			LOOP_OVER_LINKED_LIST(CS, ls_section, C->sections) {
				if (S == CS) section_counter = c;
				c++;
			}
		}
		if (section_counter < 0) internal_error("section not in web");
		C = S->owning_chapter;
		@<Concoct a range for section S in chapter C in web W@>;
	}
	return S->sect_range;
}

@<Concoct a range for section S in chapter C in web W@> =
	if (sequential) {
		if (chapter_count > 1) WRITE_TO(S->sect_range, "%S/", C->ch_range);
		WRITE_TO(S->sect_range, "s%d", section_counter);
	} else {
		text_stream *from = S->sect_title;
		int letters_from_each_word = 5;
		do {
			Str::clear(S->sect_range);
			if (chapter_count > 1) WRITE_TO(S->sect_range, "%S/", C->ch_range);
			@<Make the tail using this many consonants from each word@>;
			if (--letters_from_each_word == 0) break;
		} while (Str::len(S->sect_range) > 5);

		@<Terminate with disambiguating numbers in case of collisions@>;
	}

@ We collapse words to an initial letter plus consonants: thus "electricity"
would be "elctrcty", since we don't count "y" as a vowel here.

@<Make the tail using this many consonants from each word@> =
	int sn = 0, sw = Str::len(S->sect_range);
	if (Platform::is_folder_separator(Str::get_at(from, sn))) sn++;
	int letters_from_current_word = 0;
	while ((Str::get_at(from, sn)) && (Str::get_at(from, sn) != '.')) {
		if ((Str::get_at(from, sn) == ' ') || (Str::get_at(from, sn) == '_'))
			letters_from_current_word = 0;
		else {
			if (letters_from_current_word < letters_from_each_word) {
				if (Str::get_at(from, sn) != '-') {
					inchar32_t l = Characters::tolower(Str::get_at(from, sn));
					if ((letters_from_current_word == 0) ||
						((l != 'a') && (l != 'e') && (l != 'i') &&
							(l != 'o') && (l != 'u'))) {
						Str::put_at(S->sect_range, sw++, l);
						Str::put_at(S->sect_range, sw, 0);
						letters_from_current_word++;
					}
				}
			}
		}
		sn++;
	}

@ We never want two sections to have the same range.

@<Terminate with disambiguating numbers in case of collisions@> =
	TEMPORARY_TEXT(original_range)
	Str::copy(original_range, S->sect_range);
	int disnum = 0, collision = FALSE;
	do {
		if (disnum++ > 0) {
			int ldn = 4;
			if (disnum >= 1000) ldn = 3;
			else if (disnum >= 100) ldn = 2;
			else if (disnum >= 10) ldn = 1;
			else ldn = 0;
			Str::clear(S->sect_range);
			WRITE_TO(S->sect_range, "%S", original_range);
			Str::truncate(S->sect_range, Str::len(S->sect_range) - ldn);
			WRITE_TO(S->sect_range, "%d", disnum);
		}
		collision = FALSE;
		ls_chapter *C2;
		ls_section *S2;
		LOOP_OVER_LINKED_LIST(C2, ls_chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S2, ls_section, C2->sections)
				if ((S2 != S) && (Str::eq(S2->sect_range, S->sect_range))) {
					collision = TRUE; break;
				}
	} while (collision);
	DISCARD_TEXT(original_range)

@h Looking up chapters and sections.
Given a range, which chapter or section does it correspond to? There is no
need for this to be at all quick: there are fewer than 1000 sections even
in large webs, and lookup is performed only a few times.

Note that range comparison is case sensitive.

=
ls_chapter *WebRanges::to_chapter(ls_web *W, text_stream *range) {
	ls_chapter *C;
	if (W)
		LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
			if (Str::eq(C->ch_range, range))
				return C;
	return NULL;
}

ls_section *WebRanges::to_section(ls_web *W, text_stream *range) {
	ls_chapter *C;
	ls_section *S;
	if (W)
		LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S, ls_section, C->sections)
				if (Str::eq(S->sect_range, range))
					return S;
	return NULL;
}

@h Ranges and containment.
This provides a sort of partial ordering on ranges, testing if the portion
of the web represented by |range1| is contained inside the portion represented
by |range2|. Note that |"0"| means the entire web, and is what the word |all|
translates to when it's used on the command line.

=
int WebRanges::is_within(text_stream *range1, text_stream *range2) {
	if (Str::eq_wide_string(range2, U"0")) return TRUE;
	if (Str::eq(range1, range2)) return TRUE;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, range2, U"%c+/%c+")) { Regexp::dispose_of(&mr); return FALSE; }
	if (Regexp::match(&mr, range1, U"(%c+)/%c+")) {
		if (Str::eq(mr.exp[0], range2)) { Regexp::dispose_of(&mr); return TRUE; }
	}
	return FALSE;
}
