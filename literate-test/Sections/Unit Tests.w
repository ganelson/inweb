[Unit::] Unit Tests.

A selection of tests for, or demonstrations of, foundation features.

@h Web Control Language.

=
void Unit::test_WCL(text_stream *arg) {
	filename *F = Filenames::from_text(arg);
	wcl_declaration *D = WCL::read_for_type_only(F, MISCELLANY_WCLTYPE);
	WCL::write(STDOUT, D);
	WCL::summarise(STDOUT, D);
}
