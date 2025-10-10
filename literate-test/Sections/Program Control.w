[Main::] Program Control.

Choosing which unit test to run on the basis of the command-line arguments.

@h Main routine.

@d PROGRAM_NAME "literate-test"

@e TEST_WCL_CLSW

=
int main(int argc, char **argv) {
	Foundation::start(argc, argv);
	LiterateModule::start();
	CommandLine::declare_heading(U"literate-test: a tool for testing literate-module facilities\n");

	CommandLine::declare_switch(TEST_WCL_CLSW, U"test-wcl", 2,
		U"test parsing of WCL file X");

	CommandLine::read(argc, argv, NULL, &Main::respond, &Main::ignore);
	LiterateModule::end();
	Foundation::end();
	return 0;
}

void Main::respond(int id, int val, text_stream *arg, void *state) {
	switch (id) {
		case TEST_WCL_CLSW: Unit::test_WCL(arg); break;
	}
}

void Main::ignore(int id, text_stream *arg, void *state) {
	Errors::fatal("only switches may be used at the command line");
}
