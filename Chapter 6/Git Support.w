[Git::] Git Support.

Constructing a suitable gitignore file for a simple inweb project.

@ This is an extremely simple use of //foundation: Preprocessor//.

=
typedef struct gitignore_state {
	struct web *for_web;
	CLASS_DEFINITION
} gitignore_state;

void Git::write_gitignore(web *W, filename *prototype, filename *F) {
	linked_list *L = NEW_LINKED_LIST(preprocessor_macro);
	Preprocessor::reserve_macro(L, I"basics", NULL, Git::basics_expander);
	gitignore_state *specifics = CREATE(gitignore_state);
	specifics->for_web = W;
	text_stream *header = Str::new();
	WRITE_TO(header, "# This gitignore was automatically written by inweb -gitignore\n");
	WRITE_TO(header, "# and is not intended for human editing\n\n");
	WRITE_TO(STDOUT, "(Read script from %f)\n", prototype);
	Preprocessor::preprocess(prototype, F, header, L, STORE_POINTER_gitignore_state(specifics));
}

void Git::basics_expander(preprocessor_macro *mm, preprocessor_state *PPS,
	text_stream **parameter_values, preprocessor_loop *rep, text_file_position *tfp) {
	filename *prototype = Filenames::in(path_to_inweb_materials, I"default.giscript");
	TextFiles::read(prototype, FALSE, "can't open basic .gitignore file",
		TRUE, Preprocessor::scan_line, NULL, PPS);
	WRITE_TO(STDOUT, "(Read basics.giscript from inweb/");
	Pathnames::to_text_relative(STDOUT, path_to_inweb, path_to_inweb_materials);
	WRITE_TO(STDOUT, ")\n");
}
