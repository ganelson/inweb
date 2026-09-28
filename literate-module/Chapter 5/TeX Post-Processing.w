[TeXPost::] TeX Post-Processing.

Making sense of console output from pdftex, tex or similar tools.

@ Pattern commands post-processing TeX tend to run TeX-like tools in
"scrollmode", so that any errors whizz by rather than interrupting or halting
the session. Prime among errors is the "overfull hbox error", a defect of TeX
resulting from its inability to adjust letter spacing, so that it requires us
to adjust the copy to fit the margins of the page properly. (In practice we
get this here by having code lines which are too wide to display.)

Also, TeX helpfully reports the size and page count of what it produces, and
we're not too proud to scrape that information out of the console file, besides
the error messages (which begin with an exclamation mark in column 1).

This structure will store what we find:

=
classdef tex_results {
	int overfull_hbox_count;
	int tex_error_count;
	int page_count;
	int pdf_size;
	int missing_character_count;
	struct filename *PDF_filename;
	struct text_stream *output_message;
}

@ =
tex_results *TeXPost::new_results(weave_order *wv, filename *CF) {
	tex_results *res = CREATE(tex_results);
	res->overfull_hbox_count = 0;
	res->tex_error_count = 0;
	res->missing_character_count = 0;
	res->page_count = 0;
	res->pdf_size = 0;
	res->PDF_filename = Filenames::set_extension(CF, I".pdf");
	res->output_message = Str::new();
	return res;
}

@ So, then, here's the function called from //Patterns// in response to
the special `PROCESS` command.

The `xetex`, `tex` and `pdftex` engines create subtly different logs: in
particular, `xetex` reports page count but not byte size, and encodes its
log as UTF-8, whereas the others use Latin-1.

=
void TeXPost::scan_TeX_log(weave_order *wv, filename *CF) {
	tex_results *tr = TeXPost::new_results(wv, CF);
	wv->post_processing_results = tr;
	TextFiles::read(CF, FALSE,
		"can't open TeX log file", TRUE, TeXPost::scan_console_line, NULL, (void *) tr);
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, tr->output_message, U"%c*%((%d+) pages*, (%d+) bytes*%c*")) {
		tr->page_count = Str::atoi(mr.exp[0], 0);
		tr->pdf_size = Str::atoi(mr.exp[1], 0);
	} else if (Regexp::match(&mr, tr->output_message, U"%c*%((%d+) pages*%)*%c*")) {
		tr->page_count = Str::atoi(mr.exp[0], 0);
	}
	Regexp::dispose_of(&mr);
}

@ Infuriatingly, the TeX log file has hard line breaks at 80-column boundaries;
so if the filename is long enough, the line `Output written on "..." (... pages, ... bytes).`
will break in the middle of the numbers. So we buffer up the tail of the log into
a single string, and parse it later.

=
void TeXPost::scan_console_line(text_stream *line, text_file_position *tfp,
	void *res_V) {
	tex_results *res = (tex_results *) res_V;
	match_results mr = Regexp::create_mr();
	if (Regexp::match(&mr, line, U"Output written %c*")) {
		WRITE_TO(res->output_message, "%S", line);
	} else if (Str::len(res->output_message) > 0) {
		WRITE_TO(res->output_message, "%S", line);
	}
	if (Regexp::match(&mr, line, U"%c*not set up for use with LaTeX.%c*"))
		res->missing_character_count++;
	else if (Regexp::match(&mr, line, U"%c*Missing character: There is no (%c*) in font (%c+)!%c*"))
		res->missing_character_count++;
	else if (Regexp::match(&mr, line, U"%c*Missing character: There is no (%c*) %(\"(%c+)%) in font (%c+)!%c*"))
		res->missing_character_count++;
	else if (Regexp::match(&mr, line, U"%c+verfull \\hbox%c+"))
		res->overfull_hbox_count++;
	else if (Str::get_first_char(line) == '!') {
		res->tex_error_count++;
	}
	Regexp::dispose_of(&mr);
}

@h Reporting.

=
void TeXPost::report_on_post_processing(weave_order *wv) {
	tex_results *res = wv->post_processing_results;
	if (res) {
		PRINT(": %dpp", res->page_count);
		if (res->pdf_size > 0) PRINT(" %dK", res->pdf_size/1024);
		if (res->overfull_hbox_count > 0)
			PRINT(", %d overfull hbox(es)", res->overfull_hbox_count);
		if (res->tex_error_count > 0)
			PRINT(", %d error(s)", res->tex_error_count);
		if (res->missing_character_count > 0)
			PRINT(", %d missing character warning(s)", res->missing_character_count);
	}
}

@ And here are some details to do with the results of post-processing.

=
int TeXPost::substitute_post_processing_data(text_stream *to, weave_order *wv,
	text_stream *detail) {
	if (wv) {
		tex_results *res = wv->post_processing_results;
		if (res) {
			if (Str::eq_wide_string(detail, U"PDF Size")) {
				WRITE_TO(to, "%dKB", res->pdf_size/1024);
			} else if (Str::eq_wide_string(detail, U"Extent")) {
				WRITE_TO(to, "%dpp", res->page_count);
			} else if (Str::eq_wide_string(detail, U"Leafname")) {
				Str::copy(to, Filenames::get_leafname(res->PDF_filename));
			} else if (Str::eq_wide_string(detail, U"Errors")) {
				Str::clear(to);
				if ((res->overfull_hbox_count > 0) || (res->tex_error_count > 0) ||
					(res->missing_character_count > 0))
					WRITE_TO(to, ": ");
				if (res->overfull_hbox_count > 0) {
					WRITE_TO(to, "%d overfull line%s",
						res->overfull_hbox_count,
						(res->overfull_hbox_count>1)?"s":"");
					if ((res->missing_character_count > 0) || (res->tex_error_count > 0))
						WRITE_TO(to, ", ");
				}
				if (res->missing_character_count > 0) {
					WRITE_TO(to, "%d missing character error%s",
						res->missing_character_count,
						(res->missing_character_count>1)?"s":"");
					if (res->tex_error_count > 0)
						WRITE_TO(to, ", ");
				}
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
