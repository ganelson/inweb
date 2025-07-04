[Git::] Git Support.

Constructing a suitable gitignore file for a simple inweb project.

@ This is an extremely simple use of //foundation: Preprocessor//.

=
void Git::write_gitignore(ls_web *W, filename *prototype, filename *F) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	Preprocessor::new_macro(L, I"basics", NULL, Git::basics_expander, NULL);
	text_stream *header = Str::new();
	WRITE_TO(header, "# This gitignore was automatically written by inweb -gitignore\n");
	WRITE_TO(header, "# and is not intended for human editing\n\n");
	WRITE_TO(STDOUT, "(Read script from %f)\n", prototype);
	Preprocessor::preprocess(prototype, F, header, L, NULL_GENERAL_POINTER, '#', ISO_ENC);
}

@ Our one non-standard macro simply includes a file of standing material which
is the same as the default .giscript file anyway:

=
void Git::basics_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *loop, text_file_position *tfp) {
	filename *prototype = Filenames::in(Pathnames::path_to_inweb_materials(), I"default.giscript");
	TextFiles::read(prototype, FALSE, "can't open basic .gitignore file",
		TRUE, Preprocessor::scan_line, NULL, PPS);
	WRITE_TO(STDOUT, "(Read basics.giscript from %f)\n", prototype);
}
