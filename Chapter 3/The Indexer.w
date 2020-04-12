[Indexer::] The Indexer.

To construct indexes of the material woven, following a template.

@h Cover sheets.
The indexer offers two basic services. One, which is much simpler, makes
cover sheets, and has only simple escapes (except that it has the ability
to call the fuller indexing service if need be, using |[[Template T]]|).

=
void Indexer::cover_sheet_maker(OUTPUT_STREAM, web *W, text_stream *unextended_leafname,
	weave_target *wt, int halves) {
	cover_sheet_state state;
	@<Clear the cover sheet state@>;

	TEMPORARY_TEXT(extended_leafname);
	WRITE_TO(extended_leafname, "%S%S", unextended_leafname, Formats::file_extension(wt->format));
	filename *cs_filename = Patterns::obtain_filename(wt->pattern, extended_leafname);
	DISCARD_TEXT(extended_leafname);

	TextFiles::read(cs_filename, FALSE, "can't open cover sheet file", TRUE,
		Indexer::scan_cover_line, NULL, (void *) &state);
}

@ The cover-sheet-maker has the ability to weave only the top half, or only
the bottom half, of the template; they are divided by the marker |[[Code]]|.

@d WEAVE_FIRST_HALF 1
@d WEAVE_SECOND_HALF 2
@d IN_SECOND_HALF 4

=
typedef struct cover_sheet_state {
	struct text_stream *WEAVE_COVER_TO;
	int halves; /* a bitmap of the above values */
	struct weave_target *target;
} cover_sheet_state;

@<Clear the cover sheet state@> =
	state.halves = halves;
	state.WEAVE_COVER_TO = OUT;
	state.target = wt;

@ The above, then, iterates the following routine on each line of the template
file one by one, passing it a pointer to an instance of the above state
structure.

=
void Indexer::scan_cover_line(text_stream *line, text_file_position *tfp, void *v_state) {
	cover_sheet_state *state = (cover_sheet_state *) v_state;
	text_stream *OUT = state->WEAVE_COVER_TO;
	int include = FALSE;
	if (((state->halves & WEAVE_FIRST_HALF) &&
			((state->halves & IN_SECOND_HALF) == 0)) ||
		((state->halves & WEAVE_SECOND_HALF) &&
			(state->halves & IN_SECOND_HALF))) include = TRUE;

	TEMPORARY_TEXT(matter);
	Str::copy(matter, line);
	match_results mr = Regexp::create_mr();
	if ((include) && ((state->target->self_contained) || (state->target->pattern->embed_CSS)) &&
		(Regexp::match(&mr, matter, L" *%<link href=%\"(%c+?)\"%c*"))) {
		
		filename *CSS_file = Patterns::obtain_filename(state->target->pattern, mr.exp[0]);
		Indexer::transcribe_CSS(matter, CSS_file);
	} else {
		while (Regexp::match(&mr, matter, L"(%c*?)%[%[(%c*?)%]%](%c*)")) {
			text_stream *left = mr.exp[0];
			text_stream *command = mr.exp[1];
			text_stream *right = mr.exp[2];
			if (include) WRITE("%S", left);
			@<Deal with a double-squares escape in a cover sheet@>;
			Str::copy(matter, right);
		}
	}
	Regexp::dispose_of(&mr);
	if (include) WRITE("%S\n", matter);
	DISCARD_TEXT(matter);
}

@<Deal with a double-squares escape in a cover sheet@> =
	match_results mr2 = Regexp::create_mr();
	if (Str::eq_wide_string(command, L"Code")) {
		state->halves |= IN_SECOND_HALF;
	} else if (Str::eq_wide_string(command, L"Plugins")) {
		weave_plugin *wp;
		LOOP_OVER_LINKED_LIST(wp, weave_plugin, state->target->plugins)
			WeavePlugins::include(OUT, state->target->weave_web, wp,
				state->target->pattern);
	} else if (Str::eq_wide_string(command, L"Cover Sheet")) {
		if (include) @<Weave in the parent pattern's cover sheet@>;
	} else if (Regexp::match(&mr2, command, L"Navigation")) {
		if (include) @<Weave in navigation@>;
	} else if (Regexp::match(&mr2, command, L"Template (%c*?)")) {
		if (include) @<Weave in an index@>;
	} else if (Bibliographic::data_exists(state->target->weave_web->md, command)) {
		if (include) @<Weave in the value of this variable name@>;
	} else {
		if (include) WRITE("%S", command);
	}
	Regexp::dispose_of(&mr2);

@<Weave in the parent pattern's cover sheet@> =
	if (state->target->pattern->based_on) {
		weave_pattern *saved = state->target->pattern;
		state->target->pattern = state->target->pattern->based_on;
		Indexer::cover_sheet_maker(OUT, state->target->weave_web,
			I"cover-sheet", state->target,
			(state->halves & (WEAVE_FIRST_HALF + WEAVE_SECOND_HALF)));
		state->target->pattern = saved;
	} else {
		Errors::in_text_file("cover sheet recursively includes itself", tfp);
	}

@<Weave in navigation@> =
	pathname *P = Filenames::get_path_to(state->target->weave_to);
	Indexer::nav_column(OUT, P, state->target->weave_web, state->target->weave_range,
		state->target->pattern, state->target->navigation,
		Filenames::get_leafname(state->target->weave_to));

@<Weave in an index@> =
	pathname *P = Filenames::get_path_to(state->target->weave_to);
	filename *CF = Patterns::obtain_filename(state->target->pattern, mr2.exp[0]);
	if (CF == NULL)
		Errors::in_text_file("pattern does not provide this template file", tfp);
	else
		Indexer::run(state->target->weave_web, state->target->weave_range,
			CF, NULL, OUT, state->target->pattern, P, state->target->navigation,
			NULL, FALSE, FALSE);

@<Weave in the value of this variable name@> =
	WRITE("%S", Bibliographic::get_datum(state->target->weave_web->md, command));

@

=
void Indexer::nav_column(OUTPUT_STREAM, pathname *P, web *W, text_stream *range,
	weave_pattern *pattern, filename *nav, text_stream *leafname) {
	if (nav) {
		if (TextFiles::exists(nav))
			Indexer::run(W, range, nav, leafname, OUT, pattern, P, NULL, NULL, FALSE, TRUE);
		else
			Errors::fatal_with_file("unable to find navigation file", nav);
	} else {
		if (pattern->hierarchical) {
			filename *F = Filenames::in_folder(Pathnames::up(P), I"nav.html");
			if (TextFiles::exists(F))
				Indexer::run(W, range, F, leafname, OUT, pattern, P, NULL, NULL, FALSE, TRUE);
		}
		filename *F = Filenames::in_folder(P, I"nav.html");
		if (TextFiles::exists(F))
			Indexer::run(W, range, F, leafname, OUT, pattern, P, NULL, NULL, FALSE, TRUE);
	}
}

@h Full index pages.
This is a much more substantial service, and operates as a little processor
interpreting a meta-language all of its very own, with a stack for holding
nested repeat loops, and a program counter and -- well, and nothing else to
speak of, in fact, except for the slightly unusual way that loop variables
provide context by changing the subject of what is discussed rather than by
being accessed directly.

The current state of the processor is recorded in the following.

@d MAX_TEMPLATE_LINES 8192 /* maximum number of lines in template */
@d CI_STACK_CAPACITY 8 /* maximum recursion of chapter/section iteration */

=
typedef struct contents_processor {
	text_stream *leafname;
	text_stream *tlines[MAX_TEMPLATE_LINES];
	int no_tlines;
	int repeat_stack_level[CI_STACK_CAPACITY];
	linked_list_item *repeat_stack_variable[CI_STACK_CAPACITY];
	linked_list_item *repeat_stack_threshold[CI_STACK_CAPACITY];
	int repeat_stack_startpos[CI_STACK_CAPACITY];
	int stack_pointer; /* And this is our stack pointer for tracking of loops */
	text_stream *restrict_to_range;
	web *nav_web;
	weave_pattern *nav_pattern;
	pathname *nav_path;
	filename *nav_file;
	linked_list *crumbs;
	int docs_mode;
} contents_processor;

contents_processor Indexer::new_processor(text_stream *range) {
	contents_processor cp;
	cp.no_tlines = 0;
	cp.restrict_to_range = Str::duplicate(range);
	cp.stack_pointer = 0;
	cp.leafname = Str::new();
	return cp;
}

@h Running the interpreter.

@d TRACE_CI_EXECUTION FALSE /* set true for debugging */

=
void Indexer::run(web *W, text_stream *range,
	filename *template_filename, text_stream *contents_page_leafname,
	text_stream *write_to, weave_pattern *pattern, pathname *P, filename *nav_file,
	linked_list *crumbs, int docs, int unlink_selflinks) {
	contents_processor actual_cp = Indexer::new_processor(range);
	actual_cp.nav_web = W;
	actual_cp.nav_pattern = pattern;
	actual_cp.nav_path = P;
	actual_cp.nav_file = nav_file;
	actual_cp.crumbs = crumbs;
	actual_cp.docs_mode = docs;
	actual_cp.leafname = Str::duplicate(contents_page_leafname);
	contents_processor *cp = &actual_cp;
	text_stream TO_struct; text_stream *OUT = &TO_struct;
	@<Read in the source file containing the contents page template@>;
	@<Open the contents page file to be constructed@>;

	int lpos = 0; /* This is our program counter: a line number in the template */
	while (lpos < cp->no_tlines) {
		match_results mr = Regexp::create_mr();
		TEMPORARY_TEXT(tl);
		Str::copy(tl, cp->tlines[lpos++]); /* Fetch the line at the program counter and advance */
		@<Make any necessary substitutions to turn tl into final output@>;
		WRITE("%S\n", tl); /* Copy the now finished line to the output */
		DISCARD_TEXT(tl);
		CYCLE: ;
		Regexp::dispose_of(&mr);
	}
	if (write_to == NULL) STREAM_CLOSE(OUT);
}

@<Make any necessary substitutions to turn tl into final output@> =
	if (Regexp::match(&mr, tl, L"(%c*?) ")) Str::copy(tl, mr.exp[0]); /* Strip trailing spaces */
	if (TRACE_CI_EXECUTION)
		@<Print line and contents of repeat stack@>;
	if ((pattern->embed_CSS) &&
		(Regexp::match(&mr, tl, L" *%<link href=%\"(%c+?)\"%c*"))) {
		filename *CSS_file = Patterns::obtain_filename(pattern, mr.exp[0]);
		Indexer::transcribe_CSS(OUT, CSS_file);
		Str::clear(tl);
	}
	if ((unlink_selflinks) &&
		(Regexp::match(&mr, tl, L"(%c+?)<a href=\"(%c+?)\">(%c+?)</a>(%c*)")) &&
		(Str::eq_insensitive(mr.exp[1], contents_page_leafname))) {
		TEMPORARY_TEXT(unlinked);
		WRITE_TO(unlinked, "%S<span class=\"unlink\">%S</span>%S",
			mr.exp[0], mr.exp[2], mr.exp[3]);
		Str::clear(tl);
		Str::copy(tl, unlinked);
		DISCARD_TEXT(unlinked);
	}
	if ((Regexp::match(&mr, tl, L"%[%[(%c+)%]%]")) ||
		(Regexp::match(&mr, tl, L" %[%[(%c+)%]%]"))) {
		TEMPORARY_TEXT(command);
		Str::copy(command, mr.exp[0]);
		@<Deal with a Select command@>;
		@<Deal with a Repeat command@>;
		@<Deal with a Repeat End command@>;
		DISCARD_TEXT(command);
	}
	@<Skip line if inside an empty loop@>;
	@<Make substitutions of square-bracketed variables in line@>;

@h File handling.

@<Read in the source file containing the contents page template@> =
	TextFiles::read(template_filename, FALSE,
		"can't find contents template", TRUE, Indexer::save_template_line, NULL, cp);
	if (TRACE_CI_EXECUTION)
		PRINT("Read template <%f>: %d line(s)\n", template_filename, cp->no_tlines);

@ With the following iterator:

=
void Indexer::save_template_line(text_stream *line, text_file_position *tfp, void *void_cp) {
	contents_processor *cp = (contents_processor *) void_cp;
	if (cp->no_tlines < MAX_TEMPLATE_LINES)
		cp->tlines[cp->no_tlines++] = Str::duplicate(line);
}

@<Open the contents page file to be constructed@> =
	pathname *H = W->redirect_weaves_to;
	if (H == NULL) H = Reader::woven_folder(W);
	if (write_to) OUT = write_to;
	else {
		filename *Contents = Filenames::in_folder(H, contents_page_leafname);
		if (STREAM_OPEN_TO_FILE(OUT, Contents, ISO_ENC) == FALSE)
			Errors::fatal_with_file("unable to write contents file", Contents);
		if (W->as_ebook)
			Epub::note_page(W->as_ebook, Contents, I"Index", I"index");
		PRINT("[Index file: %f]\n", Contents);
	}

@h The repeat stack and loops.

@<Print line and contents of repeat stack@> =
	PRINT("%04d: %S\nStack:", lpos-1, tl);
	for (int j=0; j<cp->stack_pointer; j++) {
		if (cp->repeat_stack_level[j] == CHAPTER_LEVEL)
			PRINT(" %d: %S/%S",
				j, ((chapter *) CONTENT_IN_ITEM(cp->repeat_stack_variable[j], chapter))->md->ch_range,
				((chapter *) CONTENT_IN_ITEM(cp->repeat_stack_threshold[j], chapter))->md->ch_range);
		else if (cp->repeat_stack_level[j] == SECTION_LEVEL)
			PRINT(" %d: %S/%S",
				j, ((section *) CONTENT_IN_ITEM(cp->repeat_stack_variable[j], section))->md->sect_range,
				((section *) CONTENT_IN_ITEM(cp->repeat_stack_threshold[j], section))->md->sect_range);
	}
	PRINT("\n");

@ We start the direct commands with Select, which is implemented as a
one-iteration loop in which the loop variable has the given section or
chapter as its value during the sole iteration.

@<Deal with a Select command@> =
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, command, L"Select (%c*)")) {
		chapter *C;
		section *S;
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			LOOP_OVER_LINKED_LIST(S, section, C->sections)
				if (Str::eq(S->md->sect_range, mr.exp[0])) {
					Indexer::start_CI_loop(cp, SECTION_LEVEL, S_item, S_item, lpos);
					Regexp::dispose_of(&mr);
					goto CYCLE;
				}
		LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
			if (Str::eq(C->md->ch_range, mr.exp[0])) {
				Indexer::start_CI_loop(cp, CHAPTER_LEVEL, C_item, C_item, lpos);
				Regexp::dispose_of(&mr);
				goto CYCLE;
			}
		Errors::at_position("don't recognise the chapter or section abbreviation range",
			template_filename, lpos);
		Regexp::dispose_of(&mr);
		goto CYCLE;
	}

@ Next, a genuine loop beginning:

@<Deal with a Repeat command@> =
	int loop_level = 0;
	if (Regexp::match(&mr, command, L"Repeat Chapter")) loop_level = CHAPTER_LEVEL;
	if (Regexp::match(&mr, command, L"Repeat Section")) loop_level = SECTION_LEVEL;
	if (loop_level != 0) {
		linked_list_item *from = NULL, *to = NULL;
		linked_list_item *CI = FIRST_ITEM_IN_LINKED_LIST(chapter, W->chapters);
		while ((CI) && (CONTENT_IN_ITEM(CI, chapter)->md->imported))
			CI = NEXT_ITEM_IN_LINKED_LIST(CI, chapter);
		if (loop_level == CHAPTER_LEVEL) {
			from = CI;
			to = LAST_ITEM_IN_LINKED_LIST(chapter, W->chapters);
			if (Str::eq_wide_string(cp->restrict_to_range, L"0") == FALSE) {
				chapter *C;
				LOOP_OVER_LINKED_LIST(C, chapter, W->chapters)
					if (Str::eq(C->md->ch_range, cp->restrict_to_range)) {
						from = C_item; to = from;
						break;
					}
			}
		}
		if (loop_level == SECTION_LEVEL) {
			chapter *within_chapter =
				CONTENT_IN_ITEM(Indexer::heading_topmost_on_stack(cp, CHAPTER_LEVEL), chapter);
			if (within_chapter == NULL) {
				if (CI) {
					chapter *C = CONTENT_IN_ITEM(CI, chapter);
					from = FIRST_ITEM_IN_LINKED_LIST(section, C->sections);
				}
				chapter *LC = LAST_IN_LINKED_LIST(chapter, W->chapters);
				if (LC) to = LAST_ITEM_IN_LINKED_LIST(section, LC->sections);
			} else {
				from = FIRST_ITEM_IN_LINKED_LIST(section, within_chapter->sections);
				to = LAST_ITEM_IN_LINKED_LIST(section, within_chapter->sections);
			}
		}
		if (from) Indexer::start_CI_loop(cp, loop_level, from, to, lpos);
		goto CYCLE;
	}

@ And at the other bookend:

@<Deal with a Repeat End command@> =
	if ((Regexp::match(&mr, command, L"End Repeat")) || (Regexp::match(&mr, command, L"End Select"))) {
		if (cp->stack_pointer <= 0)
			Errors::at_position("stack underflow on contents template", template_filename, lpos);
		if (cp->repeat_stack_level[cp->stack_pointer-1] == SECTION_LEVEL) {
			linked_list_item *SI = cp->repeat_stack_variable[cp->stack_pointer-1];
			if ((SI == cp->repeat_stack_threshold[cp->stack_pointer-1]) ||
				(NEXT_ITEM_IN_LINKED_LIST(SI, section) == NULL))
				Indexer::end_CI_loop(cp);
			else {
				cp->repeat_stack_variable[cp->stack_pointer-1] =
					NEXT_ITEM_IN_LINKED_LIST(SI, section);
				lpos = cp->repeat_stack_startpos[cp->stack_pointer-1]; /* Back round loop */
			}
		} else {
			linked_list_item *CI = cp->repeat_stack_variable[cp->stack_pointer-1];
			if (CI == cp->repeat_stack_threshold[cp->stack_pointer-1])
				Indexer::end_CI_loop(cp);
			else {
				cp->repeat_stack_variable[cp->stack_pointer-1] =
					NEXT_ITEM_IN_LINKED_LIST(CI, chapter);
				lpos = cp->repeat_stack_startpos[cp->stack_pointer-1]; /* Back round loop */
			}
		}
		goto CYCLE;
	}

@ It can happen that a section loop, at least, is empty:

@<Skip line if inside an empty loop@> =
	for (int rstl = cp->stack_pointer-1; rstl >= 0; rstl--)
		if (cp->repeat_stack_level[cp->stack_pointer-1] == SECTION_LEVEL) {
			linked_list_item *SI = cp->repeat_stack_threshold[cp->stack_pointer-1];
			if (NEXT_ITEM_IN_LINKED_LIST(SI, section) ==
				cp->repeat_stack_variable[cp->stack_pointer-1])
				goto CYCLE;
		}

@ If called with level |CHAPTER_LEVEL|, this returns the topmost chapter number
on the stack; and similarly for |SECTION_LEVEL|.

@d CHAPTER_LEVEL 1
@d SECTION_LEVEL 2

=
linked_list_item *Indexer::heading_topmost_on_stack(contents_processor *cp, int level) {
	for (int rstl = cp->stack_pointer-1; rstl >= 0; rstl--)
		if (cp->repeat_stack_level[rstl] == level)
			return cp->repeat_stack_variable[rstl];
	return NULL;
}

@ This is the code for starting a loop, which stacks up the details, and
similarly for ending it by popping them again:

=
void Indexer::start_CI_loop(contents_processor *cp, int level,
	linked_list_item *from, linked_list_item *to, int pos) {
	if (cp->stack_pointer < CI_STACK_CAPACITY) {
		cp->repeat_stack_level[cp->stack_pointer] = level;
		cp->repeat_stack_variable[cp->stack_pointer] = from;
		cp->repeat_stack_threshold[cp->stack_pointer] = to;
		cp->repeat_stack_startpos[cp->stack_pointer++] = pos;
	}
}

void Indexer::end_CI_loop(contents_processor *cp) {
	cp->stack_pointer--;
}

@h Variable substitutions.
We can now forget about this tiny stack machine: the one task left is to
take a line from the template, and make substitutions of variables into
its square-bracketed parts.

@<Make substitutions of square-bracketed variables in line@> =
	int slen, spos;
	while ((spos = Regexp::find_expansion(tl, '[', '[', ']', ']', &slen)) >= 0) {
		TEMPORARY_TEXT(left_part);
		TEMPORARY_TEXT(varname);
		TEMPORARY_TEXT(right_part);

		Str::substr(left_part, Str::start(tl), Str::at(tl, spos));
		Str::substr(varname, Str::at(tl, spos+2), Str::at(tl, spos+slen-2));
		Str::substr(right_part, Str::at(tl, spos+slen), Str::end(tl));

		TEMPORARY_TEXT(substituted);
		match_results mr = Regexp::create_mr();
		if (Bibliographic::data_exists(W->md, varname)) {
			@<Substitute any bibliographic datum named@>;
		} else if (Regexp::match(&mr, varname, L"Navigation")) {
			Indexer::nav_column(substituted, cp->nav_path, cp->nav_web,
				cp->restrict_to_range, cp->nav_pattern, cp->nav_file, cp->leafname);
		} else if (Regexp::match(&mr, varname, L"Breadcrumbs")) {
			HTMLFormat::drop_initial_breadcrumbs(substituted, cp->crumbs, cp->docs_mode);
		} else if (Str::eq_wide_string(varname, L"Plugins")) {
			weave_plugin *wp;
			LOOP_OVER_LINKED_LIST(wp, weave_plugin, cp->nav_pattern->plugins)
				WeavePlugins::include(OUT, cp->nav_web, wp, cp->nav_pattern);
		} else if (Regexp::match(&mr, varname, L"Modules")) {
			@<Substitute the list of imported modules@>;
		} else if (Regexp::match(&mr, varname, L"Chapter (%c+)")) {
			text_stream *detail = mr.exp[0];
			chapter *C = CONTENT_IN_ITEM(
				Indexer::heading_topmost_on_stack(cp, CHAPTER_LEVEL), chapter);
			if (C == NULL)
				Errors::at_position("no chapter is currently selected",
					template_filename, lpos);
			else @<Substitute a detail about the currently selected Chapter@>;
		} else if (Regexp::match(&mr, varname, L"Section (%c+)")) {
			text_stream *detail = mr.exp[0];
			section *S = CONTENT_IN_ITEM(
				Indexer::heading_topmost_on_stack(cp, SECTION_LEVEL), section);
			if (S == NULL)
				Errors::at_position("no section is currently selected",
					template_filename, lpos);
			else @<Substitute a detail about the currently selected Section@>;
		} else if (Regexp::match(&mr, varname, L"Complete (%c+)")) {
			text_stream *detail = mr.exp[0];
			@<Substitute a detail about the complete PDF@>;
		} else {
			WRITE_TO(substituted, "<b>%S</b>", varname);
		}
		Str::clear(tl);
		WRITE_TO(tl, "%S%S%S", left_part, substituted, right_part);
		Regexp::dispose_of(&mr);
		DISCARD_TEXT(left_part);
		DISCARD_TEXT(varname);
		DISCARD_TEXT(substituted);
		DISCARD_TEXT(right_part);
	}

@ This is why, for instance, |[[Author]]| is replaced by the author's name:

@<Substitute any bibliographic datum named@> =
	Str::copy(substituted, Bibliographic::get_datum(W->md, varname));

@ We store little about the complete-web-in-one-file PDF:

@<Substitute a detail about the complete PDF@> =
	if (swarm_leader)
		if (Formats::substitute_post_processing_data(substituted, swarm_leader, detail, pattern) == FALSE)
			WRITE_TO(substituted, "%S for complete web", detail);

@ And here for Chapters:

@<Substitute a detail about the currently selected Chapter@> =
	if (Str::eq_wide_string(detail, L"Title")) {
		Str::copy(substituted, C->md->ch_title);
	} else if (Str::eq_wide_string(detail, L"Code")) {
		Str::copy(substituted, C->md->ch_range);
	} else if (Str::eq_wide_string(detail, L"Purpose")) {
		Str::copy(substituted, C->md->rubric);
	} else if (Formats::substitute_post_processing_data(substituted, C->ch_weave, detail, pattern)) {
		;
	} else {
		WRITE_TO(substituted, "%S for %S", varname, C->md->ch_title);
	}

@ And this, finally, is a very similar construction for Sections.

@<Substitute a detail about the currently selected Section@> =
	if (Str::eq_wide_string(detail, L"Title")) {
		Str::copy(substituted, S->md->sect_title);
	} else if (Str::eq_wide_string(detail, L"Purpose")) {
		Str::copy(substituted, S->sect_purpose);
	} else if (Str::eq_wide_string(detail, L"Code")) {
		Str::copy(substituted, S->md->sect_range);
	} else if (Str::eq_wide_string(detail, L"Lines")) {
		WRITE_TO(substituted, "%d", S->sect_extent);
	} else if (Str::eq_wide_string(detail, L"Source")) {
		WRITE_TO(substituted, "%f", S->md->source_file_for_section);
	} else if (Str::eq_wide_string(detail, L"Page")) {
		TEMPORARY_TEXT(linkto);
		Str::copy(linkto, S->md->sect_range);
		LOOP_THROUGH_TEXT(P, linkto)
			if ((Str::get(P) == '/') || (Str::get(P) == ' '))
				Str::put(P, '-');
		WRITE_TO(linkto, ".html");
		Str::copy(substituted, linkto);
		DISCARD_TEXT(linkto);
	} else if (Str::eq_wide_string(detail, L"Paragraphs")) {
		WRITE_TO(substituted, "%d", S->sect_paragraphs);
	} else if (Str::eq_wide_string(detail, L"Mean")) {
		int denom = S->sect_paragraphs;
		if (denom == 0) denom = 1;
		WRITE_TO(substituted, "%d", S->sect_extent/denom);
	} else if (Formats::substitute_post_processing_data(substituted, S->sect_weave, detail, pattern)) {
		;
	} else {
		WRITE_TO(substituted, "%S for %S", varname, S->md->sect_title);
	}

@<Substitute the list of imported modules@> =
	module *M = W->md->as_module;
	int L = LinkedLists::len(M->dependencies);
	if (L > 0) {
		WRITE_TO(substituted,
			"<p class=\"purpose\">Together with the following imported module%s:\n",
			(L==1)?"":"s");
		WRITE_TO(substituted, "<ul class=\"chapterlist\">\n");
		Indexer::list_module(substituted, W->md->as_module, FALSE);
		WRITE_TO(substituted, "</ul>\n");
	}

@ =
void Indexer::list_module(OUTPUT_STREAM, module *M, int list_this) {
	if (list_this) {
		WRITE("<li><p>%S - ", M->module_name);
		TEMPORARY_TEXT(url);
		WRITE_TO(url, "%p", M->module_location);
		Readme::write_var(OUT, url, I"Purpose");
		DISCARD_TEXT(url);
		WRITE("</p></li>");
	}
	module *N;
	LOOP_OVER_LINKED_LIST(N, module, M->dependencies)
		Indexer::list_module(OUT, N, TRUE);
}

@h Transcribing CSS.

=
void Indexer::transcribe_CSS(OUTPUT_STREAM, filename *CSS_file) {
	WRITE("<style type=\"text/css\">\n");
	TextFiles::read(CSS_file, FALSE, "can't open CSS file",
		TRUE, Indexer::copy_CSS, NULL, OUT);
	WRITE("\n</style>\n");
}

void Indexer::copy_CSS(text_stream *line, text_file_position *tfp, void *X) {
	text_stream *OUT = (text_stream *) X;
	WRITE("%S\n", line);
}
