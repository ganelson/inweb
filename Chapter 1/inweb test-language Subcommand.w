[InwebTestLanguage::] inweb test-language Subcommand.

The inweb test-language subcommand tries a passage of code against a language definition.

@ The command line interface and help text:

@e TEST_LANGUAGE_CLSUB
@e TEST_LANGUAGE_ON_CLSW
@e LANGUAGE_CALLED_CLSW

=
void InwebTestLanguage::cli(void) {
	CommandLine::begin_subcommand(TEST_LANGUAGE_CLSUB, U"test-language");
	CommandLine::declare_heading(
		U"Usage: inweb test-language [-called NAME | FILE] -on FILE\n\n"
		U"Shows how the FILE of code would be read by Inweb if Inweb thought it were\n"
		U"written in the given language. This can either be the name of a language whose\n"
		U"definition Inweb already knows, e.g., '-called C' (see 'inweb inspect -resources'),\n"
		U"or it can be a filename containing a language declaration.\n\n"
		U"The code should be raw, not written in literate programming notation.\n\n"
		U"This is occasionally useful when experimenting with a new language definition,\n"
		U"but is mainly used for testing Inweb itself.");
	CommandLine::declare_switch(TEST_LANGUAGE_ON_CLSW, U"on", 2,
		U"sample of code to be run through the test");
	CommandLine::declare_switch(LANGUAGE_CALLED_CLSW, U"called", 2,
		U"use the language with this name (which Inweb must be able to find somewhere)");
	CommandLine::end_subcommand();
}

@ Changing the settings:

=
typedef struct inweb_test_language_settings {
	struct filename *test_language_on_setting; /* |-on X| */
	struct text_stream *name;
} inweb_test_language_settings;

void InwebTestLanguage::initialise(inweb_test_language_settings *itls) {
	itls->test_language_on_setting = NULL;
	itls->name = NULL;
}

int InwebTestLanguage::switch(inweb_instructions *ins, int id, int val, text_stream *arg) {
	inweb_test_language_settings *itls = &(ins->test_language_settings);
	switch (id) {
		case TEST_LANGUAGE_ON_CLSW:
			itls->test_language_on_setting = Filenames::from_text(arg); return TRUE;
		case LANGUAGE_CALLED_CLSW:
			itls->name = Str::duplicate(arg); return TRUE;
	}
	return FALSE;
}

@ In operation:

=
void InwebTestLanguage::run(inweb_instructions *ins) {
	inweb_operand op = Configuration::operand(ins, WEB_OPERAND_DISALLOWED, FALSE, FALSE);
	inweb_test_language_settings *itls = &(ins->test_language_settings);
	if (itls->test_language_on_setting == NULL)
		Errors::fatal("can't see what code to try out: '-on FILE' must be specified");
	programming_language *pl = NULL;
	if (op.F) pl = Languages::read_definition(op.F);
	else if (Str::len(itls->name) > 0) pl = Languages::find(NULL, itls->name);
	if (pl == NULL)
		Errors::fatal("programming language not found");
	TEMPORARY_TEXT(matter)
	TEMPORARY_TEXT(coloured)
	Painter::colour_file(pl, itls->test_language_on_setting, matter, coloured);
	PRINT("Test of colouring for language %S:\n%S\n%S\n", pl->language_name, matter, coloured);
	DISCARD_TEXT(matter)
	DISCARD_TEXT(coloured)
}
