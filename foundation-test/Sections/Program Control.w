[Main::] Program Control.

Choosing which unit test to run on the basis of the command-line arguments.

@h Main routine.

@d PROGRAM_NAME "foundation-test"

@e TEST_STRINGS_CLSW
@e TEST_RE_CLSW
@e TEST_DICT_CLSW
@e TEST_LITERALS_CLSW
@e TEST_REPLACEMENT_CLSW
@e TEST_LISTS_CLSW
@e TEST_STACKS_CLSW
@e TEST_SEMVER_CLSW
@e TEST_TREES_CLSW

=
int main(int argc, char **argv) {
	Foundation::start();
	CommandLine::set_locale(argc, argv);
	CommandLine::declare_heading(L"inexample: a tool for testing foundation facilities\n");

	CommandLine::declare_switch(TEST_STRINGS_CLSW, L"test-strings", 2,
		L"test string manipulation (X is ignored)");
	CommandLine::declare_switch(TEST_RE_CLSW, L"test-regexp", 2,
		L"test regular expression matches on a list of cases in file X");
	CommandLine::declare_switch(TEST_DICT_CLSW, L"test-dictionaries", 2,
		L"test dictionary building on a list of keys and values in file X");
	CommandLine::declare_switch(TEST_LITERALS_CLSW, L"test-literals", 2,
		L"test string literals (X is ignored)");
	CommandLine::declare_switch(TEST_REPLACEMENT_CLSW, L"test-replacement", 2,
		L"test regular expression replacements on a list of cases in file X");
	CommandLine::declare_switch(TEST_LISTS_CLSW, L"test-lists", 2,
		L"test linked lists (X is ignored)");
	CommandLine::declare_switch(TEST_STACKS_CLSW, L"test-stacks", 2,
		L"test LIFO stacks (X is ignored)");
	CommandLine::declare_switch(TEST_SEMVER_CLSW, L"test-semver", 2,
		L"test semantic version numbers (X is ignored)");
	CommandLine::declare_switch(TEST_TREES_CLSW, L"test-trees", 2,
		L"test heterogeneous trees (X is ignored)");

	CommandLine::read(argc, argv, NULL, &Main::respond, &Main::ignore);
	Foundation::end();
	return 0;
}

void Main::respond(int id, int val, text_stream *arg, void *state) {
	switch (id) {
		case TEST_STRINGS_CLSW: Unit::test_strings(); break;
		case TEST_RE_CLSW: Unit::test_regexp(arg); break;
		case TEST_REPLACEMENT_CLSW: Unit::test_replacement(arg); break;
		case TEST_DICT_CLSW: Unit::test_dictionaries(arg); break;
		case TEST_LITERALS_CLSW: Unit::test_literals(); break;
		case TEST_LISTS_CLSW: Unit::test_linked_lists(); break;
		case TEST_STACKS_CLSW: Unit::test_stacks(); break;
		case TEST_SEMVER_CLSW: Unit::test_semver(); break;
		case TEST_TREES_CLSW: Unit::test_trees(); break;
	}
}

void Main::ignore(int id, text_stream *arg, void *state) {
	Errors::fatal("only switches may be used at the command line");
}
