[InwebInspect::] inweb inspect Subcommand.

The inweb inspect subcommand describes a web or other resource without changing it.

@ The command line interface and help text:

@e INSPECT_CLSUB
@e INSPECT_ONLY_CLSW
@e RESOURCES_CLSW
@e FULLER_CLSW
@e SCAN_CLSW
@e METADATA_CLSW
@e INDEX_CLSW
@e CONVENTIONS_CLSW
@e TAGS_CLSW
@e LINKS_CLSW
@e CLIKE_CLSG

=
void InwebInspect::cli(void) {
	CommandLine::begin_subcommand(INSPECT_CLSUB, U"inspect");
	CommandLine::declare_heading(
		U"Usage: inweb inspect [WEB [RANGE] | FILE]\n\n"
		U"This shows the contents of a web, colony, or other Inweb resource without\n"
		U"changing it or taking any action.");

	CommandLine::declare_switch(RESOURCES_CLSW, U"resources", 1,
		U"show the Inweb resources (such as languages and notations) available");
	CommandLine::declare_switch(FULLER_CLSW, U"fuller", 1,
		U"show fuller details where available");

	CommandLine::begin_group(CLIKE_CLSG,
		I"when inspecting webs only");
	CommandLine::declare_switch(INSPECT_ONLY_CLSW, U"only", 2,
		U"inspect only the section or chapter whose abbreviation is X");
	CommandLine::declare_switch(METADATA_CLSW, U"metadata", 1,
		U"show the bibliographic metadata associated with this web");
	CommandLine::declare_switch(INDEX_CLSW, U"index", 1,
		U"show the index (if any) for this web");
	CommandLine::declare_switch(CONVENTIONS_CLSW, U"conventions", 1,
		U"show the conventions as they are applied to this web");
	CommandLine::declare_switch(TAGS_CLSW, U"tags", 1,
		U"show the paragraph tags used in this web");
	CommandLine::declare_switch(LINKS_CLSW, U"links", 1,
		U"show the external Internet links used in this web");
	CommandLine::declare_switch(SCAN_CLSW, U"scan", 1,
		U"parse the web and display its syntax tree (can produce lots of output)");
	CommandLine::end_group();

	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_inspect_settings {
	struct inweb_range_specifier subset;
	int scan_switch;      /* |-scan|: simply show the syntactic scan of the source */
	int metadata_switch;  /* |-metadata|: simply show the syntactic scan of the source */
	int index_switch;  /* |-index|: show the web index in textual form */
	int conventions_switch; /* |-conventions|: show what conventions apply */
	int resources_switch; /* |-resources|: show WCL objects in scope */
	int tags_switch; /* |-tags|: show paragraph tags used */
	int links_switch; /* |-links|: show http(s) links used */
	int fuller_switch;    /* |-fuller|: give further details */
} inweb_inspect_settings;

void InwebInspect::initialise(inweb_inspect_settings *iis) {
	iis->subset = Configuration::new_range_specifier();
	iis->scan_switch = FALSE;
	iis->metadata_switch = FALSE;
	iis->index_switch = FALSE;
	iis->conventions_switch = FALSE;
	iis->resources_switch = FALSE;
	iis->tags_switch = FALSE;
	iis->links_switch = FALSE;
	iis->fuller_switch = FALSE;
}

int InwebInspect::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_inspect_settings *iis = &(ins->inspect_settings);
	switch (id) {
		case INSPECT_ONLY_CLSW: Configuration::set_range(&(iis->subset), arg, FALSE); return TRUE;
		case SCAN_CLSW: iis->scan_switch = val; return TRUE;
		case METADATA_CLSW: iis->metadata_switch = val; return TRUE;
		case INDEX_CLSW: iis->index_switch = val; return TRUE;
		case CONVENTIONS_CLSW: iis->conventions_switch = val; return TRUE;
		case TAGS_CLSW: iis->tags_switch = val; return TRUE;
		case LINKS_CLSW: iis->links_switch = val; return TRUE;
		case RESOURCES_CLSW: iis->resources_switch = val; return TRUE;
		case FULLER_CLSW: iis->fuller_switch = val; return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebInspect::run(inweb_instructions *ins) {
	inweb_inspect_settings *iis = &(ins->inspect_settings);
	int type = WEB_OPERAND_ALLOWED;
	if (iis->scan_switch) type = WEB_OPERAND_COMPULSORY;
	inweb_operand op = Configuration::operand(ins, type, FALSE, FALSE);
	if (no_inweb_errors > 0) return;
	if (iis->resources_switch) {
		if (op.D) {
			if (op.W) WebStructure::print_statistics(op.W);
			else { WCL::write_briefly(STDOUT, op.D); PRINT("-- "); }
			PRINT("with the following Inweb resources available for use:\n");
		} else {
			PRINT("The following Inweb resources are available for any web or colony to use:\n");
		}
		WCL::write_sorted_list_of_declaration_resources(STDOUT, op.D, -1);
	} else if (op.W) {
		WebStructure::print_statistics(op.W);
		int modular = FALSE;
		@<Check that the range contains sections@>;
		if (iis->scan_switch) {
			WebStructure::write_web(STDOUT, op.W, iis->subset.range);
		} else if (iis->index_switch) {
			WebIndexing::inspect_index(STDOUT, op.W, iis->subset.range);
		} else if (iis->tags_switch) {
			WebStructure::parse_markdown(op.W);
			PRINT("\n");
			ParagraphTags::tabulate(STDOUT, op.W, iis->subset.range, iis->fuller_switch);
			if ((iis->fuller_switch == FALSE) && (modular))
				PRINT("\n(main module only: use '-fuller' for all modules)\n");
		} else if (iis->links_switch) {
			WebStructure::parse_markdown(op.W);
			PRINT("\n");
			ParagraphTags::tabulate_links(STDOUT, op.W, iis->subset.range, iis->fuller_switch);
			if ((iis->fuller_switch == FALSE) && (modular))
				PRINT("\n(main module only: use '-fuller' for all modules)\n");
		} else if (iis->conventions_switch) {
			Conventions::show(STDOUT, op.W, iis->fuller_switch);
		} else {
			PRINT("\n");
			if (iis->metadata_switch) {
				if (iis->fuller_switch) {
					web_bibliographic_datum *bd;
					LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, op.W) {
						if (bd->alias)
							PRINT("%S, alias for %S\n", bd->key, bd->alias->key);
						else if (bd->default_setting_only)
							PRINT("%S, default value: %S\n", bd->key, bd->value);
						else
							PRINT("%S: %S\n", bd->key, bd->value);
					}
				} else {
					web_bibliographic_datum *bd;
					LOOP_OVER_BIBLIOGRAPHIC_DATA(bd, op.W)
						if ((bd->alias == NULL) && (bd->default_setting_only == FALSE))
							PRINT("%S: %S\n", bd->key, bd->value);
				}
			} else if (op.W->is_page == FALSE) {
				PRINT("Contents");
				if (Str::ne(iis->subset.range, I"0"))
					PRINT(" of sections matching '%S'", iis->subset.range);
				if ((iis->fuller_switch == FALSE) && (modular))
					PRINT(" (main module only: use '-fuller' for all modules)");
				PRINT(":\n");
				InwebInspect::catalogue_the_sections(op.W, iis->subset.range,
					iis->fuller_switch);
			}
		}
	} else if (op.D) WCL::write(STDOUT, op.D);
	else if (op.F) PRINT("Unable to identify file '%f' as Inweb resources\n", op.F);
	else if (op.P) PRINT("Unable to identify directory '%p' as Inweb resources\n", op.P);
}

@<Check that the range contains sections@> =
	int s = 0;
	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, op.W->chapters)
		LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
			if (C->owning_module != op.W->main_module)
				modular = TRUE;
			if (WebRanges::is_within(WebRanges::of(S), iis->subset.range))
				s++;
		}
	if (s == 0) Errors::fatal("no sections of this web match that -only requirement");

@h The section catalogue.
This provides quite a useful overview of the sections:

=
void InwebInspect::catalogue_the_sections(ls_web *W, text_stream *range, int fully) {
	textual_table *T = TextualTables::new_table();
	WRITE_TO(TextualTables::next_cell(T), "abbrev");
	if (fully) WRITE_TO(TextualTables::next_cell(T), "module");
	if (W->chaptered) WRITE_TO(TextualTables::next_cell(T), "chapter");
	WRITE_TO(TextualTables::next_cell(T), "section");
	WRITE_TO(TextualTables::next_cell(T), "lines");

	ls_chapter *C;
	ls_section *S;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if (C->owning_module == W->main_module)
			@<Rows for this chapter@>;
	LOOP_OVER_LINKED_LIST(C, ls_chapter, W->chapters)
		if ((C->owning_module != W->main_module) && (fully))
			@<Rows for this chapter@>;
	TextualTables::tabulate(STDOUT, T);
}

@<Rows for this chapter@> =
	LOOP_OVER_LINKED_LIST(S, ls_section, C->sections) {
		if (WebRanges::is_within(WebRanges::of(S), range)) {
			TextualTables::begin_row(T);
			WRITE_TO(TextualTables::next_cell(T), "%S", WebRanges::of(S));
			if (fully) WRITE_TO(TextualTables::next_cell(T), "%S", C->owning_module->module_name);
			if (W->chaptered) WRITE_TO(TextualTables::next_cell(T), "%S", C->ch_basic_title);
			WRITE_TO(TextualTables::next_cell(T), "%S", S->sect_title);
			WRITE_TO(TextualTables::next_cell(T), "%d", S->sect_extent);
		}
	}
