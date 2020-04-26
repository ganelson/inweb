[RunningTeX::] Running Through TeX.

To post-process a weave by running it through TeX, or one of its
variant typesetting programs.

@h Running TeX.
Although we are running |pdftex|, a modern variant of TeX, rather than the
original, they are very similar as command-line tools; the difference is
that the output is a PDF file rather than a DVI file, Knuth's original stab
at the same basic idea.

In particular, we call it in |-interaction=scrollmode| so that any errors
whizz by rather than interrupting or halting the session. Because of that, we
spool the output onto a console file which we can then read in and parse to
find the number of errors actually generated. Prime among errors is the
"overfull hbox error", a defect of TeX resulting from its inability to adjust
letter spacing, so that it requires us to adjust the copy to fit the margins
of the page properly. (In practice we get this here by having code lines which
are too wide to display.)

@ =
void RunningTeX::post_process_weave(weave_order *wv, filename *CF) {
	tex_results *res = CREATE(tex_results);
	@<Initialise the TeX results@>;
	wv->post_processing_results = res;	
	@<Read back the console file and parse it for error messages@>;
}

@ We're going to have to read in a console file of TeX output to work out
what happened, and this structure will store what we find:

=
typedef struct tex_results {
	int overfull_hbox_count;
	int tex_error_count;
	int page_count;
	int pdf_size;
	struct filename *PDF_filename;
	MEMORY_MANAGEMENT
} tex_results;

@<Initialise the TeX results@> =
	res->overfull_hbox_count = 0;
	res->tex_error_count = 0;
	res->page_count = 0;
	res->pdf_size = 0;
	res->PDF_filename = Filenames::set_extension(CF, I".pdf");

@ TeX helpfully reports the size and page count of what it produces, and
we're not too proud to scrape that information out of the console file, besides
the error messages (which begin with an exclamation mark in column 1).

@<Read back the console file and parse it for error messages@> =
	TextFiles::read(CF, FALSE,
		"can't open console file", TRUE, RunningTeX::scan_console_line, NULL,
		(void *) res);

@ =
void RunningTeX::scan_console_line(text_stream *line, text_file_position *tfp,
	void *res_V) {
	tex_results *res = (tex_results *) res_V;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line,
		L"Output written %c*? %((%d+) page%c*?(%d+) bytes%).")) {
		res->page_count = Str::atoi(mr.exp[0], 0);
		res->pdf_size = Str::atoi(mr.exp[1], 0);
	}
	if (Regexp::match(&mr, line, L"%c+verfull \\hbox%c+"))
		res->overfull_hbox_count++;
	else if (Str::get_first_char(line) == '!') {
		res->tex_error_count++;
	}
	Regexp::dispose_of(&mr);
}

@h Reporting.

=
void RunningTeX::report_on_post_processing(weave_order *wv) {
	tex_results *res = wv->post_processing_results;
	if (res) {
		PRINT(": %dpp %dK", res->page_count, res->pdf_size/1024);
		if (res->overfull_hbox_count > 0)
			PRINT(", %d overfull hbox(es)", res->overfull_hbox_count);
		if (res->tex_error_count > 0)
			PRINT(", %d error(s)", res->tex_error_count);
	}
}

@ And here are some details to do with the results of post-processing.

=
int RunningTeX::substitute_post_processing_data(text_stream *to, weave_order *wv,
	text_stream *detail) {
	if (wv) {
		tex_results *res = wv->post_processing_results;
		if (res) {
			if (Str::eq_wide_string(detail, L"PDF Size")) {
				WRITE_TO(to, "%dKB", res->pdf_size/1024);
			} else if (Str::eq_wide_string(detail, L"Extent")) {
				WRITE_TO(to, "%dpp", res->page_count);
			} else if (Str::eq_wide_string(detail, L"Leafname")) {
				Str::copy(to, Filenames::get_leafname(res->PDF_filename));
			} else if (Str::eq_wide_string(detail, L"Errors")) {
				Str::clear(to);
				if ((res->overfull_hbox_count > 0) || (res->tex_error_count > 0))
					WRITE_TO(to, ": ");
				if (res->overfull_hbox_count > 0)
					WRITE_TO(to, "%d overfull line%s",
						res->overfull_hbox_count,
						(res->overfull_hbox_count>1)?"s":"");
				if ((res->overfull_hbox_count > 0) && (res->tex_error_count > 0))
					WRITE_TO(to, ", ");
				if (res->tex_error_count > 0)
					WRITE_TO(to, "%d TeX error%s",
						res->tex_error_count,
						(res->tex_error_count>1)?"s":"");
			} else return FALSE;
			return TRUE;
		}
	}
	return FALSE;
}
