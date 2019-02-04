[Git::] Git Support.

Constructing a suitable gitignore file for a simple inweb project.

@ This section offers just one function, which constructs a |.gitignore|
file by following a "prototype".

=
typedef struct gitignore_state {
	struct web *for_web;
	struct text_stream to_gitignore;
	int last_line_was_blank; /* used to suppress runs of multiple blank lines */
} gitignore_state;

void Git::write_gitignore(web *W, filename *prototype, filename *F) {
	gitignore_state MS;
	MS.for_web = W;
	MS.last_line_was_blank = TRUE;
	text_stream *OUT = &(MS.to_gitignore);
	if (STREAM_OPEN_TO_FILE(OUT, F, ISO_ENC) == FALSE)
		Errors::fatal_with_file("unable to write tangled file", F);
	WRITE("# This gitignore was automatically written by inweb -gitignore\n");
	WRITE("# and is not intended for human editing\n\n");
	TextFiles::read(prototype, FALSE, "can't open prototype file",
		TRUE, Git::copy_gitignore_line, NULL, &MS);
	STREAM_CLOSE(OUT);
	WRITE_TO(STDOUT, "Wrote gitignore to %f\n", F);
}

@ =
void Git::copy_gitignore_line(text_stream *line, text_file_position *tfp, void *X) {
	gitignore_state *MS = (gitignore_state *) X;
	text_stream *OUT = &(MS->to_gitignore);

	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, L" *#%c*")) { Regexp::dispose_of(&mr); return; }
	if (Regexp::match(&mr, line, L" *{basics} *")) @<Expand basics@>;
	Regexp::dispose_of(&mr);

	@<And otherwise copy the line straight through@>;
}

@<Expand basics@> =
	filename *prototype =
		Filenames::in_folder(path_to_inweb_materials, I"gitignorescript.txt");
	TextFiles::read(prototype, FALSE, "can't open make settings file",
		TRUE, Git::copy_gitignore_line, NULL, MS);
	Regexp::dispose_of(&mr);
	return;

@<And otherwise copy the line straight through@> =
	if (Str::len(line) == 0) {
		if (MS->last_line_was_blank == FALSE) WRITE("\n");
		MS->last_line_was_blank = TRUE;
	} else {
		MS->last_line_was_blank = FALSE;
		WRITE("%S\n", line);
	}
