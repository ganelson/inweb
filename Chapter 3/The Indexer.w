[Indexer::] The Indexer.

To construct indexes of the material woven, following a template.

@h Cover sheets.
The indexer offers two basic services. One, which is much simpler, makes
cover sheets, and has only simple escapes (except that it has the ability
to call the fuller indexing service if need be, using |[[Template T]]|
or |[[Navigation]]|).

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
	if ((include) &&
		((state->target->self_contained) || (state->target->pattern->embed_CSS)) &&
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
	if (state->target->navigation) {
		if (TextFiles::exists(state->target->navigation))
			Indexer::incorporate_template_for_target(OUT, state->target, state->target->navigation);
		else
			Errors::fatal_with_file("unable to find navigation file", state->target->navigation);
	} else {
		PRINT("Warning: no sidebar links will be generated, as -navigation is unset");
	}

@<Weave in an index@> =
	filename *CF = Patterns::obtain_filename(state->target->pattern, mr2.exp[0]);
	if (CF == NULL)
		Errors::in_text_file("pattern does not provide this template file", tfp);
	else
		Indexer::incorporate_template_for_target(OUT, state->target, CF);

@<Weave in the value of this variable name@> =
	WRITE("%S", Bibliographic::get_datum(state->target->weave_web->md, command));

@h Full index pages.
This is a much more substantial service, and operates as a little processor
interpreting a meta-language all of its very own, with a stack for holding
nested repeat loops, and a program counter and -- well, and nothing else to
speak of, in fact, except for the slightly unusual way that loop variables
provide context by changing the subject of what is discussed rather than by
being accessed directly.

For convenience, we provide three way to call:

=
void Indexer::incorporate_template_for_web_and_pattern(text_stream *OUT, web *W,
	weave_pattern *pattern, filename *F) {
	Indexer::incorporate_template(OUT, W, I"", F, pattern, NULL, NULL);
}

void Indexer::incorporate_template_for_target(text_stream *OUT, weave_target *wv,
	filename *F) {
	Indexer::incorporate_template(OUT, wv->weave_web, wv->weave_range, F, wv->pattern,
		wv->navigation, wv->breadcrumbs);
}

void Indexer::incorporate_template(text_stream *OUT, web *W, text_stream *range,
	filename *template_filename, weave_pattern *pattern, filename *nav_file,
	linked_list *crumbs) {
	index_engine_state actual_ies =
		Indexer::new_processor(W, range, template_filename, pattern, nav_file, crumbs);
	index_engine_state *ies = &actual_ies;
	Indexer::run_engine(OUT, ies);
}

@ The current state of the processor is recorded in the following.

@d TRACE_CI_EXECUTION FALSE /* set true for debugging */

@d MAX_TEMPLATE_LINES 8192 /* maximum number of lines in template */
@d CI_STACK_CAPACITY 8 /* maximum recursion of chapter/section iteration */

=
typedef struct index_engine_state {
	web *for_web;
	text_stream *tlines[MAX_TEMPLATE_LINES];
	int no_tlines;
	int repeat_stack_level[CI_STACK_CAPACITY];
	linked_list_item *repeat_stack_variable[CI_STACK_CAPACITY];
	linked_list_item *repeat_stack_threshold[CI_STACK_CAPACITY];
	int repeat_stack_startpos[CI_STACK_CAPACITY];
	int stack_pointer; /* And this is our stack pointer for tracking of loops */
	text_stream *restrict_to_range;
	weave_pattern *nav_pattern;
	filename *nav_file;
	linked_list *crumbs;
	int inside_navigation_submenu;
	filename *errors_at;
} index_engine_state;

index_engine_state Indexer::new_processor(web *W, text_stream *range,
	filename *template_filename, weave_pattern *pattern, filename *nav_file,
	linked_list *crumbs) {
	index_engine_state ies;
	ies.no_tlines = 0;
	ies.restrict_to_range = Str::duplicate(range);
	ies.stack_pointer = 0;
	ies.inside_navigation_submenu = FALSE;
	ies.for_web = W;
	ies.nav_pattern = pattern;
	ies.nav_file = nav_file;
	ies.crumbs = crumbs;
	ies.errors_at = template_filename;
	@<Read in the source file containing the contents page template@>;
	return ies;
}

@<Read in the source file containing the contents page template@> =
	TextFiles::read(template_filename, FALSE,
		"can't find contents template", TRUE, Indexer::temp_line, NULL, &ies);
	if (TRACE_CI_EXECUTION)
		PRINT("Read template <%f>: %d line(s)\n", template_filename, ies.no_tlines);
	if (ies.no_tlines >= MAX_TEMPLATE_LINES)
		PRINT("Warning: template <%f> truncated after %d line(s)\n",
			template_filename, ies.no_tlines);

@ =
void Indexer::temp_line(text_stream *line, text_file_position *tfp, void *v_ies) {
	index_engine_state *ies = (index_engine_state *) v_ies;
	if (ies->no_tlines < MAX_TEMPLATE_LINES)
		ies->tlines[ies->no_tlines++] = Str::duplicate(line);
}

@ Running the engine...

=
void Indexer::run_engine(text_stream *OUT, index_engine_state *ies) {
	filename *save_cf = Indexer::current_file();
	int lpos = 0; /* This is our program counter: a line number in the template */
	while (lpos < ies->no_tlines) {
		match_results mr = Regexp::create_mr();
		TEMPORARY_TEXT(tl);
		Str::copy(tl, ies->tlines[lpos++]); /* Fetch the line at the program counter and advance */
		@<Make any necessary substitutions to turn tl into final output@>;
		WRITE("%S\n", tl); /* Copy the now finished line to the output */
		DISCARD_TEXT(tl);
		CYCLE: ;
		Regexp::dispose_of(&mr);
	}
	if (ies->inside_navigation_submenu) WRITE("</ul>");
	ies->inside_navigation_submenu = FALSE;
	Indexer::set_current_file(save_cf);
}

@<Make any necessary substitutions to turn tl into final output@> =
	if (Regexp::match(&mr, tl, L"(%c*?) ")) Str::copy(tl, mr.exp[0]); /* Strip trailing spaces */
	if (TRACE_CI_EXECUTION)
		@<Print line and contents of repeat stack@>;
	if ((ies->nav_pattern->embed_CSS) &&
		(Regexp::match(&mr, tl, L" *%<link href=%\"(%c+?)\"%c*"))) {
		filename *CSS_file = Patterns::obtain_filename(ies->nav_pattern, mr.exp[0]);
		Indexer::transcribe_CSS(OUT, CSS_file);
		Str::clear(tl);
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

@h The repeat stack and loops.
This is used only for debugging:

@<Print line and contents of repeat stack@> =
	PRINT("%04d: %S\nStack:", lpos-1, tl);
	for (int j=0; j<ies->stack_pointer; j++) {
		if (ies->repeat_stack_level[j] == CHAPTER_LEVEL)
			PRINT(" %d: %S/%S",
				j, ((chapter *)
					CONTENT_IN_ITEM(ies->repeat_stack_variable[j], chapter))->md->ch_range,
				((chapter *)
					CONTENT_IN_ITEM(ies->repeat_stack_threshold[j], chapter))->md->ch_range);
		else if (ies->repeat_stack_level[j] == SECTION_LEVEL)
			PRINT(" %d: %S/%S",
				j, ((section *)
					CONTENT_IN_ITEM(ies->repeat_stack_variable[j], section))->md->sect_range,
				((section *)
					CONTENT_IN_ITEM(ies->repeat_stack_threshold[j], section))->md->sect_range);
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
		LOOP_OVER_LINKED_LIST(C, chapter, ies->for_web->chapters)
			LOOP_OVER_LINKED_LIST(S, section, C->sections)
				if (Str::eq(S->md->sect_range, mr.exp[0])) {
					Indexer::start_CI_loop(ies, SECTION_LEVEL, S_item, S_item, lpos);
					Regexp::dispose_of(&mr);
					goto CYCLE;
				}
		LOOP_OVER_LINKED_LIST(C, chapter, ies->for_web->chapters)
			if (Str::eq(C->md->ch_range, mr.exp[0])) {
				Indexer::start_CI_loop(ies, CHAPTER_LEVEL, C_item, C_item, lpos);
				Regexp::dispose_of(&mr);
				goto CYCLE;
			}
		Errors::at_position("don't recognise the chapter or section abbreviation range",
			ies->errors_at, lpos);
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
		linked_list_item *CI = FIRST_ITEM_IN_LINKED_LIST(chapter, ies->for_web->chapters);
		while ((CI) && (CONTENT_IN_ITEM(CI, chapter)->md->imported))
			CI = NEXT_ITEM_IN_LINKED_LIST(CI, chapter);
		if (loop_level == CHAPTER_LEVEL) {
			from = CI;
			to = LAST_ITEM_IN_LINKED_LIST(chapter, ies->for_web->chapters);
			if (Str::eq_wide_string(ies->restrict_to_range, L"0") == FALSE) {
				chapter *C;
				LOOP_OVER_LINKED_LIST(C, chapter, ies->for_web->chapters)
					if (Str::eq(C->md->ch_range, ies->restrict_to_range)) {
						from = C_item; to = from;
						break;
					}
			}
		}
		if (loop_level == SECTION_LEVEL) {
			chapter *within_chapter =
				CONTENT_IN_ITEM(Indexer::heading_topmost_on_stack(ies, CHAPTER_LEVEL),
					chapter);
			if (within_chapter == NULL) {
				if (CI) {
					chapter *C = CONTENT_IN_ITEM(CI, chapter);
					from = FIRST_ITEM_IN_LINKED_LIST(section, C->sections);
				}
				chapter *LC = LAST_IN_LINKED_LIST(chapter, ies->for_web->chapters);
				if (LC) to = LAST_ITEM_IN_LINKED_LIST(section, LC->sections);
			} else {
				from = FIRST_ITEM_IN_LINKED_LIST(section, within_chapter->sections);
				to = LAST_ITEM_IN_LINKED_LIST(section, within_chapter->sections);
			}
		}
		if (from) Indexer::start_CI_loop(ies, loop_level, from, to, lpos);
		goto CYCLE;
	}

@ And at the other bookend:

@<Deal with a Repeat End command@> =
	if ((Regexp::match(&mr, command, L"End Repeat")) ||
		(Regexp::match(&mr, command, L"End Select"))) {
		if (ies->stack_pointer <= 0)
			Errors::at_position("stack underflow on contents template",
				ies->errors_at, lpos);
		if (ies->repeat_stack_level[ies->stack_pointer-1] == SECTION_LEVEL) {
			linked_list_item *SI = ies->repeat_stack_variable[ies->stack_pointer-1];
			if ((SI == ies->repeat_stack_threshold[ies->stack_pointer-1]) ||
				(NEXT_ITEM_IN_LINKED_LIST(SI, section) == NULL))
				Indexer::end_CI_loop(ies);
			else {
				ies->repeat_stack_variable[ies->stack_pointer-1] =
					NEXT_ITEM_IN_LINKED_LIST(SI, section);
				lpos = ies->repeat_stack_startpos[ies->stack_pointer-1]; /* Back round loop */
			}
		} else {
			linked_list_item *CI = ies->repeat_stack_variable[ies->stack_pointer-1];
			if (CI == ies->repeat_stack_threshold[ies->stack_pointer-1])
				Indexer::end_CI_loop(ies);
			else {
				ies->repeat_stack_variable[ies->stack_pointer-1] =
					NEXT_ITEM_IN_LINKED_LIST(CI, chapter);
				lpos = ies->repeat_stack_startpos[ies->stack_pointer-1]; /* Back round loop */
			}
		}
		goto CYCLE;
	}

@ It can happen that a section loop, at least, is empty:

@<Skip line if inside an empty loop@> =
	for (int rstl = ies->stack_pointer-1; rstl >= 0; rstl--)
		if (ies->repeat_stack_level[ies->stack_pointer-1] == SECTION_LEVEL) {
			linked_list_item *SI = ies->repeat_stack_threshold[ies->stack_pointer-1];
			if (NEXT_ITEM_IN_LINKED_LIST(SI, section) ==
				ies->repeat_stack_variable[ies->stack_pointer-1])
				goto CYCLE;
		}

@ If called with level |CHAPTER_LEVEL|, this returns the topmost chapter number
on the stack; and similarly for |SECTION_LEVEL|.

@d CHAPTER_LEVEL 1
@d SECTION_LEVEL 2

=
linked_list_item *Indexer::heading_topmost_on_stack(index_engine_state *ies, int level) {
	for (int rstl = ies->stack_pointer-1; rstl >= 0; rstl--)
		if (ies->repeat_stack_level[rstl] == level)
			return ies->repeat_stack_variable[rstl];
	return NULL;
}

@ This is the code for starting a loop, which stacks up the details, and
similarly for ending it by popping them again:

=
void Indexer::start_CI_loop(index_engine_state *ies, int level,
	linked_list_item *from, linked_list_item *to, int pos) {
	if (ies->stack_pointer < CI_STACK_CAPACITY) {
		ies->repeat_stack_level[ies->stack_pointer] = level;
		ies->repeat_stack_variable[ies->stack_pointer] = from;
		ies->repeat_stack_threshold[ies->stack_pointer] = to;
		ies->repeat_stack_startpos[ies->stack_pointer++] = pos;
	}
}

void Indexer::end_CI_loop(index_engine_state *ies) {
	ies->stack_pointer--;
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
		if (Bibliographic::data_exists(ies->for_web->md, varname)) {
			@<Substitute any bibliographic datum named@>;
		} else if (Regexp::match(&mr, varname, L"Navigation")) {
			@<Substitute Navigation@>;
		} else if (Regexp::match(&mr, varname, L"Breadcrumbs")) {
			@<Substitute Breadcrumbs@>;
		} else if (Str::eq_wide_string(varname, L"Plugins")) {
			@<Substitute Plugins@>;
		} else if (Regexp::match(&mr, varname, L"Modules")) {
			@<Substitute Modules@>;
		} else if (Regexp::match(&mr, varname, L"Complete (%c+)")) {
			text_stream *detail = mr.exp[0];
			@<Substitute a detail about the complete PDF@>;
		} else if (Regexp::match(&mr, varname, L"Chapter (%c+)")) {
			text_stream *detail = mr.exp[0];
			@<Substitute a Chapter@>;
		} else if (Regexp::match(&mr, varname, L"Section (%c+)")) {
			text_stream *detail = mr.exp[0];
			@<Substitute a Section@>;
		} else if (Regexp::match(&mr, varname, L"Docs")) {
			@<Substitute a Docs@>;
		} else if (Regexp::match(&mr, varname, L"URL \"(%c+)\"")) {
			text_stream *link_text = mr.exp[0];
			@<Substitute a URL@>;
		} else if (Regexp::match(&mr, varname, L"Link \"(%c+)\"")) {
			text_stream *link_text = mr.exp[0];
			@<Substitute a Link@>;
		} else if (Regexp::match(&mr, varname, L"Menu \"(%c+)\"")) {
			text_stream *menu_name = mr.exp[0];
			@<Substitute a Menu@>;
		} else if (Regexp::match(&mr, varname, L"Item \"(%c+)\"")) {
			text_stream *item_name = mr.exp[0];
			text_stream *link_text = item_name;
			@<Substitute a member Item@>;
		} else if (Regexp::match(&mr, varname, L"Item \"(%c+)\" -> (%c+)")) {
			text_stream *item_name = mr.exp[0];
			text_stream *link_text = mr.exp[1];
			@<Substitute a general Item@>;
		} else {
			WRITE_TO(substituted, "%S", varname);
			if (Regexp::match(&mr, varname, L"%i+%c*"))
				PRINT("Warning: unable to resolve command '%S'\n", varname);
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
	Str::copy(substituted, Bibliographic::get_datum(ies->for_web->md, varname));

@ |[[Navigation]]| substitutes to the content of the sidebar navigation file;
this will recursively call the Indexer, in fact.

@<Substitute Navigation@> =
	if (ies->nav_file) {
		if (TextFiles::exists(ies->nav_file))
			Indexer::incorporate_template(substituted, ies->for_web, ies->restrict_to_range,
				ies->nav_file, ies->nav_pattern, NULL, NULL);
		else
			Errors::fatal_with_file("unable to find navigation file", ies->nav_file);
	} else {
		PRINT("Warning: no sidebar links will be generated, as -navigation is unset");
	}

@ A trail of breadcrumbs, used for overhead navigation in web pages.

@<Substitute Breadcrumbs@> =
	Colonies::drop_initial_breadcrumbs(substituted, Indexer::current_file(),
		ies->crumbs);

@ |[[Plugins]]| here expands to material needed by any plugins required
by the weave ies->nav_pattern itself; it doesn't include optional extras for a
specific page because, of course, the Indexer is used for cover sheets and
not pages. (Except for navigation purposes, and navigation files should never
use this.)

@<Substitute Plugins@> =
	weave_plugin *wp;
	LOOP_OVER_LINKED_LIST(wp, weave_plugin, ies->nav_pattern->plugins)
		WeavePlugins::include(OUT, ies->for_web, wp, ies->nav_pattern);

@ A list of all modules in the current web.

@<Substitute Modules@> =
	module *M = ies->for_web->md->as_module;
	int L = LinkedLists::len(M->dependencies);
	if (L > 0) {
		WRITE_TO(substituted,
			"<p class=\"purpose\">Together with the following imported module%s:\n",
			(L==1)?"":"s");
		WRITE_TO(substituted, "<ul class=\"chapterlist\">\n");
		Indexer::list_module(substituted, ies->for_web->md->as_module, FALSE);
		WRITE_TO(substituted, "</ul>\n");
	}

@ We store little about the complete-web-in-one-file PDF:

@<Substitute a detail about the complete PDF@> =
	if (swarm_leader)
		if (Formats::substitute_post_processing_data(substituted,
			swarm_leader, detail, ies->nav_pattern) == FALSE)
			WRITE_TO(substituted, "%S for complete web", detail);

@ And here for Chapters:

@<Substitute a Chapter@> =
	chapter *C = CONTENT_IN_ITEM(
		Indexer::heading_topmost_on_stack(ies, CHAPTER_LEVEL), chapter);
	if (C == NULL)
		Errors::at_position("no chapter is currently selected",
			ies->errors_at, lpos);
	else @<Substitute a detail about the currently selected Chapter@>;

@<Substitute a detail about the currently selected Chapter@> =
	if (Str::eq_wide_string(detail, L"Title")) {
		Str::copy(substituted, C->md->ch_title);
	} else if (Str::eq_wide_string(detail, L"Code")) {
		Str::copy(substituted, C->md->ch_range);
	} else if (Str::eq_wide_string(detail, L"Purpose")) {
		Str::copy(substituted, C->md->rubric);
	} else if (Formats::substitute_post_processing_data(substituted,
		C->ch_weave, detail, ies->nav_pattern)) {
		;
	} else {
		WRITE_TO(substituted, "%S for %S", varname, C->md->ch_title);
	}

@ And this is a very similar construction for Sections.

@<Substitute a Section@> =
	section *S = CONTENT_IN_ITEM(
		Indexer::heading_topmost_on_stack(ies, SECTION_LEVEL), section);
	if (S == NULL)
		Errors::at_position("no section is currently selected",
			ies->errors_at, lpos);
	else @<Substitute a detail about the currently selected Section@>;

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
		Colonies::section_URL(substituted, S->md);
	} else if (Str::eq_wide_string(detail, L"Paragraphs")) {
		WRITE_TO(substituted, "%d", S->sect_paragraphs);
	} else if (Str::eq_wide_string(detail, L"Mean")) {
		int denom = S->sect_paragraphs;
		if (denom == 0) denom = 1;
		WRITE_TO(substituted, "%d", S->sect_extent/denom);
	} else if (Formats::substitute_post_processing_data(substituted,
		S->sect_weave, detail, ies->nav_pattern)) {
		;
	} else {
		WRITE_TO(substituted, "%S for %S", varname, S->md->sect_title);
	}

@ These commands are all used in constructing relative URLs, especially for
navigation purposes.

@<Substitute a Docs@> =
	Pathnames::relative_URL(substituted,
		Filenames::get_path_to(Indexer::current_file()),
		Pathnames::from_text(Colonies::home()));

@<Substitute a URL@> =
	Pathnames::relative_URL(substituted,
		Filenames::get_path_to(Indexer::current_file()),
		Pathnames::from_text(link_text));

@<Substitute a Link@> =
	WRITE_TO(substituted, "<a href=\"");
	Colonies::reference_URL(substituted, link_text, Indexer::current_file());
	WRITE_TO(substituted, "\">");

@<Substitute a Menu@> =
	if (ies->inside_navigation_submenu) WRITE_TO(substituted, "</ul>");
	WRITE_TO(substituted, "<h2>%S</h2><ul>", menu_name);
	ies->inside_navigation_submenu = TRUE;

@<Substitute a member Item@> =
	TEMPORARY_TEXT(url);
	Colonies::reference_URL(url, link_text, Indexer::current_file());
	@<Substitute an item at this URL@>;
	DISCARD_TEXT(url);

@<Substitute a general Item@> =
	TEMPORARY_TEXT(url);
	Colonies::link_URL(url, link_text, Indexer::current_file());
	@<Substitute an item at this URL@>;
	DISCARD_TEXT(url);

@<Substitute an item at this URL@> =
	if (ies->inside_navigation_submenu == FALSE) WRITE_TO(substituted, "<ul>");
	ies->inside_navigation_submenu = TRUE;
	WRITE_TO(substituted, "<li>");
	if (Str::eq(url, Filenames::get_leafname(Indexer::current_file()))) {
		WRITE_TO(substituted, "<span class=\"unlink\">");
		WRITE_TO(substituted, "%S", item_name);
		WRITE_TO(substituted, "</span>");
	} else if (Str::eq(url, I"index.html")) {
		WRITE_TO(substituted, "<a href=\"%S\">", url);
		WRITE_TO(substituted, "<span class=\"selectedlink\">");
		WRITE_TO(substituted, "%S", item_name);
		WRITE_TO(substituted, "</span>");
		WRITE_TO(substituted, "</a>");
	} else {
		WRITE_TO(substituted, "<a href=\"%S\">", url);
		WRITE_TO(substituted, "%S", item_name);
		WRITE_TO(substituted, "</a>");
	}
	WRITE_TO(substituted, "</li>");

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

@h Tracking the file being written to.

=
filename *file_being_woven = NULL;
filename *Indexer::current_file(void) {
	return file_being_woven;
}
void Indexer::set_current_file(filename *F) {
	file_being_woven = F;
}
