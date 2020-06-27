[TeXUtilities::] TeX Utilities.

A few conveniences for using Inweb with TeX.

@h Post-processing TeX console output.
Pattern commands post-processing TeX tend to run TeX-like tools in
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
typedef struct tex_results {
	int overfull_hbox_count;
	int tex_error_count;
	int page_count;
	int pdf_size;
	struct filename *PDF_filename;
	CLASS_DEFINITION
} tex_results;

@ =
tex_results *TeXUtilities::new_results(weave_order *wv, filename *CF) {
	tex_results *res = CREATE(tex_results);
	res->overfull_hbox_count = 0;
	res->tex_error_count = 0;
	res->page_count = 0;
	res->pdf_size = 0;
	res->PDF_filename = Filenames::set_extension(CF, I".pdf");
	return res;
}

@ So, then, here's the function called from //Patterns// in response to
the special |PROCESS| command:

=
void TeXUtilities::post_process_weave(weave_order *wv, filename *CF) {
	wv->post_processing_results = TeXUtilities::new_results(wv, CF);
	TextFiles::read(CF, FALSE,
		"can't open console file", TRUE, TeXUtilities::scan_console_line, NULL,
		(void *) wv->post_processing_results);
}

@ =
void TeXUtilities::scan_console_line(text_stream *line, text_file_position *tfp,
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
void TeXUtilities::report_on_post_processing(weave_order *wv) {
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
int TeXUtilities::substitute_post_processing_data(text_stream *to, weave_order *wv,
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

@h Removing math mode.
"Math mode", in TeX jargon, is what happens when a mathematical formula
is written inside dollar signs: in |Answer is $x+y^2$|, the math mode
content is |x+y^2|. But since math mode doesn't (easily) exist in HTML,
for example, we want to strip it out if the format is not TeX-related.
To do this, the weaver calls the following.

=
void TeXUtilities::remove_math_mode(OUTPUT_STREAM, text_stream *text) {
	TEMPORARY_TEXT(math_matter)
	TeXUtilities::remove_math_mode_range(math_matter, text, 0, Str::len(text)-1);
	WRITE("%S", math_matter);
	DISCARD_TEXT(math_matter)
}

void TeXUtilities::remove_math_mode_range(OUTPUT_STREAM, text_stream *text, int from, int to) {
	for (int i=from; i <= to; i++) {
		@<Remove the over construction@>;
	}
	for (int i=from; i <= to; i++) {
		@<Remove the rm and it constructions@>;
		@<Remove the sqrt constructions@>;
	}
	int math_mode = FALSE;
	for (int i=from; i <= to; i++) {
		switch (Str::get_at(text, i)) {
			case '$':
				if (Str::get_at(text, i+1) == '$') i++;
				math_mode = (math_mode)?FALSE:TRUE; break;
			case '~': if (math_mode) WRITE(" "); else WRITE("~"); break;
			case '\\': @<Do something to strip out a TeX macro@>; break;
			default: PUT(Str::get_at(text, i)); break;
		}
	}
}

@ Here we remove |{{top}\over{bottom}}|, converting it to |((top) / (bottom))|.

@<Remove the over construction@> =
	if ((Str::get_at(text, i) == '\\') &&
		(Str::get_at(text, i+1) == 'o') && (Str::get_at(text, i+2) == 'v') &&
		(Str::get_at(text, i+3) == 'e') && (Str::get_at(text, i+4) == 'r') &&
		(Str::get_at(text, i+5) == '{')) {
		int bl = 1;
		int j = i-1;
		for (; j >= from; j--) {
			wchar_t c = Str::get_at(text, j);
			if (c == '{') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '}') bl++;
		}
		TeXUtilities::remove_math_mode_range(OUT, text, from, j-1);
		WRITE("((");
		TeXUtilities::remove_math_mode_range(OUT, text, j+2, i-2);
		WRITE(") / (");
		j=i+6; bl = 1;
		for (; j <= to; j++) {
			wchar_t c = Str::get_at(text, j);
			if (c == '}') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '{') bl++;
		}
		TeXUtilities::remove_math_mode_range(OUT, text, i+6, j-1);
		WRITE("))");
		TeXUtilities::remove_math_mode_range(OUT, text, j+2, to);
		return;
	}

@ Here we remove |{\rm text}|, converting it to |text|, and similarly |\it|.

@<Remove the rm and it constructions@> =
	if ((Str::get_at(text, i) == '{') && (Str::get_at(text, i+1) == '\\') &&
		(((Str::get_at(text, i+2) == 'r') && (Str::get_at(text, i+3) == 'm')) ||
			((Str::get_at(text, i+2) == 'i') && (Str::get_at(text, i+3) == 't'))) &&
		(Str::get_at(text, i+4) == ' ')) {
		TeXUtilities::remove_math_mode_range(OUT, text, from, i-1);
		int j=i+5;
		for (; j <= to; j++)
			if (Str::get_at(text, j) == '}')
				break;
		TeXUtilities::remove_math_mode_range(OUT, text, i+5, j-1);
		TeXUtilities::remove_math_mode_range(OUT, text, j+1, to);
		return;
	}

@ Here we remove |\sqrt{N}|, converting it to |sqrt(N)|. As a special case,
we also look out for |{}^3\sqrt{N}| for cube root.

@<Remove the sqrt constructions@> =
	if ((Str::get_at(text, i) == '\\') &&
		(Str::get_at(text, i+1) == 's') && (Str::get_at(text, i+2) == 'q') &&
		(Str::get_at(text, i+3) == 'r') && (Str::get_at(text, i+4) == 't') &&
		(Str::get_at(text, i+5) == '{')) {
		if ((Str::get_at(text, i-4) == '{') &&
			(Str::get_at(text, i-3) == '}') &&
			(Str::get_at(text, i-2) == '^') &&
			(Str::get_at(text, i-1) == '3')) {
			TeXUtilities::remove_math_mode_range(OUT, text, from, i-5);
			WRITE(" curt(");				
		} else {
			TeXUtilities::remove_math_mode_range(OUT, text, from, i-1);
			WRITE(" sqrt(");
		}
		int j=i+6, bl = 1;
		for (; j <= to; j++) {
			wchar_t c = Str::get_at(text, j);
			if (c == '}') {
				bl--;
				if (bl == 0) break;
			}
			if (c == '{') bl++;
		}
		TeXUtilities::remove_math_mode_range(OUT, text, i+6, j-1);
		WRITE(")");
		TeXUtilities::remove_math_mode_range(OUT, text, j+1, to);
		return;
	}

@<Do something to strip out a TeX macro@> =
	TEMPORARY_TEXT(macro)
	i++;
	while ((i < Str::len(text)) && (Characters::isalpha(Str::get_at(text, i))))
		PUT_TO(macro, Str::get_at(text, i++));
	if (Str::eq(macro, I"not")) @<Remove the not prefix@>
	else @<Remove a general macro@>;
	DISCARD_TEXT(macro)
	i--;

@<Remove a general macro@> =
	if (Str::eq(macro, I"leq")) WRITE("<=");
	else if (Str::eq(macro, I"geq")) WRITE(">=");
	else if (Str::eq(macro, I"sim")) WRITE("~");
	else if (Str::eq(macro, I"hbox")) WRITE("");
	else if (Str::eq(macro, I"left")) WRITE("");
	else if (Str::eq(macro, I"right")) WRITE("");
	else if (Str::eq(macro, I"Rightarrow")) WRITE("=>");
	else if (Str::eq(macro, I"Leftrightarrow")) WRITE("<=>");
	else if (Str::eq(macro, I"to")) WRITE("-->");
	else if (Str::eq(macro, I"rightarrow")) WRITE("-->");
	else if (Str::eq(macro, I"longrightarrow")) WRITE("-->");
	else if (Str::eq(macro, I"leftarrow")) WRITE("<--");
	else if (Str::eq(macro, I"longleftarrow")) WRITE("<--");
	else if (Str::eq(macro, I"lbrace")) WRITE("{");
	else if (Str::eq(macro, I"mid")) WRITE("|");
	else if (Str::eq(macro, I"rbrace")) WRITE("}");
	else if (Str::eq(macro, I"cdot")) WRITE(".");
	else if (Str::eq(macro, I"cdots")) WRITE("...");
	else if (Str::eq(macro, I"dots")) WRITE("...");
	else if (Str::eq(macro, I"times")) WRITE("*");
	else if (Str::eq(macro, I"quad")) WRITE("  ");
	else if (Str::eq(macro, I"qquad")) WRITE("    ");
	else if (Str::eq(macro, I"TeX")) WRITE("TeX");
	else if (Str::eq(macro, I"neq")) WRITE("!=");
	else if (Str::eq(macro, I"noteq")) WRITE("!=");
	else if (Str::eq(macro, I"ell")) WRITE("l");
	else if (Str::eq(macro, I"log")) WRITE("log");
	else if (Str::eq(macro, I"exp")) WRITE("exp");
	else if (Str::eq(macro, I"sin")) WRITE("sin");
	else if (Str::eq(macro, I"cos")) WRITE("cos");
	else if (Str::eq(macro, I"tan")) WRITE("tan");
	else if (Str::eq(macro, I"top")) WRITE("T");
	else if (Str::eq(macro, I"Alpha")) PUT((wchar_t) 0x0391);
	else if (Str::eq(macro, I"Beta")) PUT((wchar_t) 0x0392);
	else if (Str::eq(macro, I"Gamma")) PUT((wchar_t) 0x0393);
	else if (Str::eq(macro, I"Delta")) PUT((wchar_t) 0x0394);
	else if (Str::eq(macro, I"Epsilon")) PUT((wchar_t) 0x0395);
	else if (Str::eq(macro, I"Zeta")) PUT((wchar_t) 0x0396);
	else if (Str::eq(macro, I"Eta")) PUT((wchar_t) 0x0397);
	else if (Str::eq(macro, I"Theta")) PUT((wchar_t) 0x0398);
	else if (Str::eq(macro, I"Iota")) PUT((wchar_t) 0x0399);
	else if (Str::eq(macro, I"Kappa")) PUT((wchar_t) 0x039A);
	else if (Str::eq(macro, I"Lambda")) PUT((wchar_t) 0x039B);
	else if (Str::eq(macro, I"Mu")) PUT((wchar_t) 0x039C);
	else if (Str::eq(macro, I"Nu")) PUT((wchar_t) 0x039D);
	else if (Str::eq(macro, I"Xi")) PUT((wchar_t) 0x039E);
	else if (Str::eq(macro, I"Omicron")) PUT((wchar_t) 0x039F);
	else if (Str::eq(macro, I"Pi")) PUT((wchar_t) 0x03A0);
	else if (Str::eq(macro, I"Rho")) PUT((wchar_t) 0x03A1);
	else if (Str::eq(macro, I"Varsigma")) PUT((wchar_t) 0x03A2);
	else if (Str::eq(macro, I"Sigma")) PUT((wchar_t) 0x03A3);
	else if (Str::eq(macro, I"Tau")) PUT((wchar_t) 0x03A4);
	else if (Str::eq(macro, I"Upsilon")) PUT((wchar_t) 0x03A5);
	else if (Str::eq(macro, I"Phi")) PUT((wchar_t) 0x03A6);
	else if (Str::eq(macro, I"Chi")) PUT((wchar_t) 0x03A7);
	else if (Str::eq(macro, I"Psi")) PUT((wchar_t) 0x03A8);
	else if (Str::eq(macro, I"Omega")) PUT((wchar_t) 0x03A9);
	else if (Str::eq(macro, I"alpha")) PUT((wchar_t) 0x03B1);
	else if (Str::eq(macro, I"beta")) PUT((wchar_t) 0x03B2);
	else if (Str::eq(macro, I"gamma")) PUT((wchar_t) 0x03B3);
	else if (Str::eq(macro, I"delta")) PUT((wchar_t) 0x03B4);
	else if (Str::eq(macro, I"epsilon")) PUT((wchar_t) 0x03B5);
	else if (Str::eq(macro, I"zeta")) PUT((wchar_t) 0x03B6);
	else if (Str::eq(macro, I"eta")) PUT((wchar_t) 0x03B7);
	else if (Str::eq(macro, I"theta")) PUT((wchar_t) 0x03B8);
	else if (Str::eq(macro, I"iota")) PUT((wchar_t) 0x03B9);
	else if (Str::eq(macro, I"kappa")) PUT((wchar_t) 0x03BA);
	else if (Str::eq(macro, I"lambda")) PUT((wchar_t) 0x03BB);
	else if (Str::eq(macro, I"mu")) PUT((wchar_t) 0x03BC);
	else if (Str::eq(macro, I"nu")) PUT((wchar_t) 0x03BD);
	else if (Str::eq(macro, I"xi")) PUT((wchar_t) 0x03BE);
	else if (Str::eq(macro, I"omicron")) PUT((wchar_t) 0x03BF);
	else if (Str::eq(macro, I"pi")) PUT((wchar_t) 0x03C0);
	else if (Str::eq(macro, I"rho")) PUT((wchar_t) 0x03C1);
	else if (Str::eq(macro, I"varsigma")) PUT((wchar_t) 0x03C2);
	else if (Str::eq(macro, I"sigma")) PUT((wchar_t) 0x03C3);
	else if (Str::eq(macro, I"tau")) PUT((wchar_t) 0x03C4);
	else if (Str::eq(macro, I"upsilon")) PUT((wchar_t) 0x03C5);
	else if (Str::eq(macro, I"phi")) PUT((wchar_t) 0x03C6);
	else if (Str::eq(macro, I"chi")) PUT((wchar_t) 0x03C7);
	else if (Str::eq(macro, I"psi")) PUT((wchar_t) 0x03C8);
	else if (Str::eq(macro, I"omega")) PUT((wchar_t) 0x03C9);
	else if (Str::eq(macro, I"exists")) PUT((wchar_t) 0x2203);
	else if (Str::eq(macro, I"in")) PUT((wchar_t) 0x2208);
	else if (Str::eq(macro, I"forall")) PUT((wchar_t) 0x2200);
	else if (Str::eq(macro, I"cap")) PUT((wchar_t) 0x2229);
	else if (Str::eq(macro, I"emptyset")) PUT((wchar_t) 0x2205);
	else if (Str::eq(macro, I"subseteq")) PUT((wchar_t) 0x2286);
	else if (Str::eq(macro, I"land")) PUT((wchar_t) 0x2227);
	else if (Str::eq(macro, I"lor")) PUT((wchar_t) 0x2228);
	else if (Str::eq(macro, I"lnot")) PUT((wchar_t) 0x00AC);
	else if (Str::eq(macro, I"sum")) PUT((wchar_t) 0x03A3);
	else if (Str::eq(macro, I"prod")) PUT((wchar_t) 0x03A0);
	else {
		if (Str::len(macro) > 0) {
			int suspect = TRUE;
			LOOP_THROUGH_TEXT(pos, macro) {
				wchar_t c = Str::get(pos);
				if ((c >= 'A') && (c <= 'Z')) continue;
				if ((c >= 'a') && (c <= 'z')) continue;
				suspect = FALSE;
			}
			if (Str::eq(macro, I"n")) suspect = FALSE;
			if (Str::eq(macro, I"t")) suspect = FALSE;
			if (suspect)
				PRINT("[Passing through unknown TeX macro \\%S:\n  %S\n", macro, text);
		}
		WRITE("\\%S", macro);
	}

@ For Inform's purposes, we need to deal with just |\not\exists| and |\not\forall|.

@<Remove the not prefix@> =
	if (Str::get_at(text, i) == '\\') {
		Str::clear(macro);
		i++;
		while ((i < Str::len(text)) && (Characters::isalpha(Str::get_at(text, i))))
			PUT_TO(macro, Str::get_at(text, i++));
		if (Str::eq(macro, I"exists")) PUT((wchar_t) 0x2204);
		else if (Str::eq(macro, I"forall")) { PUT((wchar_t) 0x00AC); PUT((wchar_t) 0x2200); }
		else {
			PRINT("Don't know how to apply '\\not' to '\\%S'\n", macro);
		}
	} else {
		PRINT("Don't know how to apply '\\not' here\n");
	}
